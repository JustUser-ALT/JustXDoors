--[[
    JustXDoors
    Game/Main/Main.lua

    Character tab — Speed, Acceleration, Fly, Jump/Slide, Noclip, Idle Kick
    Ported from Abyssal Hub / Abyssal Hub Continued.

    Lifecycle (called by Loader):
        Main:Init(Core)   — grab core refs, resolve character / game data
        Main:Build()      — build UI into Core.Main.Tabs.Main, wire connections
        Main:Destroy()    — clean up connections + state
]]

local Main = {}

------------------------------------------------------
-- CORE REFS
------------------------------------------------------

local Core
local Services
local Connections
local Settings
local Notifications
local UI

------------------------------------------------------
-- STATE
------------------------------------------------------

local Initialized = false
local Built       = false
local Connected   = false

local Tab

local Groups   = {}
local Elements = {}

------------------------------------------------------
-- CHARACTER
------------------------------------------------------

local Character
local Humanoid
local RootPart
local Camera

local LiveModifiers
local GameData

-- Fly BodyVelocity (created fresh each character spawn)
local FlyBody

-- Per-character original physics properties (RemoveAcceleration)
local PartProperties = {}
local CustomPhysics  = nil

-- Original jump / slide flags (restored on toggle off)
local OldJump  = false
local OldSlide = false

-- Crouch remote spam throttle
local LastCrouchFire = 0

-- RemotesFolder
local RemotesFolder

------------------------------------------------------
-- HELPERS — character
------------------------------------------------------

local function getCharacter()
    if not Services or not Services.LocalPlayer then return nil end
    return Services.LocalPlayer.Character
end

local function getHumanoid(c)
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(c)
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function refreshCharacter()
    Character = getCharacter()
    if not Character then
        Humanoid = nil
        RootPart = nil
        return false
    end
    Humanoid = getHumanoid(Character)
    RootPart = getRootPart(Character)
    return Humanoid ~= nil and RootPart ~= nil
end

------------------------------------------------------
-- HELPERS — world
------------------------------------------------------

local function getCamera()
    return Services and Services.Workspace and Services.Workspace.CurrentCamera
end

local function getFloor()
    if not GameData then return nil end
    local v = GameData:FindFirstChild("Floor")
    return v and v.Value
end

------------------------------------------------------
-- CROUCH STATE
------------------------------------------------------

local function isCrouching()
    if not Character then return false end
    local floor = getFloor()
    if floor == "Fools" or floor == "OldHotel" then
        return Character:GetAttribute("Crouching") == true
    end
    local cp = Character:FindFirstChild("CollisionPart")
    if cp and cp:IsA("BasePart") then
        local ok, g = pcall(function() return cp.CollisionGroup end)
        if ok then return g == "PlayerCrouching" end
    end
    return Character:GetAttribute("Crouching") == true
end

------------------------------------------------------
-- SPEED — calculation (mirrors Abyssal exactly)
------------------------------------------------------

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
    if LiveModifiers then
        if LiveModifiers:FindFirstChild("PlayerFast")        then s += 3  end
        if LiveModifiers:FindFirstChild("PlayerFaster")      then s += 6  end
        if LiveModifiers:FindFirstChild("PlayerFastest")     then s += 20 end
        if LiveModifiers:FindFirstChild("PlayerSlow")        then s -= 3  end
        if LiveModifiers:FindFirstChild("PlayerSlowHealth")  then s -= getInjuriesSpeed() end
    end
    if isCrouching() then
        if LiveModifiers and LiveModifiers:FindFirstChild("PlayerCrouchSlow") then s -= 8
        elseif LiveModifiers and LiveModifiers:FindFirstChild("PlayerSlow")   then s -= 8
        else s -= 5 end
    end
    return s
end

local function getSpeedBoost()
    local el = Elements.SpeedBoost
    if not el then return 0 end
    return type(el.Value) == "number" and el.Value or 0
end

local function isSpeedBoostEnabled()
    local el = Elements.SpeedBoostToggle
    return el and el.Value == true
end

local function applySpeed()
    if not Humanoid or not Humanoid.Parent then return end
    local final = math.max(getCurrentSpeed() + (isSpeedBoostEnabled() and getSpeedBoost() or 0), 0)
    if Humanoid.WalkSpeed ~= final then
        Humanoid.WalkSpeed = final
    end
end

------------------------------------------------------
-- CROUCH REMOTE SPAM (Abyssal parity — 10 Hz)
------------------------------------------------------

