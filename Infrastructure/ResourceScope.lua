-- Tracks cleanup callbacks and runs them once, in reverse registration order.
-- Pass an explicit cleanup function for each resource, or pass a cleanup
-- callback directly as the only argument.

local ResourceScope = {}
ResourceScope.__index = ResourceScope

function ResourceScope.new()
    return setmetatable({
        _cleanups = {},
        _cleaned = false,
    }, ResourceScope)
end

function ResourceScope:Add(resource, cleanup)
    local callback

    if type(resource) == "function" and cleanup == nil then
        callback = resource
    else
        assert(type(cleanup) == "function", "cleanup must be a function")
        callback = function()
            cleanup(resource)
        end
    end

    if self._cleaned then
        pcall(callback)
        return resource
    end

    table.insert(self._cleanups, callback)
    return resource
end

function ResourceScope:Cleanup()
    if self._cleaned then
        return true, {}
    end

    self._cleaned = true
    local errors = {}

    for index = #self._cleanups, 1, -1 do
        local ok, err = pcall(self._cleanups[index])
        if not ok then
            table.insert(errors, tostring(err))
        end
        self._cleanups[index] = nil
    end

    return #errors == 0, errors
end

function ResourceScope:IsCleaned()
    return self._cleaned
end

return ResourceScope
