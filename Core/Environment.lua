local Environment = {}

--==================================================
-- Safe helpers
--==================================================

local function safeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local success, a, b, c = pcall(fn, ...)

    if success then
        return a, b, c
    end

    return nil
end

local function getFunction(name)
    -- Direct global lookup.
    -- The Loader provides the executor environment
    -- through the module environment.
    local value = _G and _G[name]

    if type(value) == "function" then
        return value
    end

    -- Fallback to the current environment.
    value = _ENV and _ENV[name]

    if type(value) == "function" then
        return value
    end

    return nil
end


--==================================================
-- Executor
--==================================================

local executorName = "Unknown"
local executorVersion = "Unknown"

local identifyexecutor = getFunction("identifyexecutor")

if identifyexecutor then
    local name, version = safeCall(identifyexecutor)

    if name ~= nil then
        executorName = tostring(name)
    end

    if version ~= nil then
        executorVersion = tostring(version)
    end
end

if executorName == "Unknown" then
    local getexecutorname = getFunction("getexecutorname")

    if getexecutorname then
        local name = safeCall(getexecutorname)

        if name ~= nil then
            executorName = tostring(name)
        end
    end
end

if executorVersion == "Unknown" then
    local getexecutorversion = getFunction("getexecutorversion")

    if getexecutorversion then
        local version = safeCall(getexecutorversion)

        if version ~= nil then
            executorVersion = tostring(version)
        end
    end
end


Environment.Executor = {
    Name = executorName,
    Version = executorVersion
}


--==================================================
-- Capabilities
--==================================================

local function hasFunction(name)
    return getFunction(name) ~= nil
end

Environment.Capabilities = {

    -- Environment
    GetGenv = hasFunction("getgenv"),
    GetRenv = hasFunction("getrenv"),
    GetFenv = hasFunction("getfenv"),

    -- Loading
    Loadstring = hasFunction("loadstring"),

    -- HTTP
    Request =
        hasFunction("request")
        or hasFunction("http_request")
        or hasFunction("syn_request")
        or hasFunction("http"),

    -- File system
    IsFile = hasFunction("isfile"),
    ReadFile = hasFunction("readfile"),
    WriteFile = hasFunction("writefile"),
    AppendFile = hasFunction("appendfile"),
    MakeFolder = hasFunction("makefolder"),
    IsFolder = hasFunction("isfolder"),
    ListFiles = hasFunction("listfiles"),
    DeleteFile = hasFunction("delfile"),

    -- Hooks
    HookFunction = hasFunction("hookfunction"),
    HookMetamethod = hasFunction("hookmetamethod"),
    NewCClosure = hasFunction("newcclosure"),
    CheckCaller = hasFunction("checkcaller"),

    -- Debug
    GetConstants = hasFunction("getconstants"),
    GetConstant = hasFunction("getconstant"),
    GetUpvalues = hasFunction("getupvalues"),
    GetUpvalue = hasFunction("getupvalue"),
    GetProtos = hasFunction("getprotos"),
    GetProto = hasFunction("getproto"),
    GetInfo = hasFunction("getinfo"),

    -- Drawing
    Drawing = hasFunction("Drawing"),

    -- Clipboard
    SetClipboard =
        hasFunction("setclipboard")
        or hasFunction("toclipboard"),

    -- Input
    Mouse1Click = hasFunction("mouse1click"),
    Mouse1Press = hasFunction("mouse1press"),
    Mouse1Release = hasFunction("mouse1release"),

    -- Misc
    QueueOnTeleport = hasFunction("queue_on_teleport"),
    SetIdentity = hasFunction("setidentity"),
    GetIdentity = hasFunction("getidentity"),
}


--==================================================
-- API
--==================================================

Environment.API = {}

local API_NAMES = {
    "getgenv",
    "getrenv",
    "getfenv",

    "loadstring",

    "request",
    "http_request",
    "syn_request",
    "http",

    "isfile",
    "readfile",
    "writefile",
    "appendfile",
    "makefolder",
    "isfolder",
    "listfiles",
    "delfile",

    "hookfunction",
    "hookmetamethod",
    "newcclosure",
    "checkcaller",

    "getconstants",
    "getconstant",
    "getupvalues",
    "getupvalue",
    "getprotos",
    "getproto",
    "getinfo",

    "setclipboard",
    "toclipboard",

    "mouse1click",
    "mouse1press",
    "mouse1release",

    "queue_on_teleport",

    "setidentity",
    "getidentity",
}

for _, name in ipairs(API_NAMES) do
    Environment.API[name] = getFunction(name)
end


--==================================================
-- Public API
--==================================================

function Environment:Has(capability)
    return self.Capabilities[capability] == true
end

function Environment:Get(name)
    return self.API[name]
end

function Environment:IsExecutor(name)
    if not name then
        return false
    end

    return string.lower(tostring(self.Executor.Name))
        == string.lower(tostring(name))
end

function Environment:GetExecutorName()
    return self.Executor.Name
end

function Environment:GetExecutorVersion()
    return self.Executor.Version
end

function Environment:GetInfo()
    return {
        Name = self.Executor.Name,
        Version = self.Executor.Version,
        Capabilities = self.Capabilities
    }
end

return Environment
