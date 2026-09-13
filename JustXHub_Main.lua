local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/JustUser-ALT/JustLib/refs/heads/main/JustLib.lua"))()

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local SoundService     = game:GetService("SoundService")
local Lighting         = game:GetService("Lighting")
local TextChatService  = game:GetService("TextChatService")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local RemotesFolder    = ReplicatedStorage:FindFirstChild("RemotesFolder")
local LiveModifiers    = ReplicatedStorage:FindFirstChild("LiveModifiers") or Instance.new("Folder")
local FloorReplicated  = ReplicatedStorage:FindFirstChild("FloorReplicated") or Instance.new("Folder")
local CurrentRooms     = workspace:FindFirstChild("CurrentRooms")
local Drops            = workspace:FindFirstChild("Drops")
local GameData   = ReplicatedStorage:WaitForChild("GameData", 10)
local Floor      = GameData and GameData:WaitForChild("Floor", 5) and GameData:WaitForChild("Floor", 5).Value or "Hotel"
local LatestRoom = GameData and GameData:WaitForChild("LatestRoom", 5)

if Floor == "Hotel" and RemotesFolder and RemotesFolder.Name == "Bricks" then
    Floor = "OldHotel"
end
if not RemotesFolder then
    RemotesFolder = ReplicatedStorage:FindFirstChild("EntityInfo")
              or ReplicatedStorage:FindFirstChild("Bricks")
              or Instance.new("Folder")
end

local Character, Humanoid, RootPart
local Collision, CollisionClone, CollisionPart, CollisionPartClone
local OldJump, OldSlide
local Main_Game

---------------------------------------------------------
-- Глобальное состояние
---------------------------------------------------------
local Globals = {
    FogInstances      = {},
    OldFog            = Lighting.FogEnd,
    SpoofOffset       = 0,
    AutoClosetActive  = false,
    AnticheatDisabled = false,
    IsEyes            = false,
    IsLookman         = false,
    RoomsAutoWalkActive = false,
    LibraryCodeFound  = false,
    UsedRandomCodes   = {},
    ThirdPersonParts  = {},
    SelfKilled        = false,
}

local Objects = {
    Prompts          = {},
    Objectives       = {},
    Doors            = {},
    HidingSpots      = {},
    Entities         = {},
    SeekObstructions = {},
    Items            = {},
    Chests           = {},
    Currency         = {},
    Ladders          = {},
    Obstructions     = {},
    EventTriggers    = {},
    SeekHighlights   = {},
    EyestalkHighlights = {},
    SeekNodes        = {},
    SeekDuckBoards   = {},
    SeekBridges      = {},
    PathLights       = {},
}

local Connections    = {}
local ESPConnections = {}
local FakePrompts    = {}
local PartProperties = {}
local ESPBlacklist   = {}

---------------------------------------------------------
-- FakeEvents для блокировки урона
---------------------------------------------------------
local FakeEvents = {
    Screech = Instance.new("RemoteEvent"),
    Shade   = Instance.new("RemoteEvent"),
    A90     = Instance.new("RemoteEvent"),
    Surge   = Instance.new("RemoteEvent"),
}
FakeEvents.Screech.Name = "Screech"
FakeEvents.Shade.Name   = "ShadeResult"
FakeEvents.A90.Name     = "A90"
FakeEvents.Surge.Name   = "SurgeRemote"

FakeEvents.Screech_Real = RemotesFolder:WaitForChild("Screech", 5)
FakeEvents.Shade_Real   = RemotesFolder:WaitForChild("ShadeResult", 5)
FakeEvents.A90_Real     = RemotesFolder:FindFirstChild("A90")
FakeEvents.Surge_Real   = RemotesFolder:FindFirstChild("SurgeRemote")

Globals.SeekNodesFolder = Instance.new("Folder")
Globals.SeekNodesFolder.Name = "JXH_SeekNodes"
Globals.SeekNodesFolder.Parent = workspace
Globals.RoomsNodesFolder = Instance.new("Folder")
Globals.RoomsNodesFolder.Name = "JXH_RoomsNodes"
Globals.RoomsNodesFolder.Parent = workspace

local EntityData = {
    ["RushMoving"]      = { Alias = "Rush",            Notify = { Title = "Rush spawned!",            Body = "Find a hiding spot."              } },
    ["AmbushMoving"]    = { Alias = "Ambush",          Notify = { Title = "Ambush spawned!",          Body = "Find a hiding spot."              } },
    ["Eyes"]            = { Alias = "Eyes",            Notify = { Title = "Eyes spawned!",            Body = "Avoid looking at it."             } },
    ["Lookman"]         = { Alias = "Eyes",            Notify = { Title = "Eyes spawned!",            Body = "Avoid looking at it."             } },
    ["BackdoorRush"]    = { Alias = "Blitz",           Notify = { Title = "Blitz spawned!",           Body = "Find a hiding spot."              } },
    ["BackdoorLookman"] = { Alias = "Lookman",         Notify = { Title = "Lookman spawned!",         Body = "Avoid looking at its eyes."       } },
    ["Groundskeeper"]   = { Alias = "Groundskeeper",   Notify = { Title = "Groundskeeper spawned!",   Body = "Avoid the grass."                 } },
    ["A60"]             = { Alias = "A-60",            Notify = { Title = "A-60 spawned!",            Body = "Find a hiding spot."              } },
    ["A120"]            = { Alias = "A-120",           Notify = { Title = "A-120 spawned!",           Body = "Find a hiding spot."              } },
    ["GloombatSwarm"]   = { Alias = "Gloombat Swarm",  Notify = { Title = "Gloombat Swarm spawned!",  Body = "Turn off all light sources."      } },
    ["GlitchRush"]      = { Alias = "RNIUSHCG==",      Notify = { Title = "RNIUSHCG== spawned!",      Body = "Find a hiding spot."              } },
    ["GlitchAmbush"]    = { Alias = "AR0xMBUSH",       Notify = { Title = "AR0xMBUSH spawned!",       Body = "Find a hiding spot."              } },
    ["MonumentEntity"]  = { Alias = "Monument",        Notify = { Title = "Monument spawned!",        Body = "Don't look away from it."         } },
    ["JeffTheKiller"]   = { Alias = "Jeff the Killer", Notify = { Title = "Jeff the Killer spawned!", Body = "Avoid touching him."              } },
    ["CustomEntity"]    = { Alias = "Custom Entity",   Notify = { Title = "Custom Entity spawned!",   Body = "Find a hiding spot."              } },
    ["FrozenAmbush"]    = { Alias = "Frozen Ambush",   Notify = { Title = "Frozen Ambush spawned!",   Body = "Find a hiding spot."              } },
    ["SallyMoving"]     = { Alias = "Sally",           Notify = { Title = "Sally spawned!",           Body = "Drop an item for her."            } },
}

local EntityIcons = {
    ["RushMoving"]      = "rbxassetid://10716032262",
    ["AmbushMoving"]    = "rbxassetid://10110576663",
    ["A60"]             = "rbxassetid://12571092295",
    ["A120"]            = "rbxassetid://12711591665",
    ["BackdoorRush"]    = "rbxassetid://16602023490",
    ["Eyes"]            = "rbxassetid://10183704772",
    ["Lookman"]         = "rbxassetid://10183704772",
    ["BackdoorLookman"] = "rbxassetid://16764872677",
    ["GloombatSwarm"]   = "rbxassetid://79221203116470",
    ["JeffTheKiller"]   = "rbxassetid://94479432156278",
    ["GlitchRush"]      = "rbxassetid://73859273102919",
    ["GlitchAmbush"]    = "rbxassetid://88369678433359",
    ["SallyMoving"]     = "rbxassetid://10840888070",
    ["MonumentEntity"]  = "rbxassetid://88933556873017",
    ["Groundskeeper"]   = "rbxassetid://114991380115557",
}

local EntityDistances = {
    ["RushMoving"]   = 85,  ["AmbushMoving"] = 150, ["A60"]         = 125,
    ["A120"]         = 85,  ["GlitchRush"]   = 90,  ["GlitchAmbush"]= 175,
    ["BackdoorRush"] = 85,  ["CustomEntity"] = 85,
}

