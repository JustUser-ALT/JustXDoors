local Settings = {}

local DEFAULTS = {
    General = {
        Debug = false
    },

    UI = {
        Title = "JustXDoors",
        Footer = "DOORS",
        Icon = nil,

        Width = 720,
        Height = 520,

        Center = true,
        AutoShow = true,
        Resizable = true,
        AlwaysOnTop = true,

        MobileButtonsSide = "Right",
        NotifySide = "Right",

        ShowCustomCursor = false,

        CornerRadius = 8
    },

    Notifications = {
        Provider = "JustXDoors",

        Side = "Right",

        DefaultDuration = 4,
        MaxVisible = 5,

        SoundEnabled = false,
        SoundId = nil,
        SoundVolume = 0.5,

        JustXDoors = {
            Width = 330,
            Height = 72,

            Gap = 8,
            Offset = 14,

            CornerRadius = 10,

            AnimationTime = 0.22,

            ProgressBar = true,
            ClickToDismiss = true
        }
    }
}

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}

    for key, child in pairs(value) do
        result[key] = deepCopy(child)
    end

    return result
end

local function merge(target, source)
    for key, value in pairs(source) do
        if type(value) == "table"
            and type(target[key]) == "table"
        then
            merge(target[key], value)
        else
            target[key] = deepCopy(value)
        end
    end
end

local function splitPath(path)
    local parts = {}

    for part in string.gmatch(
        tostring(path or ""),
        "[^%.]+"
    ) do
        table.insert(parts, part)
    end

    return parts
end

Settings.Data = deepCopy(DEFAULTS)

function Settings:Get(path)
    local parts = splitPath(path)

    if #parts == 0 then
        return nil
    end

    local current = self.Data

    for _, part in ipairs(parts) do
        if type(current) ~= "table" then
            return nil
        end

        current = current[part]

        if current == nil then
            return nil
        end
    end

    return current
end

function Settings:Set(path, value)
    local parts = splitPath(path)

    if #parts == 0 then
        return false
    end

    local current = self.Data

    for index = 1, #parts - 1 do
        local part = parts[index]

        if type(current[part]) ~= "table" then
            current[part] = {}
        end

        current = current[part]
    end

    current[parts[#parts]] = value

    return true
end

function Settings:Apply(data)
    if type(data) ~= "table" then
        return false
    end

    merge(self.Data, data)

    return true
end

function Settings:Export()
    return deepCopy(self.Data)
end

function Settings:GetDefaults()
    return deepCopy(DEFAULTS)
end

function Settings:Reset()
    self.Data = deepCopy(DEFAULTS)

    return self.Data
end

function Settings:ResetSection(section)
    if DEFAULTS[section] == nil then
        return false
    end

    self.Data[section] =
        deepCopy(DEFAULTS[section])

    return true
end

function Settings:Has(path)
    return self:Get(path) ~= nil
end

return Settings
