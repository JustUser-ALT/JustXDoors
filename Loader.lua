--[[
    JustXDoors
    Loader.lua
    Modular loader

    Structure:

    JustXDoors/
    ├── Loader.lua
    ├── Main.lua
    ├── Core/
    │   ├── Environment.lua
    │   ├── Services.lua
    │   ├── Connections.lua
    │   ├── Config.lua
    │   ├── Settings.lua
    │   ├── Notifications.lua
    │   ├── UI.lua
    │   ├── ESP.lua
    │   └── Utils.lua
    │
    ├── Features/
    │   ├── Configs.lua
    │   ├── Settings.lua
    │   └── Debug.lua
    │
    └── Game/
        ├── Lobby/
        │   └── Main.lua
        ├── Main/
        │   └── Main.lua
        ├── Hotel/
        │   └── Main.lua
        ├── Mines/
        │   └── Main.lua
        ├── Backdoors/
        │   └── Main.lua
        ├── Outdoors/
        │   └── Main.lua
        ├── Archives/
        │   └── Main.lua
        └── Stairwell/
            └── Main.lua
]]

local Loader = {}

Loader.Version = "1.2.0"

--//==================================================
--// Configuration
--//==================================================

local REPOSITORY =
    "https://raw.githubusercontent.com/JustUser-ALT/JustXDoors/refs/heads/main/"

local GLOBAL_NAME = "JustXDoors"

local GLOBAL_ENV =
    (getgenv and getgenv())
    or (_G)

--//==================================================
--// Executor APIs
--//==================================================

local getgenvFn = getgenv
local getfenvFn = getfenv
local setfenvFn = setfenv
local loadstringFn = loadstring

local requestFn =
    (syn and syn.request)
    or (http and http.request)
    or (http_request)
    or (request)

--//==================================================
--// State
--//==================================================

local State = {
    Started = false,
    Finished = false,

    Loading = {},
    Loaded = {},
    Failed = {},

    Core = {},
    Features = {},
    Game = {},

    Main = nil
}

Loader.State = State

--//==================================================
--// Helpers
--//==================================================

local function normalizePath(path)
    path = tostring(path or "")

    path = path:gsub("\\", "/")
    path = path:gsub("^/+", "")
    path = path:gsub("/+$", "")

    if path:sub(-4) ~= ".lua" then
        path = path .. ".lua"
    end

    return path
end

local function getURL(path)
    return REPOSITORY .. normalizePath(path)
end

local function isLoaded(path)
    path = normalizePath(path)

    return State.Loaded[path] ~= nil
end

local function getLoaded(path)
    path = normalizePath(path)

    return State.Loaded[path]
end

--//==================================================
--// HTTP
--//==================================================

local function httpGet(url)
    if game.HttpGet then
        local success, result = pcall(function()
            return game:HttpGet(url)
        end)

        if success and type(result) == "string" then
            return result
        end
    end

    if requestFn then
        local success, response = pcall(function()
            return requestFn({
                Url = url,
                Method = "GET"
            })
        end)

        if success and response then
            local body = response.Body or response.body

            if type(body) == "string" then
                return body
            end
        end
    end

    error("HTTP request failed: " .. tostring(url))
end

--//==================================================
--// Fetch
--//==================================================

function Loader:Fetch(path)
    path = normalizePath(path)

    local url = getURL(path)

    local success, source = pcall(function()
        return httpGet(url)
    end)

    if not success then
        error(
            "[Loader] Failed to fetch "
            .. path
            .. "\n"
            .. tostring(source)
        )
    end

    if type(source) ~= "string" or source == "" then
        error("[Loader] Empty source: " .. path)
    end

    return source
end

--//==================================================
--// Compile
--//==================================================

function Loader:Compile(source, chunkName)
    if not loadstringFn then
        error(
            "[Loader] loadstring is unavailable.\n"
            .. "Your executor does not expose loadstring."
        )
    end

    local success, fn, err = pcall(function()
        return loadstringFn(source, chunkName)
    end)

    if not success then
        error(
            "[Loader] Compile error: "
            .. tostring(fn)
        )
    end

    if not fn then
        error(
            "[Loader] Compile error in "
            .. tostring(chunkName)
            .. "\n"
            .. tostring(err)
        )
    end

    return fn
end

--//==================================================
--// Module environment
--//==================================================

