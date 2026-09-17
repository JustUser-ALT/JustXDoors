local Main = {}

------------------------------------------------------
-- CORE
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
local Built = false
local Connected = false

local Tab

local Groups = {}
local Elements = {}

------------------------------------------------------
-- CHARACTER
------------------------------------------------------

local Character
local Humanoid
local RootPart

local LiveModifiers
local GameData
local Floor

------------------------------------------------------
-- HELPERS
------------------------------------------------------

local function getCharacter()
    if not Services or not Services.LocalPlayer then
        return nil
    end

    return Services.LocalPlayer.Character
end

local function getHumanoid(character)
    if not character then
        return nil
    end

    return character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(character)
    if not character then
        return nil
    end

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

    return Humanoid ~= nil
        and RootPart ~= nil
end

------------------------------------------------------
-- FLOOR
------------------------------------------------------

local function getFloor()
    if not GameData then
        return nil
    end

    local floorValue =
        GameData:FindFirstChild("Floor")

    if not floorValue then
        return nil
    end

    return floorValue.Value
end

------------------------------------------------------
-- CROUCH
------------------------------------------------------

local function isCrouching()
    if not Character then
        return false
    end

    local currentFloor =
        getFloor()

    --------------------------------------------------
    -- Fools / OldHotel
    --------------------------------------------------

    if currentFloor == "Fools"
        or currentFloor == "OldHotel"
    then
        return Character:GetAttribute(
            "Crouching"
        ) == true
    end

    --------------------------------------------------
    -- CollisionPart
    --------------------------------------------------

    local collisionPart =
        Character:FindFirstChild(
            "CollisionPart"
        )

    if collisionPart
        and collisionPart:IsA("BasePart")
    then
        local success, group =
            pcall(function()
                return collisionPart.CollisionGroup
            end)

        if success then
            return group == "PlayerCrouching"
        end
    end

    --------------------------------------------------
    -- Attribute fallback
    --------------------------------------------------

    return Character:GetAttribute(
        "Crouching"
    ) == true
end

------------------------------------------------------
-- INJURY SPEED
------------------------------------------------------

local function getInjuriesSpeed()
    if not Humanoid then
        return 0
    end

    return 0.075 *
        (
            Humanoid.MaxHealth
            - Humanoid.Health
        )
end

------------------------------------------------------
-- BASE GAME SPEED
------------------------------------------------------

local function getCurrentSpeed()
    if not Character then
        return 15
    end

    local speed = 15

    --------------------------------------------------
    -- CHARACTER ATTRIBUTES
    --------------------------------------------------

    speed +=
        Character:GetAttribute(
            "SpeedBoost"
        ) or 0

    speed +=
        Character:GetAttribute(
            "SpeedBoostBehind"
        ) or 0

    speed +=
        Character:GetAttribute(
            "SpeedBoostExtra"
        ) or 0

    --------------------------------------------------
    -- PARTY
    --------------------------------------------------

    if getFloor() == "Party" then
        speed += 10
    end

    --------------------------------------------------
    -- LIVE MODIFIERS
    --------------------------------------------------

    if LiveModifiers then

        if LiveModifiers:FindFirstChild(
            "PlayerFast"
        ) then
            speed += 3
        end

        if LiveModifiers:FindFirstChild(
            "PlayerFaster"
        ) then
            speed += 6
        end

        if LiveModifiers:FindFirstChild(
            "PlayerFastest"
        ) then
            speed += 20
        end

        if LiveModifiers:FindFirstChild(
            "PlayerSlow"
        ) then
            speed -= 3
        end

        if LiveModifiers:FindFirstChild(
            "PlayerSlowHealth"
        ) then
            speed -= getInjuriesSpeed()
        end
    end

    --------------------------------------------------
    -- CROUCH
    --------------------------------------------------

    if isCrouching() then

        if LiveModifiers
            and LiveModifiers:FindFirstChild(
                "PlayerCrouchSlow"
            )
        then

            speed -= 8

        elseif LiveModifiers
            and LiveModifiers:FindFirstChild(
                "PlayerSlow"
            )
        then

            speed -= 8

        else
            speed -= 5
        end
    end

    return speed
