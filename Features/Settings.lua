local SettingsFeature = {}

local Settings
local Notifications
local UI
local Configs

local Elements = {}

local Refreshing = false
local Built = false

------------------------------------------------------
-- HELPERS
------------------------------------------------------

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return false
    end

    local success, result = pcall(
        callback,
        ...
    )

    if not success then
        warn(
            "[JustXDoors Settings] "
                .. tostring(result)
        )

        return false
    end

    return true, result
end

local function getValue(element)
    if not element then
        return nil
    end

    return element.Value
end

local function setValue(element, value)
    if not element then
        return
    end

    if type(element.SetValue) ~= "function" then
        return
    end

    safeCall(
        function()
            element:SetValue(value)
        end
    )
end

local function notifyInfo(
    title,
    description,
    time
)
    if not Notifications then
        return
    end

    safeCall(
        function()
            Notifications:Info(
                title,
                description,
                time or 4
            )
        end
    )
end

local function notifySuccess(
    description,
    time
)
    if not Notifications then
        return
    end

    safeCall(
        function()
            Notifications:Success(
                "Settings",
                description,
                time or 4
            )
        end
    )
end

local function notifyError(
    description,
    time
)
    if not Notifications then
        return
    end

    safeCall(
        function()
            Notifications:Error(
                "Settings",
                description,
                time or 5
            )
        end
    )
end

------------------------------------------------------
-- INIT
------------------------------------------------------

function SettingsFeature:Init(Core)
    if type(Core) ~= "table" then
        return false
    end

    Settings = Core.Settings
    Notifications = Core.Notifications
    UI = Core.UI
    Configs = Core.Configs

    Elements = {}

    Refreshing = false
    Built = false

    return true
end

------------------------------------------------------
-- ELEMENT ACCESS
------------------------------------------------------

function SettingsFeature:GetElement(name)
    return Elements[name]
end

function SettingsFeature:GetElements()
    return Elements
end

------------------------------------------------------
-- APPLY RUNTIME SETTINGS
------------------------------------------------------

function SettingsFeature:ApplyRuntimeSettings()
    if not Settings then
        return false
    end

    --------------------------------------------------
    -- UI
    --------------------------------------------------

    local alwaysOnTop =
        Settings:Get(
            "UI.AlwaysOnTop"
        )

    local cornerRadius =
        Settings:Get(
            "UI.CornerRadius"
        )

    local customCursor =
        Settings:Get(
            "UI.ShowCustomCursor"
        )

    if UI then
        --------------------------------------------------
        -- Always On Top
        --------------------------------------------------

        if alwaysOnTop ~= nil then
            safeCall(
                function()
                    UI:SetAlwaysOnTop(
                        alwaysOnTop == true
                    )
                end
            )
        end

        --------------------------------------------------
        -- Corner Radius
        --------------------------------------------------

        if cornerRadius ~= nil then
            safeCall(
                function()
                    UI:SetCornerRadius(
                        tonumber(cornerRadius)
                            or 8
                    )
                end
            )
        end

        --------------------------------------------------
        -- Custom Cursor
        --
        -- Only call this if UI implements it.
        --------------------------------------------------

        if type(UI.SetCustomCursor)
            == "function"
        then
            safeCall(
                function()
                    UI:SetCustomCursor(
                        customCursor == true
                    )
                end
            )
        end
    end

    --------------------------------------------------
    -- NOTIFICATIONS
    --------------------------------------------------

    local provider =
        Settings:Get(
            "Notifications.Provider"
        )

    local side =
        Settings:Get(
            "Notifications.Side"
        )

    if Notifications then
        --------------------------------------------------
        -- Provider
        --------------------------------------------------

        if provider then
            safeCall(
                function()
                    Notifications:SetProvider(
                        tostring(provider)
                    )
                end
            )
        end

        --------------------------------------------------
        -- Side
        --------------------------------------------------

        if side then
            safeCall(
                function()
                    Notifications:SetSide(
                        tostring(side)
                    )
                end
            )
        end
    end

    return true
end

------------------------------------------------------
-- REFRESH UI
------------------------------------------------------