local function createModuleEnvironment(path)
    local env = {}

    --// Standard globals
    env.game = game
    env.workspace = workspace

    env.task = task
    env.math = math
    env.string = string
    env.table = table
    env.utf8 = utf8
    env.os = os
    env.debug = debug
    env.coroutine = coroutine
    env.bit32 = bit32

    env.Instance = Instance
    env.Enum = Enum
    env.CFrame = CFrame
    env.Vector2 = Vector2
    env.Vector3 = Vector3
    env.Color3 = Color3
    env.UDim = UDim
    env.UDim2 = UDim2
    env.Ray = Ray

    env.typeof = typeof
    env.tostring = tostring
    env.tonumber = tonumber
    env.select = select
    env.next = next
    env.pairs = pairs
    env.ipairs = ipairs
    env.unpack = unpack
    env.error = error
    env.assert = assert
    env.pcall = pcall
    env.xpcall = xpcall
    env.warn = warn
    env.print = print
    env.require = require

    --// Shared globals
    env._G = _G

    if getgenvFn then
        local success, genv = pcall(getgenvFn)

        if success then
            env.getgenv = getgenvFn
            env.getgenv = getgenvFn
            env.JustXDoors = genv and genv.JustXDoors
        end
    end

    --// Executor functions
    env.getfenv = getfenvFn
    env.setfenv = setfenvFn
    env.loadstring = loadstringFn

    --// Custom loader reference
    env.JustXLoader = Loader

    --// Fake script object
    env.script = {
        Name = path:match("([^/]+)%.lua$") or path,
        Path = path
    }

    --//==================================================
    --// Custom require
    --//==================================================

    env.require = function(module)
        -- Already-loaded module object
        if type(module) == "table" then
            return module
        end

        -- String path
        if type(module) == "string" then
            return Loader:Load(module)
        end

        -- Normal Roblox ModuleScript require
        if typeof(module) == "Instance" then
            return require(module)
        end

        error(
            "[Loader] Invalid require argument in "
            .. path
        )
    end

    return env
end

--//==================================================
--// Execute
--//==================================================

function Loader:Execute(path, source)
    path = normalizePath(path)

    local chunk = self:Compile(
        source,
        "@" .. path
    )

    local env = createModuleEnvironment(path)

    -- Prefer setfenv when the executor exposes it.
    if setfenvFn then
        pcall(function()
            setfenvFn(chunk, env)
        end)
    end

    local success, result = xpcall(
        function()
            return chunk()
        end,
        function(err)
            return tostring(err)
                .. "\n"
                .. debug.traceback()
        end
    )

    if not success then
        error(
            "[Loader] Runtime error in "
            .. path
            .. "\n"
            .. tostring(result)
        )
    end

    return result
end

--//==================================================
--// Load
--//==================================================

function Loader:Load(path, force)
    path = normalizePath(path)

    if not force and State.Loaded[path] ~= nil then
        return State.Loaded[path]
    end

    if State.Loading[path] then
        error(
            "[Loader] Circular dependency detected: "
            .. path
        )
    end

    State.Loading[path] = true

    local success, result = xpcall(
        function()
            local source = self:Fetch(path)

            return self:Execute(
                path,
                source
            )
        end,
        function(err)
            return tostring(err)
                .. "\n"
                .. debug.traceback()
        end
    )

    State.Loading[path] = nil

    if not success then
        State.Failed[path] = result

        error(result)
    end

    State.Loaded[path] = result

    return result
end

function Loader:TryLoad(path, force)
    local success, result = pcall(function()
        return self:Load(path, force)
    end)

    if success then
        return result
    end

    return nil, result
end

--//==================================================
--// Unload
--//==================================================

function Loader:Unload(path)
    path = normalizePath(path)

    local module = State.Loaded[path]

    if type(module) == "table" then
        if type(module.Destroy) == "function" then
            pcall(function()
                module:Destroy()
            end)
        elseif type(module.Unload) == "function" then
            pcall(function()
                module:Unload()
            end)
        end
    end

    State.Loaded[path] = nil
    State.Failed[path] = nil
end

function Loader:UnloadAll()
    for path in pairs(State.Loaded) do
        self:Unload(path)
    end

    State.Core = {}
    State.Features = {}
    State.Game = {}

    State.Main = nil
end

--//==================================================
--// Core
--//==================================================

local CORE_MODULES = {
    "Core/Environment",
    "Core/Services",
    "Core/Connections",
    "Core/Config",
    "Core/Settings",
    "Core/Notifications",
    "Core/UI",
    "Core/ESP",
    "Core/Utils"
}

function Loader:LoadCore()
    for _, path in ipairs(CORE_MODULES) do
        local module = self:Load(path)

        local name = path:match("([^/]+)%.lua$")

        if name then
            State.Core[name] = module
        end
    end

    return State.Core
end

--//==================================================
--// Features
--//==================================================

local FEATURE_MODULES = {
    "Features/Configs",
    "Features/Settings",
    "Features/Debug"
}

function Loader:LoadFeatures()
    for _, path in ipairs(FEATURE_MODULES) do
        local module = self:Load(path)

        local name = path:match("([^/]+)%.lua$")

        if name then
            State.Features[name] = module
        end
    end

    return State.Features
end

function Loader:InitFeatures()
    local Core = State.Core

    for name, module in pairs(State.Features) do
        if type(module) == "table"
            and type(module.Init) == "function"
        then
            local success, err = pcall(function()
                module:Init(Core)
            end)

            if not success then
                warn(
                    "[Loader] Feature Init failed: "
                    .. name
                    .. "\n"
                    .. tostring(err)
                )
            end
        end
    end
