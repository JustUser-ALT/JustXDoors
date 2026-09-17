local Lobby = {}

------------------------------------------------------
-- CORE
------------------------------------------------------

local Core
local Services
local Connections
local UI
local Notifications

------------------------------------------------------
-- STATE
------------------------------------------------------

local Tab
local Groups = {}
local Elements = {}

local Initialized = false
local Built = false
local Connected = false

local RemotesFolder
local LocalPlayer

local RedeemingCodes = false
local UnlockedBadges = {}

local LastBadgeChange = 0
local LastElevatorCheck = 0

local PreviousBadge

------------------------------------------------------
-- QUICK PLAY DESTINATIONS
------------------------------------------------------

local QUICK_PLAY = {
    {
        Text = "The Hotel",
        Destination = "Hotel"
    },

    {
        Text = "The Mines",
        Destination = "Mines"
    },

    {
        Text = "The Backdoor",
        Destination = "Backdoor"
    },

    {
        Text = "The Rooms",
        Destination = "Rooms"
    },

    {
        Text = "The Outdoors",
        Destination = "Garden"
    },

    {
        Text = "Battle Mode",
        Destination = "Party"
    },

    {
        Text = "Retro Mode",
        Destination = "Retro"
    },

    {
        Text = "Rush Mode",
        Destination = "Fools26"
    },

    {
        Text = "Halloween",
        Destination = "Halloween25"
    },

    {
        Text = "Hotel-",
        Destination = "BeforePlus"
    },

    {
        Text = "Super Hard Mode",
        Destination = "SuperHardMode"
    }
}

------------------------------------------------------
-- CODES
------------------------------------------------------

local CODES = {
    "67",
    "54",
    "41",
    "CHEDDAR BALLS",
    "XQC",
    "PENGUINZ0",
    "KREEKCRAFT",
    "ISHOWSPEED",
    "DANTDM",
    "KUBZ SCOUTS",
    "FIND THE TROLLFACES",
    "THINKNOODLES",
    "W",
    "RAGDOLL UNIVERSE",
    "RAGDOLL MAYHEM",
    "BIJUU MIKE",
    "8BITRYAN",
    "SCREECHSUCKS",
    "LORE",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    "FIND THE TROLLFACES",
    "3rd",
    "LAZYDEVS",
    "RAGDOLL COMBAT",
    "VOCAB HAVOC",
    "PATHSWAP",
    "JUMP OVER THE BRICK"
}

------------------------------------------------------
-- NOTIFICATIONS
------------------------------------------------------

local function notify(title, description, duration)
    if not Notifications then
        return
    end

    pcall(function()
        Notifications:Info(
            title,
            description,
            duration or 5
        )
    end)
end

------------------------------------------------------
-- REMOTE HELPERS
------------------------------------------------------

local function getRemote(name)
    if not RemotesFolder then
        return nil
    end

    return RemotesFolder:FindFirstChild(name)
end

local function fireRemote(name, ...)
    local remote = getRemote(name)

    if not remote then
        return false
    end

    -- Store varargs before entering the nested pcall.
    local args = table.pack(...)

    local success = pcall(function()
        remote:FireServer(
            table.unpack(
                args,
                1,
                args.n
            )
        )
    end)

    return success
end

------------------------------------------------------
-- PLAYER / GUI HELPERS
------------------------------------------------------

local function getPlayerGui()
    if not LocalPlayer then
        return nil
    end

    return LocalPlayer:FindFirstChild("PlayerGui")
end

local function getMainUI()
    local playerGui = getPlayerGui()

    if not playerGui then
        return nil
    end

    return playerGui:FindFirstChild("MainUI")
end

local function getLobbyFrame()
    local mainUI = getMainUI()

    if not mainUI then
        return nil
    end

    return mainUI:FindFirstChild("LobbyFrame")
end

local function getAchievements()
    local lobbyFrame = getLobbyFrame()

    if not lobbyFrame then
        return nil
    end

    return lobbyFrame:FindFirstChild("Achievements")
end

local function getAchievementContainer()
    local achievements = getAchievements()

    if not achievements then
        return nil
    end

    return achievements:FindFirstChild("List")
end

------------------------------------------------------
-- ELEVATOR
------------------------------------------------------

