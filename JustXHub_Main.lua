-- Just X Hub — Main (In-Game)
-- Полный перенос Abysall Hub Main на JustLib API
-- Оптимизировано: throttling, pcall, кэширование

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
local ProximityPromptService = game:GetService("ProximityPromptService")

local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local RemotesFolder   = ReplicatedStorage:FindFirstChild("RemotesFolder")
local LiveModifiers   = ReplicatedStorage:FindFirstChild("LiveModifiers") or Instance.new("Folder")
local FloorReplicated = ReplicatedStorage:FindFirstChild("FloorReplicated") or Instance.new("Folder")
local CurrentRooms    = workspace:FindFirstChild("CurrentRooms")
local Drops           = workspace:FindFirstChild("Drops")
local GameData        = ReplicatedStorage:WaitForChild("GameData", 10)
local Floor           = "Hotel"
local LatestRoom      = nil

if GameData then
    local floorVal = GameData:WaitForChild("Floor", 5)
    if floorVal then Floor = floorVal.Value end
    LatestRoom = GameData:FindFirstChild("LatestRoom")
    local frlr = GameData:FindFirstChild("FinishedLoadingRoom")
    if frlr then frlr:Destroy() end
end

if not RemotesFolder then
    RemotesFolder = ReplicatedStorage:FindFirstChild("EntityInfo")
        or ReplicatedStorage:FindFirstChild("Bricks")
        or Instance.new("Folder")
end
if Floor == "Hotel" and RemotesFolder.Name == "Bricks" then Floor = "OldHotel" end

-- Footstep remote fake
if RemotesFolder:FindFirstChild("FootstepRemoteThatWeNeed") then
    RemotesFolder:FindFirstChild("FootstepRemoteThatWeNeed"):Destroy()
    local fake = Instance.new("RemoteEvent", RemotesFolder)
    fake.Name = "FootstepRemoteThatWeNeed"
end

-- Персонаж
local Character, Humanoid, RootPart
local Collision, CollisionClone, CollisionPart, CollisionPartClone
local OldJump = false
local OldSlide = false
local Main_Game
local Modules = {}
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Globals
local Globals = {
    FogInstances      = {},
    OldFog            = Lighting.FogEnd,
    SpoofOffset       = 0,
    IsEyes            = false,
    IsLookman         = false,
    AnticheatDisabled = false,
    LibraryCodeFound  = false,
    UsedRandomCodes   = {},
    KnobFarmActive    = false,
    KnobFarmStarted   = false,
    SelfKilled        = false,
    IsTyping          = false,
    LastAutoHide      = 0,
    LastAutoAnchor    = 0,
    LastCrouchFire    = 0,
    LastAnimCheck     = 0,
    Sliding           = false,
    SpectateEntity    = nil,
    AutoClosetActive  = false,
    BreakerBoxInteracted = false,
    BreakerBoxNotified   = false,
    BreakerBoxStartNotified = false,
    BreakerBoxFinishedNotified = false,
    ManipulateBody    = nil,
    FlyBody           = nil,
    ThirdPersonParts  = {},
    OriginalC1        = nil,
    UseAnimation      = nil,
    UseAnimationBreak = nil,
    NearestTurnNode   = nil,
    AutoMinecartDucked = false,
    LastDuck          = 0,
    OriginalGetMoveVector = nil,
    RoomsAutoWalkActive = false,
    OldOxygen         = 0,
    PromptContainer   = nil,
}

local Objects = {
    Prompts={}, Objectives={}, Doors={}, HidingSpots={},
    Entities={}, SeekObstructions={}, Items={}, Chests={},
    Currency={}, Ladders={}, Obstructions={}, EventTriggers={},
    JumpscareModules={}, SeekHighlights={}, EyestalkHighlights={},
    SeekNodes={}, SeekDuckBoards={}, SeekBridges={}, PathLights={}
}

local Connections    = {}
local ESPConnections = {}
local ESPBlacklist   = {}
local FakePrompts    = {}
local PartProperties = {}

-- FakeEvents
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
FakeEvents.Screech_Real = RemotesFolder:WaitForChild("Screech", 3)
FakeEvents.Shade_Real   = RemotesFolder:WaitForChild("ShadeResult", 3)
FakeEvents.A90_Real     = RemotesFolder:FindFirstChild("A90")
FakeEvents.Surge_Real   = RemotesFolder:FindFirstChild("SurgeRemote")

-- Ноды
Globals.SeekNodesFolder = Instance.new("Folder")
Globals.SeekNodesFolder.Name = "JXH_SeekNodes"
Globals.SeekNodesFolder.Parent = workspace
Globals.RoomsNodesFolder = Instance.new("Folder")
Globals.RoomsNodesFolder.Name = "JXH_RoomsNodes"
Globals.RoomsNodesFolder.Parent = workspace
Globals.PromptContainer = Instance.new("Folder")
Globals.PromptContainer.Name = "JXH_Prompts"
Globals.PromptContainer.Parent = workspace

-- Fog
for _, obj in Lighting:GetChildren() do
    if obj:IsA("Atmosphere") then
        obj:SetAttribute("Density_Old", obj.Density)
        local c = obj:GetPropertyChangedSignal("Density"):Connect(function()
            if obj.Density ~= 0 then obj:SetAttribute("Density_Old", obj.Density) end
        end)
        table.insert(Connections, c)
        table.insert(Globals.FogInstances, obj)
    end
end
Connections.FogHandler = Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
    if Lighting.FogEnd ~= 1e7 then Globals.OldFog = Lighting.FogEnd end
end)
Connections.FogHandler2 = Lighting.DescendantAdded:Connect(function(obj)
    if not obj:IsA("Atmosphere") then return end
    obj:SetAttribute("Density_Old", obj.Density)
    local c = obj:GetPropertyChangedSignal("Density"):Connect(function()
        if obj.Density ~= 0 then obj:SetAttribute("Density_Old", obj.Density) end
    end)
    obj.Destroying:Once(function() c:Disconnect() end)
    table.insert(Connections, c)
    table.insert(Globals.FogInstances, obj)
end)

-- Данные сущностей
local EntityData = {
    ["RushMoving"]      = { Alias="Rush",            NotifyMessage={Title="Entity 'Rush' has spawned.",           Body="Find a hiding spot."}     },
    ["AmbushMoving"]    = { Alias="Ambush",          NotifyMessage={Title="Entity 'Ambush' has spawned.",         Body="Find a hiding spot."}     },
    ["Eyes"]            = { Alias="Eyes",            NotifyMessage={Title="Entity 'Eyes' has spawned.",           Body="Avoid looking at it."}    },
    ["Lookman"]         = { Alias="Eyes",            NotifyMessage={Title="Entity 'Eyes' has spawned.",           Body="Avoid looking at it."}    },
    ["BackdoorRush"]    = { Alias="Blitz",           NotifyMessage={Title="Entity 'Blitz' has spawned.",          Body="Find a hiding spot."}     },
    ["BackdoorLookman"] = { Alias="Lookman",         NotifyMessage={Title="Entity 'Lookman' has spawned.",        Body="Avoid looking at its eyes."} },
    ["Groundskeeper"]   = { Alias="Groundskeeper",   NotifyMessage={Title="Entity 'Groundskeeper' has spawned.", Body="Avoid the grass."}         },
    ["A60"]             = { Alias="A-60",            NotifyMessage={Title="Entity 'A-60' has spawned.",           Body="Find a hiding spot."}     },
    ["A120"]            = { Alias="A-120",           NotifyMessage={Title="Entity 'A-120' has spawned.",          Body="Find a hiding spot."}     },
    ["GloombatSwarm"]   = { Alias="Gloombat Swarm",  NotifyMessage={Title="Entity 'Gloombat Swarm' has spawned.",Body="Turn off all lights."}     },
    ["GlitchRush"]      = { Alias="RNIUSHCG==",      NotifyMessage={Title="Entity 'RNIUSHCG==' has spawned.",    Body="Find a hiding spot."}     },
    ["GlitchAmbush"]    = { Alias="AR0xMBUSH",       NotifyMessage={Title="Entity 'AR0xMBUSH' has spawned.",     Body="Find a hiding spot."}     },
    ["MonumentEntity"]  = { Alias="Monument",        NotifyMessage={Title="Entity 'Monument' has spawned.",      Body="Don't look away from it."} },
    ["JeffTheKiller"]   = { Alias="Jeff the Killer", NotifyMessage={Title="Entity 'Jeff the Killer' has spawned.",Body="Avoid touching him."}     },
    ["CustomEntity"]    = { Alias="Custom Entity",   NotifyMessage={Title="Entity 'Custom Entity' has spawned.", Body="Find a hiding spot."}     },
    ["FrozenAmbush"]    = { Alias="Frozen Ambush",   NotifyMessage={Title="Entity 'Frozen Ambush' has spawned.", Body="Find a hiding spot."}     },
    ["SallyMoving"]     = { Alias="Sally",           NotifyMessage={Title="Entity 'Sally' has spawned.",         Body="Drop an item for her."}   },
}

local EntityIcons = {
    ["RushMoving"]="rbxassetid://10716032262", ["AmbushMoving"]="rbxassetid://10110576663",
    ["A60"]="rbxassetid://12571092295",        ["A120"]="rbxassetid://12711591665",
    ["BackdoorRush"]="rbxassetid://16602023490",["Eyes"]="rbxassetid://10183704772",
    ["Lookman"]="rbxassetid://10183704772",    ["BackdoorLookman"]="rbxassetid://16764872677",
    ["GloombatSwarm"]="rbxassetid://79221203116470",["JeffTheKiller"]="rbxassetid://94479432156278",
    ["GlitchRush"]="rbxassetid://73859273102919",   ["GlitchAmbush"]="rbxassetid://88369678433359",
    ["SallyMoving"]="rbxassetid://10840888070",["MonumentEntity"]="rbxassetid://88933556873017",
    ["Groundskeeper"]="rbxassetid://114991380115557",
}

local EntityDistances = {
    ["RushMoving"]=85, ["AmbushMoving"]=150, ["A60"]=125, ["A120"]=85,
    ["GlitchRush"]=90, ["GlitchAmbush"]=175, ["BackdoorRush"]=85, ["CustomEntity"]=85,
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
    Wardrobe="Closet", Backdoor_Wardrobe="Closet", Toolshed="Closet",
    RetroWardrobe="Closet", ["Wardrobe-FOOLS26"]="Closet",
    Locker_Large="Locker", Rooms_Locker="Locker", Rooms_Locker_Fridge="Locker",
    Bed="Bed", Double_Bed="Double Bed", CircularVent="Vent", Dumpster="Dumpster",
}

local ChestLabels = {
    ChestBox=true, ChestBoxLocked=true, Toolbox=true, Toolbox_Locked=true,
    Chest_Vine="Vine Chest", Toolshed_Small="Toolshed",
    Locker_Small_Locked="Locked Item Locker", MouseHole="Mouse"
}

local EntityESPLabels = {
    JeffTheKiller="Jeff the Killer", GiggleCeiling="Giggle", Snare="Snare",
    GrumbleRig="Grumble", Hole="Mandrake Hole", Groundskeeper="Groundskeeper",
    LiveEntityBramble="Bramble", Figure="Figure", FigureRig="Figure",
    FigureRagdoll="Figure", FakeDoor="Dupe", DoorFake="Dupe",
    Drakobloxxer="Drakobloxxer", GloomPile="Gloombat Eggs",
}

local NodeEntities = {
    Rush=true, Ambush=true, Eyes=true, Blitz=true, Lookman=true,
    ["A-60"]=true, ["A-120"]=true, Sally=true, Monument=true,
    ["AR0xMBUSH"]=true, ["RNIUSHCG=="]=true,
}

local ObjectiveLabels = {
    KeyObtain="Door Key", ElectricalKeyObtain="Electrical Key",
    MinesGenerator="Generator", FuseObtain="Generator Fuse",
    LiveHintBook="Hint Book", LiveBreakerPolePickup="Fuse Breaker",
    LibraryHintPaper="Hint Paper", PickupItem="Hint Paper",
    CringlePresent="Present", LeverForGate="Gate Lever",
    MinesGateButton="Gate Button", GardenGateButton="Gate Button",
}

local CutsceneNames = {
    "Figure","FigureEnd","FigureHotelEnd","FigureHotelFire",
    "SeekIntroFools","SeekIntroHotel","SeekIntroMines","SeekIntroMines2",
    "SerewSeekDrain","SewerSeekLower","GrumbleNestEnd","EyestalkIntro",
}

local LockPromptNames = {
    UnlockPrompt=true, SkullPrompt=true, LockPrompt=true,
    ThingToEnable=true, FusesPrompt=true
}

-- Утилиты
local function notify(title, body, dur)
    Lib:Notify({ Title=title, Desc=body or "", Type="Info", Duration=dur or 5 })
end

local function sendChat(msg)
    pcall(function()
        local f = ReplicatedStorage:FindFirstChild("DefaultChatSystemEvents")
        local e = f and f:FindFirstChild("SayMessageRequest")
        if e then e:FireServer(msg,"All") end
        local ch = TextChatService:FindFirstChild("TextChannels")
        ch = ch and ch:FindFirstChild("RBXGeneral")
        if ch then ch:SendAsync(msg) end
    end)
end

local function isCrouching()
    if not Character then return false end
    if Floor=="Fools" or Floor=="OldHotel" then
        return Character:GetAttribute("Crouching") == true
    end
    return CollisionPart and CollisionPart.CollisionGroup=="PlayerCrouching"
end

local function getInjuriesSpeed()
    if not Humanoid then return 0 end
    return 0.075*(Humanoid.MaxHealth-Humanoid.Health)
end

local function getCurrentSpeed(speedBoostVal)
    local s=15
    if Character then
        s+=Character:GetAttribute("SpeedBoost") or 0
        s+=Character:GetAttribute("SpeedBoostBehind") or 0
        s+=Character:GetAttribute("SpeedBoostExtra") or 0
    end
    s+=(Floor=="Party" and 10 or 0)
    s+=(LiveModifiers:FindFirstChild("PlayerFast") and 3 or 0)
    s+=(LiveModifiers:FindFirstChild("PlayerFaster") and 6 or 0)
    s+=(LiveModifiers:FindFirstChild("PlayerFastest") and 20 or 0)
    s-=(LiveModifiers:FindFirstChild("PlayerSlow") and 3 or 0)
    s-=(LiveModifiers:FindFirstChild("PlayerSlowHealth") and getInjuriesSpeed() or 0)
    if isCrouching() then
        if LiveModifiers:FindFirstChild("PlayerCrouchSlow") then s-=8
        elseif LiveModifiers:FindFirstChild("PlayerSlow") then s-=8
        else s-=5 end
    end
    s+=(speedBoostVal or 0)
    return s
end

local function isHidePersistent()
    return Floor=="Mines" or Floor=="Ripple" or Floor=="Party"
        or LiveModifiers:FindFirstChild("HideLevel2")~=nil
end

local function hasItem(name, onlyChar)
    if not onlyChar and LP.Backpack:FindFirstChild(name) then
        return LP.Backpack:FindFirstChild(name)
    end
    if Character and Character:FindFirstChild(name) then
        return Character:FindFirstChild(name)
    end
end

local function getFlyVelocity()
    if Humanoid.MoveDirection==Vector3.zero then return Vector3.zero end
    local lookFlat = Vector3.new(Camera.CFrame.LookVector.X,0,Camera.CFrame.LookVector.Z)
    local flatFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position+lookFlat)
    local vel = (Camera.CFrame*CFrame.new(flatFrame:VectorToObjectSpace(Humanoid.MoveDirection))).Position - Camera.CFrame.Position
    if vel==Vector3.zero then return vel end
    return vel.Unit
end

local function getLibraryCode()
    local paper = (Character and (Character:FindFirstChild("LibraryHintPaper") or Character:FindFirstChild("LibraryHintPaperHard")))
        or LP.Backpack:FindFirstChild("LibraryHintPaper") or LP.Backpack:FindFirstChild("LibraryHintPaperHard")
    if paper and paper:FindFirstChild("UI") then
        local code={}
        local len = Floor=="Fools" and 10 or 5
        for i=1,len do code[i]="_" end
        for _,hint in LP.PlayerGui.PermUI.Hints:GetChildren() do
            for _,ui in paper.UI:GetChildren() do
                if hint:IsA("ImageLabel") and ui:IsA("ImageLabel")
                    and hint.ImageRectOffset==ui.ImageRectOffset
                    and code[tonumber(ui.Name)]
                then code[tonumber(ui.Name)]=hint.TextLabel.Text end
            end
        end
        return table.concat(code)
    end
    return Floor=="Fools" and "__________" or "_____"
end

local function getRandomCode()
    local tmpl=getLibraryCode()
    if not tmpl then return nil end
    local new; local tries=0
    repeat
        new=tmpl:gsub("_",function() return tostring(math.random(0,9)) end)
        tries+=1
    until not Globals.UsedRandomCodes[new] or tries>=10
    Globals.UsedRandomCodes[new]=true
    return new
end

local function getDoorNumber(obj)
    local n=tonumber(obj.Parent.Name) or tonumber(obj.Parent.Parent.Name)
    if n then n=n+1 end
    if Floor=="Mines" then n=(n or 0)+100 end
    if Floor=="Backdoor" then n=(n or 0)-50 end
    return tostring(n)
end

local function getMinecart()
    return Camera:FindFirstChild("MinecartRig")~=nil
end

local function getHasteTime()
    local t = FloorReplicated:FindFirstChild("DigitalTimer")
    if not t then return "??:??" end
    local mins=math.floor(t.Value/60)
    local secs=t.Value-(mins*60)
    return (mins<10 and "0" or "")..mins..":"..(secs<10 and "0" or "")..secs
end

-- ESP
local espObjects = {}
local espSettings = { fillT=0.75, outlineT=0, showDist=true, rainbow=false }

local function doAddESP(obj, label, color)
    if espObjects[obj] then return end
    local hl = Instance.new("Highlight")
    hl.FillColor    = color or Color3.new(1,1,1)
    hl.OutlineColor = color or Color3.new(1,1,1)
    hl.FillTransparency    = espSettings.fillT
    hl.OutlineTransparency = espSettings.outlineT
    hl.Adornee = obj
    hl.Parent  = workspace
    local bb, lbl
    if label then
        bb = Instance.new("BillboardGui")
        bb.AlwaysOnTop = true
        bb.Size = UDim2.new(0,200,0,40)
        bb.StudsOffsetWorldSpace = Vector3.new(0,3,0)
        local adornee = (obj:IsA("Model") and obj.PrimaryPart) or (obj:IsA("BasePart") and obj) or nil
        bb.Adornee = adornee
        bb.Parent = workspace
        lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = color or Color3.new(1,1,1)
        lbl.Text = label
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 14
        lbl.Parent = bb
    end
    espObjects[obj] = {hl=hl, bb=bb, lbl=lbl, color=color, label=label}
end

local function addESP(obj, label, color, roomBased)
    if table.find(ESPBlacklist,obj) then return end
    if roomBased then
        local curRoom = tonumber(LP:GetAttribute("CurrentRoom"))
        local objRoom = tonumber(obj:GetAttribute("ParentRoom"))
        if objRoom==curRoom or (table.find(Objects.Doors,obj) and objRoom==curRoom+1) then
            doAddESP(obj,label,color)
        end
        local conn = LP:GetAttributeChangedSignal("CurrentRoom"):Connect(function()
            local nr = tonumber(LP:GetAttribute("CurrentRoom"))
            local or2 = tonumber(obj:GetAttribute("ParentRoom"))
            if or2==nr or (table.find(Objects.Doors,obj) and or2==nr+1) then
                doAddESP(obj,label,color)
            else
                local d=espObjects[obj]
                if d then
                    if d.hl and d.hl.Parent then d.hl:Destroy() end
                    if d.bb and d.bb.Parent then d.bb:Destroy() end
                    espObjects[obj]=nil
                end
            end
        end)
        table.insert(Connections,conn)
        ESPConnections[obj]=conn
        obj.Destroying:Once(function()
            conn:Disconnect()
            local d=espObjects[obj]
            if d then
                if d.hl and d.hl.Parent then d.hl:Destroy() end
                if d.bb and d.bb.Parent then d.bb:Destroy() end
                espObjects[obj]=nil
            end
            local pos=table.find(Connections,conn)
            if pos then table.remove(Connections,pos) end
        end)
    else
        doAddESP(obj,label,color)
    end
end

local function removeESP(obj)
    local d=espObjects[obj]
    if not d then return end
    if d.hl and d.hl.Parent then d.hl:Destroy() end
    if d.bb and d.bb.Parent then d.bb:Destroy() end
    espObjects[obj]=nil
    local conn=ESPConnections[obj]
    if conn then
        conn:Disconnect()
        ESPConnections[obj]=nil
        local pos=table.find(Connections,conn)
        if pos then table.remove(Connections,pos) end
    end
end

local function blacklistESP(obj)
    table.insert(ESPBlacklist,obj)
    removeESP(obj)
end

local function updateESPColor(obj,color)
    local d=espObjects[obj]
    if not d then return end
    if d.hl then d.hl.FillColor=color d.hl.OutlineColor=color end
    if d.lbl then d.lbl.TextColor3=color end
    d.color=color
end

-- ESP updater (каждые 0.1с)
local lastESPUpdate=0
RunService.Heartbeat:Connect(function()
    if tick()-lastESPUpdate<0.1 then return end
    lastESPUpdate=tick()
    if not RootPart then return end
    for obj,d in pairs(espObjects) do
        if not obj.Parent then removeESP(obj) continue end
        if d.lbl and espSettings.showDist then
            local pos
            if obj:IsA("Model") and obj.PrimaryPart then pos=obj.PrimaryPart.Position
            elseif obj:IsA("BasePart") then pos=obj.Position end
            if pos then
                local dist=math.round((RootPart.Position-pos).Magnitude)
                d.lbl.Text=(d.label or "?").." ["..dist.."]"
            end
        end
        if espSettings.rainbow and d.hl then
            local c=Color3.fromHSV((tick()*0.3)%1,1,1)
            d.hl.FillColor=c d.hl.OutlineColor=c
            if d.lbl then d.lbl.TextColor3=c end
        end
    end
end)

-- ForceFirePrompt
local PromptsToFire = {}
local PromptCooldown = {}

local function forceFirePrompt(prompt)
    if not prompt or not prompt.Parent then return end
    if PromptCooldown[prompt] or table.find(PromptsToFire,prompt) then return end
    table.insert(PromptsToFire,prompt)
end

task.spawn(function()
    while task.wait() do
        local prompt = table.remove(PromptsToFire,1)
        if not prompt then continue end
        PromptCooldown[prompt]=true
        pcall(function()
            local oldDist   = prompt.MaxActivationDistance
            local oldEnable = prompt.Enabled
            local oldHold   = prompt.HoldDuration
            local oldLOS    = prompt.RequiresLineOfSight
            local oldParent = prompt.Parent
            prompt.MaxActivationDistance = 99999
            prompt.Enabled = true
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
            local tmp = Instance.new("Part",workspace)
            tmp.CanCollide=false tmp.CanQuery=false tmp.CanTouch=false
            tmp.Anchored=true tmp.Transparency=1
            tmp.Size=Vector3.new(0.001,0.001,0.001)
            tmp.Position=Camera.CFrame:ToWorldSpace(CFrame.new(0,0,-0.1)).Position
            pcall(function() prompt.Parent=tmp end)
            local shown,fired=false,false
            local sc=ProximityPromptService.PromptShown:Connect(function(p) if p==prompt then shown=true end end)
            local fc=prompt.Triggered:Connect(function() fired=true end)
            local t1=0
            while not shown and t1<5 do t1+=1 task.wait() end
            local t2=0
            while not fired and t2<5 do
                prompt:InputHoldBegin() prompt:InputHoldEnd()
                t2+=1 task.wait()
            end
            prompt.MaxActivationDistance=oldDist
            prompt.Enabled=oldEnable
            prompt.HoldDuration=oldHold
            prompt.RequiresLineOfSight=oldLOS
            pcall(function() prompt.Parent=oldParent end)
            task.wait()
            tmp:Destroy()
            sc:Disconnect() fc:Disconnect()
        end)
        PromptCooldown[prompt]=nil
    end
end)

