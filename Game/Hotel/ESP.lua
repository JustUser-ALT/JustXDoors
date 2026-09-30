local Module = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Context
local Tab
local Connections = {}
local Elements = {}

local ESP = {
    Doors = {},
    Drawers = {},
    Closets = {},
    Key = {},
    Gold = {},
    Chest = {},
    Bandage = {},
    Smoothie = {},
    Flashlight = {},
    TipJar = {},
    Ambush = {},
    Vitamins = {},
    Lighter = {},
    Candle = {},
    AlarmClock = {},
    Lockpick = {},
    SkeletonKey = {},
    Shears = {},
    RiftCandle = {},
    RiftSmoothie = {},
    RiftJar = {},
    Donut = {},
    Crucifix = {},
    SallyToy = {},
    ElectricalKey = {},
    BreakerPole = {},
    Battery = {},
    Dupe = {},
    Eyes = {},
    SallyLingering = {},
    SallyMoving = {},
    Seek = {},
    Figure = {},
    Snare = {},
    Screech = {},
    VentGate = {},
    Toolshed = {},
    Lever = {},
    Rush = {},
}

local Enabled = {
    Doors = false,
    Drawers = false,
    Closets = false,
    Key = false,
    Gold = false,
    Chest = false,
    LockedChest = false,
    Rush = false,
    Ambush = false,
    Vitamins = false,
    Lighter = false,
    Candle = false,
    AlarmClock = false,
    Lockpick = false,
    SkeletonKey = false,
    Shears = false,
    RiftCandle = false,
    RiftSmoothie = false,
    RiftJar = false,
    Donut = false,
    Crucifix = false,
    SallyToy = false,
    ElectricalKey = false,
    BreakerPole = false,
    Battery = false,
    Dupe = false,
    Eyes = false,
    SallyLingering = false,
    SallyMoving = false,
    Seek = false,
    Figure = false,
    Snare = false,
    Screech = false,
    Toolshed = false,
}

Module.GoldLevel = 1

local Display = {
    Name = true,
    Distance = false,
}

local Colors = {
    Doors = Color3.fromRGB(80, 170, 255),
    Drawers = Color3.fromRGB(255, 150, 60),
    Closets = Color3.fromRGB(165, 105, 55),
    Key = Color3.fromRGB(70, 235, 220),
    Gold = Color3.fromRGB(255, 215, 50),
    Chest = Color3.fromRGB(255, 230, 80),
    Bandage = Color3.fromRGB(235, 235, 235),
    Smoothie = Color3.fromRGB(190, 100, 255),
    Flashlight = Color3.fromRGB(255, 245, 170),
    TipJar = Color3.fromRGB(255, 190, 90),
    Vitamins = Color3.fromRGB(80, 255, 120),
    Lighter = Color3.fromRGB(255, 170, 70),
    Candle = Color3.fromRGB(255, 220, 150),
    AlarmClock = Color3.fromRGB(255, 90, 120),
    Lockpick = Color3.fromRGB(150, 150, 160),
    SkeletonKey = Color3.fromRGB(210, 210, 220),
    Shears = Color3.fromRGB(180, 220, 255),
    RiftCandle = Color3.fromRGB(180, 100, 255),
    RiftSmoothie = Color3.fromRGB(210, 100, 255),
    RiftJar = Color3.fromRGB(255, 130, 220),
    Donut = Color3.fromRGB(255, 150, 190),
    Crucifix = Color3.fromRGB(240, 240, 255),
    SallyToy = Color3.fromRGB(255, 120, 180),
    ElectricalKey = Color3.fromRGB(80, 220, 255),
    BreakerPole = Color3.fromRGB(255, 240, 100),
    Battery = Color3.fromRGB(120, 190, 255),
    Dupe = Color3.fromRGB(255, 130, 60),
    Eyes = Color3.fromRGB(180, 90, 255),
    SallyLingering = Color3.fromRGB(255, 120, 180),
    SallyMoving = Color3.fromRGB(255, 70, 150),
    Seek = Color3.fromRGB(70, 150, 255),
    Figure = Color3.fromRGB(255, 80, 80),
    Snare = Color3.fromRGB(100, 220, 100),
    Screech = Color3.fromRGB(220, 220, 255),
    Toolshed = Color3.fromRGB(160, 110, 70),
    Rush = Color3.fromRGB(255, 70, 70),
    Ambush = Color3.fromRGB(190, 70, 255),
    VentGate = Color3.fromRGB(100, 190, 255),
    Lever = Color3.fromRGB(255, 190, 70),
    Rush = Color3.fromRGB(255, 70, 70),
}

local ScanTimer = 0
local RoomsConnection
local RoomScanQueued = {}
local HighlightContainer
local NotifiedEntities = {}

local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(Connections, c)
    return c
end

local function disconnectAll()
    for _, c in ipairs(Connections) do
        pcall(function()
            c:Disconnect()
        end)
    end

    table.clear(Connections)
end

local function getRooms()
    return workspace:FindFirstChild("CurrentRooms")
end

