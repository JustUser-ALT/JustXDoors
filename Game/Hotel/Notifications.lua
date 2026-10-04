local Notifications = {}

local Core
local Elements
local Connection
local HeartbeatConnection
local NotifiedEntities = {}
local LastNotifiedAt = {}
local NOTIFICATION_DEBOUNCE = 1.5

local EntityAliases = {
    RushMoving = "Rush",
    AmbushMoving = "Ambush",
    ["RNIUSHCG=="] = "Glitch Rush",
    ["RNIUSHCg=="] = "Glitch Rush",
    AR0xMBUSH = "Glitch Ambush",
    SCJVEREECH = "Glitch Screech",
    GlitchScreech = "Glitch Screech",
    Eyes = "Eyes",
    SallyLingering = "Sally",
    SallyMoving = "Sally",
    SideroomDupe = "Dupe",
    SeekMovingNewClone = "Seek",
    FigureRig = "Figure",
    Figure = "Figure",
    FigureRagdoll = "Figure",
    Dread = "Dread",
    Snare = "Snare",
    Screech = "Screech",
    DoorFake = "Dupe",
    FakeDoor = "Dupe",
}

-- The same item set used by Hotel Item ESP.
local ItemAliases = {
    KeyObtain = "Key",
    GoldPile = "Gold",
    Bandage = "Bandage",
    Smoothie = "Smoothie",
    Vitamins = "Vitamins",
    Lighter = "Lighter",
    Candle = "Candle",
    AlarmClock = "Alarm Clock",
    Lockpick = "Lockpick",
    SkeletonKey = "Skeleton Key",
    Shears = "Shears",
    RiftCandle = "Rift Candle",
    RiftSmoothie = "Rift Smoothie",
    RiftJar = "Rift Jar",
    Donut = "Donut",
    Crucifix = "Crucifix",
    SallyToyObtain = "Sally Toy",
    LiveBreakerPolePickup = "Breaker Pole",
    ElectricalKeyObtain = "Electrical Key",
    GlitchCube = "Glitch Cube",
    Flashlight = "Flashlight",
    TipJar = "Tip Jar",
    Battery = "Battery",
}

local EntityOptions = {
    "Rush","Ambush","Glitch Rush","Glitch Ambush","Glitch Screech",
    "Dupe","Eyes","Sally","Seek","Figure","Dread","Snare","Screech",
}

local ItemOptions = {
    "Key","Gold","Bandage","Smoothie","Flashlight","Tip Jar","Vitamins",
    "Lighter","Candle","Alarm Clock","Lockpick","Skeleton Key","Shears",
    "Rift Candle","Rift Smoothie","Rift Jar","Donut","Crucifix","Sally Toy",
    "Electrical Key","Breaker Pole","Battery","Glitch Cube",
}

local function isRoomObject(object)
    if not object or not object.Parent then return false end
    local rooms = workspace:FindFirstChild("CurrentRooms")
    return rooms and object:IsDescendantOf(rooms)
end

local function isEntityObject(object)
    if not object or not object.Parent then return false end
    local name = object.Name

    if name == "RushMoving" or name == "AmbushMoving"
        or name == "RNIUSHCG==" or name == "RNIUSHCg=="
        or name == "AR0xMBUSH" or name == "Eyes"
        or name == "SallyLingering" or name == "SallyMoving"
        or name == "SeekMovingNewClone" or name == "FigureRig"
        or name == "Dread"
    then
        return object.Parent == workspace
            and (object:IsA("Model") or object:IsA("BasePart"))
    end

    if name == "Screech" or name == "SCJVEREECH" or name == "GlitchScreech" then
        local camera = workspace:FindFirstChild("Camera")
        return camera ~= nil and object.Parent == camera
            and (object:IsA("Model") or object:IsA("BasePart"))
    end

    if name == "FigureRig" or name == "Figure" or name == "FigureRagdoll" then
        if not (object:IsA("Model") and object:FindFirstChildOfClass("Humanoid")) then
            return false
        end

        return object:IsDescendantOf(workspace.CurrentRooms)
            or object.Parent == workspace
    end

    if name == "Snare" then
        return isRoomObject(object)
            and (object:IsA("Model") or object:IsA("BasePart"))
    end

    if name == "DoorFake" or name == "FakeDoor" then
        return isRoomObject(object)
            and (object:IsA("Model") or object:IsA("BasePart"))
            and object:FindFirstChild("Hidden") ~= nil
    end

    return false
end

local function selected(value, name)
    if type(value) == "table" then
        if #value > 0 then return table.find(value, name) ~= nil end
        return value[name] == true
    end
    return value == name
end

local function findItemRoot(object, room)
    local root = object
    local parent = object.Parent

    while parent and parent ~= room do
        if parent.Name == object.Name then
            root = parent
        end
        parent = parent.Parent
    end

    return root
end

