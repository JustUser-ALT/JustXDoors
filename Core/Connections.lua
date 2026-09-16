local Connections = {}

Connections._groups = {}

local function getGroup(self, name)
    name = name or "Default"

    local group = self._groups[name]

    if not group then
        group = {}
        self._groups[name] = group
    end

    return group
end

local function disconnect(connection)
    if connection and connection.Connected then
        connection:Disconnect()
    end
end

function Connections:Connect(signal, callback, groupName)
    if typeof(signal) ~= "RBXScriptSignal" then
        return nil
    end

    if type(callback) ~= "function" then
        return nil
    end

    local connection = signal:Connect(callback)
    local group = getGroup(self, groupName)

    table.insert(group, connection)

    return connection
end

function Connections:Once(signal, callback, groupName)
    if typeof(signal) ~= "RBXScriptSignal" then
        return nil
    end

    if type(callback) ~= "function" then
        return nil
    end

    local connection = signal:Once(callback)
    local group = getGroup(self, groupName)

    table.insert(group, connection)

    return connection
end

function Connections:Add(connection, groupName)
    if not connection then
        return nil
    end

    local group = getGroup(self, groupName)

    table.insert(group, connection)

    return connection
end

function Connections:Disconnect(connection)
    if not connection then
        return
    end

    disconnect(connection)

    for _, group in pairs(self._groups) do
        for index = #group, 1, -1 do
            if group[index] == connection then
                table.remove(group, index)
                return
            end
        end
    end
end

function Connections:DisconnectGroup(groupName)
    local group = self._groups[groupName]

    if not group then
        return
    end

    for index = #group, 1, -1 do
        disconnect(group[index])
        group[index] = nil
    end

    self._groups[groupName] = nil
end

function Connections:DisconnectAll()
    for groupName in pairs(self._groups) do
        self:DisconnectGroup(groupName)
    end
end

function Connections:Count(groupName)
    local group = self._groups[groupName]

    if not group then
        return 0
    end

    local count = 0

    for _, connection in ipairs(group) do
        if connection and connection.Connected then
            count += 1
        end
    end

    return count
end

function Connections:HasGroup(groupName)
    return self._groups[groupName] ~= nil
end

return Connections