end

------------------------------------------------------
-- SPEED BOOST VALUE
------------------------------------------------------

local function getSpeedBoost()
    local slider =
        Elements.SpeedBoost

    if not slider then
        return 0
    end

    local value =
        slider.Value

    if type(value) ~= "number" then
        return 0
    end

    return value
end

------------------------------------------------------
-- SPEED TOGGLE
------------------------------------------------------

local function isSpeedBoostEnabled()
    local toggle =
        Elements.SpeedBoostToggle

    if not toggle then
        return false
    end

    return toggle.Value == true
end

------------------------------------------------------
-- APPLY SPEED
------------------------------------------------------

local function applySpeed()
    if not Humanoid
        or not Humanoid.Parent
    then
        return
    end

    local baseSpeed =
        getCurrentSpeed()

    local boost = 0

    if isSpeedBoostEnabled() then
        boost = getSpeedBoost()
    end

    local finalSpeed =
        baseSpeed + boost

    --------------------------------------------------
    -- Safety
    --------------------------------------------------

    if finalSpeed < 0 then
        finalSpeed = 0
    end

    --------------------------------------------------
    -- Apply
    --------------------------------------------------

    if Humanoid.WalkSpeed ~= finalSpeed then
        Humanoid.WalkSpeed = finalSpeed
    end
end

------------------------------------------------------
-- CHARACTER UI
------------------------------------------------------

local function buildCharacter()
    if not Tab then
        return false
    end

    --------------------------------------------------
    -- CHARACTER GROUP
    --------------------------------------------------

    local group =
        UI:AddLeftGroupbox(
            Tab,
            "Character",
            "user"
        )

    if not group then
        return false
    end

    Groups.Character =
        group

    --------------------------------------------------
    -- SPEED BOOST SLIDER
    --------------------------------------------------

    Elements.SpeedBoost =
        UI:AddSlider(
            group,
            "SpeedBoost",
            {
                Text = "Speed Boost",

                Min = 0,

                Max = 100,

                Default = 0,

                Rounding = 0,

                Compact = true
            }
        )

    --------------------------------------------------
    -- SPEED BOOST TOGGLE
    --------------------------------------------------

    Elements.SpeedBoostToggle =
        UI:AddToggle(
            group,
            "SpeedBoostToggle",
            {
                Text = "Enable Speed Boost",

                Default = false,

                Tooltip =
                    "Adds the selected amount to the game's current movement speed."
            }
        )

    return true
end

------------------------------------------------------
-- CHARACTER ADDED
------------------------------------------------------

