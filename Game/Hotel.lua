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
}

local Display = {
    Name = true,
    Distance = false,
}

local Colors = {
    Doors = Color3.fromRGB(255, 200, 50),
    Drawers = Color3.fromRGB(255, 170, 70),
    Closets = Color3.fromRGB(190, 120, 255),
    Key = Color3.fromRGB(50, 220, 255),
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
            local number = value:match("%d+")
            if number then
                return number
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

            text[#text + 1] = "Doors • " .. getDoorNumber(roomObject)
        else
            text[#text + 1] = kind == "Key" and "Key" or kind
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

local function addHighlight(entry, object, part, kind)
    local highlight = Instance.new("Highlight")
    highlight.Name = "JustXDoorsESP"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Colors[kind]
    highlight.OutlineColor = Colors[kind]
    highlight.FillTransparency = 0.55
    highlight.OutlineTransparency = 0
    highlight.Adornee = part
    highlight.Parent = part

    entry.Highlights[#entry.Highlights + 1] = highlight
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

    if kind == "Doors" then
        local parts = {}

        for _, child in ipairs(object:GetDescendants()) do
            if child:IsA("BasePart") and child.Name == "Door" then
                parts[#parts + 1] = child
            end
        end

        if #parts == 0 then
            for _, child in ipairs(object:GetDescendants()) do
                if child:IsA("BasePart") then
                    parts[#parts + 1] = child
                end
            end
        end

        for _, part in ipairs(parts) do
            addHighlight(entry, object, part, kind)
        end
    else
        addHighlight(entry, object, object:IsA("BasePart") and object or getPart(object), kind)
    end

    updateLabel(kind, object, entry)

    object.Destroying:Once(function()
        clearEntry(kind, object)
    end)
end

local function hasDrawerContainer(object)
    return object and object:FindFirstChild("DrawerContainer", true) ~= nil
end

local function scanRoom(room)
    if not room or not room.Parent then
        return
    end

    local assets = room:FindFirstChild("Assets")

    if ESP.Doors and room:FindFirstChild("Door") then
        addObject("Doors", room.Door, room)
    end

    if assets then
        if ESP.Drawers then
            for _, object in ipairs(assets:GetChildren()) do
                if (object.Name == "Dresser" or object.Name == "Table")
                    and hasDrawerContainer(object)
                then
                    addObject("Drawers", object, room)
                end
            end
        end

        if ESP.Closets then
            for _, object in ipairs(assets:GetChildren()) do
                if object.Name == "Wardrobe" then
                    addObject("Closets", object, room)
                end
            end
        end
    end

    if ESP.Key then
        for _, object in ipairs(room:GetDescendants()) do
            if object.Name == "KeyObtain"
                and (object:IsA("Model") or object:IsA("BasePart"))
            then
                addObject("Key", object, room)
            end
        end
    end
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

    if type(selected) == "table" then
        for _, value in ipairs(selected) do
            if value == "Doors" then
                doors = true
            elseif value == "Drawers" then
                drawers = true
            elseif value == "Closets" then
                closets = true
            end
        end
    elseif selected == "Doors" then
        doors = true
    elseif selected == "Drawers" then
        drawers = true
    elseif selected == "Closets" then
        closets = true
    end

    ESP.Doors = doors
    ESP.Drawers = drawers
    ESP.Closets = closets

    setKind("Doors", doors)
    setKind("Drawers", drawers)
    setKind("Closets", closets)
end

local function applyItems(selected)
    local key = false

    if type(selected) == "table" then
        for _, value in ipairs(selected) do
            if value == "Key" then
                key = true
            end
        end
    elseif selected == "Key" then
        key = true
    end

    ESP.Key = key

    if key then
        scanAll()
    else
        clearKind("Key")
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

    Elements.Interactables = visualPage:Dropdown({
        Name = "Interactables",
        Flag = "Hotel_Interactables",
        Options = {
            "Doors",
            "Drawers",
            "Closets",
        },
        MultiSelect = true,
        MaxSelect = 3,
        Default = {},
        Search = true,
        Callback = function(selected)
            applyInteractables(selected)
        end,
    })

    Elements.Items = visualPage:Dropdown({
        Name = "Items",
        Flag = "Hotel_Items",
        Options = {
            "Key",
        },
        MultiSelect = true,
        MaxSelect = 20,
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

    local entityPages = Tab:MultiSection({
        Pages = { "Entity", "Anti" },
        Column = 3,
        Icon = "shield",
    })

    entityPages:Page("Entity"):Label({
        Text = "Entity features.",
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
        end
    end)

    connect(RunService.Heartbeat, function(dt)
        ScanTimer += dt

        if ScanTimer < 0.35 then
            return
        end

        ScanTimer = 0

        if ESP.Doors or ESP.Drawers or ESP.Closets or ESP.Key then
            scanAll()
            refreshLabels()
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
    disconnectAll()

    ESP.Doors = false
    ESP.Drawers = false
    ESP.Closets = false
    ESP.Key = false

    table.clear(Elements)
    Tab = nil
    Core = nil
    self.Initialized = false
end

return Hotel