-- Поиск ближайших объектов
local function getNearestEntity(checkDisabled, ignoreList)
    local best={dist=math.huge,obj=nil}
    for _,entity in workspace:GetChildren() do
        if entity and EntityDistances[entity.Name] and entity.PrimaryPart then
            local ed=EntityData[entity.Name]
            if not (ignoreList and ignoreList[ed and ed.Alias]) then
                local d=LP:DistanceFromCharacter(entity.PrimaryPart.Position)
                if d<EntityDistances[entity.Name] and d<best.dist then
                    if not checkDisabled or entity:GetAttribute("Inactive")~=true then
                        best.dist=d best.obj=entity
                    end
                end
            end
        end
    end
    return best.obj
end

local function getNearestFigure()
    local best={dist=math.huge,obj=nil}
    local names={FigureRig=true,FigureRagdoll=true,Figure=true}
    for _,obj in Objects.Entities do
        if obj:IsA("Model") and obj.PrimaryPart and names[obj.Name] then
            local d=LP:DistanceFromCharacter(obj.PrimaryPart.Position)
            if d<best.dist and d<25 then best.dist=d best.obj=obj end
        end
    end
    return best.obj
end

local function getNearestHidingSpot()
    local best={dist=math.huge,obj=nil}
    local lastHide=Character and Character:FindFirstChild("LastHideSpot")
    for _,obj in Objects.HidingSpots do
        if obj.PrimaryPart and obj:FindFirstChild("HidePrompt") then
            local d=LP:DistanceFromCharacter(obj.PrimaryPart.Position)
            if d<obj.HidePrompt.MaxActivationDistance and d<best.dist then
                if not isHidePersistent() or (lastHide and lastHide.Value~=obj) or not lastHide then
                    best.dist=d best.obj=obj
                end
            end
        end
    end
    return best.obj
end

local function getNearestTurnNode(dist)
    local best={dist=math.huge,obj=nil}
    for _,node in Objects.SeekNodes do
        local d=LP:DistanceFromCharacter(node.Position)
        if d<(dist or 30) and d<best.dist then best.dist=d best.obj=node end
    end
    return best.obj
end

local function getNearestDuckBoard(dist)
    local best={dist=math.huge,obj=nil}
    for _,board in Objects.SeekDuckBoards do
        if board.PrimaryPart then
            local d=LP:DistanceFromCharacter(board.PrimaryPart.Position)
            if d<(dist or 20) and d<best.dist then best.dist=d best.obj=board end
        end
    end
    return best.obj
end

local function getCurrentAnchor()
    if not Globals.MainUI then return end
    local af=Globals.MainUI:FindFirstChild("AnchorHintFrame")
    if not af then return end
    local code=af.AnchorCode.Text
    for _,anchor in Objects.Objectives do
        if anchor.Name=="MinesAnchor" and anchor:FindFirstChild("Sign") then
            if anchor.Sign.TextLabel.Text==code then return anchor end
        end
    end
end

-- AutoInteract blacklist
local AutoInteractBlacklist = {
    HidePrompt=true,RiftPrompt=true,StarRiftPrompt=true,InteractPrompt=true,
    ClimbPrompt=true,DonatePrompt=true,DialoguePrompt=true,RevivePrompt=true,
    EnterPrompt=true,AnimatePrompt=true,ToolEventPrompt=true,Prompt=true,PropPrompt=true
}

-- ==================== ОКНО ====================
local Win = Lib:Window({
    Title="Just X Hub", Icon="sword", Config="JustXHub_Main",
    Hotkey=Enum.KeyCode.RightShift, Settings=true,
})

local GeneralTab  = Win:Tab({Label="General",  Icon="home"})
local ExploitsTab = Win:Tab({Label="Exploits", Icon="shield"})
local VisualsTab  = Win:Tab({Label="Visuals",  Icon="eye"})
local FloorsTab   = Win:Tab({Label="Floors",   Icon="earth"})

-- ==================== GENERAL ====================
-- Character
local charSec = GeneralTab:Section({Title="Character", Column="left"})

local speedBoostVal=0
local speedBoostEnabled=false
local flyEnabled=false
local flySpeed=20
local noclipEnabled=false
local enableJump=false
local enableSlide=false
local infiniteJumps=false
local removeClosetDelay=false
local removeAcceleration=false

charSec:Slider({Name="Speed Boost", Flag="G_SpeedVal", Min=0, Max=100, Default=0, Decimals=0,
    Callback=function(v) speedBoostVal=v
        if speedBoostEnabled and Humanoid then Humanoid.WalkSpeed=getCurrentSpeed(v) end
    end})
charSec:Toggle({Name="Enable Speed Boost", Flag="G_Speed", Default=false,
    Callback=function(v) speedBoostEnabled=v
        if not v and Humanoid then Humanoid.WalkSpeed=getCurrentSpeed(0) end
    end})
charSec:Divider()
charSec:Toggle({Name="Fly", Flag="G_Fly", Default=false, Callback=function(v) flyEnabled=v end})
charSec:Slider({Name="Fly Speed", Flag="G_FlySpeed", Min=0, Max=115, Default=20, Decimals=0,
    Callback=function(v) flySpeed=v end})
charSec:Divider()
charSec:Toggle({Name="Noclip", Flag="G_Noclip", Default=false, Callback=function(v) noclipEnabled=v end})
charSec:Toggle({Name="Remove Closet Delay", Flag="G_ClosetDelay", Default=false,
    Callback=function(v) removeClosetDelay=v end})
charSec:Toggle({Name="Remove Acceleration", Flag="G_NoAccel", Default=false,
    Callback=function(v) removeAcceleration=v
        for idx, old in PartProperties do
            idx.CustomPhysicalProperties = v and (Character and Character:FindFirstChild("CustomPhysicsTemplate") and PhysicalProperties.new(100,idx.CustomPhysicalProperties.Friction,idx.CustomPhysicalProperties.Elasticity,idx.CustomPhysicalProperties.FrictionWeight,idx.CustomPhysicalProperties.ElasticityWeight) or old) or old
        end
    end})
charSec:Divider()
charSec:Toggle({Name="Enable Jumping", Flag="G_Jump", Default=false,
    Callback=function(v) enableJump=v
        if Character then Character:SetAttribute("CanJump",v and true or OldJump) end
    end})
charSec:Toggle({Name="Enable Sliding", Flag="G_Slide", Default=false,
    Callback=function(v) enableSlide=v
        if Character then Character:SetAttribute("CanSlide",v and true or OldSlide) end
    end})
charSec:Toggle({Name="Infinite Jumps", Flag="G_InfJumps", Default=false,
    Callback=function(v) infiniteJumps=v end})

-- Self
local selfSec = GeneralTab:Section({Title="Self", Column="left"})

local doorReach=false
local promptReach=1
local instantPrompts=false
local promptClip=false
local disableIdleKick=false

selfSec:Toggle({Name="Door Reach", Flag="S_DoorReach", Default=false,
    Callback=function(v) doorReach=v end})
selfSec:Toggle({Name="Disable Idle Kick", Flag="S_IdleKick", Default=false,
    Callback=function(v) disableIdleKick=v end})
selfSec:Divider()
selfSec:Slider({Name="Prompt Reach Multiplier", Flag="S_PromptReach", Min=1, Max=2, Default=1, Decimals=1,
    Callback=function(v) promptReach=v
        for _,p in Objects.Prompts do
            local old=p:GetAttribute("MaxActivationDistance_Old")
            if old then p.MaxActivationDistance=old*v end
        end
    end})
selfSec:Toggle({Name="Instant Prompts", Flag="S_InstantPrompts", Default=false,
    Callback=function(v) instantPrompts=v
        for _,p in Objects.Prompts do
            p.HoldDuration=v and 0 or (p:GetAttribute("HoldDuration_Old") or p.HoldDuration)
        end
    end})
selfSec:Toggle({Name="Prompt Clip", Flag="S_PromptClip", Default=false,
    Callback=function(v) promptClip=v
        for _,p in Objects.Prompts do
            p.RequiresLineOfSight=not v
        end
    end})

LP.Idled:Connect(function()
    if disableIdleKick then
        local vu=game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end
end)

-- Automation
local autoSec = GeneralTab:Section({Title="Automation", Column="right"})

local autoCloset=false
local autoClosetIgnoreList={}
local spectateEntity=false
local spectateMode="Player to Entity"
local autoBreakerBox=false
local autoHeartbeat=false
local autoSolveAnchors=false
local autoUnlockPadlock=false
local unlockDist=10
local autoGuessLibCode=false
local autoInteract=false
local autoInteractIgnoreList={}
local autoRevive=false

autoSec:Toggle({Name="Auto Closet", Flag="A_AutoCloset", Default=false,
    Callback=function(v) autoCloset=v end})
autoSec:Dropdown({Name="Auto Closet Ignore List", Flag="A_ClosetIgnore",
    Options={"Rush","Ambush","Blitz","A-60","A-120","AR0xMBUSH","RNIUSHCG=="},
    Default={}, Multi=true, Callback=function(v) autoClosetIgnoreList=v end})
autoSec:Toggle({Name="Spectate Entity", Flag="A_Spectate", Default=false,
    Callback=function(v) spectateEntity=v end})
autoSec:Dropdown({Name="Spectate Mode", Flag="A_SpectateMode",
    Options={"Player to Entity","Entity to Player"}, Default="Player to Entity",
    Callback=function(v) spectateMode=v end})
autoSec:Divider()
autoSec:Toggle({Name="Auto Breaker Box", Flag="A_BreakerBox", Default=false,
    Callback=function(v) autoBreakerBox=v
        if v and CurrentRooms:FindFirstChild("ElevatorBreaker",true) then
            if not Globals.BreakerBoxNotified then
                notify("Interact with the breaker box.","It will be automatically solved.")
                Globals.BreakerBoxNotified=true
            end
        end
    end})
autoSec:Toggle({Name="Auto Heartbeat Minigame", Flag="A_Heartbeat", Default=false,
    Callback=function(v) autoHeartbeat=v end})
autoSec:Toggle({Name="Auto Solve Anchors", Flag="A_Anchors", Default=false,
    Callback=function(v) autoSolveAnchors=v end})
autoSec:Divider()
autoSec:Toggle({Name="Auto Unlock Padlock", Flag="A_Padlock", Default=false,
    Callback=function(v) autoUnlockPadlock=v end})
autoSec:Slider({Name="Unlock Distance", Flag="A_PadlockDist", Min=1, Max=50, Default=10, Decimals=0,
    Callback=function(v) unlockDist=v end})
autoSec:Toggle({Name="Guess Library Code", Flag="A_LibGuess", Default=false,
    Callback=function(v) autoGuessLibCode=v end})
autoSec:Divider()
autoSec:Toggle({Name="Auto Interact", Flag="A_Interact", Default=false,
    Callback=function(v) autoInteract=v end})
autoSec:Dropdown({Name="Interact Ignore List", Flag="A_InteractIgnore",
    Options={"Glitch Fragments","Jeff Items","Dropped Items","Currency","Minecarts","Locks"},
    Default={"Glitch Fragments","Jeff Items","Dropped Items"}, Multi=true,
    Callback=function(v) autoInteractIgnoreList=v end})
autoSec:Divider()
autoSec:Toggle({Name="Infinite Revives", Flag="A_AutoRevive", Default=false,
    Callback=function(v) autoRevive=v end})

-- Misc
local miscSec = GeneralTab:Section({Title="Miscellaneous", Column="right"})
miscSec:Button({Name="Play Again",      Callback=function() pcall(function() RemotesFolder.PlayAgain:FireServer() end) end})
miscSec:Button({Name="Return to Lobby", Callback=function() pcall(function() RemotesFolder.Lobby:FireServer() end) end})
miscSec:Button({Name="Revive",          Callback=function() pcall(function() RemotesFolder.Revive:FireServer() end) end})
miscSec:Button({Name="Reset Character", Callback=function()
    Globals.SelfKilled=true
    if RemotesFolder:FindFirstChild("Underwater") then
        pcall(function() RemotesFolder.Underwater:FireServer(true) end)
    elseif Humanoid then Humanoid.Health=0 end
end})

-- Notifications
local notifySec = GeneralTab:Section({Title="Notifications", Column="right"})

local notifyEntities=false
local notifyEntityList={}
local notifyItems=false
local notifyItemList={}
local notifyItemDist=false
local notifyLibCode=false
local notifyOxygen=false
local notifyHasteTime=false
local notifyKeepNotifs=false
local entityChatEnabled=false

local entityOptions={"Rush","Ambush","Eyes","Halt","Blitz","Lookman","Gloombat Swarm","A-60","A-120","Sally","Jeff the Killer","Groundskeeper","Monument","AR0xMBUSH","RNIUSHCG=="}
local itemOptions={}
for _,v in pairs(ItemNames) do if not table.find(itemOptions,v) then table.insert(itemOptions,v) end end

notifySec:Dropdown({Name="Entity List", Flag="N_EntityList", Options=entityOptions,
    Default={}, Multi=true, Callback=function(v) notifyEntityList=v end})
notifySec:Toggle({Name="Notify Entities", Flag="N_Entities", Default=false,
    Callback=function(v) notifyEntities=v end})
notifySec:Divider()
notifySec:Dropdown({Name="Item List", Flag="N_ItemList", Options=itemOptions,
    Default={}, Multi=true, Callback=function(v) notifyItemList=v end})
notifySec:Toggle({Name="Notify Items", Flag="N_Items", Default=false,
    Callback=function(v) notifyItems=v end})
notifySec:Toggle({Name="Show Item Distance", Flag="N_ItemDist", Default=false,
    Callback=function(v) notifyItemDist=v end})
notifySec:Divider()
notifySec:Toggle({Name="Notify Library Code",  Flag="N_LibCode",    Default=false, Callback=function(v) notifyLibCode=v end})
notifySec:Toggle({Name="Notify Oxygen Level",  Flag="N_Oxygen",     Default=false, Callback=function(v) notifyOxygen=v end})
notifySec:Toggle({Name="Notify Haste Time",    Flag="N_HasteTime",  Default=false, Callback=function(v) notifyHasteTime=v end})
notifySec:Toggle({Name="Keep Notifications",   Flag="N_KeepNotifs", Default=false, Callback=function(v) notifyKeepNotifs=v end})
notifySec:Divider()
notifySec:Toggle({Name="Entity Chat Alert",    Flag="N_Chat",       Default=false, Callback=function(v) entityChatEnabled=v end})

-- Haste timer
if FloorReplicated:FindFirstChild("DigitalTimer") then
    Connections.HasteTimer = FloorReplicated.DigitalTimer:GetPropertyChangedSignal("Value"):Connect(function()
        if notifyHasteTime and Globals.MainUI then
            pcall(function()
                local caption = Globals.MainUI.MainFrame:WaitForChild("Caption",3)
                if caption then caption.Text=getHasteTime() end
            end)
        end
    end)
end

-- ==================== EXPLOITS ====================
-- Bypass Left
local bypassSec = ExploitsTab:Section({Title="Bypass", Column="left"})

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

bypassSec:Toggle({Name="Bypass Giggle",            Flag="B_Giggle",   Default=false, Callback=function(v) bypassGiggle=v
    for _,obj in Objects.Entities do if obj.Name=="GiggleCeiling" then
        pcall(function() obj:WaitForChild("Hitbox",3).CanTouch=not v end) end end end})
bypassSec:Toggle({Name="Bypass Dupe",              Flag="B_Dupe",     Default=false, Callback=function(v) bypassDupe=v
    for _,obj in Objects.Entities do if obj.Name=="DoorFake" or obj.Name=="FakeDoor" then
        pcall(function() obj:WaitForChild("Hidden",3).CanTouch=not v end)
        if obj:FindFirstChild("Lock") then pcall(function() obj.Lock.UnlockPrompt.Enabled=not v end) end end end end})
bypassSec:Toggle({Name="Bypass Eyes",              Flag="B_Eyes",     Default=false, Callback=function(v) bypassEyes=v
    if v and Globals.IsEyes then pcall(function()
        if Floor=="Fools" or Floor=="OldHotel" then RemotesFolder.MotorReplication:FireServer(0,(Globals.SpoofOffset==200 and 65 or -65),0,false)
        else RemotesFolder.MotorReplication:FireServer(-650) end end) end end})
bypassSec:Toggle({Name="Bypass Lookman",           Flag="B_Lookman",  Default=false, Callback=function(v) bypassLookman=v
    if v and Globals.IsLookman then pcall(function()
        if Floor=="Fools" or Floor=="OldHotel" then RemotesFolder.MotorReplication:FireServer(0,(Globals.SpoofOffset==200 and 65 or -65),0,false)
        else RemotesFolder.MotorReplication:FireServer(-650) end end) end end})
bypassSec:Toggle({Name="Bypass Gloombat Eggs",     Flag="B_Gloombat", Default=false, Callback=function(v) bypassGloombat=v
    for _,obj in Objects.Entities do if obj.Name=="GloomPile" then
        for _,p in obj:GetDescendants() do if p:IsA("BasePart") then p.CanTouch=not v end end end end end})
bypassSec:Toggle({Name="Bypass Seek Obstructions", Flag="B_SeekObs",  Default=false, Callback=function(v) bypassSeekObs=v
    for _,obj in Objects.SeekObstructions do obj.CanTouch=not v if obj.Name=="SeekFloodline" then obj.CanCollide=v end end
    for _,obj in Objects.SeekBridges do obj.CanCollide=v obj.Transparency=v and 0 or 1 end end})
bypassSec:Toggle({Name="Bypass Vacuum",            Flag="B_Vacuum",   Default=false, Callback=function(v) bypassVacuum=v
    for _,obj in Objects.Entities do if obj.Name=="SideroomSpace" then
        pcall(function() obj:WaitForChild("Collision",3).CanCollide=v obj:WaitForChild("Collision",3).CanTouch=not v end) end end end})
bypassSec:Toggle({Name="Bypass Killbricks",        Flag="B_Kill",     Default=false, Callback=function(v) bypassKillbrick=v
    for _,obj in Objects.Obstructions do if obj.Name=="Lava" then obj.CanTouch=not v end end end})
bypassSec:Toggle({Name="Bypass Seeking Wall",      Flag="B_SeekWall", Default=false, Callback=function(v) bypassSeekWall=v
    for _,obj in Objects.Obstructions do if obj.Name=="ScaryWall" then
        for _,p in obj:GetDescendants() do if p:IsA("BasePart") then p.CanTouch=not v p.CanCollide=not v end end end end end})
bypassSec:Toggle({Name="Bypass Snare",             Flag="B_Snare",    Default=false, Callback=function(v) bypassSnare=v
    for _,obj in Objects.Entities do if obj.Name=="Snare" then
        for _,p in obj:GetDescendants() do if p:IsA("BasePart") then p.CanTouch=not v end end end end end})
bypassSec:Toggle({Name="Bypass Banana",            Flag="B_Banana",   Default=false, Callback=function(v) bypassBanana=v
    for _,obj in Objects.Entities do if obj.Name=="BananaPeel" then obj.CanTouch=not v end end end})
bypassSec:Toggle({Name="Bypass Jeff",              Flag="B_Jeff",     Default=false, Callback=function(v) bypassJeff=v
    for _,obj in Objects.Entities do if obj.Name=="JeffTheKiller" then
        for _,p in obj:GetDescendants() do if p:IsA("BasePart") then p.CanCollide=not v p.CanTouch=not v end end
        pcall(function() obj:WaitForChild("Humanoid",3).Health=0 end) end end end})

-- Bypass Right
local bypassRightSec = ExploitsTab:Section({Title="Bypass", Column="right"})

local posSpoof=false
local crouchSpoof=false
local disableAnticheat=false
local velocityManip=false
local velocityManipMode="Velocity"
local infiniteItems=false
local infiniteItemList={}

bypassRightSec:Toggle({Name="Position Spoof", Flag="BR_PosSpoof", Default=false, Callback=function(v) posSpoof=v
    if Floor~="Fools" and Floor~="OldHotel" and RootPart then
        if v then RootPart.CFrame=RootPart.CFrame*CFrame.new(0,-2.346,0) Humanoid.HipHeight=0.05
               pcall(function() RemotesFolder.Crouch:FireServer(true,true) end)
        else   RootPart.CFrame=RootPart.CFrame*CFrame.new(0,2.346,0) Humanoid.HipHeight=2.396 end end end})
bypassRightSec:Toggle({Name="Crouch Spoof", Flag="BR_Crouch", Default=false, Callback=function(v) crouchSpoof=v
    if RemotesFolder:FindFirstChild("Crouch") then
        pcall(function() RemotesFolder.Crouch:FireServer(v or isCrouching(),true) end) end end})
bypassRightSec:Toggle({Name="Anticheat Bypass", Flag="BR_AC", Default=false, Callback=function(v) disableAnticheat=v
    if not v and Globals.AnticheatDisabled then
        pcall(function() RemotesFolder.ClimbLadder:FireServer() end)
        Globals.AnticheatDisabled=false
    end end})
bypassRightSec:Toggle({Name="Velocity Manipulation", Flag="BR_VelManip", Default=false,
    Callback=function(v) velocityManip=v end})
bypassRightSec:Dropdown({Name="Manipulation Method", Flag="BR_VelMode",
    Options={"Velocity","Pivot"}, Default="Velocity",
    Callback=function(v) velocityManipMode=v end})
bypassRightSec:Divider()
bypassRightSec:Toggle({Name="Infinite Items", Flag="BR_InfItems", Default=false,
    Callback=function(v) infiniteItems=v end})
bypassRightSec:Dropdown({Name="Item List", Flag="BR_InfItemList",
    Options={"Lockpicks","Skeleton Key","Shears","Multitool"},
    Default={}, Multi=true, Callback=function(v) infiniteItemList=v end})

-- Remove
local removeSec = ExploitsTab:Section({Title="Remove", Column="left"})

local removeScreech=false
local removeHalt=false
local removeA90=false
local removeDread=false
local removeSurge=false
local noScreechDmg=false
local noHaltDmg=false
local noA90Dmg=false
local noSurgeDmg=false

removeSec:Toggle({Name="Remove Screech", Flag="R_Screech", Default=false, Callback=function(v) removeScreech=v
    if Modules.Screech then Modules.Screech.Name=v and "Screech_Disabled" or "Screech" end
    if Modules.GlitchScreech then Modules.GlitchScreech.Name=v and "GlitchScreech_Disabled" or "GlitchScreech" end end})
removeSec:Toggle({Name="Remove Halt",    Flag="R_Halt",    Default=false, Callback=function(v) removeHalt=v
    if Modules.Shade then Modules.Shade.Name=v and "Shade_Disabled" or "Shade" end end})
removeSec:Toggle({Name="Remove A-90",   Flag="R_A90",     Default=false, Callback=function(v) removeA90=v
    if Modules.A90 then Modules.A90.Name=v and "A90_Disabled" or "A90" end end})
