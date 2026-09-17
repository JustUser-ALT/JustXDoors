local SettingsFeature = {}

local Settings
local Config
local Notifications
local UI
local Connections

local Elements = {}

local function notify(title, description, time)
    Notifications:Info(title, description, time)
end

local function getProvider()
    return Settings:Get("Notifications.Provider") or "JustXDoors"
end

local function getNotifySide()
    return Settings:Get("Notifications.Side") or "Right"
end

function SettingsFeature:Init(Core)
    Settings = Core.Settings
    Config = Core.Config
    Notifications = Core.Notifications
    UI = Core.UI
    Connections = Core.Connections

    Elements = {}
end

function SettingsFeature:Build()
    local Tab = UI:AddTab("Settings")

    ----------------------------------------------------------------
    -- INTERFACE
    ----------------------------------------------------------------

    local InterfaceBox = UI:AddGroupbox(Tab, "Interface")

    InterfaceBox:AddToggle("SettingsAlwaysOnTop", {
        Text = "Always On Top",

        Default = Settings:Get("UI.AlwaysOnTop"),

        Callback = function(value)
            Settings:Set("UI.AlwaysOnTop", value)
            UI:SetAlwaysOnTop(value)
        end
    })

    InterfaceBox:AddToggle("SettingsCustomCursor", {
        Text = "Custom Cursor",

        Default = Settings:Get("UI.ShowCustomCursor"),

        Callback = function(value)
            Settings:Set("UI.ShowCustomCursor", value)

            local Library = UI.Library

            if Library then
                Library.ShowCustomCursor = value
            end
        end
    })

    InterfaceBox:AddSlider("SettingsCornerRadius", {
        Text = "Corner Radius",

        Min = 0,
        Max = 20,

        Default = Settings:Get("UI.CornerRadius") or 8,

        Rounding = 0,

        Callback = function(value)
            Settings:Set("UI.CornerRadius", value)
            UI:SetCornerRadius(value)
        end
    })

    ----------------------------------------------------------------
    -- NOTIFICATIONS
    ----------------------------------------------------------------

    local NotificationsBox = UI:AddGroupbox(
        Tab,
        "Notifications"
    )

    Elements.Provider = NotificationsBox:AddDropdown(
        "NotificationProvider",
        {
            Values = {
                "JustXDoors",
                "Obsidian"
            },

            Default = getProvider(),

            Multi = false,

            Text = "Provider",

            Tooltip = "Choose the notification system",

            Callback = function(value)
                if value ~= "JustXDoors"
                    and value ~= "Obsidian"
                then
                    return
                end

                Settings:Set(
                    "Notifications.Provider",
                    value
                )

                local success =
                    Notifications:SetProvider(value)

                if not success then
                    Settings:Set(
                        "Notifications.Provider",
                        "JustXDoors"
                    )

                    if Elements.Provider then
                        Elements.Provider:SetValue(
                            "JustXDoors"
                        )
                    end

                    Notifications:Warning(
                        "Notifications",
                        "Obsidian provider is unavailable."
                    )

                    return
                end

                Notifications:Success(
                    "Notifications",
                    "Provider switched to " .. value
                )
            end
        }
    )

    Elements.NotifySide = NotificationsBox:AddDropdown(
        "NotificationSide",
        {
            Values = {
                "Left",
                "Right"
            },

            Default = getNotifySide(),

            Multi = false,

            Text = "Position",

            Tooltip = "Notification position on screen",

            Callback = function(value)
                if value ~= "Left"
                    and value ~= "Right"
                then
                    return
                end

                Settings:Set(
                    "Notifications.Side",
                    value
                )

                Notifications:SetSide(value)
            end
        }
    )

    Elements.Duration = NotificationsBox:AddSlider(
        "NotificationDuration",
        {
            Text = "Duration",

            Min = 1,
            Max = 15,

            Default =
                Settings:Get(
                    "Notifications.DefaultDuration"
                ) or 4,

            Rounding = 1,

            Suffix = "s",

            Callback = function(value)
                Settings:Set(
                    "Notifications.DefaultDuration",
                    value
                )
            end
        }
    )

    Elements.MaxVisible = NotificationsBox:AddSlider(
        "NotificationMaxVisible",
        {
            Text = "Max Visible",

            Min = 1,
            Max = 10,

            Default =
                Settings:Get(
                    "Notifications.MaxVisible"
                ) or 5,

            Rounding = 0,

            Callback = function(value)
                Settings:Set(
                    "Notifications.MaxVisible",
                    value
                )
            end
        }
    )

    NotificationsBox:AddToggle(
        "NotificationSound",
        {
            Text = "Notification Sound",

            Default =
                Settings:Get(
                    "Notifications.SoundEnabled"
                ) or false,

            Callback = function(value)
                Settings:Set(
                    "Notifications.SoundEnabled",
                    value
                )
            end
        }
    )

    NotificationsBox:AddButton({
        Text = "Test Notification",

        Func = function()
            Notifications:Success(
                "JustXDoors",
                "Notification system is working!",
                Settings:Get(
                    "Notifications.DefaultDuration"
                ) or 4
            )
        end
    })

    ----------------------------------------------------------------
    -- CONFIG
    ----------------------------------------------------------------

    local ConfigBox = UI:AddGroupbox(
        Tab,
        "Config"
    )

    local configNames = Config:List()

    if #configNames == 0 then
        configNames = {
            "No configs"
        }
    end

    Elements.ConfigDropdown = ConfigBox:AddDropdown(
        "ConfigSelection",
        {
            Values = configNames,

            Default = configNames[1],

            Multi = false,

            Text = "Config",

            Tooltip = "Select a saved configuration"
        }
    )

    Elements.ConfigName = ConfigBox:AddInput(
        "ConfigName",
        {
            Text = "Config Name",

            Default = "Default",

            Placeholder = "Enter config name...",

            Finished = true
        }
    )

    ConfigBox:AddButton({
        Text = "Save",

        Func = function()
            local name = Elements.ConfigName.Value

            if not name or name == "" then
                notify(
                    "Config",
                    "Enter a config name first."
                )

                return
            end

            local data = Settings:Export()

            local success, result =
                Config:Save(name, data)

            if success then
                notify(
                    "Config",
                    "Saved: " .. name
                )

                self:RefreshConfigs()
            else
                Notifications:Error(
                    "Config",
                    tostring(result)
                )
            end
        end
    })

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

            notify(
                "Config",
                "Loaded: " .. name
            )
        end
    })

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
        end
    })

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

            notify(
                "Config",
                "Autoload config loaded."
            )
        end
    })

    ConfigBox:AddButton({
        Text = "Reset Settings",

        Func = function()
            Settings:Reset()

            self:ApplyRuntimeSettings()

            notify(
                "Settings",
                "Settings restored to defaults."
            )
        end
    })

    ----------------------------------------------------------------
    -- DEBUG
    ----------------------------------------------------------------

    local DebugBox = UI:AddGroupbox(
        Tab,
        "Debug"
    )

    DebugBox:AddToggle(
        "DebugMode",
        {
            Text = "Debug Mode",

            Default =
                Settings:Get("General.Debug"),

            Callback = function(value)
                Settings:Set(
                    "General.Debug",
                    value
                )
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

    return Tab
end

function SettingsFeature:RefreshConfigs()
    if not Elements.ConfigDropdown then
        return
    end

    local configs = Config:List()

    if #configs == 0 then
        configs = {
            "No configs"
        }
    end

    Elements.ConfigDropdown:SetValues(configs)
    Elements.ConfigDropdown:SetValue(configs[1])
end

function SettingsFeature:ApplyRuntimeSettings()
    local provider =
        Settings:Get("Notifications.Provider")

    if provider then
        Notifications:SetProvider(provider)
    end

    local side =
        Settings:Get("Notifications.Side")

    if side then
        Notifications:SetSide(side)
    end

    local alwaysOnTop =
        Settings:Get("UI.AlwaysOnTop")

    if alwaysOnTop ~= nil then
        UI:SetAlwaysOnTop(alwaysOnTop)
    end

    local radius =
        Settings:Get("UI.CornerRadius")

    if radius then
        UI:SetCornerRadius(radius)
    end

    local cursor =
        Settings:Get("UI.ShowCustomCursor")

    if cursor ~= nil
        and UI.Library
    then
        UI.Library.ShowCustomCursor = cursor
    end

    if Elements.Provider then
        Elements.Provider:SetValue(
            provider or "JustXDoors"
        )
    end

    if Elements.NotifySide then
        Elements.NotifySide:SetValue(
            side or "Right"
        )
    end
end

function SettingsFeature:Destroy()
    Elements = {}
end

return SettingsFeature