local RusherAliases = {
    Rush=true, Ambush=true, Eyes=true, Lookman=true, Blitz=true,
    ["A-60"]=true, ["A-120"]=true, AR0xMBUSH=true, ["RNIUSHCG=="]=true, ["Custom Entity"]=true
}

local ItemNames = {
    ["Lighter"]="Lighter",["Flashlight"]="Flashlight",["Lockpick"]="Lockpicks",
    ["Vitamins"]="Vitamins",["Bandage"]="Bandage",["StarVial"]="Starlight Vial",
    ["StarBottle"]="Starlight Bottle",["StarJug"]="Starlight Barrel",
    ["Shakelight"]="Gummy Flashlight",["Straplight"]="Straplight",["Bulklight"]="Spotlight",
    ["Battery"]="Battery",["Candle"]="Candle",["Crucifix"]="Crucifix",
    ["CrucifixWall"]="Crucifix",["Glowsticks"]="Glowstick",["SkeletonKey"]="Skeleton Key",
    ["Candy"]="Candy",["ShieldMini"]="Mini Shield Potion",["ShieldBig"]="Big Shield Potion",
    ["BandagePack"]="Bandage Pack",["BatteryPack"]="Battery Pack",["RiftCandle"]="Moonlight Candle",
    ["LaserPointer"]="Laser Pointer",["HolyGrenade"]="Holy Hand Grenade",["Shears"]="Shears",
    ["Smoothie"]="Smoothie",["Cheese"]="Cheese",["Bread"]="Bread",["AlarmClock"]="Alarm Clock",
    ["RiftSmoothie"]="Moonlight Smoothie",["GweenSoda"]="Gween Soda",["GlitchCube"]="Glitch Fragment",
    ["Scanner"]="Tablet",["Bomb"]="Bomb",["Knockbomb"]="Knockbomb",["Nanner"]="Nanner",
    ["BigBomb"]="Big Bomb",["SnakeBox"]="Hiding Box",["GoldGun"]="Golden Gun",
    ["StopSign"]="Stop Sign",["TipJar"]="Tip Jar",["Lantern"]="Lantern",["IronKey"]="Iron Key",
    ["LotusPetal"]="Lotus Petal",["Compass"]="Compass",["LotusPetalPickup"]="Lotus Petal",
    ["LanternLitItem"]="Lantern",["KeyIron"]="Iron Key",["IronKeyForCrypt"]="Iron Key",
    ["LotusHolder"]="Lotus Petal",["Multitool"]="Multitool",["RiftJar"]="Rift Jar",
    ["AloeVera"]="Aloe Vera",["Donut"]="Donut",["Lotus"]="Lotus",["BoxingGloves"]="Boxing Gloves",
}

local HidingSpotLabels = {
    Wardrobe="Wardrobe", Closet="Closet", Bed="Bed", Desk="Desk", Couch="Couch",
    Barrel="Barrel", BookshelfHideable="Bookshelf", WoodenCrate="Wooden Crate",
    StoneBarrel="Stone Barrel",
}

local CutsceneNames = {
    "Figure","FigureEnd","FigureHotelEnd","FigureHotelFire",
    "SeekIntroFools","SeekIntroHotel","SeekIntroMines","SeekIntroMines2",
    "SerewSeekDrain","SewerSeekLower","GrumbleNestEnd","EyestalkIntro",
}

---------------------------------------------------------
-- Вспомогательные функции
---------------------------------------------------------
local function notify(title, body, dur)
    Lib:Notify({ Title = title, Desc = body or "", Type = "Info", Duration = dur or 5 })
end

local function sendChat(msg)
    pcall(function()
        local folder = ReplicatedStorage:FindFirstChild("DefaultChatSystemEvents")
        local event = folder and folder:FindFirstChild("SayMessageRequest")
        if event then event:FireServer(msg, "All") end
        local ch = TextChatService:FindFirstChild("TextChannels")
        ch = ch and ch:FindFirstChild("RBXGeneral")
        if ch then ch:SendAsync(msg) end
    end)
end

local function hasItem(name, onlyChar)
    if not onlyChar and LP.Backpack:FindFirstChild(name) then return LP.Backpack:FindFirstChild(name) end
    if Character and Character:FindFirstChild(name) then return Character:FindFirstChild(name) end
end

local function isCrouching()
    if Floor == "Fools" or Floor == "OldHotel" then
        return Character and Character:GetAttribute("Crouching")
    end
    return CollisionPart and CollisionPart.CollisionGroup == "PlayerCrouching"
end

local function getInjuriesSpeed()
    if not Humanoid then return 0 end
    return 0.075 * (Humanoid.MaxHealth - Humanoid.Health)
end

local function getCurrentSpeed()
    local speed = 15
    if Character then
        speed += Character:GetAttribute("SpeedBoost") or 0
        speed += Character:GetAttribute("SpeedBoostBehind") or 0
        speed += Character:GetAttribute("SpeedBoostExtra") or 0
    end
    speed += Floor == "Party" and 10 or 0
    speed += LiveModifiers:FindFirstChild("PlayerFast") and 3 or 0
    speed += LiveModifiers:FindFirstChild("PlayerFaster") and 6 or 0
    speed += LiveModifiers:FindFirstChild("PlayerFastest") and 20 or 0
    speed -= LiveModifiers:FindFirstChild("PlayerSlow") and 3 or 0
    speed -= LiveModifiers:FindFirstChild("PlayerSlowHealth") and getInjuriesSpeed() or 0
    if isCrouching() then
        if LiveModifiers:FindFirstChild("PlayerCrouchSlow") then speed -= 8
        elseif LiveModifiers:FindFirstChild("PlayerSlow") then speed -= 8
        else speed -= 5 end
    end
    return speed
end

local function isHidePersistent()
    return Floor == "Mines" or Floor == "Ripple" or Floor == "Party"
        or LiveModifiers:FindFirstChild("HideLevel2") ~= nil
end

local function getMinecart()
    return Camera:FindFirstChild("MinecartRig") ~= nil
end

local function getLibraryCode()
    local paper = Character and (Character:FindFirstChild("LibraryHintPaper") or Character:FindFirstChild("LibraryHintPaperHard"))
               or LP.Backpack:FindFirstChild("LibraryHintPaper") or LP.Backpack:FindFirstChild("LibraryHintPaperHard")
    if paper and paper:FindFirstChild("UI") then
        local code = {}
        local codeLen = Floor == "Fools" and 10 or 5
        for i = 1, codeLen do code[i] = "_" end
        local hints = LP.PlayerGui.PermUI.Hints:GetChildren()
        local uis   = paper.UI:GetChildren()
        for _, hint in hints do
            for _, ui in uis do
                if hint:IsA("ImageLabel") and ui:IsA("ImageLabel")
                    and hint.ImageRectOffset == ui.ImageRectOffset
                    and code[tonumber(ui.Name)]
                then
                    code[tonumber(ui.Name)] = hint.TextLabel.Text
                end
            end
        end
        return table.concat(code)
    end
    return Floor == "Fools" and "__________" or "_____"
end

local function getRandomCode()
    local tmpl = getLibraryCode()
    if not tmpl then return nil end
    local new
    local tries = 0
    repeat
        new = tmpl:gsub("_", function() return tostring(math.random(0,9)) end)
        tries += 1
    until not Globals.UsedRandomCodes[new] or tries >= 10
    Globals.UsedRandomCodes[new] = true
    return new
end

local function getDoorNumber(obj)
    local n = tonumber(obj.Parent.Name) or tonumber(obj.Parent.Parent.Name)
    if n then n = n + 1 end
    if Floor == "Mines"    then n = n + 100 end
    if Floor == "Backdoor" then n = n - 50  end
    return tostring(n)
end

---------------------------------------------------------
-- ESP (через Highlight + BillboardGui)
---------------------------------------------------------
local espObjects = {}

local espSettings = {
    fillTransparency    = 0.75,
    outlineTransparency = 0,
    textTransparency    = 0,
    showDistance        = true,
    rainbow             = false,
    renderLimit         = 150,
}