removeSec:Toggle({Name="Remove Dread",   Flag="R_Dread",   Default=false, Callback=function(v) removeDread=v
    if Modules.Dread then Modules.Dread.Name=v and "Dread_Disabled" or "Dread" end end})
removeSec:Toggle({Name="Remove Surge",   Flag="R_Surge",   Default=false, Callback=function(v) removeSurge=v
    if Globals.SurgeFrame then Globals.SurgeFrame.Name=v and "SurgeVignette_Disabled" or "SurgeVignette" end end})
removeSec:Divider()
removeSec:Toggle({Name="No Screech Damage", Flag="R_ScreechDmg", Default=false, Callback=function(v) noScreechDmg=v
    if v then FakeEvents.Screech.Parent=RemotesFolder FakeEvents.Screech_Real.Parent=nil
    else FakeEvents.Screech_Real.Parent=RemotesFolder FakeEvents.Screech.Parent=nil end end})
removeSec:Toggle({Name="No Halt Damage",    Flag="R_HaltDmg",    Default=false, Callback=function(v) noHaltDmg=v
    if v then FakeEvents.Shade.Parent=RemotesFolder FakeEvents.Shade_Real.Parent=nil
    else FakeEvents.Shade_Real.Parent=RemotesFolder FakeEvents.Shade.Parent=nil end end})
removeSec:Toggle({Name="No A-90 Damage",    Flag="R_A90Dmg",     Default=false, Callback=function(v) noA90Dmg=v
    if FakeEvents.A90_Real then
        if v then FakeEvents.A90.Parent=RemotesFolder FakeEvents.A90_Real.Parent=nil
        else FakeEvents.A90_Real.Parent=RemotesFolder FakeEvents.A90.Parent=nil end end end})
removeSec:Toggle({Name="No Surge Damage",   Flag="R_SurgeDmg",   Default=false, Callback=function(v) noSurgeDmg=v
    if FakeEvents.Surge_Real then
        if v then FakeEvents.Surge.Parent=RemotesFolder FakeEvents.Surge_Real.Parent=nil
        else FakeEvents.Surge_Real.Parent=RemotesFolder FakeEvents.Surge.Parent=nil end end end})

-- Audio
local audioSec = ExploitsTab:Section({Title="Audio", Column="right"})

local removeFootsteps=false
local removeJamminMusic=false
local removeInteractSounds=false

audioSec:Toggle({Name="Remove Footstep Sounds",    Flag="A_NoFoot",     Default=false, Callback=function(v) removeFootsteps=v end})
audioSec:Toggle({Name="Remove Jammin Music",       Flag="A_NoJammin",   Default=false, Callback=function(v) removeJamminMusic=v
    if Globals.MainUI then pcall(function()
        local jam=Globals.MainUI.Initiator.Main_Game.Health:FindFirstChild("Jam")
        if jam then jam.Volume=v and 0 or 0.45 end end) end end})
audioSec:Toggle({Name="Remove Interact Sounds",    Flag="A_NoInteract", Default=false, Callback=function(v) removeInteractSounds=v
    if Globals.MainUI then pcall(function()
        local PS=Globals.MainUI.Initiator.Main_Game.PromptService
        PS.Triggered.Volume=v and 0 or 0.04 PS.Holding.Volume=v and 0 or 0.1 PS.Notification.Volume=v and 0 or 0.03
        Globals.MainUI.Initiator.Main_Game.Reminder.Caption.Volume=v and 0 or 0.1 end) end end})

-- Floor Bypass (in Exploits)
local floorBypassSec = ExploitsTab:Section({Title="Floor Bypass", Column="right"})

local figureGodmode=false
local removeFigure=false
local removeSeekTrigger=false
local removeBasementGate=false
local removePaintingsDoor=false
local removeSkeletonDoor=false

floorBypassSec:Toggle({Name="Figure Godmode", Flag="FB_FigGod", Default=false, Callback=function(v) figureGodmode=v end})
floorBypassSec:Toggle({Name="Delete Figure",  Flag="FB_DelFig", Default=false, Callback=function(v) removeFigure=v end})
floorBypassSec:Divider()
floorBypassSec:Toggle({Name="Remove Basement Gate",  Flag="FB_Basement",  Default=false, Callback=function(v) removeBasementGate=v
    for _,obj in Objects.Obstructions do if obj.Name=="ThingToOpen" then
        obj:PivotTo(v and CFrame.new(-10000,-10000,-10000) or (obj:GetAttribute("OriginalPosition") or obj:GetPivot())) end end end})
floorBypassSec:Toggle({Name="Remove Paintings Door", Flag="FB_Paintings", Default=false, Callback=function(v) removePaintingsDoor=v
    for _,obj in Objects.Obstructions do if obj.Name=="MovingDoor" then
        obj:PivotTo(v and CFrame.new(-10000,-10000,-10000) or (obj:GetAttribute("OriginalPosition") or obj:GetPivot())) end end end})
floorBypassSec:Toggle({Name="Remove Skeleton Door",  Flag="FB_Skeleton",  Default=false, Callback=function(v) removeSkeletonDoor=v
    for _,obj in Objects.Obstructions do if obj.Name=="Wax_Door" then
        obj:PivotTo(v and CFrame.new(-10000,-10000,-10000) or (obj:GetAttribute("OriginalPosition") or obj:GetPivot())) end end end})

-- Misc Exploits
local exploitMiscSec = ExploitsTab:Section({Title="Misc", Column="left"})

local removeHideVignette=false
local disableFiredamp=false
local disableJumpscares=false
local disableGlitchJS=false
local disableTimothyJS=false
local disableVoidJS=false
local removeCutscenes=false

exploitMiscSec:Toggle({Name="Disable Hide Vignette",    Flag="E_NoVig",    Default=false, Callback=function(v) removeHideVignette=v
    if Globals.MainUI then pcall(function()
        local vig=Globals.MainUI:FindFirstChild("HideVignette") or Globals.MainUI.MainFrame:FindFirstChild("HideVignette")
        if vig then vig.Image=v and "Disabled" or "rbxassetid://6100076320" end end) end end})
exploitMiscSec:Toggle({Name="Disable Firedamp Effect",  Flag="E_NoFire",   Default=false, Callback=function(v) disableFiredamp=v
    if CurrentRooms then
        for _,obj in CurrentRooms:GetChildren() do
            if v then obj:SetAttribute("Firedamp",false)
                for _,fo in Camera:GetChildren() do if fo.Name=="LiveFiredamp" then fo:Destroy() end end
            else obj:SetAttribute("Firedamp",obj:GetAttribute("Firedamp_Old")) end
        end
        local old=LP:GetAttribute("CurrentRoom")
        LP:SetAttribute("CurrentRoom",0) task.wait() LP:SetAttribute("CurrentRoom",old)
    end end})
exploitMiscSec:Toggle({Name="Disable Entity Jumpscares",Flag="E_NoJS",     Default=false, Callback=function(v) disableJumpscares=v
    if Globals.MainUI then pcall(function()
        local js=Globals.MainUI.Initiator.Main_Game.RemoteListener:FindFirstChild("Jumpscares")
            or Globals.MainUI.Initiator.Main_Game.RemoteListener:FindFirstChild("Jumpscares_Disabled")
        if js then js.Name=v and "Jumpscares_Disabled" or "Jumpscares" end end) end end})
exploitMiscSec:Toggle({Name="Disable Glitch Jumpscare", Flag="E_NoGlitch", Default=false, Callback=function(v) disableGlitchJS=v
    if Modules.Glitch then Modules.Glitch.Name=v and "Glitch_Disabled" or "Glitch" end end})
exploitMiscSec:Toggle({Name="Disable Timothy Jumpscare",Flag="E_NoTimothy",Default=false, Callback=function(v) disableTimothyJS=v
    if Modules.SpiderJumpscare then Modules.SpiderJumpscare.Name=v and "SpiderJumpscare_Disabled" or "SpiderJumpscare" end end})
exploitMiscSec:Toggle({Name="Disable Void Jumpscare",  Flag="E_NoVoid",   Default=false, Callback=function(v) disableVoidJS=v
    if Modules.Void then Modules.Void.Name=v and "Void_Disabled" or "Void" end end})
exploitMiscSec:Divider()
exploitMiscSec:Toggle({Name="Remove Cutscenes",         Flag="E_NoCuts",   Default=false, Callback=function(v) removeCutscenes=v
    if Globals.MainUI then pcall(function()
        for _,obj in Globals.MainUI.Initiator.Main_Game.RemoteListener.Cutscenes:GetChildren() do
            if obj:IsA("ModuleScript") then
                local orig=obj:GetAttribute("OriginalName")
                if orig or table.find(CutsceneNames,obj.Name) then
                    if not orig then obj:SetAttribute("OriginalName",obj.Name) end
                    obj.Name=v and (obj.Name.."_Disabled") or (obj:GetAttribute("OriginalName"))
                end
            end
        end end) end end})

-- ==================== VISUALS ====================
-- Camera
local camSec = VisualsTab:Section({Title="Camera", Column="left"})

local ambientEnabled=false
local ambientColor=Color3.fromRGB(255,255,255)
local fovValue=70
local removeCamShake=false
local removeCamBobbing=false
local removeCamFog=false
local thirdPerson=false
local thirdX=1.5
local thirdY=1
local thirdZ=5
local thirdWallCheck=false
local viewmodelOffset=false
local viewmodelX=0
local viewmodelY=0
local viewmodelZ=0

camSec:Toggle({Name="Ambient", Flag="V_Ambient", Default=false, Callback=function(v) ambientEnabled=v
    if CurrentRooms then
        local r=CurrentRooms:FindFirstChild(tostring(LP:GetAttribute("CurrentRoom")))
        local old=r and r:GetAttribute("Ambient")
        TweenService:Create(Lighting,TweenInfo.new(0.2,Enum.EasingStyle.Exponential),{
            Ambient=v and ambientColor or (old or Color3.new(0,0,0))
        }):Play()
    end end})
camSec:ColorPicker({Name="Ambient Color", Flag="V_AmbientColor", Default=Color3.fromRGB(255,255,255),
    Callback=function(v) ambientColor=v
        if ambientEnabled then TweenService:Create(Lighting,TweenInfo.new(0.2,Enum.EasingStyle.Exponential),{Ambient=v}):Play() end end})
camSec:Slider({Name="Field of View", Flag="V_FOV", Min=1, Max=120, Default=70, Decimals=0,
    Callback=function(v) fovValue=v
        if Main_Game then Main_Game.fovtarget=v else Camera.FieldOfView=v end end})
camSec:Divider()
camSec:Toggle({Name="Remove Camera Shake",   Flag="V_NoCamShake", Default=false, Callback=function(v) removeCamShake=v
    if Main_Game then Main_Game.csgo=v and CFrame.new() or nil end end})
camSec:Toggle({Name="Remove Camera Bobbing", Flag="V_NoBob",      Default=false, Callback=function(v) removeCamBobbing=v
    if Main_Game then Main_Game.spring.Speed=v and 9e9 or 8 end end})
camSec:Toggle({Name="Remove Cutscenes",      Flag="V_NoCuts2",    Default=false, Callback=function(v) removeCutscenes=v end})
camSec:Toggle({Name="Remove Fog",            Flag="V_NoFog",      Default=false, Callback=function(v) removeCamFog=v
    Lighting.FogEnd=v and 1e7 or Globals.OldFog
    for _,atmo in Globals.FogInstances do atmo.Density=v and 0 or (atmo:GetAttribute("Density_Old") or 0) end end})
camSec:Divider()
camSec:Toggle({Name="Third Person", Flag="V_ThirdPerson", Default=false, Callback=function(v) thirdPerson=v
    if not v then Camera.CameraType=Enum.CameraType.Custom
        for _,p in Globals.ThirdPersonParts do p.Transparency=1 p.LocalTransparencyModifier=1 end end end})
camSec:Slider({Name="X Offset",    Flag="V_ThirdX",    Min=-10, Max=10, Default=1.5, Decimals=1, Callback=function(v) thirdX=v end})
camSec:Slider({Name="Y Offset",    Flag="V_ThirdY",    Min=-10, Max=10, Default=1,   Decimals=1, Callback=function(v) thirdY=v end})
camSec:Slider({Name="Z Offset",    Flag="V_ThirdZ",    Min=-10, Max=10, Default=5,   Decimals=1, Callback=function(v) thirdZ=v end})
camSec:Toggle({Name="Wall Check",  Flag="V_WallCheck", Default=false, Callback=function(v) thirdWallCheck=v end})
camSec:Divider()
camSec:Toggle({Name="Viewmodel Offset", Flag="V_ViewOff", Default=false, Callback=function(v) viewmodelOffset=v
    if Main_Game then Main_Game.tooloffset=v and Vector3.new(viewmodelX,viewmodelY,viewmodelZ) or Vector3.zero end end})
camSec:Slider({Name="VM X", Flag="V_VMX", Min=-10, Max=10, Default=0, Decimals=1, Callback=function(v) viewmodelX=v
    if Main_Game and viewmodelOffset then Main_Game.tooloffset=Vector3.new(v,viewmodelY,viewmodelZ) end end})
camSec:Slider({Name="VM Y", Flag="V_VMY", Min=-10, Max=10, Default=0, Decimals=1, Callback=function(v) viewmodelY=v
    if Main_Game and viewmodelOffset then Main_Game.tooloffset=Vector3.new(viewmodelX,v,viewmodelZ) end end})
camSec:Slider({Name="VM Z", Flag="V_VMZ", Min=-10, Max=10, Default=0, Decimals=1, Callback=function(v) viewmodelZ=v
    if Main_Game and viewmodelOffset then Main_Game.tooloffset=Vector3.new(viewmodelX,viewmodelY,v) end end})

-- Effects
local effectsSec = VisualsTab:Section({Title="Effects", Column="left"})

local transpHiding=false
local transpVal=0.5

local function applyHidingTransparency(toggle, slider)
    for _,obj in Objects.HidingSpots do
        local isHiding=false
        for _,child in obj:GetDescendants() do
            if child.Name=="HiddenPlayer" and child.Value==Character then isHiding=true break end
        end
        for _,part in obj:GetDescendants() do
            if part:IsA("BasePart") and part:GetAttribute("Transparency_Old") then
                TweenService:Create(part,TweenInfo.new(0.25,Enum.EasingStyle.Linear),{
                    Transparency=(toggle and isHiding) and slider or part:GetAttribute("Transparency_Old")
                }):Play()
            end
        end
    end
end

effectsSec:Toggle({Name="Transparent Hiding Spots", Flag="V_TranspHide", Default=false, Callback=function(v) transpHiding=v applyHidingTransparency(v,transpVal) end})
effectsSec:Slider({Name="Transparency", Flag="V_TranspVal", Min=0, Max=1, Default=0.5, Decimals=2, Callback=function(v) transpVal=v applyHidingTransparency(transpHiding,v) end})
effectsSec:Divider()
effectsSec:Toggle({Name="Disable Glitch Jumpscare",   Flag="V_NoGlitch2",  Default=false, Callback=function(v) disableGlitchJS=v
    if Modules.Glitch then Modules.Glitch.Name=v and "Glitch_Disabled" or "Glitch" end end})
effectsSec:Toggle({Name="Disable Timothy Jumpscare",  Flag="V_NoTimothy2", Default=false, Callback=function(v) disableTimothyJS=v
    if Modules.SpiderJumpscare then Modules.SpiderJumpscare.Name=v and "SpiderJumpscare_Disabled" or "SpiderJumpscare" end end})
effectsSec:Toggle({Name="Disable Void Jumpscare",     Flag="V_NoVoid2",    Default=false, Callback=function(v) disableVoidJS=v
    if Modules.Void then Modules.Void.Name=v and "Void_Disabled" or "Void" end end})
effectsSec:Divider()
effectsSec:Toggle({Name="Disable Hide Vignette",      Flag="V_NoVig2",     Default=false, Callback=function(v) removeHideVignette=v end})
effectsSec:Toggle({Name="Disable Firedamp Effect",    Flag="V_NoFire2",    Default=false, Callback=function(v) disableFiredamp=v end})
effectsSec:Toggle({Name="Disable Entity Jumpscares",  Flag="V_NoJS2",      Default=false, Callback=function(v) disableJumpscares=v end})

-- ESP
local espSec = VisualsTab:Section({Title="ESP", Column="right"})

local espEntities=false
local espEntityList={}
local espItems=false
local espDoors=false
local espChests=false
local espCurrency=false
local espHiding=false
local espObjective=false
local espPlayers=false
local espLadders=false

local espEntityColor=Color3.fromRGB(255,0,0)
local espItemColor=Color3.fromRGB(170,0,255)
local espDoorColor=Color3.fromRGB(0,200,255)
local espChestColor=Color3.fromRGB(255,255,0)
local espCurrencyColor=Color3.fromRGB(255,215,0)
local espHidingColor=Color3.fromRGB(255,170,0)
local espObjectiveColor=Color3.fromRGB(0,255,0)
local espPlayerColor=Color3.fromRGB(255,255,255)
local espLadderColor=Color3.fromRGB(255,255,255)

local entityESPOptions={"Rush","Ambush","Eyes","Dupe","Figure","Blitz","Lookman","Snare","Giggle","Gloombat Eggs","Grumble","A-60","A-120","Sally","Jeff the Killer","Groundskeeper","Mandrake Hole","Monument","Bramble","Drakobloxxer","AR0xMBUSH","RNIUSHCG=="}

espSec:Dropdown({Name="Entity List", Flag="ESP_EntityOpts", Options=entityESPOptions,
    Default={}, Multi=true, Callback=function(v) espEntityList=v
        for _,obj in Objects.Entities do
            local label=EntityESPLabels[obj.Name] or (EntityData[obj.Name] and EntityData[obj.Name].Alias)
            if label then
                if espEntities and v[label] then addESP(obj,label,espEntityColor,NodeEntities[label]~=true)
                else removeESP(obj) end
            end
        end end})
espSec:Toggle({Name="Entities ESP",   Flag="ESP_Entities",  Default=false, Callback=function(v) espEntities=v
    for _,obj in Objects.Entities do
        local label=EntityESPLabels[obj.Name] or (EntityData[obj.Name] and EntityData[obj.Name].Alias)
        if v and label and espEntityList[label] then addESP(obj,label,espEntityColor,NodeEntities[label]~=true)
        else removeESP(obj) end end end})
espSec:ColorPicker({Name="Entity Color", Flag="ESP_EntColor", Default=Color3.fromRGB(255,0,0),
    Callback=function(v) espEntityColor=v for _,obj in Objects.Entities do updateESPColor(obj,v) end end})
espSec:Divider()
espSec:Toggle({Name="Objective ESP",  Flag="ESP_Objectives", Default=false, Callback=function(v) espObjective=v
    for _,obj in Objects.Objectives do
        local label
        if obj.Name=="TimerLever" then label="Time Lever [+"..( obj:GetAttribute("AddTime") or "?").."s]"
        elseif obj.Name=="MinesAnchor" and obj:FindFirstChild("Sign") then label="Anchor ["..obj.Sign.TextLabel.Text.."]"
        else label=ObjectiveLabels[obj.Name] end
        if v and label then addESP(obj,label,espObjectiveColor,true) else removeESP(obj) end end end})
espSec:ColorPicker({Name="Objective Color", Flag="ESP_ObjColor", Default=Color3.fromRGB(0,255,0),
    Callback=function(v) espObjectiveColor=v for _,obj in Objects.Objectives do updateESPColor(obj,v) end end})
espSec:Divider()
espSec:Toggle({Name="Door ESP",       Flag="ESP_Doors",     Default=false, Callback=function(v) espDoors=v
    for _,obj in Objects.Doors do if v then addESP(obj,"Door",espDoorColor,true) else removeESP(obj) end end end})
espSec:ColorPicker({Name="Door Color", Flag="ESP_DoorColor", Default=Color3.fromRGB(0,200,255),
    Callback=function(v) espDoorColor=v for _,obj in Objects.Doors do updateESPColor(obj,v) end end})
espSec:Divider()
espSec:Toggle({Name="Hiding Spot ESP",Flag="ESP_Hiding",    Default=false, Callback=function(v) espHiding=v
    for _,obj in Objects.HidingSpots do
        local label=HidingSpotLabels[obj.Name]
        if v and label then addESP(obj,label,espHidingColor,true) else removeESP(obj) end end end})
espSec:ColorPicker({Name="Hiding Color", Flag="ESP_HideColor", Default=Color3.fromRGB(255,170,0),
    Callback=function(v) espHidingColor=v for _,obj in Objects.HidingSpots do updateESPColor(obj,v) end end})
espSec:Divider()
espSec:Toggle({Name="Chest ESP",      Flag="ESP_Chests",    Default=false, Callback=function(v) espChests=v
    for _,obj in Objects.Chests do
        local label
        if obj.Name=="ChestBox" or obj.Name=="ChestBoxLocked" then label=obj:GetAttribute("Locked") and "Locked Chest" or "Chest"
        elseif obj.Name=="Toolbox" or obj.Name=="Toolbox_Locked" then label=obj:GetAttribute("Locked") and "Locked Toolbox" or "Toolbox"
        elseif ChestLabels[obj.Name] and ChestLabels[obj.Name]~=true then label=ChestLabels[obj.Name] end
        if v and label then addESP(obj,label,espChestColor,true) else removeESP(obj) end end end})
espSec:ColorPicker({Name="Chest Color", Flag="ESP_ChestColor", Default=Color3.fromRGB(255,255,0),
    Callback=function(v) espChestColor=v for _,obj in Objects.Chests do updateESPColor(obj,v) end end})
espSec:Divider()
espSec:Toggle({Name="Item ESP",       Flag="ESP_Items",     Default=false, Callback=function(v) espItems=v
    for _,obj in Objects.Items do
        local label=ItemNames[obj.Name] or (obj.Name=="Green_Herb" and "Green Herb")
        if v and label then addESP(obj,label,espItemColor,obj:GetAttribute("ParentRoom")~=nil)
        else removeESP(obj) end end end})
espSec:ColorPicker({Name="Item Color", Flag="ESP_ItemColor", Default=Color3.fromRGB(170,0,255),
    Callback=function(v) espItemColor=v for _,obj in Objects.Items do updateESPColor(obj,v) end end})
espSec:Divider()
espSec:Toggle({Name="Currency ESP",   Flag="ESP_Currency",  Default=false, Callback=function(v) espCurrency=v
    for _,obj in Objects.Currency do
        local label=(obj.Name=="GoldPile" and "Gold Pile ["..(obj:GetAttribute("GoldValue") or "?").."]") or (obj.Name=="StardustPickup" and "Stardust Pile")
        if v and label then addESP(obj,label,espCurrencyColor,true) else removeESP(obj) end end end})
espSec:ColorPicker({Name="Currency Color", Flag="ESP_CurrColor", Default=Color3.fromRGB(255,215,0),
    Callback=function(v) espCurrencyColor=v for _,obj in Objects.Currency do updateESPColor(obj,v) end end})
espSec:Divider()
espSec:Toggle({Name="Player ESP",     Flag="ESP_Players",   Default=false, Callback=function(v) espPlayers=v
    for _,p in Players:GetPlayers() do if p~=LP and p.Character then
        if v and p:GetAttribute("Alive")==true then addESP(p.Character,p.Name,espPlayerColor)
        else removeESP(p.Character) end end end end})
