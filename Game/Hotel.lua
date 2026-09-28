--[[
    JustXDoors — Game/Hotel/Hotel.lua

    Main tab sections (Hotel floor):
        Column 1 — Game   (left tabbox: Game | Bypass)
        Column 2 — Visual (MultiSection: Visual | Entity)
        Column 3 — Notifications

    ESP approach for Doors:
        Workspace.CurrentRooms["N"].Door.Door is a BasePart.
        We use Highlight instances (SelectionBox is too noisy for parts
        inside a Model) — one Highlight per Door part, created as rooms
        load. Same approach for Keys (KeyObtain parts anywhere in rooms).

    MultiSelect ESP dropdown lets the player pick which object types
    to highlight. On change we create/destroy Highlights accordingly.
]]

local Hotel = {}

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core
local Tab
local Connections = {}
local Elements    = {}

------------------------------------------------------
-- STATE
------------------------------------------------------

-- ESP: active Highlight instances keyed by the part they track
local Highlights = {
    Doors = {},   -- [BasePart] = Highlight
    Keys  = {},   -- [BasePart] = Highlight
}

-- Which ESP categories are currently enabled (set by Dropdown callback)
local ESPEnabled = {
    Doors = false,
    Keys  = false,
}

local ESPColors = {
    Doors = Color3.fromRGB(255, 200, 50),
    Keys  = Color3.fromRGB(50, 220, 255),
}

------------------------------------------------------
-- HELPERS
------------------------------------------------------

local function connect(signal, cb)
    local c = signal:Connect(cb)
    table.insert(Connections, c)
    return c
end

local function disconnectAll()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    table.clear(Connections)
end

local function getCurrentRooms()
    return workspace:FindFirstChild("CurrentRooms")
end

------------------------------------------------------
-- ESP — Highlight helpers
------------------------------------------------------

local function makeHighlight(part, color)
    local hl = Instance.new("Highlight")
    hl.FillColor        = color
    hl.OutlineColor     = color
    hl.FillTransparency = 0.55
    hl.Adornee          = part
    hl.Parent           = part  -- parented to the part so it auto-cleans when part is removed
    return hl
end

local function removeHighlight(tbl, part)
    local hl = tbl[part]
    if hl then
        pcall(function() hl:Destroy() end)
        tbl[part] = nil
    end
end

local function clearHighlights(tbl)
    for part, hl in pairs(tbl) do
        pcall(function() hl:Destroy() end)
    end
    table.clear(tbl)
end

------------------------------------------------------
-- DOOR ESP
-- Door part path: CurrentRooms["N"].Door.Door
-- We iterate CurrentRooms children and look for a Model
-- named "Door" that contains a BasePart also named "Door".
------------------------------------------------------

local function addDoorESP(doorPart)
    if Highlights.Doors[doorPart] then return end
    local hl = makeHighlight(doorPart, ESPColors.Doors)
    Highlights.Doors[doorPart] = hl
    -- Auto-clean if the part is removed (door opened / room unloaded)
    doorPart.Destroying:Once(function()
        Highlights.Doors[doorPart] = nil
    end)
end

local function scanDoorsInRoom(room)
    local doorModel = room:FindFirstChild("Door")
    if not doorModel then return end
    local doorPart = doorModel:FindFirstChild("Door")
    if doorPart and doorPart:IsA("BasePart") then
        addDoorESP(doorPart)
    end
end

local function enableDoorESP()
    local rooms = getCurrentRooms()
    if not rooms then return end
    for _, room in rooms:GetChildren() do
        pcall(scanDoorsInRoom, room)
    end
end

local function disableDoorESP()
    clearHighlights(Highlights.Doors)
end

------------------------------------------------------
-- KEY ESP
-- Keys can be inside DrawerContainers, on shelves, floor, etc.
-- Any BasePart named "KeyObtain" anywhere in CurrentRooms.
------------------------------------------------------

local function addKeyESP(part)
    if Highlights.Keys[part] then return end
    local hl = makeHighlight(part, ESPColors.Keys)
    Highlights.Keys[part] = hl
    part.Destroying:Once(function()
        Highlights.Keys[part] = nil
    end)
end

local function scanKeysInRoom(room)
    for _, obj in room:GetDescendants() do
        if obj.Name == "KeyObtain" and obj:IsA("BasePart") then
            addKeyESP(obj)
        end
    end
end

local function enableKeyESP()
    local rooms = getCurrentRooms()
    if not rooms then return end
    for _, room in rooms:GetChildren() do
        pcall(scanKeysInRoom, room)
    end
end

local function disableKeyESP()
    clearHighlights(Highlights.Keys)