local function addESP(obj, label, color)
    if table.find(ESPBlacklist, obj) then return end
    if espObjects[obj] then return end

    local hl = Instance.new("Highlight")
    hl.FillColor    = color or Color3.fromRGB(255,255,255)
    hl.OutlineColor = color or Color3.fromRGB(255,255,255)
    hl.FillTransparency    = espSettings.fillTransparency
    hl.OutlineTransparency = espSettings.outlineTransparency
    hl.Adornee = obj
    hl.Parent  = workspace

    local bb, lbl
    if label then
        bb = Instance.new("BillboardGui")
        bb.AlwaysOnTop = true
        bb.Size = UDim2.new(0,200,0,40)
        bb.StudsOffsetWorldSpace = Vector3.new(0,3,0)
        bb.Adornee = (obj:IsA("Model") and obj.PrimaryPart) or (obj:IsA("BasePart") and obj) or nil
        bb.Parent = workspace
        lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = color or Color3.fromRGB(255,255,255)
        lbl.Text = label
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 14
        lbl.Parent = bb
    end

    espObjects[obj] = { hl=hl, bb=bb, lbl=lbl, color=color, label=label }
end

local function removeESP(obj)
    local d = espObjects[obj]
    if not d then return end
    if d.hl and d.hl.Parent then d.hl:Destroy() end
    if d.bb and d.bb.Parent then d.bb:Destroy() end
    espObjects[obj] = nil
    local conn = ESPConnections[obj]
    if conn then conn:Disconnect() ESPConnections[obj] = nil end
end

local function blacklistESP(obj)
    table.insert(ESPBlacklist, obj)
    removeESP(obj)
end

local function addESPRoombased(obj, label, color)
    if table.find(ESPBlacklist, obj) then return end
    local currentRoom = tonumber(LP:GetAttribute("CurrentRoom"))
    local objectRoom  = tonumber(obj:GetAttribute("ParentRoom"))
    if objectRoom == currentRoom or (table.find(Objects.Doors, obj) and objectRoom == currentRoom + 1) then
        addESP(obj, label, color)
    end
    local conn = LP:GetAttributeChangedSignal("CurrentRoom"):Connect(function()
        local nr = tonumber(LP:GetAttribute("CurrentRoom"))
        local or2 = tonumber(obj:GetAttribute("ParentRoom"))
        if or2 == nr or (table.find(Objects.Doors, obj) and or2 == nr + 1) then
            addESP(obj, label, color)
        else
            removeESP(obj)
        end
    end)
    table.insert(Connections, conn)
    ESPConnections[obj] = conn
    obj.Destroying:Once(function()
        conn:Disconnect()
        removeESP(obj)
    end)
end

-- ESP distance updater
RunService.Heartbeat:Connect(function()
    if not RootPart then return end
    for obj, d in pairs(espObjects) do
        if not obj.Parent then removeESP(obj) continue end
        if d.lbl and espSettings.showDistance then
            local pos
            if obj:IsA("Model") and obj.PrimaryPart then pos = obj.PrimaryPart.Position
            elseif obj:IsA("BasePart") then pos = obj.Position end
            if pos then
                local dist = math.round((RootPart.Position - pos).Magnitude)
                d.lbl.Text = (d.label or "?") .. " [" .. dist .. "]"
            end
        end
        if espSettings.rainbow and d.hl then
            local hue = (tick() * 0.3) % 1
            local c = Color3.fromHSV(hue, 1, 1)
            d.hl.FillColor = c
            d.hl.OutlineColor = c
            if d.lbl then d.lbl.TextColor3 = c end
        end
    end
end)

---------------------------------------------------------
-- FirePrompt
---------------------------------------------------------
local function firePrompt(prompt)
    if not prompt or not prompt.Parent then return end
    pcall(function()
        local old = {
            dist = prompt.MaxActivationDistance,
            en   = prompt.Enabled,
            hold = prompt.HoldDuration,
            los  = prompt.RequiresLineOfSight,
        }
        prompt.MaxActivationDistance = 99999
        prompt.Enabled = true
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt:InputHoldBegin()
        task.wait(0.05)
        prompt:InputHoldEnd()
        task.wait(0.1)
        prompt.MaxActivationDistance = old.dist
        prompt.Enabled = old.en
        prompt.HoldDuration = old.hold
        prompt.RequiresLineOfSight = old.los
    end)
end

---------------------------------------------------------
-- Окно
---------------------------------------------------------
local Win = Lib:Window({
    Title    = "Just X Hub",
    Icon     = "🗡️",
    Config   = "JustXHub_Main",
    Hotkey   = Enum.KeyCode.RightShift,
    Settings = true,
})

---------------------------------------------------------
-- Вкладки
---------------------------------------------------------
local GeneralTab  = Win:Tab({ Label = "General",  Icon = "⌂"  })
local ExploitsTab = Win:Tab({ Label = "Exploits", Icon = "⚡" })
local VisualsTab  = Win:Tab({ Label = "Visuals",  Icon = "👁"  })
local FloorsTab   = Win:Tab({ Label = "Floors",   Icon = "🏠"  })

---------------------------------------------------------
-- GENERAL TAB
---------------------------------------------------------
-- Self
local selfSec = GeneralTab:Section({ Title = "Self", Column = "left" })

local speedEnabled = false
local speedValue   = 16
local flyEnabled   = false
local flySpeed     = 24
local noclipEnabled = false
local infiniteJumps = false
local infiniteStamina = false
local fovValue     = 70
local thirdPerson  = false
local removeFog    = false
local removeCameraBobbing = false

selfSec:Toggle({ Name="Speed Hack",       Flag="G_Speed",         Default=false, Callback=function(v) speedEnabled=v
    if not v and Humanoid then Humanoid.WalkSpeed = getCurrentSpeed() end end })
selfSec:Slider({ Name="Walk Speed",       Flag="G_SpeedVal",      Min=1, Max=100, Default=16, Decimals=0,
    Callback=function(v) speedValue=v end })
selfSec:Divider()
selfSec:Toggle({ Name="Fly",              Flag="G_Fly",           Default=false, Callback=function(v) flyEnabled=v end })
selfSec:Slider({ Name="Fly Speed",        Flag="G_FlySpeed",      Min=5, Max=150, Default=24, Decimals=0,
    Callback=function(v) flySpeed=v end })
selfSec:Divider()
selfSec:Toggle({ Name="Noclip",           Flag="G_Noclip",        Default=false, Callback=function(v) noclipEnabled=v end })
selfSec:Toggle({ Name="Infinite Jumps",   Flag="G_InfJumps",      Default=false, Callback=function(v) infiniteJumps=v end })
selfSec:Toggle({ Name="Infinite Stamina", Flag="G_InfStamina",    Default=false, Callback=function(v) infiniteStamina=v end })
selfSec:Divider()
selfSec:Toggle({ Name="Remove Camera Bobbing", Flag="G_NoBob",    Default=false, Callback=function(v)
    removeCameraBobbing=v
    if Main_Game then Main_Game.spring.Speed = v and 9e9 or 8 end end })
selfSec:Slider({ Name="Field of View",    Flag="G_FOV",           Min=50, Max=120, Default=70, Decimals=0,
    Callback=function(v) fovValue=v end })
selfSec:Toggle({ Name="Third Person",     Flag="G_ThirdPerson",   Default=false, Callback=function(v) thirdPerson=v end })
selfSec:Toggle({ Name="Remove Fog",       Flag="G_RemoveFog",     Default=false, Callback=function(v)
    removeFog=v
    Lighting.FogEnd = v and 9e9 or Globals.OldFog
    for _, atmo in Globals.FogInstances do atmo.Density = v and 0 or (atmo:GetAttribute("Density_Old") or 0) end
end })

-- Automation
local autoSec = GeneralTab:Section({ Title = "Automation", Column = "left" })

local autoLootEnabled    = false
local lootReach          = 10
local autoInteract       = false
local autoHide           = false
local autoRevive         = false
local autoUnlockPadlock  = false
local unlockDist         = 10
local notifyEntities     = false
local notifyItems        = false
local notifyLibCode      = false
local entityChatEnabled  = false
local entityChatMsg      = "is nearby!"
local autoGuessLibCode   = false

