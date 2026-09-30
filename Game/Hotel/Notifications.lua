local Notifications = {}

local Core
local Elements
local Connection
local HeartbeatConnection
local NotifiedEntities = {}

local Aliases = {
    RushMoving = "Rush",
    AmbushMoving = "Ambush",
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
        if Aliases[object.Name] then
            task.defer(function() notifyEntity(object) end)
        end
    end)

    -- Notifications are event-driven. Do not continuously scan Workspace:
    -- unrelated entity spawns must not cause an old Eyes instance to notify.
    HeartbeatConnection = nil

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
    Core = nil
    Elements = nil
end

return Notifications
