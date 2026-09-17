--[[
    JustXDoors
    Loader.lua
    Modular loader

    Version: 1.4.0
]]

local Loader = {}

Loader.Version = "1.4.0"

--//==================================================
--// Configuration
--//==================================================

local REPOSITORY =
    "https://raw.githubusercontent.com/JustUser-ALT/JustXDoors/refs/heads/main/"

local GLOBAL_NAME = "JustXDoors"


--//==================================================
--// Executor / Global environment
--//==================================================

local function getGlobalEnvironment()

    local genv = nil
    local getgenvCandidate

    pcall(function()
        getgenvCandidate = getgenv
    end)

    if type(getgenvCandidate) == "function" then

        local success, result =
            pcall(getgenvCandidate)

        if success and type(result) == "table" then
            genv = result
        end
    end

    if type(genv) ~= "table" then
        genv = _G
    end

    return genv
end


local GLOBAL_ENV =
    getGlobalEnvironment()


--//==================================================
--// Executor APIs
--//==================================================

local function getGlobalFunction(name)

    local value

    pcall(function()
        value = GLOBAL_ENV[name]
    end)

    if type(value) == "function" then
        return value
    end

    return nil
end


local getgenvFn =
    getGlobalFunction("getgenv")

local getfenvFn =
    getGlobalFunction("getfenv")

local setfenvFn =
    getGlobalFunction("setfenv")

local loadstringFn =
    getGlobalFunction("loadstring")


local requestFn =
    getGlobalFunction("request")
    or getGlobalFunction("http_request")
    or getGlobalFunction("syn_request")


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

    return REPOSITORY
        .. normalizePath(path)
        .. "?v="
        .. tostring(os.clock())
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

    --------------------------------------------------
    -- Roblox HttpGet
    --------------------------------------------------

    local success, result =
        pcall(function()

            return game:HttpGet(url)

        end)


    if success
        and type(result) == "string"
        and result ~= ""
    then

        return result
    end


    --------------------------------------------------
    -- Executor request
    --------------------------------------------------

    if requestFn then

        local requestSuccess, response =
            pcall(function()

                return requestFn({
                    Url = url,
                    Method = "GET"
                })

            end)


        if requestSuccess
            and response
        then

            local body =
                response.Body
                or response.body


            if type(body) == "string"
                and body ~= ""
            then

                return body
            end
        end
    end


    error(
        "[Loader] HTTP request failed:\n"
        .. tostring(url)
    )
end


--//==================================================
--// Fetch
--//==================================================

