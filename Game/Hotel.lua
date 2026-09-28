local Hotel = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Core
local Tab
local Connections = {}
local Elements = {}

local Highlights = {
    Doors = {},
    Keys = {},
}

local Labels = {
    Doors = {},
    Keys = {},
}

local DoorRooms = {}

local ESPEnabled = {
    Doors = false,
    Keys = false,
}

local DisplayName = true
local DisplayDistance = false
local ScanTimer = 0

local ESPColors = {
    Doors = Color3.fromRGB(255, 200, 50),
    Keys = Color3.fromRGB(50, 220, 255),
}

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Connections, connection)
    return connection
end

local function disconnectAll()
    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(Connections)
end

local function getRooms()
    return workspace:FindFirstChild("CurrentRooms")
end

local function getPlayerRoot()
    local player = Players.LocalPlayer
    local character = player and player.Character

    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getDisplayPart(object)
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
    local door = room:FindFirstChild("Door")
    local sign = door and door:FindFirstChild("Sign")
    local stinker = sign and sign:FindFirstChild("Stinker")

    if stinker then
        local ok, value = pcall(function()
            return stinker.Text
        end)

        if ok and type(value) == "string" and value ~= "" then
            local digits = value:match("%d+")

            if digits then
                return digits
            end
        end
    end

    local roomNumber = tonumber(room.Name)

    if roomNumber then
        return string.format("%04d", roomNumber + 1)
    end

    return "????"
end

local function makeHighlight(object, color)
    local highlight = Instance.new("Highlight")

    highlight.Name = "JustXDoorsESP"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.55
    highlight.OutlineTransparency = 0
    highlight.Adornee = object
    highlight.Parent = object

    return highlight
end

