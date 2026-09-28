--[[
    JustXDoors — Game/Main/Main.lua

    Tab layout:
        Column 1 — Character
        Column 2 — Visual
        Column 3 — Misc

    Fly ported from Abyssal Hub:
        Single BodyVelocity, camera-projected direction,
        NO PlatformStand / BodyGyro (those cause the server
        to rubber-band the character back).
]]

local Main = {}

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")

local Player = Players.LocalPlayer

------------------------------------------------------
-- CORE / UI
------------------------------------------------------

local Core
local Tab
local Connections = {}
local Elements    = {}

------------------------------------------------------
-- CHARACTER
------------------------------------------------------

local Character
local Humanoid
local RootPart

local OldJump  = false
local OldSlide = false

------------------------------------------------------
-- PHYSICS / FLY
------------------------------------------------------

-- Abyssal-style: one BodyVelocity, no gyro, no PlatformStand
local FlyBody    = nil
local FlyEnabled = false

-- Remove Acceleration
local PartProperties = {}   -- [BasePart] = original CustomPhysicalProperties
local CustomPhysics  = nil

------------------------------------------------------
-- VISUAL
------------------------------------------------------

local FullBrightEnabled = false
local NoFogEnabled      = false
local LightingBackup    = nil
local AtmosphereBackup  = {}

------------------------------------------------------
-- INSTANT INTERACT
------------------------------------------------------

local ModifiedPrompts = {}

------------------------------------------------------
-- HELPERS
------------------------------------------------------

local function connect(signal, cb)
    local c = signal:Connect(cb)
    table.insert(Connections, c)
    return c
end

local function disconnectAll()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    table.clear(Connections)
end

local function getCharacter()
    Character = Player.Character or Player.CharacterAdded:Wait()
    Humanoid  = Character:FindFirstChildOfClass("Humanoid")
    RootPart  = Character:FindFirstChild("HumanoidRootPart")
    return Character
end

local function getFloor()
    local gd = ReplicatedStorage:FindFirstChild("GameData")
    if not gd then return "Hotel" end
    local f = gd:FindFirstChild("Floor")
    return f and f.Value or "Hotel"
end

local function getLiveModifiers()
    return workspace:FindFirstChild("LiveModifiers")
        or ReplicatedStorage:FindFirstChild("LiveModifiers")
end

local function isCrouching()
    if not Character then return false end
    local floor = getFloor()
    if floor == "Fools" or floor == "OldHotel" then
        return Character:GetAttribute("Crouching") == true
    end
    local cp = Character:FindFirstChild("CollisionPart") or Character:FindFirstChild("Collision")
    if cp and cp:IsA("BasePart") then
        local ok, g = pcall(function() return cp.CollisionGroup end)
        if ok and g == "PlayerCrouching" then return true end
    end
    return Character:GetAttribute("Crouching") == true
end

local function getInjuriesSpeed()
    if not Humanoid then return 0 end
    return 0.075 * (Humanoid.MaxHealth - Humanoid.Health)
end

local function getCurrentSpeed()
    if not Character then return 15 end
    local s = 15
    s += Character:GetAttribute("SpeedBoost")       or 0
    s += Character:GetAttribute("SpeedBoostBehind") or 0
    s += Character:GetAttribute("SpeedBoostExtra")  or 0
    if getFloor() == "Party" then s += 10 end
    local m = getLiveModifiers()
    if m then
        if m:FindFirstChild("PlayerFast")       then s += 3  end
        if m:FindFirstChild("PlayerFaster")     then s += 6  end
        if m:FindFirstChild("PlayerFastest")    then s += 20 end
        if m:FindFirstChild("PlayerSlow")       then s -= 3  end
        if m:FindFirstChild("PlayerSlowHealth") then s -= getInjuriesSpeed() end
    end
    if isCrouching() then
        if m and m:FindFirstChild("PlayerCrouchSlow") then s -= 8
        elseif m and m:FindFirstChild("PlayerSlow")   then s -= 8
        else s -= 5 end
    end
    return math.max(s, 0)
end

local function getToggleValue(el)
    if not el then return false end
    if type(el.Get) == "function" then
        local ok, v = pcall(function() return el:Get() end)
        if ok then return v == true end
    end
    return el.Value == true
end

