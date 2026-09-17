local HttpService = game:GetService("HttpService")

----------------------------------------------------------------
-- SOURCE
----------------------------------------------------------------

local REPOSITORY =
    "https://raw.githubusercontent.com/JustUser-ALT/JustXDoors/main/"

----------------------------------------------------------------
-- EXECUTOR FUNCTIONS
----------------------------------------------------------------

local getgenvFunction =
    type(getgenv) == "function"
        and getgenv
        or nil

local loadstringFunction =
    type(loadstring) == "function"
        and loadstring
        or nil

local httpGetFunction =
    game.HttpGet

----------------------------------------------------------------
-- GLOBAL ENVIRONMENT
----------------------------------------------------------------

local GlobalEnv

if getgenvFunction then
    local success, result =
        pcall(getgenvFunction)

    if success
        and type(result) == "table"
    then
        GlobalEnv = result
    end
end

GlobalEnv =
    GlobalEnv
    or _G

----------------------------------------------------------------
-- LOADER STATE
----------------------------------------------------------------

local LoaderState = {
    Loaded = {},
    Loading = {},

    Started = false,
    Failed = false,

    Version = "1.0.0"
}

----------------------------------------------------------------
-- LOGGING
----------------------------------------------------------------

local PREFIX = "[JustXDoors]"

local function log(...)
    print(
        PREFIX,
        ...
    )
end

local function warnLog(...)
    warn(
        PREFIX,
        ...
    )
end

local function errorLog(...)
    warn(
        PREFIX,
        "ERROR:",
        ...
    )
end

----------------------------------------------------------------
-- VALIDATION
----------------------------------------------------------------

local function assertFunction(
    value,
    name
)
    if type(value) ~= "function" then
        error(
            name
            .. " is not available.",
            3
        )
    end

    return value
end

assertFunction(
    loadstringFunction,
    "loadstring"
)

assertFunction(
    httpGetFunction,
    "game:HttpGet"
)

----------------------------------------------------------------
-- PATH NORMALIZATION
----------------------------------------------------------------

local function normalizePath(path)
    path = tostring(path or "")

    path =
        path:gsub(
            "\\",
            "/"
        )

    path =
        path:gsub(
            "^/+",
            ""
        )

    path =
        path:gsub(
            "/+$",
            ""
        )

    path =
        path:gsub(
            "%.lua$",
            ""
        )

    return path
end

----------------------------------------------------------------
-- URL
----------------------------------------------------------------

local function getURL(path)
    path =
        normalizePath(path)

    return REPOSITORY
        .. path
        .. ".lua"
end

----------------------------------------------------------------
-- HTTP
----------------------------------------------------------------

local function fetch(path)
    local url =
        getURL(path)

    log(
        "Downloading:",
        path
    )

    local success, result =
        pcall(
            function()
                return game:HttpGet(
                    url
                )
            end
        )

    if not success then
        error(
            "Failed to download "
            .. path
            .. ": "
            .. tostring(result),
            3
        )
    end

    if type(result) ~= "string"
        or result == ""
    then
        error(
            "Empty response for "
            .. path,
            3
        )
    end

    return result
end

----------------------------------------------------------------
-- MODULE LOADER
----------------------------------------------------------------

local ModuleLoader = {}

function ModuleLoader:Load(path)
    path =
        normalizePath(path)

    ------------------------------------------------------------
    -- ALREADY LOADED
    ------------------------------------------------------------

    if LoaderState.Loaded[path] ~= nil then
        return LoaderState.Loaded[path]
    end

    ------------------------------------------------------------
    -- CIRCULAR DEPENDENCY
    ------------------------------------------------------------

    if LoaderState.Loading[path] then
        local chain = {}

        for moduleName in pairs(
            LoaderState.Loading
        ) do
            table.insert(
                chain,
                moduleName
            )
        end

        table.insert(
            chain,
            path
        )

        error(
            "Circular dependency detected: "
            .. table.concat(
                chain,
                " -> "
            ),
            3
        )
    end

    LoaderState.Loading[path] = true

    ------------------------------------------------------------
    -- DOWNLOAD
    ------------------------------------------------------------

    local source

    local success, result =
        pcall(
            function()
                return fetch(path)
            end
        )

    if not success then
        LoaderState.Loading[path] = nil

        error(
            result,
            3
        )
    end

    source = result

    ------------------------------------------------------------
    -- COMPILE
    ------------------------------------------------------------

    local chunk, compileError =
        loadstringFunction(
            source,
            "@" .. path
        )

    if not chunk then
        LoaderState.Loading[path] = nil

        error(
            "Failed to compile "
            .. path
            .. ":\n"
            .. tostring(
                compileError
            ),
            3
        )
    end

    ------------------------------------------------------------
    -- MODULE ENVIRONMENT
    ------------------------------------------------------------

    local moduleEnvironment = {}

    setmetatable(
        moduleEnvironment,
        {
            __index = getfenv
                and getfenv()
                or _G
        }
    )

    ------------------------------------------------------------
    -- CUSTOM REQUIRE
    ------------------------------------------------------------

    local function moduleRequire(
        dependency
    )
        if type(dependency)
            ~= "string"
        then
            error(
                "require() expects a string path.",
                2
            )
        end

        dependency =
            normalizePath(
                dependency
            )

        return ModuleLoader:Load(
            dependency
        )
    end

    moduleEnvironment.require =
        moduleRequire

    moduleEnvironment.script = {
        Name = path,

        GetFullName = function()
            return path
        end
    }

    ------------------------------------------------------------
    -- EXECUTOR ENVIRONMENT SUPPORT
    ------------------------------------------------------------

    local setfenvFunction =
        type(setfenv) == "function"
            and setfenv
            or nil

    if setfenvFunction then
        pcall(
            function()
                setfenvFunction(
                    chunk,
                    moduleEnvironment
                )
            end
        )
    end

    ------------------------------------------------------------
    -- EXECUTE
    ------------------------------------------------------------

    local executed, result =
        pcall(chunk)

    if not executed then
        LoaderState.Loading[path] = nil

        error(
            "Failed to execute "
            .. path
            .. ":\n"
            .. tostring(result),
            3
        )
    end

    ------------------------------------------------------------
    -- MODULE RESULT
    ------------------------------------------------------------

    if result == nil then
        result = true
    end

    LoaderState.Loading[path] = nil
    LoaderState.Loaded[path] = result

    log(
        "Loaded:",
        path
    )

    return result
