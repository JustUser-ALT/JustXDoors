local SettingsFeature = {}

local Settings
local Config
local Notifications
local UI
local Configs
local Environment

local Elements = {}

local Refreshing = false
local Built = false

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return false
    end

    local success, result = pcall(callback, ...)

    if not success then
        warn("[JustXDoors Settings] " .. tostring(result))
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

    pcall(function()
        element:SetValue(value)
    end)
end

local function notifyInfo(title, description, time)
    if not Notifications then
        return
    end

    safeCall(
        function()
            Notifications:Info(
                title,
                description,
                time
            )
        end
    )
end

local function notifyError(description)
    if not Notifications then
        return
    end

    safeCall(
        function()
            Notifications:Error(
                "Settings",
                description
            )
        end
    )
end

local function notifySuccess(description)
    if not Notifications then
        return
    end

    safeCall(
        function()
            Notifications:Success(
                "Settings",
                description
            )
        end
    )
end

local function bool(value)
    return value == true
end

function SettingsFeature:Init(Core)
    if type(Core) ~= "table" then
        return false
    end

    Settings = Core.Settings
    Config = Core.Config
    Notifications = Core.Notifications
    UI = Core.UI
    Configs = Core.Configs
    Environment = Core.Environment

    Elements = {}

    Built = false
    Refreshing = false

    return true
end

function SettingsFeature:GetElement(name)
    return Elements[name]
end

function SettingsFeature:GetElements()
    return Elements
end

function SettingsFeature:ApplyRuntimeSettings()
    if not Settings then
        return false
    end

    --------------------------------------------------
    -- UI
    --------------------------------------------------

    local alwaysOnTop =
        Settings:Get("UI.AlwaysOnTop")

    local cornerRadius =
        Settings:Get("UI.CornerRadius")

    local showCustomCursor =
        Settings:Get("UI.ShowCustomCursor")

    if UI then
        if alwaysOnTop ~= nil then
            safeCall(
                function()
                    UI:SetAlwaysOnTop(
                        bool(alwaysOnTop)
                    )
                end
            )
        end

        if cornerRadius ~= nil then
            safeCall(
                function()
                    UI:SetCornerRadius(
                        tonumber(cornerRadius) or 8
                    )
                end
            )
        end
    end

    --------------------------------------------------
    -- Notifications
    --------------------------------------------------

    local provider =
        Settings:Get("Notifications.Provider")

    local side =
        Settings:Get("Notifications.Side")

    if Notifications then
        if provider then
            safeCall(
                function()
                    Notifications:SetProvider(
                        provider
                    )
                end
            )
        end

        if side then
            safeCall(
                function()
                    Notifications:SetSide(side)
                end
            )
        end
    end

    --------------------------------------------------
    -- Custom cursor
    --
    -- Actual cursor implementation can be handled
    -- by Core/UI later. Here we only keep the setting
    -- synchronized.
    --------------------------------------------------

    if UI and type(UI.SetCustomCursor) == "function" then
        safeCall(
            function()
                UI:SetCustomCursor(
                    bool(showCustomCursor)
                )
            end
        )
    end

    return true
end

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
        Settings:Get("UI.AlwaysOnTop")
    )

    setValue(
        Elements.CustomCursor,
        Settings:Get("UI.ShowCustomCursor")
    )

    setValue(
        Elements.CornerRadius,
        Settings:Get("UI.CornerRadius")
    )

    --------------------------------------------------
    -- Notifications
    --------------------------------------------------

    setValue(
        Elements.NotificationProvider,
        Settings:Get("Notifications.Provider")
    )

    setValue(
        Elements.NotificationSide,
        Settings:Get("Notifications.Side")
    )

    setValue(
        Elements.NotificationDuration,
        Settings:Get("Notifications.DefaultDuration")
    )

    setValue(
        Elements.NotificationMaxVisible,
        Settings:Get("Notifications.MaxVisible")
    )

    setValue(
        Elements.NotificationSound,
        Settings:Get("Notifications.SoundEnabled")
    )

    --------------------------------------------------
    -- Debug
    --------------------------------------------------

    setValue(
        Elements.DebugMode,
        Settings:Get("General.Debug")
    )

    Refreshing = false

    self:ApplyRuntimeSettings()

    return true
end

------------------------------------------------------
-- INTERFACE
------------------------------------------------------