local function fireCrouchRemote()
    if not RemotesFolder then return end
    local remote = RemotesFolder:FindFirstChild("Crouch")
    if not remote then return end
    local now = tick()
    if now - LastCrouchFire <= 0.1 then return end
    LastCrouchFire = now
    pcall(function() remote:FireServer(isCrouching(), true) end)
end

------------------------------------------------------
-- REMOVE ACCELERATION
-- Sets Density=100 on all BaseParts so the character
-- stops sliding. Restores original properties on toggle off.
-- Rebuilt every CharacterAdded (same as Abyssal).
------------------------------------------------------

local function buildCustomPhysics()
    if not RootPart then return end
    CustomPhysics = PhysicalProperties.new(
        100,
        RootPart.CustomPhysicalProperties.Friction,
        RootPart.CustomPhysicalProperties.Elasticity,
        RootPart.CustomPhysicalProperties.FrictionWeight,
        RootPart.CustomPhysicalProperties.ElasticityWeight
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

local function applyAcceleration(enabled)
    for part, original in PartProperties do
        pcall(function()
            part.CustomPhysicalProperties = enabled and CustomPhysics or original
        end)
    end
end

------------------------------------------------------
-- FLY
-- BodyVelocity parented to RootPart when active.
-- Direction from camera look vector (Abyssal method).
------------------------------------------------------

local function getFlyVelocity()
    Camera = getCamera()
    if not Camera or not Humanoid then return Vector3.zero end
    if Humanoid.MoveDirection == Vector3.zero then return Vector3.zero end
    local look   = Camera.CFrame.LookVector
    local flat   = Vector3.new(look.X, 0, look.Z)
    local frame  = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + flat)
    local vel    = (Camera.CFrame * CFrame.new(frame:VectorToObjectSpace(Humanoid.MoveDirection))).Position
                   - Camera.CFrame.Position
    if vel == Vector3.zero then return vel end
    return vel.Unit
end

local function setupFlyBody()
    if FlyBody then pcall(function() FlyBody:Destroy() end) end
    FlyBody = Instance.new("BodyVelocity")
    FlyBody.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    FlyBody.Velocity  = Vector3.zero
end

local function isFlyEnabled()
    local el = Elements.FlyToggle
    return el and el.Value == true
end

local function getFlySpeed()
    local el = Elements.FlySpeed
    if not el then return 20 end
    return type(el.Value) == "number" and el.Value or 20
end

------------------------------------------------------
-- NOCLIP
------------------------------------------------------

