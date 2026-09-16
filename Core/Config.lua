local Config = {}

local Environment = require("Core/Environment")
local Services = require("Core/Services")

local writefile = Environment:Get("writefile")
local readfile = Environment:Get("readfile")
local isfile = Environment:Get("isfile")
local delfile = Environment:Get("delfile")
local listfiles = Environment:Get("listfiles")
local makefolder = Environment:Get("makefolder")
local isfolder = Environment:Get("isfolder")

local HttpService = Services.HttpService

Config.Folder = "JustXDoors"
Config.ConfigFolder = "JustXDoors/Configs"
Config.Extension = ".json"

Config.Current = {}
Config.Name = nil

Config.AutoloadName = nil

--------------------------------------------------
-- UTIL
--------------------------------------------------

local function normalizeName(name)
    name = tostring(name or "")

    name = name:gsub("[\\/:*?\"<>|]", "")
    name = name:gsub("^%s+", "")
    name = name:gsub("%s+$", "")

    if name == "" then
        return nil
    end

    return name
end

local function encode(data)
    local success, result = pcall(function()
        return HttpService:JSONEncode(data)
    end)

    if success then
        return result
    end

    return nil
end

local function decode(data)
    local success, result = pcall(function()
        return HttpService:JSONDecode(data)
    end)

    if success and type(result) == "table" then
        return result
    end

    return nil
end

local function ensureFolder(path)
    if not makefolder then
        return false
    end

    if isfolder then
        if isfolder(path) then
            return true
        end
    end

    local success = pcall(function()
        makefolder(path)
    end)

    return success
end

local function ensureFolders()
    ensureFolder(Config.Folder)
    ensureFolder(Config.ConfigFolder)
end

local function getPath(name)
    return Config.ConfigFolder
        .. "/"
        .. name
        .. Config.Extension
end

local function getAutoloadPath()
    return Config.Folder .. "/autoload.txt"
end

local function canUseFiles()
    return
        type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
end

--------------------------------------------------
-- BASIC
--------------------------------------------------

function Config:IsAvailable()
    return canUseFiles()
end

function Config:SetFolder(folder)
    folder = normalizeName(folder)

    if not folder then
        return false
    end

    Config.Folder = folder
    Config.ConfigFolder = folder .. "/Configs"

    ensureFolders()

    return true
end

function Config:Set(data)
    if type(data) ~= "table" then
        return false
    end

    Config.Current = data

    return true
end

function Config:Get()
    return Config.Current
end

function Config:GetName()
    return Config.Name
end

--------------------------------------------------
-- SAVE
--------------------------------------------------

function Config:Save(name, data)
    if not canUseFiles() then
        return false, "File API is unavailable"
    end

    name = normalizeName(name)

    if not name then
        return false, "Invalid config name"
    end

    ensureFolders()

    data = data or Config.Current

    if type(data) ~= "table" then
        return false, "Config data must be a table"
    end

    local encoded = encode(data)

    if not encoded then
        return false, "Failed to encode config"
    end

    local path = getPath(name)

    local success, errorMessage = pcall(function()
        writefile(path, encoded)
    end)

    if not success then
        return false, errorMessage
    end

    Config.Current = data
    Config.Name = name

    return true
end

--------------------------------------------------
-- LOAD
--------------------------------------------------

function Config:Load(name)
    if not canUseFiles() then
        return false, "File API is unavailable"
    end

    name = normalizeName(name)

    if not name then
        return false, "Invalid config name"
    end

    local path = getPath(name)

    if not isfile(path) then
        return false, "Config does not exist"
    end

    local success, contents = pcall(function()
        return readfile(path)
    end)

    if not success then
        return false, contents
    end

    local data = decode(contents)

    if not data then
        return false, "Failed to decode config"
    end

    Config.Current = data
    Config.Name = name

    return true, data
end

--------------------------------------------------
-- DELETE
--------------------------------------------------

function Config:Delete(name)
    if not delfile or not isfile then
        return false, "File API is unavailable"
    end

    name = normalizeName(name)

    if not name then
        return false, "Invalid config name"
    end

    local path = getPath(name)

    if not isfile(path) then
        return false, "Config does not exist"
    end

    local success, errorMessage = pcall(function()
        delfile(path)
    end)

    if not success then
        return false, errorMessage
    end

    if Config.Name == name then
        Config.Name = nil
        Config.Current = {}
    end

    if Config.AutoloadName == name then
        Config:SetAutoload(nil)
    end

    return true
