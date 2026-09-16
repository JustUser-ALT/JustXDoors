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

--------------------------------------------------
-- DEFAULT CONFIG
--------------------------------------------------

local DEFAULT_CONFIG = {
    UI = {
        Scale = 100,
        CornerRadius = 8,
        NotifySide = "Right",
        AlwaysOnTop = true
    },

    Menu = {
        ToggleKey = "RightControl"
    },

    General = {
        AutoLoadConfig = true,
        LastConfig = nil
    }
}

--------------------------------------------------
-- COPY
--------------------------------------------------

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

--------------------------------------------------
-- MERGE
--------------------------------------------------

local function mergeDefaults(
    target,
    defaults
)

    for key, defaultValue in pairs(defaults) do

        if target[key] == nil then

            if type(defaultValue) == "table" then
                target[key] =
                    copyTable(defaultValue)
            else
                target[key] =
                    defaultValue
            end

        elseif type(defaultValue) == "table"
            and type(target[key]) == "table"
        then

            mergeDefaults(
                target[key],
                defaultValue
            )

        end
    end

    return target
end

--------------------------------------------------
-- CONFIG STATE
--------------------------------------------------

local function getConfig()

    local current =
        Config:Get()

    if type(current) ~= "table" then
        current = {}
    end

    mergeDefaults(
        current,
        DEFAULT_CONFIG
    )

    Config:Set(current)

    return current
end

--------------------------------------------------
-- UI STATE
--------------------------------------------------

local function getUIRegistry()

    if not UI.Library then
        return nil
    end

    local registry = {
        Options = UI.Library.Options,
        Toggles = UI.Library.Toggles
    }

    return registry
end

--------------------------------------------------
-- SERIALIZE UI
--------------------------------------------------

local function captureUI()

    local registry =
        getUIRegistry()

    if not registry then
        return {}
    end

    local result = {}

    --------------------------------------------------
    -- Options
    --------------------------------------------------

    if type(registry.Options) == "table" then

        for id, option in pairs(
            registry.Options
        ) do

            if type(option) == "table"
                and option.Value ~= nil
            then

                local value =
                    option.Value

                if type(value) == "table" then

                    local copy = {}

                    for key, item in pairs(value) do
                        copy[key] = item
                    end

                    result[id] = copy

                elseif type(value) == "string"
                    or type(value) == "number"
                    or type(value) == "boolean"
                then

                    result[id] = value

                end
            end
        end
    end

    --------------------------------------------------
    -- Toggles
    --------------------------------------------------

    if type(registry.Toggles) == "table" then

        for id, toggle in pairs(
            registry.Toggles
        ) do

            if type(toggle) == "table"
                and toggle.Value ~= nil
            then

                result[id] =
                    toggle.Value
            end
        end
    end

    return result
end

--------------------------------------------------
-- APPLY UI
--------------------------------------------------

local function applyUI(data)

    if type(data) ~= "table" then
        return
    end

    local registry =
        getUIRegistry()

    if not registry then
        return
    end

    --------------------------------------------------
    -- Options
    --------------------------------------------------

    if type(registry.Options) == "table" then

        for id, value in pairs(data) do

            local option =
                registry.Options[id]

            if option
                and type(option.SetValue)
                    == "function"
            then

                pcall(function()
                    option:SetValue(value)
                end)

            end
        end
    end

    --------------------------------------------------
    -- Toggles
    --------------------------------------------------

    if type(registry.Toggles) == "table" then

        for id, value in pairs(data) do

            local toggle =
                registry.Toggles[id]

            if toggle
                and type(toggle.SetValue)
                    == "function"
            then

                pcall(function()
                    toggle:SetValue(value)
                end)

            end
        end
    end
end

--------------------------------------------------
-- BUILD SAVE DATA
--------------------------------------------------

local function buildSaveData()

    local config =
        getConfig()

    return {
        Version = 1,

        UI = copyTable(
            config.UI
        ),

        Menu = copyTable(
            config.Menu
        ),

        General = copyTable(
            config.General
        ),

        Elements = captureUI()
    }
end

--------------------------------------------------
-- APPLY SAVE DATA
--------------------------------------------------