end

----------------------------------------------------------------
-- CORE
----------------------------------------------------------------

local Core = {}

----------------------------------------------------------------
-- LOAD CORE MODULES
----------------------------------------------------------------

local function loadCore()
    log(
        "Loading Core..."
    )

    Core.Environment =
        ModuleLoader:Load(
            "Core/Environment"
        )

    Core.Services =
        ModuleLoader:Load(
            "Core/Services"
        )

    Core.Connections =
        ModuleLoader:Load(
            "Core/Connections"
        )

    Core.Config =
        ModuleLoader:Load(
            "Core/Config"
        )

    Core.Settings =
        ModuleLoader:Load(
            "Core/Settings"
        )

    Core.Notifications =
        ModuleLoader:Load(
            "Core/Notifications"
        )

    Core.UI =
        ModuleLoader:Load(
            "Core/UI"
        )

    log(
        "Core loaded."
    )
end

----------------------------------------------------------------
-- LOAD FEATURES
----------------------------------------------------------------

local function loadFeatures()
    log(
        "Loading Features..."
    )

    Core.Configs =
        ModuleLoader:Load(
            "Features/Configs"
        )

    Core.SettingsFeature =
        ModuleLoader:Load(
            "Features/Settings"
        )

    log(
        "Features loaded."
    )
end

----------------------------------------------------------------
-- LOAD MAIN
----------------------------------------------------------------

local function loadMain()
    log(
        "Loading Main..."
    )

    local Main =
        ModuleLoader:Load(
            "Main"
        )

    if type(Main) ~= "table" then
        error(
            "Main.lua must return a table."
        )
    end

    return Main
end

----------------------------------------------------------------
-- START
----------------------------------------------------------------

local function start()
    if LoaderState.Started then
        warnLog(
            "Already loaded."
        )

        return
    end

    LoaderState.Started = true

    log(
        "================================"
    )

    log(
        "JustXDoors",
        LoaderState.Version
    )

    log(
        "Starting..."
    )

    log(
        "================================"
    )

    ------------------------------------------------------------
    -- CORE
    ------------------------------------------------------------

    local success, result =
        xpcall(
            function()
                loadCore()
                loadFeatures()
            end,
            debug.traceback
        )

    if not success then
        LoaderState.Failed = true

        errorLog(
            "Core initialization failed."
        )

        error(
            result,
            0
        )
    end

    ------------------------------------------------------------
    -- MAIN
    ------------------------------------------------------------

    local Main

    success, result =
        xpcall(
            function()
                Main =
                    loadMain()
            end,
            debug.traceback
        )

    if not success then
        LoaderState.Failed = true

        errorLog(
            "Main loading failed."
        )

        error(
            result,
            0
        )
    end

    ------------------------------------------------------------
    -- INITIALIZE MAIN
    ------------------------------------------------------------

    if type(Main.Init) ~= "function" then
        error(
            "Main.lua does not contain Init(Core)."
        )
    end

    success, result =
        xpcall(
            function()
                Main:Init(
                    Core
                )
            end,
            debug.traceback
        )

    if not success then
        LoaderState.Failed = true

        errorLog(
            "Main initialization failed."
        )

        error(
            result,
            0
        )
    end

    ------------------------------------------------------------
    -- START SETTINGS
    ------------------------------------------------------------

    if Core.SettingsFeature then
        local feature =
            Core.SettingsFeature

        if type(feature.Init)
            == "function"
        then
            feature:Init(
                Core
            )
        end

        if type(feature.Build)
            == "function"
        then
            feature:Build()
        end
    end

    ------------------------------------------------------------
    -- GLOBAL STATE
    ------------------------------------------------------------

    GlobalEnv.JustXDoors = {
        Core = Core,
        Main = Main,

        Loader = {
            Version =
                LoaderState.Version,

            Loaded =
                LoaderState.Loaded
        }
    }

    ------------------------------------------------------------
    -- FINISH
    ------------------------------------------------------------

    log(
        "================================"
    )

    log(
        "JustXDoors loaded successfully."
    )

    log(
        "================================"
    )

    return Core
end

----------------------------------------------------------------
-- START LOADER
----------------------------------------------------------------

local success, result =
    xpcall(
        start,
        debug.traceback
    )

if not success then
    LoaderState.Failed = true

    errorLog(
        result
    )

    return nil
end

return result
