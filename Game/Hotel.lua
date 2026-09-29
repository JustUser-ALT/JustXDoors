local Hotel = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Core
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
    VentGate = {},
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
}

Hotel.GoldLevel = 1

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
            elseif kind == "VentGate" then
                text[#text + 1] = "Vent Gate"
            elseif kind == "Lever" then
                text[#text + 1] = "Lever"
            elseif kind == "Rush" then
                text[#text + 1] = "Rush"
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

    if kind == "Key" or kind == "Gold" then
        return number >= current - 1 and number <= current + 1
    end

    return number == current
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

        if Enabled.Closets and roomVisible.Closets and object.Name == "Wardrobe" then
            addObject("Closets", object, room)
        end

        if (Enabled.Chest or Enabled.LockedChest) and roomVisible.Drawers then
            if Enabled.Chest and (object.Name == "ChestBox" or object.Name == "ChestBoxLocked") then
                addObject("Chest", object, room)
            elseif Enabled.LockedChest and object.Name == "LockedChestBox" then
                addObject("Chest", object, room)
            end
        end

        if Enabled.Key and roomVisible.Key and object.Name == "KeyObtain" then
            addObject("Key", object, room)
        end

        if Enabled.Gold and roomVisible.Gold and object.Name == "GoldPile" then
            for _, levelObject in ipairs(object:GetChildren()) do
                local level = tonumber(levelObject.Name)
                if level and level >= (Hotel.GoldLevel or 1)
                    and (levelObject:IsA("Model") or levelObject:IsA("BasePart"))
                then
                    addObject("Gold", levelObject, room)
                end
            end
        end

        if object.Name == "Bandage" and Enabled.Bandage and roomVisible.Key then
            addObject("Bandage", object, room)
        end

        if object.Name == "Smoothie" and Enabled.Smoothie and roomVisible.Key then
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

local function isSelected(value, name)
    if type(value) == "table" then
        if #value > 0 then
            return table.find(value, name) ~= nil
        end
        return value[name] ~= nil
    end
    return value == name
end

local function notifyEntity(entity)
    if not entity or NotifiedEntities[entity] then
        return
    end

    if not Elements.NotifyEntities or not Elements.NotifyEntities:Get() then
        return
    end

    local alias = entity.Name == "RushMoving" and "Rush" or entity.Name == "AmbushMoving" and "Ambush" or nil
    if not alias then
        return
    end

    local selected = Elements.NotificationEntities and Elements.NotificationEntities:Get()
    if not isSelected(selected, alias) then
        return
    end

    NotifiedEntities[entity] = true

    if Core then
        Core:Notify({
            Title = "Entity '" .. alias .. "' has spawned.",
            Desc = "Find a hiding spot.",
            Type = "Warning",
            Duration = 5,
        })
    end

    entity.Destroying:Once(function()
        NotifiedEntities[entity] = nil
    end)
end

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
                notifyEntity(entity)

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
    local current = tonumber(Players.LocalPlayer:GetAttribute("CurrentRoom"))
    if not current then return end

    for kind, objects in pairs(ESP) do
        for object, entry in pairs(objects) do
            if kind ~= "Rush" then
                local room = entry.Room
                if not room or not room.Parent or not isRoomVisible(kind, room) then
                    clearEntry(kind, object)
                end
            end
        end
    end

    scanAll()
end

scanAll = function()
    local rooms = getRooms()

    if not rooms then
        return
    end

    for _, room in ipairs(rooms:GetChildren()) do
        scanRoom(room)
    end
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

    local function enable(value)
        if value == "Doors" then doors = true
        elseif value == "Drawers" then drawers = true
        elseif value == "Closets" then closets = true
        elseif value == "Chest" then chest = true
        elseif value == "LockedChest" then lockedChest = true
        elseif value == "Vent Gate" then ventGate = true
        elseif value == "Lever" then lever = true
        elseif value == "All" then
            doors = true
            drawers = true
            closets = true
            chest = true
            lockedChest = true
            ventGate = true
            lever = true
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
            if selected.All == true then
                doors = true
                drawers = true
                closets = true
                chest = true
                lockedChest = true
                ventGate = true
                lever = true
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

    setKind("Doors", doors)
    setKind("Drawers", drawers)
    setKind("Closets", closets)
    clearKind("Chest")
    clearKind("VentGate")
    clearKind("Lever")

    if chest or lockedChest or ventGate or lever then
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
    Hotel.GoldLevel = goldLevel or 1

    clearKind("Key")
    clearKind("Gold")
    clearKind("Bandage")
    clearKind("Smoothie")

    if key or goldLevel ~= nil or bandage or smoothie then
        scanAll()
    end
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

local function createUI()
    Tab = Core:Tab({
        Name = "Hotel",
        Icon = "building-2",
        Type = "Grid",
    })

    if not Tab then
        return false
    end

    local gameSection = Tab:Section({
        Title = "Game",
        Column = 1,
        Icon = "joystick",
    })

    if not gameSection then
        return false
    end

    Elements.AutoInteract = gameSection:Dropdown({
        Name = "Auto Interact",
        Flag = "Hotel_AutoInteract",
        Options = {},
        MultiSelect = true,
        MaxSelect = 8,
        Default = {},
        Search = true,
        Callback = function()
        end,
    })

    Elements.AutoLoot = gameSection:Dropdown({
        Name = "Auto Loot",
        Flag = "Hotel_AutoLoot",
        Options = {},
        MultiSelect = true,
        MaxSelect = 8,
        Default = {},
        Search = true,
        Callback = function()
        end,
    })

    local visualPages = Tab:MultiSection({
        Pages = { "Visual", "Settings" },
        Column = 2,
        Icon = "eye",
    })

    local visualPage = visualPages:Page("Visual")
    local settingsPage = visualPages:Page("Settings")

    Elements.Interactables = visualPage:ValueDropdown({
        Name = "Interactables",
        Flag = "Hotel_Interactables",
        Options = {
            "Doors",
            "Drawers",
            "Closets",
            "Chest",
            "LockedChest",
            "Vent Gate",
            "Lever",
            "All",
        },
        MultiSelect = true,
        MaxSelect = 8,
        Default = {},
        Search = true,
        Callback = function(selected)
            applyInteractables(selected)
        end,
    })

    Elements.Items = visualPage:ValueDropdown({
        Name = "Items",
        Flag = "Hotel_Items",
        Options = {
            "Key",
            "Gold",
            "Bandage",
            "Smoothie",
            "Flashlight",
            "Tip Jar",
        },
        Values = {
            Gold = {
                Min = 1,
                Max = 6,
                Default = 1,
            },
        },
        MultiSelect = true,
        MaxSelect = 4,
        Default = {},
        Search = true,
        Callback = function(selected)
            applyItems(selected)
        end,
    })

    Elements.DisplayName = settingsPage:Toggle({
        Name = "Display Name",
        Flag = "Hotel_DisplayName",
        Default = true,
        Callback = function(value)
            Display.Name = value
            refreshLabels()
        end,
    })

    Elements.DisplayDistance = settingsPage:Toggle({
        Name = "Display Distance",
        Flag = "Hotel_DisplayDistance",
        Default = false,
        Callback = function(value)
            Display.Distance = value
            refreshLabels()
        end,
    })

    for _, kind in ipairs({"Doors", "Drawers", "Closets", "Key", "Gold", "Chest", "Bandage", "Smoothie", "VentGate", "Lever", "Rush"}) do
        Elements[kind .. "Color"] = settingsPage:ColorPicker({
            Name = kind .. " ESP Color",
            Flag = "Hotel_" .. kind .. "Color",
            Default = Colors[kind],
            Callback = function(value)
                Colors[kind] = value
                for object, entry in pairs(ESP[kind]) do
                    for _, highlight in ipairs(entry.Highlights) do
                        highlight.FillColor = value
                        highlight.OutlineColor = value
                    end
                    local label = entry.Label and entry.Label:FindFirstChild("Text")
                    if label then
                        label.TextColor3 = value
                    end
                end
            end,
        })
    end

    local entityPages = Tab:MultiSection({
        Pages = { "Entity", "Notifications", "Anti" },
        Column = 3,
        Icon = "shield",
    })

    local entityPage = entityPages:Page("Entity")

    Elements.Entities = entityPage:Dropdown({
        Name = "Entities",
        Flag = "Hotel_Entities",
        Options = {
            "Rush",
            "Ambush",
        },
        MultiSelect = true,
        MaxSelect = 2,
        Default = {},
        Search = true,
        Callback = function(selected)
            local rush = false
            local ambush = false
            if type(selected) == "table" then
                if #selected > 0 then
                    for _, value in ipairs(selected) do
                        if value == "Rush" then rush = true end
                        if value == "Ambush" then ambush = true end
                    end
                else
                    rush = selected.Rush == true
                    ambush = selected.Ambush == true
                end
            elseif selected == "Rush" then
                rush = true
            elseif selected == "Ambush" then
                ambush = true
            end
            Enabled.Rush = rush
            Enabled.Ambush = ambush
            scanEntities()
        end,
    })

    entityPage:Label({
        Text = "Entity ESP",
    })

    local notificationsPage = entityPages:Page("Notifications")

    Elements.NotificationEntities = notificationsPage:Dropdown({
        Name = "Entities",
        Flag = "Hotel_NotificationEntities",
        Options = {
            "Rush",
            "Ambush",
        },
        MultiSelect = true,
        MaxSelect = 2,
        Default = {},
        Search = true,
        Callback = function()
        end,
    })

    Elements.NotifyEntities = notificationsPage:Toggle({
        Name = "Notify Entities",
        Flag = "Hotel_NotifyEntities",
        Default = false,
        Callback = function()
        end,
    })

    entityPages:Page("Anti"):Label({
        Text = "Anti features.",
    })

    return true
end

local function setupConnections()
    local rooms = getRooms()

    if rooms then
        hookRooms(rooms)
    end

    local oldContainer = workspace:FindFirstChild("JustXDoors_HotelESP")
    if oldContainer then
        pcall(function()
            oldContainer:Destroy()
        end)
    end

    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("BillboardGui") and object.Name == "JustXDoorsESPLabel" then
            pcall(function()
                object:Destroy()
            end)
        end
    end

    connect(workspace.ChildAdded, function(object)
        if object.Name == "CurrentRooms" then
            task.defer(function()
                hookRooms(object)
            end)
        elseif object.Name == "RushMoving" then
            task.defer(function()
                scanEntities()
            end)
        end
    end)

    connect(Players.LocalPlayer:GetAttributeChangedSignal("CurrentRoom"), function()
        refreshRoomVisibility()
    end)

    connect(RunService.Heartbeat, function(dt)
        ScanTimer += dt

        if ScanTimer < 0.35 then
            return
        end

        ScanTimer = 0

        if Enabled.Doors or Enabled.Drawers or Enabled.Closets or Enabled.Key or Enabled.Gold or Enabled.Chest
            or Enabled.Bandage or Enabled.Smoothie or Enabled.VentGate or Enabled.Lever then
            scanAll()
            refreshLabels()
        end
        if Enabled.Rush then
            scanEntities()
        end
    end)
end

function Hotel:Init(core)
    if self.Initialized then
        return self
    end

    if type(core) ~= "table" then
        warn("[JustXDoors Hotel] Core is missing.")
        return self
    end

    Core = core

    local ok, result = pcall(createUI)

    if not ok or not result then
        warn("[JustXDoors Hotel] Failed to create UI: " .. tostring(result))
        return self
    end

    setupConnections()

    self.Initialized = true
    return self
end

function Hotel:Destroy()
    clearKind("Doors")
    clearKind("Drawers")
    clearKind("Closets")
    clearKind("Key")
    clearKind("Gold")
    clearKind("Chest")
    clearKind("Bandage")
    clearKind("Smoothie")
    clearKind("Flashlight")
    clearKind("TipJar")
    clearKind("VentGate")
    clearKind("Lever")
    clearKind("Rush")
    clearKind("Ambush")
    table.clear(NotifiedEntities)
    if HighlightContainer then
        pcall(function()
            HighlightContainer:Destroy()
        end)
        HighlightContainer = nil
    end
    table.clear(RoomScanQueued)
    disconnectAll()

    Enabled.Doors = false
    Enabled.Drawers = false
    Enabled.Closets = false
    Enabled.Key = false
    Enabled.Gold = false
    Enabled.Chest = false
    Enabled.LockedChest = false
    Enabled.Bandage = false
    Enabled.Smoothie = false
    Enabled.Flashlight = false
    Enabled.TipJar = false
    Enabled.VentGate = false
    Enabled.Lever = false
    Enabled.Rush = false
    Enabled.Ambush = false

    table.clear(Elements)
    Tab = nil
    Core = nil
    self.Initialized = false
end

return Hotel