function SettingsFeature:RefreshUI()
    if not Settings then
        return false
    end

    Refreshing = true

    --------------------------------------------------
    -- Interface
    --------------------------------------------------

    setValue(
        Elements.AlwaysOnTop,
        Settings:Get(
            "UI.AlwaysOnTop"
        )
    )

    setValue(
        Elements.CustomCursor,
        Settings:Get(
            "UI.ShowCustomCursor"
        )
    )

    setValue(
        Elements.CornerRadius,
        Settings:Get(
            "UI.CornerRadius"
        )
    )

    --------------------------------------------------
    -- Notifications
    --------------------------------------------------

    setValue(
        Elements.NotificationProvider,
        Settings:Get(
            "Notifications.Provider"
        )
    )

    setValue(
        Elements.NotificationSide,
        Settings:Get(
            "Notifications.Side"
        )
    )

    setValue(
        Elements.NotificationDuration,
        Settings:Get(
            "Notifications.DefaultDuration"
        )
    )

    setValue(
        Elements.NotificationMaxVisible,
        Settings:Get(
            "Notifications.MaxVisible"
        )
    )

    setValue(
        Elements.NotificationSound,
        Settings:Get(
            "Notifications.SoundEnabled"
        )
    )

    Refreshing = false

    self:ApplyRuntimeSettings()

    return true
end

------------------------------------------------------
-- INTERFACE
------------------------------------------------------

function SettingsFeature:BuildInterface(
    groupbox
)
    if not groupbox then
        return false
    end

    --------------------------------------------------
    -- ALWAYS ON TOP
    --------------------------------------------------

    groupbox:AddToggle(
        "SettingsAlwaysOnTop",
        {
            Text = "Always On Top",

            Default = Settings:Get(
                "UI.AlwaysOnTop"
            ),

            Callback = function(value)
                if Refreshing then
                    return
                end

                Settings:Set(
                    "UI.AlwaysOnTop",
                    value == true
                )

                self:ApplyRuntimeSettings()
            end
        }
    )

    Elements.AlwaysOnTop =
        groupbox:Get(
            "SettingsAlwaysOnTop"
        )

    --------------------------------------------------
    -- CUSTOM CURSOR
    --------------------------------------------------

    groupbox:AddToggle(
        "SettingsCustomCursor",
        {
            Text = "Custom Cursor",

            Default = Settings:Get(
                "UI.ShowCustomCursor"
            ),

            Callback = function(value)
                if Refreshing then
                    return
                end

                Settings:Set(
                    "UI.ShowCustomCursor",
                    value == true
                )

                self:ApplyRuntimeSettings()
            end
        }
    )

    Elements.CustomCursor =
        groupbox:Get(
            "SettingsCustomCursor"
        )

    --------------------------------------------------
    -- CORNER RADIUS
    --------------------------------------------------

    groupbox:AddSlider(
        "SettingsCornerRadius",
        {
            Text = "Corner Radius",

            Default =
                Settings:Get(
                    "UI.CornerRadius"
                ) or 8,

            Min = 0,
            Max = 20,

            Rounding = 0,

            Callback = function(value)
                if Refreshing then
                    return
                end

                value =
                    tonumber(value)
                    or 8

                Settings:Set(
                    "UI.CornerRadius",
                    value
                )

                self:ApplyRuntimeSettings()
            end
        }
    )

    Elements.CornerRadius =
        groupbox:Get(
            "SettingsCornerRadius"
        )

    return true
end

------------------------------------------------------
-- NOTIFICATIONS
------------------------------------------------------

