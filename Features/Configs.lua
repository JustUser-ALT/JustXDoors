local Configs = {}

local Settings
local Config
local Notifications

local Elements = {}

local function notify(title, description, time)
    Notifications:Info(
        title,
        description,
        time
    )
end

local function errorNotify(description)
    Notifications:Error(
        "Config",
        description
    )
end

function Configs:Init(Core)
    Settings = Core.Settings
    Config = Core.Config
    Notifications = Core.Notifications

    Elements = {}
end

function Configs:SetElements(elements)
    Elements = elements or {}
end

function Configs:GetSelected()
    local dropdown = Elements.ConfigDropdown

    if not dropdown then
        return nil
    end

    local value = dropdown.Value

    if not value
        or value == ""
        or value == "No configs"
    then
        return nil
    end

    return value
end

function Configs:GetName()
    local input = Elements.ConfigName

    if not input then
        return nil
    end

    local value = input.Value

    if not value
        or value == ""
    then
        return nil
    end

    return tostring(value)
end

function Configs:Refresh()
    local dropdown =
        Elements.ConfigDropdown

    if not dropdown then
        return
    end

    local configs = Config:List()

    if #configs == 0 then
        configs = {
            "No configs"
        }
    end

    pcall(function()
        dropdown:SetValues(configs)
        dropdown:SetValue(configs[1])
    end)
end

function Configs:Save()
    local name = self:GetName()

    if not name then
        errorNotify(
            "Enter a config name first."
        )

        return false
    end

    local success, result =
        Config:Save(
            name,
            Settings:Export()
        )

    if not success then
        errorNotify(
            tostring(result)
        )

        return false
    end

    self:Refresh()

    pcall(function()
        Elements.ConfigDropdown:SetValue(name)
    end)

    notify(
        "Config",
        "Saved: " .. name
    )

    return true
end

function Configs:Load(name)
    name = name or self:GetSelected()

    if not name then
        errorNotify(
            "No config selected."
        )

        return false
    end

    local success, data =
        Config:Load(name)

    if not success then
        errorNotify(
            tostring(data)
        )

        return false
    end

    if type(data) ~= "table" then
        errorNotify(
            "Invalid config data."
        )

        return false
    end

    Settings:Apply(data)

    notify(
        "Config",
        "Loaded: " .. name
    )

    return true, data
end

function Configs:Delete(name)
    name = name or self:GetSelected()

    if not name then
        errorNotify(
            "No config selected."
        )

        return false
    end

    local success, result =
        Config:Delete(name)

    if not success then
        errorNotify(
            tostring(result)
        )

        return false
    end

    self:Refresh()

    notify(
        "Config",
        "Deleted: " .. name
    )

    return true
end

function Configs:Rename(oldName, newName)
    oldName =
        oldName
        or self:GetSelected()

    newName =
        newName
        or self:GetName()

    if not oldName then
        errorNotify(
            "No config selected."
        )

        return false
    end

    if not newName
        or newName == ""
    then
        errorNotify(
            "Enter a new name."
        )

        return false
    end

    local success, result =
        Config:Rename(
            oldName,
            newName
        )

    if not success then
        errorNotify(
            tostring(result)
        )

        return false
    end

    self:Refresh()

    pcall(function()
        Elements.ConfigDropdown:SetValue(
            newName
        )
    end)

    notify(
        "Config",
        "Renamed successfully."
    )

    return true
end

function Configs:SetAutoload(name)
    name =
        name
        or self:GetSelected()

    if not name then
        errorNotify(
            "No config selected."
        )

        return false
    end

    local success, result =
        Config:SetAutoload(name)

    if not success then
        errorNotify(
            tostring(result)
        )

        return false
    end

    notify(
        "Config",
        "Autoload: " .. name
    )

    return true
end

function Configs:GetAutoload()
    return Config:GetAutoload()
end

function Configs:LoadAutoload()
    local success, data =
        Config:LoadAutoload()

    if not success then
        return false
    end

    if type(data) ~= "table" then
        return false
    end

    Settings:Apply(data)

    return true, data
end

function Configs:Reset()
    Settings:Reset()

    notify(
        "Config",
        "Settings restored to defaults."
    )

    return true
end

function Configs:List()
    return Config:List()
end

function Configs:Destroy()
    Elements = {}
end

return Configs