local function applyNoclip()
    if not RootPart then return end
    local noClip = Elements.NoclipToggle and Elements.NoclipToggle.Value == true
    pcall(function()
        RootPart.CanCollide = not noClip
    end)
    -- CollisionPart (the game's actual hitbox)
    if Character then
        local cp = Character:FindFirstChild("CollisionPart")
        if cp and cp:IsA("BasePart") then
            pcall(function() cp.CanCollide = not noClip end)
        end
    end
end

------------------------------------------------------
-- JUMP / SLIDE ATTRIBUTES
------------------------------------------------------

local function applyJump(value)
    if not Character then return end
    Character:SetAttribute("CanJump", value and true or OldJump)
end

local function applySlide(value)
    if not Character then return end
    Character:SetAttribute("CanSlide", value and true or OldSlide)
end

------------------------------------------------------
-- IDLE KICK BYPASS
-- Primary: disable all connections on LocalPlayer.Idled
-- Fallback: VirtualUser heartbeat click (always fires
-- regardless of getconnections availability)
------------------------------------------------------

local function applyIdleKick(enabled)
    local lp = Services and Services.LocalPlayer
    if not lp then return end

    -- Method 1: getconnections (executor-level)
    pcall(function()
        if type(getconnections) == "function" then
            for _, conn in getconnections(lp.Idled) do
                if enabled then conn:Disable() else conn:Enable() end
            end
        end
    end)
end

------------------------------------------------------
-- CHARACTER ADDED
------------------------------------------------------

local function onCharacterAdded(character)
    Character  = character
    Humanoid   = character:WaitForChild("Humanoid",         10)
    RootPart   = character:WaitForChild("HumanoidRootPart", 10)

    -- Snapshot original jump / slide
    OldJump  = character:GetAttribute("CanJump")  or false
    OldSlide = character:GetAttribute("CanSlide") or false

    -- Re-apply jump / slide overrides immediately if toggles are on
    if Elements.EnableCharacterJump  and Elements.EnableCharacterJump.Value  then applyJump(true)  end
    if Elements.EnableCharacterSlide and Elements.EnableCharacterSlide.Value then applySlide(true) end

    -- Physics snapshot for RemoveAcceleration
    task.defer(function()
        if not Character or Character ~= character then return end
        refreshCharacter()
        buildCustomPhysics()
        snapshotPartProperties()
        if Elements.RemoveAcceleration and Elements.RemoveAcceleration.Value then
            applyAcceleration(true)
        end
        -- Fly body
        setupFlyBody()
        -- Initial speed
        if Humanoid then applySpeed() end
    end)
end

------------------------------------------------------
-- BUILD UI — all of the Character group
------------------------------------------------------

local function buildCharacter()
    if not Tab then return false end

    local group = UI:AddLeftGroupbox(Tab, "Character", "user")
    if not group then return false end
    Groups.Character = group

    --------------------------------------------------
    -- Speed Boost Slider + Toggle
    --------------------------------------------------

    Elements.SpeedBoost = UI:AddSlider(group, "SpeedBoost", {
        Text     = "Speed Boost",
        Min      = 0, Max = 100, Default = 0,
        Rounding = 0, Compact = true,
    })

    Elements.SpeedBoostToggle = UI:AddToggle(group, "SpeedBoostToggle", {
        Text    = "Enable Speed Boost",
        Default = false,
        Tooltip = "Adds the selected amount to the current game movement speed.",
    })

    --------------------------------------------------
    -- Remove Acceleration (right after Speed Toggle)
    --------------------------------------------------

    Elements.RemoveAcceleration = UI:AddToggle(group, "RemoveAcceleration", {
        Text    = "Remove Acceleration",
        Default = false,
        Tooltip = "Prevents the character from sliding while moving.",
    })

    --------------------------------------------------
    -- Fly Toggle + Fly Speed Slider
    --------------------------------------------------

    Elements.FlyToggle = UI:AddToggle(group, "FlyToggle", {
        Text    = "Fly",
        Default = false,
        Tooltip = "Allows you to freely fly around the map.",
    })

    Elements.FlySpeed = UI:AddSlider(group, "FlySpeed", {
        Text     = "Fly Speed",
        Min      = 0, Max = 115, Default = 20,
        Rounding = 0, Compact = true,
    })

    --------------------------------------------------
    -- Divider
    --------------------------------------------------

    UI:AddDivider(group)

    --------------------------------------------------
    -- Enable Jumping + Infinite Jumps + Enable Sliding
    --------------------------------------------------

    Elements.EnableCharacterJump = UI:AddToggle(group, "EnableCharacterJump", {
        Text    = "Enable Jumping",
        Default = false,
        Tooltip = "Allows your character to jump.",
    })

    Elements.InfiniteJumps = UI:AddToggle(group, "InfiniteJumps", {
        Text    = "Infinite Jumps",
        Default = false,
        Tooltip = "Allows you to jump while in the air.",
    })

    Elements.EnableCharacterSlide = UI:AddToggle(group, "EnableCharacterSlide", {
        Text    = "Enable Sliding",
        Default = false,
        Tooltip = "Allows your character to slide.",
    })

    --------------------------------------------------
    -- Divider
    --------------------------------------------------

    UI:AddDivider(group)

    --------------------------------------------------
    -- Noclip + Disable Idle Kick
    --------------------------------------------------

    Elements.NoclipToggle = UI:AddToggle(group, "NoclipToggle", {
        Text    = "Noclip",
        Default = false,
        Tooltip = "Allows your character to pass through solid objects.",
    })

    Elements.DisableIdleKick = UI:AddToggle(group, "DisableIdleKick", {
        Text    = "Disable Idle Kick",
        Default = false,
        Tooltip = "Prevents the kick from being idle for 20 minutes.",
    })

    return true
end

------------------------------------------------------
-- CONNECTIONS
------------------------------------------------------

function Main:Connect()
    if Connected then return end
    if not Connections or not Services then return end
    Connected = true

    local LocalPlayer = Services.LocalPlayer

    --------------------------------------------------
    -- CharacterAdded
    --------------------------------------------------

    if LocalPlayer then
        Connections:Connect(
            LocalPlayer.CharacterAdded,
            onCharacterAdded,
            "GameMain"
        )
    end

    --------------------------------------------------
    -- Speed Slider / Toggle — OnChanged
    --------------------------------------------------

    if Elements.SpeedBoost and type(Elements.SpeedBoost.OnChanged) == "function" then
        Elements.SpeedBoost:OnChanged(function()
            if isSpeedBoostEnabled() then applySpeed() end
            fireCrouchRemote()
        end)
    end

    if Elements.SpeedBoostToggle and type(Elements.SpeedBoostToggle.OnChanged) == "function" then
        Elements.SpeedBoostToggle:OnChanged(function()
            applySpeed()
            fireCrouchRemote()
        end)
    end

    --------------------------------------------------
    -- Remove Acceleration
    --------------------------------------------------

    if Elements.RemoveAcceleration and type(Elements.RemoveAcceleration.OnChanged) == "function" then
        Elements.RemoveAcceleration:OnChanged(function(value)
            applyAcceleration(value)
        end)
    end

    --------------------------------------------------
    -- Fly Toggle (no special OnChanged needed;
    --             the Heartbeat loop handles it)
    --------------------------------------------------

    --------------------------------------------------
    -- Enable Jumping
    --------------------------------------------------

    if Elements.EnableCharacterJump and type(Elements.EnableCharacterJump.OnChanged) == "function" then
        Elements.EnableCharacterJump:OnChanged(function(value)
            applyJump(value)
        end)
    end

    --------------------------------------------------
    -- Enable Sliding
    --------------------------------------------------

    if Elements.EnableCharacterSlide and type(Elements.EnableCharacterSlide.OnChanged) == "function" then
        Elements.EnableCharacterSlide:OnChanged(function(value)
            applySlide(value)
        end)
    end

    --------------------------------------------------
    -- Noclip
    --------------------------------------------------

    if Elements.NoclipToggle and type(Elements.NoclipToggle.OnChanged) == "function" then
        Elements.NoclipToggle:OnChanged(function()
            applyNoclip()
        end)
    end

    --------------------------------------------------
    -- Disable Idle Kick
    --------------------------------------------------

    if Elements.DisableIdleKick and type(Elements.DisableIdleKick.OnChanged) == "function" then
        Elements.DisableIdleKick:OnChanged(function(value)
            applyIdleKick(value)
        end)
    end

    -- VirtualUser fallback — fires regardless of executor support
    if LocalPlayer then
        Connections:Connect(
            LocalPlayer.Idled,
            function()
                if Elements.DisableIdleKick and Elements.DisableIdleKick.Value then
                    pcall(function()
                        Services.VirtualUser:CaptureController()
                        Services.VirtualUser:ClickButton2(Vector2.new())
                    end)
                end
            end,
            "GameMain"
        )
    end

    --------------------------------------------------
    -- Infinite Jumps — keyboard + mobile button
    --------------------------------------------------

    if Elements.InfiniteJumps then
        Connections:Connect(
            Services.UserInputService.InputBegan,
            function(input, processed)
                if processed then return end
                if input.KeyCode == Enum.KeyCode.Space
                    and Elements.InfiniteJumps.Value
                    and Humanoid
                then
                    pcall(function()
                        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    end)
                end
            end,
            "GameMain"
        )

        -- Mobile jump button (optional — safe if missing)
        task.defer(function()
            local lp = Services.LocalPlayer
            if not lp then return end
            local pg = lp:FindFirstChild("PlayerGui")
            if not pg then return end
            local mainUI = pg:FindFirstChild("MainUI")
            if not mainUI then return end
            local btn = mainUI:FindFirstChild("MainFrame")
                and mainUI.MainFrame:FindFirstChild("MobileButtons")
                and mainUI.MainFrame.MobileButtons:FindFirstChild("JumpButton")
            if btn then
                Connections:Connect(
                    btn.MouseButton1Down,
                    function()
                        if Elements.InfiniteJumps and Elements.InfiniteJumps.Value and Humanoid then
                            pcall(function()
                                Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                            end)
                        end
                    end,
                    "GameMain"
                )
            end
        end)
    end

    --------------------------------------------------
    -- CanJump / CanSlide attribute watchers
    -- Keep overrides alive even when the server resets them
    --------------------------------------------------

    task.defer(function()
        if not Character then return end

        Connections:Connect(
            Character:GetAttributeChangedSignal("CanJump"),
            function()
                local val = Character:GetAttribute("CanJump")
                if Elements.EnableCharacterJump and Elements.EnableCharacterJump.Value and val ~= true then
                    OldJump = val
                    Character:SetAttribute("CanJump", true)
                else
                    OldJump = val
                end
            end,
            "GameMain"
        )

        Connections:Connect(
            Character:GetAttributeChangedSignal("CanSlide"),
            function()
                local val = Character:GetAttribute("CanSlide")
                if Elements.EnableCharacterSlide and Elements.EnableCharacterSlide.Value and val ~= true then
                    OldSlide = val
                    Character:SetAttribute("CanSlide", true)
                else
                    OldSlide = val
                end
            end,
            "GameMain"
        )
    end)

    --------------------------------------------------
    -- Heartbeat — master loop
    --------------------------------------------------

    Connections:Connect(
        Services.RunService.Heartbeat,
        function()
            -- Refresh stale refs
            if not Character or not Character.Parent then refreshCharacter() end
            if not Humanoid  or not Humanoid.Parent  then refreshCharacter() end
            if not Humanoid then return end

            -- Speed
            if isSpeedBoostEnabled() then
                applySpeed()
                fireCrouchRemote()
            end

            -- Noclip (enforce every frame, game resets CanCollide)
            if Elements.NoclipToggle and Elements.NoclipToggle.Value then
                applyNoclip()
            end

            -- Fly
            if FlyBody then
                if isFlyEnabled() and RootPart then
                    FlyBody.Parent   = RootPart
                    FlyBody.Velocity = getFlyVelocity() * getFlySpeed()
                else
                    FlyBody.Parent  = nil
                end
            end
        end,
        "GameMain"
    )
end

------------------------------------------------------
-- INIT
------------------------------------------------------

function Main:Init(CoreModules)
    if Initialized then return self end
    if type(CoreModules) ~= "table" then return self end

    Core          = CoreModules
    Services      = Core.Services
    Connections   = Core.Connections
    Settings      = Core.Settings
    Notifications = Core.Notifications
    UI            = Core.UI

    if not Services or not Connections or not UI then
        warn("[JustXDoors GameMain] Core modules missing.")
        return self
    end

    local RS = Services.ReplicatedStorage
    if RS then
        GameData      = RS:FindFirstChild("GameData")
        LiveModifiers = RS:FindFirstChild("LiveModifiers")
        RemotesFolder = RS:WaitForChild("RemotesFolder", 10)
    end

    Camera = getCamera()

    refreshCharacter()

    Initialized = true
    return self
end

------------------------------------------------------
-- BUILD
------------------------------------------------------

function Main:Build()
    if Built then return self end
    if not Initialized then return self end

    if Core and Core.Main and Core.Main.Tabs then
        Tab = Core.Main.Tabs.Main
    end

    if not Tab then
        warn("[JustXDoors GameMain] Core.Main.Tabs.Main is missing.")
        return self
    end

    if not buildCharacter() then
        warn("[JustXDoors GameMain] Failed to build Character section.")
        return self
    end

    self:Connect()

    -- Initial character pass
    task.defer(function()
        refreshCharacter()
        if Humanoid then
            buildCustomPhysics()
            snapshotPartProperties()
            setupFlyBody()
            applySpeed()
        end
    end)

    Built = true
    return self
end

------------------------------------------------------
-- DESTROY
------------------------------------------------------

function Main:Destroy()
    -- Restore attributes before disconnecting
    if Character then
        pcall(function() Character:SetAttribute("CanJump",  OldJump)  end)
        pcall(function() Character:SetAttribute("CanSlide", OldSlide) end)
    end

    -- Remove fly body
    if FlyBody then
        pcall(function() FlyBody:Destroy() end)
        FlyBody = nil
    end

    -- Restore acceleration
    applyAcceleration(false)

    -- Restore noclip
    if RootPart then
        pcall(function() RootPart.CanCollide = true end)
    end

    if Connections then
        Connections:DisconnectGroup("GameMain")
    end

    Groups       = {}
    Elements     = {}
    PartProperties = {}
    CustomPhysics  = nil

    Tab        = nil
    Character  = nil
    Humanoid   = nil
    RootPart   = nil
    Camera     = nil

    LiveModifiers = nil
    GameData      = nil
    RemotesFolder = nil

    OldJump  = false
    OldSlide = false
    LastCrouchFire = 0

    Initialized = false
    Built       = false
    Connected   = false

    Core          = nil
    Services      = nil
    Connections   = nil
    Settings      = nil
    Notifications = nil
    UI            = nil
end

------------------------------------------------------
-- RETURN
------------------------------------------------------

return Main