function SettingsFeature:BuildInterface(groupbox)
    if not groupbox then
        return
    end

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
                    value
                )

                self:ApplyRuntimeSettings()
            end
        }
    )

    Elements.AlwaysOnTop =
        groupbox:Get("SettingsAlwaysOnTop")

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
                    value
                )

                self:ApplyRuntimeSettings()
            end
        }
    )

    Elements.CustomCursor =
        groupbox:Get("SettingsCustomCursor")

    groupbox:AddSlider(
        "SettingsCornerRadius",
        {
            Text = "Corner Radius",
            Default = Settings:Get(
                "UI.CornerRadius"
            ) or 8,

            Min = 0,
            Max = 20,
            Rounding = 0,

            Callback = function(value)
                if Refreshing then
                    return
                end

                Settings:Set(
                    "UI.CornerRadius",
                    value
                )

                self:ApplyRuntimeSettings()
            end
        }
    )

    Elements.CornerRadius =
        groupbox:Get("SettingsCornerRadius")
end

------------------------------------------------------
-- NOTIFICATIONS
------------------------------------------------------

function SettingsFeature:BuildNotifications(groupbox)
    if not groupbox then
        return
    end

    groupbox:AddDropdown(
        "SettingsNotificationProvider",
        {
            Text = "Provider",

            Values = {
                "JustXDoors",
                "Obsidian"
            },

            Default = Settings:Get(
                "Notifications.Provider"
            ),

            Callback = function(value)
                if Refreshing then
                    return
                end

                value = tostring(value)

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

    groupbox:AddDropdown(
        "SettingsNotificationSide",
        {
            Text = "Position",

            Values = {
                "Left",
                "Right"
            },

            Default = Settings:Get(
                "Notifications.Side"
            ),

            Callback = function(value)
                if Refreshing then
                    return
                end

                value = tostring(value)

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

    groupbox:AddSlider(
        "SettingsNotificationDuration",
        {
            Text = "Duration",

            Default = Settings:Get(
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
                    value
                )
            end
        }
    )

    Elements.NotificationDuration =
        groupbox:Get(
            "SettingsNotificationDuration"
        )

    groupbox:AddSlider(
        "SettingsNotificationMaxVisible",
        {
            Text = "Max Visible",

            Default = Settings:Get(
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
                    value
                )
            end
        }
    )

    Elements.NotificationMaxVisible =
        groupbox:Get(
            "SettingsNotificationMaxVisible"
        )

    groupbox:AddToggle(
        "SettingsNotificationSound",
        {
            Text = "Notification Sound",

            Default = Settings:Get(
                "Notifications.SoundEnabled"
            ),

            Callback = function(value)
                if Refreshing then
                    return
                end

                Settings:Set(
                    "Notifications.SoundEnabled",
                    value
                )
            end
        }
    )

    Elements.NotificationSound =
        groupbox:Get(
            "SettingsNotificationSound"
        )

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
                    4
                )
            end
        }
    )
end

------------------------------------------------------
-- CONFIGS
------------------------------------------------------

function SettingsFeature:BuildConfigs(groupbox)
    if not groupbox then
        return
    end

    --------------------------------------------------
    -- Config dropdown
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
                -- Selection is handled by Features/Configs.lua.
            end
        }
    )

    Elements.ConfigDropdown =
        groupbox:Get(
            "SettingsConfigDropdown"
        )

    --------------------------------------------------
    -- Config name
    --------------------------------------------------

    groupbox:AddInput(
        "SettingsConfigName",
        {
            Text = "Config Name",

            Default = "",

            Placeholder = "Enter config name",

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
    -- Pass UI references to Configs.lua
    --------------------------------------------------

    if Configs then
        Configs:SetElements(
            {
                ConfigDropdown =
                    Elements.ConfigDropdown,

                ConfigName =
                    Elements.ConfigName
            }
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
                    return
                end

                local success =
                    Configs:Load()

                if success then
                    self:ApplyRuntimeSettings()
                    self:RefreshUI()
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
                    return
                end

                Configs:Rename()
            end
        }
    )

    --------------------------------------------------
    -- AUTOLOAD
    --------------------------------------------------

    groupbox:AddButton(
        {
            Text = "Set Autoload",

            Func = function()
                if not Configs then
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
                    return
                end

                local success =
                    Configs:LoadAutoload()

                if success then
                    self:ApplyRuntimeSettings()
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
                    return
                end

                local success =
                    Configs:Reset()

                if success then
                    self:ApplyRuntimeSettings()
                    self:RefreshUI()

                    notifyInfo(
                        "Settings",
                        "All settings restored to defaults."
                    )
                end
            end
        }
    )

    --------------------------------------------------
    -- Initial config list
    --------------------------------------------------

    if Configs then
        safeCall(function()
            Configs:Refresh()
        end)
    end
end

------------------------------------------------------
-- DEBUG
------------------------------------------------------

function SettingsFeature:BuildDebug(groupbox)
    if not groupbox then
        return
    end

    groupbox:AddToggle(
        "SettingsDebugMode",
        {
            Text = "Debug Mode",

            Default = Settings:Get(
                "General.Debug"
            ),

            Callback = function(value)
                if Refreshing then
                    return
                end

                Settings:Set(
                    "General.Debug",
                    value
                )
            end
        }
    )

    Elements.DebugMode =
        groupbox:Get(
            "SettingsDebugMode"
        )

    --------------------------------------------------
    -- Environment information
    --------------------------------------------------

    groupbox:AddButton(
        {
            Text = "Executor Info",

            Func = function()
                if not Environment then
                    notifyError(
                        "Environment module is unavailable."
                    )

                    return
                end

                local name =
                    "Unknown"

                local version =
                    "Unknown"

                safeCall(
                    function()
                        name =
                            Environment:GetExecutorName()
                            or "Unknown"

                        version =
                            Environment:GetExecutorVersion()
                            or "Unknown"
                    end
                )

                notifyInfo(
                    "Executor",
                    tostring(name)
                        .. " "
                        .. tostring(version),
                    5
                )
            end
        }
    )

    --------------------------------------------------
    -- Environment capabilities
    --------------------------------------------------

    groupbox:AddButton(
        {
            Text = "Environment Info",

            Func = function()
                if not Environment then
                    notifyError(
                        "Environment module is unavailable."
                    )

                    return
                end

                local info

                safeCall(
                    function()
                        info =
                            Environment:GetInfo()
                    end
                )

                if type(info) ~= "table" then
                    notifyError(
                        "Unable to read environment."
                    )

                    return
                end

                local executor =
                    tostring(
                        info.Executor
                        or "Unknown"
                    )

                local capabilityCount = 0

                if type(info.Capabilities)
                    == "table"
                then
                    for _, enabled in pairs(
                        info.Capabilities
                    ) do
                        if enabled == true then
                            capabilityCount += 1
                        end
                    end
                end

                notifyInfo(
                    "Environment",
                    "Executor: "
                        .. executor
                        .. "\nCapabilities: "
                        .. tostring(
                            capabilityCount
                        ),
                    6
                )
            end
        }
    )

    --------------------------------------------------
    -- Notifications
    --------------------------------------------------

    groupbox:AddButton(
        {
            Text = "Test Notifications",

            Func = function()
                if not Notifications then
                    return
                end

                Notifications:Info(
                    "Information",
                    "This is an information notification.",
                    3
                )

                task.delay(
                    0.25,
                    function()
                        Notifications:Success(
                            "Success",
                            "This is a success notification.",
                            3
                        )
                    end
                )

                task.delay(
                    0.5,
                    function()
                        Notifications:Warning(
                            "Warning",
                            "This is a warning notification.",
                            3
                        )
                    end
                )

                task.delay(
                    0.75,
                    function()
                        Notifications:Error(
                            "Error",
                            "This is an error notification.",
                            3
                        )
                    end
                )
            end
        }
    )

    --------------------------------------------------
    -- Clear notifications
    --------------------------------------------------

    groupbox:AddButton(
        {
            Text = "Clear Notifications",

            Func = function()
                if not Notifications then
                    return
                end

                safeCall(
                    function()
                        Notifications:Clear()
                    end
                )
            end
        }
    )

    --------------------------------------------------
    -- Reload UI
    --------------------------------------------------

    groupbox:AddButton(
        {
            Text = "Reload UI",

            Func = function()
                if not UI then
                    return
                end

                notifyInfo(
                    "Settings",
                    "Reloading UI...",
                    2
                )

                task.defer(
                    function()
                        safeCall(
                            function()
                                UI:Unload()
                            end
                        )

                        task.wait(0.15)

                        safeCall(
                            function()
                                UI:Load()
                            end
                        )

                        task.wait(0.15)

                        safeCall(
                            function()
                                UI:Create()
                            end
                        )
                    end
                )
            end
        }
    )
end

------------------------------------------------------
-- BUILD
------------------------------------------------------

function SettingsFeature:Build()
    if Built then
        return true
    end

    if not UI then
        return false
    end

    if not Settings then
        return false
    end

    --------------------------------------------------
    -- Create Settings tab
    --------------------------------------------------

    local tab = UI:AddTab(
        "Settings",
        "settings"
    )

    if not tab then
        return false
    end

    --------------------------------------------------
    -- Interface
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
    -- Notifications
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
    -- Configs
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
    -- Debug
    --------------------------------------------------

    local debugGroup =
        UI:AddRightGroupbox(
            tab,
            "Debug"
        )

    self:BuildDebug(
        debugGroup
    )

    --------------------------------------------------
    -- Apply current settings
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
    Elements = {}

    Built = false
    Refreshing = false

    return true
end

return SettingsFeature