end

------------------------------------------------------
-- ESP apply/remove based on dropdown selection
------------------------------------------------------

local function applyESP(selected)
    -- selected is a table like {"Doors", "Keys"} (MultiSelect)
    local wantDoors = false
    local wantKeys  = false

    for _, v in ipairs(selected) do
        if v == "Doors" then wantDoors = true end
        if v == "Keys"  then wantKeys  = true end
    end

    -- Doors
    if wantDoors and not ESPEnabled.Doors then
        ESPEnabled.Doors = true
        enableDoorESP()
    elseif not wantDoors and ESPEnabled.Doors then
        ESPEnabled.Doors = false
        disableDoorESP()
    end

    -- Keys
    if wantKeys and not ESPEnabled.Keys then
        ESPEnabled.Keys = true
        enableKeyESP()
    elseif not wantKeys and ESPEnabled.Keys then
        ESPEnabled.Keys = false
        disableKeyESP()
    end
end

------------------------------------------------------
-- UI
------------------------------------------------------

local function createUI()
    Tab = Core:Tab({ Name = "Hotel", Icon = "building-2", Type = "Grid" })
    if not Tab then return false end

    --------------------------------------------------
    -- Column 1 — Game | Bypass  (left tabbox via MultiSection)
    --------------------------------------------------
    local msGame = Tab:MultiSection({
        Pages  = { "Game", "Bypass" },
        Column = 1,
        Icon   = "joystick",
    })

    local gamePage   = msGame:Page("Game")
    local bypassPage = msGame:Page("Bypass")

    -- Game page — empty for now
    gamePage:Label({ Text = "Game features coming soon." })

    -- Bypass page — empty for now
    bypassPage:Label({ Text = "Bypass features coming soon." })

    --------------------------------------------------
    -- Column 2 — Visual | Entity  (MultiSection)
    --------------------------------------------------
    local msVisual = Tab:MultiSection({
        Pages  = { "Visual", "Entity" },
        Column = 2,
        Icon   = "eye",
    })

    local visualPage = msVisual:Page("Visual")
    local entityPage = msVisual:Page("Entity")

    -- Visual page — empty for now
    visualPage:Label({ Text = "Visual features coming soon." })

    -- Entity page — ESP dropdown
    Elements.ESPDropdown = entityPage:Dropdown({
        Name        = "ESP",
        Flag        = "Hotel_ESP",
        Options     = { "Doors", "Keys" },
        MultiSelect = true,
        Default     = {},
        Tooltip     = "Select object types to highlight.",
        Callback    = function(selected)
            applyESP(selected)
        end,
    })

    --------------------------------------------------
    -- Column 3 — Notifications
    --------------------------------------------------
    local notifSec = Tab:Section({
        Title  = "Notifications",
        Column = 3,
        Icon   = "bell",
    })

    -- Empty for now
    notifSec:Label({ Text = "Notification features coming soon." })

    return true
end

------------------------------------------------------
-- CONNECTIONS
------------------------------------------------------

local function setupConnections()
    local rooms = getCurrentRooms()
    if not rooms then return end

    -- Watch for new rooms loading (each new child = new floor room)
    connect(rooms.ChildAdded, function(room)
        task.defer(function()
            -- Door ESP
            if ESPEnabled.Doors then
                pcall(scanDoorsInRoom, room)
            end

            -- Key ESP — also watch for late-replicating KeyObtain parts
            if ESPEnabled.Keys then
                pcall(scanKeysInRoom, room)

                -- Some keys appear after room loads (spawned from drawers etc.)
                connect(room.DescendantAdded, function(obj)
                    if ESPEnabled.Keys
                        and obj.Name == "KeyObtain"
                        and obj:IsA("BasePart")
                    then
                        task.defer(function()
                            if obj.Parent then addKeyESP(obj) end
                        end)
                    end
                end)
            end
        end)
    end)
end

------------------------------------------------------
-- LIFECYCLE
------------------------------------------------------

function Hotel:Init(core)
    if self.Initialized then return self end
    if type(core) ~= "table" then
        warn("[JustXDoors Hotel] Core is missing.")
        return self
    end

    Core = core

    if not createUI() then
        warn("[JustXDoors Hotel] Failed to create UI.")
        return self
    end

    setupConnections()
    self.Initialized = true

    return self
end

function Hotel:Destroy()
    clearHighlights(Highlights.Doors)
    clearHighlights(Highlights.Keys)
    ESPEnabled = { Doors=false, Keys=false }
    disconnectAll()
    Elements = {}
    Tab  = nil
    Core = nil
    self.Initialized = false
end

return Hotel