autoSec:Toggle({ Name="Auto Loot",         Flag="A_Loot",     Default=false, Callback=function(v) autoLootEnabled=v end })
autoSec:Slider({ Name="Loot Reach",        Flag="A_LootReach",Min=1,Max=50,Default=10,Decimals=0,
    Callback=function(v) lootReach=v end })
autoSec:Divider()
autoSec:Toggle({ Name="Auto Interact",     Flag="A_Interact", Default=false, Callback=function(v) autoInteract=v end })
autoSec:Toggle({ Name="Auto Closet (Hide)",Flag="A_AutoHide", Default=false, Callback=function(v) autoHide=v end })
autoSec:Toggle({ Name="Auto Revive",       Flag="A_AutoRevive",Default=false,Callback=function(v) autoRevive=v end })
autoSec:Divider()
autoSec:Toggle({ Name="Auto Unlock Padlock",Flag="A_Padlock",Default=false,Callback=function(v) autoUnlockPadlock=v end })
autoSec:Slider({ Name="Unlock Distance",   Flag="A_PadlockDist",Min=1,Max=50,Default=10,Decimals=0,
    Callback=function(v) unlockDist=v end })
autoSec:Toggle({ Name="Guess Library Code",Flag="A_LibGuess",Default=false,Callback=function(v) autoGuessLibCode=v end })

-- Misc
local miscSec = GeneralTab:Section({ Title = "Miscellaneous", Column = "right" })
miscSec:Button({ Name="Play Again",       Callback=function() pcall(function() RemotesFolder.PlayAgain:FireServer() end) end })
miscSec:Button({ Name="Return to Lobby",  Callback=function() pcall(function() RemotesFolder.Lobby:FireServer() end) end })
miscSec:Button({ Name="Revive",           Callback=function() pcall(function() RemotesFolder.Revive:FireServer() end) end })
miscSec:Button({ Name="Reset Character",  Callback=function()
    Globals.SelfKilled = true
    pcall(function()
        if RemotesFolder:FindFirstChild("Underwater") then
            RemotesFolder.Underwater:FireServer(true)
        elseif Humanoid then
            Humanoid.Health = 0
        end
    end)
end })

-- Notify
local notifySec = GeneralTab:Section({ Title = "Notifications", Column = "right" })
notifySec:Toggle({ Name="Notify Entities",   Flag="N_Entities", Default=true,  Callback=function(v) notifyEntities=v end })
notifySec:Toggle({ Name="Notify Items",      Flag="N_Items",    Default=false, Callback=function(v) notifyItems=v end })
notifySec:Toggle({ Name="Notify Library Code",Flag="N_LibCode", Default=false, Callback=function(v) notifyLibCode=v end })
notifySec:Divider()
notifySec:Toggle({ Name="Entity Chat Alert", Flag="N_EntityChat",Default=false,Callback=function(v) entityChatEnabled=v end })

---------------------------------------------------------
-- EXPLOITS TAB
---------------------------------------------------------
-- Bypass
local bypassSec = ExploitsTab:Section({ Title = "Bypass", Column = "left" })

local bypassGiggle=false
local bypassDupe=false
local bypassEyes=false
local bypassLookman=false
local bypassGloombat=false
local bypassSeekObs=false
local bypassVacuum=false
local bypassKillbrick=false
local bypassSeekWall=false
local bypassSnare=false
local bypassBanana=false
local bypassJeff=false

bypassSec:Toggle({ Name="Bypass Giggle",            Flag="B_Giggle",    Default=false, Callback=function(v) bypassGiggle=v
    for _, obj in Objects.Entities do if obj.Name=="GiggleCeiling" then pcall(function() obj:WaitForChild("Hitbox").CanTouch=not v end) end end end })
bypassSec:Toggle({ Name="Bypass Dupe",              Flag="B_Dupe",      Default=false, Callback=function(v) bypassDupe=v
    for _, obj in Objects.Entities do if obj.Name=="DoorFake" or obj.Name=="FakeDoor" then
        pcall(function() obj:WaitForChild("Hidden").CanTouch=not v end)
        if obj:FindFirstChild("Lock") then pcall(function() obj.Lock.UnlockPrompt.Enabled=not v end) end
    end end end })
bypassSec:Toggle({ Name="Bypass Eyes",              Flag="B_Eyes",      Default=false, Callback=function(v) bypassEyes=v end })
bypassSec:Toggle({ Name="Bypass Lookman",           Flag="B_Lookman",   Default=false, Callback=function(v) bypassLookman=v end })
bypassSec:Toggle({ Name="Bypass Gloombat Eggs",     Flag="B_Gloombat",  Default=false, Callback=function(v) bypassGloombat=v end })
bypassSec:Toggle({ Name="Bypass Seek Obstructions", Flag="B_SeekObs",   Default=false, Callback=function(v) bypassSeekObs=v
    for _, obj in Objects.SeekObstructions do obj.CanTouch=not v if obj.Name=="SeekFloodline" then obj.CanCollide=v end end
    for _, obj in Objects.SeekBridges do obj.CanCollide=v obj.Transparency=v and 0 or 1 end end })
bypassSec:Toggle({ Name="Bypass Vacuum",            Flag="B_Vacuum",    Default=false, Callback=function(v) bypassVacuum=v
    for _, obj in Objects.Entities do if obj.Name=="SideroomSpace" then
        pcall(function() obj:WaitForChild("Collision").CanCollide=v obj:WaitForChild("Collision").CanTouch=not v end) end end end })
bypassSec:Toggle({ Name="Bypass Killbricks",        Flag="B_Killbrick", Default=false, Callback=function(v) bypassKillbrick=v
    for _, obj in Objects.Obstructions do if obj.Name=="Lava" then obj.CanTouch=not v end end end })
bypassSec:Toggle({ Name="Bypass Seeking Wall",      Flag="B_SeekWall",  Default=false, Callback=function(v) bypassSeekWall=v
    for _, obj in Objects.Obstructions do if obj.Name=="ScaryWall" then
        for _, p in obj:GetDescendants() do if p:IsA("BasePart") then p.CanTouch=not v p.CanCollide=not v end end end end end })
bypassSec:Toggle({ Name="Bypass Snare",             Flag="B_Snare",     Default=false, Callback=function(v) bypassSnare=v
    for _, obj in Objects.Entities do if obj.Name=="Snare" then
        for _, p in obj:GetDescendants() do if p:IsA("BasePart") then p.CanTouch=not v end end end end end })
bypassSec:Toggle({ Name="Bypass Banana",            Flag="B_Banana",    Default=false, Callback=function(v) bypassBanana=v
    for _, obj in Objects.Entities do if obj.Name=="BananaPeel" then obj.CanTouch=not v end end end })
bypassSec:Toggle({ Name="Bypass Jeff",              Flag="B_Jeff",      Default=false, Callback=function(v) bypassJeff=v
    for _, obj in Objects.Entities do if obj.Name=="JeffTheKiller" then
        for _, p in obj:GetDescendants() do if p:IsA("BasePart") then p.CanCollide=not v p.CanTouch=not v end end
        pcall(function() obj:WaitForChild("Humanoid").Health=0 end) end end end })

-- Remove entities
local removeSec = ExploitsTab:Section({ Title = "Remove", Column = "right" })
local Modules = {}

local removeScreech=false,removeHalt=false,removeA90=false,removeDread=false,removeSurge=false
local noScreechDmg=false,noHaltDmg=false,noA90Dmg=false,noSurgeDmg=false

removeSec:Toggle({ Name="Remove Screech",    Flag="R_Screech",  Default=false, Callback=function(v) removeScreech=v
    if Modules.Screech then Modules.Screech.Name=v and "Screech_Disabled" or "Screech" end end })
removeSec:Toggle({ Name="Remove Halt",       Flag="R_Halt",     Default=false, Callback=function(v) removeHalt=v
    if Modules.Shade then Modules.Shade.Name=v and "Shade_Disabled" or "Shade" end end })
removeSec:Toggle({ Name="Remove A-90",       Flag="R_A90",      Default=false, Callback=function(v) removeA90=v
    if Modules.A90 then Modules.A90.Name=v and "A90_Disabled" or "A90" end end })
