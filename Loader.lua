local BASE_URL = "https://raw.githubusercontent.com/JustUser-ALT/JustXDoors/main/"

local function getGlobalFunction(name)
    local success, value = pcall(function()
        return getfenv(0)[name]
    end)

    if success and type(value) == "function" then
        return value
    end

    return nil
end

local loadstring = getGlobalFunction("loadstring")

if not loadstring then
    error("JustXDoors: loadstring is unavailable")
end

local ModuleLoader = {}

ModuleLoader.Cache = {}
ModuleLoader.Loading = {}
ModuleLoader.Stack = {}

local function normalizePath(path)
    path = tostring(path or "")

    path = path:gsub("\\", "/")
    path = path:gsub("^/+", "")
    path = path:gsub("%.lua$", "")

    return path
end

local function getModulePath(path)
    path = normalizePath(path)

    if path == "" then
        return nil
    end

    return path .. ".lua"
end

function ModuleLoader:GetURL(path)
    local modulePath = getModulePath(path)

    if not modulePath then
        return nil
    end

    return BASE_URL .. modulePath
end

function ModuleLoader:IsLoaded(path)
    path = normalizePath(path)

    return self.Cache[path] ~= nil
end

function ModuleLoader:Load(path)
    path = normalizePath(path)

    if path == "" then
        error("JustXDoors: invalid module path")
    end

    if self.Cache[path] ~= nil then
        return self.Cache[path]
    end

    if self.Loading[path] then
        local chain = table.concat(self.Stack, " -> ")

        error(
            "JustXDoors: circular module dependency\n" ..
            chain ..
            " -> " ..
            path
        )
    end

    self.Loading[path] = true
    table.insert(self.Stack, path)

    local modulePath = getModulePath(path)
    local url = self:GetURL(path)

    local success, source = pcall(function()
        return game:HttpGet(url)
    end)

    if not success then
        self.Loading[path] = nil
        table.remove(self.Stack)

        error(
            "JustXDoors: failed to download module\n" ..
            modulePath ..
            "\n" ..
            tostring(source)
        )
    end

    local chunk, compileError = loadstring(source)

    if not chunk then
        self.Loading[path] = nil
        table.remove(self.Stack)

        error(
            "JustXDoors: failed to compile module\n" ..
            modulePath ..
            "\n" ..
            tostring(compileError)
        )
    end

    local moduleRequire = function(dependency)
        if type(dependency) ~= "string" then
            error(
                "JustXDoors: module require expects a string path"
            )
        end

        return self:Load(dependency)
    end

    local executed, result = pcall(
        chunk,
        moduleRequire
    )

    if not executed then
        self.Loading[path] = nil
        table.remove(self.Stack)

        error(
            "JustXDoors: failed to execute module\n" ..
            modulePath ..
            "\n" ..
            tostring(result)
        )
    end

    self.Loading[path] = nil
    table.remove(self.Stack)

    self.Cache[path] = result

    return result
end

function ModuleLoader:Unload(path)
    path = normalizePath(path)

    self.Cache[path] = nil
end

function ModuleLoader:ClearCache()
    table.clear(self.Cache)
end

local function loadCore()
    return {
        Environment = ModuleLoader:Load("Core/Environment"),
        Services = ModuleLoader:Load("Core/Services"),
        Connections = ModuleLoader:Load("Core/Connections"),
        Config = ModuleLoader:Load("Core/Config"),
        Notifications = ModuleLoader:Load("Core/Notifications"),
        UI = ModuleLoader:Load("Core/UI")
    }
end

local Core = loadCore()

local Environment = Core.Environment
local Notifications = Core.Notifications

local info = Environment:GetInfo()

if info.Executor == "Unknown" then
    Notifications:Warning(
        "JustXDoors",
        "Executor was not detected"
    )
end

local Main

local success, result = pcall(function()
    return ModuleLoader:Load("Main")
end)

if not success then
    Notifications:Error(
        "JustXDoors",
        "Failed to load Main"
    )

    error(result)
end

Main = result

if type(Main) == "table" and type(Main.Init) == "function" then
    local initialized, initError = pcall(function()
        Main:Init(Core)
    end)

    if not initialized then
        Notifications:Error(
            "JustXDoors",
            "Main initialization failed"
        )

        error(initError)
    end
end

return {
    Loader = ModuleLoader,
    Core = Core,
    Main = Main
}
