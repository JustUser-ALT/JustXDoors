--[[
    JustXDoors — Game/Main/Main.lua
    Layout: Column 1 = Character, Column 2 = Visual, Column 3 = Misc
]]

local Main = {}

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")

local Player = Players.LocalPlayer

local Core
local Tab
local Connections = {}
local Elements    = {}

------------------------------------------------------
-- CHARACTER
------------------------------------------------------

local Character, Humanoid, RootPart
local OldJump  = false
local OldSlide = false

------------------------------------------------------
-- FLY
------------------------------------------------------

local FlyBody    = nil
local FlyEnabled = false

------------------------------------------------------
-- REMOVE ACCELERATION
------------------------------------------------------

local PartProperties = {}
local CustomPhysics  = nil

------------------------------------------------------
-- VISUAL
------------------------------------------------------

local FullBrightEnabled = false
local NoFogEnabled      = false
local LightingBackup    = nil
local AtmosphereBackup  = {}

-- Live values read from sliders (set in Callback, never via :Get())
local CurrentFlySpeed    = 20
local CurrentSpeedBoost  = 0
local CurrentBrightness  = 35  -- raw slider value 25-100

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

local SpeedBoostEnabled = false

local function applySpeed()
    if not Humanoid or not Humanoid.Parent then return end
    local speed = getCurrentSpeed()
    if SpeedBoostEnabled then speed = speed + CurrentSpeedBoost end
    Humanoid.WalkSpeed = math.max(speed, 0)
end

local CrouchThrottle = 0
local function fireCrouchRemote()
    local now = tick()
    if now - CrouchThrottle < 0.1 then return end
    CrouchThrottle = now
    local rf = ReplicatedStorage:FindFirstChild("RemotesFolder")
    if not rf then return end
    local cr = rf:FindFirstChild("Crouch")
    if not cr or not cr:IsA("RemoteEvent") then return end
    pcall(function() cr:FireServer(isCrouching(), true) end)
end

------------------------------------------------------
-- REMOVE ACCELERATION
------------------------------------------------------

local function buildCustomPhysics()
    if not RootPart then return end
    local p = RootPart.CustomPhysicalProperties
    CustomPhysics = PhysicalProperties.new(100, p.Friction, p.Elasticity, p.FrictionWeight, p.ElasticityWeight)
end

local function snapshotPartProperties()
    PartProperties = {}
    if not Character then return end
    for _, part in Character:GetDescendants() do
        if part:IsA("BasePart") then PartProperties[part] = part.CustomPhysicalProperties end
    end
end

local RemoveAccelEnabled = false

local function applyRemoveAcceleration()
    if not CustomPhysics then return end
    for part, original in pairs(PartProperties) do
        pcall(function()
            part.CustomPhysicalProperties = RemoveAccelEnabled and CustomPhysics or original
        end)
    end
end

------------------------------------------------------
-- FLY — Abyssal style (no PlatformStand, no BodyGyro)
------------------------------------------------------

local function setupFlyBody()
    if FlyBody then pcall(function() FlyBody:Destroy() end) end
    FlyBody = Instance.new("BodyVelocity")
    FlyBody.Name     = "JustXDoorsFly"
    FlyBody.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    FlyBody.Velocity  = Vector3.zero
end

local function getFlyVelocity()
    local cam = workspace.CurrentCamera
    if not cam or not Humanoid then return Vector3.zero end
    if Humanoid.MoveDirection == Vector3.zero then return Vector3.zero end
    local look  = cam.CFrame.LookVector
    local flat  = Vector3.new(look.X, 0, look.Z)
    local frame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + flat)
    local vel   = (cam.CFrame * CFrame.new(frame:VectorToObjectSpace(Humanoid.MoveDirection))).Position
                  - cam.CFrame.Position
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
        FlyBody.Parent = nil
        pcall(function() FlyBody:Destroy() end)
        FlyBody = nil
    end
    if Humanoid then
        pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
    end
end

local function tickFly()
    if not FlyEnabled or not FlyBody or not RootPart then return end
    local vertical = 0
    if UserInputService:IsKeyDown(Enum.KeyCode.Space)
        or Humanoid:GetState() == Enum.HumanoidStateType.Jumping
    then
        vertical = CurrentFlySpeed
    elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.C)
    then
        vertical = -CurrentFlySpeed
    end
    FlyBody.Parent   = RootPart
    FlyBody.Velocity = getFlyVelocity() * CurrentFlySpeed + Vector3.new(0, vertical, 0)
end

------------------------------------------------------
-- JUMP / SLIDE
------------------------------------------------------

