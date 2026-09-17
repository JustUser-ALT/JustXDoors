local SettingsFeature = {}

local Settings
local Config
local Notifications
local UI

local Elements = {}
local Refreshing = false

local function get(path, fallback)
    local value = Settings:Get(path)

    if value == nil then
        return fallback
    end

    return value
end

local function notify(title, description, time)
    Notifications:Info(
        title,
        description,
        time
    )
end

local function setElementValue(element, value)
    if not element or value == nil then
        return
    end

    pcall(function()
        element:SetValue(value)
    end)
end

local function safeCall(callback)
    if Refreshing then
        return
    end

    if callback then
        callback()
    end
end

function SettingsFeature:Init(Core)
    Settings = Core.Settings
    Config = Core.Config
    Notifications = Core.Notifications
    UI = Core.UI

    Elements = {}
    Refreshing = false
end

function SettingsFeature:Build()
    local Tab = UI:AddTab("Settings")

    ------------------------------------------------------------
    -- INTERFACE
    ------------------------------------------------------------

    local InterfaceBox =
        UI:AddGroupbox(
            Tab,
            "Interface"
        )

    Elements.AlwaysOnTop =
        InterfaceBox:AddToggle(
            "SettingsAlwaysOnTop",
            {
                Text = "Always On Top",

                Default =
                    get(
                        "UI.AlwaysOnTop",
                        true
                    ),

                Callback = function(value)
                    safeCall(function()
                        Settings:Set(
                            "UI.AlwaysOnTop",
                            value
                        )

                        UI:SetAlwaysOnTop(value)
                    end)
                end
            }
        )

    Elements.CustomCursor =
        InterfaceBox:AddToggle(
            "SettingsCustomCursor",
            {
                Text = "Custom Cursor",

                Default =
                    get(
                        "UI.ShowCustomCursor",
                        false
                    ),

                Callback = function(value)
                    safeCall(function()
                        Settings:Set(
                            "UI.ShowCustomCursor",
                            value
                        )

                        if UI.Library then
                            UI.Library.ShowCustomCursor =
                                value
                        end
                    end)
                end
            }
        )

    Elements.CornerRadius =
        InterfaceBox:AddSlider(
            "SettingsCornerRadius",
            {
                Text = "Corner Radius",

                Min = 0,
                Max = 20,

                Default =
                    get(
                        "UI.CornerRadius",
                        8
                    ),

                Rounding = 0,

                Callback = function(value)
                    safeCall(function()
                        Settings:Set(
                            "UI.CornerRadius",
                            value
                        )

                        UI:SetCornerRadius(value)
                    end)
                end
            }
        )

    ------------------------------------------------------------
    -- NOTIFICATIONS
    ------------------------------------------------------------

    local NotificationsBox =
        UI:AddGroupbox(
            Tab,
            "Notifications"
        )

    Elements.Provider =
        NotificationsBox:AddDropdown(
            "NotificationProvider",
            {
                Values = {
                    "JustXDoors",
                    "Obsidian"
                },

                Default =
                    get(
                        "Notifications.Provider",
                        "JustXDoors"
                    ),

                Multi = false,

                Text = "Provider",

                Tooltip =
                    "Notification system",

                Callback = function(value)
                    safeCall(function()
                        if value ~= "JustXDoors"
                            and value ~= "Obsidian"
                        then
                            return
                        end

                        local success =
                            Notifications:SetProvider(
                                value
                            )

                        if not success then
                            return
                        end

                        Settings:Set(
                            "Notifications.Provider",
                            value
                        )

                        Notifications:Success(
                            "Notifications",
                            "Provider: " .. value
                        )
                    end)
                end
            }
        )

    Elements.NotifySide =
        NotificationsBox:AddDropdown(
            "NotificationSide",
            {
                Values = {
                    "Left",
                    "Right"
                },

                Default =
                    get(
                        "Notifications.Side",
                        "Right"
                    ),

                Multi = false,

                Text = "Position",

                Tooltip =
                    "Notification position",

                Callback = function(value)
                    safeCall(function()
                        if value ~= "Left"
                            and value ~= "Right"
                        then
                            return
                        end

                        Settings:Set(
                            "Notifications.Side",
                            value
                        )

                        Notifications:SetSide(
                            value
                        )
                    end)
                end
            }
        )

    Elements.Duration =
        NotificationsBox:AddSlider(
            "NotificationDuration",
            {
                Text = "Duration",

                Min = 1,
                Max = 15,

                Default =
                    get(
                        "Notifications.DefaultDuration",
                        4
                    ),

                Rounding = 1,

                Suffix = "s",

                Callback = function(value)
                    safeCall(function()
                        Settings:Set(
                            "Notifications.DefaultDuration",
                            value
                        )
                    end)
                end
            }
        )

    Elements.MaxVisible =
        NotificationsBox:AddSlider(
            "NotificationMaxVisible",
            {
                Text = "Max Visible",

                Min = 1,
                Max = 10,

                Default =
                    get(
                        "Notifications.MaxVisible",
                        5
                    ),

                Rounding = 0,

                Callback = function(value)
                    safeCall(function()
                        Settings:Set(
                            "Notifications.MaxVisible",
                            value
                        )
                    end)
                end
            }
        )

    Elements.Sound =
        NotificationsBox:AddToggle(
            "NotificationSound",
            {
                Text = "Notification Sound",

                Default =
                    get(
                        "Notifications.SoundEnabled",
                        false
                    ),

                Callback = function(value)
                    safeCall(function()
                        Settings:Set(
                            "Notifications.SoundEnabled",
                            value
                        )
                    end)
                end
            }
        )

    NotificationsBox:AddButton({
        Text = "Test Notification",

        Func = function()
            Notifications:Success(
                "JustXDoors",
                "Notification system is working!",
                get(
                    "Notifications.DefaultDuration",
                    4
                )
            )
        end
    })

    ------------------------------------------------------------
    -- CONFIG
    ------------------------------------------------------------

    local ConfigBox =
        UI:AddGroupbox(
            Tab,
            "Config"
        )

    local configs = Config:List()

    if #configs == 0 then
        configs = {
            "No configs"
        }
    end

    Elements.ConfigDropdown =
        ConfigBox:AddDropdown(
            "ConfigSelection",
            {
                Values = configs,

                Default = configs[1],

                Multi = false,

                Text = "Config",

                Tooltip =
                    "Select configuration"
            }
        )

    Elements.ConfigName =
        ConfigBox:AddInput(
            "ConfigName",
            {
                Text = "Config Name",

                Default = "Default",

                Placeholder =
                    "Enter config name...",

                Finished = true
            }
        )

    ------------------------------------------------------------
    -- SAVE
    ------------------------------------------------------------

    ConfigBox:AddButton({
        Text = "Save",

        Func = function()
            local name =
                Elements.ConfigName.Value

            if not name
                or name == ""
            then
                notify(
                    "Config",
                    "Enter a config name first."
                )

                return
            end

            local success, result =
                Config:Save(
                    name,
                    Settings:Export()
                )

            if not success then
                Notifications:Error(
                    "Config",
                    tostring(result)
                )

                return
            end

            notify(
                "Config",
                "Saved: " .. name
            )

            self:RefreshConfigs()
        end
    })

    ------------------------------------------------------------
    -- LOAD
    ------------------------------------------------------------

    ConfigBox:AddButton({
        Text = "Load",

        Func = function()
            local name =
                Elements.ConfigDropdown.Value

            if not name
                or name == "No configs"
            then
                notify(
                    "Config",
                    "No config selected."
                )

                return
            end

            local success, data =
                Config:Load(name)

            if not success then
                Notifications:Error(
                    "Config",
                    tostring(data)
                )

                return
            end

            if type(data) ~= "table" then
                Notifications:Error(
                    "Config",
                    "Invalid config data."
                )

                return
            end

            Settings:Apply(data)

            self:ApplyRuntimeSettings()

            self:RefreshUI()

            notify(
                "Config",
                "Loaded: " .. name
            )
        end
    })

    ------------------------------------------------------------
    -- DELETE
    ------------------------------------------------------------

    ConfigBox:AddButton({
        Text = "Delete",

        Func = function()
            local name =
                Elements.ConfigDropdown.Value

            if not name
                or name == "No configs"
            then
                notify(
                    "Config",
                    "No config selected."
                )

                return
            end

            local success, result =
                Config:Delete(name)

            if not success then
                Notifications:Error(
                    "Config",
                    tostring(result)
                )

                return
            end

            notify(
                "Config",
                "Deleted: " .. name
            )

            self:RefreshConfigs()
        end
    })

    ------------------------------------------------------------
    -- RENAME
    ------------------------------------------------------------

    ConfigBox:AddButton({
        Text = "Rename",

        Func = function()
            local oldName =
                Elements.ConfigDropdown.Value

            local newName =
                Elements.ConfigName.Value

            if not oldName
                or oldName == "No configs"
            then
                notify(
                    "Config",
                    "No config selected."
                )

                return
            end

            if not newName
                or newName == ""
            then
                notify(
                    "Config",
                    "Enter a new name."
                )

                return
            end

            local success, result =
                Config:Rename(
                    oldName,
                    newName
                )

            if not success then
                Notifications:Error(
                    "Config",
                    tostring(result)
                )

                return
            end

            notify(
                "Config",
                "Renamed successfully."
            )

            self:RefreshConfigs()

            setElementValue(
                Elements.ConfigDropdown,
                newName
            )
        end
    })

    ------------------------------------------------------------
    -- AUTOLOAD
    ------------------------------------------------------------

    ConfigBox:AddButton({
        Text = "Set Autoload",

        Func = function()
            local name =
                Elements.ConfigDropdown.Value

            if not name
                or name == "No configs"
            then
                notify(
                    "Config",
                    "No config selected."
                )

                return
            end

            local success, result =
                Config:SetAutoload(name)

            if success then
                notify(
                    "Config",
                    "Autoload: " .. name
                )
            else
                Notifications:Error(
                    "Config",
                    tostring(result)
                )
            end
        end
    })

    ConfigBox:AddButton({
        Text = "Load Autoload",

        Func = function()
            local success, data =
                Config:LoadAutoload()

            if not success then
                notify(
                    "Config",
                    "No autoload config."
                )

                return
            end

            if type(data) ~= "table" then
                Notifications:Error(
                    "Config",
                    "Invalid autoload config."
                )

                return
            end

            Settings:Apply(data)

            self:ApplyRuntimeSettings()

            self:RefreshUI()

            notify(
                "Config",
                "Autoload loaded."
            )
        end
    })

    ------------------------------------------------------------
    -- RESET
    ------------------------------------------------------------

    ConfigBox:AddButton({
        Text = "Reset Settings",

        Func = function()
            Settings:Reset()

            self:ApplyRuntimeSettings()

            self:RefreshUI()

            notify(
                "Settings",
                "Settings restored to defaults."
            )
        end
    })

    ------------------------------------------------------------
    -- DEBUG
    ------------------------------------------------------------

    local DebugBox =
        UI:AddGroupbox(
            Tab,
            "Debug"
        )

    Elements.Debug =
        DebugBox:AddToggle(
            "DebugMode",
            {
                Text = "Debug Mode",

                Default =
                    get(
                        "General.Debug",
                        false
                    ),

                Callback = function(value)
                    safeCall(function()
                        Settings:Set(
                            "General.Debug",
                            value
                        )
                    end)
                end
            }
        )

    DebugBox:AddButton({
        Text = "Test All Notifications",

        Func = function()
            Notifications:Info(
                "Info",
                "Information notification"
            )

            task.wait(0.15)

            Notifications:Success(
                "Success",
                "Success notification"
            )

            task.wait(0.15)

            Notifications:Warning(
                "Warning",
                "Warning notification"
            )

            task.wait(0.15)

            Notifications:Error(
                "Error",
                "Error notification"
            )
        end
    })

    ------------------------------------------------------------
    -- INITIAL SYNC
    ------------------------------------------------------------

    self:RefreshUI()

    return Tab