local function applySaveData(data)

    if type(data) ~= "table" then
        return
    end

    local config =
        getConfig()

    if type(data.UI) == "table" then
        mergeDefaults(
            config.UI,
            data.UI
        )
    end

    if type(data.Menu) == "table" then
        mergeDefaults(
            config.Menu,
            data.Menu
        )
    end

    if type(data.General) == "table" then
        mergeDefaults(
            config.General,
            data.General
        )
    end

    Config:Set(config)

    if type(data.Elements) == "table" then
        applyUI(
            data.Elements
        )
    end
end

--------------------------------------------------
-- SAVE CURRENT
--------------------------------------------------

local function saveCurrentConfig(name)

    if not name then
        return false,
            "Config name is required"
    end

    local data =
        buildSaveData()

    return Config:Save(
        name,
        data
    )
end

--------------------------------------------------
-- CONFIG DROPDOWN
--------------------------------------------------

local function refreshConfigDropdown(
    selectedName
)

    local dropdown =
        Main.Elements.ConfigList

    if not dropdown then
        return
    end

    local configs =
        Config:List()

    local values = {}

    for _, name in ipairs(configs) do
        table.insert(
            values,
            name
        )
    end

    if #values == 0 then
        values = {
            "No configs"
        }
    end

    pcall(function()

        dropdown:SetValues(
            values
        )

    end)

    local target =
        selectedName

        or Config:GetName()

        or values[1]

    if target
        and target ~= "No configs"
    then

        pcall(function()

            dropdown:SetValue(
                target
            )

        end)

    end
end

--------------------------------------------------
-- CREATE WINDOW
--------------------------------------------------

function Main:CreateWindow()

    local window =
        UI:Create()

    if not window then
        return nil
    end

    return window
end

--------------------------------------------------
-- TABS
--------------------------------------------------

function Main:CreateTabs()

    local window =
        UI.Window

    if not window then
        return false
    end

    self.Tabs.Main =
        UI:AddTab(
            "Main",
            "home",
            "Main features"
        )

    self.Tabs.Hotel =
        UI:AddTab(
            "Hotel",
            "door-open",
            "Hotel features"
        )

    self.Tabs.Mines =
        UI:AddTab(
            "Mines",
            "pickaxe",
            "Mines features"
        )

    self.Tabs.Backdoors =
        UI:AddTab(
            "Backdoors",
            "door-closed",
            "Backdoor features"
        )

    self.Tabs.Outdoors =
        UI:AddTab(
            "Outdoors",
            "trees",
            "Outdoors features"
        )

    self.Tabs.Archives =
        UI:AddTab(
            "Archives",
            "archive",
            "Archives features"
        )

    self.Tabs.Stairwell =
        UI:AddTab(
            "Stairwell",
            "stairs",
            "Stairwell features"
        )

    self.Tabs.Settings =
        UI:AddTab(
            "Settings",
            "settings",
            "JustXDoors settings"
        )

    return true
end

--------------------------------------------------
-- MAIN TAB
--------------------------------------------------

