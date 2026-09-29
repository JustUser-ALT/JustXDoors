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
    Rush = Color3.fromRGB(255, 70, 70),
}

local ScanTimer = 0
local RoomsConnection

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
    proxy.Parent = object

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
    highlight.FillTransparency = 0.55
    highlight.OutlineTransparency = 0
    highlight.Adornee = adornee
    highlight.Parent = object

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

    local assets = room:FindFirstChild("Assets")

    if Enabled.Doors and room:FindFirstChild("Door") and isRoomVisible("Doors", room) then
        addObject("Doors", room.Door, room)
    end

    if assets and isRoomVisible("Drawers", room) then
        for _, object in ipairs(assets:GetDescendants()) do
            if Enabled.Drawers and (object.Name == "Dresser" or object.Name == "Table" or object.Name == "Rolltop_Desk")
                and (object.Name == "Rolltop_Desk" or hasDrawerContainer(object))
                and (object:IsA("Model") or object:IsA("BasePart"))
            then
                addObject("Drawers", object, room)
            end

            if Enabled.Closets and object.Name == "Wardrobe"
                and (object:IsA("Model") or object:IsA("BasePart"))
            then
                addObject("Closets", object, room)
            end

            if Enabled.Chest and (object.Name == "ChestBox" or object.Name == "ChestBoxLocked")
                and (object:IsA("Model") or object:IsA("BasePart"))
            then
                addObject("Chest", object, room)
            elseif Enabled.LockedChest and object.Name == "LockedChestBox"
                and (object:IsA("Model") or object:IsA("BasePart"))
            then
                addObject("Chest", object, room)
            end
        end
    end

    if Enabled.Key and isRoomVisible("Key", room) then
        for _, object in ipairs(room:GetDescendants()) do
            if object.Name == "KeyObtain"
                and (object:IsA("Model") or object:IsA("BasePart"))
            then
                addObject("Key", object, room)
            end
        end
    end

    if Enabled.Gold and isRoomVisible("Gold", room) then
        local gold = room:FindFirstChild("Assets")
        if gold then
            for _, pile in ipairs(gold:GetDescendants()) do
                if pile.Name == "GoldPile" and (pile:IsA("Model") or pile:IsA("BasePart")) then
                    for _, levelObject in ipairs(pile:GetChildren()) do
                        local level = tonumber(levelObject.Name)
                        if level and level >= (Hotel.GoldLevel or 1) then
                            if levelObject:IsA("Model") or levelObject:IsA("BasePart") then
                                addObject("Gold", levelObject, room)
                            end
                        end
                    end
                end
            end
        end
    end
end

local function clearEntityESP()
    clearKind("Rush")
end

local function scanEntities()
    if not Enabled.Rush then
        clearEntityESP()
        return
    end

    local entity = workspace:FindFirstChild("RushMoving")
    if not entity then
        clearEntityESP()
        return
    end

    local root = entity:FindFirstChild("RushNew") or entity.PrimaryPart or entity:FindFirstChildWhichIsA("BasePart", true)
    if not root then
        return
    end

    entity.PrimaryPart = root

    local humanoid = entity:FindFirstChild("HighlightHumanoid")
    if not humanoid then
        humanoid = Instance.new("Humanoid")
        humanoid.Name = "HighlightHumanoid"
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.Parent = entity
    end

    if root:IsA("BasePart") then
        root.Transparency = 0.999
        root.Material = Enum.Material.Glass
    end

    addObject("Rush", entity, nil)
end

local function refreshRoomVisibility()
    local current = tonumber(Players.LocalPlayer:GetAttribute("CurrentRoom"))
    if not current then return end

    for kind, objects in pairs(ESP) do
        for object, entry in pairs(objects) do
            local room = entry.Room
            if not room or not room.Parent or not isRoomVisible(kind, room) then
                clearEntry(kind, object)
            end
        end
    end

    scanAll()
end

local function scanAll()
    local rooms = getRooms()

    if not rooms then
        return
    end

    for _, room in ipairs(rooms:GetChildren()) do
        scanRoom(room)
    end
end