local function getSliderValue(el, default)
    if not el then return default end
    if type(el.Get) == "function" then
        local ok, v = pcall(function() return el:Get() end)
        if ok and type(v) == "number" then return v end
    end
    if type(el.Value) == "number" then return el.Value end
    return default
end

local function speedEnabled() return getToggleValue(Elements.SpeedBoostToggle) end

local function applySpeed()
    if not Humanoid or not Humanoid.Parent then return end
    local speed = getCurrentSpeed()
    if speedEnabled() then
        speed = speed + getSliderValue(Elements.SpeedBoost, 0)
    end
    Humanoid.WalkSpeed = math.max(speed, 0)
end

local function fireCrouchRemote()
    local rf = ReplicatedStorage:FindFirstChild("RemotesFolder")
    if not rf then return end
    local cr = rf:FindFirstChild("Crouch")
    if not cr or not cr:IsA("RemoteEvent") then return end
    pcall(function() cr:FireServer(isCrouching(), true) end)
end

------------------------------------------------------
-- REMOVE ACCELERATION (Abyssal port)
------------------------------------------------------

local function buildCustomPhysics()
    if not RootPart then return end
    local p = RootPart.CustomPhysicalProperties
    CustomPhysics = PhysicalProperties.new(
        100,              -- Density (very high = no slide)
        p.Friction,
        p.Elasticity,
        p.FrictionWeight,
        p.ElasticityWeight
    )
end

local function snapshotPartProperties()
    PartProperties = {}
    if not Character then return end
    for _, part in Character:GetDescendants() do
        if part:IsA("BasePart") then
            PartProperties[part] = part.CustomPhysicalProperties
        end
    end
end

local function applyRemoveAcceleration(enabled)
    if not CustomPhysics then return end
    for part, original in pairs(PartProperties) do
        pcall(function()
            part.CustomPhysicalProperties = enabled and CustomPhysics or original
        end)
    end
end

------------------------------------------------------
-- FLY (Abyssal style)
-- Key differences from old implementation:
--   • NO PlatformStand / AutoRotate = false  ← caused server rubber-band
--   • NO BodyGyro                            ← caused jitter
--   • BodyVelocity parented each frame (on=RootPart, off=nil)
--   • Direction from camera's projected look vector (like Abyssal)
------------------------------------------------------

local function setupFlyBody()
    if FlyBody then pcall(function() FlyBody:Destroy() end) end
    FlyBody = Instance.new("BodyVelocity")
    FlyBody.Name      = "JustXDoorsFly"
    FlyBody.MaxForce  = Vector3.new(9e9, 9e9, 9e9)
    FlyBody.Velocity   = Vector3.zero
end

-- Abyssal's GetFlyVelocity: project MoveDirection onto camera's look plane
local function getFlyVelocity()
    local cam = workspace.CurrentCamera
    if not cam or not Humanoid then return Vector3.zero end
    if Humanoid.MoveDirection == Vector3.zero then return Vector3.zero end

    local look  = cam.CFrame.LookVector
    local flat  = Vector3.new(look.X, 0, look.Z)
    local frame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + flat)
    local vel   = (cam.CFrame * CFrame.new(
                      frame:VectorToObjectSpace(Humanoid.MoveDirection)
                  )).Position - cam.CFrame.Position

    if vel.Magnitude == 0 then return Vector3.zero end
    return vel.Unit
end

local function enableFly()
    if FlyEnabled then return end
    getCharacter()
    if not RootPart or not Humanoid then return end
    FlyEnabled = true
    setupFlyBody()
end

local function disableFly()
    FlyEnabled = false
    if FlyBody then
        FlyBody.Parent = nil   -- detach first so physics settle
        pcall(function() FlyBody:Destroy() end)
        FlyBody = nil
    end
    -- Restore walk state (gentle, no PlatformStand toggle needed)
    if Humanoid then
        pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
    end
end

local function tickFly()
    if not FlyEnabled or not FlyBody or not RootPart then return end

    local flySpeed = getSliderValue(Elements.FlySpeed, 20)
    local dir      = getFlyVelocity()

    -- Vertical control
    local vertical = 0
    if UserInputService:IsKeyDown(Enum.KeyCode.Space)
        or Humanoid:GetState() == Enum.HumanoidStateType.Jumping
    then
        vertical = flySpeed
    elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.C)
    then
        vertical = -flySpeed
    end

    FlyBody.Parent   = RootPart
    FlyBody.Velocity = dir * flySpeed + Vector3.new(0, vertical, 0)
