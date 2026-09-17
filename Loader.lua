
local Loader = {}

Loader.Version = "1.0.0"

local REPOSITORY =
    "https://raw.githubusercontent.com/JustUser-ALT/JustXDoors/main/"

local HttpService =
    game:GetService("HttpService")

------------------------------------------------------
-- EXECUTOR FUNCTIONS
------------------------------------------------------

local getgenvFunction =
    rawget(_G, "getgenv")

local getfenvFunction =
    rawget(_G, "getfenv")

local setfenvFunction =
    rawget(_G, "setfenv")

local loadstringFunction =
    rawget(_G, "loadstring")

local requestFunction =
    rawget(_G, "request")
        or rawget(_G, "http_request")

------------------------------------------------------
-- GLOBAL ENVIRONMENT
------------------------------------------------------

local GlobalEnv

if type(getgenvFunction) == "function" then
    local success, result =
        pcall(
            getgenvFunction
        )

    if success
        and type(result) == "table"
    then
        GlobalEnv = result
    end
end

if not GlobalEnv then
    GlobalEnv = _G
end

------------------------------------------------------
-- STATE
------------------------------------------------------

local LoaderState = {
    Version = Loader.Version,

    Loaded = {},
    Loading = {},

    Failed = {},

    Started = false,
    Finished = false
}

------------------------------------------------------
-- LOGGING
------------------------------------------------------

local function log(...)
    print(
        "[JustXDoors Loader]",
        ...
    )
end

local function warnLog(...)
    warn(
        "[JustXDoors Loader]",
        ...
    )
end

------------------------------------------------------
-- PATH
------------------------------------------------------

local function normalizePath(path)
    path = tostring(path or "")

    path = path:gsub("\\", "/")

    path = path:gsub("^/+", "")
    path = path:gsub("/+$", "")

    path = path:gsub("^%./+", "")

    if path:sub(-4) ~= ".lua" then
        path = path .. ".lua"
    end

    return path
end

------------------------------------------------------
-- URL
------------------------------------------------------

local function getURL(path)
    return REPOSITORY
        .. normalizePath(path)
end

------------------------------------------------------
-- HTTP
------------------------------------------------------

local function httpGet(url)
    if type(game.HttpGet) == "function" then
        local success, result =
            pcall(
                function()
                    return game:HttpGet(url)
                end
            )

        if success
            and type(result) == "string"
        then
            return true, result
        end
    end

    --------------------------------------------------
    -- Fallback request()
    --------------------------------------------------

    if type(requestFunction) == "function" then
        local success, response =
            pcall(
                requestFunction,
                {
                    Url = url,
                    Method = "GET"
                }
            )

        if success
            and type(response) == "table"
        then
            local body =
                response.Body
                    or response.body

            local status =
                response.StatusCode
                    or response.Status

            if type(body) == "string" then
                if not status
                    or tonumber(status) == 200
                then
                    return true, body
                end
            end
        end
    end

    return false,
        "HTTP request failed: "
            .. tostring(url)
end

------------------------------------------------------
-- FETCH
------------------------------------------------------

local function fetch(path)
    path = normalizePath(path)

    local url =
        getURL(path)

    local success, source =
        httpGet(url)

    if not success then
        return false, source
    end

    if type(source) ~= "string"
        or source == ""
    then
        return false,
            "Empty module source: "
                .. path
    end

    return true, source
end

------------------------------------------------------
-- COMPILE
------------------------------------------------------

local function compile(
    source,
    path
)
    if type(loadstringFunction)
        ~= "function"
    then
        return false,
            "loadstring is unavailable."
    end

    local chunkName =
        "@JustXDoors/"
            .. normalizePath(path)

    local success, chunk, errorMessage =
        pcall(
            loadstringFunction,
            source,
            chunkName
        )

    if not success then
        return false,
            tostring(chunk)
    end

    if type(chunk) ~= "function" then
        return false,
            tostring(errorMessage)
    end

    return true, chunk
end

------------------------------------------------------
-- MODULE ENVIRONMENT
------------------------------------------------------