local function onCharacterAdded(character)
    Character = character

    Humanoid =
        character:WaitForChild(
            "Humanoid",
            10
        )

    RootPart =
        character:WaitForChild(
            "HumanoidRootPart",
            10
        )

    --------------------------------------------------
    -- Wait for character systems
    --------------------------------------------------

    task.delay(0.25, function()

        if not Character
            or Character ~= character
        then
            return
        end

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

    if Connected then
        return
    end

    if not Connections
        or not Services
    then
        return
    end

    Connected = true

    --------------------------------------------------
    -- PLAYER
    --------------------------------------------------

    local LocalPlayer =
        Services.LocalPlayer

    if LocalPlayer then

        Connections:Connect(
            LocalPlayer.CharacterAdded,

            onCharacterAdded,

            "GameMain"
        )
    end

    --------------------------------------------------
    -- SPEED SLIDER
    --------------------------------------------------

    local slider =
        Elements.SpeedBoost

    if slider then

        Connections:Connect(
            slider.Changed,

            function()
                if isSpeedBoostEnabled() then
                    applySpeed()
                end
            end,

            "GameMain"
        )
    end

    --------------------------------------------------
    -- SPEED TOGGLE
    --------------------------------------------------

    local toggle =
        Elements.SpeedBoostToggle

    if toggle then

        Connections:Connect(
            toggle.Changed,

            function()
                applySpeed()
            end,

            "GameMain"
        )
    end

    --------------------------------------------------
    -- HEARTBEAT
    --------------------------------------------------

    Connections:Connect(
        Services.RunService.Heartbeat,

        function()

            --------------------------------------------------
            -- Character refresh
            --------------------------------------------------

            if not Character
                or not Character.Parent
            then
                refreshCharacter()
            end

            if not Humanoid
                or not Humanoid.Parent
            then
                refreshCharacter()
            end

            if not Humanoid then
                return
            end

            --------------------------------------------------
            -- Speed
            --------------------------------------------------

            if isSpeedBoostEnabled() then
                applySpeed()
            end

        end,

        "GameMain"
    )
end

------------------------------------------------------
-- INIT
------------------------------------------------------

function Main:Init(CoreModules)

    if Initialized then
        return self
    end

    if type(CoreModules) ~= "table" then
        return self
    end

    Core =
        CoreModules

    Services =
        Core.Services

    Connections =
        Core.Connections

    Settings =
        Core.Settings

    Notifications =
        Core.Notifications

    UI =
        Core.UI

    if not Services
        or not Connections
        or not UI
    then
        warn(
            "[JustXDoors GameMain] Core modules missing."
        )

        return self
    end

    --------------------------------------------------
    -- GAME DATA
    --------------------------------------------------

    local ReplicatedStorage =
        Services.ReplicatedStorage

    if ReplicatedStorage then

        GameData =
            ReplicatedStorage:FindFirstChild(
                "GameData"
            )

        LiveModifiers =
            ReplicatedStorage:FindFirstChild(
                "LiveModifiers"
            )
    end

    --------------------------------------------------
    -- CHARACTER
    --------------------------------------------------

    refreshCharacter()

    --------------------------------------------------
    -- INIT COMPLETE
    --------------------------------------------------

    Initialized = true

    return self
end

------------------------------------------------------
-- BUILD
------------------------------------------------------

function Main:Build()

    if Built then
        return self
    end

    if not Initialized then
        return self
    end

    --------------------------------------------------
    -- USE ROOT MAIN TAB
    --
    -- IMPORTANT:
    -- Do NOT call UI:AddTab() here.
    --------------------------------------------------

    if Core
        and Core.Main
        and Core.Main.Tabs
    then

        Tab =
            Core.Main.Tabs.Main

    end

    --------------------------------------------------
    -- Compatibility fallback
    --------------------------------------------------

    if not Tab then

        warn(
            "[JustXDoors GameMain] "
            .. "Core.Main.Tabs.Main is missing."
        )

        return self
    end

    --------------------------------------------------
    -- CHARACTER UI
    --------------------------------------------------

    if not buildCharacter() then
        warn(
            "[JustXDoors GameMain] "
            .. "Failed to build Character section."
        )

        return self
    end

    --------------------------------------------------
    -- CONNECTIONS
    --------------------------------------------------

    self:Connect()

    --------------------------------------------------
    -- INITIAL SPEED
    --------------------------------------------------

    task.defer(function()

        refreshCharacter()

        if Humanoid then
            applySpeed()
        end

    end)

    --------------------------------------------------
    -- STATE
    --------------------------------------------------

    Built = true

    return self
end

------------------------------------------------------
-- DESTROY
------------------------------------------------------

function Main:Destroy()

    --------------------------------------------------
    -- Connections
    --------------------------------------------------

    if Connections then

        Connections:DisconnectGroup(
            "GameMain"
        )

    end

    --------------------------------------------------
    -- State
    --------------------------------------------------

    Groups = {}
    Elements = {}

    Tab = nil

    Character = nil
    Humanoid = nil
    RootPart = nil

    LiveModifiers = nil
    GameData = nil
    Floor = nil

    Initialized = false
    Built = false
    Connected = false

    --------------------------------------------------
    -- Core
    --------------------------------------------------

    Core = nil
    Services = nil
    Connections = nil
    Settings = nil
    Notifications = nil
    UI = nil
end

------------------------------------------------------
-- RETURN
------------------------------------------------------

return Main