local InfiniteJumpEnabled = false

local function applyJump(enabled)
    if not Character then return end
    Character:SetAttribute("CanJump", enabled and true or OldJump)
end

local function applySlide(enabled)
    if not Character then return end
    Character:SetAttribute("CanSlide", enabled and true or OldSlide)
end

------------------------------------------------------
-- VISUAL
------------------------------------------------------

local function saveLighting()
    if LightingBackup then return end
    LightingBackup = {
        Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
        FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd,
        ExposureCompensation = Lighting.ExposureCompensation,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
        ColorShift_Top    = Lighting.ColorShift_Top,
    }
    table.clear(AtmosphereBackup)
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then
            AtmosphereBackup[obj] = { Density=obj.Density, Haze=obj.Haze, Glare=obj.Glare }
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
            pcall(function() obj.Density=vals.Density; obj.Haze=vals.Haze; obj.Glare=vals.Glare end)
        end
    end
    LightingBackup = nil
    table.clear(AtmosphereBackup)
end

-- Maps slider 25-100 → Lighting.Brightness 1.25-5
local function sliderToBrightness(v)
    return (v / 100) * 5
end

local function applyFullBright()
    if not FullBrightEnabled then return end
    saveLighting()
    Lighting.Ambient              = Color3.new(1, 1, 1)
    Lighting.OutdoorAmbient       = Color3.new(1, 1, 1)
    Lighting.Brightness           = sliderToBrightness(CurrentBrightness)
    Lighting.ClockTime            = 14
    Lighting.ExposureCompensation = 0
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then
            obj.Density = 0; obj.Haze = 0; obj.Glare = 0
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
            obj.Density = 0; obj.Haze = 0; obj.Glare = 0
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
    local char = Tab:Section({ Title = "Character", Column = 1, Icon = "user" })

    -- Speed Boost slider at top
    Elements.SpeedBoost = char:Slider({
        Name = "Speed Boost", Flag = "Main_SpeedBoost",
        Min = 0, Max = 100, Step = 1, Default = 0,
        Callback = function(v)
            CurrentSpeedBoost = v
            if SpeedBoostEnabled then applySpeed() end
            fireCrouchRemote()
        end,
    })

    -- Fly Speed slider second (both sliders at top)
    Elements.FlySpeed = char:Slider({
        Name = "Fly Speed", Flag = "Main_FlySpeed",
        Min = 0, Max = 115, Step = 1, Default = 20,
        Callback = function(v)
            CurrentFlySpeed = v
        end,
    })

    -- Speed Boost toggle
    Elements.SpeedBoostToggle = char:Toggle({
        Name = "Enable Speed Boost", Flag = "Main_SpeedBoostToggle", Default = false,
        Callback = function(v)
            SpeedBoostEnabled = v
            applySpeed()
            fireCrouchRemote()
        end,
    })

    -- Remove Acceleration
    Elements.RemoveAcceleration = char:Toggle({
        Name = "Remove Acceleration", Flag = "Main_RemoveAcceleration", Default = false,
        Callback = function(v)
            RemoveAccelEnabled = v
            if not CustomPhysics then buildCustomPhysics(); snapshotPartProperties() end
            applyRemoveAcceleration()
        end,
    })

    -- Fly toggle
    Elements.Fly = char:Toggle({
        Name = "Fly", Flag = "Main_Fly", Default = false,
        Callback = function(v)
            if v then enableFly() else disableFly() end
        end,
    })

    -- Divider between Fly and jump/slide group
    char:Divider()

    Elements.EnableJump = char:Toggle({
        Name = "Enable Jumping", Flag = "Main_EnableJump", Default = false,
        Callback = function(v) applyJump(v) end,
    })

    Elements.InfiniteJump = char:Toggle({
        Name = "Infinite Jump", Flag = "Main_InfiniteJump", Default = false,
        Callback = function(v) InfiniteJumpEnabled = v end,
    })

    Elements.EnableSlide = char:Toggle({
        Name = "Enable Sliding", Flag = "Main_EnableSlide", Default = false,
        Callback = function(v) applySlide(v) end,
    })

    --------------------------------------------------
    -- Column 2 — Visual
    --------------------------------------------------
    local vis = Tab:Section({ Title = "Visual", Column = 2, Icon = "eye" })

    Elements.FullBright = vis:Toggle({
        Name = "Fullbright", Flag = "Main_FullBright", Default = false,
        Callback = function(v)
            FullBrightEnabled = v
            if v then applyFullBright() else if not NoFogEnabled then restoreLighting() end end
        end,
    })

    Elements.NoFog = vis:Toggle({
        Name = "No Fog", Flag = "Main_NoFog", Default = false,
        Callback = function(v)
            NoFogEnabled = v
            if v then applyNoFog() else if not FullBrightEnabled then restoreLighting() end end
        end,
    })

    -- Brightness: callback receives v directly — fixes the slider not updating Fullbright
    Elements.Brightness = vis:Slider({
        Name = "Brightness", Flag = "Main_Brightness",
        Min = 25, Max = 100, Step = 1, Default = 35,
        Callback = function(v)
            CurrentBrightness = v
            -- Immediately update Lighting.Brightness if Fullbright is on
            if FullBrightEnabled then
                Lighting.Brightness = sliderToBrightness(v)
            end
        end,
    })

    --------------------------------------------------
    -- Column 3 — Misc
    --------------------------------------------------
    local misc = Tab:Section({ Title = "Misc", Column = 3, Icon = "settings-2" })

    Elements.InstantInteract = misc:Toggle({
        Name = "Instant Interact", Flag = "Main_InstantInteract", Default = false,
        Callback = function(v)
            if v then enableInstantInteract() else disableInstantInteract() end
        end,
    })

    return true
