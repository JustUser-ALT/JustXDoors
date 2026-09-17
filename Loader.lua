local ModuleLoader = {}

local BASE_URL =
    "https://raw.githubusercontent.com/JustUser-ALT/JustXDoors/main/"

ModuleLoader.Cache = {}
ModuleLoader.Loading = {}
ModuleLoader.Stack = {}

local loadstring = loadstring
local getfenv = getfenv
local setfenv = setfenv

local function log(message)
    print(
        "[JustXDoors] "
        .. tostring(message)
    )
end

local function warnLog(message)
    warn(
        "[JustXDoors] "
        .. tostring(message)
    )
end

local function normalizePath(path)
    path = tostring(path or "")

    path = path:gsub(
        "\\",
        "/"
    )

    path = path:gsub(
        "^/+",
        ""
    )

    path = path:gsub(
        "/+",
        "/"
    )

    if path:sub(-4) == ".lua" then
        path =
            path:sub(
                1,
                -5
            )
    end

    return path
end

local function makeURL(path)
    return BASE_URL
        .. path
        .. ".lua"
end

local function createError(
    path,
    message
)
    return string.format(
        "[JustXDoors] Failed to load '%s': %s",
        path,
        tostring(message)
    )
end

function ModuleLoader:Load(path)
    path =
        normalizePath(path)

    if path == "" then
        error(
            createError(
                path,
                "empty module path"
            ),
            2
        )
    end

    if self.Cache[path] ~= nil then
        return self.Cache[path]
    end

    if self.Loading[path] then
        local chain =
            table.concat(
                self.Stack,
                " -> "
            )

        error(
            createError(
                path,
                "circular dependency detected\n"
                .. "Load chain: "
                .. chain
                .. " -> "
                .. path
            ),
            2
        )
    end

    self.Loading[path] = true

    table.insert(
        self.Stack,
        path
    )

    local success, result =
        xpcall(
            function()
                log(
                    "Loading "
                    .. path
                )

                local source =
                    game:HttpGet(
                        makeURL(path)
                    )

                if type(source)
                    ~= "string"
                    or source == ""
                then
                    error(
                        "empty source returned by GitHub"
                    )
                end

                if type(loadstring)
                    ~= "function"
                then
                    error(
                        "loadstring is unavailable"
                    )
                end

                local chunk,
                    compileError =
                    loadstring(
                        source,
                        "@JustXDoors/"
                        .. path
                    )

                if not chunk then
                    error(
                        "compile error:\n"
                        .. tostring(
                            compileError
                        )
                    )
                end

                local function moduleRequire(
                    modulePath
                )
                    if type(modulePath)
                        ~= "string"
                    then
                        error(
                            "JustXDoors require expects a string path, got "
                            .. type(modulePath),
                            2
                        )
                    end

                    return self:Load(
                        modulePath
                    )
                end

                if type(getfenv)
                    == "function"
                    and type(setfenv)
                    == "function"
                then
                    local environment =
                        getfenv(chunk)

                    local customEnvironment =
                        setmetatable(
                            {
                                require =
                                    moduleRequire
                            },
                            {
                                __index =
                                    environment,

                                __newindex =
                                    environment
                            }
                        )

                    setfenv(
                        chunk,
                        customEnvironment
                    )
                end

                local module =
                    chunk()

                self.Cache[path] =
                    module

                log(
                    "Loaded "
                    .. path
                )

                return module
            end,

            function(errorMessage)
                return debug.traceback(
                    tostring(
                        errorMessage
                    ),
                    2
                )
            end
        )

    self.Loading[path] = nil

    table.remove(
        self.Stack
    )

    if not success then
        warnLog(result)

        error(
            result,
            2
        )
    end

    return result
end

function ModuleLoader:ClearCache()
    table.clear(
        self.Cache
    )
end

function ModuleLoader:IsLoaded(path)
    path =
        normalizePath(path)

    return self.Cache[path]
        ~= nil
end

function ModuleLoader:GetCache()
    return self.Cache
end

function ModuleLoader:GetBaseURL()
    return BASE_URL
end

local Core = {}

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

Core.SettingsFeature =
    ModuleLoader:Load(
        "Features/Settings"
    )

Core.UI =
    ModuleLoader:Load(
        "Core/UI"
    )

log(
    "Core loaded successfully"
)

local Main =
    ModuleLoader:Load(
        "Main"
    )

if type(Main) == "table"
    and type(Main.Init)
        == "function"
then
    Main:Init(Core)
else
    warnLog(
        "Main.lua did not return a valid module"
    )
end

return ModuleLoader