function SettingsFeature:BuildNotifications(
    groupbox
)
    if not groupbox then
        return false
    end

    --------------------------------------------------
    -- PROVIDER
    --------------------------------------------------

    groupbox:AddDropdown(
        "SettingsNotificationProvider",
        {
            Text = "Provider",

            Values = {
                "JustXDoors",
                "Obsidian"
            },

            Default =
                Settings:Get(
                    "Notifications.Provider"
                ),

            Callback = function(value)
                if Refreshing then
                    return
                end

                value =
                    tostring(value)

                if not Notifications then
                    return
                end

                local success =
                    safeCall(
                        function()
                            return Notifications:SetProvider(
                                value
                            )
                        end
                    )

                if success then
                    Settings:Set(
                        "Notifications.Provider",
                        value
                    )
                end
            end
        }
    )

    Elements.NotificationProvider =
        groupbox:Get(
            "SettingsNotificationProvider"
        )

    --------------------------------------------------
    -- POSITION
    --------------------------------------------------

    groupbox:AddDropdown(
        "SettingsNotificationSide",
        {
            Text = "Position",

            Values = {
                "Left",
                "Right"
            },

            Default =
                Settings:Get(
                    "Notifications.Side"
                ),

            Callback = function(value)
                if Refreshing then
                    return
                end

                value =
                    tostring(value)

                Settings:Set(
                    "Notifications.Side",
                    value
                )

                if Notifications then
                    safeCall(
                        function()
                            Notifications:SetSide(
                                value
                            )
                        end
                    )
                end
            end
        }
    )

    Elements.NotificationSide =
        groupbox:Get(
            "SettingsNotificationSide"
        )

    --------------------------------------------------
    -- DURATION
    --------------------------------------------------

    groupbox:AddSlider(
        "SettingsNotificationDuration",
        {
            Text = "Duration",

            Default =
                Settings:Get(
                    "Notifications.DefaultDuration"
                ) or 4,

            Min = 1,
            Max = 15,

            Rounding = 1,

            Callback = function(value)
                if Refreshing then
                    return
                end

                Settings:Set(
                    "Notifications.DefaultDuration",
                    tonumber(value)
                        or 4
                )
            end
        }
    )

    Elements.NotificationDuration =
        groupbox:Get(
            "SettingsNotificationDuration"
        )

    --------------------------------------------------
    -- MAX VISIBLE
    --------------------------------------------------

    groupbox:AddSlider(
        "SettingsNotificationMaxVisible",
        {
            Text = "Max Visible",

            Default =
                Settings:Get(
                    "Notifications.MaxVisible"
                ) or 5,

            Min = 1,
            Max = 10,

            Rounding = 0,

            Callback = function(value)
                if Refreshing then
                    return
                end

                Settings:Set(
                    "Notifications.MaxVisible",
                    tonumber(value)
                        or 5
                )
            end
        }
    )

    Elements.NotificationMaxVisible =
        groupbox:Get(
            "SettingsNotificationMaxVisible"
        )

    --------------------------------------------------
    -- SOUND
    --------------------------------------------------

    groupbox:AddToggle(
        "SettingsNotificationSound",
        {
            Text = "Notification Sound",

            Default =
                Settings:Get(
                    "Notifications.SoundEnabled"
                ),

            Callback = function(value)
                if Refreshing then
                    return
                end

                Settings:Set(
                    "Notifications.SoundEnabled",
                    value == true
                )
            end
        }
    )

    Elements.NotificationSound =
        groupbox:Get(
            "SettingsNotificationSound"
        )

    --------------------------------------------------
    -- TEST
    --------------------------------------------------

    groupbox:AddButton(
        {
            Text = "Test Notification",

            Func = function()
                if not Notifications then
                    return
                end

                Notifications:Info(
                    "JustXDoors",
                    "Notification system is working.",
                    Settings:Get(
                        "Notifications.DefaultDuration"
                    ) or 4
                )
            end
        }
    )

    return true
end

------------------------------------------------------
-- CONFIGS
------------------------------------------------------

