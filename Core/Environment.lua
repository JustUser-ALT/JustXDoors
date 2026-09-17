local Environment = {}

local function safeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local success, result = pcall(fn, ...)
    if success then
        return result
    end

    return nil
end

local function getGlobal(name)
    -- 1. Executor global environment
    local getgenvFn = rawget(_G, "getgenv")

    if type(getgenvFn) == "function" then
        local env = safeCall(getgenvFn)

        if type(env) == "table" and env[name] ~= nil then
            return env[name]
        end
    end

    -- 2. Current environment
    local getfenvFn = rawget(_G, "getfenv")

    if type(getfenvFn) == "function" then
        local env = safeCall(getfenvFn, 0)

        if type(env) == "table" and env[name] ~= nil then
            return env[name]
        end
    end

    -- 3. _G fallback
    local global = rawget(_G, name)

    if global ~= nil then
        return global
    end

    return nil
end

local function getFunction(name)
    local value = getGlobal(name)

    if type(value) == "function" then
        return value
    end

    return nil
end

local function has(name)
    return getFunction(name) ~= nil
end


--==================================================
-- Executor
--==================================================

local identifyexecutor = getFunction("identifyexecutor")
local getexecutorname = getFunction("getexecutorname")
local getexecutorversion = getFunction("getexecutorversion")

local executorName
local executorVersion

if identifyexecutor then
    local success, name, version = pcall(identifyexecutor)

    if success then
        executorName = name
        executorVersion = version
    end
end

if not executorName and getexecutorname then
    executorName = safeCall(getexecutorname)
end

if not executorVersion and getexecutorversion then
    executorVersion = safeCall(getexecutorversion)
end

Environment.Executor = {
    Name = executorName or "Unknown",
    Version = executorVersion or "Unknown"
}


--==================================================
-- Capabilities
--==================================================

Environment.Capabilities = {

    -- Environment
    GetGenv = has("getgenv"),
    GetRenv = has("getrenv"),
    GetFenv = has("getfenv"),

    -- Loading
    Loadstring = has("loadstring"),

    -- HTTP
    Request =
        has("request")
        or has("http_request")
        or has("syn_request")
        or has("http"),

    -- File system
    IsFile = has("isfile"),
    ReadFile = has("readfile"),
    WriteFile = has("writefile"),
    AppendFile = has("appendfile"),
    MakeFolder = has("makefolder"),
    IsFolder = has("isfolder"),
    ListFiles = has("listfiles"),
    DeleteFile = has("delfile"),

    -- Hooks
    HookFunction = has("hookfunction"),
    HookMetamethod = has("hookmetamethod"),
    NewCClosure = has("newcclosure"),
    CheckCaller = has("checkcaller"),

    -- Debug
    GetConstants = has("getconstants"),
    GetConstant = has("getconstant"),
    GetUpvalues = has("getupvalues"),
    GetUpvalue = has("getupvalue"),
    GetProtos = has("getprotos"),
    GetProto = has("getproto"),
    GetInfo = has("getinfo"),

    -- Drawing
    Drawing = has("Drawing"),

    -- Clipboard
    SetClipboard =
        has("setclipboard")
        or has("toclipboard"),

    -- Input
    Mouse1Click = has("mouse1click"),
    Mouse1Press = has("mouse1press"),
    Mouse1Release = has("mouse1release"),

    -- Misc
    QueueOnTeleport = has("queue_on_teleport"),
    SetIdentity = has("setidentity"),
    GetIdentity = has("getidentity"),
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
-- Methods
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
        Capabilities = self.Capabilities,
    }
end

return Environment