local function getESPText(kind, object)
    local parts = {}

    if DisplayName then
        if kind == "Doors" then
            local room = DoorRooms[object]
            local number = room and getDoorNumber(room) or "????"

            parts[#parts + 1] = "Doors • " .. number
        else
            parts[#parts + 1] = "Key"
        end
    end

    if DisplayDistance then
        local root = getPlayerRoot()
        local target = getDisplayPart(object)

        if root and target then
            local distance = math.floor(
                (root.Position - target.Position).Magnitude + 0.5
            )

            parts[#parts + 1] = tostring(distance)
        end
    end

    return table.concat(parts, " • ")
end

local function removeLabel(tbl, object)
    local gui = tbl[object]

    if gui then
        pcall(function()
            gui:Destroy()
        end)

        tbl[object] = nil
    end
end

local function updateLabel(kind, object)
    local tbl = Labels[kind]

    if not object or not object.Parent then
        removeLabel(tbl, object)
        return
    end

    local text = getESPText(kind, object)
    local target = getDisplayPart(object)
    local gui = tbl[object]

    if not DisplayName and not DisplayDistance then
        if gui then
            gui.Enabled = false
        end

        return
    end

    if not target then
        removeLabel(tbl, object)
        return
    end

    if not gui then
        gui = Instance.new("BillboardGui")

        gui.Name = "JustXDoorsESPLabel"
        gui.AlwaysOnTop = true
        gui.LightInfluence = 0
        gui.MaxDistance = 1000
        gui.Size = UDim2.fromOffset(180, 28)
        gui.StudsOffset = Vector3.new(0, 2.5, 0)
        gui.Adornee = target
        gui.Parent = target

        local label = Instance.new("TextLabel")

        label.Name = "Text"
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextColor3 = ESPColors[kind]
        label.TextStrokeTransparency = 0.35
        label.Parent = gui

        tbl[object] = gui
    else
        gui.Adornee = target
    end

    gui.Enabled = text ~= ""

    local label = gui:FindFirstChild("Text")

    if label then
        label.Text = text
    end
end

local function addDoorESP(doorPart, room)
    if not doorPart or not doorPart:IsA("BasePart") then
        return
    end

    DoorRooms[doorPart] = room

    if not Highlights.Doors[doorPart] then
        Highlights.Doors[doorPart] = makeHighlight(
            doorPart,
            ESPColors.Doors
        )

        doorPart.Destroying:Once(function()
            Highlights.Doors[doorPart] = nil
            DoorRooms[doorPart] = nil
            removeLabel(Labels.Doors, doorPart)
        end)
    end

    updateLabel("Doors", doorPart)
end

local function addKeyESP(key)
    if not key then
        return
    end

    if not key:IsA("BasePart") and not key:IsA("Model") then
        return
    end

    if not Highlights.Keys[key] then
        Highlights.Keys[key] = makeHighlight(
            key,
            ESPColors.Keys
        )

        key.Destroying:Once(function()
            Highlights.Keys[key] = nil
            removeLabel(Labels.Keys, key)
        end)
    end

    updateLabel("Keys", key)
end

local function scanRoom(room)
    if not room or not room.Parent then
        return
    end

    if ESPEnabled.Doors then
        local doorModel = room:FindFirstChild("Door")

        if doorModel then
            local doorPart = doorModel:FindFirstChild("Door", true)

            if doorPart and doorPart:IsA("BasePart") then
                addDoorESP(doorPart, room)
            end
        end
    end

    if ESPEnabled.Keys then
        for _, object in ipairs(room:GetDescendants()) do
            if object.Name == "KeyObtain"
                and (
                    object:IsA("BasePart")
                    or object:IsA("Model")
                )
            then
                addKeyESP(object)
            end
        end
    end
end

local function scanAllRooms()
    local rooms = getRooms()

    if not rooms then
        return
    end

    for _, room in ipairs(rooms:GetChildren()) do
        scanRoom(room)
    end
end

local function clearESP(kind)
    for object, highlight in pairs(Highlights[kind]) do
        pcall(function()
            highlight:Destroy()
        end)

        Highlights[kind][object] = nil

        if kind == "Doors" then
            DoorRooms[object] = nil
        end
    end

    for object, gui in pairs(Labels[kind]) do
        pcall(function()
            gui:Destroy()
        end)

        Labels[kind][object] = nil
    end
end

local function applyESP(selected)
    local wantedDoors = false
    local wantedKeys = false

    if type(selected) == "table" then
        for _, value in ipairs(selected) do
            if value == "Doors" then
                wantedDoors = true
            elseif value == "Key" then
                wantedKeys = true
            end
        end
    elseif selected == "Doors" then
        wantedDoors = true
    elseif selected == "Key" then
        wantedKeys = true
    end

    ESPEnabled.Doors = wantedDoors
    ESPEnabled.Keys = wantedKeys

    if not wantedDoors then
        clearESP("Doors")
    end

    if not wantedKeys then
        clearESP("Keys")
    end

    scanAllRooms()
end

local function refreshAllLabels()
    for object in pairs(Highlights.Doors) do
        if object and object.Parent then
            updateLabel("Doors", object)
        end
    end

    for object in pairs(Highlights.Keys) do
        if object and object.Parent then
            updateLabel("Keys", object)
        end
    end
end

local function hookRooms(rooms)
    if not rooms then
        return
    end

    connect(rooms.ChildAdded, function(room)
        task.defer(function()
            scanRoom(room)
        end)
    end)

    connect(rooms.DescendantAdded, function(object)
        if object.Name == "KeyObtain"
            or object.Name == "Door"
            or object.Name == "Sign"
            or object.Name == "Stinker"
        then
            task.defer(function()
                scanAllRooms()
            end)
        end
    end)

    scanAllRooms()
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

    Elements.ESPDropdown = visualPage:Dropdown({
        Name = "ESP",
        Flag = "Hotel_ESP",
        Options = {
            "Doors",
            "Key",
        },
        MultiSelect = true,
        MaxSelect = 2,
        Default = {},
        Search = true,
        Tooltip = "Select multiple ESP types.",
        Callback = function(selected)
            applyESP(selected)
        end,
    })

    Elements.DisplayName = settingsPage:Toggle({
        Name = "Display Name",
        Flag = "Hotel_DisplayName",
        Default = true,
        Callback = function(value)
            DisplayName = value
            refreshAllLabels()
        end,
    })

    Elements.DisplayDistance = settingsPage:Toggle({
        Name = "Display Distance",
        Flag = "Hotel_DisplayDistance",
        Default = false,
        Callback = function(value)
            DisplayDistance = value
            refreshAllLabels()
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

        if ScanTimer < 0.25 then
            return
        end

        ScanTimer = 0

        if ESPEnabled.Doors or ESPEnabled.Keys then
            scanAllRooms()
            refreshAllLabels()
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
        warn(
            "[JustXDoors Hotel] Failed to create UI: "
            .. tostring(result)
        )

        return self
    end

    setupConnections()

    self.Initialized = true

    return self
end

function Hotel:Destroy()
    clearESP("Doors")
    clearESP("Keys")
    disconnectAll()

    ESPEnabled.Doors = false
    ESPEnabled.Keys = false

    table.clear(Elements)

    Tab = nil
    Core = nil
    self.Initialized = false
end

return Hotel