local function getSelectedTarget()
    local dropdown =
        Elements.AutoJoinElevatorTarget

    if not dropdown then
        return nil
    end

    local value = dropdown.Value

    if not value then
        return nil
    end

    if typeof(value) == "Instance" then
        if value:IsA("Player") then
            return value
        end

        return nil
    end

    if type(value) == "string" then
        return Services.Players:FindFirstChild(
            value
        )
    end

    return nil
end

local function checkElevators()
    local toggle =
        Elements.AutoJoinElevator

    if not toggle
        or toggle.Value ~= true
    then
        return
    end

    local targetPlayer =
        getSelectedTarget()

    if not targetPlayer then
        fireRemote("ElevatorExit")
        return
    end

    local targetCharacter =
        targetPlayer.Character

    if not targetCharacter then
        return
    end

    local lobby =
        Services.Workspace:FindFirstChild(
            "Lobby"
        )

    if not lobby then
        return
    end

    local elevators =
        lobby:FindFirstChild(
            "LobbyElevators"
        )

    if not elevators then
        return
    end

    local targetElevatorId =
        targetCharacter:GetAttribute(
            "InGameElevator"
        )

    if not targetElevatorId then
        fireRemote("ElevatorExit")
        return
    end

    local found = false

    for _, elevator in ipairs(
        elevators:GetChildren()
    ) do

        if elevator:GetAttribute("ID")
            == targetElevatorId
        then

            found = true

            fireRemote(
                "ElevatorJoin",
                elevator
            )

            break
        end
    end

    if not found then
        fireRemote("ElevatorExit")
    end
end

------------------------------------------------------
-- ACHIEVEMENTS
------------------------------------------------------

local function getAchievementList()
    local result = {}

    local list =
        getAchievementContainer()

    if not list then
        return result
    end

    for _, frame in ipairs(
        list:GetChildren()
    ) do

        if frame:IsA("ImageButton")
            and frame.ImageTransparency == 0
        then

            table.insert(
                result,
                frame.Name
            )
        end
    end

    return result
end

local function updateAchievements()
    UnlockedBadges =
        getAchievementList()
end

local function setBadgeStar(
    frame,
    visible
)
    if not frame then
        return
    end

    local icons =
        frame:FindFirstChild("Icons")

    if not icons then
        return
    end

    local star =
        icons:FindFirstChild("Star")

    if star then
        star.Visible = visible
    end
end

local function hideCurrentStars()
    local list =
        getAchievementContainer()

    if not list then
        return
    end

    for _, frame in ipairs(
        list:GetChildren()
    ) do

        if frame:IsA("ImageButton")
            and frame.ImageTransparency == 0
        then

            setBadgeStar(
                frame,
                false
            )
        end
    end
end

local function flexAchievement(
    badgeName
)
    if not badgeName then
        return false
    end

    local list =
        getAchievementContainer()

    if not list then
        return false
    end

    --------------------------------------------------
    -- HIDE CURRENT STARS
    --------------------------------------------------

    hideCurrentStars()

    --------------------------------------------------
    -- REMOTE
    --------------------------------------------------

    local remote =
        getRemote("FlexAchievement")

    if remote then
        pcall(function()
            remote:FireServer(
                badgeName
            )
        end)
    end

    --------------------------------------------------
    -- SHOW NEW STAR
    --------------------------------------------------

    local selected =
        list:FindFirstChild(
            badgeName
        )

    if selected then
        setBadgeStar(
            selected,
            true
        )
    end

    PreviousBadge =
        badgeName

    return true
end

------------------------------------------------------
-- REDEEM CODES
------------------------------------------------------