espSec:ColorPicker({Name="Player Color", Flag="ESP_PlrColor", Default=Color3.fromRGB(255,255,255),
    Callback=function(v) espPlayerColor=v
        for _,p in Players:GetPlayers() do if p~=LP and p.Character then updateESPColor(p.Character,v) end end end})
espSec:Divider()
espSec:Toggle({Name="Ladder ESP",     Flag="ESP_Ladders",   Default=false, Callback=function(v) espLadders=v
    for _,obj in Objects.Ladders do if v then addESP(obj,"Ladder",espLadderColor,true) else removeESP(obj) end end end})
espSec:ColorPicker({Name="Ladder Color", Flag="ESP_LadderColor", Default=Color3.fromRGB(255,255,255),
    Callback=function(v) espLadderColor=v for _,obj in Objects.Ladders do updateESPColor(obj,v) end end})

-- ESP Settings
local espSettingsSec = VisualsTab:Section({Title="ESP Settings", Column="right"})
espSettingsSec:Toggle({Name="Show Distance",        Flag="ESP_ShowDist", Default=true,  Callback=function(v) espSettings.showDist=v end})
espSettingsSec:Toggle({Name="Rainbow Effect",       Flag="ESP_Rainbow",  Default=false, Callback=function(v) espSettings.rainbow=v end})
espSettingsSec:Slider({Name="Fill Transparency",    Flag="ESP_FillT",    Min=0, Max=1,  Default=0.75, Decimals=2,
    Callback=function(v) espSettings.fillT=v for _,d in pairs(espObjects) do if d.hl then d.hl.FillTransparency=v end end end})
espSettingsSec:Slider({Name="Outline Transparency", Flag="ESP_OutT",     Min=0, Max=1,  Default=0,    Decimals=2,
    Callback=function(v) espSettings.outlineT=v for _,d in pairs(espObjects) do if d.hl then d.hl.OutlineTransparency=v end end end})

-- ==================== FLOORS ====================
local floorAutoSec = FloorsTab:Section({Title="Automation", Column="left"})

local autoSteerMinecart=false
local autoSteerDist=30
local autoSteerDuckDist=20
local roomsAutoWalk=false
local roomsShowPath=false
local roomsPathTimeout=3

floorAutoSec:Toggle({Name="Auto Steer Minecart", Flag="F_Minecart", Default=false,
    Callback=function(v) autoSteerMinecart=v end})
floorAutoSec:Slider({Name="Turn Distance",  Flag="F_TurnDist",  Min=5,  Max=60, Default=30, Decimals=0, Callback=function(v) autoSteerDist=v end})
floorAutoSec:Slider({Name="Duck Distance",  Flag="F_DuckDist",  Min=5,  Max=40, Default=20, Decimals=0, Callback=function(v) autoSteerDuckDist=v end})
floorAutoSec:Divider()
floorAutoSec:Toggle({Name="Auto Rooms Walk", Flag="F_RoomsWalk", Default=false,
    Callback=function(v) roomsAutoWalk=v end})
floorAutoSec:Toggle({Name="Show Path", Flag="F_ShowPath", Default=false,
    Callback=function(v) roomsShowPath=v
        for _,obj in Globals.RoomsNodesFolder:GetChildren() do
            if obj.Name=="PathNode" then obj.Transparency=v and 0.5 or 1 end end end})
floorAutoSec:Slider({Name="Pathfind Timeout", Flag="F_PathTimeout", Min=1, Max=10, Default=3, Decimals=0,
    Callback=function(v) roomsPathTimeout=v end})

local floorVisSec = FloorsTab:Section({Title="Visuals", Column="left"})

local showSeekPath=false
local seekPathColor=Color3.fromRGB(0,255,0)
local showEyestalkPath=false
local eyestalkPathColor=Color3.fromRGB(0,255,0)

local function updateBeamVis(beams,vis)
    local t=vis and 0 or 1
    local seq=NumberSequence.new({NumberSequenceKeypoint.new(0,t),NumberSequenceKeypoint.new(1,t)})
    for _,beam in beams do beam.Transparency=seq end
end
local function updateBeamColor(beams,color)
    local seq=ColorSequence.new({ColorSequenceKeypoint.new(0,color),ColorSequenceKeypoint.new(1,color)})
    for _,beam in beams do beam.Color=seq end
end

floorVisSec:Toggle({Name="Show Seek Path",     Flag="F_SeekPath",      Default=false, Callback=function(v) showSeekPath=v updateBeamVis(Objects.SeekHighlights,v) end})
floorVisSec:ColorPicker({Name="Seek Color",    Flag="F_SeekPathColor", Default=Color3.fromRGB(0,255,0), Callback=function(v) seekPathColor=v updateBeamColor(Objects.SeekHighlights,v) end})
floorVisSec:Toggle({Name="Show Eyestalk Path", Flag="F_EyePath",       Default=false, Callback=function(v) showEyestalkPath=v updateBeamVis(Objects.EyestalkHighlights,v) end})
floorVisSec:ColorPicker({Name="Eyestalk Color",Flag="F_EyePathColor",  Default=Color3.fromRGB(0,255,0), Callback=function(v) eyestalkPathColor=v updateBeamColor(Objects.EyestalkHighlights,v) end})

local floorBypassSec2 = FloorsTab:Section({Title="Bypass", Column="right"})
floorBypassSec2:Toggle({Name="Delete Seek Trigger", Flag="F2_SeekTrig", Default=false, Callback=function(v) removeSeekTrigger=v end})
floorBypassSec2:Toggle({Name="Delete Figure",       Flag="F2_DelFig",   Default=false, Callback=function(v) removeFigure=v end})
floorBypassSec2:Toggle({Name="Figure Godmode",      Flag="F2_FigGod",   Default=false, Callback=function(v) figureGodmode=v end})
floorBypassSec2:Toggle({Name="Infinite Revives",    Flag="F2_AutoRev",  Default=false, Callback=function(v) autoRevive=v end})
floorBypassSec2:Divider()
floorBypassSec2:Toggle({Name="Remove Basement Gate",  Flag="F2_Basement",  Default=false, Callback=function(v) removeBasementGate=v
    for _,obj in Objects.Obstructions do if obj.Name=="ThingToOpen" then
        obj:PivotTo(v and CFrame.new(-10000,-10000,-10000) or (obj:GetAttribute("OriginalPosition") or obj:GetPivot())) end end end})
floorBypassSec2:Toggle({Name="Remove Paintings Door", Flag="F2_Paintings", Default=false, Callback=function(v) removePaintingsDoor=v
    for _,obj in Objects.Obstructions do if obj.Name=="MovingDoor" then
        obj:PivotTo(v and CFrame.new(-10000,-10000,-10000) or (obj:GetAttribute("OriginalPosition") or obj:GetPivot())) end end end})
floorBypassSec2:Toggle({Name="Remove Skeleton Door",  Flag="F2_Skeleton",  Default=false, Callback=function(v) removeSkeletonDoor=v
    for _,obj in Objects.Obstructions do if obj.Name=="Wax_Door" then
        obj:PivotTo(v and CFrame.new(-10000,-10000,-10000) or (obj:GetAttribute("OriginalPosition") or obj:GetPivot())) end end end})

local floorFarmSec = FloorsTab:Section({Title="Farming", Column="right"})
floorFarmSec:Toggle({Name="Knob Farm", Flag="F_KnobFarm", Default=false, Callback=function(v)
    if v then notify("Collect gold first.","Click 'Start Knob Farm' when ready.")
    else Globals.KnobFarmStarted=false end end})
floorFarmSec:Button({Name="Start Knob Farm", Callback=function()
    if LatestRoom and LatestRoom.Value~=0 then notify("Must be in Room 0.") return end
    Globals.KnobFarmStarted=true end})

local floorComplSec = FloorsTab:Section({Title="Completion", Column="right"})
floorComplSec:Button({Name="Auto Complete Dam Seek", Callback=function()
    if not LatestRoom or LatestRoom.Value<100 or Floor~="Mines" then
        notify("Must be in Room 200 (Mines).") return end
    task.spawn(function()
        local isCutscene=false
        local cc=RemotesFolder.Cutscene.OnClientEvent:Connect(function()
            isCutscene=true task.wait(7) isCutscene=false end)
        local function getNextPump()
            local best={h=-69420,obj=nil}
            for _,obj in Objects.Objectives do
                if obj.Name=="WaterPump" and obj:GetAttribute("Abysall_Completed")~=true and obj.PrimaryPart then
                    if obj.PrimaryPart.Position.Y>best.h then best.h=obj.PrimaryPart.Position.Y best.obj=obj end
                end
            end
            return best.obj
        end
        notify("Attempting to complete the valves.","Please wait.")
        while task.wait(0.1) do
            local pump=getNextPump()
            if pump then
                while task.wait(0.1) do
                    if isCutscene then continue end
                    pcall(function() Character:PivotTo(pump:GetPivot()) end)
                    local pr=pump:FindFirstChild("ValvePrompt",true)
                    if pr then forceFirePrompt(pr) end
                    if pump:GetAttribute("Abysall_Completed") then break end
                end
            else break end
        end
        notify("Valves completed!") cc:Disconnect()
    end)
end})
floorComplSec:Button({Name="Auto Complete Cringle", Callback=function()
    local touch=CurrentRooms:FindFirstChild("RippleExitDoor",true)
    if touch and Character then Character:PivotTo(touch:GetPivot()) end
end})

-- ==================== ЛОГИКА ====================
-- Fly
local FlyBody = Instance.new("BodyVelocity")
FlyBody.MaxForce = Vector3.new(9e9,9e9,9e9)
FlyBody.Velocity  = Vector3.zero
local ManipulateBody = Instance.new("BodyVelocity")
ManipulateBody.MaxForce = Vector3.new(9e9,9e9,9e9)
Globals.FlyBody = FlyBody
Globals.ManipulateBody = ManipulateBody

-- Infinite jumps
UserInputService.InputBegan:Connect(function(input,gpe)
    if gpe or Globals.IsTyping then return end
    if input.KeyCode==Enum.KeyCode.Space and infiniteJumps and Humanoid then
        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)
-- Mobile jump button handled in HandleCharacter

-- TextBox focus
UserInputService.TextBoxFocused:Connect(function() Globals.IsTyping=true end)
UserInputService.TextBoxFocusReleased:Connect(function() Globals.IsTyping=false end)

-- Player ESP handlers
Players.PlayerAdded:Connect(function(p)
    if p==LP then return end
    local cc=p.CharacterAdded:Connect(function(char)
        if espPlayers and p:GetAttribute("Alive")==true then addESP(char,p.Name,espPlayerColor) end
    end)
    local dc=p:GetAttributeChangedSignal("Alive"):Connect(function()
        if p:GetAttribute("Alive")~=true and p.Character then removeESP(p.Character) end
    end)
    table.insert(Connections,cc) table.insert(Connections,dc)
    p.Destroying:Once(function() cc:Disconnect() dc:Disconnect() end)
end)
for _,p in Players:GetPlayers() do
    if p~=LP then
        if p.Character and espPlayers and p:GetAttribute("Alive")==true then addESP(p.Character,p.Name,espPlayerColor) end
        local cc=p.CharacterAdded:Connect(function(char)
            if espPlayers and p:GetAttribute("Alive")==true then addESP(char,p.Name,espPlayerColor) end
        end)
        local dc=p:GetAttributeChangedSignal("Alive"):Connect(function()
            if p:GetAttribute("Alive")~=true and p.Character then removeESP(p.Character) end
        end)
        table.insert(Connections,cc) table.insert(Connections,dc)
    end
end

-- Infinite Items handler
Connections.InfItemsHandler = ProximityPromptService.PromptTriggered:Connect(function(obj)
    if not obj:GetAttribute("FakePrompt") then return end
    local anyTool = Character and Character:FindFirstChildOfClass("Tool")
    local toolData = anyTool and ItemNames[anyTool.Name]
    if anyTool and toolData and infiniteItems and infiniteItemList[toolData] then
        Drops.ChildAdded:Once(function(newTool)
            local pr=newTool:FindFirstChild("ModulePrompt")
            local real=FakePrompts[obj]
            if pr then forceFirePrompt(pr) end
            if real then forceFirePrompt(real) end
        end)
        pcall(function() RemotesFolder.DropItem:FireServer(anyTool) end)
    else
        local real=FakePrompts[obj]
        if real then forceFirePrompt(real) end
    end
end)

-- AutoInteract TriggerPrompt
local triggerDebounce=false
local function triggerPrompt(prompt)
    if AutoInteractBlacklist[prompt.Name] then return end
    if not prompt or not prompt.Parent then return end
    if triggerDebounce then return end
    local isLock = LockPromptNames[prompt.Name]
        or (prompt.Parent and prompt.Parent:GetAttribute("Locked")==true)
        or (prompt.Parent and prompt.Parent.Parent and prompt.Parent.Parent.Name=="Locker_Small_Locked" and prompt.Name=="ActivateEventPrompt")
    if isLock then
        if autoInteractIgnoreList["Locks"] then return end
        local keys={"Key","GeneratorFuse","KeyBackdoor","KeyElectrical","KeyIron","Lockpick","SkeletonKey","Shears","Multitool"}
        local hasKey=false
        for _,k in keys do if hasItem(k,true) or hasItem(k) then hasKey=true break end end
        if not hasKey then return end
    end
    local pn=prompt.Parent.Name
    if (pn=="CuttableVines" or pn=="Chest_Vine" or pn=="Cellar") and not hasItem("Shears",true) and not hasItem("Multitool",true) then return end
    if pn=="SkullLock" and not hasItem("SkeletonKey",true) then return end
    if (pn=="Lock1" or pn=="Lock2") and not hasItem("Lockpick",true) and not hasItem("Multitool",true) then return end
    if pn=="GlitchCube" and autoInteractIgnoreList["Glitch Fragments"] then return end
    if (pn=="GoldPile" or pn=="StardustPickup") and autoInteractIgnoreList["Currency"] then return end
    if prompt.Parent:GetAttribute("JeffShop") and autoInteractIgnoreList["Jeff Items"] then return end
    if prompt.Name=="PushPrompt" and autoInteractIgnoreList["Minecarts"] then return end
    if prompt:IsDescendantOf(Drops) and autoInteractIgnoreList["Dropped Items"] then return end
    if prompt.Name=="ActivateEventPrompt" and (prompt.ActionText=="Close" or pn=="ElevatorBreaker" or (prompt.Parent.Parent and prompt.Parent.Parent.Name=="IndustrialGate")) then return end
    if prompt.Name=="ActivateEventPrompt" and (pn=="Padlock" or pn=="MinesAnchor") then return end
    if pn=="LeverForGate" and prompt:GetAttribute("Interactions") then return end
    if prompt.Parent.Parent and (prompt.Parent.Parent.Name=="DoorFake" or prompt.Parent.Parent.Name=="FakeDoor") then return end
    if prompt.Name=="TrackLever" then return end
    if prompt:GetAttribute("AutoInteractIgnore") then return end
    forceFirePrompt(prompt)
    triggerDebounce=true
    if Floor=="OldHotel" then task.wait() end
    triggerDebounce=false
end

local lastAutoInteract=0
Connections.AutoInteract = RunService.Heartbeat:Connect(function()
    if not autoInteract then return end
    if tick()-lastAutoInteract<1/60 then return end
    for _,p in Objects.Prompts do
        if p:GetAttribute("ParentRoom") and tonumber(p:GetAttribute("ParentRoom"))~=tonumber(LP:GetAttribute("CurrentRoom")) then continue end
        if p.Parent and (p.Parent:IsA("BasePart") or p.Parent:IsA("Model")) then
            local dist
            if p.Parent:IsA("BasePart") then dist=LP:DistanceFromCharacter(p.Parent.Position)
            else dist=LP:DistanceFromCharacter(p.Parent:GetPivot().Position) end
            if (dist<=p.MaxActivationDistance and p.Enabled) or p.Name=="LongPushPrompt" or p.Name=="BigPropPrompt" then
                task.spawn(triggerPrompt,p)
            end
        end
    end
    lastAutoInteract=tick()
end)

-- PromptFixer
local lastPromptFix=0
Connections.PromptFixer = RunService.Heartbeat:Connect(function()
    if tick()-lastPromptFix<0.5 then return end
    lastPromptFix=tick()
    for _,p in Objects.Prompts do
        if p:HasTag("DisableWhenEnabledOnClient") then p:RemoveTag("DisableWhenEnabledOnClient") end
    end
end)

-- FloorReplicated handler
Connections.FloorRepHandler = FloorReplicated.DescendantAdded:Connect(function(obj)
    if obj.Name=="GlitchScreech" then
        Modules.GlitchScreech=obj
        if removeScreech then obj.Name="GlitchScreech_Disabled" end
    end
    if obj.Name:find("Jumpscare") and obj:IsA("ModuleScript")
        and not obj.Name:find("Eyestalk") and not obj.Name:find("Groundskeeper") and not obj.Name:find("Monument")
    then
        obj:SetAttribute("OriginalName",obj.Name)
        if disableJumpscares then obj.Name=obj.Name.."_Disabled" end
        table.insert(Objects.JumpscareModules,obj)
    end
end)

-- Entity handler (workspace.ChildAdded)
Connections.EntityHandler = workspace.ChildAdded:Connect(function(entity)
    local ed=EntityData[entity.Name]
    if not ed then return end
    task.spawn(function()
        while not entity.PrimaryPart do
            for _,c in entity:GetChildren() do if c:IsA("BasePart") then entity.PrimaryPart=c end end
            task.wait()
        end
        task.wait(0.1)
        if not entity.Parent or LP:DistanceFromCharacter(entity.PrimaryPart.Position)>=10000 then return end
        local alias=ed.Alias
        if notifyEntities and notifyEntityList[alias] then
            notify(ed.NotifyMessage.Title, ed.NotifyMessage.Body, 5)
        end
        if entityChatEnabled then sendChat(alias.." spotted!") end
        local label=EntityESPLabels[entity.Name] or alias
        if espEntities and espEntityList[label] then
            addESP(entity,label,espEntityColor,NodeEntities[alias]~=true)
        end
        if RusherAliases[alias] then
            Instance.new("Humanoid",entity).Name="HighlightHumanoid"
            local root=entity.PrimaryPart
            if root then root.Transparency=0.999 root.Material=Enum.Material.Plastic end
        end
        if entity.Name=="Eyes" then
            Globals.IsEyes=true
            entity.Destroying:Once(function() Globals.IsEyes=false end)
        end
        if entity.Name=="Lookman" or entity.Name=="BackdoorLookman" then
            Globals.IsLookman=true
            entity.Destroying:Once(function() Globals.IsLookman=false end)
        end
        if entity.Name=="Lookman" then
            CurrentRooms.ChildAdded:Wait()
            task.wait(10)
            pcall(function() entity:Destroy() end)
        end
    end)
end)

-- Cleaner
local lastClean=0
Connections.Cleaner = RunService.Heartbeat:Connect(function()
    if tick()-lastClean<0.5 then return end
    lastClean=tick()
    for _,array in {Objects.Entities,Objects.Items,Objects.Currency,Objects.Doors,
                    Objects.HidingSpots,Objects.Chests,Objects.Ladders,Objects.Obstructions,
                    Objects.Objectives,Objects.Prompts} do
        local i=#array
        while i>=1 do
            local obj=array[i]
            if obj==nil or not obj:IsDescendantOf(workspace) then
                table.remove(array,i)
                removeESP(obj)
            end
            i-=1
        end
    end
end)

-- ==================== MAIN HEARTBEAT ====================
local lastThrottle = {
    speed=0, anchors=0, padlock=0, knobfarm=0, closet=0,
}