removeSec:Toggle({ Name="Remove Dread",      Flag="R_Dread",    Default=false, Callback=function(v) removeDread=v
    if Modules.Dread then Modules.Dread.Name=v and "Dread_Disabled" or "Dread" end end })
removeSec:Toggle({ Name="Remove Surge",      Flag="R_Surge",    Default=false, Callback=function(v) removeSurge=v
    if Globals.SurgeFrame then Globals.SurgeFrame.Name=v and "SurgeVignette_Disabled" or "SurgeVignette" end end })
removeSec:Divider()
removeSec:Toggle({ Name="No Screech Damage", Flag="R_ScreechDmg",Default=false, Callback=function(v) noScreechDmg=v
    if v then FakeEvents.Screech.Parent=RemotesFolder FakeEvents.Screech_Real.Parent=nil
    else FakeEvents.Screech_Real.Parent=RemotesFolder FakeEvents.Screech.Parent=nil end end })
removeSec:Toggle({ Name="No Halt Damage",    Flag="R_HaltDmg",  Default=false, Callback=function(v) noHaltDmg=v
    if v then FakeEvents.Shade.Parent=RemotesFolder FakeEvents.Shade_Real.Parent=nil
    else FakeEvents.Shade_Real.Parent=RemotesFolder FakeEvents.Shade.Parent=nil end end })
removeSec:Toggle({ Name="No A-90 Damage",    Flag="R_A90Dmg",   Default=false, Callback=function(v) noA90Dmg=v
    if FakeEvents.A90_Real then
        if v then FakeEvents.A90.Parent=RemotesFolder FakeEvents.A90_Real.Parent=nil
        else FakeEvents.A90_Real.Parent=RemotesFolder FakeEvents.A90.Parent=nil end end end })
removeSec:Toggle({ Name="No Surge Damage",   Flag="R_SurgeDmg", Default=false, Callback=function(v) noSurgeDmg=v
    if FakeEvents.Surge_Real then
        if v then FakeEvents.Surge.Parent=RemotesFolder FakeEvents.Surge_Real.Parent=nil
        else FakeEvents.Surge_Real.Parent=RemotesFolder FakeEvents.Surge.Parent=nil end end end })

-- Misc exploits
local exploitMiscSec = ExploitsTab:Section({ Title = "Misc", Column = "left" })

local posSpoof=false,crouchSpoof=false,disableAnticheat=false
local removeFootsteps=false,removeInteractSounds=false,removeHideVignette=false
local disableJumpscares=false,removeCutscenes=false
local enableJump=false,enableSlide=false

exploitMiscSec:Toggle({ Name="Position Spoof",    Flag="E_PosSpoof",  Default=false, Callback=function(v) posSpoof=v
    if Floor~="Fools" and Floor~="OldHotel" and RootPart then
        if v then RootPart.CFrame=RootPart.CFrame*CFrame.new(0,-2.346,0) Humanoid.HipHeight=0.05
               pcall(function() RemotesFolder.Crouch:FireServer(true,true) end)
        else RootPart.CFrame=RootPart.CFrame*CFrame.new(0,2.346,0) Humanoid.HipHeight=2.396 end end end })
exploitMiscSec:Toggle({ Name="Crouch Spoof",      Flag="E_CrouchSpoof",Default=false,Callback=function(v) crouchSpoof=v
    pcall(function() RemotesFolder.Crouch:FireServer(v or isCrouching(),true) end) end })
exploitMiscSec:Toggle({ Name="Anticheat Bypass",  Flag="E_ACBypass",  Default=false, Callback=function(v) disableAnticheat=v
    if not v and Globals.AnticheatDisabled then pcall(function() RemotesFolder.ClimbLadder:FireServer() end) Globals.AnticheatDisabled=false end end })
exploitMiscSec:Divider()
exploitMiscSec:Toggle({ Name="Remove Footstep Sounds",  Flag="E_NoFootstep",Default=false,Callback=function(v) removeFootsteps=v end })
exploitMiscSec:Toggle({ Name="Remove Interact Sounds",  Flag="E_NoInteract",Default=false,Callback=function(v) removeInteractSounds=v
    if Globals.MainUI then pcall(function()
        local PS=Globals.MainUI.Initiator.Main_Game.PromptService
        PS.Triggered.Volume=v and 0 or 1 PS.Holding.Volume=v and 0 or 1 PS.Notification.Volume=v and 0 or 1 end) end end })
exploitMiscSec:Toggle({ Name="Disable Hide Vignette",   Flag="E_NoVignette",Default=false,Callback=function(v) removeHideVignette=v
    if Globals.MainUI then pcall(function()
        local vig=Globals.MainUI:FindFirstChild("HideVignette") or Globals.MainUI.MainFrame:FindFirstChild("HideVignette")
        if vig then vig.Image=v and "Disabled" or "rbxassetid://6100076320" end end) end end })
exploitMiscSec:Toggle({ Name="Disable Entity Jumpscares",Flag="E_NoJS",    Default=false,Callback=function(v) disableJumpscares=v
    if Globals.MainUI then pcall(function()
        local js=Globals.MainUI.Initiator.Main_Game.RemoteListener:FindFirstChild("Jumpscares")
        if js then js.Name=v and "Jumpscares_Disabled" or "Jumpscares" end end) end end })
exploitMiscSec:Toggle({ Name="Remove Cutscenes",         Flag="E_NoCuts",   Default=false,Callback=function(v) removeCutscenes=v
    for _, folder in {FloorReplicated} do
        for _, obj in pairs(folder:GetChildren()) do
            if table.find(CutsceneNames,obj.Name) then obj.Name=v and obj.Name.."_Disabled" or (obj:GetAttribute("OriginalName") or obj.Name:gsub("_Disabled","")) end end end end })
exploitMiscSec:Divider()
exploitMiscSec:Toggle({ Name="Enable Jump",   Flag="E_Jump",  Default=false, Callback=function(v) enableJump=v
    if Character then Character:SetAttribute("CanJump",v or OldJump) end end })
exploitMiscSec:Toggle({ Name="Enable Slide",  Flag="E_Slide", Default=false, Callback=function(v) enableSlide=v
    if Character then Character:SetAttribute("CanSlide",v or OldSlide) end end })

---------------------------------------------------------
-- VISUALS TAB
---------------------------------------------------------
-- ESP Toggles
local espSec = VisualsTab:Section({ Title = "ESP", Column = "left" })

local espEntities=false,espItems=false,espDoors=false,espChests=false
local espCurrency=false,espHiding=false,espObjective=false,espPlayers=false,espLadders=false
local espEntityColor=Color3.fromRGB(255,60,60)
local espItemColor=Color3.fromRGB(100,255,100)
local espDoorColor=Color3.fromRGB(0,200,255)
local espChestColor=Color3.fromRGB(205,133,63)
local espCurrencyColor=Color3.fromRGB(255,215,0)
local espHidingColor=Color3.fromRGB(180,180,255)
local espObjectiveColor=Color3.fromRGB(255,165,0)
local espPlayerColor=Color3.fromRGB(255,255,255)
local espLadderColor=Color3.fromRGB(200,200,200)

espSec:Toggle({ Name="Entity ESP",    Flag="ESP_Entities",  Default=false, Callback=function(v) espEntities=v
    for _, obj in Objects.Entities do if v then local ed=EntityData[obj.Name] if ed then addESP(obj,ed.Alias,espEntityColor) end else removeESP(obj) end end end })
espSec:ColorPicker({ Name="Entity Color",     Flag="ESP_EntColor",  Default=Color3.fromRGB(255,60,60),   Callback=function(v) espEntityColor=v end })
espSec:Toggle({ Name="Item ESP",      Flag="ESP_Items",     Default=false, Callback=function(v) espItems=v
    for _, obj in Objects.Items do if v then addESPRoombased(obj,ItemNames[obj.Name],espItemColor) else removeESP(obj) end end end })
espSec:ColorPicker({ Name="Item Color",       Flag="ESP_ItemColor", Default=Color3.fromRGB(100,255,100), Callback=function(v) espItemColor=v end })
espSec:Toggle({ Name="Door ESP",      Flag="ESP_Doors",     Default=false, Callback=function(v) espDoors=v
    for _, obj in Objects.Doors do if v then addESPRoombased(obj,"Door",espDoorColor) else removeESP(obj) end end end })