local function createModuleEnvironment(
    path
)
    local moduleEnvironment = {}

    --------------------------------------------------
    -- Basic module information
    --------------------------------------------------

    moduleEnvironment.script = {
        Name = path,

        GetFullName = function()
            return "JustXDoors/"
                .. normalizePath(path)
        end
    }

    --------------------------------------------------
    -- Custom require
    --------------------------------------------------

    moduleEnvironment.require =
        function(modulePath)
            if type(modulePath) == "table"
                and modulePath.__JustXModule
            then
                modulePath =
                    modulePath.Path
            end

            return Loader:Load(
                modulePath
            )
        end

    --------------------------------------------------
    -- Loader reference
    --------------------------------------------------

    moduleEnvironment.JustXLoader =
        Loader

    --------------------------------------------------
    -- Fallback globals
    --------------------------------------------------

    local fallback

    if type(getfenvFunction)
        == "function"
    then
        local success, environment =
            pcall(
                getfenvFunction,
                2
            )

        if success
            and type(environment)
                == "table"
        then
            fallback = environment
        end
    end

    if not fallback then
        fallback = _G
    end

    setmetatable(
        moduleEnvironment,
        {
            __index = fallback
        }
    )

    return moduleEnvironment
end

------------------------------------------------------
-- EXECUTE MODULE
------------------------------------------------------

local function execute(
    chunk,
    path
)
    local environment =
        createModuleEnvironment(
            path
        )

    --------------------------------------------------
    -- Use custom environment when supported.
    --------------------------------------------------

    if type(setfenvFunction)
        == "function"
    then
        local success, errorMessage =
            pcall(
                setfenvFunction,
                chunk,
                environment
            )

        if not success then
            warnLog(
                "setfenv failed for "
                    .. path
                    .. ": "
                    .. tostring(
                        errorMessage
                    )
            )
        end
    end

    --------------------------------------------------
    -- Execute
    --------------------------------------------------

    local success, result =
        xpcall(
            function()
                return chunk()
            end,
            function(errorMessage)
                return debug
                    and debug.traceback
                    and debug.traceback(
                        tostring(
                            errorMessage
                        )
                    )
                    or tostring(
                        errorMessage
                    )
            end
        )

    if not success then
        return false, result
    end

    return true, result
end

------------------------------------------------------
-- LOAD
------------------------------------------------------

function Loader:Load(path)
    path = normalizePath(path)

    --------------------------------------------------
    -- Already loaded
    --------------------------------------------------

    if LoaderState.Loaded[path]
        ~= nil
    then
        return LoaderState.Loaded[path]
    end

    --------------------------------------------------
    -- Circular dependency
    --------------------------------------------------

    if LoaderState.Loading[path] then
        error(
            "Circular dependency detected: "
                .. path
        )
    end

    --------------------------------------------------
    -- Mark loading
    --------------------------------------------------

    LoaderState.Loading[path] = true

    --------------------------------------------------
    -- Fetch
    --------------------------------------------------

    local success, source =
        fetch(path)

    if not success then
        LoaderState.Loading[path] = nil
        LoaderState.Failed[path] =
            source

        error(
            "Failed to fetch module '"
                .. path
                .. "': "
                .. tostring(source)
        )
    end

    --------------------------------------------------
    -- Compile
    --------------------------------------------------

    local compiled, chunk =
        compile(
            source,
            path
        )

    if not compiled then
        LoaderState.Loading[path] = nil
        LoaderState.Failed[path] =
            chunk

        error(
            "Failed to compile module '"
                .. path
                .. "': "
                .. tostring(chunk)
        )
    end

    --------------------------------------------------
    -- Execute
    --------------------------------------------------

    local executed, result =
        execute(
            chunk,
            path
        )

    if not executed then
        LoaderState.Loading[path] = nil
        LoaderState.Failed[path] =
            result

        error(
            "Failed to execute module '"
                .. path
                .. "': "
                .. tostring(result)
        )
    end

    --------------------------------------------------
    -- Cache
    --------------------------------------------------

    LoaderState.Loading[path] = nil
    LoaderState.Loaded[path] = result

    log(
        "Loaded:",
        path
    )

    return result
end

------------------------------------------------------
-- OPTIONAL LOAD
------------------------------------------------------