Connections.MainHandler = RunService.RenderStepped:Connect(function()
    if not Character or not Humanoid or not RootPart then return end
    local t=tick()

    -- Speed
    if speedBoostEnabled then
        Humanoid.WalkSpeed=getCurrentSpeed(speedBoostVal)
    end

    -- Fly
    if flyEnabled then
        if FlyBody.Parent~=RootPart then FlyBody.Parent=RootPart end
        FlyBody.Velocity=getFlyVelocity()*flySpeed
        Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    else
        if FlyBody.Parent==RootPart then FlyBody.Parent=nil end
    end

    -- Velocity Manipulation
    if velocityManip and velocityManipMode=="Velocity" then
        ManipulateBody.Parent=RootPart
        ManipulateBody.Velocity=RootPart.CFrame.LookVector*2.25
    else
        ManipulateBody.Parent=nil
    end
    if velocityManip and velocityManipMode=="Pivot" and Floor~="Fools" and Floor~="OldHotel" then
        pcall(function() Character:PivotTo(Camera:GetPivot()*CFrame.new(0,0,2560)) end)
    end

    -- Eyes/Lookman bypass
    local doEyesBypass=(bypassEyes and Globals.IsEyes) or (bypassLookman and Globals.IsLookman)
    if doEyesBypass then
        pcall(function()
            if Floor=="Fools" or Floor=="OldHotel" then RemotesFolder.MotorReplication:FireServer(0,(Globals.SpoofOffset==200 and 65 or -65),0,false)
            else RemotesFolder.MotorReplication:FireServer(-650) end
        end)
    end

    -- Crouch fire (каждые 0.1с)
    if t-Globals.LastCrouchFire>0.1 then
        if RemotesFolder:FindFirstChild("Crouch") then
            local ic=isCrouching()
            if crouchSpoof or posSpoof then ic=true end
            pcall(function() RemotesFolder.Crouch:FireServer(ic,true) end)
        end
        Globals.LastCrouchFire=t
    end

    -- Animation check (каждые 0.1с)
    if t-Globals.LastAnimCheck>0.1 then
        local sliding=false
        for _,anim in Humanoid:GetPlayingAnimationTracks() do
            if anim.Name=="Slide" then sliding=true break end
        end
        Globals.Sliding=sliding
        Character:SetAttribute("Sliding",sliding)
        if Character:GetAttribute("Crouching")~=isCrouching() then
            Character:SetAttribute("Crouching",isCrouching())
        end
        Globals.LastAnimCheck=t
    end

    -- Collision handling
    if Floor=="OldHotel" or Floor=="Fools" then
        local spoofY=(posSpoof and getNearestEntity()) and 200 or (figureGodmode and getNearestFigure()) and 200 or 0
        Globals.SpoofOffset=spoofY
        if Collision then Collision.Position=RootPart.Position+Vector3.new(0,spoofY,0) Collision.CanCollide=false end
        if Floor=="Fools" and Collision and Collision:FindFirstChild("CollisionCrouch") then
            Collision.CollisionCrouch.CanCollide=false
        end
        if CollisionClone and Floor=="Fools" and CollisionClone:FindFirstChild("CollisionCrouch") then
            CollisionClone.CollisionCrouch.CanCollide=false
        end
        RootPart.CanCollide=not (noclipEnabled or velocityManip)
    else
        if Collision then
            Collision.CanCollide=false
            if Collision:FindFirstChild("CollisionCrouch") then Collision.CollisionCrouch.CanCollide=false end
        end
        if CollisionClone then
            if CollisionClone:FindFirstChild("CollisionCrouch") then
                local ic2=isCrouching()
                CollisionClone.CanCollide=not (noclipEnabled or velocityManip or ic2)
                CollisionClone.CollisionCrouch.CanCollide=not (noclipEnabled or velocityManip or not ic2)
            else
                RootPart.CanCollide=not (noclipEnabled or velocityManip)
            end
        end
        if Character and Character:FindFirstChild("LowerTorso") and Character.LowerTorso:FindFirstChild("Root") and Globals.OriginalC1 then
            Character.LowerTorso.Root.C1=Globals.OriginalC1*CFrame.new(0,posSpoof and -2.346 or 0,0)
        end
        local spoofY2=posSpoof and 2.328 or 0.18
        if Collision then Collision.Position=RootPart.Position+Vector3.new(0,spoofY2,0) end
        if CollisionPart then CollisionPart.Position=RootPart.Position+Vector3.new(0,spoofY2,0) end
        if CollisionClone then
            CollisionClone.CollisionGroup=Collision and Collision.CollisionGroup or "Default"
            CollisionClone.Position=RootPart.Position+Vector3.new(0,posSpoof and 1.75 or 0.18,0)
            if CollisionClone:FindFirstChild("CollisionCrouch") then
                CollisionClone.CollisionCrouch.Position=RootPart.Position+Vector3.new(0,posSpoof and 0.75 or -0.982,0)
                if Collision and Collision:FindFirstChild("CollisionCrouch") then
                    CollisionClone.CollisionCrouch.CollisionGroup=Collision.CollisionCrouch.CollisionGroup
                end
            end
        end
        if Collision and Collision:FindFirstChild("CollisionCrouch") and CollisionClone and CollisionClone:FindFirstChild("CollisionCrouch") then
            Collision.CollisionCrouch.Position=RootPart.Position+Vector3.new(0,posSpoof and 1.328 or -0.982,0)
        end
    end

    -- FOV + camera shake
    if Main_Game then
        Main_Game.fovtarget=fovValue
        if removeCamShake then Main_Game.csgo=CFrame.new() end
    else
        Camera.FieldOfView=fovValue
    end

    -- Remove closet delay
    if removeClosetDelay and Humanoid.MoveDirection~=Vector3.zero
        and CollisionPart and (CollisionPart.Anchored or RootPart.Anchored)
        and Character:GetAttribute("AnimatingClient")~=true
        and Character:GetAttribute("Hiding")==true
    then
        pcall(function() RemotesFolder.CamLock:FireServer() end)
    end

    -- Third Person
    if thirdPerson then
        Camera.CameraType=Enum.CameraType.Scriptable
        local tpOffset=CFrame.new(thirdX,thirdY,thirdZ)
        local dir=(Camera.CFrame*tpOffset).Position-Camera.CFrame.Position
        if thirdWallCheck then
            RayParams.FilterDescendantsInstances={Character}
            local wr=workspace:Spherecast(Camera.CFrame.Position,0.2,dir,RayParams)
            if wr and wr.Instance.CanCollide then
                local np=Camera.CFrame.Position+dir.Unit*wr.Distance
                Camera.CFrame=CFrame.new(np,np+Camera.CFrame.LookVector)
            else
                Camera.CFrame=Camera.CFrame*tpOffset
            end
        else
            Camera.CFrame=Camera.CFrame*tpOffset
        end
        for _,p in Globals.ThirdPersonParts do p.Transparency=0 p.LocalTransparencyModifier=0 end
    end

    -- Spectate entity
    if Globals.SpectateEntity and autoCloset and spectateEntity then
        local ent=Globals.SpectateEntity
        if ent and ent.PrimaryPart then
            Camera.CameraType=Enum.CameraType.Scriptable
            local cf
            if spectateMode=="Player to Entity" then
                cf=CFrame.lookAt(Character.Head.Position,ent.PrimaryPart.Position)
            else
                cf=CFrame.lookAt(ent.PrimaryPart.Position,Character.Head.Position)
            end
            Camera.CFrame=cf
        end
    end

    -- Auto closet (throttle 0.1s)
    if t-lastThrottle.closet>0.1 then
        if autoCloset then
            local entity=getNearestEntity(true,autoClosetIgnoreList)
            if entity then
                Globals.AutoClosetActive=true
                local closet=getNearestHidingSpot()
                if Character:GetAttribute("Hiding")~=true and closet then
                    forceFirePrompt(closet.HidePrompt)
                end
                if Character:GetAttribute("Hiding") and spectateEntity and entity.PrimaryPart then
                    Globals.SpectateEntity=entity
                end
            elseif Character:GetAttribute("Hiding")==true then
                Globals.SpectateEntity=nil
                Globals.AutoClosetActive=false
                pcall(function() RemotesFolder.CamLock:FireServer() end)
            else
                Globals.SpectateEntity=nil
                Globals.AutoClosetActive=false
            end
        end
        lastThrottle.closet=t
    end

    -- Auto solve anchors (throttle 0.1s)
    if t-lastThrottle.anchors>0.1 then
        if autoSolveAnchors and Globals.MainUI and Globals.MainUI:FindFirstChild("AnchorHintFrame") then
            pcall(function()
                local anchor=getCurrentAnchor()
                if anchor and LP:DistanceFromCharacter(anchor.PrimaryPart.Position)<anchor.ActivateEventPrompt.MaxActivationDistance
                    and not anchor:GetAttribute("Activated")
                then
                    anchor:WaitForChild("AnchorRemote",2):InvokeServer(Globals.MainUI.AnchorHintFrame.Code.Text)
                end
            end)
        end
        lastThrottle.anchors=t
    end

    -- Auto unlock padlock (throttle 0.1s)
    if t-lastThrottle.padlock>0.1 then
        if autoUnlockPadlock then
            pcall(function()
                local padlock=workspace:FindFirstChild("Padlock",true)
                if padlock and padlock.PrimaryPart and LP:DistanceFromCharacter(padlock.PrimaryPart.Position)<unlockDist then
                    local code=getLibraryCode()
                    if code and tonumber(code) then
                        RemotesFolder.PL:FireServer(code)
                    end
                end
                if autoGuessLibCode and LatestRoom and LatestRoom.Value==50 then
                    local guessed=getRandomCode()
                    if guessed then pcall(function() RemotesFolder.PL:FireServer(guessed) end) end
                end
            end)
        end
        lastThrottle.padlock=t
    end

    -- Knob Farm
    if t-lastThrottle.knobfarm>0.1 then
        if Globals.KnobFarmStarted and not Globals.KnobFarmActive then
            Globals.KnobFarmActive=true
            task.spawn(function()
                if RemotesFolder:FindFirstChild("Underwater") then
                    pcall(function() RemotesFolder.Underwater:FireServer(true) end)
                elseif Humanoid then Humanoid.Health=0 end
                while task.wait() do if LP:GetAttribute("Alive") then break end end
                pcall(function() RemotesFolder.Statistics:FireServer() end)
                task.wait(0.25)
                Globals.KnobFarmActive=false
            end)
        end
        lastThrottle.knobfarm=t
    end

    -- Minecart
    if autoSteerMinecart and getMinecart() then
        Globals.NearestTurnNode=getNearestTurnNode(autoSteerDist)
        local duckBoard=getNearestDuckBoard(autoSteerDuckDist)
        if not Globals.AutoMinecartDucked and duckBoard then
            if Main_Game then pcall(function() Main_Game.crouch(true) end) end
            Globals.AutoMinecartDucked=true
        elseif not duckBoard and Globals.AutoMinecartDucked then
            if Main_Game then pcall(function() Main_Game.crouch(false) end) end
            Globals.AutoMinecartDucked=false
        end
        if Globals.NearestTurnNode and Main_Game then
            -- steer via Controls handled in HandleCharacter
        end
    end

    -- Figure godmode
    if figureGodmode then
        for _,obj in Objects.Entities do
            if obj.Name=="Figure" or obj.Name=="FigureRig" or obj.Name=="FigureRagdoll" then
                pcall(function()
                    local h=obj:FindFirstChildOfClass("Humanoid")
                    if h and h.Health~=h.MaxHealth then h.Health=h.MaxHealth end
                end)
            end
        end
    end
end)

-- Auto Revive
LP:GetAttributeChangedSignal("Alive"):Connect(function()
    if LP:GetAttribute("Alive")==false and autoRevive then
        task.spawn(function()
            while LP:GetAttribute("Alive")~=true do
                pcall(function() RemotesFolder.Revive:FireServer() end)
                task.wait(0.5)
            end
        end)
    end
end)

-- ==================== HandleObject ====================
local function handleObject(obj)
    if not obj or not obj.Parent then return end

    -- Set ParentRoom
    if CurrentRooms then
        for _,room in CurrentRooms:GetChildren() do
            if obj:IsDescendantOf(room) then
                obj:SetAttribute("ParentRoom",tonumber(room.Name))
                break
            end
        end
    end

    -- Firedamp
    if obj.Parent==CurrentRooms then
        local fdv=obj:GetAttribute("Firedamp")
        obj:SetAttribute("Firedamp_Old",fdv~=nil and fdv or false)
        if disableFiredamp then obj:SetAttribute("Firedamp",false) end
    end

    local name=obj.Name

    -- Objectives
    if name=="KeyObtain" then
        task.spawn(function() task.wait(0.5) if obj.Parent then
            if espObjective then addESP(obj,"Door Key",espObjectiveColor,true) end
            table.insert(Objects.Objectives,obj) end end)
    elseif name=="ElectricalKeyObtain" then
        task.spawn(function() task.wait(0.5) if obj.Parent then
            if espObjective then addESP(obj,"Electrical Key",espObjectiveColor,true) end
            table.insert(Objects.Objectives,obj) end end)
    elseif name=="TimerLever" then
        task.spawn(function() task.wait(0.5) if obj.Parent then
            obj:SetAttribute("AddTime", obj:FindFirstChild("TakeTimer") and obj.TakeTimer:FindFirstChild("TextLabel") and obj.TakeTimer.TextLabel.Text=="01:00" and 60 or 30)
            local label="Time Lever [+"..obj:GetAttribute("AddTime").."s]"
            if espObjective then addESP(obj,label,espObjectiveColor,true) end
            pcall(function() obj:WaitForChild("Main",3).SoundToPlay.Played:Once(function() blacklistESP(obj) end) end)
            table.insert(Objects.Objectives,obj) end end)
    elseif name=="LiveHintBook" then
        if espObjective then addESP(obj,"Hint Book",espObjectiveColor,true) end
        table.insert(Objects.Objectives,obj)
    elseif name=="LiveBreakerPolePickup" then
        if espObjective then addESP(obj,"Fuse Breaker",espObjectiveColor,true) end
        for _,child in obj:GetChildren() do
            if child.Name=="ActivateEventPrompt" and child.MaxActivationDistance==5 then child:Destroy() end
        end
        table.insert(Objects.Objectives,obj)
    elseif name=="LibraryHintPaper" or name=="PickupItem" then
        if espObjective then addESP(obj,"Hint Paper",espObjectiveColor,true) end
        table.insert(Objects.Objectives,obj)
    elseif name=="MinesAnchor" then
        task.spawn(function()
            local sign=obj:WaitForChild("Sign",5)
            local label=sign and "Anchor ["..sign.TextLabel.Text.."]" or "Anchor"
            if espObjective then addESP(obj,label,espObjectiveColor,true) end
            obj:GetAttributeChangedSignal("Activated"):Once(function() blacklistESP(obj) end)
            table.insert(Objects.Objectives,obj)
        end)
    elseif name=="WaterPump" then
        task.spawn(function()
            local wheel=obj:WaitForChild("Wheel",5)
            if wheel then
                if espObjective then addESP(wheel,"Water Pump",espObjectiveColor,true) end
                wheel.Sound.Played:Once(function()
                    obj:SetAttribute("Abysall_Completed",true)
                    blacklistESP(wheel)
                end)
            end
            table.insert(Objects.Objectives,obj)
        end)
    elseif name=="CringlePresent" then
        if espObjective then addESP(obj,"Present",espObjectiveColor,true) end
        pcall(function() obj:WaitForChild("ToolProp",3).Highlight:Destroy() end)
        table.insert(Objects.Objectives,obj)
    elseif name=="LeverForGate" then
        if espObjective then addESP(obj,"Gate Lever",espObjectiveColor,true) end
        pcall(function() obj:WaitForChild("Main",3).SoundToPlay.Played:Once(function() blacklistESP(obj) end) end)
        table.insert(Objects.Objectives,obj)
    elseif name=="VineGuillotine" then
        if espObjective then addESP(obj.Lever,"Vine Lever",espObjectiveColor,true) end
        pcall(function() obj.Lever:WaitForChild("ActivateEventPrompt",3):GetAttributeChangedSignal("Interactions"):Once(function() blacklistESP(obj) end) end)
        table.insert(Objects.Objectives,obj)
    elseif name=="MandrakeLive" then
        pcall(function()
            if espEntities and espEntityList["Mandrake Hole"] then addESP(obj.Hole,"Mandrake Hole",espEntityColor,true) end
            table.insert(Objects.Entities,obj.Hole)
        end)
    elseif name=="MinesGenerator" then
        task.spawn(function() task.wait(0.75) if obj.Parent then
            if espObjective then addESP(obj,"Generator",espObjectiveColor,true) end
            pcall(function() obj:WaitForChild("Lever",3).Sound.Played:Once(function() blacklistESP(obj) end) end)
            table.insert(Objects.Objectives,obj) end end)

    -- Hiding spots
    elseif HidingSpotLabels[name] then
        if espHiding then addESP(obj,HidingSpotLabels[name],espHidingColor,true) end
        for _,p in obj:GetDescendants() do
            if p:IsA("BasePart") then p:SetAttribute("Transparency_Old",p.Transparency) end
        end
        -- Hiding transparency watcher
        for _,child in obj:GetDescendants() do
            if child.Name=="HiddenPlayer" then
                local hc=child:GetPropertyChangedSignal("Value"):Connect(function()
                    for _,p in obj:GetDescendants() do
                        if p:IsA("BasePart") and p:GetAttribute("Transparency_Old") then
                            TweenService:Create(p,TweenInfo.new(0.25,Enum.EasingStyle.Linear),{
                                Transparency=(child.Value==Character and transpHiding) and transpVal or p:GetAttribute("Transparency_Old")
                            }):Play()
                        end
                    end
                end)
                table.insert(Connections,hc)
                obj.Destroying:Once(function() hc:Disconnect() end)
            end
        end
        table.insert(Objects.HidingSpots,obj)

    -- Chests
    elseif ChestLabels[name] then
        local label
        if name=="ChestBox" or name=="ChestBoxLocked" then label=obj:GetAttribute("Locked") and "Locked Chest" or "Chest"
        elseif name=="Toolbox" or name=="Toolbox_Locked" then label=obj:GetAttribute("Locked") and "Locked Toolbox" or "Toolbox"
        elseif ChestLabels[name]~=true then label=ChestLabels[name] end
        if espChests and label then addESP(obj,label,espChestColor,true) end
        table.insert(Objects.Chests,obj)

    -- Items
    elseif ItemNames[name] and obj:FindFirstChild("ModulePrompt") then
        local label=ItemNames[name]
        if espItems then addESP(obj,label,espItemColor,obj:GetAttribute("ParentRoom")~=nil) end
        if notifyItems and notifyItemList[label] and obj.Parent and obj.Parent.Name~="Drops" then
            if notifyItemDist and obj.PrimaryPart then
                notify("Item '"..label.."' spawned!","Distance: "..math.round(LP:DistanceFromCharacter(obj.PrimaryPart.Position)).." studs")
            else
                notify("Item '"..label.."' spawned!")
            end
        end
        if (name=="LotusHolder" or name=="LotusPetalPickup") and obj:FindFirstChild("Handle") then
            obj.Handle:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
                blacklistESP(obj)
            end)
        end
        table.insert(Objects.Items,obj)
    elseif name=="Green_Herb" then
        if espItems then addESP(obj,"Green Herb",espItemColor,true) end
        table.insert(Objects.Items,obj)

    -- Currency
    elseif name=="GoldPile" and obj:GetAttribute("GoldValue") then
        local label="Gold Pile ["..(obj:GetAttribute("GoldValue") or "?").."]"
        if espCurrency then addESP(obj,label,espCurrencyColor,true) end
        table.insert(Objects.Currency,obj)
    elseif name=="StardustPickup" then
        if espCurrency then addESP(obj,"Stardust Pile",espCurrencyColor,true) end
        table.insert(Objects.Currency,obj)

    -- Ladders
    elseif name=="Ladder" then
        if espLadders then addESP(obj,"Ladder",espLadderColor,true) end
        table.insert(Objects.Ladders,obj)

    -- Doors
    elseif name=="Door" and obj.Parent and tonumber(obj.Parent.Name) then
        local doorParts={}
        for _,child in obj:GetChildren() do
            if child.Name=="Door" and child:IsA("BasePart") then table.insert(doorParts,child) end
        end
        if #doorParts>=1 then
            local hl=Instance.new("Model",obj)
            hl.Name="HighlightModel"
            Instance.new("Humanoid",hl).Name="HighlightHumanoid"
            hl:SetAttribute("ParentRoom",tonumber(obj.Parent.Name))
            for _,dp in doorParts do
                local hp=Instance.new("Part",hl)
                hp.Transparency=0.999 hp.Size=dp.Size hp.CanCollide=false
                hp.CFrame=dp.CFrame hp.Material=Enum.Material.Plastic
                hp:SetAttribute("ParentRoom",tonumber(obj.Parent.Name))
                local w=Instance.new("WeldConstraint",hp)
                w.Part0=hp w.Part1=dp w.Enabled=true
            end
            table.insert(Objects.Doors,hl)
            if espDoors then addESP(hl,"Door "..getDoorNumber(obj),espDoorColor,true) end
        end
        -- Door reach
        local lastFire=tick()
        local dc=RunService.Heartbeat:Connect(function()
            if doorReach and obj:FindFirstChild("Door") and obj:FindFirstChild("ClientOpen") then
                local door=obj:FindFirstChild("Door")
                if door and LP:DistanceFromCharacter(door.Position)<75 and tick()-lastFire>0.1 then
                    pcall(function() obj.ClientOpen:FireServer() end)
                    lastFire=tick()
                end
            end
        end)
        table.insert(Connections,dc)
        pcall(function()
            obj:WaitForChild("Door",5):WaitForChild("Open",5).Played:Once(function() dc:Disconnect() end)
        end)

    -- Entities (bypass)
    elseif name=="GiggleCeiling" then
        if espEntities and espEntityList["Giggle"] then addESP(obj,"Giggle",espEntityColor,true) end
        if bypassGiggle then pcall(function() obj:WaitForChild("Hitbox",3).CanTouch=false end) end
        table.insert(Objects.Entities,obj)
    elseif name=="GloomPile" then
        if bypassGloombat then
            for _,p in obj:GetDescendants() do if p:IsA("BasePart") then p.CanTouch=false end end
        end
        local gc=obj.DescendantAdded:Connect(function(p)
            if p:IsA("BasePart") and bypassGloombat then p.CanTouch=false end
        end)
        table.insert(Connections,gc)
        obj.Destroying:Once(function() gc:Disconnect() end)
        if espEntities and espEntityList["Gloombat Eggs"] then addESP(obj,"Gloombat Eggs",espEntityColor,false) end
        table.insert(Objects.Entities,obj)
    elseif name=="GrumbleRig" then
        if espEntities and espEntityList["Grumble"] then addESP(obj,"Grumble",espEntityColor,true) end
        table.insert(Objects.Entities,obj)
    elseif name=="LiveEntityBramble" then
        if espEntities and espEntityList["Bramble"] then addESP(obj,"Bramble",espEntityColor,true) end
        table.insert(Objects.Entities,obj)
    elseif name=="Groundskeeper" then
        if espEntities and espEntityList["Groundskeeper"] then addESP(obj,"Groundskeeper",espEntityColor,true) end
        if notifyEntities and notifyEntityList["Groundskeeper"] then
            notify("Entity 'Groundskeeper' has spawned.","Avoid the grass.")
        end
        table.insert(Objects.Entities,obj)
    elseif name=="Figure" or name=="FigureRig" or name=="FigureRagdoll" then
        for _,p in obj:GetDescendants() do if p:IsA("BasePart") then p.CanTouch=false end end
        if espEntities and espEntityList["Figure"] then addESP(obj,"Figure",espEntityColor,true) end
        table.insert(Objects.Entities,obj)
    elseif name=="JeffTheKiller" then
        if bypassJeff then
            for _,p in obj:GetDescendants() do if p:IsA("BasePart") then p.CanCollide=false p.CanTouch=false end end
            pcall(function() obj:WaitForChild("Humanoid",3).Health=0 end)
        end
        if espEntities and espEntityList["Jeff the Killer"] then addESP(obj,"Jeff the Killer",espEntityColor,true) end
        table.insert(Objects.Entities,obj)
    elseif name=="DoorFake" or name=="FakeDoor" then
        if obj:FindFirstChild("Hidden") then
            if bypassDupe then
                pcall(function() obj:WaitForChild("Hidden",3).CanTouch=false end)
                if obj:FindFirstChild("Lock") and obj.Lock:FindFirstChild("UnlockPrompt") then
                    obj.Lock.UnlockPrompt.Enabled=false
                end
            end
            if espEntities and espEntityList["Dupe"] then addESP(obj,"Dupe",espEntityColor,true) end
            table.insert(Objects.Entities,obj)
        end
    elseif name=="SideroomSpace" then
        if bypassVacuum then
            pcall(function()
                obj:WaitForChild("Collision",3).CanCollide=true
                obj:WaitForChild("Collision",3).CanTouch=false
            end)
        end
        table.insert(Objects.Entities,obj)
    elseif name=="Snare" then
        if espEntities and espEntityList["Snare"] then addESP(obj,"Snare",espEntityColor,true) end
        for _,p in obj:GetDescendants() do if p:IsA("BasePart") then p.CanTouch=not bypassSnare end end
        local sc=obj.DescendantAdded:Connect(function(p) if p:IsA("BasePart") then p.CanTouch=not bypassSnare end end)
        table.insert(Connections,sc)
        obj.Destroying:Once(function() sc:Disconnect() end)
        -- Snare visual
        if obj:FindFirstChild("Snare") then
            pcall(function()
                obj.Snare:WaitForChild("Roots",3).Transparency=1
                obj.Snare:WaitForChild("SnareBase",3).Transparency=1
            end)
        end
        if obj:FindFirstChild("Void") then
            obj.Void.Transparency=0
            obj.Void.Color=Color3.fromRGB(76,67,55)
        end
        table.insert(Objects.Entities,obj)
    elseif name=="BananaPeel" then
        if bypassBanana then obj.CanTouch=false end
        table.insert(Objects.Entities,obj)
    elseif name=="Seek_Arm" or name=="ChandelierObstruction" then
        for _,p in obj:GetDescendants() do
            if p:IsA("BasePart") then p.CanTouch=not bypassSeekObs table.insert(Objects.SeekObstructions,p) end
        end
    elseif name=="SeekFloodline" then
        obj.CanCollide=bypassSeekObs
        obj.CanTouch=not bypassSeekObs
        local fc=obj:GetPropertyChangedSignal("CanCollide"):Connect(function()
            if obj.CanCollide~=bypassSeekObs then obj.CanCollide=bypassSeekObs end
        end)
        obj.Destroying:Once(function() fc:Disconnect() end)
        table.insert(Objects.SeekObstructions,obj)
    elseif name=="SeekBridge" then
        obj.CanCollide=bypassSeekObs
        obj.Transparency=bypassSeekObs and 0 or 1
        table.insert(Objects.SeekBridges,obj)
    elseif obj:GetAttribute("RawName") and tostring(obj:GetAttribute("RawName")):find("Halt")
        or obj:GetAttribute("Shade")==true
    then
        if notifyEntities and notifyEntityList["Halt"] then
            notify("Entity 'Halt' will spawn in the next room.")
            if entityChatEnabled then sendChat("Halt next room!") end
        end
    elseif name=="Lava" then
        if bypassKillbrick then obj.CanTouch=false end
        table.insert(Objects.Obstructions,obj)
    elseif name=="ScaryWall" then
        for _,p in obj:GetDescendants() do
            if p:IsA("BasePart") then p.CanTouch=not bypassSeekWall p.CanCollide=not bypassSeekWall end
        end
        table.insert(Objects.Obstructions,obj)
    elseif (name=="ThingToOpen" or name=="MovingDoor") and (Floor=="Fools" or Floor=="OldHotel")
        or name=="Wax_Door" and Floor=="Fools"
    then
        obj:SetAttribute("OriginalPosition",obj:GetPivot())
        local toggleMap={ThingToOpen=removeBasementGate,MovingDoor=removePaintingsDoor,Wax_Door=removeSkeletonDoor}
        if toggleMap[name] then obj:PivotTo(CFrame.new(-10000,-10000,-10000)) end
        table.insert(Objects.Obstructions,obj)
    elseif name=="TriggerEventCollision" then
        if (Floor=="Fools" or Floor=="OldHotel") and removeSeekTrigger then
            task.spawn(function()
                while obj:IsDescendantOf(game) do
                    for _,p in obj:GetChildren() do
                        if p:IsA("BasePart") then
                            pcall(function()
                                p.CanTouch=false p.CanCollide=false
                            end)
                        end
                    end
                    task.wait()
                end
            end)
        end
        table.insert(Objects.EventTriggers,obj)
    elseif name=="ElevatorBreaker" then
        if autoBreakerBox and not Globals.BreakerBoxNotified then
            notify("Interact with the breaker box.","It will be automatically solved.")
            Globals.BreakerBoxNotified=true
        end
        local bc=obj:WaitForChild("SurfaceGui",5)
        if bc then
            local code=bc:FindFirstChild("Frame") and bc.Frame:FindFirstChild("Code")
            if code then
                Connections.BreakerConn=code:GetPropertyChangedSignal("Text"):Connect(function()
                    if autoBreakerBox then
                        if not Globals.BreakerBoxStartNotified then
                            notify("Solving breaker box.","Please wait.")
                            Globals.BreakerBoxStartNotified=true
                        end
                        pcall(function() RemotesFolder.EBF:FireServer() end)
                    end
                    Globals.BreakerBoxInteracted=true
                end)
            end
        end
    elseif name=="Padlock" then
        -- handled in heartbeat (padlock throttle)
    elseif obj:IsA("ProximityPrompt") and not obj:GetAttribute("FakePrompt") then
        if obj:HasTag("DisableWhenEnabledOnClient") then obj:RemoveTag("DisableWhenEnabledOnClient") end
        obj:SetAttribute("HoldDuration_Old",obj.HoldDuration)
        obj:SetAttribute("RequiresLineOfSight_Old",obj.RequiresLineOfSight)
        obj:SetAttribute("MaxActivationDistance_Old",obj.MaxActivationDistance)
        if instantPrompts then obj.HoldDuration=0 end
        if promptClip then obj.RequiresLineOfSight=false end
        obj.MaxActivationDistance=obj:GetAttribute("MaxActivationDistance_Old")*promptReach
        table.insert(Objects.Prompts,obj)
    end
