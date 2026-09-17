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

local OriginalWalkSpeed = nil

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

local function getFloor()
    if Floor ~= nil then
        return Floor
    end

    if not GameData then
        return nil
    end

    local floorValue =
        GameData:FindFirstChild("Floor")

    if not floorValue then
        return nil
    end

    Floor = floorValue.Value

    return Floor
end

------------------------------------------------------
-- CHARACTER SPEED
------------------------------------------------------

local function isCrouching()
    if not Character then
        return false
    end

    local currentFloor =
        getFloor()

    --------------------------------------------------
    -- Abyssal uses Character.Crouching for these
    -- floors.
    --------------------------------------------------

    if currentFloor == "Fools"
        or currentFloor == "OldHotel"
    then
        return Character:GetAttribute(
            "Crouching"
        ) == true
    end

    --------------------------------------------------
    -- For normal DOORS floors we first try the
    -- game's collision group.
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
    -- Fallback used if CollisionPart isn't available.
    --------------------------------------------------

    return Character:GetAttribute(
        "Crouching"
    ) == true
end

local function getInjuriesSpeed()
    if not Humanoid then
        return 0
    end

    return 0.075
        * (Humanoid.MaxHealth - Humanoid.Health)
end

local function getCurrentSpeed()
    if not Character then
        return 15
    end

    local speed = 15

    --------------------------------------------------
    -- Character speed attributes
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
    -- Party floor bonus
    --------------------------------------------------

    if getFloor() == "Party" then
        speed += 10
    end

    --------------------------------------------------
    -- Live modifiers
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
    -- Crouch penalty
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

local function isSpeedBoostEnabled()
    local toggle =
        Elements.SpeedBoostToggle

    if not toggle then
        return false
    end

    return toggle.Value == true
end

local function applySpeed()
    if not Humanoid
        or Humanoid.Parent == nil
    then
        return
    end

    local baseSpeed =
        getCurrentSpeed()

    if isSpeedBoostEnabled() then

        Humanoid.WalkSpeed =
            baseSpeed
            + getSpeedBoost()

    else

        Humanoid.WalkSpeed =
            baseSpeed
    end
end

------------------------------------------------------
-- CHARACTER UI
------------------------------------------------------

local function buildCharacter()
    if not Tab then
        return false
    end

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
                    "Increases your WalkSpeed by the specified amount."
            }
        )

    return true
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
    -- CHARACTER ADDED
    --------------------------------------------------

    local LocalPlayer =
        Services.LocalPlayer

    if LocalPlayer then

        Connections:Connect(
            LocalPlayer.CharacterAdded,

            function(character)

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

                OriginalWalkSpeed = nil

                task.defer(function()

                    if Humanoid then
                        applySpeed()
                    end

                end)

            end,

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
            -- Only continuously control WalkSpeed when
            -- Speed Boost is enabled.
            --
            -- This follows Abyssal Continued's approach:
            -- current DOORS speed + selected boost.
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
    -- TAB
    --------------------------------------------------

    Tab =
        UI:AddTab(
            "Main",
            "user",
            "Main character features"
        )

    if not Tab then
        return self
    end

    --------------------------------------------------
    -- CHARACTER
    --------------------------------------------------

    buildCharacter()

    --------------------------------------------------
    -- INITIAL CONNECTIONS
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

    Built = true

    return self
end

------------------------------------------------------
-- DESTROY
------------------------------------------------------

function Main:Destroy()

    if Connections then

        Connections:DisconnectGroup(
            "GameMain"
        )

    end

    Groups = {}
    Elements = {}

    Tab = nil

    Character = nil
    Humanoid = nil
    RootPart = nil

    LiveModifiers = nil
    GameData = nil
    Floor = nil

    OriginalWalkSpeed = nil

    Initialized = false
    Built = false
    Connected = false

    Core = nil
    Services = nil
    Connections = nil
    Settings = nil
    Notifications = nil
    UI = nil

end

return Main
