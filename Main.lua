local Main = {}

local Core
local Services
local Connections
local Config
local Notifications
local UI

Main.Initialized = false
Main.Unloaded = false

Main.Tabs = {}
Main.Groups = {}
Main.Elements = {}

local DEFAULT_CONFIG = {
    UI = {
        Scale = 100,
        CornerRadius = 8,
        NotifySide = "Right",
        AlwaysOnTop = true,
    },

    Menu = {
        ToggleKey = "RightControl",
    },

    General = {
        AutoLoadConfig = true,
        LastConfig = nil,
    }
}

local function copyTable(source)
    local result = {}

    for key, value in pairs(source) do
        if type(value) == "table" then
            result[key] = copyTable(value)
        else
            result[key] = value
        end
    end

    return result
end

local function mergeDefaults(target, defaults)
    for key, defaultValue in pairs(defaults) do
        if target[key] == nil then
            if type(defaultValue) == "table" then
                target[key] = copyTable(defaultValue)
            else
                target[key] = defaultValue
            end
        elseif type(defaultValue) == "table" and type(target[key]) == "table" then
            mergeDefaults(target[key], defaultValue)
        end
    end

    return target
end

local function getConfig()
    local current = Config:Get()

    if type(current) ~= "table" then
        current = {}
    end

    mergeDefaults(current, DEFAULT_CONFIG)

    Config:Set(current)

    return current
end

local function saveCurrentConfig()
    local config = getConfig()

    if not Config:GetName() then
        return false
    end

    return Config:Save(Config:GetName(), config)
end

function Main:CreateWindow()
    local window = UI:Create()

    if not window then
        return nil
    end

    return window
end

function Main:CreateTabs()
    local window = UI.Window

    if not window then
        return false
    end

    self.Tabs.Main = UI:AddTab(
        "Main",
        "home",
        "Main features"
    )

    self.Tabs.Hotel = UI:AddTab(
        "Hotel",
        "door-open",
        "Hotel features"
    )

    self.Tabs.Mines = UI:AddTab(
        "Mines",
        "pickaxe",
        "Mines features"
    )

    self.Tabs.Backdoors = UI:AddTab(
        "Backdoors",
        "door-closed",
        "Backdoor features"
    )

    self.Tabs.Outdoors = UI:AddTab(
        "Outdoors",
        "trees",
        "Outdoors features"
    )

    self.Tabs.Archives = UI:AddTab(
        "Archives",
        "archive",
        "Archives features"
    )

    self.Tabs.Stairwell = UI:AddTab(
        "Stairwell",
        "stairs",
        "Stairwell features"
    )

    self.Tabs.Settings = UI:AddTab(
        "Settings",
        "settings",
        "JustXDoors settings"
    )

    return true
end

function Main:CreateMainTab()
    local tab = self.Tabs.Main

    if not tab then
        return
    end

    local information = UI:AddLeftGroupbox(
        tab,
        "JustXDoors",
        "sparkles"
    )

    UI:AddLabel(
        information,
        "JustXDoors"
    )

    UI:AddLabel(
        information,
        "Modular Doors hub"
    )

    local status = UI:AddRightGroupbox(
        tab,
        "Status",
        "activity"
    )

    UI:AddLabel(
        status,
        "Core loaded"
    )

    UI:AddLabel(
        status,
        "Game features will be added here."
    )

    self.Groups.MainInformation = information
    self.Groups.MainStatus = status
end