local function clearKind(kind)
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

    if type(selected) == "table" then
        if #selected > 0 then
            for _, value in ipairs(selected) do
                if value == "Doors" then doors = true
                elseif value == "Drawers" then drawers = true
                elseif value == "Closets" then closets = true
                elseif value == "Chest" then chest = true
                elseif value == "LockedChest" then lockedChest = true
                elseif value == "All" then
                    chest = true
                    lockedChest = true
                end
            end
        else
            doors = selected.Doors ~= nil
            drawers = selected.Drawers ~= nil
            closets = selected.Closets ~= nil
            chest = selected.Chest ~= nil
            lockedChest = selected.LockedChest ~= nil
            if selected.All ~= nil then
                chest = true
                lockedChest = true
            end
        end
    elseif selected == "Doors" then doors = true
    elseif selected == "Drawers" then drawers = true
    elseif selected == "Closets" then closets = true
    elseif selected == "Chest" then chest = true
    elseif selected == "LockedChest" then lockedChest = true
    elseif selected == "All" then chest = true; lockedChest = true end

    Enabled.Doors = doors
    Enabled.Drawers = drawers
    Enabled.Closets = closets
    Enabled.Chest = chest
    Enabled.LockedChest = lockedChest

    setKind("Doors", doors)
    setKind("Drawers", drawers)
    setKind("Closets", closets)

    if chest or lockedChest then
        scanAll()
    else
        clearKind("Chest")
    end
end

local function applyItems(selected)
    local key = false
    local goldLevel = nil

    if type(selected) == "table" then
        key = selected.Key ~= nil
        goldLevel = tonumber(selected.Gold)
    elseif selected == "Key" then
        key = true
    elseif selected == "Gold" then
        goldLevel = 1
    end

    Enabled.Key = key
    Enabled.Gold = goldLevel ~= nil
    Hotel.GoldLevel = goldLevel or 1

    if key then
        scanAll()
    else
        clearKind("Key")
    end

    if goldLevel ~= nil then
        scanAll()
    else
        clearKind("Gold")
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
        task.defer(function()
            scanRoom(room)
        end)
    end)

    table.insert(Connections, RoomsConnection)

    connect(rooms.DescendantAdded, function(object)
        if object.Name == "KeyObtain"
            or object.Name == "Door"
            or object.Name == "Dresser"
            or object.Name == "Table"
            or object.Name == "Wardrobe"
            or object.Name == "DrawerContainer"
            or object.Name == "Stinker"
        then
            task.defer(function()
                if object.Parent then
                    scanAll()
                end
            end)
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

    local gamePages = Tab:MultiSection({
        Pages = { "Game", "Bypass" },
        Column = 1,
        Icon = "joystick",
    })

    gamePages:Page("Game"):Label({
        Text = "Hotel game features.",
    })

    gamePages:Page("Bypass"):Label({
        Text = "Hotel bypass features.",
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
            "All",
        },
        MultiSelect = true,
        MaxSelect = 6,
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
        },
        Values = {
            Gold = {
                Min = 1,
                Max = 6,
                Default = 1,
            },
        },
        MultiSelect = true,
        MaxSelect = 2,
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

    for _, kind in ipairs({"Doors", "Drawers", "Closets", "Key", "Gold", "Chest", "Rush"}) do
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
        Pages = { "Entity", "Anti" },
        Column = 3,
        Icon = "shield",
    })

    local entityPage = entityPages:Page("Entity")

    Elements.Entities = entityPage:Dropdown({
        Name = "Entities",
        Flag = "Hotel_Entities",
        Options = {
            "Rush",
        },
        MultiSelect = true,
        MaxSelect = 1,
        Default = {},
        Search = true,
        Callback = function(selected)
            local rush = false
            if type(selected) == "table" then
                if #selected > 0 then
                    for _, value in ipairs(selected) do
                        if value == "Rush" then rush = true end
                    end
                else
                    rush = selected.Rush ~= nil
                end
            elseif selected == "Rush" then
                rush = true
            end
            Enabled.Rush = rush
            if rush then
                scanEntities()
            else
                clearKind("Rush")
            end
        end,
    })

    entityPage:Label({
        Text = "Entity ESP",
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

        if Enabled.Doors or Enabled.Drawers or Enabled.Closets or Enabled.Key or Enabled.Gold or Enabled.Chest then
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
    clearKind("Rush")
    disconnectAll()

    Enabled.Doors = false
    Enabled.Drawers = false
    Enabled.Closets = false
    Enabled.Key = false
    Enabled.Gold = false
    Enabled.Chest = false
    Enabled.LockedChest = false
    Enabled.Rush = false

    table.clear(Elements)
    Tab = nil
    Core = nil
    self.Initialized = false
end

return Hotel
