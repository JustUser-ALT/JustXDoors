-- Just X Hub — Lobby
-- Полный перенос Abysall Hub Lobby на JustLib API
-- Оригинал: bocaj111004/Abysall — Lobby.luau

local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustLib/refs/heads/main/JustLib.lua"))()

local LP           = game:GetService("Players").LocalPlayer
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesFolder = ReplicatedStorage:WaitForChild("RemotesFolder")

while not LP.Character do task.wait() end
task.wait(1)

---------------------------------------------------------
-- Окно
---------------------------------------------------------
local Win = Lib:Window({
    Title  = "Just X Hub",
    Icon   = "🗡️",
    Config = "JustXHub_Lobby",
    Hotkey = Enum.KeyCode.RightShift,
    Settings = true,
})

---------------------------------------------------------
-- Вкладки
---------------------------------------------------------
local GeneralTab = Win:Tab({ Label = "General", Icon = "🏠" })

---------------------------------------------------------
-- Состояния
---------------------------------------------------------
local autoJoinEnabled   = false
local autoJoinTarget    = nil
local cycleAchievements = false
local cycleDelay        = 0.1
local redeemingCodes    = false

local unlockedBadges = {}
local previousBadge  = nil

---------------------------------------------------------
-- Коды для автопогашения
---------------------------------------------------------
local codesList = {
    "67", "54", "41",
    "CHEDDAR BALLS", "XQC", "PENGUINZ0", "KREEKCRAFT",
    "ISHOWSPEED", "DANTDM", "KUBZ SCOUTS", "FIND THE TROLLFACES",
    "THINKNOODLES", "W", "RAGDOLL UNIVERSE", "RAGDOLL MAYHEM",
    "BIJUU MIKE", "8BITRYAN", "SCREECHSUCKS", "LORE",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "3rd", "LAZYDEVS",
    "RAGDOLL COMBAT", "VOCAB HAVOC", "PATHSWAP", "JUMP OVER THE BRICK"
}

---------------------------------------------------------
-- Функции
---------------------------------------------------------
local function notify(title, body)
    Lib:Notify({ Title = title, Desc = body or "", Type = "Info", Duration = 5 })
end

local function checkElevators()
    if not autoJoinEnabled then return end
    local targetChar
    if typeof(autoJoinTarget) == "Instance" then
        targetChar = autoJoinTarget.Character
    elseif typeof(autoJoinTarget) == "string" and autoJoinTarget ~= "" then
        local p = game:GetService("Players"):FindFirstChild(autoJoinTarget)
        if p then targetChar = p.Character end
    end
    if not targetChar then
        pcall(function() RemotesFolder.ElevatorExit:FireServer() end)
        return
    end

    local found = false
    local lobbyElevators = workspace:FindFirstChild("Lobby")
    if lobbyElevators then
        lobbyElevators = lobbyElevators:FindFirstChild("LobbyElevators")
    end
    if lobbyElevators then
        for _, elevator in pairs(lobbyElevators:GetChildren()) do
            if targetChar:GetAttribute("InGameElevator")
               and elevator:GetAttribute("ID")
               and elevator:GetAttribute("ID") == targetChar:GetAttribute("InGameElevator")
            then
                found = true
                pcall(function() RemotesFolder.ElevatorJoin:FireServer(elevator) end)
            end
        end
    end
    if not found then
        pcall(function() RemotesFolder.ElevatorExit:FireServer() end)
    end
end

local function createElevator(destination)
    pcall(function()
        RemotesFolder.CreateElevator:FireServer({
            Mods        = {},
            Settings    = {},
            Destination = destination,
            FriendsOnly = false,
            MaxPlayers  = "1"
        })
    end)
end

local function createElevatorFree(destination)
    pcall(function()
        RemotesFolder.CreateElevator:FireServer({
            Mods        = { "AdminPanel" },
            Settings    = {},
            Destination = destination,
            FriendsOnly = false,
            MaxPlayers  = "1"
        })
    end)
end

---------------------------------------------------------
-- Собираем разблокированные бейджи
---------------------------------------------------------
task.spawn(function()
    pcall(function()
        local list = LP.PlayerGui.MainUI.LobbyFrame.Achievements.List
        for _, frame in pairs(list:GetChildren()) do
            if frame:IsA("ImageButton") and frame.ImageTransparency == 0 then
                table.insert(unlockedBadges, frame.Name)
            end
        end
        list.ChildAdded:Connect(function(frame)
            RunService.Heartbeat:Wait()
            if frame:IsA("ImageButton") and frame.ImageTransparency == 0 then
                table.insert(unlockedBadges, frame.Name)
            end
        end)
    end)
end)

---------------------------------------------------------
-- Главный цикл (авто лифт + цикл бейджей)
---------------------------------------------------------
local lastElevatorCheck = tick()
local lastBadgeChange   = tick()