local function redeemAllCodes()
    if RedeemingCodes then
        return
    end

    local remote =
        getRemote("ShopCode")

    if not remote then
        notify(
            "Lobby",
            "ShopCode remote was not found."
        )

        return
    end

    RedeemingCodes = true

    notify(
        "Redeeming Codes",
        "Redeeming "
            .. tostring(#CODES)
            .. " codes..."
    )

    task.spawn(function()
        for _, code in ipairs(CODES) do

            pcall(function()
                remote:FireServer(
                    code
                )
            end)

            task.wait(5.1)
        end

        RedeemingCodes = false

        notify(
            "Redeeming Codes",
            "Finished redeeming codes."
        )
    end)
end

------------------------------------------------------
-- CREATE ELEVATOR
------------------------------------------------------

local function createElevator(
    destination,
    mods
)
    local remote =
        getRemote("CreateElevator")

    if not remote then
        notify(
            "Lobby",
            "CreateElevator remote was not found."
        )

        return false
    end

    local data = {
        Mods = mods or {},
        Settings = {},
        Destination = destination,
        FriendsOnly = false,
        MaxPlayers = "1"
    }

    local success =
        pcall(function()
            remote:FireServer(
                data
            )
        end)

    return success
end

------------------------------------------------------
-- QUICK PLAY UI
------------------------------------------------------

local function buildQuickPlay()
    local group =
        UI:AddRightGroupbox(
            Tab,
            "Quick Play",
            "play"
        )

    if not group then
        return
    end

    Groups.QuickPlay =
        group

    for _, entry in ipairs(
        QUICK_PLAY
    ) do

        UI:AddButton(
            group,
            entry.Text,
            function()
                createElevator(
                    entry.Destination
                )
            end
        )
    end

    UI:AddDivider(group)

    UI:AddButton(
        group,
        "The Rooms [Free, No Progress]",
        function()
            createElevator(
                "Rooms",
                {
                    "AdminPanel"
                }
            )
        end
    )

    UI:AddButton(
        group,
        "The Outdoors [Free, No Progress]",
        function()
            createElevator(
                "Garden",
                {
                    "AdminPanel"
                }
            )
        end
    )
end

------------------------------------------------------
-- SELF UI
------------------------------------------------------

local function buildSelf()
    local group =
        UI:AddLeftGroupbox(
            Tab,
            "Self",
            "user"
        )

    if not group then
        return
    end

    Groups.Self =
        group

    Elements.AutoJoinElevator =
        UI:AddToggle(
            group,
            "AutoJoinElevator",
            {
                Text = "Auto Join Elevator",

                Default = false,

                Tooltip =
                    "Automatically joins the selected player's elevator."
            }
        )

    Elements.AutoJoinElevatorTarget =
        UI:AddDropdown(
            group,
            "AutoJoinElevatorTarget",
            {
                Text = "Target",

                SpecialType = "Player",

                ExcludeLocalPlayer = true,

                Searchable = true
            }
        )
end

------------------------------------------------------
-- AUTOMATION UI
------------------------------------------------------

local function buildAutomation()
    local group =
        UI:AddLeftGroupbox(
            Tab,
            "Automation",
            "repeat"
        )

    if not group then
        return
    end

    Groups.Automation =
        group

    Elements.CycleAchievements =
        UI:AddToggle(
            group,
            "CycleAchievements",
            {
                Text =
                    "Cycle Achievements",

                Default = false,

                Tooltip =
                    "Rapidly equips a random unlocked badge."
            }
        )

    Elements.CycleAchievementsDelay =
        UI:AddSlider(
            group,
            "CycleAchievementsDelay",
            {
                Text =
                    "Cycle Delay",

                Min = 0,

                Max = 1,

                Default = 0.1,

                Rounding = 2,

                Compact = true
            }
        )

    UI:AddDivider(group)

    UI:AddButton(
        group,
        "Redeem All Codes",
        function()
            redeemAllCodes()
        end
    )
end

------------------------------------------------------
-- BUILD
------------------------------------------------------

function Lobby:Build()
    if Built then
        return true
    end

    if not Initialized then
        return false
    end

    if not UI then
        return false
    end

    --------------------------------------------------
    -- TAB
    --------------------------------------------------

    Tab =
        UI:AddTab(
            "Lobby",
            "home",
            "Lobby features"
        )

    if not Tab then
        return false
    end

    --------------------------------------------------
    -- GROUPS
    --------------------------------------------------

    buildSelf()
    buildAutomation()
    buildQuickPlay()

    --------------------------------------------------
    -- INITIAL DATA
    --------------------------------------------------

    updateAchievements()

    LastBadgeChange =
        os.clock()

    LastElevatorCheck =
        os.clock()

    Built = true

    return true
end

------------------------------------------------------
-- CONNECTIONS
------------------------------------------------------

function Lobby:Connect()
    if Connected then
        return
    end

    if not Connections
        or not Services
        or not LocalPlayer
    then
        return
    end

    Connected = true

    --------------------------------------------------
    -- ACHIEVEMENT LIST
    --------------------------------------------------

    local list =
        getAchievementContainer()

    if list then

        Connections:Connect(
            list.ChildAdded,

            function(frame)
                task.defer(function()

                    if not frame:IsA(
                        "ImageButton"
                    ) then
                        return
                    end

                    if frame.ImageTransparency
                        ~= 0
                    then
                        return
                    end

                    if not table.find(
                        UnlockedBadges,
                        frame.Name
                    ) then

                        table.insert(
                            UnlockedBadges,
                            frame.Name
                        )
                    end
                end)
            end,

            "Lobby"
        )
    end

    --------------------------------------------------
    -- HEARTBEAT
    --------------------------------------------------

    Connections:Connect(
        Services.RunService.Heartbeat,

        function()
            local now =
                os.clock()

            --------------------------------------------------
            -- ELEVATOR
            --------------------------------------------------

            if now - LastElevatorCheck
                > 0.25
            then

                checkElevators()

                LastElevatorCheck =
                    now
            end

            --------------------------------------------------
            -- ACHIEVEMENTS
            --------------------------------------------------

            local cycle =
                Elements.CycleAchievements

            local delaySlider =
                Elements.CycleAchievementsDelay

            if not cycle
                or not delaySlider
            then
                return
            end

            if cycle.Value ~= true then
                return
            end

            if now - LastBadgeChange
                <= delaySlider.Value
            then
                return
            end

            --------------------------------------------------
            -- REFRESH BADGES
            --------------------------------------------------

            if #UnlockedBadges == 0 then

                updateAchievements()

                if #UnlockedBadges == 0 then
                    return
                end
            end

            --------------------------------------------------
            -- SELECT BADGE
            --------------------------------------------------

            local badge =
                UnlockedBadges[
                    math.random(
                        1,
                        #UnlockedBadges
                    )
                ]

            --------------------------------------------------
            -- AVOID SAME BADGE
            --------------------------------------------------

            if #UnlockedBadges > 1
                and badge == PreviousBadge
            then

                for _ = 1, 10 do

                    local newBadge =
                        UnlockedBadges[
                            math.random(
                                1,
                                #UnlockedBadges
                            )
                        ]

                    if newBadge
                        ~= PreviousBadge
                    then

                        badge =
                            newBadge

                        break
                    end
                end
            end

            --------------------------------------------------
            -- FLEX
            --------------------------------------------------

            if flexAchievement(
                badge
            ) then

                LastBadgeChange =
                    now
            end
        end,

        "Lobby"
    )
end

------------------------------------------------------
-- INIT
------------------------------------------------------

function Lobby:Init(
    core,
    Main
)
    if Initialized then
        return self
    end

    if type(core) ~= "table" then
        return self
    end

    Core =
        core

    Services =
        Core.Services

    Connections =
        Core.Connections

    UI =
        Core.UI

    Notifications =
        Core.Notifications

    if not Services then
        return self
    end

    LocalPlayer =
        Services.LocalPlayer

    if not LocalPlayer then
        return self
    end

    --------------------------------------------------
    -- REMOTES
    --------------------------------------------------

    local replicatedStorage =
        Services.ReplicatedStorage

    if not replicatedStorage then
        return self
    end

    RemotesFolder =
        replicatedStorage:WaitForChild(
            "RemotesFolder"
        )

    --------------------------------------------------
    -- INIT COMPLETE
    --------------------------------------------------

    Initialized = true

    return self
end

------------------------------------------------------
-- START
------------------------------------------------------

function Lobby:Start()
    if not Initialized then
        return false
    end

    if not Built then
        if not self:Build() then
            return false
        end
    end

    self:Connect()

    notify(
        "Lobby",
        "Lobby features loaded."
    )

    return true
end

------------------------------------------------------
-- DESTROY
------------------------------------------------------

function Lobby:Destroy()
    if Connections then
        Connections:DisconnectGroup(
            "Lobby"
        )
    end

    Groups = {}
    Elements = {}
    UnlockedBadges = {}

    Tab = nil

    RemotesFolder = nil
    LocalPlayer = nil

    PreviousBadge = nil

    RedeemingCodes = false

    LastBadgeChange = 0
    LastElevatorCheck = 0

    Initialized = false
    Built = false
    Connected = false

    Core = nil
    Services = nil
    Connections = nil
    UI = nil
    Notifications = nil
end

return Lobby