end

-- Сканируем существующие объекты
task.spawn(function()
    if CurrentRooms then
        for _,room in CurrentRooms:GetChildren() do
            for _,obj in room:GetDescendants() do pcall(handleObject,obj) end
        end
        Connections.RoomsHandler = CurrentRooms.ChildAdded:Connect(function(room)
            for _,obj in Globals.RoomsNodesFolder:GetChildren() do
                if obj.Name=="StuckPart" then obj:Destroy() end
            end
            -- Eyestalk path
            if room:GetAttribute("RawName") and tostring(room:GetAttribute("RawName")):find("Eyestalk") then
                task.spawn(function()
                    room:WaitForChild("RoomEntrance",9e9)
                    room:WaitForChild("RoomExit",9e9)
                    local prevNode=nil
                    local function createNode(pos)
                        local n=Instance.new("Part")
                        n.Size=Vector3.one n.Transparency=1 n.Anchored=true
                        n.CanCollide=false n.Position=pos n.Name="SeekLightNode"
                        n.Parent=Globals.SeekNodesFolder
                        local prev=prevNode or n
                        prevNode=n
                        local beam=Instance.new("Beam")
                        beam.FaceCamera=true beam.Width0=0.2 beam.Width1=0.2
                        beam.Brightness=10 beam.LightInfluence=0 beam.LightEmission=0 beam.Enabled=true
                        local vis=showEyestalkPath and 0 or 1
                        beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,vis),NumberSequenceKeypoint.new(1,vis)})
                        beam.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,eyestalkPathColor),ColorSequenceKeypoint.new(1,eyestalkPathColor)})
                        beam.Parent=Globals.SeekNodesFolder
                        local a0=Instance.new("Attachment",n)
                        local a1=Instance.new("Attachment",prev)
                        beam.Attachment0=a0 beam.Attachment1=a1
                        table.insert(Objects.EyestalkHighlights,beam)
                    end
                    while not room:GetAttribute("PathFound") do
                        if showEyestalkPath and RootPart then
                            local path=PathfindingService:CreatePath({AgentCanJump=false,AgentCanClimb=false,WaypointSpacing=2,AgentRadius=1,AgentHeight=1})
                            path:ComputeAsync(RootPart.Position,room.RoomExit.Position)
                            if path.Status==Enum.PathStatus.Success then
                                room:SetAttribute("PathFound",true)
                                for _,wp in path:GetWaypoints() do createNode(wp.Position) task.wait() end
                                break
                            end
                        end
                        task.wait(0.25)
                    end
                end)
            end
            task.wait(0.1)
            room.DescendantAdded:Connect(function(obj) pcall(handleObject,obj) end)
            for _,obj in room:GetDescendants() do pcall(handleObject,obj) end
        end)
    end
    workspace.ChildAdded:Connect(function(obj) pcall(handleObject,obj) end)
    if Drops then
        for _,obj in Drops:GetChildren() do pcall(handleObject,obj) end
        Drops.ChildAdded:Connect(function(obj) pcall(handleObject,obj) end)
    end
end)

-- ==================== HandleCharacter ====================
local function handleCharacter(newChar)
    while not LP.PlayerGui:FindFirstChild("MainUI") do task.wait() end

    Character = newChar
    Humanoid  = newChar:WaitForChild("Humanoid",9e9)
    RootPart  = newChar:FindFirstChild("HumanoidRootPart")
    Camera    = workspace.CurrentCamera

    Globals.MainUI = LP.PlayerGui.MainUI

    Collision    = newChar:WaitForChild("Collision",5)
    CollisionPart = newChar:FindFirstChild("CollisionPart") or newChar:FindFirstChild("Collision")

    if Collision then
        CollisionClone = Collision:Clone()
        CollisionClone.Parent=newChar CollisionClone.Name="CollisionClone" CollisionClone.Massless=true
        if CollisionClone:FindFirstChild("CollisionCrouch") then
            CollisionClone.CollisionCrouch:Destroy()
        end
    end
    if CollisionPart then
        CollisionPartClone = CollisionPart:Clone()
        CollisionPartClone.Parent=newChar CollisionPartClone.Name="CollisionPartClone"
        CollisionPartClone.CanCollide=false CollisionPartClone.Massless=true
    end

    Character:SetAttribute("SpeedBoost",0)
    Character:SetAttribute("SpeedBoostBehind",0)
    Character:SetAttribute("SpeedBoostExtra",0)

    OldJump  = newChar:GetAttribute("CanJump")
    OldSlide = newChar:GetAttribute("CanSlide")

    if enableJump  then Character:SetAttribute("CanJump",true) end
    if enableSlide then Character:SetAttribute("CanSlide",true) end

    -- Third person parts
    Globals.ThirdPersonParts={}
    for _,obj in newChar:GetDescendants() do
        if obj:IsA("Accessory") and obj:FindFirstChild("Handle") then
            table.insert(Globals.ThirdPersonParts,obj.Handle)
        end
    end
    local head=newChar:WaitForChild("Head",5)
    if head then table.insert(Globals.ThirdPersonParts,head) end

    -- OriginalC1
    if newChar:FindFirstChild("LowerTorso") and newChar.LowerTorso:FindFirstChild("Root") then
        Globals.OriginalC1=newChar.LowerTorso.Root.C1
    end

    -- PhysicalProperties
    PartProperties={}
    local customPhysics = CollisionPart and PhysicalProperties.new(
        100,
        CollisionPart.CustomPhysicalProperties.Friction,
        CollisionPart.CustomPhysicalProperties.Elasticity,
        CollisionPart.CustomPhysicalProperties.FrictionWeight,
        CollisionPart.CustomPhysicalProperties.ElasticityWeight
    )
    for _,p in newChar:GetDescendants() do
        if p:IsA("BasePart") then
            PartProperties[p]=p.CustomPhysicalProperties
            if removeAcceleration and customPhysics then p.CustomPhysicalProperties=customPhysics end
        end
    end

    -- Load modules
    pcall(function()
        local rl=Globals.MainUI.Initiator.Main_Game.RemoteListener
        local uim=rl.Modules
        Modules.A90             = uim:FindFirstChild("A90")
        Modules.Screech         = uim:FindFirstChild("Screech")
        Modules.Dread           = uim:FindFirstChild("Dread")
        Modules.SpiderJumpscare = uim:FindFirstChild("SpiderJumpscare")

        local clientModules=ReplicatedStorage:FindFirstChild("ModulesClient") or ReplicatedStorage:FindFirstChild("ClientModules")
        if clientModules then
            local em=clientModules:FindFirstChild("EntityModules")
            if em then
                Modules.Glitch = em:FindFirstChild("Glitch")
                Modules.Shade  = em:FindFirstChild("Shade")
                Modules.Void   = em:FindFirstChild("Void")
            end
        end

        if removeScreech and Modules.Screech then Modules.Screech.Name="Screech_Disabled" end
        if removeA90 and Modules.A90 then Modules.A90.Name="A90_Disabled" end
        if removeDread and Modules.Dread then Modules.Dread.Name="Dread_Disabled" end
        if disableTimothyJS and Modules.SpiderJumpscare then Modules.SpiderJumpscare.Name="SpiderJumpscare_Disabled" end
        if disableGlitchJS and Modules.Glitch then Modules.Glitch.Name="Glitch_Disabled" end
        if disableVoidJS and Modules.Void then Modules.Void.Name="Void_Disabled" end
        if disableJumpscares then
            local js=rl:FindFirstChild("Jumpscares")
            if js then js.Name="Jumpscares_Disabled" end
        end
        if removeHideVignette then
            local vig=Globals.MainUI:FindFirstChild("HideVignette") or Globals.MainUI.MainFrame:FindFirstChild("HideVignette")
            if vig then vig.Image="Disabled" end
        end
        if removeInteractSounds then
            local PS=Globals.MainUI.Initiator.Main_Game.PromptService
            PS.Triggered.Volume=0 PS.Holding.Volume=0 PS.Notification.Volume=0
            Globals.MainUI.Initiator.Main_Game.Reminder.Caption.Volume=0
        end
        for _,obj in rl.Cutscenes:GetChildren() do
            if obj:IsA("ModuleScript") and (table.find(CutsceneNames,obj.Name) or table.find(CutsceneNames,obj:GetAttribute("OriginalName"))) then
                if not obj:GetAttribute("OriginalName") then obj:SetAttribute("OriginalName",obj.Name) end
                if removeCutscenes then obj.Name=obj.Name.."_Disabled" end
            end
        end

        Main_Game = require(Globals.MainUI.Initiator.Main_Game)
        if removeCamBobbing and Main_Game then Main_Game.spring.Speed=9e9 end
        if removeCamShake and Main_Game then Main_Game.csgo=CFrame.new() end
        if viewmodelOffset and Main_Game then Main_Game.tooloffset=Vector3.new(viewmodelX,viewmodelY,viewmodelZ) end

        -- Surge frame
        Globals.SurgeFrame = Globals.MainUI.MainFrame:FindFirstChild("SurgeVignette")

        -- Jammin music
        local jam=Globals.MainUI.Initiator.Main_Game.Health:FindFirstChild("Jam")
        if jam and removeJamminMusic then jam.Volume=0 end

        -- Minecart steering via Controls
        if Main_Game then
            local ok, Controls = pcall(function()
                return require(LP.PlayerScripts.PlayerModule):GetControls()
            end)
            if ok and Controls then
                local origGetMove=Controls.GetMoveVector
                Globals.OriginalGetMoveVector=origGetMove
                Controls.GetMoveVector=function(...)
                    if autoSteerMinecart and Floor=="Mines" and getMinecart() then
                        local node=Globals.NearestTurnNode
                        if node then
                            local turn=node:GetAttribute("Turn")
                            return turn=="Left" and Vector3.new(-1,0,0) or turn=="Right" and Vector3.new(1,0,0) or Vector3.zero
                        end
                    end
                    return origGetMove(...)
                end
            end
        end
    end)

    -- Check current Eyes/Lookman state
    Globals.IsEyes    = workspace:FindFirstChild("Eyes")~=nil or workspace:FindFirstChild("Lookman")~=nil
    Globals.IsLookman = workspace:FindFirstChild("BackdoorLookman")~=nil

    -- Ambient
    if ambientEnabled then
        TweenService:Create(Lighting,TweenInfo.new(0.2,Enum.EasingStyle.Exponential),{Ambient=ambientColor}):Play()
    end

    -- Position spoof apply on respawn
    task.wait(1)
    if posSpoof and Floor~="Fools" and Floor~="OldHotel" then
        RootPart.CFrame=RootPart.CFrame*CFrame.new(0,-2.346,0)
        Humanoid.HipHeight=0.05
        pcall(function() RemotesFolder.Crouch:FireServer(true,true) end)
    end

    Globals.SpoofOffset=0
    Globals.LibraryCodeFound=false
    Globals.SelfKilled=false
    Globals.OldOxygen=Character:GetAttribute("Oxygen") or 100
    Globals.LastCrouchFire=tick()
    Globals.LastAnimCheck=tick()
    Globals.AutoMinecartDucked=false
    Globals.LastDuck=tick()

    -- Jump handler
    Character:GetAttributeChangedSignal("CanJump"):Connect(function()
        local v=Character:GetAttribute("CanJump")
        if enableJump and v~=true then OldJump=v end
        if enableJump then Character:SetAttribute("CanJump",true) end
    end)
    Character:GetAttributeChangedSignal("CanSlide"):Connect(function()
        local v=Character:GetAttribute("CanSlide")
        if enableSlide and v~=true then OldSlide=v end
        if enableSlide then Character:SetAttribute("CanSlide",true) end
    end)

    -- Mobile jump
    local jumpBtn=Globals.MainUI.MainFrame.MobileButtons:FindFirstChild("JumpButton")
    if jumpBtn then
        jumpBtn.MouseButton1Down:Connect(function()
            if infiniteJumps then Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end

    -- Footstep sounds
    Character.ChildAdded:Connect(function(obj)
        if obj:IsA("Sound") and obj.Name=="Sound" and removeFootsteps then obj.Volume=0 end
    end)

    -- Library code
    LP.PlayerGui.PermUI.Hints.ChildAdded:Connect(function()
        if notifyLibCode then
            local code=getLibraryCode()
            if code and not code:find("_") and not Globals.LibraryCodeFound then
                notify("Padlock code found!","The code is: '"..code.."'",15)
                Globals.LibraryCodeFound=true
            end
        end
    end)
    Character.ChildAdded:Connect(function(child)
        if (child.Name=="LibraryHintPaper" or child.Name=="LibraryHintPaperHard") and notifyLibCode then
            local code=getLibraryCode()
            if code and not code:find("_") and not Globals.LibraryCodeFound then
                notify("Padlock code found!","The code is: '"..code.."'",15)
                Globals.LibraryCodeFound=true
            end
        end
    end)

    -- Oxygen
    Character:GetAttributeChangedSignal("Oxygen"):Connect(function()
        local newOxy=Character:GetAttribute("Oxygen") or 0
        if newOxy<Globals.OldOxygen and notifyOxygen and Globals.MainUI then
            pcall(function()
                local cap=Globals.MainUI.MainFrame:FindFirstChild("Caption")
                if cap then cap.Text="Oxygen: "..math.floor(newOxy*10)/10.."%" end
            end)
        end
        Globals.OldOxygen=newOxy
    end)

    -- Anticheat
    Character:GetAttributeChangedSignal("Climbing"):Connect(function()
        if Character:GetAttribute("Climbing")==true and disableAnticheat and not Globals.AnticheatDisabled then
            task.wait(0.25)
            Character:SetAttribute("Climbing",false)
            notify("Anticheat disabled.","Interact with a ladder to re-enable.")
            Globals.AnticheatDisabled=true
        end
    end)
    pcall(function()
        RemotesFolder:WaitForChild("Cutscene",3).OnClientEvent:Connect(function(cn)
            if Globals.AnticheatDisabled and not tostring(cn):find("SewerSeek") then
                Globals.AnticheatDisabled=false
                notify("Anticheat re-enabled.","Interact with a ladder to disable it again.")
            end
        end)
        RemotesFolder:WaitForChild("UseEnemyModule",3).OnClientEvent:Connect(function(mn)
            if (mn=="Void" or mn=="Glitch") and Globals.AnticheatDisabled then
                Globals.AnticheatDisabled=false
                notify("Anticheat re-enabled.","Interact with a ladder to disable it again.")
                LP:SetAttribute("CurrentRoom",LatestRoom and LatestRoom.Value or 0)
            end
        end)
    end)

    -- SHM Fixer
    RootPart:GetPropertyChangedSignal("Anchored"):Connect(function()
        task.wait()
        if Floor=="Fools" and RootPart.Anchored and Character:GetAttribute("Hiding")~=true then
            RootPart.Anchored=false
        end
    end)

    -- Dead player room sync
    RunService.Heartbeat:Connect(function()
        if LP:GetAttribute("Alive")==true then return end
        local closest={dist=math.huge,obj=nil}
        for _,p in Players:GetPlayers() do
            if p~=LP and p.Character then
                local root=p.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local d=(Camera.CFrame.Position-root.Position).Magnitude
                    if d<closest.dist then closest.dist=d closest.obj=p end
                end
            end
        end
        if closest.obj then
            LP:SetAttribute("CurrentRoom",closest.obj:GetAttribute("CurrentRoom"))
        end
    end)
end

if LP.Character then task.spawn(function() handleCharacter(LP.Character) end) end
LP.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    handleCharacter(newChar)
end)

-- ==================== FINISH ====================
Win:Settings()
notify("Just X Hub","Loaded! Press RightShift to toggle.",4)

-- ==================== ARCHIVES TAB ====================
local ArchivesTab = Win:Tab({Label="Archives", Icon="folder"})

-- Archives locals
local DroneWalkedIntoParents = {}
local DroneConnection = nil
local BypassDronesStampedeConn = nil
local AlmaConnection = nil
local AntiRansomConn = nil
local AntiClosetTrashConn = nil
local AntiScribblesConn = nil
local WaterBypassConn = nil
local WaterParts = {}
local ForgetMeNotConn = nil
local ForgetMeNotRunning = false
local ForgetMeNotProcessing = {}
local ForgetMeNotNotified = {}
local TimeShowerConn = nil
local TimeShowerToken = 0
local TimeShowerSourceLabel = nil
local TimeShowerLabel = nil
local HonchoConn = nil
local HonchoProcessedRooms = {}
local HonchoESPObjects = {}

-- Time shower label
do
    local sg = Instance.new("ScreenGui")
    sg.Name = "JXH_TimeShower"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = LP.PlayerGui
    TimeShowerLabel = Instance.new("TextLabel")
    TimeShowerLabel.AnchorPoint = Vector2.new(0,1)
    TimeShowerLabel.Position = UDim2.new(0,12,1,-12)
    TimeShowerLabel.Size = UDim2.new(0,180,0,32)
    TimeShowerLabel.BackgroundTransparency = 1
    TimeShowerLabel.TextColor3 = Color3.fromRGB(255,255,255)
    TimeShowerLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    TimeShowerLabel.TextStrokeTransparency = 0.35
    TimeShowerLabel.Font = Enum.Font.GothamBold
    TimeShowerLabel.TextSize = 18
    TimeShowerLabel.TextXAlignment = Enum.TextXAlignment.Left
    TimeShowerLabel.Text = "Time: --:--"
    TimeShowerLabel.Visible = false
    TimeShowerLabel.Parent = sg
end

local function getArchivesClockLabel(room)
    local assets = room and room:FindFirstChild("Assets",true)
    local clock = assets and assets:FindFirstChild("ArchivesClock",true)
    local time = clock and clock:FindFirstChild("Time",true)
    local lbl = time and time:FindFirstChild("TextLabel")
    return (lbl and lbl:IsA("TextLabel")) and lbl or nil
end