end

------------------------------------------------------
-- JUMP / SLIDE
------------------------------------------------------

local function applyJump(enabled)
    if not Character then return end
    Character:SetAttribute("CanJump", enabled and true or OldJump)
end

local function applySlide(enabled)
    if not Character then return end
    Character:SetAttribute("CanSlide", enabled and true or OldSlide)
end

------------------------------------------------------
-- VISUAL — Fullbright / NoFog / Brightness
------------------------------------------------------

local function saveLighting()
    if LightingBackup then return end
    LightingBackup = {
        Ambient              = Lighting.Ambient,
        OutdoorAmbient       = Lighting.OutdoorAmbient,
        Brightness           = Lighting.Brightness,
        ClockTime            = Lighting.ClockTime,
        FogStart             = Lighting.FogStart,
        FogEnd               = Lighting.FogEnd,
        ExposureCompensation = Lighting.ExposureCompensation,
        ColorShift_Bottom    = Lighting.ColorShift_Bottom,
        ColorShift_Top       = Lighting.ColorShift_Top,
    }
    table.clear(AtmosphereBackup)
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then
            AtmosphereBackup[obj] = { Density = obj.Density, Haze = obj.Haze, Glare = obj.Glare }
        end
    end
end

local function restoreLighting()
    if not LightingBackup then return end
    if FullBrightEnabled or NoFogEnabled then return end
    pcall(function()
        Lighting.Ambient              = LightingBackup.Ambient
        Lighting.OutdoorAmbient       = LightingBackup.OutdoorAmbient
        Lighting.Brightness           = LightingBackup.Brightness
        Lighting.ClockTime            = LightingBackup.ClockTime
        Lighting.FogStart             = LightingBackup.FogStart
        Lighting.FogEnd               = LightingBackup.FogEnd
        Lighting.ExposureCompensation = LightingBackup.ExposureCompensation
        Lighting.ColorShift_Bottom    = LightingBackup.ColorShift_Bottom
        Lighting.ColorShift_Top       = LightingBackup.ColorShift_Top
    end)
    for obj, vals in pairs(AtmosphereBackup) do
        if obj and obj.Parent then
            pcall(function()
                obj.Density = vals.Density
                obj.Haze    = vals.Haze
                obj.Glare   = vals.Glare
            end)
        end
    end
    LightingBackup = nil
    table.clear(AtmosphereBackup)
end

-- brightness slider maps 25–100 → Lighting.Brightness 1–5
local function getBrightness()
    local v = getSliderValue(Elements.Brightness, 35)
    return (v / 100) * 5
end

local function applyFullBright()
    if not FullBrightEnabled then return end
    saveLighting()
    Lighting.Ambient              = Color3.new(1, 1, 1)
    Lighting.OutdoorAmbient       = Color3.new(1, 1, 1)
    Lighting.Brightness           = getBrightness()   -- ← slider-driven
    Lighting.ClockTime            = 14
    Lighting.ExposureCompensation = 0
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then
            obj.Density = 0
            obj.Haze    = 0
            obj.Glare   = 0
        end
    end
end

local function applyNoFog()
    if not NoFogEnabled then return end
    saveLighting()
    Lighting.FogStart = 0
    Lighting.FogEnd   = 1e6
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then
            obj.Density = 0
            obj.Haze    = 0
            obj.Glare   = 0
        end
    end
end

------------------------------------------------------
-- INSTANT INTERACT
------------------------------------------------------

local function applyPrompt(p)
    if not p:IsA("ProximityPrompt") then return end
    if ModifiedPrompts[p] == nil then ModifiedPrompts[p] = p.HoldDuration end
    p.HoldDuration = 0
end

local function enableInstantInteract()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then applyPrompt(obj) end
    end
end

local function disableInstantInteract()
    for p, dur in pairs(ModifiedPrompts) do
        if p and p.Parent then pcall(function() p.HoldDuration = dur end) end
    end
    table.clear(ModifiedPrompts)
end

------------------------------------------------------
-- UI
------------------------------------------------------

