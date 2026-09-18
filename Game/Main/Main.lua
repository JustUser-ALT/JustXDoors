--[[
    JustXDoors
    Game/Main/Main.lua

    Character tab — Speed Boost (toggle + slider)
    Remote spam pattern ported from Abyssal Hub / Abyssal Hub Continued.

    Lifecycle (called by Loader):
        Main:Init(Core)   — grab core refs, resolve character/game data
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

local LiveModifiers
local GameData

-- Mirrors Abyssal's Globals.LastCrouchFire throttle (10 Hz)
local LastCrouchFire = 0

-- RemotesFolder reference (ReplicatedStorage.RemotesFolder)
local RemotesFolder

------------------------------------------------------
-- HELPERS — character
------------------------------------------------------

local function getCharacter()
    if not Services or not Services.LocalPlayer then
        return nil
    end
    return Services.LocalPlayer.Character
end

local function getHumanoid(character)
    if not character then return nil end
    return character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(character)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
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
-- HELPERS — floor / modifiers
------------------------------------------------------

local function getFloor()
    if not GameData then return nil end

    local floorValue = GameData:FindFirstChild("Floor")
    if not floorValue then return nil end

    return floorValue.Value
end

------------------------------------------------------
-- CROUCH STATE
-- (mirrors Abyssal's Functions.IsCrouching)
------------------------------------------------------

local function isCrouching()
    if not Character then return false end

    local currentFloor = getFloor()

    -- Fools / OldHotel store crouch in attribute
    if currentFloor == "Fools" or currentFloor == "OldHotel" then
        return Character:GetAttribute("Crouching") == true
    end

    -- Standard: check CollisionPart group
    local collisionPart = Character:FindFirstChild("CollisionPart")
    if collisionPart and collisionPart:IsA("BasePart") then
        local ok, group = pcall(function()
            return collisionPart.CollisionGroup
        end)
        if ok then
            return group == "PlayerCrouching"
        end
    end

    -- Fallback attribute
    return Character:GetAttribute("Crouching") == true
end

------------------------------------------------------
-- SPEED CALCULATION
-- Mirrors Abyssal's Functions.GetCurrentSpeed exactly:
-- base 15 + character attributes + floor bonuses
-- + live modifiers – crouch penalty
------------------------------------------------------

local function getInjuriesSpeed()
    if not Humanoid then return 0 end
    return 0.075 * (Humanoid.MaxHealth - Humanoid.Health)
end

local function getCurrentSpeed()
    if not Character then return 15 end

    local speed = 15

    -- Character speed attributes (server-set)
    speed += Character:GetAttribute("SpeedBoost")       or 0
    speed += Character:GetAttribute("SpeedBoostBehind") or 0
    speed += Character:GetAttribute("SpeedBoostExtra")  or 0

    -- Party floor bonus
    if getFloor() == "Party" then
        speed += 10
    end

    -- Live modifier bonuses / penalties
    if LiveModifiers then
        if LiveModifiers:FindFirstChild("PlayerFast")    then speed += 3  end
        if LiveModifiers:FindFirstChild("PlayerFaster")  then speed += 6  end
        if LiveModifiers:FindFirstChild("PlayerFastest") then speed += 20 end
        if LiveModifiers:FindFirstChild("PlayerSlow")    then speed -= 3  end
        if LiveModifiers:FindFirstChild("PlayerSlowHealth") then
            speed -= getInjuriesSpeed()
        end
    end

    -- Crouch penalty
    if isCrouching() then
        if LiveModifiers and LiveModifiers:FindFirstChild("PlayerCrouchSlow") then
            speed -= 8
        elseif LiveModifiers and LiveModifiers:FindFirstChild("PlayerSlow") then
            speed -= 8
        else
            speed -= 5
        end
    end

    return speed
end

------------------------------------------------------
-- ELEMENT ACCESSORS
------------------------------------------------------

local function getSpeedBoost()
    local slider = Elements.SpeedBoost
    if not slider then return 0 end

    local v = slider.Value
    return type(v) == "number" and v or 0
end

local function isSpeedBoostEnabled()
    local toggle = Elements.SpeedBoostToggle
    if not toggle then return false end
    return toggle.Value == true
end

------------------------------------------------------
-- APPLY SPEED
-- Sets Humanoid.WalkSpeed = base game speed + boost
------------------------------------------------------

local function applySpeed()
    if not Humanoid or not Humanoid.Parent then
        return
    end

    local base  = getCurrentSpeed()
    local boost = isSpeedBoostEnabled() and getSpeedBoost() or 0

    local final = math.max(base + boost, 0)

    -- Only write when value actually changes (avoid useless replications)
    if Humanoid.WalkSpeed ~= final then
        Humanoid.WalkSpeed = final
    end
end

------------------------------------------------------
-- REMOTE SPAM — Crouch
--
-- Abyssal fires RemotesFolder.Crouch:FireServer(isCrouching, true)
-- every 0.1 s inside RenderStepped to keep the server in sync
-- while a speed-affecting feature is active.
--
-- We replicate that behaviour in Heartbeat with the same
-- 0.1 s throttle so the server always has a fresh state.
------------------------------------------------------

local function fireCrouchRemote()
    if not RemotesFolder then return end

    local remote = RemotesFolder:FindFirstChild("Crouch")
    if not remote then return end

    -- Rate-limit: max 10 Hz, same as Abyssal
    local now = tick()
    if now - LastCrouchFire <= 0.1 then return end

    LastCrouchFire = now

    local crouching = isCrouching()

    pcall(function()
        remote:FireServer(crouching, true)
    end)
end

------------------------------------------------------
-- UI — buildCharacter
------------------------------------------------------

local function buildCharacter()
    if not Tab then return false end

    --------------------------------------------------
    -- Group
    --------------------------------------------------

    local group = UI:AddLeftGroupbox(Tab, "Character", "user")
    if not group then return false end

    Groups.Character = group

    --------------------------------------------------
    -- Speed Boost Slider
    -- Range 0–100, mirrors Abyssal's SpeedBoostSlider
    --------------------------------------------------

    Elements.SpeedBoost = UI:AddSlider(group, "SpeedBoost", {
        Text    = "Speed Boost",
        Min     = 0,
        Max     = 100,
        Default = 0,
        Rounding = 0,
        Compact = true,
    })

    --------------------------------------------------
    -- Speed Boost Toggle
    --------------------------------------------------

    Elements.SpeedBoostToggle = UI:AddToggle(group, "SpeedBoostToggle", {
        Text    = "Enable Speed Boost",
        Default = false,
        Tooltip = "Adds the selected amount to the current game movement speed.",
    })

    return true
end

------------------------------------------------------
-- CHARACTER ADDED
------------------------------------------------------

local function onCharacterAdded(character)
    Character = character

    Humanoid = character:WaitForChild("Humanoid",          10)
    RootPart = character:WaitForChild("HumanoidRootPart",  10)

    -- Brief delay so the server has time to set base attributes
    task.delay(0.25, function()
        if not Character or Character ~= character then return end

        refreshCharacter()

        if Humanoid then
            applySpeed()
        end
    end)
end

------------------------------------------------------
-- CONNECTIONS
------------------------------------------------------

function Main:Connect()
    if Connected then return end

    if not Connections or not Services then return end

    Connected = true

    --------------------------------------------------
    -- CharacterAdded — re-apply speed on respawn
    --------------------------------------------------

    local LocalPlayer = Services.LocalPlayer

    if LocalPlayer then
        Connections:Connect(
            LocalPlayer.CharacterAdded,
            onCharacterAdded,
            "GameMain"
        )
    end

    --------------------------------------------------
    -- Slider changed → re-apply if toggle is on
    --
    -- Also fires Crouch remote so the server syncs
    -- position / crouching state after a speed change
    -- (same behaviour as Abyssal's Options.SpeedBoostSlider:OnChanged)
    --------------------------------------------------

    local slider = Elements.SpeedBoost

    if slider and type(slider.OnChanged) == "function" then
        -- Obsidian elements use :OnChanged(), NOT a .Changed signal
        slider:OnChanged(function()
            if isSpeedBoostEnabled() then
                applySpeed()
            end
            fireCrouchRemote()
        end)
    end

    --------------------------------------------------
    -- Toggle changed → immediately apply speed
    -- (mirrors Abyssal's Toggles.SpeedBoostToggle:OnChanged)
    --------------------------------------------------

    local toggle = Elements.SpeedBoostToggle

    if toggle and type(toggle.OnChanged) == "function" then
        toggle:OnChanged(function()
            applySpeed()
            fireCrouchRemote()
        end)
    end

    --------------------------------------------------
    -- Heartbeat — main loop
    --
    -- Every frame:
    --   1. Refresh character if lost
    --   2. Apply speed if boost is enabled
    --   3. Spam Crouch remote at 10 Hz (Abyssal parity)
    --------------------------------------------------

    Connections:Connect(
        Services.RunService.Heartbeat,

        function()
            -- Refresh dead refs
            if not Character or not Character.Parent then
                refreshCharacter()
            end

            if not Humanoid or not Humanoid.Parent then
                refreshCharacter()
            end

            if not Humanoid then return end

            -- Speed enforcement
            if isSpeedBoostEnabled() then
                applySpeed()
            end

            -- Crouch remote spam (only when boost is active to match Abyssal intent)
            if isSpeedBoostEnabled() then
                fireCrouchRemote()
            end
        end,

        "GameMain"
    )
end

------------------------------------------------------
-- INIT
-- Called first by Loader. Grabs Core refs + game data.
------------------------------------------------------

function Main:Init(CoreModules)
    if Initialized then return self end

    if type(CoreModules) ~= "table" then return self end

    Core        = CoreModules
    Services    = Core.Services
    Connections = Core.Connections
    Settings    = Core.Settings
    Notifications = Core.Notifications
    UI          = Core.UI

    if not Services or not Connections or not UI then
        warn("[JustXDoors GameMain] Core modules missing.")
        return self
    end

    --------------------------------------------------
    -- Game data / modifiers from ReplicatedStorage
    --------------------------------------------------

    local RS = Services.ReplicatedStorage

    if RS then
        GameData      = RS:FindFirstChild("GameData")
        LiveModifiers = RS:FindFirstChild("LiveModifiers")
        RemotesFolder = RS:WaitForChild("RemotesFolder", 10)
    end

    --------------------------------------------------
    -- Initial character snapshot
    --------------------------------------------------

    refreshCharacter()

    Initialized = true

    return self
end

------------------------------------------------------
-- BUILD
-- Called after Init. Creates UI elements + wires
-- connections into Core.Main.Tabs.Main.
------------------------------------------------------

function Main:Build()
    if Built then return self end

    if not Initialized then return self end

    --------------------------------------------------
    -- Grab the pre-created "Main" tab from root Main
    -- (DO NOT call UI:AddTab here — Loader owns tabs)
    --------------------------------------------------

    if Core and Core.Main and Core.Main.Tabs then
        Tab = Core.Main.Tabs.Main
    end

    if not Tab then
        warn("[JustXDoors GameMain] Core.Main.Tabs.Main is missing.")
        return self
    end

    --------------------------------------------------
    -- Build Character section (slider + toggle)
    --------------------------------------------------

    if not buildCharacter() then
        warn("[JustXDoors GameMain] Failed to build Character section.")
        return self
    end

    --------------------------------------------------
    -- Wire all connections
    --------------------------------------------------

    self:Connect()

    --------------------------------------------------
    -- Initial speed pass after a tick
    --------------------------------------------------

    task.defer(function()
        refreshCharacter()

        if Humanoid then
            applySpeed()
        end
    end)

    Built = true

    return self
end

------------------------------------------------------
-- DESTROY
-- Disconnects everything and resets state.
-- Called by Loader on unload.
------------------------------------------------------

function Main:Destroy()
    if Connections then
        Connections:DisconnectGroup("GameMain")
    end

    -- UI elements
    Groups   = {}
    Elements = {}

    Tab = nil

    -- Character refs
    Character = nil
    Humanoid  = nil
    RootPart  = nil

    -- Game data refs
    LiveModifiers = nil
    GameData      = nil
    RemotesFolder = nil

    -- Timing
    LastCrouchFire = 0

    -- Flags
    Initialized = false
    Built       = false
    Connected   = false

    -- Core refs
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