local function resolveClockLabel()
    if TimeShowerSourceLabel and TimeShowerSourceLabel.Parent then
        return TimeShowerSourceLabel
    end
    if not CurrentRooms then return nil end
    local rooms = {}
    for _,r in CurrentRooms:GetChildren() do
        local n=tonumber(r.Name)
        if n then table.insert(rooms,{r=r,n=n}) end
    end
    table.sort(rooms,function(a,b) return a.n>b.n end)
    for i=1,math.min(6,#rooms) do
        local lbl=getArchivesClockLabel(rooms[i].r)
        if lbl then TimeShowerSourceLabel=lbl return lbl end
    end
    return nil
end

local function resolveClockRemote()
    local lbl=resolveClockLabel()
    if not lbl then return nil end
    local clock=lbl:FindFirstAncestor("ArchivesClock")
    if not clock then return nil end
    local remote=clock:FindFirstChild("LookedAtRemote",true)
    return (remote and remote:IsA("RemoteEvent")) and remote or nil
end

task.spawn(function()
    local lastCount=0
    while true do
        if CurrentRooms then
            local count=0
            for _,c in CurrentRooms:GetChildren() do if tonumber(c.Name) then count+=1 end end
            if count>0 and (lastCount==0 or count-lastCount>=10) then
                resolveClockLabel() lastCount=count
            end
        end
        task.wait(0.5)
    end
end)

-- Archives Exploits
local archMiscSec = ArchivesTab:Section({Title="Exploits / Anti", Column="right"})

archMiscSec:Toggle({Name="Anti Ransom", Flag="AR_Ransom", Default=false,
    Callback=function(v)
        if AntiRansomConn then AntiRansomConn:Disconnect() AntiRansomConn=nil end
        if not v then return end
        for _,c in workspace:GetChildren() do if c.Name=="Ransom" then c:Destroy() end end
        AntiRansomConn=workspace.ChildAdded:Connect(function(c)
            if c.Name=="Ransom" then c:Destroy() end
        end)
    end})
archMiscSec:Toggle({Name="Anti Closet Trash", Flag="AR_ClosetTrash", Default=false,
    Callback=function(v)
        if AntiClosetTrashConn then AntiClosetTrashConn:Disconnect() AntiClosetTrashConn=nil end
        if not v then return end
        AntiClosetTrashConn=workspace.ChildAdded:Connect(function(c)
            local n=c.Name
            if n:sub(1,6)=="Binder" or n:sub(1,4)=="Shoe" or n:sub(1,5)=="Shelf" then
                c:Destroy()
            end
        end)
    end})
archMiscSec:Toggle({Name="Forget Me Not Skipper", Flag="AR_ForgetMeNot", Default=false,
    Callback=function(v)
        if ForgetMeNotConn then ForgetMeNotConn:Disconnect() ForgetMeNotConn=nil end
        ForgetMeNotRunning=false ForgetMeNotProcessing={} ForgetMeNotNotified={}
        if not v then return end
        ForgetMeNotRunning=true
        local function fireAll(room)
            for i=1,6 do
                local obj=room:FindFirstChild(tostring(i))
                if obj then
                    local la=obj:FindFirstChild("LookAt")
                    if la then pcall(function() la:FireServer() end) end
                end
            end
        end
        local function getNextRoom(num)
            while ForgetMeNotRunning do
                for n=num+1,num+5 do
                    local r=CurrentRooms:FindFirstChild(tostring(n))
                    if r then return r end
                end
                task.wait(0.1)
            end
        end
        local function run(room)
            if not ForgetMeNotRunning or ForgetMeNotProcessing[room] then return end
            ForgetMeNotProcessing[room]=true
            task.wait(2)
            if not ForgetMeNotRunning or not room.Parent then ForgetMeNotProcessing[room]=nil return end
            if not room:FindFirstChild("ForgetMeNotVineDoors",true) then ForgetMeNotProcessing[room]=nil return end
            fireAll(room)
            local nextRoom=getNextRoom(tonumber(room.Name))
            if not nextRoom then ForgetMeNotProcessing[room]=nil return end
            local door=nextRoom:FindFirstChild("Door")
            if not door or door:GetAttribute("Opened")==true then ForgetMeNotProcessing[room]=nil return end
            if not room:FindFirstChild(LP.Name,true) then
                if not ForgetMeNotNotified[room] then
                    ForgetMeNotNotified[room]=true
                    notify("Please Enter The First ForgetMeNot Door")
                end
                repeat task.wait() until room:FindFirstChild(LP.Name,true) or not ForgetMeNotRunning or not room.Parent
                if not ForgetMeNotRunning or not room.Parent then ForgetMeNotProcessing[room]=nil return end
            end
            if not ForgetMeNotRunning or door:GetAttribute("Opened")==true then ForgetMeNotProcessing[room]=nil return end
            local hidden=door:WaitForChild("Hidden",10)
            if not hidden or not ForgetMeNotRunning or door:GetAttribute("Opened")==true then ForgetMeNotProcessing[room]=nil return end
            task.wait(3)
            if not ForgetMeNotRunning or not nextRoom.Parent or door:GetAttribute("Opened")==true then ForgetMeNotProcessing[room]=nil return end
            while ForgetMeNotRunning and nextRoom.Parent and door:GetAttribute("Opened")~=true do
                if Character then
                    if hidden:IsA("BasePart") then Character:PivotTo(hidden.CFrame)
                    elseif hidden:IsA("Model") then Character:PivotTo(hidden:GetPivot()) end
                end
                pcall(function() door.ClientOpen:FireServer() end)
                task.wait()
            end
            if ForgetMeNotRunning and door:GetAttribute("Opened")==true then
                if Character then
                    for _=1,5 do Character:PivotTo(CFrame.new(0,-120,0)) end
                end
                notify("Spam Void In Debug If Stuck In ForgetMeNot")
                ForgetMeNotNotified[room]=nil
            end
            ForgetMeNotProcessing[room]=nil
        end
        ForgetMeNotConn=CurrentRooms.ChildAdded:Connect(function(room)
            if not tonumber(room.Name) then return end
            task.spawn(function() task.wait(2) if ForgetMeNotRunning and room.Parent then task.spawn(run,room) end end)
        end)
        task.spawn(function()
            while ForgetMeNotRunning do
                local lr=LatestRoom and LatestRoom.Value or 0
                for n=math.max(0,lr-4),lr do
                    if not ForgetMeNotRunning then return end
                    local r=CurrentRooms:FindFirstChild(tostring(n))
                    if r and not ForgetMeNotProcessing[r] then task.spawn(run,r) end
                end
                task.wait(2)
            end
        end)
    end})
archMiscSec:Toggle({Name="Time Shower", Flag="AR_TimeShower", Default=false,
    Callback=function(v)
        TimeShowerToken+=1
        if TimeShowerConn then TimeShowerConn:Disconnect() TimeShowerConn=nil end
        TimeShowerLabel.Visible=v
        if not v then TimeShowerLabel.Text="Time: --:--" return end
        local token=TimeShowerToken
        TimeShowerConn=RunService.Heartbeat:Connect(function()
            if token~=TimeShowerToken then return end
            local lbl=resolveClockLabel()
            TimeShowerLabel.Text=lbl and ("Time: "..lbl.Text) or "Time: --:--"
        end)
    end})
archMiscSec:Toggle({Name="Stop Time / Anti Stampede", Flag="AR_StopTime", Default=false,
    Callback=function(v)
        if BypassDronesStampedeConn then task.cancel(BypassDronesStampedeConn) BypassDronesStampedeConn=nil end
        if not v then return end
        BypassDronesStampedeConn=task.spawn(function()
            while true do
                local remote=resolveClockRemote()
                if remote then remote:FireServer() end
                task.wait(1)
            end
        end)
    end})
archMiscSec:Toggle({Name="Honcho Correct Box ESP", Flag="AR_HonchoESP", Default=false,
    Callback=function(v)
        if HonchoConn then HonchoConn:Disconnect() HonchoConn=nil end
        for _,obj in HonchoESPObjects do removeESP(obj) end
        table.clear(HonchoESPObjects) table.clear(HonchoProcessedRooms)
        if not v or not CurrentRooms then return end
        local function processRoom(room)
            if not tonumber(room.Name) or HonchoProcessedRooms[room] then return end
            HonchoProcessedRooms[room]=true
            task.wait(3)
            if not v or not room.Parent then HonchoProcessedRooms[room]=nil return end
            local honcho=room:FindFirstChild("ArchivesHonchoRoom",true)
            if not honcho then HonchoProcessedRooms[room]=nil return end
            local boxIDs={}
            for _,desc in room:GetDescendants() do
                if desc.Name=="ArchivesPackageDeposit" then
                    local bid=desc:GetAttribute("BoxID")
                    if bid~=nil then boxIDs[bid]=true end
                end
            end
            if not next(boxIDs) then HonchoProcessedRooms[room]=nil return end
            local rn=tonumber(room.Name)
            for _,child in honcho:GetDescendants() do
                if child.Name=="ArchivesStorageBox" then
                    local tid=child:GetAttribute("Tool_BoxID")
                    if tid~=nil and boxIDs[tid] then
                        if not child:GetAttribute("ParentRoom") then child:SetAttribute("ParentRoom",rn) end
                        addESP(child,"Correct Box",espObjectiveColor,true)
                        table.insert(HonchoESPObjects,child)
                        child.Destroying:Once(function()
                            removeESP(child)
                            local pos=table.find(HonchoESPObjects,child)
                            if pos then table.remove(HonchoESPObjects,pos) end
                        end)
                    end
                end
            end
        end
        for _,r in CurrentRooms:GetChildren() do task.spawn(processRoom,r) end
        HonchoConn=CurrentRooms.ChildAdded:Connect(function(r) task.spawn(processRoom,r) end)
    end})

-- Archives Bypasses
local archBypassSec = ArchivesTab:Section({Title="Bypasses", Column="left"})

archBypassSec:Toggle({Name="Bypass Electric Water", Flag="AB_Water", Default=false,
    Callback=function(v)
        notify("PositionSpoof Will Break This!.")
        if WaterBypassConn then WaterBypassConn:Disconnect() WaterBypassConn=nil end
        for _,p in WaterParts do if p then p:Destroy() end end
        table.clear(WaterParts)
        if not v or not CurrentRooms then return end
        local function processRoom(room)
            if not tonumber(room.Name) then return end
            task.wait(3)
            local water=room:FindFirstChild("Water")
            if not water or WaterParts[water] then return end
            local bp=Instance.new("Part")
            bp.Name="WaterBypass" bp.Anchored=true bp.CanCollide=true
            bp.CanTouch=false bp.CanQuery=false bp.Transparency=0.25
            bp.Color=Color3.fromRGB(0,150,255) bp.Material=Enum.Material.ForceField
            if water:IsA("BasePart") then
                bp.Size=water.Size+Vector3.new(0,0.5,0)
                bp.CFrame=water.CFrame*CFrame.new(0,0.25,0)
            elseif water:IsA("Model") then
                local cf,sz=water:GetBoundingBox()
                bp.Size=sz+Vector3.new(0,0.5,0)
                bp.CFrame=cf*CFrame.new(0,0.25,0)
            else
                bp.Size=Vector3.new(10,1.5,10)
                bp.CFrame=water:GetPivot()*CFrame.new(0,0.25,0)
            end
            if bp.Size.Y>3 then bp:Destroy() notify("Water Bypass removed: Softlock.") return end
            bp.Parent=room
            WaterParts[water]=bp
        end
        local lr=LatestRoom and LatestRoom.Value or 0
        for n=math.max(0,lr-4),lr do
            local r=CurrentRooms:FindFirstChild(tostring(n))
            if r then task.spawn(processRoom,r) end
        end
        WaterBypassConn=CurrentRooms.ChildAdded:Connect(function(r) task.spawn(processRoom,r) end)
    end})
archBypassSec:Toggle({Name="Bypass Alma", Flag="AB_Alma", Default=false,
    Callback=function(v)
        if AlmaConnection then AlmaConnection:Disconnect() AlmaConnection=nil end
        if v then
            for _,c in workspace:GetChildren() do if c.Name=="Alma" then c:Destroy() end end
            AlmaConnection=workspace.ChildAdded:Connect(function(c)
                if c.Name=="Alma" then c:Destroy() end
            end)
        end
    end})
archBypassSec:Toggle({Name="Bypass Drones", Flag="AB_Drones", Default=false,
    Callback=function(v)
        if DroneConnection then DroneConnection:Disconnect() DroneConnection=nil end
        if v then
            local function processDrones(drones)
                local wi=drones:FindFirstChild("WalkedInto") or drones:WaitForChild("WalkedInto",3)
                if wi and not DroneWalkedIntoParents[wi] then
                    DroneWalkedIntoParents[wi]=drones
                    wi.Parent=ReplicatedStorage
                end
            end
            for _,c in workspace:GetChildren() do if c.Name=="Drones" then processDrones(c) end end
            DroneConnection=workspace.ChildAdded:Connect(function(c)
                if c.Name=="Drones" then processDrones(c) end
            end)
        else
            for wi,orig in DroneWalkedIntoParents do
                if wi and wi.Parent and orig and orig.Parent then wi.Parent=orig end
            end
            table.clear(DroneWalkedIntoParents)
        end
    end})
archBypassSec:Toggle({Name="Bypass Scribbles", Flag="AB_Scribbles", Default=false,
    Callback=function(v)
        if AntiScribblesConn then AntiScribblesConn:Disconnect() AntiScribblesConn=nil end
        if not v then return end
        AntiScribblesConn=workspace.ChildAdded:Connect(function(c)
            if c.Name=="Scribbles" then
                local ew=c:FindFirstChild("IfYoureExploitingDeleteThis")
                if ew then ew:Destroy() end
            end
        end)
    end})

-- ==================== STAIRWELL TAB ====================
local StairwellTab = Win:Tab({Label="Stairwell", Icon="stairs"})

local stairExpSec = StairwellTab:Section({Title="Experimental", Column="left"})

stairExpSec:Button({Name="Bring Dropped Items",
    Callback=function()
        local drops=workspace:FindFirstChild("Drops")
        if not drops or not RootPart then return end
        for _,item in drops:GetChildren() do
            if item:IsA("Model") then pcall(function() item:PivotTo(RootPart.CFrame) end)
            elseif item:IsA("BasePart") then item.CFrame=RootPart.CFrame end
        end
        notify("Dropped items brought to you!")
    end})

local antiNoiseEnabled=false
local antiNoiseConn=nil

stairExpSec:Toggle({Name="Anti Noise", Flag="SW_AntiNoise", Default=false,
    Callback=function(v)
        antiNoiseEnabled=v
        if antiNoiseConn then antiNoiseConn:Disconnect() antiNoiseConn=nil end
        if not v then return end
        antiNoiseConn=RunService.PreSimulation:Connect(function(dt)
            if not antiNoiseEnabled then return end
            if not LP:GetAttribute("Alive") then return end
            if not Character or not Humanoid or not RootPart or not Camera then return end
            if Humanoid.Health<=0 then return end
            if RootPart.Anchored then return end
            local state=Humanoid:GetState()
            if state==Enum.HumanoidStateType.Dead or state==Enum.HumanoidStateType.Ragdoll
                or state==Enum.HumanoidStateType.Climbing or state==Enum.HumanoidStateType.Swimming
            then return end
            Humanoid.AutoRotate=false
            Humanoid:Move(Vector3.zero,false)
            local uis=game:GetService("UserInputService")
            local inputVec=Vector3.new(
                (uis:IsKeyDown(Enum.KeyCode.D) and 1 or 0)-(uis:IsKeyDown(Enum.KeyCode.A) and 1 or 0),
                0,
                (uis:IsKeyDown(Enum.KeyCode.S) and 1 or 0)-(uis:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
            )
            if inputVec.Magnitude<=0 then
                RootPart.AssemblyLinearVelocity=Vector3.zero return
            end
            local cf=Camera.CFrame
            local fwd=Vector3.new(cf.LookVector.X,0,cf.LookVector.Z)
            local rgt=Vector3.new(cf.RightVector.X,0,cf.RightVector.Z)
            if fwd.Magnitude<0.001 or rgt.Magnitude<0.001 then return end
            fwd=fwd.Unit rgt=rgt.Unit
            local dir=(rgt*inputVec.X)+(fwd*-inputVec.Z)
            if dir.Magnitude<=0 then return end
            dir=dir.Unit
            local speed=Humanoid.WalkSpeed*math.clamp(inputVec.Magnitude,0,1)
            local cdt=math.clamp(dt,0,1/30)
            RootPart.AssemblyLinearVelocity=Vector3.zero
            RootPart.CFrame=RootPart.CFrame+(dir*speed*cdt)
            RootPart.CFrame=CFrame.new(RootPart.Position,RootPart.Position+dir)
        end)
    end})

local stairMiscSec = StairwellTab:Section({Title="Exploits / Anti", Column="right"})
stairMiscSec:Label({Text="Stairwell features coming soon."})

-- ==================== ПАТЧ: Новые сущности и предметы из AbysallContinued ====================

-- Добавляем новые сущности в EntityData
EntityData["StemsEntity"]    = { Alias="Balls",          NotifyMessage={Title="Entity 'Balls' has spawned.",          Body="Balls."} }
EntityData["NoiseModel"]     = { Alias="Noise",          NotifyMessage={Title="Entity 'Noise' has spawned.",          Body="Don't let it touch you."} }
EntityData["Creak"]          = { Alias="Creak",          NotifyMessage={Title="Entity 'Creak' has spawned.",          Body="Don't touch him."} }
EntityData["DronesStampede"] = { Alias="DronesStampede", NotifyMessage={Title="Entity 'Drones Stampede' has spawned.",Body="Find a hiding spot."} }
EntityData["TellerRig"]      = { Alias="Teller",         NotifyMessage={Title="Entity 'Teller' has spawned.",         Body="Don't worry, he's only annoying."} }
EntityData["Scribbles"]      = { Alias="Scribbles",      NotifyMessage={Title="Entity 'Scribbles' has spawned.",      Body="Find a hiding spot."} }
EntityData["BashMoving"]     = { Alias="Bash",           NotifyMessage={Title="Entity 'Bash' has spawned.",           Body="Find a hiding spot."} }

-- Добавляем новые дистанции
EntityDistances["Scribbles"]      = 100
EntityDistances["BashMoving"]     = 150
EntityDistances["DronesStampede"] = 100

-- Добавляем новые предметы
ItemNames["DinkyLamp"]        = "Lamp"
ItemNames["BottleCrate"]      = "18+ Bottles"
ItemNames["GweenSodaPack"]    = "Gween Soda Pack"
ItemNames["BrokenMonitor"]    = "Broken Monitor"
ItemNames["JerryCan"]         = "Jerry Can"
ItemNames["SallyToyObtain"]   = "Sally Toy"
ItemNames["Leftovers"]        = "Lunch Box"
ItemNames["HoneyPot"]         = "Honey Pot"
ItemNames["FihFlakes"]        = "Fih Food"
ItemNames["SecretCD"]         = "CD Disc"
ItemNames["Pizza"]            = "Pizza"
ItemNames["PaperPlanePickup"] = "Paper Plane"

-- Добавляем новые ObjectiveLabels
ObjectiveLabels["ShoppingCart"]           = "Shopping Cart"
ObjectiveLabels["StairwellFireAlarm"]     = "Fire Alarm"
ObjectiveLabels["SalvageChute"]           = "Salvage"
ObjectiveLabels["ArchivesPackageDeposit"] = "Box Deposit"
ObjectiveLabels["ArchivesFihTank"]        = "Fih Tank"
ObjectiveLabels["Cellar"]                 = "Cellar"

-- Debug секция (в General)
local debugSec = GeneralTab:Section({Title="Debug", Column="right"})
debugSec:Button({Name="Void (Y -120)", Callback=function()
    if not Character then return end
    local pivot=Character:GetPivot()
    for _=1,22 do Character:PivotTo(pivot+Vector3.new(0,-120-pivot.Position.Y,0)) end
    notify("Teleported to void.")
end})
debugSec:Button({Name="Exit Closet", Callback=function()
    pcall(function() RemotesFolder.CamLock:FireServer() end)
end})

-- Infinite Crucifix (в Exploits > Bypass Right)
local infCrucifixDropTable = {
    RushMoving=54, AmbushMoving=67, A60=70,
    GlitchRush=120, GlitchAmbush=155, A120=75,
}
local infCrucifixEnabled = false
local infCrucifixConn = nil

local infCrucifixSec = ExploitsTab:Section({Title="Infinite Crucifix", Column="right"})
infCrucifixSec:Toggle({Name="Infinite Crucifix", Flag="IC_Toggle", Default=false,
    Callback=function(v)
        infCrucifixEnabled=v
        if infCrucifixConn then infCrucifixConn:Disconnect() infCrucifixConn=nil end
        if not v then return end
        local rcParams=RaycastParams.new()
        rcParams.FilterType=Enum.RaycastFilterType.Exclude
        infCrucifixConn=RunService.RenderStepped:Connect(function()
            if not infCrucifixEnabled or not Character or not CollisionPart then return end
            rcParams.FilterDescendantsInstances={Character}
            for _,entity in workspace:GetChildren() do
                local maxDist=infCrucifixDropTable[entity.Name]
                if not maxDist or not entity.PrimaryPart then continue end
                entity.PrimaryPart.CanCollide=true
                entity.PrimaryPart.CanQuery=true
                local origin=CollisionPart.Position
                local dir=entity.PrimaryPart.Position-origin
                local rr=workspace:Raycast(origin,dir,rcParams)
                if not rr or not rr.Instance:IsDescendantOf(entity) then continue end
                local dist=(origin-entity.PrimaryPart.Position).Magnitude
                if dist>=maxDist then continue end
                local tool=Character:FindFirstChildOfClass("Tool")
                if not tool or tool.Name~="Crucifix" then continue end
                task.spawn(function()
                    pcall(function() RemotesFolder.DropItem:FireServer(tool) end)
                    task.wait(0.54)
                    if not Drops then return end
                    local dropped=Drops:FindFirstChild("Crucifix")
                    if not dropped then return end
                    local prompt=dropped:FindFirstChildOfClass("ProximityPrompt")
                    if prompt then forceFirePrompt(prompt) end
                end)
                task.wait(0.6)
            end
        end)
    end})
infCrucifixSec:Label({Text="Risky! Low ping + stable FPS recommended."})

-- ==================== ФИНАЛЬНЫЙ ПАТЧ ====================

-- 1. AllowedInstances whitelist для handleObject (оптимизация)
local AllowedInstances = {
    Lava=true, GoldPile=true, KeyObtain=true, Drakobloxxer=true, FuseObtain=true,
    MinesGenerator=true, JeffTheKiller=true, Snare=true, FakeDoor=true, DoorFake=true,
    SideroomSpace=true, ChestBox=true, ChestBoxLocked=true, Chest_Vine=true,
    Locker_Small_Locked=true, Toolbox=true, Toolbox_Locked=true, Wardrobe=true,
    ["Wardrobe-FOOLS26"]=true, Toolshed=true, Toolshed_Small=true, Bed=true,
    MinesAnchor=true, Double_Bed=true, RetroWardrobe=true, Backdoor_Wardrobe=true,
    Rooms_Locker=true, Rooms_Locker_Fridge=true, Locker_Large=true, FigureRig=true,
    FigureRagdoll=true, TimerLever=true, Lever=true, Seek_Arm=true,
    ChandelierObstruction=true, ScaryWall=true, Ladder=true, CircularVent=true,
    Dumpster=true, SquareGrate=true, TriggerEventCollision=true, GrumbleRig=true,
    GiggleCeiling=true, MinesGateButton=true, ElectricalKeyObtain=true,
    LibraryHintPaper=true, WaterPump=true, CringlePresent=true, Wheel=true,
    PickupItem=true, LiveHintBook=true, LiveBreakerPolePickup=true, LeverForGate=true,
    GloomPile=true, SeekFloodline=true, Door=true, Green_Herb=true, Bridge=true,
    MouseHole=true, BananaPeel=true, NannerPeel=true, PowerupPad=true,
    IndustrialGate=true, CollisionFloor=true, ElevatorCar=true, Wax_Door=true,
    ThingToOpen=true, MovingDoor=true, StardustPickup=true, Hole=true,
    Groundskeeper=true, MandrakeLive=true, GardenGateButton=true,
    LotusPetalPickup=true, VineGuillotine=true, LiveEntityBramble=true,
    RiftSpawn=true, ElevatorBreaker=true, RunnerNodes=true, PathLights=true,
    DuckBoard=true, Padlock=true, EyestalkEndCutscene=true, MinecartRig=true,
    SeekMovingNewClone=true, ShoppingCart=true, StairwellFireAlarm=true,
    SalvageChute=true, ArchivesPackageDeposit=true, ArchivesFihTank=true,
    Cellar=true, StemsEntity=true, NoiseModel=true, Creak=true,
    DronesStampede=true, TellerRig=true, Scribbles=true, BashMoving=true,
}

-- Добавляем ItemNames в AllowedInstances
for k in pairs(ItemNames) do AllowedInstances[k]=true end
-- Добавляем EntityData в AllowedInstances
for k in pairs(EntityData) do AllowedInstances[k]=true end

-- Патчим handleObject чтобы использовал whitelist
local _origHandleObject = handleObject
handleObject = function(obj)
    if not obj or not obj.Parent then return end
    if not AllowedInstances[obj.Name] then return end
    _origHandleObject(obj)
end

-- 2. ScaryWall PropertyChangedSignal патч (сбрасывание CanTouch/CanCollide)
-- Применяется через отдельный воркспейс хэндлер
local scaryWallConn = workspace.DescendantAdded:Connect(function(obj)
    if obj.Name~="ScaryWall" then return end
    task.spawn(function()
        for _,p in obj:GetDescendants() do
            if p:IsA("BasePart") then
                local c1=p:GetPropertyChangedSignal("CanTouch"):Connect(function()
                    if p.CanTouch==bypassSeekWall then p.CanTouch=not bypassSeekWall end
                end)
                local c2=p:GetPropertyChangedSignal("CanCollide"):Connect(function()
                    if p.CanCollide==bypassSeekWall then p.CanCollide=not bypassSeekWall end
                end)
                obj.Destroying:Once(function() c1:Disconnect() c2:Disconnect() end)
            end
        end
    end)
end)
table.insert(Connections, scaryWallConn)

-- 3. ElevatorCar — уведомление об успешном решении breaker box
local elevCarConn = workspace.DescendantAdded:Connect(function(obj)
    if obj.Name~="ElevatorCar" then return end
    local ec=obj.DescendantAdded:Connect(function(desc)
        if autoBreakerBox and desc.Name=="TouchInterest" and not Globals.BreakerBoxFinishedNotified then
            notify("Successfully solved the breaker box.","Try going to the elevator!")
            Globals.BreakerBoxFinishedNotified=true
        end
    end)
    obj.Destroying:Once(function() ec:Disconnect() end)
end)
table.insert(Connections, elevCarConn)

-- 4. RunnerNodes — полная логика направлений для минекарта
local function setupRunnerNodes(obj)
    local function isBehind(p1,p2)
        local f=(p1.CFrame+p1.CFrame.LookVector).Position
        local b=(p1.CFrame+p1.CFrame.LookVector*-1).Position
        return (f-p2.Position).Magnitude>(b-p2.Position).Magnitude
    end
    local function getDir(p1,p2)
        local rd=p1.CFrame.RightVector:Dot(p1.Position-p2.Position)
        if rd>0.5  then return isBehind(p1,p2) and "Right" or "Left" end
        if rd<-0.5 then return isBehind(p1,p2) and "Left" or "Right" end
        return "Straight"
    end
    local function getClosestNode(node)
        local best,bestDist=nil,math.huge
        local nodeID=tonumber(node.Name:split("MinecartNode")[2])
        for _,other in obj:GetChildren() do
            local otherID=tonumber(other.Name:split("MinecartNode")[2])
            if other~=node and otherID and nodeID and otherID>nodeID then
                local d=(node.Position-other.Position).Magnitude
                if d<bestDist and other:GetAttribute("DistanceBlacklist")~=true then
                    bestDist=d best=other
                end
            end
        end
        return best
    end
    task.spawn(function()
        for _,node in obj:GetChildren() do
            local nid=tonumber(node.Name:split("MinecartNode")[2])
            if node:GetAttribute("DeathType") then node:SetAttribute("DistanceBlacklist",true) end
            for i=1,20 do
                local next=nid and obj:FindFirstChild("MinecartNode"..nid+i)
                if next and next:GetAttribute("DeathType")~=nil then
                    node:SetAttribute("DistanceBlacklist",true)
                end
            end
            local prev=nid and obj:FindFirstChild("MinecartNode"..nid-1)
            if prev and prev:GetAttribute("ForceConnect") then
                node:SetAttribute("DistanceBlacklist",nil)
            end
            task.wait()
        end
        for _,node in obj:GetChildren() do
            if node:GetAttribute("ForceConnect") then
                local nextNode=getClosestNode(node)
                if nextNode then
                    node:SetAttribute("Turn",getDir(node,nextNode))
                    table.insert(Objects.SeekNodes,node)
                end
            end
            task.wait()
        end
    end)
end

-- 5. SeekMovingNewClone — очистка нод
local seekCloneConn = workspace.DescendantAdded:Connect(function(obj)
    if obj.Name=="RunnerNodes" then
        setupRunnerNodes(obj)
    elseif obj.Name=="SeekMovingNewClone" then
        obj.Destroying:Connect(function()
            for _,folder in Objects.PathLights do folder:ClearAllChildren() end
            Globals.SeekNodesFolder:ClearAllChildren()
            table.clear(Objects.SeekNodes)
        end)
    elseif obj.Name=="MinecartRig" then
        Globals.Minecart=obj
    elseif obj.Name=="EyestalkEndCutscene" then
        obj.Name="_EyestalkEndCutscene"
    elseif obj.Name=="DuckBoard" then
        table.insert(Objects.SeekDuckBoards,obj)
    elseif obj.Name=="Bridge" then
        task.spawn(function()
            for _,child in obj:GetChildren() do
                if child.Name=="PlayerBarrier" and child.Size.Y==2.75
                    and (child.Rotation.X==0 or child.Rotation.X==180)
                then
                    local newBridge=child:Clone()
                    newBridge.CFrame=newBridge.CFrame*CFrame.new(0,0,-5)
                    newBridge.Name="JXH_Bridge_"..math.random(1,99999)
                    newBridge.Size=Vector3.new(newBridge.Size.X,newBridge.Size.Y,11)
                    newBridge.Parent=obj
                    newBridge.CanCollide=bypassSeekObs
                    newBridge.Color=Color3.fromRGB(0,255,255)
                    newBridge.Transparency=bypassSeekObs and 0 or 1
                    newBridge.Material=Enum.Material.ForceField
                    table.insert(Objects.SeekBridges,newBridge)
                end
                task.wait()
            end
        end)
    end
end)
table.insert(Connections, seekCloneConn)

-- 6. NannerPeel (как BananaPeel)
local nannerConn = workspace.DescendantAdded:Connect(function(obj)
    if obj.Name=="NannerPeel" then
        if bypassBanana then obj.CanTouch=false end
        table.insert(Objects.Entities,obj)
    end
end)
table.insert(Connections, nannerConn)

-- 7. PromptAnimationFixer — анимация при использовании ключей
local animToolNames={"Lockpick","Shears","SkeletonKey","Key","KeyElectrical","KeyBackdoor","KeyIron","Multitool"}
local lockPromptNamesAnim={UnlockPrompt=true,SkullPrompt=true,LockPrompt=true,ThingToEnable=true,FusesPrompt=true}

ProximityPromptService.PromptButtonHoldBegan:Connect(function(obj)
    if not obj:GetAttribute("FakePrompt") then return end
    if not Character then return end
    local isLock=lockPromptNamesAnim[obj.Name]
        or (obj.Parent and obj.Parent:GetAttribute("Locked")==true)
        or (obj.Parent and obj.Parent.Parent and obj.Parent.Parent.Name=="Locker_Small_Locked" and obj.Name=="ActivateEventPrompt")
    if isLock then
        if autoInteractIgnoreList["Locks"] then return end
        local keyItems={"Key","GeneratorFuse","KeyBackdoor","KeyElectrical","KeyIron","Lockpick","SkeletonKey","Shears","Multitool"}
        local hasKey=false
        for _,k in keyItems do if hasItem(k,true) or hasItem(k) then hasKey=true break end end
        if not hasKey then return end
    end
    local tool
    for _,n in animToolNames do tool=Character:FindFirstChild(n) if tool then break end end
    if tool and Globals.UseAnimation then
        if Globals.UseAnimationBreak then Globals.UseAnimationBreak:Stop() end
        Globals.UseAnimation:Stop()
        Globals.UseAnimation:Play()
        if tool.Name=="Shears" then
            local h=tool:FindFirstChild("Handle")
            local s=h and h:FindFirstChild("sound_prompt")
            if s then s:Play() end
        end
    end
end)

-- 8. Halt LogService античит ре-активация
local ok_ls, LogService = pcall(function() return game:GetService("LogService") end)
if ok_ls and LogService then
    local haltLogConn=LogService.MessageOut:Connect(function(msg)
        if msg=="client teleporting" and Globals.AnticheatDisabled then
            Globals.AnticheatDisabled=false
            notify("Anticheat re-enabled.","Interact with a ladder to disable it again.")
        end
    end)
    table.insert(Connections,haltLogConn)
end

-- 9. Добавляем новые сущности в notify/ESP при спавне
-- (патч EntityHandler для новых сущностей AbysallContinued)
local newEntityNames={
    StemsEntity=true, NoiseModel=true, Creak=true,
    DronesStampede=true, TellerRig=true, Scribbles=true, BashMoving=true,
}
workspace.ChildAdded:Connect(function(entity)
    if not newEntityNames[entity.Name] then return end
    local ed=EntityData[entity.Name]
    if not ed then return end
    task.spawn(function()
        while not entity.PrimaryPart do
            for _,c in entity:GetChildren() do if c:IsA("BasePart") then entity.PrimaryPart=c end end
            task.wait()
        end
        task.wait(0.1)
        if not entity.Parent then return end
        if notifyEntities and notifyEntityList[ed.Alias] then
            notify(ed.NotifyMessage.Title, ed.NotifyMessage.Body, 5)
        end
        if entityChatEnabled then sendChat(ed.Alias.." spawned!") end
        local label=EntityESPLabels[entity.Name] or ed.Alias
        if espEntities and espEntityList[label] then
            addESP(entity,label,espEntityColor,false)
        end
        table.insert(Objects.Entities,entity)
        entity.Destroying:Once(function()
            for i,e in Objects.Entities do if e==entity then table.remove(Objects.Entities,i) break end end
            removeESP(entity)
        end)
    end)
end)

-- 10. RiftSpawn/PowerupPad — добавляем в Objectives ESP
local riftConn = workspace.DescendantAdded:Connect(function(obj)
    if obj.Name=="RiftSpawn" then
        if espObjective then addESP(obj,"Rift Spawn",espObjectiveColor,true) end
        table.insert(Objects.Objectives,obj)
    elseif obj.Name=="PowerupPad" then
        if espObjective then addESP(obj,"Powerup Pad",espObjectiveColor,true) end
        table.insert(Objects.Objectives,obj)
    elseif obj.Name=="ShoppingCart" then
        if espObjective then addESP(obj,"Shopping Cart",espObjectiveColor,true) end
        table.insert(Objects.Objectives,obj)
    elseif obj.Name=="StairwellFireAlarm" then
        if espObjective then addESP(obj,"Fire Alarm",espObjectiveColor,true) end
        table.insert(Objects.Objectives,obj)
    elseif obj.Name=="SalvageChute" then
        if espObjective then addESP(obj,"Salvage",espObjectiveColor,true) end
        table.insert(Objects.Objectives,obj)
    elseif obj.Name=="ArchivesFihTank" then
        if espObjective then addESP(obj,"Fih Tank",espObjectiveColor,true) end
        table.insert(Objects.Objectives,obj)
    end
end)
table.insert(Connections, riftConn)

print("[Just X Hub] All patches applied. Total features: fully ported from Abysall + AbysallContinued.")

-- ==================== ПАТЧ: Улучшенный TriggerPrompt ====================
-- Заменяем triggerPrompt на полную версию из AbysallContinued

triggerPrompt = function(prompt)
    if not prompt or not prompt.Parent then return end
    if AutoInteractBlacklist[prompt.Name] then return end
    if triggerDebounce then return end

    -- Durability check для инструментов
    local parentItem = hasItem(prompt.Parent.Name)
    if parentItem and parentItem:GetAttribute("Durability") and parentItem:GetAttribute("DurabilityMax")
        and parentItem:GetAttribute("Durability") >= parentItem:GetAttribute("DurabilityMax")
    then return end

    -- Lock prompts
    local isLock = LockPromptNames[prompt.Name]
        or (prompt.Parent and prompt.Parent:GetAttribute("Locked")==true)
        or (prompt.Parent and prompt.Parent.Parent and prompt.Parent.Parent.Name=="Locker_Small_Locked" and prompt.Name=="ActivateEventPrompt")

    if isLock then
        if autoInteractIgnoreList["Locks"] then return end
        local keyItems={"Key","GeneratorFuse","KeyBackdoor","KeyElectrical","KeyIron","Lockpick","SkeletonKey","Shears","Multitool"}
        local offhandKeys={"Key","GeneratorFuse","KeyElectrical","KeyIron"}
        local hasKey=false
        for _,k in keyItems do if hasItem(k,true) then hasKey=true break end end
        if not hasKey then
            for _,k in offhandKeys do if hasItem(k) then hasKey=true break end end
        end
        if not hasKey then return end
    end

    local pn=prompt.Parent.Name
    -- Vines / Cellar
    if (pn=="CuttableVines" or pn=="Chest_Vine" or pn=="Cellar")
        and not hasItem("Shears",true) and not hasItem("Multitool",true)
    then return end
    -- SkullLock
    if pn=="SkullLock" and not hasItem("SkeletonKey",true) then return end
    -- Locks
    if (pn=="Lock1" or pn=="Lock2")
        and not hasItem("Lockpick",true) and not hasItem("Multitool",true)
    then return end
    -- Shears priority
    if hasItem("Shears",true) and isLock
        and pn~="CuttableVines" and pn~="Chest_Vine" and pn~="Cellar"
    then return end
    -- Glitch fragments
    if pn=="GlitchCube" and autoInteractIgnoreList["Glitch Fragments"] then return end
    -- Keys already held
    if (pn=="KeyObtain" and (hasItem("Key") or hasItem("KeyBackdoor")))
        or (pn=="ElectricalKeyObtain" and hasItem("KeyElectrical"))
    then return end
    -- Dropped items
    if Drops and prompt:IsDescendantOf(Drops) and autoInteractIgnoreList["Dropped Items"] then return end
    -- Misc ignores
    if prompt.Name=="TrackLever" then return end
    if prompt.Name=="ActivateEventPrompt" and (prompt.ActionText=="Close"
        or pn=="ElevatorBreaker"
        or (prompt.Parent.Parent and prompt.Parent.Parent.Name=="IndustrialGate"))
    then return end
    if prompt.Name=="ActivateEventPrompt" and (pn=="Padlock" or pn=="MinesAnchor") then return end
    if pn=="LeverForGate" and prompt:GetAttribute("Interactions") then return end
    if prompt.Parent.Parent and (prompt.Parent.Parent.Name=="DoorFake" or prompt.Parent.Parent.Name=="FakeDoor") then return end
    if prompt.Parent:GetAttribute("JeffShop") and autoInteractIgnoreList["Jeff Items"] then return end
    if prompt.Name=="PushPrompt" and autoInteractIgnoreList["Minecarts"] then return end
    if (pn=="GoldPile" or pn=="StardustPickup") and autoInteractIgnoreList["Currency"] then return end
    if prompt:GetAttribute("AutoInteractIgnore") then return end

    -- Bandage — только если нужно лечение
    if pn=="Bandage" then
        local bpack=hasItem("BandagePack")
        if Humanoid and Humanoid.Health>=Humanoid.MaxHealth and not bpack then return end
        if bpack and bpack:GetAttribute("Durability") and bpack:GetAttribute("DurabilityMax")
            and bpack:GetAttribute("Durability")>=bpack:GetAttribute("DurabilityMax")
        then return end
    end

    -- Battery — только если есть lightsource или BatteryPack
    if pn=="Battery" then
        local tool = Character and Character:FindFirstChildOfClass("Tool")
        local bpack = hasItem("BatteryPack")
        if not tool and not bpack then return end
        if tool and tool:GetAttribute("LightSource") then
            if tool:GetAttribute("Durability") and tool:GetAttribute("DurabilityMax")
                and tool:GetAttribute("Durability")>tool:GetAttribute("DurabilityMax")
            then return end
        elseif not bpack then return end
        if bpack and bpack:GetAttribute("Durability") and bpack:GetAttribute("DurabilityMax")
            and bpack:GetAttribute("Durability")>=bpack:GetAttribute("DurabilityMax")
        then return end
    end

    -- HerbPrompt — не подбирать если эффект уже активен
    if prompt.Name=="HerbPrompt" and Globals.MainUI then
        pcall(function()
            local effects=Globals.MainUI.MainFrame.Healthbar:FindFirstChild("Effects")
            if effects and effects:FindFirstChild("HerbGreenEffect") and effects.HerbGreenEffect.Visible then return end
        end)
    end

    -- LibraryHintPaper — не подбирать если уже есть
    if (pn=="LibraryHintPaper" or pn=="PickupItem")
        and (hasItem("LibraryHintPaper") or hasItem("LibraryHintPaperHard"))
    then return end

    -- AlarmClock — не подбирать если уже есть
    if pn=="AlarmClock" and hasItem("AlarmClock") then return end

    -- Игнорировать фейковые ключи и жертвенные тарелки
    if pn=="KeyObtainFake" or pn=="TithingPlate" then return end

    forceFirePrompt(prompt)
    triggerDebounce=true
    if Floor=="OldHotel" then task.wait() end
    triggerDebounce=false
end

-- ==================== ONUNLOAD / CLEANUP ====================
-- Полная очистка при выгрузке скрипта (аналог Library:OnUnload)

local function onUnload()
    -- Отключаем все коннекции
    for _, conn in pairs(Connections) do
        pcall(function()
            if type(conn) == "function" then return end
            conn:Disconnect()
        end)
    end

    -- Восстанавливаем сущности
    for _, obj in Objects.Entities do
        if not obj or not obj.Parent then continue end
        if obj.Name=="Snare" or obj.Name=="GiggleCeiling" then
            local hitbox=obj:FindFirstChild("Hitbox")
            if hitbox then hitbox.CanTouch=true end
        end
        if obj.Name=="GloomPile" then
            for _,p in obj:GetDescendants() do if p:IsA("BasePart") then p.CanTouch=true end end
        end
        if obj.Name=="FakeDoor" or obj.Name=="DoorFake" then
            local hidden=obj:FindFirstChild("Hidden")
            if hidden then hidden.CanTouch=true end
            local lock=obj:FindFirstChild("Lock")
            if lock and lock:FindFirstChild("UnlockPrompt") then lock.UnlockPrompt.Enabled=true end
        end
        if obj.Name=="SideroomSpace" then
            local coll=obj:FindFirstChild("Collision")
            if coll then coll.CanCollide=false coll.CanTouch=true end
        end
    end

    -- Удаляем SeekBridges
    for _, obj in Objects.SeekBridges do pcall(function() obj:Destroy() end) end

    -- Восстанавливаем туман
    for _, atmo in Globals.FogInstances do
        pcall(function()
            atmo.Density = atmo:GetAttribute("Density_Old") or 0
        end)
    end
    Lighting.FogEnd = Globals.OldFog

    -- Восстанавливаем HideVignette
    if Globals.MainUI then
        pcall(function()
            local vig = Globals.MainUI:FindFirstChild("HideVignette")
                or Globals.MainUI.MainFrame:FindFirstChild("HideVignette")
            if vig then vig.Image="rbxassetid://6100076320" end
        end)
    end

    -- Восстанавливаем модули
    local restores = {
        Screech="Screech", GlitchScreech="GlitchScreech", Glitch="Glitch",
        Shade="Shade", SpiderJumpscare="SpiderJumpscare",
        A90="A90", Dread="Dread", Void="Void"
    }
    for key, origName in pairs(restores) do
        if Modules[key] and Modules[key].Parent then
            pcall(function() Modules[key].Name=origName end)
        end
    end

    -- Восстанавливаем FakeEvents
    pcall(function()
        FakeEvents.Screech:Destroy()
        if FakeEvents.Screech_Real then FakeEvents.Screech_Real.Parent=RemotesFolder end
        FakeEvents.Shade:Destroy()
        if FakeEvents.Shade_Real then FakeEvents.Shade_Real.Parent=RemotesFolder end
        if FakeEvents.A90_Real then
            FakeEvents.A90:Destroy()
            FakeEvents.A90_Real.Parent=RemotesFolder
        end
        if FakeEvents.Surge_Real then
            FakeEvents.Surge:Destroy()
            FakeEvents.Surge_Real.Parent=RemotesFolder
        end
    end)

    -- Удаляем служебные папки
    pcall(function() Globals.SeekNodesFolder:Destroy() end)
    pcall(function() Globals.RoomsNodesFolder:Destroy() end)
    pcall(function() Globals.PromptContainer:Destroy() end)
    pcall(function() ManipulateBody:Destroy() end)
    pcall(function() FlyBody:Destroy() end)

    -- Восстанавливаем ambient
    if CurrentRooms then
        pcall(function()
            local room = CurrentRooms:FindFirstChild(tostring(LP:GetAttribute("CurrentRoom")))
            if room then
                local oldAmbient = room:GetAttribute("Ambient")
                TweenService:Create(Lighting, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {
                    Ambient = oldAmbient or Color3.new(0,0,0)
                }):Play()
            end
        end)
    end

    -- Восстанавливаем промпты
    for _, prompt in Objects.Prompts do
        pcall(function()
            if not prompt or not prompt.Parent then return end
            local real = FakePrompts[prompt]
            if real then
                real.Parent = prompt.Parent
                prompt:Destroy()
            else
                prompt.HoldDuration = prompt:GetAttribute("HoldDuration_Old") or prompt.HoldDuration
                prompt.RequiresLineOfSight = prompt:GetAttribute("RequiresLineOfSight_Old") or prompt.RequiresLineOfSight
                prompt.MaxActivationDistance = prompt:GetAttribute("MaxActivationDistance_Old") or prompt.MaxActivationDistance
            end
        end)
    end

    -- Восстанавливаем персонажа
    if Character then
        pcall(function() Character:SetAttribute("CanJump", OldJump) end)
        pcall(function() Character:SetAttribute("CanSlide", OldSlide) end)
    end
    if Humanoid then
        pcall(function()
            Humanoid.WalkSpeed = getCurrentSpeed(0)
            Humanoid.JumpPower = 5
            Humanoid.HipHeight = 2.367
        end)
    end
    if RootPart then
        pcall(function()
            local baseY = 0.18
            if Collision then Collision.Position = RootPart.Position + Vector3.new(0, baseY, 0) end
            if CollisionPart then CollisionPart.Position = RootPart.Position + Vector3.new(0, baseY, 0) end
            if CollisionPartClone then CollisionPartClone.Position = RootPart.Position + Vector3.new(0, baseY, 0) end
            if Character and Character:FindFirstChild("LowerTorso") and Character.LowerTorso:FindFirstChild("Root") and Globals.OriginalC1 then
                Character.LowerTorso.Root.C1 = Globals.OriginalC1
            end
            if Collision and Collision:FindFirstChild("CollisionCrouch") then
                Collision.CollisionCrouch.Position = RootPart.Position + Vector3.new(0, -0.982, 0)
            end
        end)
    end
    if CollisionClone then pcall(function() CollisionClone:Destroy() end) end
    if CollisionPartClone then pcall(function() CollisionPartClone:Destroy() end) end

    -- Восстанавливаем камеру и Main_Game
    if Main_Game then
        pcall(function()
            Main_Game.fovtarget    = 70
            Main_Game.spring.Speed = 8
            Main_Game.tooloffset   = Vector3.zero
            if removeCamShake then Main_Game.csgo = nil end
        end)
    end
    Camera.FieldOfView = 70
    Camera.CameraType = Enum.CameraType.Custom

    -- Восстанавливаем Controls
    if Globals.OriginalGetMoveVector then
        pcall(function()
            local Controls = require(LP.PlayerScripts.PlayerModule):GetControls()
            Controls.GetMoveVector = Globals.OriginalGetMoveVector
        end)
    end

    -- Убираем весь ESP
    for obj in pairs(espObjects) do
        pcall(function() removeESP(obj) end)
    end

    -- Убираем TimeShower
    if TimeShowerLabel and TimeShowerLabel.Parent then
        TimeShowerLabel.Parent.Parent:Destroy()
    end

    print("[Just X Hub] Unloaded.")
end

-- Привязываем к уничтожению GUI
local unloadConn
unloadConn = LP.PlayerGui.ChildRemoved:Connect(function(child)
    if child.Name=="JustXHub" or child.Name=="CrossServerCopy" then
        pcall(onUnload)
        unloadConn:Disconnect()
    end
end)

-- Также при выходе персонажа с определёнными условиями
game:BindToClose(function()
    pcall(onUnload)
end)