local function createUI()
    Tab = Core:Tab({ Name = "Main", Icon = "user", Type = "Grid" })
    if not Tab then return false end

    --------------------------------------------------
    -- Column 1 — Character
    --------------------------------------------------
    local characterSection = Tab:Section({ Title = "Character", Column = 1, Icon = "user" })

    -- Speed Boost
    Elements.SpeedBoost = characterSection:Slider({
        Name = "Speed Boost", Min = 0, Max = 100, Default = 0,
        Flag = "Main_SpeedBoost", TextMode = "Smart",
        Callback = function()
            if speedEnabled() then applySpeed() end
            fireCrouchRemote()
        end,
    })

    Elements.SpeedBoostToggle = characterSection:Toggle({
        Name = "Enable Speed Boost", Default = false,
        Flag = "Main_SpeedBoostToggle", TextMode = "Smart",
        Callback = function() applySpeed(); fireCrouchRemote() end,
    })

    -- Remove Acceleration
    Elements.RemoveAcceleration = characterSection:Toggle({
        Name = "Remove Acceleration", Default = false,
        Flag = "Main_RemoveAcceleration", TextMode = "Smart",
        Callback = function(v)
            if not CustomPhysics then
                buildCustomPhysics()
                snapshotPartProperties()
            end
            applyRemoveAcceleration(v)
        end,
    })

    -- Fly (moved from Movement)
    Elements.Fly = characterSection:Toggle({
        Name = "Fly", Default = false,
        Flag = "Main_Fly", TextMode = "Smart",
        Callback = function(v)
            if v then enableFly() else disableFly() end
        end,
    })

    Elements.FlySpeed = characterSection:Slider({
        Name = "Fly Speed", Min = 0, Max = 115, Default = 20,
        Flag = "Main_FlySpeed", TextMode = "Smart",
    })

    -- Jump / Slide
    Elements.EnableJump = characterSection:Toggle({
        Name = "Enable Jumping", Default = false,
        Flag = "Main_EnableJump", TextMode = "Smart",
        Callback = function(v) applyJump(v) end,
    })

    Elements.InfiniteJump = characterSection:Toggle({
        Name = "Infinite Jump", Default = false,
        Flag = "Main_InfiniteJump", TextMode = "Smart",
    })

    Elements.EnableSlide = characterSection:Toggle({
        Name = "Enable Sliding", Default = false,
        Flag = "Main_EnableSlide", TextMode = "Smart",
        Callback = function(v) applySlide(v) end,
    })

    --------------------------------------------------
    -- Column 2 — Visual
    --------------------------------------------------
    local visualSection = Tab:Section({ Title = "Visual", Column = 2, Icon = "eye" })

    Elements.FullBright = visualSection:Toggle({
        Name = "Fullbright", Default = false,
        Flag = "Main_FullBright", TextMode = "Smart",
        Callback = function(v)
            FullBrightEnabled = v == true
            if FullBrightEnabled then
                applyFullBright()
            else
                if not NoFogEnabled then restoreLighting() end
            end
        end,
    })

    Elements.NoFog = visualSection:Toggle({
        Name = "No Fog", Default = false,
        Flag = "Main_NoFog", TextMode = "Smart",
        Callback = function(v)
            NoFogEnabled = v == true
            if NoFogEnabled then
                applyNoFog()
            else
                if not FullBrightEnabled then restoreLighting() end
            end
        end,
    })

    -- Brightness slider — drives Lighting.Brightness while Fullbright is on
    Elements.Brightness = visualSection:Slider({
        Name = "Brightness", Min = 25, Max = 100, Default = 35,
        Flag = "Main_Brightness", TextMode = "Smart",
        Callback = function()
            -- Only re-apply if Fullbright is active; otherwise it's a no-op
            if FullBrightEnabled then
                Lighting.Brightness = getBrightness()
            end
        end,
    })

    --------------------------------------------------
    -- Column 3 — Misc  (separate column, not under Character)
    --------------------------------------------------
    local miscSection = Tab:Section({ Title = "Misc", Column = 3, Icon = "settings-2" })

    Elements.InstantInteract = miscSection:Toggle({
        Name = "Instant Interact", Default = false,
        Flag = "Main_InstantInteract", TextMode = "Smart",
        Callback = function(v)
            if v then enableInstantInteract() else disableInstantInteract() end
        end,
    })

    return true
