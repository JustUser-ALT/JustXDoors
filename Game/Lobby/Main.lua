local Lobby = {}

local Core
local Services
local Connections
local UI
local Notifications

local Tab
local Groups = {}
local Elements = {}

local Initialized = false
local Built = false

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
-- NOTIFY
------------------------------------------------------

local function notify(
    title,
    description,
    duration
)

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
-- ELEVATOR
------------------------------------------------------

local function getSelectedTarget()

    local dropdown =
        Elements.AutoJoinElevatorTarget

    if not dropdown then
        return nil
    end

    local value =
        dropdown.Value

    if not value then
        return nil
    end

    if typeof(value) == "Instance" then

        return value

    end

    if type(value) == "string" then

        return Services.Players:
            FindFirstChild(value)

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

        pcall(function()

            RemotesFolder
                .ElevatorExit
                :FireServer()

        end)

        return
    end

    local targetCharacter =
        targetPlayer.Character

    if not targetCharacter then
        return
    end

    local lobby =
        Services.Workspace:
            FindFirstChild("Lobby")

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

    local found = false

    if targetElevatorId then

        for _, elevator in ipairs(
            elevators:GetChildren()
        ) do

            if elevator:GetAttribute("ID")
                == targetElevatorId
            then

                found = true

                pcall(function()

                    RemotesFolder
                        .ElevatorJoin
                        :FireServer(
                            elevator
                        )

                end)

                break
            end
        end
    end

    if not found then

        pcall(function()

            RemotesFolder
                .ElevatorExit
                :FireServer()

        end)

    end
end

------------------------------------------------------
-- ACHIEVEMENTS
------------------------------------------------------

local function getAchievementList()

    local result = {}

    local playerGui =
        LocalPlayer:FindFirstChild(
            "PlayerGui"
        )

    if not playerGui then
        return result
    end

    local mainUI =
        playerGui:FindFirstChild(
            "MainUI"
        )

    if not mainUI then
        return result
    end

    local lobbyFrame =
        mainUI:FindFirstChild(
            "LobbyFrame"
        )

    if not lobbyFrame then
        return result
    end

    local achievements =
        lobbyFrame:FindFirstChild(
            "Achievements"
        )

    if not achievements then
        return result
    end

    local list =
        achievements:FindFirstChild(
            "List"
        )

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

local function flexAchievement(
    badgeName
)

    if not badgeName then
        return false
    end

    local playerGui =
        LocalPlayer:FindFirstChild(
            "PlayerGui"
        )

    if not playerGui then
        return false
    end

    local mainUI =
        playerGui:FindFirstChild(
            "MainUI"
        )

    if not mainUI then
        return false
    end

    local lobbyFrame =
        mainUI:FindFirstChild(
            "LobbyFrame"
        )

    if not lobbyFrame then
        return false
    end

    local achievements =
        lobbyFrame:FindFirstChild(
            "Achievements"
        )

    if not achievements then
        return false
    end

    local list =
        achievements:FindFirstChild(
            "List"
        )

    if not list then
        return false
    end

    --------------------------------------------------
    -- HIDE CURRENT STARS
    --------------------------------------------------

    for _, frame in ipairs(
        list:GetChildren()
    ) do

        if frame:IsA("ImageButton")
            and frame.ImageTransparency == 0
        then

            local icons =
                frame:FindFirstChild(
                    "Icons"
                )

            if icons then

                local star =
                    icons:FindFirstChild(
                        "Star"
                    )

                if star then
                    star.Visible = false
                end

            end
        end
    end

    --------------------------------------------------
    -- REMOTE
    --------------------------------------------------

    local remote =
        RemotesFolder:
            FindFirstChild(
                "FlexAchievement"
            )

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

        local icons =
            selected:FindFirstChild(
                "Icons"
            )

        if icons then

            local star =
                icons:FindFirstChild(
                    "Star"
                )

            if star then
                star.Visible = true
            end

        end
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
        RemotesFolder:
            FindFirstChild(
                "ShopCode"
            )

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
        RemotesFolder:
            FindFirstChild(
                "CreateElevator"
            )

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
-- BUILD QUICK PLAY
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

    UI:AddDivider(
        group
    )

    --------------------------------------------------
    -- FREE / NO PROGRESS
    --------------------------------------------------

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
-- BUILD SELF
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
                Text =
                    "Auto Join Elevator",

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
-- BUILD AUTOMATION
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

    UI:AddDivider(
        group
    )

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

    --------------------------------------------------
    -- STATE
    --------------------------------------------------

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

    if not Connections then
        return
    end

    --------------------------------------------------
    -- ACHIEVEMENT ADDED
    --------------------------------------------------

    Connections:Connect(
        LocalPlayer
            .PlayerGui
            .MainUI
            .LobbyFrame
            .Achievements
            .List
            .ChildAdded,

        function(frame)

            task.defer(function()

                if frame:IsA("ImageButton")
                    and frame.ImageTransparency == 0
                then

                    if not table.find(
                        UnlockedBadges,
                        frame.Name
                    ) then

                        table.insert(
                            UnlockedBadges,
                            frame.Name
                        )

                    end
                end

            end)

        end,

        "Lobby"
    )

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
            -- EMPTY LIST
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

function Lobby:Init(core)

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

    RemotesFolder =
        replicatedStorage:
            WaitForChild(
                "RemotesFolder"
            )

    --------------------------------------------------
    -- BUILD
    --------------------------------------------------

    self:Build()

    --------------------------------------------------
    -- CONNECTIONS
    --------------------------------------------------

    self:Connect()

    Initialized =
        true

    notify(
        "Lobby",
        "Lobby features loaded."
    )

    return self
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

    Initialized = false
    Built = false

end

return Lobby