espSec:ColorPicker({ Name="Door Color",       Flag="ESP_DoorColor", Default=Color3.fromRGB(0,200,255),   Callback=function(v) espDoorColor=v end })
espSec:Toggle({ Name="Chest ESP",     Flag="ESP_Chests",    Default=false, Callback=function(v) espChests=v
    for _, obj in Objects.Chests do if v then addESPRoombased(obj,"Chest",espChestColor) else removeESP(obj) end end end })
espSec:ColorPicker({ Name="Chest Color",      Flag="ESP_ChestColor",Default=Color3.fromRGB(205,133,63),  Callback=function(v) espChestColor=v end })
espSec:Toggle({ Name="Currency ESP",  Flag="ESP_Currency",  Default=false, Callback=function(v) espCurrency=v
    for _, obj in Objects.Currency do if v then addESPRoombased(obj,"Gold",espCurrencyColor) else removeESP(obj) end end end })
espSec:ColorPicker({ Name="Currency Color",   Flag="ESP_CurrColor", Default=Color3.fromRGB(255,215,0),   Callback=function(v) espCurrencyColor=v end })
espSec:Toggle({ Name="Hiding Spot ESP",Flag="ESP_Hiding",   Default=false, Callback=function(v) espHiding=v
    for _, obj in Objects.HidingSpots do if v then addESPRoombased(obj,HidingSpotLabels[obj.Name],espHidingColor) else removeESP(obj) end end end })
espSec:ColorPicker({ Name="Hiding Color",     Flag="ESP_HideColor", Default=Color3.fromRGB(180,180,255), Callback=function(v) espHidingColor=v end })
espSec:Toggle({ Name="Objective ESP", Flag="ESP_Objectives", Default=false, Callback=function(v) espObjective=v end })
espSec:ColorPicker({ Name="Objective Color",  Flag="ESP_ObjColor",  Default=Color3.fromRGB(255,165,0),   Callback=function(v) espObjectiveColor=v end })
espSec:Toggle({ Name="Player ESP",    Flag="ESP_Players",   Default=false, Callback=function(v) espPlayers=v
    for _, p in Players:GetPlayers() do if p~=LP and p.Character then if v then addESP(p.Character,p.Name,espPlayerColor) else removeESP(p.Character) end end end end })
espSec:ColorPicker({ Name="Player Color",     Flag="ESP_PlrColor",  Default=Color3.fromRGB(255,255,255), Callback=function(v) espPlayerColor=v end })
espSec:Toggle({ Name="Ladder ESP",    Flag="ESP_Ladders",   Default=false, Callback=function(v) espLadders=v
    for _, obj in Objects.Ladders do if v then addESPRoombased(obj,"Ladder",espLadderColor) else removeESP(obj) end end end })

-- ESP Settings
local espSettingsSec = VisualsTab:Section({ Title = "ESP Settings", Column = "right" })
espSettingsSec:Toggle({ Name="Show Distance",    Flag="ESP_ShowDist",    Default=true,  Callback=function(v) espSettings.showDistance=v end })
espSettingsSec:Toggle({ Name="Rainbow Effect",   Flag="ESP_Rainbow",     Default=false, Callback=function(v) espSettings.rainbow=v end })
espSettingsSec:Slider({ Name="Fill Transparency",Flag="ESP_FillTrans",   Min=0,Max=1,Default=0.75,Decimals=2,
    Callback=function(v) espSettings.fillTransparency=v for _,d in pairs(espObjects) do if d.hl then d.hl.FillTransparency=v end end end })
espSettingsSec:Slider({ Name="Outline Transparency",Flag="ESP_OutTrans", Min=0,Max=1,Default=0,Decimals=2,
    Callback=function(v) espSettings.outlineTransparency=v for _,d in pairs(espObjects) do if d.hl then d.hl.OutlineTransparency=v end end end })
espSettingsSec:Slider({ Name="Render Limit",     Flag="ESP_RenderDist",  Min=30,Max=500,Default=150,Decimals=0,
    Callback=function(v) espSettings.renderLimit=v end })

---------------------------------------------------------
-- FLOORS TAB
---------------------------------------------------------
local floorsSec = FloorsTab:Section({ Title = "Automation", Column = "right" })

local roomsAutoWalk=false,roomsAutoWalkShowPath=false
local autoSteerMinecart=false
local autoSolveAnchors=false

floorsSec:Toggle({ Name="Auto Rooms",        Flag="F_AutoRooms",  Default=false, Callback=function(v) roomsAutoWalk=v end })
floorsSec:Toggle({ Name="Show Path",         Flag="F_ShowPath",   Default=false, Callback=function(v) roomsAutoWalkShowPath=v
    for _, obj in Globals.RoomsNodesFolder:GetChildren() do if obj.Name=="PathNode" then obj.Transparency=v and 0.5 or 1 end end end })
floorsSec:Divider()
floorsSec:Toggle({ Name="Auto Steer Minecart",Flag="F_Minecart",  Default=false, Callback=function(v) autoSteerMinecart=v end })
floorsSec:Divider()
floorsSec:Toggle({ Name="Auto Solve Anchors",Flag="F_Anchors",    Default=false, Callback=function(v) autoSolveAnchors=v end })

---------------------------------------------------------
-- Логика: Speed, Fly, Noclip, AutoHide
---------------------------------------------------------
local FlyBody = Instance.new("BodyVelocity")
FlyBody.MaxForce = Vector3.new(9e9,9e9,9e9)
FlyBody.Velocity = Vector3.zero

RunService.Heartbeat:Connect(function()
    if not Character or not Humanoid or not RootPart then return end

    -- Speed
    if speedEnabled then
        Humanoid.WalkSpeed = speedValue
    end

    -- Fly
    if flyEnabled then
        if FlyBody.Parent ~= RootPart then FlyBody.Parent = RootPart end
        local camCF = Camera.CFrame
        local vel = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel = vel + camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel = vel - camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel = vel - camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel = vel + camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.new(0,1,0) end
        FlyBody.Velocity = vel.Magnitude > 0 and (vel.Unit * flySpeed) or Vector3.zero
        Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    else
        if FlyBody.Parent == RootPart then FlyBody.Parent = nil end
    end

    -- Noclip
    if noclipEnabled then
        for _, p in Character:GetDescendants() do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end

    -- Infinite stamina
    if infiniteStamina and Character:GetAttribute("Stamina") ~= nil then
        Character:SetAttribute("Stamina", 100)
    end

    -- FOV
    if Main_Game then Main_Game.fovtarget = fovValue else Camera.FieldOfView = fovValue end

    -- Third person
    if thirdPerson then
        Camera.CameraType = Enum.CameraType.Custom
    end

    -- Eyes/Lookman bypass
    if (Globals.IsEyes and bypassEyes) or (Globals.IsLookman and bypassLookman) then
        pcall(function()
            if Floor=="Fools" or Floor=="OldHotel" then
                RemotesFolder.MotorReplication:FireServer(0,(Globals.SpoofOffset==200 and 65 or -65),0,false)
            else
                RemotesFolder.MotorReplication:FireServer(-650)
            end
        end)
    end
end)

-- Infinite jumps
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Space and infiniteJumps and Humanoid then
        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

---------------------------------------------------------
-- Логика: AutoHide
---------------------------------------------------------
local lastAutoHide = tick()
local function getNearestEntity(ignoreDisabled, ignoreList)
    local best = { dist = math.huge, obj = nil }
    for _, entity in workspace:GetChildren() do
        if entity and EntityDistances[entity.Name] and entity.PrimaryPart then
            local ed = EntityData[entity.Name]
            if not (ignoreList and ignoreList[ed and ed.Alias]) then
                local d = LP:DistanceFromCharacter(entity.PrimaryPart.Position)
                if d < EntityDistances[entity.Name] and d < best.dist then
                    if not ignoreDisabled or entity:GetAttribute("Inactive") ~= true then
                        best.dist = d best.obj = entity
                    end
                end
            end
        end
    end
    return best.obj
end