function SettingsFeature:BuildConfigs(
    groupbox
)
    if not groupbox then
        return false
    end

    --------------------------------------------------
    -- CONFIG DROPDOWN
    --------------------------------------------------

    groupbox:AddDropdown(
        "SettingsConfigDropdown",
        {
            Text = "Config",

            Values = {
                "No configs"
            },

            Default = "No configs",

            Callback = function()
                -- Config selection is read
                -- directly by Features/Configs.lua.
            end
        }
    )

    Elements.ConfigDropdown =
        groupbox:Get(
            "SettingsConfigDropdown"
        )

    --------------------------------------------------
    -- CONFIG NAME
    --------------------------------------------------

    groupbox:AddInput(
        "SettingsConfigName",
        {
            Text = "Config Name",

            Default = "",

            Placeholder =
                "Enter config name",

            Numeric = false,

            Finished = false,

            Callback = function()
                -- Value is read by Configs.lua.
            end
        }
    )

    Elements.ConfigName =
        groupbox:Get(
            "SettingsConfigName"
        )

    --------------------------------------------------
    -- GIVE ELEMENTS TO CONFIG FEATURE
    --------------------------------------------------

    if Configs then
        safeCall(
            function()
                Configs:SetElements(
                    {
                        ConfigDropdown =
                            Elements.ConfigDropdown,

                        ConfigName =
                            Elements.ConfigName
                    }
                )
            end
        )
    end

    --------------------------------------------------
    -- SAVE
    --------------------------------------------------

    groupbox:AddButton(
        {
            Text = "Save Config",

            Func = function()
                if not Configs then
                    notifyError(
                        "Config system is unavailable."
                    )

                    return
                end

                Configs:Save()
            end
        }
    )

    --------------------------------------------------
    -- LOAD
    --------------------------------------------------

    groupbox:AddButton(
        {
            Text = "Load Config",

            Func = function()
                if not Configs then
                    notifyError(
                        "Config system is unavailable."
                    )

                    return
                end

                local success =
                    Configs:Load()

                if success then
                    self:RefreshUI()

                    notifySuccess(
                        "Config loaded and applied."
                    )
                end
            end
        }
    )

    --------------------------------------------------
    -- DELETE
    --------------------------------------------------

    groupbox:AddButton(
        {
            Text = "Delete Config",

            Func = function()
                if not Configs then
                    notifyError(
                        "Config system is unavailable."
                    )

                    return
                end

                Configs:Delete()
            end
        }
    )

    --------------------------------------------------
    -- RENAME
    --------------------------------------------------

    groupbox:AddButton(
        {
            Text = "Rename Config",

            Func = function()
                if not Configs then
                    notifyError(
                        "Config system is unavailable."
                    )

                    return
                end

                Configs:Rename()
            end
        }
    )

    --------------------------------------------------
    -- SET AUTOLOAD
    --------------------------------------------------

    groupbox:AddButton(
        {
            Text = "Set Autoload",

            Func = function()
                if not Configs then
                    notifyError(
                        "Config system is unavailable."
                    )

                    return
                end

                Configs:SetAutoload()
            end
        }
    )

    --------------------------------------------------
    -- LOAD AUTOLOAD
    --------------------------------------------------

    groupbox:AddButton(
        {
            Text = "Load Autoload",

            Func = function()
                if not Configs then
                    notifyError(
                        "Config system is unavailable."
                    )

                    return
                end

                local success =
                    Configs:LoadAutoload()

                if success then
                    self:RefreshUI()

                    notifySuccess(
                        "Autoload config applied."
                    )
                end
            end
        }
    )

    --------------------------------------------------
    -- RESET
    --------------------------------------------------

    groupbox:AddButton(
        {
            Text = "Reset Settings",

            Func = function()
                if not Configs then
                    notifyError(
                        "Config system is unavailable."
                    )

                    return
                end

                local success =
                    Configs:Reset()

                if success then
                    self:RefreshUI()

                    notifyInfo(
                        "Settings",
                        "All settings restored to defaults.",
                        4
                    )
                end
            end
        }
    )

    --------------------------------------------------
    -- INITIAL REFRESH
    --------------------------------------------------

    if Configs then
        safeCall(
            function()
                Configs:Refresh()
            end
        )
    end

    return true
end

------------------------------------------------------
-- BUILD
------------------------------------------------------

function SettingsFeature:Build()
    if Built then
        return true
    end

    if not UI then
        warn(
            "[JustXDoors Settings] UI is unavailable."
        )

        return false
    end

    if not Settings then
        warn(
            "[JustXDoors Settings] Settings is unavailable."
        )

        return false
    end

    --------------------------------------------------
    -- SETTINGS TAB
    --------------------------------------------------

    local tab =
        UI:AddTab(
            "Settings",
            "settings"
        )

    if not tab then
        warn(
            "[JustXDoors Settings] Failed to create tab."
        )

        return false
    end

    --------------------------------------------------
    -- INTERFACE
    --------------------------------------------------

    local interfaceGroup =
        UI:AddLeftGroupbox(
            tab,
            "Interface"
        )

    self:BuildInterface(
        interfaceGroup
    )

    --------------------------------------------------
    -- NOTIFICATIONS
    --------------------------------------------------

    local notificationGroup =
        UI:AddRightGroupbox(
            tab,
            "Notifications"
        )

    self:BuildNotifications(
        notificationGroup
    )

    --------------------------------------------------
    -- CONFIGS
    --------------------------------------------------

    local configGroup =
        UI:AddLeftGroupbox(
            tab,
            "Configs"
        )

    self:BuildConfigs(
        configGroup
    )

    --------------------------------------------------
    -- APPLY
    --------------------------------------------------

    self:ApplyRuntimeSettings()
    self:RefreshUI()

    Built = true

    return true
end

------------------------------------------------------
-- DESTROY
------------------------------------------------------

function SettingsFeature:Destroy()
    if Configs then
        safeCall(
            function()
                Configs:SetElements({})
            end
        )
    end

    Elements = {}

    Refreshing = false
    Built = false

    return true
end

return SettingsFeature