function Main:CreateMainTab()

    local tab =
        self.Tabs.Main

    if not tab then
        return
    end

    local information =
        UI:AddLeftGroupbox(
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

    local status =
        UI:AddRightGroupbox(
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

    self.Groups.MainInformation =
        information

    self.Groups.MainStatus =
        status
end

--------------------------------------------------
-- SETTINGS
--------------------------------------------------

function Main:CreateSettingsTab()

    local tab =
        self.Tabs.Settings

    if not tab then
        return
    end

    local config =
        getConfig()

    --------------------------------------------------
    -- CONFIGURATION
    --------------------------------------------------

    local configBox =
        UI:AddLeftGroupbox(
            tab,
            "Configuration",
            "folder-cog"
        )

    --------------------------------------------------
    -- CONFIG NAME
    --------------------------------------------------

    local configName =
        UI:AddInput(
            configBox,
            "ConfigName",
            {
                Text = "Config Name",

                Default =
                    Config:GetName()
                    or "Default",

                Placeholder =
                    "Enter config name...",

                Finished = true
            }
        )

    self.Elements.ConfigName =
        configName

    --------------------------------------------------
    -- CONFIG LIST
    --------------------------------------------------

    local configs =
        Config:List()

    local configValues = {}

    for _, name in ipairs(configs) do
        table.insert(
            configValues,
            name
        )
    end

    if #configValues == 0 then
        configValues = {
            "No configs"
        }
    end

    local configList =
        UI:AddDropdown(
            configBox,
            "ConfigList",
            {
                Text = "Saved Configs",

                Values =
                    configValues,

                Default =
                    configValues[1],

                Callback = function(value)

                    if value
                        and value ~= "No configs"
                    then

                        pcall(function()

                            configName:SetValue(
                                value
                            )

                        end)

                    end
                end
            }
        )

    self.Elements.ConfigList =
        configList

    --------------------------------------------------
    -- SAVE
    --------------------------------------------------

    UI:AddButton(
        configBox,
        "SaveConfig",
        function()

            local name

            if configName then
                name = configName.Value
            end

            name =
                tostring(name or "")

            name =
                name:gsub("^%s+", "")
                    :gsub("%s+$", "")

            if name == "" then

                Notifications:Warning(
                    "Configuration",
                    "Enter a config name first."
                )

                return
            end

            local success,
                errorMessage =
                saveCurrentConfig(name)

            if success then

                config.General.LastConfig =
                    name

                Config:Set(config)

                refreshConfigDropdown(
                    name
                )

                Notifications:Success(
                    "Configuration",
                    "Config saved: " ..
                    name
                )

            else

                Notifications:Error(
                    "Configuration",
                    tostring(
                        errorMessage
                    )
                )
            end
        end
    )

    --------------------------------------------------
    -- LOAD
    --------------------------------------------------

    UI:AddButton(
        configBox,
        "LoadConfig",
        function()

            local name

            if configList then
                name =
                    configList.Value
            end

            if not name
                or name == "No configs"
            then

                if configName then
                    name =
                        configName.Value
                end

            end

            if not name
                or tostring(name) == ""
            then

                Notifications:Warning(
                    "Configuration",
                    "Select a config first."
                )

                return
            end

            local success,
                data =
                Config:Load(name)

            if success then

                applySaveData(
                    data
                )

                config =
                    getConfig()

                config.General.LastConfig =
                    name

                Config:Set(config)

                pcall(function()
                    configName:SetValue(
                        name
                    )
                end)

                refreshConfigDropdown(
                    name
                )

                Notifications:Success(
                    "Configuration",
                    "Config loaded: " ..
                    name
                )

            else

                Notifications:Error(
                    "Configuration",
                    tostring(data)
                )
            end
        end
    )

    --------------------------------------------------
    -- OVERWRITE
    --------------------------------------------------

    UI:AddButton(
        configBox,
        "OverwriteConfig",
        function()

            local name

            if configList then
                name =
                    configList.Value
            end

            if not name
                or name == "No configs"
            then

                if configName then
                    name =
                        configName.Value
                end

            end

            if not name
                or tostring(name) == ""
            then

                Notifications:Warning(
                    "Configuration",
                    "Select a config first."
                )

                return
            end

            if not Config:Exists(name) then

                Notifications:Warning(
                    "Configuration",
                    "Config does not exist."
                )

                return
            end

            local success,
                errorMessage =
                saveCurrentConfig(name)

            if success then

                config.General.LastConfig =
                    name

                Config:Set(config)

                Notifications:Success(
                    "Configuration",
                    "Config overwritten: " ..
                    name
                )

            else

                Notifications:Error(
                    "Configuration",
                    tostring(
                        errorMessage
                    )
                )
            end
        end
    )

    --------------------------------------------------
    -- DELETE
    --------------------------------------------------

    UI:AddButton(
        configBox,
        "DeleteConfig",
        function()

            local name

            if configList then
                name =
                    configList.Value
            end

            if not name
                or name == "No configs"
            then
                return
            end

            local success,
                errorMessage =
                Config:Delete(name)

            if success then

                refreshConfigDropdown()

                pcall(function()
                    configName:SetValue(
                        ""
                    )
                end)

                Notifications:Success(
                    "Configuration",
                    "Config deleted: " ..
                    name
                )

            else

                Notifications:Error(
                    "Configuration",
                    tostring(
                        errorMessage
                    )
                )
            end
        end
    )

    --------------------------------------------------
    -- RENAME
    --------------------------------------------------

    UI:AddButton(
        configBox,
        "RenameConfig",
        function()

            local oldName

            if configList then
                oldName =
                    configList.Value
            end

            local newName

            if configName then
                newName =
                    configName.Value
            end

            if not oldName
                or oldName == "No configs"
            then

                Notifications:Warning(
                    "Configuration",
                    "Select a config first."
                )

                return
            end

            if not newName
                or tostring(newName) == ""
            then

                Notifications:Warning(
                    "Configuration",
                    "Enter the new name."
                )

                return
            end

            local success,
                errorMessage =
                Config:Rename(
                    oldName,
                    newName
                )

            if success then

                refreshConfigDropdown(
                    newName
                )

                Notifications:Success(
                    "Configuration",
                    "Renamed to: " ..
                    tostring(newName)
                )

            else

                Notifications:Error(
                    "Configuration",
                    tostring(
                        errorMessage
                    )
                )
            end
        end
    )

    --------------------------------------------------
    -- REFRESH
    --------------------------------------------------

    UI:AddButton(
        configBox,
        "RefreshConfigs",
        function()

            refreshConfigDropdown()

            local configs =
                Config:List()

            Notifications:Info(
                "Configuration",
                "Found " ..
                tostring(#configs) ..
                " config(s)."
            )
        end
    )

    --------------------------------------------------
    -- AUTO LOAD
    --------------------------------------------------

    UI:AddDivider(
        configBox
    )

    local autoloadName =
        Config:GetAutoload()

    local autoLoad =
        UI:AddToggle(
            configBox,
            "AutoLoadConfig",
            {
                Text = "Auto Load Selected",

                Default =
                    config.General.AutoLoadConfig,

                Callback = function(value)

                    config.General.AutoLoadConfig =
                        value

                    if value then

                        local selected

                        if configList then
                            selected =
                                configList.Value
                        end

                        if selected
                            and selected ~= "No configs"
                        then

                            local success,
                                errorMessage =
                                Config:SetAutoload(
                                    selected
                                )

                            if not success then

                                Notifications:Error(
                                    "Configuration",
                                    tostring(
                                        errorMessage
                                    )
                                )

                            else

                                Notifications:Success(
                                    "Configuration",
                                    "Autoload set to " ..
                                    selected
                                )

                            end
                        end

                    else

                        Config:ClearAutoload()

                    end

                    Config:Set(config)
                end
            }
        )

    self.Elements.AutoLoadConfig =
        autoLoad

    --------------------------------------------------
    -- AUTOLOAD INFO
    --------------------------------------------------

    local autoloadText =
        autoloadName
        and (
            "Autoload: " ..
            tostring(autoloadName)
        )
        or
        "Autoload: None"

    UI:AddLabel(
        configBox,
        autoloadText
    )

    --------------------------------------------------
    -- INTERFACE
    --------------------------------------------------

    local uiBox =
        UI:AddRightGroupbox(
            tab,
            "Interface",
            "panels-top-left"
        )

    --------------------------------------------------
    -- UI SCALE
    --------------------------------------------------

    local scale =
        UI:AddSlider(
            uiBox,
            "UIScale",
            {
                Text = "UI Scale",

                Default =
                    config.UI.Scale,

                Min = 75,

                Max = 150,

                Rounding = 0,

                Suffix = "%",

                Callback = function(value)

                    config.UI.Scale =
                        value

                    if UI.Library then

                        pcall(function()

                            UI.Library:SetDPIScale(
                                value
                            )

                        end)

                    end

                end
            }
        )

    self.Elements.UIScale =
        scale

    --------------------------------------------------
    -- CORNER
    --------------------------------------------------

    local cornerRadius =
        UI:AddSlider(
            uiBox,
            "CornerRadius",
            {
                Text = "Corner Radius",

                Default =
                    config.UI.CornerRadius,

                Min = 0,

                Max = 20,

                Rounding = 0,

                Callback = function(value)

                    config.UI.CornerRadius =
                        value

                    UI:SetCornerRadius(
                        value
                    )

                end
            }
        )

    self.Elements.CornerRadius =
        cornerRadius

    --------------------------------------------------
    -- ALWAYS ON TOP
    --------------------------------------------------

    local alwaysOnTop =
        UI:AddToggle(
            uiBox,
            "AlwaysOnTop",
            {
                Text = "Always On Top",

                Default =
                    config.UI.AlwaysOnTop,

                Callback = function(value)

                    config.UI.AlwaysOnTop =
                        value

                    UI:SetAlwaysOnTop(
                        value
                    )

                end
            }
        )

    self.Elements.AlwaysOnTop =
        alwaysOnTop

    --------------------------------------------------
    -- NOTIFY SIDE
    --------------------------------------------------

    local notifySide =
        UI:AddDropdown(
            uiBox,
            "NotifySide",
            {
                Text =
                    "Notification Side",

                Values = {
                    "Left",
                    "Right"
                },

                Default =
                    config.UI.NotifySide,

                Callback = function(value)

                    config.UI.NotifySide =
                        value

                    UI:SetNotifySide(
                        value
                    )

                end
            }
        )

    self.Elements.NotifySide =
        notifySide

    --------------------------------------------------
    -- UNLOAD
    --------------------------------------------------

    UI:AddDivider(
        uiBox
    )

    UI:AddButton(
        uiBox,
        "Unload",
        function()
            self:Unload()
        end
    )
end

--------------------------------------------------
-- AUTO LOAD LAST
--------------------------------------------------

function Main:LoadLastConfig()

    local config =
        getConfig()

    if not config.General.AutoLoadConfig then
        return
    end

    local name =
        Config:GetAutoload()

    if not name then
        return
    end

    local success,
        data =
        Config:Load(name)

    if not success then

        Notifications:Warning(
            "Configuration",
            "Failed to autoload: " ..
            tostring(data)
        )

        return
    end

    applySaveData(data)

    config =
        getConfig()

    config.General.LastConfig =
        name

    Config:Set(config)

    refreshConfigDropdown(
        name
    )

    Notifications:Info(
        "JustXDoors",
        "Loaded config: " ..
        tostring(name)
    )
end

--------------------------------------------------
-- APPLY CONFIG
--------------------------------------------------

function Main:ApplyConfig()

    local config =
        getConfig()

    if config.UI.Scale then

        pcall(function()

            UI.Library:SetDPIScale(
                config.UI.Scale
            )

        end)

    end

    if config.UI.CornerRadius then

        UI:SetCornerRadius(
            config.UI.CornerRadius
        )

    end

    UI:SetAlwaysOnTop(
        config.UI.AlwaysOnTop
    )

    UI:SetNotifySide(
        config.UI.NotifySide
    )
end

--------------------------------------------------
-- UNLOAD
--------------------------------------------------

function Main:SetupUnload()

    UI:OnUnload(function()
        self:Unload(true)
    end)
end

function Main:Unload(
    fromLibrary
)

    if self.Unloaded then
        return
    end

    self.Unloaded = true

    if Connections then
        Connections:DisconnectAll()
    end

    if not fromLibrary
        and UI
    then

        UI:Unload()

    end

    self.Tabs = {}
    self.Groups = {}
    self.Elements = {}

    self.Initialized = false
end

--------------------------------------------------
-- INIT
--------------------------------------------------

function Main:Init(core)

    if self.Initialized then
        return self
    end

    Core = core

    Services =
        Core.Services

    Connections =
        Core.Connections

    Config =
        Core.Config

    Notifications =
        Core.Notifications

    UI =
        Core.UI

    --------------------------------------------------
    -- WINDOW
    --------------------------------------------------

    self:CreateWindow()

    --------------------------------------------------
    -- TABS
    --------------------------------------------------

    self:CreateTabs()

    --------------------------------------------------
    -- MAIN
    --------------------------------------------------

    self:CreateMainTab()

    --------------------------------------------------
    -- SETTINGS
    --------------------------------------------------

    self:CreateSettingsTab()

    --------------------------------------------------
    -- CONFIG
    --------------------------------------------------

    self:LoadLastConfig()

    self:ApplyConfig()

    --------------------------------------------------
    -- UNLOAD
    --------------------------------------------------

    self:SetupUnload()

    self.Initialized = true
    self.Unloaded = false

    Notifications:Success(
        "JustXDoors",
        "Interface initialized."
    )

    return self
end

return Main