end

--------------------------------------------------
-- EXISTS
--------------------------------------------------

function Config:Exists(name)
    if not isfile then
        return false
    end

    name = normalizeName(name)

    if not name then
        return false
    end

    return isfile(getPath(name))
end

--------------------------------------------------
-- LIST
--------------------------------------------------

function Config:List()
    if not listfiles then
        return {}
    end

    ensureFolders()

    local success, files = pcall(function()
        return listfiles(Config.ConfigFolder)
    end)

    if not success or type(files) ~= "table" then
        return {}
    end

    local configs = {}

    for _, path in ipairs(files) do

        local fileName =
            path:match("([^/\\]+)$")

        if fileName
            and fileName:sub(
                -#Config.Extension
            ) == Config.Extension
        then

            local name =
                fileName:sub(
                    1,
                    -#Config.Extension - 1
                )

            if name ~= "" then
                table.insert(
                    configs,
                    name
                )
            end
        end
    end

    table.sort(configs, function(a, b)
        return string.lower(a)
            < string.lower(b)
    end)

    return configs
end

--------------------------------------------------
-- RENAME
--------------------------------------------------

function Config:Rename(oldName, newName)
    if not canUseFiles()
        or not delfile
        or not writefile
    then
        return false, "File API is unavailable"
    end

    oldName = normalizeName(oldName)
    newName = normalizeName(newName)

    if not oldName or not newName then
        return false, "Invalid config name"
    end

    if oldName == newName then
        return false, "Names are identical"
    end

    if not self:Exists(oldName) then
        return false, "Source config does not exist"
    end

    if self:Exists(newName) then
        return false, "Target config already exists"
    end

    local success, data =
        self:Load(oldName)

    if not success then
        return false, data
    end

    local saved, errorMessage =
        self:Save(newName, data)

    if not saved then
        return false, errorMessage
    end

    local deleted, deleteError =
        self:Delete(oldName)

    if not deleted then
        return false, deleteError
    end

    Config.Name = newName

    if Config.AutoloadName == oldName then
        Config:SetAutoload(newName)
    end

    return true
end

--------------------------------------------------
-- RESET
--------------------------------------------------

function Config:Reset(data)
    if type(data) == "table" then
        Config.Current = data
    else
        Config.Current = {}
    end

    Config.Name = nil

    return Config.Current
end

function Config:Clear()
    Config.Current = {}
    Config.Name = nil
end

--------------------------------------------------
-- AUTOLOAD
--------------------------------------------------

function Config:SetAutoload(name)
    if not canUseFiles() then
        return false, "File API is unavailable"
    end

    ensureFolders()

    name = normalizeName(name)

    if not name then

        if delfile
            and isfile
            and isfile(getAutoloadPath())
        then

            pcall(function()
                delfile(getAutoloadPath())
            end)
        end

        Config.AutoloadName = nil

        return true
    end

    if not self:Exists(name) then
        return false, "Config does not exist"
    end

    local success, errorMessage = pcall(function()
        writefile(
            getAutoloadPath(),
            name
        )
    end)

    if not success then
        return false, errorMessage
    end

    Config.AutoloadName = name

    return true
end

function Config:GetAutoload()
    if Config.AutoloadName then
        return Config.AutoloadName
    end

    if not canUseFiles()
        or not isfile
        or not readfile
    then
        return nil
    end

    local path = getAutoloadPath()

    if not isfile(path) then
        return nil
    end

    local success, name = pcall(function()
        return readfile(path)
    end)

    if not success then
        return nil
    end

    name = normalizeName(name)

    Config.AutoloadName = name

    return name
end

function Config:ClearAutoload()
    return self:SetAutoload(nil)
end

--------------------------------------------------
-- AUTOLOAD CONFIG
--------------------------------------------------

function Config:LoadAutoload()
    local name = self:GetAutoload()

    if not name then
        return false, "No autoload config"
    end

    if not self:Exists(name) then
        self:ClearAutoload()
        return false, "Autoload config does not exist"
    end

    return self:Load(name)
end

--------------------------------------------------
-- STARTUP
--------------------------------------------------

ensureFolders()
Config:GetAutoload()

return Config