function Main:CreateSettingsTab()
    local tab = self.Tabs.Settings

    if not tab then
        return
    end

    local config = getConfig()

    local configBox = UI:AddLeftGroupbox(
        tab,
        "Configuration",
        "folder-cog"
    )

    local configName = UI:AddInput(
        configBox,
        "ConfigName",
        {
            Text = "Config Name",
            Default = Config:GetName() or "Default",
            Placeholder = "Enter config name...",
            Finished = true
        }
    )

    self.Elements.ConfigName = configName

    UI:AddButton(
        configBox,
        "SaveConfig",
        function()
            local name = configName.Value

            if not name or tostring(name):match("^%s*$") then
                Notifications:Warning(
                    "Configuration",
                    "Enter a config name first."
                )

                return
            end

            local success, errorMessage = Config:Save(
                name,
                getConfig()
            )

            if success then
                config.General.LastConfig = name

                Notifications:Success(
                    "Configuration",
                    "Config saved: " .. tostring(name)
                )
            else
                Notifications:Error(
                    "Configuration",
                    tostring(errorMessage)
                )
            end
        end
    )

    UI:AddButton(
        configBox,
        "LoadConfig",
        function()
            local name = configName.Value

            if not name or tostring(name):match("^%s*$") then
                Notifications:Warning(
                    "Configuration",
                    "Enter a config name first."
                )

                return
            end

            local success, data = Config:Load(name)

            if success then
                mergeDefaults(data, DEFAULT_CONFIG)

                Notifications:Success(
                    "Configuration",
                    "Config loaded: " .. tostring(name)
                )
            else
                Notifications:Error(
                    "Configuration",
                    tostring(data)
                )
            end
        end
    )

    UI:AddButton(
        configBox,
        "DeleteConfig",
        function()
            local name = configName.Value

            if not name or tostring(name):match("^%s*$") then
                return
            end

            local success, errorMessage = Config:Delete(name)

            if success then
                Notifications:Success(
                    "Configuration",
                    "Config deleted: " .. tostring(name)
                )
            else
                Notifications:Error(
                    "Configuration",
                    tostring(errorMessage)
                )
            end
        end
    )

    UI:AddButton(
        configBox,
        "RefreshConfigs",
        function()
            local configs = Config:List()

            Notifications:Info(
                "Configuration",
                "Found " .. tostring(#configs) .. " config(s)."
            )
        end
    )

    UI:AddDivider(configBox)

    local autoLoad = UI:AddToggle(
        configBox,
        "AutoLoadConfig",
        {
            Text = "Auto Load Config",
            Default = config.General.AutoLoadConfig,
            Callback = function(value)
                config.General.AutoLoadConfig = value
                saveCurrentConfig()
            end
        }
    )

    self.Elements.AutoLoadConfig = autoLoad

    local uiBox = UI:AddRightGroupbox(
        tab,
        "Interface",
        "panels-top-left"
    )

    local scale = UI:AddSlider(
        uiBox,
        "UIScale",
        {
            Text = "UI Scale",
            Default = config.UI.Scale,
            Min = 75,
            Max = 150,
            Rounding = 0,
            Suffix = "%",
            Callback = function(value)
                config.UI.Scale = value

                if UI.Library then
                    pcall(function()
                        UI.Library:SetDPIScale(value)
                    end)
                end
            end
        }
    )

    self.Elements.UIScale = scale

    local cornerRadius = UI:AddSlider(
        uiBox,
        "CornerRadius",
        {
            Text = "Corner Radius",
            Default = config.UI.CornerRadius,
            Min = 0,
            Max = 20,
            Rounding = 0,
            Callback = function(value)
                config.UI.CornerRadius = value
                UI:SetCornerRadius(value)
            end
        }
    )

    self.Elements.CornerRadius = cornerRadius

    local alwaysOnTop = UI:AddToggle(
        uiBox,
        "AlwaysOnTop",
        {
            Text = "Always On Top",
            Default = config.UI.AlwaysOnTop,
            Callback = function(value)
                config.UI.AlwaysOnTop = value
                UI:SetAlwaysOnTop(value)
            end
        }
    )

    self.Elements.AlwaysOnTop = alwaysOnTop

    local notifySide = UI:AddDropdown(
        uiBox,
        "NotifySide",
        {
            Text = "Notification Side",
            Values = {
                "Left",
                "Right"
            },
            Default = config.UI.NotifySide,
            Callback = function(value)
                config.UI.NotifySide = value
                UI:SetNotifySide(value)
            end
        }
    )

    self.Elements.NotifySide = notifySide

    UI:AddDivider(uiBox)

    UI:AddButton(
        uiBox,
        "Unload",
        function()
            self:Unload()
        end
    )
end

function Main:LoadLastConfig()
    local config = getConfig()

    if not config.General.AutoLoadConfig then
        return
    end

    local lastConfig = config.General.LastConfig

    if not lastConfig then
        return
    end

    if not Config:Exists(lastConfig) then
        return
    end

    local success = Config:Load(lastConfig)

    if success then
        Notifications:Info(
            "JustXDoors",
            "Loaded config: " .. tostring(lastConfig)
        )
    end
end

function Main:ApplyConfig()
    local config = getConfig()

    if config.UI.Scale then
        pcall(function()
            UI.Library:SetDPIScale(config.UI.Scale)
        end)
    end

    if config.UI.CornerRadius then
        UI:SetCornerRadius(config.UI.CornerRadius)
    end

    UI:SetAlwaysOnTop(
        config.UI.AlwaysOnTop
    )

    UI:SetNotifySide(
        config.UI.NotifySide
    )
end

function Main:SetupUnload()
    UI:OnUnload(function()
        self:Unload(true)
    end)
end

function Main:Init(core)
    if self.Initialized then
        return self
    end

    Core = core

    Services = Core.Services
    Connections = Core.Connections
    Config = Core.Config
    Notifications = Core.Notifications
    UI = Core.UI

    self:CreateWindow()
    self:CreateTabs()
    self:CreateMainTab()
    self:CreateSettingsTab()
    self:LoadLastConfig()
    self:ApplyConfig()
    self:SetupUnload()

    self.Initialized = true
    self.Unloaded = false

    Notifications:Success(
        "JustXDoors",
        "Interface initialized."
    )

    return self
end

function Main:Unload(fromLibrary)
    if self.Unloaded then
        return
    end

    self.Unloaded = true

    if Connections then
        Connections:DisconnectAll()
    end

    if not fromLibrary and UI then
        UI:Unload()
    end

    self.Tabs = {}
    self.Groups = {}
    self.Elements = {}

    self.Initialized = false
end

return Main