end

------------------------------------------------------
-- CONNECTIONS
------------------------------------------------------

local CrouchFireThrottle = 0

local function setupConnections()
    getCharacter()
    if not Character then return end

    OldJump  = Character:GetAttribute("CanJump")  or false
    OldSlide = Character:GetAttribute("CanSlide") or false

    -- Build physics snapshot for RemoveAcceleration
    task.defer(function()
        buildCustomPhysics()
        snapshotPartProperties()
        setupFlyBody()
    end)

    connect(Player.CharacterAdded, function(char)
        Character = char
        Humanoid  = char:WaitForChild("Humanoid",         10)
        RootPart  = char:WaitForChild("HumanoidRootPart", 10)

        OldJump  = char:GetAttribute("CanJump")  or false
        OldSlide = char:GetAttribute("CanSlide") or false

        -- Restore overrides
        if getToggleValue(Elements.EnableJump)  then applyJump(true)  end
        if getToggleValue(Elements.EnableSlide) then applySlide(true) end

        -- Re-build fly body (new RootPart)
        task.defer(function()
            buildCustomPhysics()
            snapshotPartProperties()
            setupFlyBody()

            if FlyEnabled then enableFly() end
            if getToggleValue(Elements.RemoveAcceleration) then
                applyRemoveAcceleration(true)
            end
            if speedEnabled() then applySpeed() end
        end)
    end)

    -- Infinite Jump
    connect(UserInputService.JumpRequest, function()
        if not getToggleValue(Elements.InfiniteJump) then return end
        if not Humanoid or Humanoid.Health <= 0 then return end
        pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
    end)

    -- New prompts
    connect(workspace.DescendantAdded, function(obj)
        if obj:IsA("ProximityPrompt") and getToggleValue(Elements.InstantInteract) then
            task.defer(function()
                if obj.Parent then applyPrompt(obj) end
            end)
        end
    end)

    -- New Atmosphere
    connect(Lighting.ChildAdded, function(obj)
        if not (FullBrightEnabled or NoFogEnabled) then return end
        if obj:IsA("Atmosphere") then
            task.defer(function()
                obj.Density = 0
                obj.Haze    = 0
                obj.Glare   = 0
            end)
        end
    end)

    -- Heartbeat — speed + fly + crouch remote
    connect(RunService.Heartbeat, function()
        if not Character or not Character.Parent then return end
        if not Humanoid  or not Humanoid.Parent  then return end

        -- Speed
        if speedEnabled() then
            applySpeed()
            -- Crouch remote spam at 10 Hz (Abyssal parity)
            local now = tick()
            if now - CrouchFireThrottle > 0.1 then
                CrouchFireThrottle = now
                fireCrouchRemote()
            end
        end

        -- Fly (Abyssal: parent on/off per frame)
        if FlyEnabled then
            tickFly()
        elseif FlyBody and FlyBody.Parent then
            FlyBody.Parent = nil
        end
    end)

    -- RenderStepped — lighting enforced every frame
    connect(RunService.RenderStepped, function()
        if FullBrightEnabled then applyFullBright() end
        if NoFogEnabled       then applyNoFog()      end
    end)
end

------------------------------------------------------
-- LIFECYCLE
------------------------------------------------------

function Main:Init(core)
    if self.Initialized then return self end

    if type(core) ~= "table" then
        warn("[JustXDoors Main] Core is missing.")
        return self
    end

    Core = core

    if not createUI() then
        warn("[JustXDoors Main] Failed to create UI.")
        return self
    end

    setupConnections()
    self.Initialized = true

    Core:Notify({
        Title    = "Main",
        Desc     = "Main module loaded.",
        Type     = "Success",
        Duration = 3,
    })

    return self
end

function Main:Destroy()
    disableFly()
    disableInstantInteract()
    applyRemoveAcceleration(false)

    FullBrightEnabled = false
    NoFogEnabled      = false
    restoreLighting()

    disconnectAll()

    if Character then
        applyJump(false)
        applySlide(false)
    end

    Elements         = {}
    PartProperties   = {}
    ModifiedPrompts  = {}
    Tab              = nil
    Core             = nil
    self.Initialized = false
end

return Main