RunService.Heartbeat:Connect(function()
    if tick() - lastElevatorCheck > 0.25 then
        pcall(checkElevators)
        lastElevatorCheck = tick()
    end

    if cycleAchievements and tick() - lastBadgeChange > cycleDelay then
        pcall(function()
            if #unlockedBadges == 0 then return end
            local badge = unlockedBadges[math.random(1, #unlockedBadges)]
            if badge == previousBadge then
                local tries = 0
                while tries < 20 do
                    local nb = unlockedBadges[math.random(1, #unlockedBadges)]
                    if nb ~= previousBadge then badge = nb break end
                    tries += 1
                end
            end
            local list = LP.PlayerGui.MainUI.LobbyFrame.Achievements.List
            for _, frame in pairs(list:GetChildren()) do
                if frame:IsA("ImageButton") and frame.ImageTransparency == 0 then
                    local star = frame:FindFirstChild("Icons") and frame.Icons:FindFirstChild("Star")
                    if star then star.Visible = false end
                end
            end
            RemotesFolder:WaitForChild("FlexAchievement"):FireServer(badge)
            previousBadge = badge
            local chosen = list:FindFirstChild(badge)
            if chosen then
                local star = chosen:FindFirstChild("Icons") and chosen.Icons:FindFirstChild("Star")
                if star then star.Visible = true end
            end
        end)
        lastBadgeChange = tick()
    end
end)

---------------------------------------------------------
-- GUI — Self
---------------------------------------------------------
local selfSec = GeneralTab:Section({ Title = "Self", Column = "left" })

selfSec:Toggle({
    Name     = "Auto Join Elevator",
    Flag     = "Lobby_AutoJoinElevator",
    Default  = false,
    Callback = function(v) autoJoinEnabled = v end
})

-- Дропдаун с именами игроков
do
    local playerNames = {}
    for _, p in pairs(game:GetService("Players"):GetPlayers()) do
        if p ~= LP then table.insert(playerNames, p.Name) end
    end
    game:GetService("Players").PlayerAdded:Connect(function(p)
        if p ~= LP then table.insert(playerNames, p.Name) end
    end)
    game:GetService("Players").PlayerRemoving:Connect(function(p)
        for i, n in ipairs(playerNames) do
            if n == p.Name then table.remove(playerNames, i) break end
        end
        if autoJoinTarget == p.Name then autoJoinTarget = nil end
    end)
    selfSec:Dropdown({
        Name    = "Target Player",
        Flag    = "Lobby_AutoJoinTarget",
        Options = playerNames,
        Default = "",
        Callback = function(v) autoJoinTarget = v end
    })
end

---------------------------------------------------------
-- GUI — Automation
---------------------------------------------------------
local autoSec = GeneralTab:Section({ Title = "Automation", Column = "left" })

autoSec:Toggle({
    Name     = "Cycle Achievements",
    Flag     = "Lobby_CycleAchievements",
    Default  = false,
    Callback = function(v) cycleAchievements = v end
})

autoSec:Slider({
    Name     = "Cycle Delay (s)",
    Flag     = "Lobby_CycleDelay",
    Min      = 0.05,
    Max      = 1,
    Default  = 0.1,
    Decimals = 2,
    Callback = function(v) cycleDelay = v end
})

autoSec:Divider()

autoSec:Button({
    Name = "Redeem All Codes",
    Callback = function()
        if redeemingCodes then return end
        redeemingCodes = true
        notify("Redeeming " .. #codesList .. " codes.", "Please wait...")
        task.spawn(function()
            for _, code in pairs(codesList) do
                pcall(function() RemotesFolder.ShopCode:FireServer(code) end)
                task.wait(5.1)
            end
            redeemingCodes = false
            notify("Done!", "All codes redeemed.")
        end)
    end
})

---------------------------------------------------------
-- GUI — Quick Play
---------------------------------------------------------
local quickSec = GeneralTab:Section({ Title = "Quick Play", Column = "right" })

local quickPlayEntries = {
    { label = "The Hotel",     dest = "Hotel"         },
    { label = "The Mines",     dest = "Mines"         },
    { label = "The Backdoor",  dest = "Backdoor"      },
    { label = "The Rooms",     dest = "Rooms"         },
    { label = "The Outdoors",  dest = "Garden"        },
}
for _, e in ipairs(quickPlayEntries) do
    quickSec:Button({ Name = e.label, Callback = function() createElevator(e.dest) end })
end

quickSec:Divider()

local modeEntries = {
    { label = "Battle Mode",    dest = "Party"         },
    { label = "Retro Mode",     dest = "Retro"         },
    { label = "Rush Mode",      dest = "Fools26"       },
}
for _, e in ipairs(modeEntries) do
    quickSec:Button({ Name = e.label, Callback = function() createElevator(e.dest) end })
end

quickSec:Divider()

local eventEntries = {
    { label = "Halloween",      dest = "Halloween25"   },
    { label = "Hotel-",         dest = "BeforePlus"    },
    { label = "Super Hard Mode",dest = "SuperHardMode" },
}
for _, e in ipairs(eventEntries) do
    quickSec:Button({ Name = e.label, Callback = function() createElevator(e.dest) end })
end

quickSec:Divider()

quickSec:Button({
    Name = "The Rooms [Free, No Progress]",
    Callback = function() createElevatorFree("Rooms") end
})
quickSec:Button({
    Name = "The Outdoors [Free, No Progress]",
    Callback = function() createElevatorFree("Garden") end
})

---------------------------------------------------------
-- Загружено
---------------------------------------------------------
Win:Settings()
notify("Just X Hub — Lobby", "Loaded! Press RightShift to toggle.")