function Loader:TryLoad(path)
    local success, result =
        pcall(
            function()
                return self:Load(path)
            end
        )

    if success then
        return true, result
    end

    warnLog(
        tostring(result)
    )

    return false, result
end

------------------------------------------------------
-- UNLOAD CACHE
------------------------------------------------------

function Loader:Unload(path)
    path = normalizePath(path)

    LoaderState.Loaded[path] = nil
    LoaderState.Failed[path] = nil

    return true
end

------------------------------------------------------
-- CHECK
------------------------------------------------------

function Loader:IsLoaded(path)
    path = normalizePath(path)

    return LoaderState.Loaded[path]
        ~= nil
end

function Loader:IsLoading(path)
    path = normalizePath(path)

    return LoaderState.Loading[path]
        == true
end

------------------------------------------------------
-- GET STATE
------------------------------------------------------

function Loader:GetState()
    return LoaderState
end

------------------------------------------------------
-- LOAD CORE
------------------------------------------------------

local function loadCore()
    local Core = {}

    --------------------------------------------------
    -- Foundation
    --------------------------------------------------

    Core.Environment =
        Loader:Load(
            "Core/Environment"
        )

    Core.Services =
        Loader:Load(
            "Core/Services"
        )

    Core.Connections =
        Loader:Load(
            "Core/Connections"
        )

    --------------------------------------------------
    -- Settings / Config
    --------------------------------------------------

    Core.Config =
        Loader:Load(
            "Core/Config"
        )

    Core.Settings =
        Loader:Load(
            "Core/Settings"
        )

    --------------------------------------------------
    -- Systems
    --------------------------------------------------

    Core.Notifications =
        Loader:Load(
            "Core/Notifications"
        )

    Core.UI =
        Loader:Load(
            "Core/UI"
        )

    --------------------------------------------------
    -- Optional Core modules
    --------------------------------------------------

    local ESP =
        Loader:TryLoad(
            "Core/ESP"
        )

    if ESP then
        Core.ESP = ESP
    end

    local Utils =
        Loader:TryLoad(
            "Core/Utils"
        )

    if Utils then
        Core.Utils = Utils
    end

    return Core
end

------------------------------------------------------
-- LOAD FEATURES
------------------------------------------------------

local function loadFeatures(
    Core
)
    --------------------------------------------------
    -- Configs
    --------------------------------------------------

    local configsSuccess,
        configs =
        Loader:TryLoad(
            "Features/Configs"
        )

    if configsSuccess then
        Core.Configs = configs

        if type(configs.Init)
            == "function"
        then
            configs:Init(Core)
        end
    end

    --------------------------------------------------
    -- Settings
    --------------------------------------------------

    local settingsSuccess,
        settingsFeature =
        Loader:TryLoad(
            "Features/Settings"
        )

    if settingsSuccess then
        Core.SettingsFeature =
            settingsFeature

        if type(
            settingsFeature.Init
        ) == "function"
        then
            settingsFeature:Init(
                Core
            )
        end
    end

    --------------------------------------------------
    -- Debug
    --------------------------------------------------

    local debugSuccess,
        debugFeature =
        Loader:TryLoad(
            "Features/Debug"
        )

    if debugSuccess then
        Core.Debug =
            debugFeature

        if type(
            debugFeature.Init
        ) == "function"
        then
            debugFeature:Init(
                Core
            )
        end
    end

    return Core
end

------------------------------------------------------
-- MAIN
------------------------------------------------------

local function loadMain(
    Core
)
    local success, Main =
        Loader:TryLoad(
            "Main"
        )

    if not success then
        return false,
            Main
    end

    Core.Main = Main

    if type(Main.Init)
        == "function"
    then
        local initialized,
            errorMessage =
            pcall(
                function()
                    return Main:Init(
                        Core
                    )
                end
            )

        if not initialized then
            return false,
                errorMessage
        end
    end

    return true, Main
end

------------------------------------------------------
-- LOBBY
------------------------------------------------------