local function getNearestHidingSpot()
    local best = { dist = math.huge, obj = nil }
    local lastHide = Character and Character:FindFirstChild("LastHideSpot")
    for _, obj in Objects.HidingSpots do
        if obj.PrimaryPart and obj:FindFirstChild("HidePrompt") then
            local d = LP:DistanceFromCharacter(obj.PrimaryPart.Position)
            if d < obj.HidePrompt.MaxActivationDistance and d < best.dist then
                local persistent = isHidePersistent()
                if not persistent or (lastHide and lastHide.Value ~= obj) or not lastHide then
                    best.dist = d best.obj = obj
                end
            end
        end
    end
    return best.obj
end

RunService.Heartbeat:Connect(function()
    if not autoHide or not Character or tick() - lastAutoHide <= 0.1 then return end
    local entity = getNearestEntity(true)
    if entity then
        local closet = getNearestHidingSpot()
        if Character:GetAttribute("Hiding") ~= true and closet then
            firePrompt(closet.HidePrompt)
        end
    elseif Character:GetAttribute("Hiding") == true then
        pcall(function() RemotesFolder.CamLock:FireServer() end)
    end
    lastAutoHide = tick()
end)

---------------------------------------------------------
-- Логика: AutoLoot / AutoInteract
---------------------------------------------------------
local AutoInteractBlacklist = {
    HidePrompt=true, RiftPrompt=true, StarRiftPrompt=true, InteractPrompt=true,
    ClimbPrompt=true, DonatePrompt=true, DialoguePrompt=true, RevivePrompt=true,
    EnterPrompt=true, AnimatePrompt=true, ToolEventPrompt=true, Prompt=true, PropPrompt=true,
}

local function tryInteractPrompt(prompt)
    if not prompt or not prompt.Parent then return end
    if AutoInteractBlacklist[prompt.Name] then return end
    if not RootPart then return end
    local part = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart")
    if part and (RootPart.Position - part.Position).Magnitude > lootReach then return end
    firePrompt(prompt)
end

RunService.Heartbeat:Connect(function()
    if not autoLootEnabled and not autoInteract then return end
    if not Character then return end
    for _, obj in Objects.Items do
        if autoLootEnabled and obj:IsDescendantOf(workspace) then
            local prompt = obj:FindFirstChild("ModulePrompt", true)
            if prompt then tryInteractPrompt(prompt) end
        end
    end
    if autoInteract then
        for _, obj in workspace:GetDescendants() do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                tryInteractPrompt(obj)
            end
        end
    end
end)

---------------------------------------------------------
-- Логика: AutoRevive
---------------------------------------------------------
LP:GetAttributeChangedSignal("Alive"):Connect(function()
    if LP:GetAttribute("Alive") == false and autoRevive then
        task.spawn(function()
            while LP:GetAttribute("Alive") ~= true do
                pcall(function() RemotesFolder.Revive:FireServer() end)
                task.wait(0.5)
            end
        end)
    end
end)

---------------------------------------------------------
-- Fog
---------------------------------------------------------
for _, atmo in Lighting:GetChildren() do
    if atmo:IsA("Atmosphere") then
        atmo:SetAttribute("Density_Old", atmo.Density)
        atmo:GetPropertyChangedSignal("Density"):Connect(function()
            if atmo.Density ~= 0 then atmo:SetAttribute("Density_Old", atmo.Density) end
            if removeFog then atmo.Density = 0 end
        end)
        table.insert(Globals.FogInstances, atmo)
    end
end

---------------------------------------------------------
-- Player ESP
---------------------------------------------------------
Players.PlayerAdded:Connect(function(p)
    if p == LP then return end
    p.CharacterAdded:Connect(function(char)
        if espPlayers then addESP(char, p.Name, espPlayerColor) end
    end)
    p:GetAttributeChangedSignal("Alive"):Connect(function()
        if p:GetAttribute("Alive") ~= true and p.Character then removeESP(p.Character) end
    end)
end)

for _, p in Players:GetPlayers() do
    if p ~= LP then
        if p.Character and espPlayers then addESP(p.Character, p.Name, espPlayerColor) end
        p.CharacterAdded:Connect(function(char)
            if espPlayers then addESP(char, p.Name, espPlayerColor) end
        end)
    end
end

---------------------------------------------------------
-- Детект объектов мира (CurrentRooms.ChildAdded и т.д.)
---------------------------------------------------------
local function handleWorldObject(obj)
    local name = obj.Name
    local data = EntityData[name]

    if data then
        -- Сущность
        task.spawn(function()
            while not obj.PrimaryPart do
                for _, c in obj:GetChildren() do if c:IsA("BasePart") then obj.PrimaryPart=c end end
                task.wait()
            end
            task.wait(0.1)
            if not obj.PrimaryPart or LP:DistanceFromCharacter(obj.PrimaryPart.Position) >= 10000 then return end

            local alias = data.Alias
            if notifyEntities then
                notify(data.Notify.Title, data.Notify.Body, 5)
            end
            if entityChatEnabled then
                sendChat(alias .. " " .. entityChatMsg)
            end
            if espEntities and name ~= "GloombatSwarm" then
                if name == "MonumentEntity" then
                    addESP(obj:FindFirstChild("Top") or obj, alias, espEntityColor)
                else
                    addESP(obj, alias, espEntityColor)
                end
            end

            if RusherAliases[alias] then
                Instance.new("Humanoid", obj).Name = "HighlightHumanoid"
                local root = obj.PrimaryPart
                if root then root.Transparency = 0.999 root.Material = Enum.Material.Plastic end
            end

            if name ~= "GloombatSwarm" then
                table.insert(Objects.Entities, obj)
            end

            -- Bypass на спавне
            if name == "GiggleCeiling" and bypassGiggle then
                pcall(function() obj:WaitForChild("Hitbox").CanTouch=false end)
            end
            if (name == "DoorFake" or name == "FakeDoor") and bypassDupe then
                pcall(function() obj:WaitForChild("Hidden").CanTouch=false end)
                if obj:FindFirstChild("Lock") then pcall(function() obj.Lock.UnlockPrompt.Enabled=false end) end
            end
            if name == "Snare" and bypassSnare then
                for _, p in obj:GetDescendants() do if p:IsA("BasePart") then p.CanTouch=false end end
            end
            if name == "BananaPeel" and bypassBanana then obj.CanTouch=false end
            if name == "SideroomSpace" and bypassVacuum then
                pcall(function() obj:WaitForChild("Collision").CanCollide=false obj:WaitForChild("Collision").CanTouch=false end)
            end
        end)

    elseif HidingSpotLabels[name] then
        if espHiding then addESPRoombased(obj, HidingSpotLabels[name], espHidingColor) end
        table.insert(Objects.HidingSpots, obj)

    elseif name == "Lava" then
        if bypassKillbrick then obj.CanTouch = false end
        table.insert(Objects.Obstructions, obj)

    elseif name == "ScaryWall" then
        for _, p in obj:GetDescendants() do
            if p:IsA("BasePart") then p.CanTouch=not bypassSeekWall p.CanCollide=not bypassSeekWall end
        end
        table.insert(Objects.Obstructions, obj)

    elseif name == "ChestBox" or name == "ChestBoxLocked" then
        if espChests then addESPRoombased(obj, obj:GetAttribute("Locked") and "Locked Chest" or "Chest", espChestColor) end
        table.insert(Objects.Chests, obj)

    elseif name == "Toolbox" or name == "Toolbox_Locked" then
        if espChests then addESPRoombased(obj, obj:GetAttribute("Locked") and "Locked Toolbox" or "Toolbox", espChestColor) end
        table.insert(Objects.Chests, obj)

    elseif ItemNames[name] and obj:FindFirstChild("ModulePrompt") then
        if espItems then addESPRoombased(obj, ItemNames[name], espItemColor) end
        if notifyItems then notify("Item '" .. ItemNames[name] .. "' has spawned.") end
        table.insert(Objects.Items, obj)

    elseif name == "GoldPile" and obj:GetAttribute("GoldValue") then
        if espCurrency then addESPRoombased(obj, "Gold Pile [" .. obj:GetAttribute("GoldValue") .. "]", espCurrencyColor) end
        table.insert(Objects.Currency, obj)

    elseif name == "StardustPickup" then
        if espCurrency then addESPRoombased(obj, "Stardust Pile", espCurrencyColor) end
        table.insert(Objects.Currency, obj)

    elseif name == "Ladder" then
        if espLadders then addESPRoombased(obj, "Ladder", espLadderColor) end
        table.insert(Objects.Ladders, obj)

    elseif name == "Door" and obj.Parent and tonumber(obj.Parent.Name) then
        local doorParts = {}
        for _, child in obj:GetChildren() do
            if child.Name == "Door" and child:IsA("BasePart") then table.insert(doorParts, child) end
        end
        local hl = Instance.new("Model", obj)
        hl.Name = "HighlightModel"
        Instance.new("Humanoid", hl).Name = "HighlightHumanoid"
        hl:SetAttribute("ParentRoom", tonumber(obj.Parent.Name))
        for _, dp in doorParts do
            local hp = Instance.new("Part", hl)
            hp.Transparency = 0.999 hp.Size = dp.Size hp.CanCollide = false
            hp.CFrame = dp.CFrame hp.Name = "HighlightPart" hp.Material = Enum.Material.Plastic
            hp:SetAttribute("ParentRoom", tonumber(obj.Parent.Name))
            local w = Instance.new("WeldConstraint", hp)
            w.Part0=hp w.Part1=dp w.Enabled=true
        end
        table.insert(Objects.Doors, hl)
        if espDoors then addESPRoombased(hl, "Door " .. getDoorNumber(obj), espDoorColor) end
    end