local function isValidItemObject(item)
    if not item then return false end

    local rooms = workspace:FindFirstChild("CurrentRooms")
    local drops = workspace:FindFirstChild("Drops")

    -- Match Hotel Items ESP for workspace.Drops. Only the actual top-level
    -- Drop is valid; decorative same-name descendants must not notify.
    if drops and item:IsDescendantOf(drops) then
        local root = item
        while root.Parent and root.Parent ~= drops do
            root = root.Parent
        end

        return root == item
    end

    if not isRoomObject(item) then return false end

    local room = nil
    local cursor = item
    while cursor and cursor.Parent and cursor.Parent ~= rooms do
        cursor = cursor.Parent
    end
    if cursor and cursor.Parent == rooms then
        room = cursor
    end
    if not room then return false end

    -- These room items are valid by their exact discovery marker and do not
    -- need the generic ModulePrompt rule used by the normal item set.
    if item.Name == "KeyObtain" or item.Name == "GoldPile"
        or item.Name == "Bandage" or item.Name == "Smoothie"
        or item.Name == "LiveBreakerPolePickup"
    then
        return findItemRoot(item, room) == item
    end

    -- Electrical Key is a special room-100 item in the ESP implementation.
    if item.Name == "ElectricalKeyObtain" then
        return room.Name == "100" and findItemRoot(item, room) == item
    end

    -- Match Hotel Items ESP: nested decorative copies (for example the
    -- Lighter inside a Bookcase) are not real obtainable items. Real room
    -- items expose ModulePrompt and are the root item instance.
    if findItemRoot(item, room) ~= item then return false end
    return item:FindFirstChild("ModulePrompt", true) ~= nil
end

local function notifyItem(item)
    if not item or NotifiedEntities[item] then return end
    if not Elements or not Elements.NotifyEntities or not Elements.NotifyEntities:Get() then return end

    local alias = ItemAliases[item.Name]
    if not alias or not isValidItemObject(item) then return end

    local picked = Elements.NotificationItems and Elements.NotificationItems:Get()
    if not selected(picked, alias) then return end

    local now = os.clock()
    local key = "Item:" .. alias
    if LastNotifiedAt[key] and now - LastNotifiedAt[key] < NOTIFICATION_DEBOUNCE then
        NotifiedEntities[item] = true
        item.Destroying:Once(function() NotifiedEntities[item] = nil end)
        return
    end

    LastNotifiedAt[key] = now
    NotifiedEntities[item] = true

    if Core then
        Core:Notify({
            Title = "Item '" .. alias .. "' found.",
            Desc = alias .. " has spawned.",
            Type = "Info",
            Duration = 5,
        })
    end

    item.Destroying:Once(function()
        NotifiedEntities[item] = nil
    end)
end

local function notifyEntity(entity)
    if not entity or NotifiedEntities[entity] then return end
    if not Elements or not Elements.NotifyEntities or not Elements.NotifyEntities:Get() then return end

    local alias = EntityAliases[entity.Name]
    if not alias or not isEntityObject(entity) then return end

    local picked = Elements.NotificationEntities and Elements.NotificationEntities:Get()
    if not selected(picked, alias) then return end

    local now = os.clock()
    if LastNotifiedAt[alias] and now - LastNotifiedAt[alias] < NOTIFICATION_DEBOUNCE then
        NotifiedEntities[entity] = true
        entity.Destroying:Once(function() NotifiedEntities[entity] = nil end)
        return
    end

    LastNotifiedAt[alias] = now
    NotifiedEntities[entity] = true

    if Core then
        local desc =
            alias == "Sally" and (entity.Name == "SallyLingering"
                and "Sally will spawn in a few rooms."
                or "Sally has spawned.")
            or alias == "Dupe" and "Dupe has spawned."
            or alias == "Eyes" and "Eyes has spawned."
            or alias == "Seek" and "Seek has spawned."
            or alias == "Figure" and "Figure has spawned."
            or alias == "Screech" and "Screech has spawned."
            or alias == "Dread" and "Dread has spawned."
            or alias == "Snare" and "Snare has spawned."
            or alias == "Dupe" and "Dupe has spawned."
            or "Find a hiding spot."

        Core:Notify({
            Title = "Entity '" .. alias .. "' has spawned.",
            Desc = desc,
            Type = "Warn",
            Duration = 5,
        })
    end

    entity.Destroying:Once(function()
        NotifiedEntities[entity] = nil
    end)
end

local function scan()
    if not Elements or not Elements.NotifyEntities or not Elements.NotifyEntities:Get() then
        table.clear(NotifiedEntities)
        return
    end

    for _, object in ipairs(workspace:GetDescendants()) do
        if EntityAliases[object.Name] then
            notifyEntity(object)
        elseif ItemAliases[object.Name] then
            notifyItem(object)
        end
    end
end

function Notifications:Init(context)
    Core = context and context.Core
    Elements = context and context.Elements

    if Connection then pcall(function() Connection:Disconnect() end) end
    if HeartbeatConnection then pcall(function() HeartbeatConnection:Disconnect() end) end

    Connection = workspace.DescendantAdded:Connect(function(object)
        if EntityAliases[object.Name] then
            task.defer(function()
                notifyEntity(object)
            end)
        elseif ItemAliases[object.Name] then
            task.defer(function()
                notifyItem(object)
            end)
        end
    end)

    -- Notifications are event-driven. Do not continuously scan Workspace:
    -- unrelated entity spawns must not cause an old Eyes instance to notify.
    HeartbeatConnection = nil

    task.defer(scan)

    self.Enabled = true
    self.Selected = function() return Elements and Elements.NotificationEntities and Elements.NotificationEntities:Get() end
    return self
end

function Notifications:SetEnabled(value)
    if Elements and Elements.NotifyEntities then
        Elements.NotifyEntities:Set(value == true)
    end
end

function Notifications:SetSelected(value)
    if Elements and Elements.NotificationEntities then
        Elements.NotificationEntities:Set(value)
    end
end

function Notifications:Scan()
    scan()
end

function Notifications:Destroy()
    if Connection then pcall(function() Connection:Disconnect() end) end
    if HeartbeatConnection then pcall(function() HeartbeatConnection:Disconnect() end) end
    Connection = nil
    HeartbeatConnection = nil
    table.clear(NotifiedEntities)
    table.clear(LastNotifiedAt)
    Core = nil
    Elements = nil
end

return Notifications
