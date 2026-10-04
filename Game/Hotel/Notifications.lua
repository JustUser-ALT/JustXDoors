local Notifications = {}

local Core
local Elements
local Connection
local HeartbeatConnection
local NotifiedEntities = {}
local LastNotifiedAt = {}
local NOTIFICATION_DEBOUNCE = 1.5

local Aliases = {
    RushMoving = "Rush",
    AmbushMoving = "Ambush",
    ["RNIUSHCG=="] = "Glitch Rush",
    AR0xMBUSH = "Glitch Ambush",
    SCJVEREECH = "Glitch Screech",
    GlitchScreech = "Glitch Screech",
    ["RNIUSHCg=="] = "Glitch Rush",
    Eyes = "Eyes",
    SallyLingering = "Sally",
    SallyMoving = "Sally",
    SideroomDupe = "Dupe",
    SeekMovingNewClone = "Seek",
    FigureRig = "Figure",
    Screech = "Screech",
}

local function selected(value, name)
    if type(value) == "table" then
        if #value > 0 then return table.find(value, name) ~= nil end
        return value[name] == true
    end
    return value == name
end

local function notifyEntity(entity)
    if not entity or NotifiedEntities[entity] then return end
    if not Elements or not Elements.NotifyEntities or not Elements.NotifyEntities:Get() then return end

    local alias = Aliases[entity.Name]
    if not alias then return end

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
            or "Find a hiding spot."

        Core:Notify({
            Title = "Entity '" .. alias .. "' has spawned.",
            Desc = desc,
            Type = "Warning",
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
        if Aliases[object.Name] then
            notifyEntity(object)
        end
    end
end

function Notifications:Init(context)
    Core = context and context.Core
    Elements = context and context.Elements

    if Connection then pcall(function() Connection:Disconnect() end) end
    if HeartbeatConnection then pcall(function() HeartbeatConnection:Disconnect() end) end

    Connection = workspace.DescendantAdded:Connect(function(object)
        local valid = false

        if object.Name == "Eyes" then
            valid = object.Parent == workspace
        elseif object.Name == "RushMoving"
            or object.Name == "AmbushMoving"
            or object.Name == "RNIUSHCG=="
            or object.Name == "AR0xMBUSH"
            or object.Name == "RNIUSHCg=="
        then
            valid = object.Parent == workspace
        elseif object.Name == "Screech" or object.Name == "SCJVEREECH" or object.Name == "GlitchScreech" then
            local camera = workspace:FindFirstChild("Camera")
            valid = object.Name == "Screech" and camera ~= nil and object.Parent == camera
                or object.Name ~= "Screech" and (object:IsA("Model") or object:IsA("BasePart"))
        elseif object.Name == "SallyLingering" or object.Name == "SallyMoving" then
            valid = object.Parent == workspace
        elseif Aliases[object.Name] then
            valid = object:IsA("Model") or object:IsA("BasePart")
        end

        if valid then
            task.defer(function()
                notifyEntity(object)
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
