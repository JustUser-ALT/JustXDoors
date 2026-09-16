local Config = {}

local Environment = require("Core/Environment")

local writefile = Environment:Get("writefile")
local readfile = Environment:Get("readfile")
local isfile = Environment:Get("isfile")
local delfile = Environment:Get("delfile")
local listfiles = Environment:Get("listfiles")
local makefolder = Environment:Get("makefolder")
local isfolder = Environment:Get("isfolder")

Config.Folder = "JustXDoors"
Config.ConfigFolder = Config.Folder .. "/Configs"
Config.Extension = ".json"

Config.Current = {}
Config.Name = nil

local function canUseFileAPI()
    return writefile and readfile and isfile
end

local function encode(data)
    local HttpService = game:GetService("HttpService")

    local success, result = pcall(function()
        return HttpService:JSONEncode(data)
    end)

    if success then
        return result
    end

    return nil
end

local function decode(data)
    local HttpService = game:GetService("HttpService")

    local success, result = pcall(function()
        return HttpService:JSONDecode(data)
    end)

    if success and type(result) == "table" then
        return result
    end

    return nil
end

local function ensureFolders()
    if not makefolder then
        return false
    end

    if isfolder and not isfolder(Config.Folder) then
        pcall(makefolder, Config.Folder)
    end

    if isfolder and not isfolder(Config.ConfigFolder) then
        pcall(makefolder, Config.ConfigFolder)
    end

    return true
end

local function getPath(name)
    return Config.ConfigFolder .. "/" .. name .. Config.Extension
end

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

function Config:IsAvailable()
    return canUseFileAPI()
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

function Config:Save(name, data)
    if not canUseFileAPI() then
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

function Config:Load(name)
    if not canUseFileAPI() then
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
    end

    return true
end

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
        local fileName = path:match("([^/\\]+)$")

        if fileName and fileName:sub(-#Config.Extension) == Config.Extension then
            local name = fileName:sub(1, -#Config.Extension - 1)

            if name ~= "" then
                table.insert(configs, name)
            end
        end
    end

    table.sort(configs)

    return configs
end

function Config:Rename(oldName, newName)
    if not canUseFileAPI() or not writefile or not delfile then
        return false, "File API is unavailable"
    end

    oldName = normalizeName(oldName)
    newName = normalizeName(newName)

    if not oldName or not newName then
        return false, "Invalid config name"
    end

    if not self:Exists(oldName) then
        return false, "Source config does not exist"
    end

    if self:Exists(newName) then
        return false, "Target config already exists"
    end

    local success, data = self:Load(oldName)

    if not success then
        return false, data
    end

    local saved, errorMessage = self:Save(newName, data)

    if not saved then
        return false, errorMessage
    end

    self:Delete(oldName)
    self.Name = newName

    return true
end

function Config:Reset(data)
    if type(data) ~= "table" then
        Config.Current = {}
    else
        Config.Current = data
    end

    Config.Name = nil

    return Config.Current
end

function Config:Clear()
    Config.Current = {}
    Config.Name = nil
end

function Config:GetName()
    return Config.Name
end

ensureFolders()

return Config