end

------------------------------------------------------------
-- REFRESH CONFIG DROPDOWN
------------------------------------------------------------

function SettingsFeature:RefreshConfigs()
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

    Refreshing = true

    pcall(function()
        dropdown:SetValues(configs)
        dropdown:SetValue(configs[1])
    end)

    Refreshing = false
end

------------------------------------------------------------
-- APPLY RUNTIME SETTINGS
------------------------------------------------------------

function SettingsFeature:ApplyRuntimeSettings()
    local provider =
        get(
            "Notifications.Provider",
            "JustXDoors"
        )

    local side =
        get(
            "Notifications.Side",
            "Right"
        )

    Notifications:SetProvider(
        provider
    )

    Notifications:SetSide(
        side
    )

    UI:SetAlwaysOnTop(
        get(
            "UI.AlwaysOnTop",
            true
        )
    )

    UI:SetCornerRadius(
        get(
            "UI.CornerRadius",
            8
        )
    )

    if UI.Library then
        UI.Library.ShowCustomCursor =
            get(
                "UI.ShowCustomCursor",
                false
            )
    end
end

------------------------------------------------------------
-- REFRESH ALL UI VALUES
------------------------------------------------------------

function SettingsFeature:RefreshUI()
    if not next(Elements) then
        return
    end

    Refreshing = true

    --------------------------------------------------------
    -- INTERFACE
    --------------------------------------------------------

    setElementValue(
        Elements.AlwaysOnTop,
        get(
            "UI.AlwaysOnTop",
            true
        )
    )

    setElementValue(
        Elements.CustomCursor,
        get(
            "UI.ShowCustomCursor",
            false
        )
    )

    setElementValue(
        Elements.CornerRadius,
        get(
            "UI.CornerRadius",
            8
        )
    )

    --------------------------------------------------------
    -- NOTIFICATIONS
    --------------------------------------------------------

    setElementValue(
        Elements.Provider,
        get(
            "Notifications.Provider",
            "JustXDoors"
        )
    )

    setElementValue(
        Elements.NotifySide,
        get(
            "Notifications.Side",
            "Right"
        )
    )

    setElementValue(
        Elements.Duration,
        get(
            "Notifications.DefaultDuration",
            4
        )
    )

    setElementValue(
        Elements.MaxVisible,
        get(
            "Notifications.MaxVisible",
            5
        )
    )

    setElementValue(
        Elements.Sound,
        get(
            "Notifications.SoundEnabled",
            false
        )
    )

    --------------------------------------------------------
    -- DEBUG
    --------------------------------------------------------

    setElementValue(
        Elements.Debug,
        get(
            "General.Debug",
            false
        )
    )

    --------------------------------------------------------
    -- FINISH
    --------------------------------------------------------

    Refreshing = false

    self:ApplyRuntimeSettings()
end

------------------------------------------------------------
-- DESTROY
------------------------------------------------------------

function SettingsFeature:Destroy()
    Elements = {}
    Refreshing = false
end

return SettingsFeature
