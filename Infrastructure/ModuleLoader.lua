-- Dependency-injected module loader.
-- This module intentionally does not perform network requests or compile code
-- by itself. Supply Fetch and Compile functions from the host application.

local ModuleLoader = {}
ModuleLoader.__index = ModuleLoader

local NIL = {}

function ModuleLoader.new(options)
    assert(type(options) == "table", "options must be a table")
    assert(type(options.Fetch) == "function", "options.Fetch must be a function")
    assert(type(options.Compile) == "function", "options.Compile must be a function")

    return setmetatable({
        _fetch = options.Fetch,
        _compile = options.Compile,
        _cache = {},
        _loading = {},
    }, ModuleLoader)
end

function ModuleLoader:Load(path)
    assert(type(path) == "string" and path ~= "", "path must be a non-empty string")

    local cached = self._cache[path]
    if cached ~= nil then
        if cached == NIL then
            return nil
        end
        return cached
    end

    if self._loading[path] then
        error("[ModuleLoader] circular dependency detected: " .. path, 2)
    end

    self._loading[path] = true

    local ok, result = pcall(function()
        local source = self._fetch(path)
        if type(source) ~= "string" or source == "" then
            error("fetch returned no source")
        end

        local chunk, compileError = self._compile(source, path)
        if type(chunk) ~= "function" then
            error("compile failed: " .. tostring(compileError or "no chunk returned"))
        end

        return chunk()
    end)

    self._loading[path] = nil

    if not ok then
        error("[ModuleLoader] failed to load '" .. path .. "': " .. tostring(result), 2)
    end

    self._cache[path] = result == nil and NIL or result
    return result
end

function ModuleLoader:TryLoad(path)
    local ok, result = pcall(function()
        return self:Load(path)
    end)

    if ok then
        return true, result
    end

    return false, result
end

function ModuleLoader:Invalidate(path)
    if path == nil then
        self._cache = {}
        return
    end

    self._cache[path] = nil
end

function ModuleLoader:Clear()
    self._cache = {}
    self._loading = {}
end

return ModuleLoader