local function getRoot()
    local character = Players.LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getPart(object)
    if not object then
        return nil
    end

    if object:IsA("BasePart") then
        return object
    end

    if object:IsA("Model") then
        if object.PrimaryPart then
            return object.PrimaryPart
        end

        local hitbox = object:FindFirstChild("Hitbox", true)
        if hitbox and hitbox:IsA("BasePart") then
            return hitbox
        end

        local handle = object:FindFirstChild("Handle", true)
        if handle and handle:IsA("BasePart") then
            return handle
        end

        return object:FindFirstChildWhichIsA("BasePart", true)
    end

    return object:FindFirstChildWhichIsA("BasePart", true)
end

local function getDoorNumber(room)
    local door = room and room:FindFirstChild("Door")
    local sign = door and door:FindFirstChild("Sign")
    local stinker = sign and sign:FindFirstChild("Stinker")

    if stinker then
        local ok, value = pcall(function()
            return stinker.Text
        end)

        if ok and type(value) == "string" then
            local number = tonumber(value:match("%d+"))
            if number then
                return string.format("%04d", number)
            end
        end
    end

    local roomNumber = room and tonumber(room.Name)

    if roomNumber then
        return string.format("%04d", roomNumber + 1)
    end

    return "????"
end

local function getLabel(kind, object)
    local text = {}

    if Display.Name then
        if kind == "Doors" then
            local room = object:GetAttribute("JustXDoorsRoom")
            local rooms = getRooms()
            local roomObject = rooms and rooms:FindFirstChild(tostring(room))

            text[#text + 1] = "Door • " .. getDoorNumber(roomObject)
        else
            if kind == "Key" then
                text[#text + 1] = "Key"
            elseif kind == "Gold" then
                text[#text + 1] = "Gold"
            elseif kind == "Drawers" then
                text[#text + 1] = "Drawer"
            elseif kind == "Closets" then
                text[#text + 1] = "Closet"
            elseif kind == "Chest" then
                text[#text + 1] = "LockedChest"
                if object.Name == "ChestBox" then
                    text[#text] = "Chest"
                end
                    elseif kind == "Bandage" then
                text[#text + 1] = "Bandage"
            elseif kind == "Smoothie" then
                text[#text + 1] = "Smoothie"
            elseif kind == "Flashlight" then
                text[#text + 1] = "Flashlight"
            elseif kind == "TipJar" then
                text[#text + 1] = "Tip Jar"
            elseif kind == "RiftCandle" then
                text[#text + 1] = "Rift Candle"
            elseif kind == "RiftSmoothie" then
                text[#text + 1] = "Rift Smoothie"
            elseif kind == "RiftJar" then
                text[#text + 1] = "Rift Jar"
            elseif kind == "SkeletonKey" then
                text[#text + 1] = "Skeleton Key"
            elseif kind == "SallyToy" then
                text[#text + 1] = "Sally Toy"
            elseif kind == "ElectricalKey" then
                text[#text + 1] = "Electrical Key"
            elseif kind == "BreakerPole" then
                text[#text + 1] = "Breaker Pole"
            elseif kind == "SallyLingering" then
                text[#text + 1] = "Sally"
            elseif kind == "SallyMoving" then
                text[#text + 1] = "Sally"
            elseif kind == "VentGate" then
                text[#text + 1] = "Vent Gate"
            elseif kind == "Lever" then
                text[#text + 1] = "Lever"
            elseif kind == "Rush" then
                text[#text + 1] = "Rush"
            elseif kind == "Ambush" then
                text[#text + 1] = "Ambush"
            elseif kind == "Dupe" then
                text[#text + 1] = "Dupe"
            elseif kind == "Eyes" then
                text[#text + 1] = "Eyes"
            elseif kind == "Seek" then
                text[#text + 1] = "Seek"
            elseif kind == "Figure" then
                text[#text + 1] = "Figure"
            elseif kind == "Snare" then
                text[#text + 1] = "Snare"
            elseif kind == "Toolshed" then
                text[#text + 1] = "Toolshed"
            else
                text[#text + 1] = kind
            end
        end
    end

    if Display.Distance then
        local root = getRoot()
        local part = getPart(object)

        if root and part then
            text[#text + 1] = tostring(math.floor((root.Position - part.Position).Magnitude + 0.5))
        end
    end

    return table.concat(text, " • ")
end

local function destroyLabel(entry)
    if entry.Label then
        pcall(function()
            entry.Label:Destroy()
        end)
        entry.Label = nil
    end
end

local function updateLabel(kind, object, entry)
    if not object or not object.Parent then
        return
    end

    local part = getPart(object)

    if not part then
        destroyLabel(entry)
        return
    end

    if not Display.Name and not Display.Distance then
        if entry.Label then
            entry.Label.Enabled = false
        end
        return
    end

    if not entry.Label then
        local gui = Instance.new("BillboardGui")
        gui.Name = "JustXDoorsESPLabel"
        gui.AlwaysOnTop = true
        gui.LightInfluence = 0
        gui.MaxDistance = 1000
        gui.Size = UDim2.fromOffset(180, 26)
        gui.StudsOffset = Vector3.new(0, 2.5, 0)
        gui.Adornee = part
        gui.Parent = part

        local label = Instance.new("TextLabel")
        label.Name = "Text"
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextColor3 = Colors[kind]
        label.TextStrokeTransparency = 0.35
        label.Parent = gui

        entry.Label = gui
    else
        entry.Label.Adornee = part
    end

    entry.Label.Enabled = true

    local label = entry.Label:FindFirstChild("Text")
    if label then
        label.Text = getLabel(kind, object)
    end
end

local function destroyProxy(entry)
    if entry.Proxy then
        pcall(function()
            entry.Proxy:Destroy()
        end)
        entry.Proxy = nil
    end
end

local function getHighlightContainer()
    if HighlightContainer and HighlightContainer.Parent then
        return HighlightContainer
    end

    HighlightContainer = Instance.new("Folder")
    HighlightContainer.Name = "JustXDoors_HotelESP"
    HighlightContainer.Parent = workspace
    return HighlightContainer
end

local function isIgnoredPart(part)
    local n = part.Name:lower()
    return n:find("hitbox", 1, true)
        or n:find("collision", 1, true)
        or n:find("prompt", 1, true)
        or n == "primarypart"
end

local function getVisiblePart(object)
    local preferred = {"Handle", "Main", "Key", "Mesh", "Root"}
    for _, name in ipairs(preferred) do
        local p = object:FindFirstChild(name, true)
        if p and p:IsA("BasePart") and p.Transparency < 1 and not isIgnoredPart(p) then
            return p
        end
    end

    local best
    local bestVolume = math.huge
    for _, p in ipairs(object:GetDescendants()) do
        if p:IsA("BasePart") and p.Transparency < 1 and not isIgnoredPart(p) then
            local volume = p.Size.X * p.Size.Y * p.Size.Z
            if volume > 0 and volume < bestVolume then
                best = p
                bestVolume = volume
            end
        end
    end
    return best
end

local function buildDoorProxy(entry, object)
    destroyProxy(entry)

    local proxy = Instance.new("Model")
    proxy.Name = "HighlightModel"
    proxy.Parent = workspace

    local humanoid = Instance.new("Humanoid")
    humanoid.Name = "HighlightHumanoid"
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.Parent = proxy

    local count = 0
    for _, source in ipairs(object:GetChildren()) do
        if source:IsA("BasePart") and source.Name == "Door" then
            local part = Instance.new("Part")
            part.Name = "HighlightPart"
            part.Transparency = 0.999
            part.Size = source.Size
            part.CFrame = source.CFrame
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.Material = Enum.Material.Glass
            part.Parent = proxy

            local weld = Instance.new("WeldConstraint")
            weld.Part0 = part
            weld.Part1 = source
            weld.Parent = part

            count += 1
        end
    end

    if count == 0 then
        proxy:Destroy()
        return nil
    end

    entry.Proxy = proxy
    return proxy
end

local function addHighlight(entry, object, kind)
    local adornee

    if kind == "Doors" then
        adornee = buildDoorProxy(entry, object)
    else
        adornee = object
    end

    if not adornee then
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "JustXDoorsESP"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Colors[kind]
    highlight.OutlineColor = Colors[kind]
    highlight.FillTransparency = (kind == "Drawers" or kind == "Closets" or kind == "Chest") and 1 or 0.55
    highlight.OutlineTransparency = 0
    highlight.Adornee = adornee
    highlight.Parent = getHighlightContainer()

    entry.Highlights[#entry.Highlights + 1] = highlight
end

local function rebuildHighlights(entry, object, kind)
    for _, highlight in ipairs(entry.Highlights) do
        pcall(function()
            highlight:Destroy()
        end)
    end
    table.clear(entry.Highlights)
    addHighlight(entry, object, kind)
end

local function clearEntry(kind, object)
    local entry = ESP[kind][object]

    if not entry then
        return
    end

    for _, highlight in ipairs(entry.Highlights) do
        pcall(function()
            highlight:Destroy()
        end)
    end

    destroyLabel(entry)
    destroyProxy(entry)
    if entry.Connection then
        pcall(function()
            entry.Connection:Disconnect()
        end)
        entry.Connection = nil
    end
    if entry.RemovingConnection then
        pcall(function()
            entry.RemovingConnection:Disconnect()
        end)
        entry.RemovingConnection = nil
    end
    ESP[kind][object] = nil
end

local function addObject(kind, object, room)
    if not object or not object.Parent then
        return
    end

    if ESP[kind][object] then
        local entry = ESP[kind][object]

        local hasLiveHighlight = false
        for _, highlight in ipairs(entry.Highlights) do
            if highlight and highlight.Parent then
                hasLiveHighlight = true
                break
            end
        end

        if not hasLiveHighlight then
            rebuildHighlights(entry, object, kind)
        end

        updateLabel(kind, object, entry)
        return
    end

    local entry = {
        Highlights = {},
        Room = room,
    }

    ESP[kind][object] = entry

    if kind == "Doors" and room then
        object:SetAttribute("JustXDoorsRoom", tonumber(room.Name))
    end

    addHighlight(entry, object, kind)

    if kind == "Doors" then
        entry.Connection = object.ChildAdded:Connect(function(child)
            if child:IsA("BasePart") and child.Name == "Door" then
                task.defer(function()
                    if object.Parent and ESP[kind][object] == entry then
                        rebuildHighlights(entry, object, kind)
                    end
                end)
            end
        end)

        entry.RemovingConnection = object.ChildRemoved:Connect(function(child)
            if child:IsA("BasePart") and child.Name == "Door" then
                task.defer(function()
                    if object.Parent and ESP[kind][object] == entry then
                        rebuildHighlights(entry, object, kind)
                    end
                end)
            end
        end)

        table.insert(Connections, entry.Connection)
        table.insert(Connections, entry.RemovingConnection)
    end

    object.Destroying:Once(function()
        clearEntry(kind, object)
    end)

    updateLabel(kind, object, entry)
end

local function hasDrawerContainer(object)
    return object and object:FindFirstChild("DrawerContainer", true) ~= nil
end

local function isRoomVisible(kind, room)
    local current = tonumber(Players.LocalPlayer:GetAttribute("CurrentRoom"))
    local number = tonumber(room and room.Name)

    if not current or not number then
        return true
    end

    if kind == "Doors" then
        return number == current or number == current + 1
    end

    if kind == "Key" or kind == "Gold"
        or kind == "Crucifix" or kind == "SallyToy"
        or kind == "ElectricalKey" or kind == "BreakerPole"
    then
        return number >= current - 1 and number <= current + 1
    end

    return number == current
end

local function isInsidePlayerInventory(object)
    local backpack = Players.LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack and object:IsDescendantOf(backpack) then
        return true
    end

    local character = Players.LocalPlayer.Character
    if character and object:IsDescendantOf(character) then
        return true
    end

    local playerModel = workspace:FindFirstChild(Players.LocalPlayer.Name)
    if playerModel and object:IsDescendantOf(playerModel) then
        return true
    end

    return false
end

local function addNamedWorkspaceObject(kind, object, room, allowInventory)
    if not object or not object.Parent then
        return
    end

    if not allowInventory and isInsidePlayerInventory(object) then
        return
    end

    addObject(kind, object, room)
end

local function scanDropItems()
    local drops = workspace:FindFirstChild("Drops")
    if not drops then
        return
    end

    -- Only direct children of Drops are valid dropped items.
    -- Do not scan descendants: Candle/BatteryPack can contain nested
    -- objects with item-like names.
    local map = {
        Vitamins="Vitamins", Lighter="Lighter", Candle="Candle",
        AlarmClock="AlarmClock", Lockpick="Lockpick", SkeletonKey="SkeletonKey",
        Shears="Shears", Battery="Battery", Bandage="Bandage",
        Smoothie="Smoothie", Flashlight="Flashlight", TipJar="TipJar",
        RiftCandle="RiftCandle", RiftSmoothie="RiftSmoothie", RiftJar="RiftJar",
        Donut="Donut", Crucifix="Crucifix",
    }

    for _, object in ipairs(drops:GetChildren()) do
        local kind = map[object.Name]
        if kind and Enabled[kind] then
            addNamedWorkspaceObject(kind, object, nil, false)
        end
    end
end
local function scanSpecialHotelItems()
    local rooms = getRooms()
    if not rooms then
        return
    end

    local room1 = rooms:FindFirstChild("1")
    if Enabled.Crucifix and room1 and isRoomVisible("Crucifix", room1) then
        local wall = room1:FindFirstChild("CrucifixWall", true)
        if wall then
            addNamedWorkspaceObject("Crucifix", wall, room1, false)
        end
    end

    local room28 = rooms:FindFirstChild("28")
    if Enabled.SallyToy and room28 and isRoomVisible("SallyToy", room28) then
        local toy = room28:FindFirstChild("SallyToyObtain", true)
        if toy then
            addNamedWorkspaceObject("SallyToy", toy, room28, false)
        end
    end

    local room100 = rooms:FindFirstChild("100")
    if Enabled.ElectricalKey and room100 and isRoomVisible("ElectricalKey", room100) then
        local key = room100:FindFirstChild("ElectricalKeyObtain", true)
        if key then
            addNamedWorkspaceObject("ElectricalKey", key, room100, false)
        end
    end

    if Enabled.BreakerPole then
        for _, object in ipairs(workspace:GetDescendants()) do
            if object.Name == "LiveBreakerPolePickup" then
                local room = object:FindFirstAncestorWhichIsA("Model")
                while room and tonumber(room.Name) == nil and room.Parent do
                    room = room.Parent
                end
                if room and isRoomVisible("BreakerPole", room) then
                    addNamedWorkspaceObject("BreakerPole", object, room, false)
                end
            end
        end
    end
end

local EntityESPNames = {
    SideroomDupe = "Dupe",
    Eyes = "Eyes",
    SallyLingering = "SallyLingering",
    SallyMoving = "SallyMoving",
    SeekMovingNewClone = "Seek",
    FigureRig = "Figure",
    Snare = "Snare",
    Screech = "Screech",
}

local function scanSpecialEntities()
    local found = {}

    for _, object in ipairs(workspace:GetDescendants()) do
        local kind = EntityESPNames[object.Name]

        if kind and Enabled[kind]
            and (object:IsA("Model") or object:IsA("BasePart"))
        then
            found[kind] = found[kind] or {}
            found[kind][object] = true

            if kind ~= "Snare" then
                notifyEntity(object)
            end

            addNamedWorkspaceObject(kind, object, nil, true)
        end
    end

    local enabledKinds = {
        "Dupe",
        "Eyes",
        "SallyLingering",
        "SallyMoving",
        "Seek",
        "Figure",
        "Snare",
        "Screech",
    }

    for _, kind in ipairs(enabledKinds) do
        if Enabled[kind] then
            for object in pairs(ESP[kind]) do
                if not found[kind] or not found[kind][object] or not object.Parent then
                    clearEntry(kind, object)
                end
            end
        else
            clearKind(kind)
        end
    end
end

local function scanRoom(room)
    if not room or not room.Parent then
        return
    end

    local roomVisible = {
        Doors = isRoomVisible("Doors", room),
        Drawers = isRoomVisible("Drawers", room),
        Closets = isRoomVisible("Closets", room),
        Key = isRoomVisible("Key", room),
        Gold = isRoomVisible("Gold", room),
    }

    local door = room:FindFirstChild("Door")
    if Enabled.Doors and roomVisible.Doors and door then
        addObject("Doors", door, room)
    end

    for _, object in ipairs(room:GetDescendants()) do
        if not object:IsA("Model") and not object:IsA("BasePart") then
            continue
        end

        if Enabled.Drawers and roomVisible.Drawers
            and (object.Name == "Dresser" or object.Name == "Table" or object.Name == "Rolltop_Desk")
            and (object.Name == "Rolltop_Desk" or hasDrawerContainer(object))
        then
            addObject("Drawers", object, room)
        end

        if Enabled.Closets and roomVisible.Closets
            and (object.Name == "Wardrobe" or object.Name == "Toolshed")
        then
            addObject("Closets", object, room)
        end

        if Enabled.Toolshed and roomVisible.Closets and object.Name == "Toolshed_Small" then
            addObject("Toolshed", object, room)
        end

        if (Enabled.Chest or Enabled.LockedChest) and roomVisible.Drawers then
            if Enabled.Chest and (object.Name == "ChestBox" or object.Name == "ChestBoxLocked") then
                addObject("Chest", object, room)
            elseif Enabled.LockedChest and object.Name == "LockedChestBox" then
                addObject("Chest", object, room)
            end
        end

        if Enabled.Key and object.Name == "KeyObtain" then
            addObject("Key", object, room)
        end

        if Enabled.Gold and object.Name == "GoldPile" then
            for _, levelObject in ipairs(object:GetChildren()) do
                local level = tonumber(levelObject.Name)
                if level and level >= (Module.GoldLevel or 1)
                    and (levelObject:IsA("Model") or levelObject:IsA("BasePart"))
                then
                    addObject("Gold", levelObject, room)
                end
            end
        end

        if object.Name == "Bandage" and Enabled.Bandage then
            addObject("Bandage", object, room)
        end

        if object.Name == "Smoothie" and Enabled.Smoothie then
            addObject("Smoothie", object, room)
        end

        if room.Name == "9" and (Enabled.Flashlight or Enabled.TipJar) then
            local shop = room:FindFirstChild("RiftRoom_JeffShop")
            if shop then
                if Enabled.Flashlight then
                    local flashlight = shop:FindFirstChild("Flashlight")
                    if flashlight then
                        addObject("Flashlight", flashlight, room)
                    end
                end
                if Enabled.TipJar then
                    local tipJar = shop:FindFirstChild("TipJar")
                    if tipJar then
                        addObject("TipJar", tipJar, room)
                    end
                end
            end
        end

        local roomItemMap = {
            Vitamins = "Vitamins",
            Lighter = "Lighter",
            Candle = "Candle",
            AlarmClock = "AlarmClock",
            Lockpick = "Lockpick",
            SkeletonKey = "SkeletonKey",
            Shears = "Shears",
            RiftCandle = "RiftCandle",
            RiftSmoothie = "RiftSmoothie",
            RiftJar = "RiftJar",
            Donut = "Donut",
            Crucifix = "Crucifix",
        }

        local roomItemKind = roomItemMap[object.Name]
        local decorativeBookcaseItem =
            roomItemKind == "Lighter"
            and object:FindFirstAncestor("Bookcase") ~= nil

        if roomItemKind
            and Enabled[roomItemKind]
            and not decorativeBookcaseItem
            and object:FindFirstChild("ModulePrompt", true)
        then
            addNamedWorkspaceObject(roomItemKind, object, room, false)
        end

        if object.Name == "VentGrate" and Enabled.VentGate and roomVisible.Drawers then
            addObject("VentGate", object, room)
        end

        if object.Name == "LeverForGate" and Enabled.Lever and roomVisible.Drawers then
            addObject("Lever", object, room)
        end
    end
end

local clearKind
local scanAll

local function clearEntityESP()
    clearKind("Rush")
end

local function notifyEntity(_) end

local function scanEntities()
    if not Enabled.Rush and not Enabled.Ambush then
        clearKind("Rush")
        clearKind("Ambush")
        return
    end

    local foundRush = {}
    local foundAmbush = {}

    for _, entity in ipairs(workspace:GetChildren()) do
        local isRush = entity.Name == "RushMoving"
        local isAmbush = entity.Name == "AmbushMoving"

        if (isRush and Enabled.Rush) or (isAmbush and Enabled.Ambush) then
            local root = entity:FindFirstChild("RushNew") or entity.PrimaryPart or entity:FindFirstChildWhichIsA("BasePart", true)
            if root and root:IsA("BasePart") then
                entity.PrimaryPart = root

                local humanoid = entity:FindFirstChild("HighlightHumanoid")
                if not humanoid then
                    humanoid = Instance.new("Humanoid")
                    humanoid.Name = "HighlightHumanoid"
                    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                    humanoid.Parent = entity
                end

                root.Transparency = 0.999
                root.Material = Enum.Material.Glass

                local kind = isRush and "Rush" or "Ambush"
                addObject(kind, entity, nil)
                if isRush then
                    foundRush[entity] = true
                else
                    foundAmbush[entity] = true
                end
            end
        end
    end

    for entity in pairs(ESP.Rush) do
        if not foundRush[entity] or not entity.Parent then
            clearEntry("Rush", entity)
        end
    end

    for entity in pairs(ESP.Ambush) do
        if not foundAmbush[entity] or not entity.Parent then
            clearEntry("Ambush", entity)
        end
    end
end
local function refreshRoomVisibility()
    -- Keep ESP for objects that still exist in Workspace.
    -- Changing CurrentRoom must not delete previous-room ESP.
    scanAll()
end

scanAll = function()
    local rooms = getRooms()

    if rooms then
        for _, room in ipairs(rooms:GetChildren()) do
            scanRoom(room)
        end
    end

    scanDropItems()
    scanSpecialHotelItems()
    scanSpecialEntities()
end

clearKind = function(kind)
    local copy = {}

    for object in pairs(ESP[kind]) do
        copy[#copy + 1] = object
    end

    for _, object in ipairs(copy) do
        clearEntry(kind, object)
    end
end

local function setKind(kind, enabled)
    if enabled then
        scanAll()
    else
        clearKind(kind)
    end
end

local function applyInteractables(selected)
    local doors = false
    local drawers = false
    local closets = false
    local chest = false
    local lockedChest = false
    local ventGate = false
    local lever = false
    local toolshed = false

    local function enable(value)
        if value == "Doors" then doors = true
        elseif value == "Drawers" then drawers = true
        elseif value == "Closets" then closets = true
        elseif value == "Chest" then chest = true
        elseif value == "LockedChest" then lockedChest = true
        elseif value == "Vent Gate" then ventGate = true
        elseif value == "Lever" then lever = true
        elseif value == "Toolshed" then toolshed = true
        elseif value == "All" then
            doors = true
            drawers = true
            closets = true
            chest = true
            lockedChest = true
            ventGate = true
            lever = true
            toolshed = true
        end
    end

    if type(selected) == "table" then
        if #selected > 0 then
            for _, value in ipairs(selected) do
                enable(value)
            end
        else
            if selected.Doors == true then doors = true end
            if selected.Drawers == true then drawers = true end
            if selected.Closets == true then closets = true end
            if selected.Chest == true then chest = true end
            if selected.LockedChest == true then lockedChest = true end
            if selected["Vent Gate"] == true then ventGate = true end
            if selected.Lever == true then lever = true end
            if selected.Toolshed == true then toolshed = true end
            if selected.All == true then
                doors = true
                drawers = true
                closets = true
                chest = true
                lockedChest = true
                ventGate = true
                lever = true
                toolshed = true
            end
        end
    else
        enable(selected)
    end

    Enabled.Doors = doors
    Enabled.Drawers = drawers
    Enabled.Closets = closets
    Enabled.Chest = chest
    Enabled.LockedChest = lockedChest
    Enabled.VentGate = ventGate
    Enabled.Lever = lever
    Enabled.Toolshed = toolshed

    setKind("Doors", doors)
    setKind("Drawers", drawers)
    setKind("Closets", closets)
    clearKind("Chest")
    clearKind("VentGate")
    clearKind("Lever")
    clearKind("Toolshed")

    if chest or lockedChest or ventGate or lever or toolshed then
        scanAll()
    end
end

local function applyItems(selected)
    local key = false
    local goldLevel = nil
    local bandage = false
    local smoothie = false
    local flashlight = false
    local tipJar = false
    local itemFlags = {
        Vitamins=false, Lighter=false, Candle=false, AlarmClock=false,
        Lockpick=false, SkeletonKey=false, Shears=false, Battery=false,
        RiftCandle=false, RiftSmoothie=false, RiftJar=false, Donut=false,
        Crucifix=false, SallyToy=false, ElectricalKey=false, BreakerPole=false,
    }

    local function enable(value)
        if value == "Key" then
            key = true
        elseif value == "Gold" then
            goldLevel = 1
        elseif value == "Bandage" then
            bandage = true
        elseif value == "Smoothie" then
            smoothie = true
        elseif value == "Flashlight" then
            flashlight = true
        elseif value == "Tip Jar" then
            tipJar = true
        else
            local map = {
                Vitamins="Vitamins", Lighter="Lighter", Candle="Candle",
                AlarmClock="AlarmClock", Lockpick="Lockpick",
                ["Skeleton Key"]="SkeletonKey", Shears="Shears", Battery="Battery",
                ["Rift Candle"]="RiftCandle", ["Rift Smoothie"]="RiftSmoothie",
                ["Rift Jar"]="RiftJar", Donut="Donut", Crucifix="Crucifix",
                ["Sally Toy"]="SallyToy", ["Electrical Key"]="ElectricalKey",
                ["Breaker Pole"]="BreakerPole",
            }
            local key = map[value]
            if key then itemFlags[key] = true end
        end
    end

    if type(selected) == "table" then
        if #selected > 0 then
            for _, value in ipairs(selected) do
                enable(value)
            end
        else
            if selected.Key == true then key = true end
            if selected.Gold ~= nil and selected.Gold ~= false then
                goldLevel = tonumber(selected.Gold) or 1
            end
            if selected.Bandage == true then bandage = true end
            if selected.Smoothie == true then smoothie = true end
            if selected.Flashlight == true then flashlight = true end
            if selected["Tip Jar"] == true then tipJar = true end
            local map = {
                Vitamins="Vitamins", Lighter="Lighter", Candle="Candle",
                AlarmClock="AlarmClock", Lockpick="Lockpick",
                ["Skeleton Key"]="SkeletonKey", Shears="Shears", Battery="Battery",
                ["Rift Candle"]="RiftCandle", ["Rift Smoothie"]="RiftSmoothie",
                ["Rift Jar"]="RiftJar", Donut="Donut", Crucifix="Crucifix",
                ["Sally Toy"]="SallyToy", ["Electrical Key"]="ElectricalKey",
                ["Breaker Pole"]="BreakerPole",
            }
            for label, key in pairs(map) do
                if selected[label] == true then itemFlags[key] = true end
            end
        end
    else
        enable(selected)
    end

    Enabled.Key = key
    Enabled.Gold = goldLevel ~= nil
    Enabled.Bandage = bandage
    Enabled.Smoothie = smoothie
    Enabled.Flashlight = flashlight
    Enabled.TipJar = tipJar
    for key, value in pairs(itemFlags) do
        Enabled[key] = value
    end
    Module.GoldLevel = goldLevel or 1

    local itemKinds = {
        "Key", "Gold", "Bandage", "Smoothie", "Flashlight", "TipJar",
        "Vitamins", "Lighter", "Candle", "AlarmClock", "Lockpick",
        "SkeletonKey", "Shears", "Battery", "RiftCandle", "RiftSmoothie",
        "RiftJar", "Donut", "Crucifix", "SallyToy", "ElectricalKey",
        "BreakerPole",
    }

    for _, kind in ipairs(itemKinds) do
        if not Enabled[kind] then
            clearKind(kind)
        end
    end

    scanAll()
end

local function refreshLabels()
    for kind, objects in pairs(ESP) do
        if type(objects) == "table" then
            for object, entry in pairs(objects) do
                if typeof(object) == "Instance" and object.Parent then
                    updateLabel(kind, object, entry)
                end
            end
        end
    end
end

local function queueRoomScan(room)
    if not room or not room.Parent or RoomScanQueued[room] then
        return
    end

    RoomScanQueued[room] = true

    task.defer(function()
        RoomScanQueued[room] = nil
        if room.Parent then
            scanRoom(room)
        end
    end)
end

local function hookRooms(rooms)
    if RoomsConnection then
        pcall(function()
            RoomsConnection:Disconnect()
        end)
        RoomsConnection = nil
    end

    if not rooms then
        return
    end

    RoomsConnection = rooms.ChildAdded:Connect(function(room)
        queueRoomScan(room)

        local roomConnection
        roomConnection = room.DescendantAdded:Connect(function()
            queueRoomScan(room)
        end)

        table.insert(Connections, roomConnection)

        task.delay(0.15, function()
            if room.Parent then
                queueRoomScan(room)
            end
        end)
    end)

    table.insert(Connections, RoomsConnection)

    for _, room in ipairs(rooms:GetChildren()) do
        local roomConnection = room.DescendantAdded:Connect(function()
            queueRoomScan(room)
        end)
        table.insert(Connections, roomConnection)
        queueRoomScan(room)
    end

    connect(rooms.DescendantAdded, function(object)
        if object.Name == "KeyObtain"
            or object.Name == "Door"
            or object.Name == "Dresser"
            or object.Name == "Table"
            or object.Name == "Wardrobe"
            or object.Name == "DrawerContainer"
            or object.Name == "Stinker"
            or object.Name == "GoldPile"
            or object.Name == "Bandage"
            or object.Name == "Smoothie"
            or object.Name == "Toolshed"
            or object.Name == "Toolshed_Small"
            or object.Name == "SideroomDupe"
            or object.Name == "FigureRig"
            or object.Name == "Snare"
            or object.Name == "SeekMovingNewClone"
            or object.Name == "CrucifixWall"
            or object.Name == "SallyToyObtain"
            or object.Name == "ElectricalKeyObtain"
            or object.Name == "LiveBreakerPolePickup"
            or object.Name == "VentGrate"
            or object.Name == "LeverForGate"
        then
            local room = object:FindFirstAncestorWhichIsA("Model")
            while room and tonumber(room.Name) == nil and room.Parent do
                room = room.Parent
            end
            if room then
                queueRoomScan(room)
            else
                scanAll()
            end
        end
    end)

    scanAll()
end


local function setup()
    local rooms = getRooms()
    if rooms then hookRooms(rooms) end

    local oldContainer = workspace:FindFirstChild("JustXDoors_HotelESP")
    if oldContainer then pcall(function() oldContainer:Destroy() end) end

    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("BillboardGui") and object.Name == "JustXDoorsESPLabel" then
            pcall(function() object:Destroy() end)
        end
    end

    connect(workspace.DescendantAdded, function(object)
        if object:IsA("ProximityPrompt") then return end
        if object.Name == "Eyes" or object.Name == "SallyLingering"
            or object.Name == "SallyMoving" or object.Name == "SeekMovingNewClone"
            or object.Name == "SideroomDupe" or object.Name == "FigureRig"
            or object.Name == "Snare" or object.Name == "Screech"
        then
            task.defer(scanSpecialEntities)
        elseif object.Name == "Vitamins" or object.Name == "Lighter"
            or object.Name == "Candle" or object.Name == "AlarmClock"
            or object.Name == "Lockpick" or object.Name == "SkeletonKey"
            or object.Name == "Shears" or object.Name == "Battery"
            or object.Name == "Bandage" or object.Name == "Smoothie"
            or object.Name == "Flashlight" or object.Name == "TipJar"
            or object.Name == "RiftCandle" or object.Name == "RiftSmoothie"
            or object.Name == "RiftJar" or object.Name == "Donut"
            or object.Name == "Crucifix"
        then
            task.defer(scanDropItems)
        end
    end)

    connect(workspace.ChildAdded, function(object)
        if object.Name == "CurrentRooms" then
            task.defer(function() hookRooms(object) end)
        elseif object.Name == "RushMoving" or object.Name == "AmbushMoving"
            or object.Name == "Eyes" or object.Name == "SallyLingering"
            or object.Name == "SallyMoving"
        then
            task.defer(function() scanEntities(); scanSpecialEntities() end)
        elseif object.Name == "Drops" then
            task.defer(scanDropItems)
        end
    end)

    connect(Players.LocalPlayer:GetAttributeChangedSignal("CurrentRoom"), refreshRoomVisibility)

    connect(RunService.Heartbeat, function(dt)
        ScanTimer += dt
        if ScanTimer < 0.35 then return end
        ScanTimer = 0

        if Enabled.Doors or Enabled.Drawers or Enabled.Closets or Enabled.Key or Enabled.Gold
            or Enabled.Chest or Enabled.Bandage or Enabled.Smoothie or Enabled.Flashlight
            or Enabled.TipJar or Enabled.Crucifix or Enabled.SallyToy or Enabled.ElectricalKey
            or Enabled.BreakerPole or Enabled.Battery or Enabled.Toolshed
            or Enabled.VentGate or Enabled.Lever
        then
            scanAll()
            refreshLabels()
        end

        if Enabled.Rush or Enabled.Ambush then scanEntities() end

        if Enabled.Dupe or Enabled.Eyes or Enabled.SallyLingering or Enabled.SallyMoving
            or Enabled.Seek or Enabled.Figure or Enabled.Snare or Enabled.Screech
        then
            scanSpecialEntities()
        end

        if Enabled.Vitamins or Enabled.Lighter or Enabled.Candle or Enabled.AlarmClock
            or Enabled.Lockpick or Enabled.SkeletonKey or Enabled.Shears or Enabled.Battery
            or Enabled.RiftCandle or Enabled.RiftSmoothie or Enabled.RiftJar or Enabled.Donut
            or Enabled.Crucifix or Enabled.SallyToy or Enabled.ElectricalKey or Enabled.BreakerPole
        then
            scanDropItems()
            scanSpecialHotelItems()
        end
    end)
end

function Module:Init(context)
    Context = context or {}
    Enabled = Context.Enabled or Enabled
    Colors = Context.Colors or Colors
    Display = Context.Display or Display
    Module.GoldLevel = Module.GoldLevel or 1
    setup()
    Module.Enabled = Enabled
    Module.Colors = Colors
    Module.Display = Display
    Module.Objects = ESP
    return Module
end

function Module:ApplyInteractables(selected) applyInteractables(selected) end
function Module:ApplyItems(selected) applyItems(selected) end
function Module:SetEntities(state)
    Enabled.Rush = state.Rush == true
    Enabled.Ambush = state.Ambush == true
    Enabled.Dupe = state.Dupe == true
    Enabled.Eyes = state.Eyes == true
    Enabled.SallyLingering = state.Sally == true
    Enabled.SallyMoving = state.Sally == true
    Enabled.Seek = state.Seek == true
    Enabled.Figure = state.Figure == true
    Enabled.Snare = state.Snare == true
    Enabled.Screech = state.Screech == true
    scanEntities()
    scanSpecialEntities()
end
function Module:RefreshLabels() refreshLabels() end
function Module:ScanAll() scanAll() end

function Module:Destroy()
    local kinds = {
        "Doors","Drawers","Closets","Key","Gold","Chest","Bandage","Smoothie","Flashlight",
        "TipJar","VentGate","Lever","Rush","Ambush","Vitamins","Lighter","Candle","AlarmClock",
        "Lockpick","SkeletonKey","Shears","RiftCandle","RiftSmoothie","RiftJar","Donut",
        "Crucifix","SallyToy","ElectricalKey","BreakerPole","Battery","Dupe","Eyes",
        "SallyLingering","SallyMoving","Seek","Figure","Snare","Screech","Toolshed"
    }
    for _, kind in ipairs(kinds) do clearKind(kind) end
    if HighlightContainer then
        pcall(function() HighlightContainer:Destroy() end)
        HighlightContainer = nil
    end
    table.clear(RoomScanQueued)
    disconnectAll()
    RoomsConnection = nil
end

return Module