end

-- Сканируем уже существующие объекты
task.spawn(function()
    if CurrentRooms then
        for _, room in CurrentRooms:GetChildren() do
            for _, obj in room:GetDescendants() do
                pcall(handleWorldObject, obj)
            end
        end
    end
    if workspace:FindFirstChild("Drops") then
        for _, obj in workspace.Drops:GetChildren() do
            pcall(handleWorldObject, obj)
        end
    end
end)

-- Новые объекты
if CurrentRooms then
    CurrentRooms.ChildAdded:Connect(function(room)
        task.wait(0.1)
        room.DescendantAdded:Connect(function(obj) pcall(handleWorldObject, obj) end)
        for _, obj in room:GetDescendants() do pcall(handleWorldObject, obj) end
    end)
end

workspace.ChildAdded:Connect(function(obj)
    pcall(handleWorldObject, obj)
end)

---------------------------------------------------------
-- Cleaner
---------------------------------------------------------
local lastClean = tick()
RunService.Heartbeat:Connect(function()
    if tick() - lastClean <= 0.5 then return end
    lastClean = tick()
    for _, array in {Objects.Entities, Objects.Items, Objects.Currency, Objects.Doors,
                     Objects.HidingSpots, Objects.Chests, Objects.Ladders, Objects.Obstructions} do
        local i = #array
        while i >= 1 do
            local obj = array[i]
            if obj == nil or not obj:IsDescendantOf(workspace) then
                table.remove(array, i)
                removeESP(obj)
            end
            i -= 1
        end
    end
end)

---------------------------------------------------------
-- HandleCharacter
---------------------------------------------------------
local function handleCharacter(newChar)
    while not LP.PlayerGui:FindFirstChild("MainUI") do task.wait() end

    Character = newChar
    Humanoid  = newChar:WaitForChild("Humanoid", 9e9)
    RootPart  = newChar:FindFirstChild("HumanoidRootPart")
    Camera    = workspace.CurrentCamera

    Globals.MainUI = LP.PlayerGui.MainUI

    Collision = newChar:WaitForChild("Collision")
    CollisionPart = newChar:FindFirstChild("CollisionPart") or newChar:FindFirstChild("Collision")
    CollisionClone = Collision:Clone()
    CollisionClone.Parent = newChar CollisionClone.Name = "CollisionClone" CollisionClone.Massless = true
    CollisionPartClone = CollisionPart:Clone()
    CollisionPartClone.Parent = newChar CollisionPartClone.Name = "CollisionPartClone"
    CollisionPartClone.CanCollide = false CollisionPartClone.Massless = true

    Character:SetAttribute("SpeedBoost", 0)
    Character:SetAttribute("SpeedBoostBehind", 0)
    Character:SetAttribute("SpeedBoostExtra", 0)

    OldJump  = newChar:GetAttribute("CanJump")
    OldSlide = newChar:GetAttribute("CanSlide")

    if enableJump  then Character:SetAttribute("CanJump",  true) end
    if enableSlide then Character:SetAttribute("CanSlide", true) end

    -- Загружаем модули
    pcall(function()
        local clientModules = ReplicatedStorage:FindFirstChild("ModulesClient") or ReplicatedStorage:FindFirstChild("ClientModules")
        if clientModules then
            local em = clientModules:FindFirstChild("EntityModules")
            if em then
                Modules.Shade  = em:FindFirstChild("Shade")
                Modules.Glitch = em:FindFirstChild("Glitch")
                Modules.Void   = em:FindFirstChild("Void")
            end
        end
        local uiModules = Globals.MainUI.Initiator.Main_Game.RemoteListener.Modules
        Modules.A90             = uiModules:FindFirstChild("A90")
        Modules.Screech         = uiModules:FindFirstChild("Screech")
        Modules.Dread           = uiModules:FindFirstChild("Dread")
        Modules.SpiderJumpscare = uiModules:FindFirstChild("SpiderJumpscare")

        if removeScreech and Modules.Screech then Modules.Screech.Name="Screech_Disabled" end
        if removeA90 and Modules.A90 then Modules.A90.Name="A90_Disabled" end
        if removeDread and Modules.Dread then Modules.Dread.Name="Dread_Disabled" end
        if disableJumpscares and Modules.SpiderJumpscare then Modules.SpiderJumpscare.Name="SpiderJumpscare_Disabled" end

        Main_Game = require(Globals.MainUI.Initiator.Main_Game)
        if removeCameraBobbing then Main_Game.spring.Speed = 9e9 end
    end)

    -- Character attribute watchers
    Character:GetAttributeChangedSignal("CanJump"):Connect(function()
        local v = Character:GetAttribute("CanJump")
        if enableJump and v ~= true then OldJump=v end
        if enableJump then Character:SetAttribute("CanJump",true) end
    end)
    Character:GetAttributeChangedSignal("CanSlide"):Connect(function()
        local v = Character:GetAttribute("CanSlide")
        if enableSlide and v ~= true then OldSlide=v end
        if enableSlide then Character:SetAttribute("CanSlide",true) end
    end)

    -- Footstep sounds
    Character.ChildAdded:Connect(function(obj)
        if obj:IsA("Sound") and obj.Name=="Sound" and removeFootsteps then obj.Volume=0 end
    end)

    -- Library code notification
    Character.ChildAdded:Connect(function(child)
        if (child.Name=="LibraryHintPaper" or child.Name=="LibraryHintPaperHard") and notifyLibCode then
            local code = getLibraryCode()
            if code and not code:find("_") and not Globals.LibraryCodeFound then
                notify("Padlock code found!", "The code is: '" .. code .. "'", 15)
                Globals.LibraryCodeFound = true
            end
        end
    end)

    -- Anticheat bypass
    Character:GetAttributeChangedSignal("Climbing"):Connect(function()
        if Character:GetAttribute("Climbing") == true and disableAnticheat and not Globals.AnticheatDisabled then
            task.wait(0.25)
            Character:SetAttribute("Climbing", false)
            notify("Anticheat disabled.", "Interact with a ladder to re-enable.")
            Globals.AnticheatDisabled = true
        end
    end)

    pcall(function()
        RemotesFolder:WaitForChild("Cutscene").OnClientEvent:Connect(function()
            if Globals.AnticheatDisabled then
                Globals.AnticheatDisabled = false
                notify("Anticheat re-enabled.", "")
            end
        end)
    end)
end

if LP.Character then task.spawn(function() handleCharacter(LP.Character) end) end
LP.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    handleCharacter(newChar)
end)

---------------------------------------------------------
-- Загружено
---------------------------------------------------------
Win:Settings()
notify("Just X Hub", "Loaded! RightShift to toggle.", 4)