end

function Loader:BuildFeatures()
    for name, module in pairs(State.Features) do
        if type(module) == "table"
            and type(module.Build) == "function"
        then
            local success, err = pcall(function()
                module:Build()
            end)

            if not success then
                warn(
                    "[Loader] Feature Build failed: "
                    .. name
                    .. "\n"
                    .. tostring(err)
                )
            end
        end
    end
end

--//==================================================
--// Root Main
--//==================================================

function Loader:LoadMain()
    local Main = self:Load("Main")

    State.Main = Main

    return Main
end

function Loader:InitMain()
    local Main = State.Main

    if not Main then
        return
    end

    if type(Main.Init) == "function" then
        local success, err = pcall(function()
            Main:Init(State.Core)
        end)

        if not success then
            error(
                "[Loader] Main Init failed:\n"
                .. tostring(err)
            )
        end
    end

    if type(Main.Build) == "function" then
        local success, err = pcall(function()
            Main:Build()
        end)

        if not success then
            error(
                "[Loader] Main Build failed:\n"
                .. tostring(err)
            )
        end
    end
end

--//==================================================
--// Game modules
--//==================================================

local GAME_MODULES = {
    {
        Name = "Lobby",
        Path = "Game/Lobby/Main"
    },

    {
        Name = "Main",
        Path = "Game/Main/Main"
    },

    {
        Name = "Hotel",
        Path = "Game/Hotel/Main"
    },

    {
        Name = "Mines",
        Path = "Game/Mines/Main"
    },

    {
        Name = "Backdoors",
        Path = "Game/Backdoors/Main"
    },

    {
        Name = "Outdoors",
        Path = "Game/Outdoors/Main"
    },

    {
        Name = "Archives",
        Path = "Game/Archives/Main"
    },

    {
        Name = "Stairwell",
        Path = "Game/Stairwell/Main"
    }
}

function Loader:LoadGame()
    for _, info in ipairs(GAME_MODULES) do
        local module, err = self:TryLoad(info.Path)

        if module then
            State.Game[info.Name] = module
        else
            warn(
                "[Loader] Game module failed: "
                .. info.Path
                .. "\n"
                .. tostring(err)
            )
        end
    end

    return State.Game
end

function Loader:InitGame()
    local Core = State.Core

    for name, module in pairs(State.Game) do
        if type(module) == "table"
            and type(module.Init) == "function"
        then
            local success, err = pcall(function()
                module:Init(Core, State.Main)
            end)

            if not success then
                warn(
                    "[Loader] Game Init failed: "
                    .. name
                    .. "\n"
                    .. tostring(err)
                )
            end
        end
    end
end

function Loader:BuildGame()
    for name, module in pairs(State.Game) do
        if type(module) == "table"
            and type(module.Build) == "function"
        then
            local success, err = pcall(function()
                module:Build()
            end)

            if not success then
                warn(
                    "[Loader] Game Build failed: "
                    .. name
                    .. "\n"
                    .. tostring(err)
                )
            end
        end
    end
end

--//==================================================
--// Global
--//==================================================

function Loader:CreateGlobal()
    local existing = GLOBAL_ENV[GLOBAL_NAME]

    if type(existing) == "table"
        and existing.Loader
    then
        return existing
    end

    local global = {
        Version = self.Version,

        Loader = self,

        Core = State.Core,
        Features = State.Features,
        Game = State.Game,

        Main = State.Main,

        State = State,

        Unload = function()
            self:UnloadAll()
        end
    }

    GLOBAL_ENV[GLOBAL_NAME] = global

    return global
end

--//==================================================
--// Start
--//==================================================

function Loader:Start()
    if State.Started then
        return GLOBAL_ENV[GLOBAL_NAME]
    end

    State.Started = true

    -- 1. Core
    self:LoadCore()

    -- 2. Root coordinator
    self:LoadMain()

    -- 3. Create UI / root tabs
    self:InitMain()

    -- 4. Features
    self:LoadFeatures()
    self:InitFeatures()
    self:BuildFeatures()

    -- 5. Game modules
    self:LoadGame()
    self:InitGame()
    self:BuildGame()

    -- 6. Global API
    local global = self:CreateGlobal()

    State.Finished = true

    return global
end

--//==================================================
--// State API
--//==================================================

function Loader:IsLoaded(path)
    return isLoaded(path)
end

function Loader:IsLoading(path)
    path = normalizePath(path)

    return State.Loading[path] == true
end

function Loader:GetState()
    return State
end

function Loader:Get(path)
    return getLoaded(path)
end

--//==================================================
--// Auto Start
--//==================================================

local success, result = xpcall(
    function()
        return Loader:Start()
    end,
    function(err)
        return tostring(err)
            .. "\n"
            .. debug.traceback()
    end
)

if not success then
    warn(
        "[JustXDoors Loader] Startup failed:\n"
        .. tostring(result)
    )
else
    return result
end

return Loader