local function loadLobby(
    Core
)
    local success, Lobby =
        Loader:TryLoad(
            "Lobby"
        )

    if not success then
        --------------------------------------------------
        -- Lobby is optional for now.
        --------------------------------------------------

        return true
    end

    Core.Lobby = Lobby

    if type(Lobby.Init)
        == "function"
    then
        local initialized,
            errorMessage =
            pcall(
                function()
                    return Lobby:Init(
                        Core
                    )
                end
            )

        if not initialized then
            warnLog(
                "Lobby initialization failed:",
                errorMessage
            )
        end
    end

    return true
end

------------------------------------------------------
-- BUILD FEATURES
------------------------------------------------------

local function buildFeatures(
    Core
)
    --------------------------------------------------
    -- Settings UI
    --------------------------------------------------

    if Core.SettingsFeature then
        local feature =
            Core.SettingsFeature

        if type(feature.Build)
            == "function"
        then
            local success,
                errorMessage =
                pcall(
                    function()
                        return feature:Build()
                    end
                )

            if not success then
                warnLog(
                    "Settings build failed:",
                    errorMessage
                )
            end
        end
    end

    --------------------------------------------------
    -- Debug UI
    --------------------------------------------------

    if Core.Debug then
        local feature =
            Core.Debug

        if type(feature.Build)
            == "function"
        then
            local success,
                errorMessage =
                pcall(
                    function()
                        return feature:Build()
                    end
                )

            if not success then
                warnLog(
                    "Debug build failed:",
                    errorMessage
                )
            end
        end
    end
end

------------------------------------------------------
-- GLOBAL OBJECT
------------------------------------------------------

local function createGlobal(
    Core
)
    local global =
        GlobalEnv.JustXDoors

    if type(global) ~= "table" then
        global = {}
    end

    global.Version =
        Loader.Version

    global.Core =
        Core

    global.Loader = {
        Version =
            Loader.Version,

        Loaded =
            LoaderState.Loaded,

        State =
            LoaderState
    }

    GlobalEnv.JustXDoors =
        global

    return global
end

------------------------------------------------------
-- START
------------------------------------------------------

function Loader:Start()
    if LoaderState.Started then
        return GlobalEnv.JustXDoors
    end

    LoaderState.Started = true

    log(
        "Starting JustXDoors..."
    )

    --------------------------------------------------
    -- CORE
    --------------------------------------------------

    local coreSuccess, Core =
        pcall(
            loadCore
        )

    if not coreSuccess then
        LoaderState.Started = false

        error(
            "Core initialization failed:\n"
                .. tostring(Core)
        )
    end

    --------------------------------------------------
    -- FEATURES
    --------------------------------------------------

    local featuresSuccess,
        featuresResult =
        pcall(
            function()
                return loadFeatures(
                    Core
                )
            end
        )

    if not featuresSuccess then
        warnLog(
            "Feature loading failed:",
            featuresResult
        )
    end

    --------------------------------------------------
    -- MAIN
    --------------------------------------------------

    local mainSuccess,
        mainResult =
        loadMain(
            Core
        )

    if not mainSuccess then
        LoaderState.Started = false

        error(
            "Main initialization failed:\n"
                .. tostring(
                    mainResult
                )
        )
    end

    --------------------------------------------------
    -- LOBBY
    --------------------------------------------------

    local lobbySuccess,
        lobbyResult =
        pcall(
            function()
                return loadLobby(
                    Core
                )
            end
        )

    if not lobbySuccess then
        warnLog(
            "Lobby loading failed:",
            lobbyResult
        )
    end

    --------------------------------------------------
    -- BUILD FEATURES
    --
    -- Main is initialized before UI features.
    --------------------------------------------------

    local buildSuccess,
        buildResult =
        pcall(
            function()
                buildFeatures(
                    Core
                )
            end
        )

    if not buildSuccess then
        warnLog(
            "Feature UI build failed:",
            buildResult
        )
    end

    --------------------------------------------------
    -- GLOBAL
    --------------------------------------------------

    local global =
        createGlobal(
            Core
        )

    LoaderState.Finished = true

    log(
        "JustXDoors loaded successfully."
    )

    return global
end

------------------------------------------------------
-- AUTO START
------------------------------------------------------

local success, result =
    pcall(
        function()
            return Loader:Start()
        end
    )

if not success then
    warn(
        "[JustXDoors Loader] "
            .. tostring(result)
    )

    return nil
end

return result