function Loader:Fetch(path)

    path =
        normalizePath(path)


    local url =
        getURL(path)


    print("========================================")
    print("[JustXDoors Loader] FETCH")
    print("Path:", path)
    print("URL:", url)
    print("========================================")


    local success, source =
        pcall(function()

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


    if type(source) ~= "string"
        or source == ""
    then

        error(
            "[Loader] Empty source: "
            .. path
        )
    end


    print(
        "[JustXDoors Loader] Fetched",
        path,
        "bytes:",
        #source
    )


    --------------------------------------------------
    -- UI diagnostics
    --------------------------------------------------

    if path == "Core/UI.lua" then

        print(
            "========== CORE/UI SOURCE CHECK =========="
        )


        local firstLine =
            source:match("^[^\r\n]*")


        print(
            "[JustXDoors Loader] UI first line:",
            tostring(firstLine)
        )


        if source:find(
            "2%.0%.0",
            1,
            false
        ) then

            print(
                "[JustXDoors Loader] UI VERSION MARKER FOUND"
            )

        else

            warn(
                "[JustXDoors Loader] UI VERSION MARKER NOT FOUND"
            )
        end


        if source:find(
            "JUSTXDOORS UI CREATE CALLED",
            1,
            true
        ) then

            print(
                "[JustXDoors Loader] NEW UI DIAGNOSTICS FOUND"
            )

        else

            warn(
                "[JustXDoors Loader] NEW UI DIAGNOSTICS NOT FOUND"
            )
        end


        print(
            "=========================================="
        )
    end


    return source
end


--//==================================================
--// Compile
--//==================================================

function Loader:Compile(source, chunkName)

    if type(loadstringFn) ~= "function" then

        error(
            "[Loader] loadstring is unavailable."
        )
    end


    local success, fn, err =
        pcall(function()

            return loadstringFn(
                source,
                chunkName
            )

        end)


    if not success then

        error(
            "[Loader] Compile error:\n"
            .. tostring(fn)
        )
    end


    if type(fn) ~= "function" then

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
--// Module Environment
--//==================================================

local function createModuleEnvironment(path)

    local env = {}


    --------------------------------------------------
    -- Loader
    --------------------------------------------------

    env.JustXLoader =
        Loader


    env.script = {

        Name =
            path:match(
                "([^/]+)%.lua$"
            )
            or path,

        Path = path
    }


    --------------------------------------------------
    -- Roblox globals
    --------------------------------------------------

    env.game =
        game

    env.workspace =
        workspace

    env.Instance =
        Instance

    env.Enum =
        Enum


    env.CFrame =
        CFrame

    env.Vector2 =
        Vector2

    env.Vector3 =
        Vector3

    env.Color3 =
        Color3


    env.UDim =
        UDim

    env.UDim2 =
        UDim2


    env.Ray =
        Ray


    env.task =
        task


    env.math =
        math

    env.string =
        string

    env.table =
        table

    env.utf8 =
        utf8

    env.os =
        os

    env.coroutine =
        coroutine

    env.bit32 =
        bit32


    --------------------------------------------------
    -- Luau globals
    --------------------------------------------------

    env.type =
        type

    env.typeof =
        typeof

    env.tostring =
        tostring

    env.tonumber =
        tonumber

    env.select =
        select

    env.next =
        next

    env.pairs =
        pairs

    env.ipairs =
        ipairs

    env.unpack =
        unpack

    env.error =
        error

    env.assert =
        assert

    env.pcall =
        pcall

    env.xpcall =
        xpcall

    env.print =
        print

    env.warn =
        warn

    env.rawget =
        rawget

    env.rawset =
        rawset

    env.rawequal =
        rawequal

    env.rawlen =
        rawlen

    env.getmetatable =
        getmetatable

    env.setmetatable =
        setmetatable


    --------------------------------------------------
    -- Shared globals
    --------------------------------------------------

    env._G =
        _G


    --------------------------------------------------
    -- Executor globals
    --------------------------------------------------

    if getgenvFn then
        env.getgenv = getgenvFn
    end

    if getfenvFn then
        env.getfenv = getfenvFn
    end

    if setfenvFn then
        env.setfenv = setfenvFn
    end

    if loadstringFn then
        env.loadstring = loadstringFn
    end


    --------------------------------------------------
    -- Global fallback
    --------------------------------------------------

    setmetatable(env, {

        __index =
            GLOBAL_ENV

    })


    --------------------------------------------------
    -- Custom require
    --------------------------------------------------

    env.require = function(module)

        if type(module) == "table" then
            return module
        end


        if type(module) == "string" then

            return Loader:Load(module)

        end


        if typeof(module) == "Instance" then

            if module:IsA("ModuleScript") then
                return require(module)
            end

        end


        error(
            "[Loader] Invalid require argument in "
            .. tostring(path)
        )
    end


    return env
end


--//==================================================
--// Execute
--//==================================================

function Loader:Execute(path, source)

    path =
        normalizePath(path)


    print(
        "[JustXDoors Loader] Execute:",
        path
    )


    local chunk =
        self:Compile(
            source,
            "@" .. path
        )


    local env =
        createModuleEnvironment(path)


    --------------------------------------------------
    -- Module environment
    --------------------------------------------------

    if type(setfenvFn) ~= "function" then

        error(
            "[Loader] setfenv is unavailable.\n"
            .. "Cannot create isolated module environment for:\n"
            .. path
        )
    end


    local setSuccess, setError =
        pcall(function()

            setfenvFn(
                chunk,
                env
            )

        end)


    if not setSuccess then

        error(
            "[Loader] Failed to assign module environment:\n"
            .. path
            .. "\n"
            .. tostring(setError)
        )
    end


    --------------------------------------------------
    -- Execute
    --------------------------------------------------

    local success, result =
        xpcall(

            function()

                return chunk()

            end,

            function(err)

                local traceback

                pcall(function()

                    traceback =
                        debug.traceback()

                end)


                return tostring(err)
                    .. "\n"
                    .. tostring(
                        traceback or ""
                    )
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


    print(
        "[JustXDoors Loader] Execute finished:",
        path,
        "return type:",
        type(result)
    )


    return result
end


--//==================================================
--// Load
--//==================================================

function Loader:Load(path, force)

    path =
        normalizePath(path)


    if not force
        and State.Loaded[path] ~= nil
    then

        print(
            "[JustXDoors Loader] Cached:",
            path
        )

        return State.Loaded[path]
    end


    if State.Loading[path] then

        error(
            "[Loader] Circular dependency detected: "
            .. path
        )
    end


    State.Loading[path] =
        true


    print(
        "[JustXDoors Loader] Loading:",
        path
    )


    local success, result =
        xpcall(

            function()

                local source =
                    self:Fetch(path)

                return self:Execute(
                    path,
                    source
                )

            end,

            function(err)

                local traceback

                pcall(function()

                    traceback =
                        debug.traceback()

                end)


                return tostring(err)
                    .. "\n"
                    .. tostring(
                        traceback or ""
                    )
            end
        )


    State.Loading[path] =
        nil


    if not success then

        State.Failed[path] =
            result

        error(result)
    end


    State.Loaded[path] =
        result


    print(
        "[JustXDoors Loader] Loaded:",
        path,
        "type:",
        type(result)
    )


    return result
end


function Loader:TryLoad(path, force)

    local success, result =
        pcall(function()

            return self:Load(
                path,
                force
            )

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

    path =
        normalizePath(path)


    local module =
        State.Loaded[path]


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


    State.Loaded[path] =
        nil

    State.Failed[path] =
        nil
end


function Loader:UnloadAll()

    for path in pairs(State.Loaded) do
        self:Unload(path)
    end


    State.Core =
        {}

    State.Features =
        {}

    State.Game =
        {}

    State.Main =
        nil


    State.Finished =
        false
end


--//==================================================
--// CORE MODULES
--//==================================================

local CORE_MODULES = {

    {
        Name = "Environment",
        Path = "Core/Environment"
    },

    {
        Name = "Services",
        Path = "Core/Services"
    },

    {
        Name = "Connections",
        Path = "Core/Connections"
    },

    {
        Name = "Config",
        Path = "Core/Config"
    },

    {
        Name = "Settings",
        Path = "Core/Settings"
    },

    {
        Name = "Notifications",
        Path = "Core/Notifications"
    },

    {
        Name = "UI",
        Path = "Core/UI"
    }
}


function Loader:LoadCore()

    print(
        "========== LOADING CORE =========="
    )


    for _, info in ipairs(CORE_MODULES) do

        local success, module =
            pcall(function()

                return self:Load(
                    info.Path,
                    true
                )

            end)


        if not success then

            error(
                "[Loader] Core module failed: "
                .. info.Path
                .. "\n"
                .. tostring(module)
            )
        end


        if module == nil then

            error(
                "[Loader] Core module returned nil: "
                .. info.Path
            )
        end


        State.Core[info.Name] =
            module


        print(
            "[JustXDoors Loader] Core:",
            info.Name,
            "type:",
            type(module)
        )
    end


    if type(State.Core.UI) ~= "table" then

        error(
            "[Loader] Core.UI was not loaded correctly."
        )
    end


    print(
        "========== CORE LOADED =========="
    )


    return State.Core
end


--//==================================================
--// FEATURES
--//==================================================

local FEATURE_MODULES = {

    "Features/Configs",
    "Features/Settings",
    "Features/Debug"
}


function Loader:LoadFeatures()

    for _, path in ipairs(FEATURE_MODULES) do

        local module, err =
            self:TryLoad(path)


        if module then

            local name =
                path:match(
                    "([^/]+)%.lua$"
                )


            if name then
                State.Features[name] =
                    module
            end

        else

            warn(
                "[Loader] Feature load failed: "
                .. path
                .. "\n"
                .. tostring(err)
            )
        end
    end


    return State.Features
end


function Loader:InitFeatures()

    local Core =
        State.Core


    for name, module in pairs(State.Features) do

        if type(module) == "table"
            and type(module.Init) == "function"
        then

            local success, err =
                pcall(function()

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

            local success, err =
                pcall(function()

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
--// ROOT MAIN
--//==================================================

function Loader:LoadMain()

    print(
        "[JustXDoors Loader] Loading Root Main"
    )


    local Main =
        self:Load(
            "Main",
            true
        )


    if type(Main) ~= "table" then

        error(
            "[Loader] Root Main returned invalid value."
        )
    end


    State.Main =
        Main


    --------------------------------------------------
    -- IMPORTANT
    --
    -- Make root Main available through Core
    -- BEFORE game modules are initialized.
    --------------------------------------------------

    State.Core.Main =
        Main


    print(
        "[JustXDoors Loader] Core.Main registered."
    )


    print(
        "[JustXDoors Loader] Root Main loaded."
    )


    return Main
end


function Loader:InitMain()

    local Main =
        State.Main


    if not Main then

        error(
            "[Loader] Root Main returned nil."
        )
    end


    --------------------------------------------------
    -- Init
    --------------------------------------------------

    if type(Main.Init) == "function" then

        local success, err =
            pcall(function()

                Main:Init(
                    State.Core
                )

            end)


        if not success then

            error(
                "[Loader] Main Init failed:\n"
                .. tostring(err)
            )
        end
    end


    --------------------------------------------------
    -- Build
    --------------------------------------------------

    if type(Main.Build) == "function" then

        local success, err =
            pcall(function()

                Main:Build()

            end)


        if not success then

            error(
                "[Loader] Main Build failed:\n"
                .. tostring(err)
            )
        end
    end


    --------------------------------------------------
    -- Verify tabs
    --------------------------------------------------

    if Main.Tabs then

        local requiredTabs = {

            "Lobby",
            "Main",
            "Hotel",
            "Mines",
            "Backdoors",
            "Outdoors",
            "Archives",
            "Stairwell"
        }


        for _, tabName in ipairs(requiredTabs) do

            if Main.Tabs[tabName] then

                print(
                    "[JustXDoors Loader] Tab OK:",
                    tabName
                )

            else

                warn(
                    "[JustXDoors Loader] "
                    .. "Missing tab: "
                    .. tabName
                )
            end
        end

    else

        warn(
            "[JustXDoors Loader] "
            .. "Root Main.Tabs is missing."
        )
    end
end


--//==================================================
--// GAME MODULES
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


--//==================================================
--// LOAD GAME
--//==================================================

function Loader:LoadGame()

    print(
        "========== LOADING GAME =========="
    )


    for _, info in ipairs(GAME_MODULES) do

        print(
            "[JustXDoors Loader] Game:",
            info.Name
        )


        local module, err =
            self:TryLoad(
                info.Path
            )


        if module then

            State.Game[info.Name] =
                module


            print(
                "[JustXDoors Loader] Game loaded:",
                info.Name
            )

        else

            warn(
                "[JustXDoors Loader] "
                .. "Game module failed: "
                .. info.Path
                .. "\n"
                .. tostring(err)
            )
        end
    end


    return State.Game
end


--//==================================================
--// INIT GAME
--//==================================================

function Loader:InitGame()

    local Core =
        State.Core


    --------------------------------------------------
    -- Verify root Main
    --------------------------------------------------

    if not Core.Main then

        error(
            "[Loader] Core.Main is missing before Game Init."
        )
    end


    if not Core.Main.Tabs then

        error(
            "[Loader] Core.Main.Tabs is missing before Game Init."
        )
    end


    --------------------------------------------------
    -- Ordered initialization
    --------------------------------------------------

    for _, info in ipairs(GAME_MODULES) do

        local module =
            State.Game[info.Name]


        if type(module) == "table"
            and type(module.Init) == "function"
        then

            print(
                "[JustXDoors Loader] Init Game:",
                info.Name
            )


            local success, err =
                pcall(function()

                    module:Init(
                        Core
                    )

                end)


            if not success then

                warn(
                    "[Loader] Game Init failed: "
                    .. info.Name
                    .. "\n"
                    .. tostring(err)
                )
            end
        end
    end
end


--//==================================================
--// BUILD GAME
--//==================================================

function Loader:BuildGame()

    --------------------------------------------------
    -- Build
    --------------------------------------------------

    for _, info in ipairs(GAME_MODULES) do

        local module =
            State.Game[info.Name]


        if type(module) == "table"
            and type(module.Build) == "function"
        then

            print(
                "[JustXDoors Loader] Build Game:",
                info.Name
            )


            local success, err =
                pcall(function()

                    module:Build()

                end)


            if not success then

                warn(
                    "[Loader] Game Build failed: "
                    .. info.Name
                    .. "\n"
                    .. tostring(err)
                )
            end
        end
    end


    --------------------------------------------------
    -- Start
    --------------------------------------------------

    for _, info in ipairs(GAME_MODULES) do

        local module =
            State.Game[info.Name]


        if type(module) == "table"
            and type(module.Start) == "function"
        then

            print(
                "[JustXDoors Loader] Start Game:",
                info.Name
            )


            local success, err =
                pcall(function()

                    module:Start()

                end)


            if not success then

                warn(
                    "[Loader] Game Start failed: "
                    .. info.Name
                    .. "\n"
                    .. tostring(err)
                )
            end
        end
    end
end


--//==================================================
--// GLOBAL API
--//==================================================

function Loader:CreateGlobal()

    local existing =
        GLOBAL_ENV[GLOBAL_NAME]


    if type(existing) == "table"
        and existing.Loader
    then

        return existing
    end


    local global = {

        Version =
            self.Version,

        Loader =
            self,

        Core =
            State.Core,

        Features =
            State.Features,

        Game =
            State.Game,

        Main =
            State.Main,

        State =
            State,

        Unload = function()

            self:UnloadAll()

        end
    }


    GLOBAL_ENV[GLOBAL_NAME] =
        global


    return global
end


--//==================================================
--// START
--//==================================================

function Loader:Start()

    if State.Started then

        return GLOBAL_ENV[GLOBAL_NAME]
    end


    State.Started =
        true


    print(
        "========================================"
    )

    print(
        "       JUSTXDOORS LOADER "
        .. self.Version
    )

    print(
        "========================================"
    )


    --------------------------------------------------
    -- 1. CORE
    --------------------------------------------------

    self:LoadCore()


    --------------------------------------------------
    -- 2. ROOT MAIN
    --
    -- Creates the UI and ALL tabs.
    --------------------------------------------------

    self:LoadMain()

    self:InitMain()


    --------------------------------------------------
    -- 3. FEATURES
    --------------------------------------------------

    self:LoadFeatures()

    self:InitFeatures()

    self:BuildFeatures()


    --------------------------------------------------
    -- 4. GAME
    --------------------------------------------------

    self:LoadGame()

    self:InitGame()

    self:BuildGame()


    --------------------------------------------------
    -- 5. GLOBAL
    --------------------------------------------------

    local global =
        self:CreateGlobal()


    State.Finished =
        true


    print(
        "========================================"
    )

    print(
        "[JustXDoors Loader] Startup complete."
    )

    print(
        "[JustXDoors Loader] Version:",
        self.Version
    )

    print(
        "========================================"
    )


    return global
end


--//==================================================
--// PUBLIC API
--//==================================================

function Loader:IsLoaded(path)

    return isLoaded(path)
end


function Loader:IsLoading(path)

    path =
        normalizePath(path)

    return State.Loading[path] == true
end


function Loader:GetState()

    return State
end


function Loader:Get(path)

    return getLoaded(path)
end


--//==================================================
--// AUTO START
--//==================================================

local success, result =
    xpcall(

        function()

            return Loader:Start()

        end,

        function(err)

            local traceback

            pcall(function()

                traceback =
                    debug.traceback()

            end)


            return tostring(err)
                .. "\n"
                .. tostring(
                    traceback or ""
                )
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
