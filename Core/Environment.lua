local Environment = {}

local function getGlobal(name)
    local success, value = pcall(function()
        return getfenv(0)[name]
    end)

    if success then
        return value
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

Environment.Executor = {
    Name = "Unknown",
    Version = "Unknown"
}

do
    local identifyexecutor = getFunction("identifyexecutor")

    if identifyexecutor then
        local success, name, version = pcall(identifyexecutor)

        if success then
            if type(name) == "string" then
                Environment.Executor.Name = name
            end

            if type(version) == "string" then
                Environment.Executor.Version = version
            end
        end
    end
end

Environment.Capabilities = {
    GetGenv = has("getgenv"),
    GetRenv = has("getrenv"),
    GetFenv = has("getfenv"),

    Loadstring = has("loadstring"),
    Request = has("request") or has("http_request"),

    GetHui = has("gethui"),
    CloneRef = has("cloneref"),

    WriteFile = has("writefile"),
    ReadFile = has("readfile"),
    IsFile = has("isfile"),
    DeleteFile = has("delfile"),
    AppendFile = has("appendfile"),
    MakeFolder = has("makefolder"),
    IsFolder = has("isfolder"),
    DeleteFolder = has("delfolder"),
    ListFiles = has("listfiles"),

    GetInstances = has("getinstances"),
    GetNilInstances = has("getnilinstances"),
    GetConnections = has("getconnections"),

    FireSignal = has("firesignal"),
    ReplicateSignal = has("replicatesignal"),

    FireProximityPrompt = has("fireproximityprompt"),
    FireClickDetector = has("fireclickdetector"),
    FireTouchInterest = has("firetouchinterest"),

    CloneFunction = has("clonefunction"),
    NewCClosure = has("newcclosure"),

    GetThreadIdentity = has("getthreadidentity"),
    SetThreadIdentity = has("setthreadidentity"),

    IsNetworkOwner = has("isnetworkowner"),

    Drawing = type(getGlobal("Drawing")) == "table",

    HookFunction = has("hookfunction"),
    RestoreFunction = has("restorefunction"),
    HookMetamethod = has("hookmetamethod"),
    GetNamecallMethod = has("getnamecallmethod"),
    GetRawMetatable = has("getrawmetatable"),
    SetRawMetatable = has("setrawmetatable"),

    GetHiddenProperty = has("gethiddenproperty"),
    SetHiddenProperty = has("sethiddenproperty"),

    IsReadonly = has("isreadonly"),
    SetReadonly = has("setreadonly")
}

Environment.API = {
    getgenv = getFunction("getgenv"),
    getrenv = getFunction("getrenv"),
    getfenv = getFunction("getfenv"),

    loadstring = getFunction("loadstring"),

    request = getFunction("request") or getFunction("http_request"),

    gethui = getFunction("gethui"),
    cloneref = getFunction("cloneref"),

    writefile = getFunction("writefile"),
    readfile = getFunction("readfile"),
    isfile = getFunction("isfile"),
    delfile = getFunction("delfile"),
    appendfile = getFunction("appendfile"),

    makefolder = getFunction("makefolder"),
    isfolder = getFunction("isfolder"),
    delfolder = getFunction("delfolder"),
    listfiles = getFunction("listfiles"),

    getinstances = getFunction("getinstances"),
    getnilinstances = getFunction("getnilinstances"),
    getconnections = getFunction("getconnections"),

    firesignal = getFunction("firesignal"),
    replicatesignal = getFunction("replicatesignal"),

    fireproximityprompt = getFunction("fireproximityprompt"),
    fireclickdetector = getFunction("fireclickdetector"),
    firetouchinterest = getFunction("firetouchinterest"),

    clonefunction = getFunction("clonefunction"),
    newcclosure = getFunction("newcclosure"),

    getthreadidentity = getFunction("getthreadidentity"),
    setthreadidentity = getFunction("setthreadidentity"),

    isnetworkowner = getFunction("isnetworkowner"),

    hookfunction = getFunction("hookfunction"),
    restorefunction = getFunction("restorefunction"),
    hookmetamethod = getFunction("hookmetamethod"),
    getnamecallmethod = getFunction("getnamecallmethod"),

    getrawmetatable = getFunction("getrawmetatable"),
    setrawmetatable = getFunction("setrawmetatable"),

    gethiddenproperty = getFunction("gethiddenproperty"),
    sethiddenproperty = getFunction("sethiddenproperty"),

    isreadonly = getFunction("isreadonly"),
    setreadonly = getFunction("setreadonly"),

    identifyexecutor = getFunction("identifyexecutor")
}

function Environment:Has(capability)
    return self.Capabilities[capability] == true
end

function Environment:Get(name)
    return self.API[name]
end

function Environment:IsExecutor(name)
    return string.lower(self.Executor.Name) == string.lower(name)
end

function Environment:GetExecutorName()
    return self.Executor.Name
end

function Environment:GetExecutorVersion()
    return self.Executor.Version
end

function Environment:GetInfo()
    local available = 0
    local total = 0

    for _, supported in pairs(self.Capabilities) do
        total += 1

        if supported then
            available += 1
        end
    end

    return {
        Executor = self.Executor.Name,
        Version = self.Executor.Version,
        Available = available,
        Total = total,
        Capabilities = self.Capabilities
    }
end

return Environment