end

------------------------------------------------------
-- CONNECTIONS
------------------------------------------------------

local function setupConnections()
    getCharacter()
    if not Character then return end

    OldJump  = Character:GetAttribute("CanJump")  or false
    OldSlide = Character:GetAttribute("CanSlide") or false

    task.defer(function()
        buildCustomPhysics()
        snapshotPartProperties()
        setupFlyBody()
    end)

    connect(Player.CharacterAdded, function(char)
        Character = char
        Humanoid  = char:WaitForChild("Humanoid",         10)
        RootPart  = char:WaitForChild("HumanoidRootPart", 10)
        OldJump   = char:GetAttribute("CanJump")  or false
        OldSlide  = char:GetAttribute("CanSlide") or false

        if Elements.EnableJump  and Elements.EnableJump:Get()  then applyJump(true)  end
        if Elements.EnableSlide and Elements.EnableSlide:Get() then applySlide(true) end

        task.defer(function()
            buildCustomPhysics()
            snapshotPartProperties()
            setupFlyBody()
            if FlyEnabled        then enableFly()             end
            if RemoveAccelEnabled then applyRemoveAcceleration() end
            if SpeedBoostEnabled  then applySpeed()           end
        end)
    end)

    -- Infinite Jump — uses JumpRequest (fired by both keyboard and mobile jump button)
    connect(UserInputService.JumpRequest, function()
        if not InfiniteJumpEnabled then return end
        if not Humanoid or Humanoid.Health <= 0 then return end
        -- Small delay so the base jump fires first, then immediately jump again
        task.defer(function()
            if Humanoid and InfiniteJumpEnabled then
                pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
            end
        end)
    end)

    connect(workspace.DescendantAdded, function(obj)
        if obj:IsA("ProximityPrompt") and Elements.InstantInteract and Elements.InstantInteract:Get() then
            task.defer(function()
                if obj.Parent then applyPrompt(obj) end
            end)
        end
    end)

    connect(Lighting.ChildAdded, function(obj)
        if obj:IsA("Atmosphere") and (FullBrightEnabled or NoFogEnabled) then
            task.defer(function() obj.Density=0; obj.Haze=0; obj.Glare=0 end)
        end
    end)

    connect(RunService.Heartbeat, function()
        if not Character or not Character.Parent then return end
        if not Humanoid  or not Humanoid.Parent  then return end

        if SpeedBoostEnabled then applySpeed(); fireCrouchRemote() end

        if FlyEnabled then
            tickFly()
        elseif FlyBody and FlyBody.Parent then
            FlyBody.Parent = nil
        end
    end)

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
    if type(core) ~= "table" then warn("[JustXDoors Main] Core is missing."); return self end
    Core = core
    if not createUI() then warn("[JustXDoors Main] Failed to create UI."); return self end
    setupConnections()
    self.Initialized = true
    Core:Notify({ Title="Main", Desc="Main module loaded.", Type="Success", Duration=3 })
    return self
end

function Main:Destroy()
    disableFly()
    disableInstantInteract()
    RemoveAccelEnabled = false
    applyRemoveAcceleration()
    FullBrightEnabled = false
    NoFogEnabled      = false
    restoreLighting()
    disconnectAll()
    if Character then applyJump(false); applySlide(false) end
    Elements = {}; PartProperties = {}; ModifiedPrompts = {}
    Tab  = nil; Core = nil
    self.Initialized = false
end

return Main
