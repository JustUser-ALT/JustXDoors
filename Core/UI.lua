local UI = {}

local Environment =
    require("Core/Environment")

local Settings =
    require("Core/Settings")

local Notifications =
    require("Core/Notifications")

local loadstring =
    Environment:Get("loadstring")

------------------------------------------------------
-- ROBLOX GLOBALS
------------------------------------------------------

local UDim2 = Environment:Get("UDim2")

if not UDim2 then
    pcall(function()
        if type(getgenv) == "function" then
            local genv = getgenv()

            if type(genv) == "table" then
                UDim2 = genv.UDim2
            end
        end
    end)
end

------------------------------------------------------
-- STATE
------------------------------------------------------

local Library
local Window

UI.Library = nil
UI.Window = nil

UI.Tabs = {}
UI.Groups = {}
UI.Elements = {}

------------------------------------------------------
-- OBSIDIAN
------------------------------------------------------

local OBSIDIAN_URL =
    "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"

------------------------------------------------------
-- DEBUG
------------------------------------------------------

local function debugLog(...)
    print(
        "[JustXDoors UI]",
        ...
    )
end

local function debugWarn(...)
    warn(
        "[JustXDoors UI]",
        ...
    )
end

local function traceback(err)
    local message =
        tostring(err)

    local trace

    pcall(function()
        trace =
            debug.traceback(
                message,
                2
            )
    end)

    if trace then
        return trace
    end

    return message
end

------------------------------------------------------
-- LOAD LIBRARY
------------------------------------------------------

local function loadLibrary()

    if type(loadstring) ~= "function" then

        return nil,
            "loadstring is unavailable"

    end

    debugLog(
        "Loading Obsidian..."
    )

    local success, result =
        xpcall(
            function()

                debugLog(
                    "Downloading:",
                    OBSIDIAN_URL
                )

                local source =
                    game:HttpGet(
                        OBSIDIAN_URL
                    )

                if type(source) ~= "string"
                    or source == ""
                then

                    error(
                        "Obsidian returned empty source"
                    )

                end

                debugLog(
                    "Obsidian source downloaded:",
                    #source,
                    "bytes"
                )

                local chunk,
                    compileError =
                    loadstring(
                        source,
                        "@JustXDoors/Obsidian/Library.lua"
                    )

                if not chunk then

                    error(
                        "Obsidian compilation failed:\n"
                        .. tostring(
                            compileError
                        )
                    )

                end

                debugLog(
                    "Obsidian compiled successfully"
                )

                local library =
                    chunk()

                if not library then

                    error(
                        "Obsidian returned nil"
                    )

                end

                if type(library) ~= "table" then

                    error(
                        "Obsidian returned "
                        .. tostring(library)
                        .. " instead of table"
                    )

                end

                debugLog(
                    "Obsidian Library created"
                )

                return library

            end,

            function(err)

                return traceback(err)

            end
        )

    if not success then

        debugWarn(
            "Failed to load Obsidian:"
        )

        debugWarn(
            result
        )

        return nil,
            result

    end

    return result
end

------------------------------------------------------
-- LOAD
------------------------------------------------------

function UI:Load()

    if Library then
        return Library
    end

    local success,
        result =
        xpcall(
            function()
                return loadLibrary()
            end,

            function(err)
                return traceback(err)
            end
        )

    if not success then

        debugWarn(
            "loadLibrary crashed:"
        )

        debugWarn(
            result
        )

        pcall(function()
            Notifications:Error(
                "JustXDoors",
                "Failed to load UI library.\nCheck console."
            )
        end)

        return nil
    end

    if not result then

        debugWarn(
            "loadLibrary returned nil"
        )

        pcall(function()
            Notifications:Error(
                "JustXDoors",
                "Failed to load UI library.\nCheck console."
            )
        end)

        return nil
    end

    Library =
        result

    self.Library =
        Library

    --------------------------------------------------
    -- NOTIFICATIONS
    --------------------------------------------------

    pcall(function()
        Notifications:SetLibrary(
            Library
        )
    end)

    --------------------------------------------------
    -- OPTIONAL LIBRARY SETTINGS
    --------------------------------------------------

    pcall(function()
        Library.ForceCheckbox =
            false
    end)

    pcall(function()
        Library.ShowToggleFrameInKeybinds =
            true
    end)

    pcall(function()

        Library.ShowCustomCursor =
            Settings:Get(
                "UI.ShowCustomCursor"
            )

    end)

    pcall(function()

        Library.NotifyOnError =
            true

    end)

    pcall(function()

        Library:SetNotifySide(
            Settings:Get(
                "Notifications.Side"
            )
        )

    end)

    debugLog(
        "UI library loaded"
    )

    return Library
end

------------------------------------------------------
-- CREATE WINDOW
------------------------------------------------------

function UI:Create()

    if Window then
        return Window
    end

    debugLog(
        "Create() started"
    )

    --------------------------------------------------
    -- LIBRARY
    --------------------------------------------------

    local library =
        self:Load()

    if not library then

        debugWarn(
            "Create(): library is nil"
        )

        return nil
    end

    --------------------------------------------------
    -- SETTINGS
    --------------------------------------------------

    local config =
        Settings.Data.UI

    if type(config) ~= "table" then

        debugWarn(
            "Create(): Settings.Data.UI is invalid"
        )

        return nil
    end

    debugLog(
        "Window config:",
        config.Title,
        config.Width,
        config.Height
    )

    --------------------------------------------------
    -- SIZE
    --------------------------------------------------

    local windowSize

    local width =
        tonumber(
            config.Width
        )
        or 720

    local height =
        tonumber(
            config.Height
        )
        or 520

    if UDim2
        and type(UDim2.fromOffset)
            == "function"
    then

        windowSize =
            UDim2.fromOffset(
                width,
                height
            )

        debugLog(
            "Window size created:",
            width,
            height
        )

    else

        debugWarn(
            "UDim2.fromOffset is unavailable."
        )

        debugWarn(
            "Creating window without explicit Size."
        )

    end

    --------------------------------------------------
    -- CREATE
    --------------------------------------------------

    debugLog(
        "Calling Library:CreateWindow()..."
    )

    local success,
        result =
        xpcall(
            function()

                local options = {

                    Title =
                        tostring(
                            config.Title
                            or "JustXDoors"
                        ),

                    Footer =
                        tostring(
                            config.Footer
                            or "DOORS"
                        ),

                    Icon =
                        config.Icon,

                    Center =
                        config.Center ~= false,

                    AutoShow =
                        config.AutoShow ~= false,

                    Resizable =
                        config.Resizable ~= false,

                    MobileButtonsSide =
                        config.MobileButtonsSide
                        or "Right",

                    NotifySide =
                        config.NotifySide
                        or "Right",

                    ShowCustomCursor =
                        config.ShowCustomCursor
                        == true,

                    AlwaysOnTop =
                        config.AlwaysOnTop
                        ~= false
                }

                if windowSize then
                    options.Size =
                        windowSize
                end

                debugLog(
                    "CreateWindow options prepared"
                )

                return library:CreateWindow(
                    options
                )

            end,

            function(err)

                return traceback(err)

            end
        )

    --------------------------------------------------
    -- ERROR
    --------------------------------------------------

    if not success then

        debugWarn(
            "================================"
        )

        debugWarn(
            "CreateWindow FAILED"
        )

        debugWarn(
            result
        )

        debugWarn(
            "================================"
        )

        pcall(function()

            Notifications:Error(
                "JustXDoors",
                "UI window failed to create.\nSee console for exact error."
            )

        end)

        return nil
    end

    --------------------------------------------------
    -- NIL
    --------------------------------------------------

    if not result then

        debugWarn(
            "CreateWindow returned nil"
        )

        pcall(function()

            Notifications:Error(
                "JustXDoors",
                "UI window returned nil."
            )

        end)

        return nil
    end

    --------------------------------------------------
    -- SAVE WINDOW
    --------------------------------------------------

    Window =
        result

    self.Window =
        Window

    --------------------------------------------------
    -- OPTIONAL SETTINGS
    --------------------------------------------------

    pcall(function()

        Window:SetCornerRadius(
            tonumber(
                config.CornerRadius
            )
            or 8
        )

    end)

    pcall(function()

        Window:SetAlwaysOnTop(
            config.AlwaysOnTop
            ~= false
        )

    end)

    pcall(function()

        library:SetNotifySide(
            config.NotifySide
            or "Right"
        )

    end)

    debugLog(
        "Window created successfully"
    )

    return Window
end

------------------------------------------------------
-- TAB
------------------------------------------------------

function UI:AddTab(
    name,
    icon,
    description
)

    if not Window then
        self:Create()
    end

    if not Window then
        return nil
    end

    local tabName =
        tostring(name)

    local tab

    local success,
        errorMessage =
        xpcall(
            function()

                if description then

                    tab =
                        Window:AddTab({
                            Name =
                                tabName,

                            Icon =
                                icon,

                            Description =
                                description
                        })

                else

                    tab =
                        Window:AddTab(
                            tabName,
                            icon
                        )

                end

            end,

            function(err)
                return traceback(err)
            end
        )

    if not success then

        debugWarn(
            "Failed to create tab:",
            tabName
        )

        debugWarn(
            errorMessage
        )

        return nil
    end

    if not tab then

        debugWarn(
            "Tab returned nil:",
            tabName
        )

        return nil
    end

    self.Tabs[tabName] =
        tab

    debugLog(
        "Tab created:",
        tabName
    )

    return tab
end

------------------------------------------------------
-- GET TAB
------------------------------------------------------

function UI:GetTab(name)
    return self.Tabs[name]
end

------------------------------------------------------
-- GROUPBOX
------------------------------------------------------

function UI:AddGroupbox(
    tab,
    name,
    side,
    icon,
    description
)

    if not tab then
        return nil
    end

    local group

    local success,
        errorMessage =
        xpcall(
            function()

                group =
                    tab:AddGroupbox({

                        Side =
                            side
                            or "Left",

                        Name =
                            name,

                        IconName =
                            icon,

                        Description =
                            description
                    })

            end,

            function(err)
                return traceback(err)
            end
        )

    if not success then

        debugWarn(
            "Failed to create groupbox:",
            name
        )

        debugWarn(
            errorMessage
        )

        return nil
    end

    if not group then
        return nil
    end

    self.Groups[name] =
        group

    return group
end

------------------------------------------------------
-- LEFT GROUPBOX
------------------------------------------------------

function UI:AddLeftGroupbox(
    tab,
    name,
    icon,
    description
)

    if not tab then
        return nil
    end

    local group

    local success,
        errorMessage =
        xpcall(
            function()

                group =
                    tab:AddLeftGroupbox(
                        name,
                        icon
                    )

                if description
                    and group
                then

                    pcall(function()

                        group:SetDescription(
                            description
                        )

                    end)

                end

            end,

            function(err)
                return traceback(err)
            end
        )

    if not success then

        debugWarn(
            "Failed to create left groupbox:",
            name
        )

        debugWarn(
            errorMessage
        )

        return nil
    end

    if group then

        self.Groups[name] =
            group

    end

    return group
end

------------------------------------------------------
-- RIGHT GROUPBOX
------------------------------------------------------

function UI:AddRightGroupbox(
    tab,
    name,
    icon,
    description
)

    if not tab then
        return nil
    end

    local group

    local success,
        errorMessage =
        xpcall(
            function()

                group =
                    tab:AddRightGroupbox(
                        name,
                        icon
                    )

                if description
                    and group
                then

                    pcall(function()

                        group:SetDescription(
                            description
                        )

                    end)

                end

            end,

            function(err)
                return traceback(err)
            end
        )

    if not success then

        debugWarn(
            "Failed to create right groupbox:",
            name
        )

        debugWarn(
            errorMessage
        )

        return nil
    end

    if group then

        self.Groups[name] =
            group

    end

    return group
end

------------------------------------------------------
-- TOGGLE
------------------------------------------------------

function UI:AddToggle(
    group,
    id,
    options
)

    if not group then
        return nil
    end

    local element

    local success,
        errorMessage =
        xpcall(
            function()

                element =
                    group:AddToggle(
                        id,
                        options or {}
                    )

            end,

            function(err)
                return traceback(err)
            end
        )

    if not success then

        debugWarn(
            "Toggle failed:",
            id
        )

        debugWarn(
            errorMessage
        )

        return nil
    end

    self.Elements[id] =
        element

    return element
end

------------------------------------------------------
-- CHECKBOX
------------------------------------------------------

function UI:AddCheckbox(
    group,
    id,
    options
)

    if not group then
        return nil
    end

    local element

    local success,
        errorMessage =
        xpcall(
            function()

                element =
                    group:AddCheckbox(
                        id,
                        options or {}
                    )

            end,

            function(err)
                return traceback(err)
            end
        )

    if not success then

        debugWarn(
            "Checkbox failed:",
            id
        )

        debugWarn(
            errorMessage
        )

        return nil
    end

    self.Elements[id] =
        element

    return element
end

------------------------------------------------------
-- BUTTON
------------------------------------------------------

function UI:AddButton(
    group,
    id,
    callback
)

    if not group then
        return nil
    end

    local element

    local success,
        errorMessage =
        xpcall(
            function()

                element =
                    group:AddButton({

                        Text =
                            tostring(id),

                        Func =
                            type(callback)
                            == "function"
                            and callback
                            or function()
                            end

                    })

            end,

            function(err)
                return traceback(err)
            end
        )

    if not success then

        debugWarn(
            "Button failed:",
            id
        )

        debugWarn(
            errorMessage
        )

        return nil
    end

    self.Elements[id] =
        element

    return element
end

------------------------------------------------------
-- INPUT
------------------------------------------------------

function UI:AddInput(
    group,
    id,
    options
)

    if not group then
        return nil
    end

    local element

    local success,
        errorMessage =
        xpcall(
            function()

                element =
                    group:AddInput(
                        id,
                        options or {}
                    )

            end,

            function(err)
                return traceback(err)
            end
        )

    if not success then

        debugWarn(
            "Input failed:",
            id
        )

        debugWarn(
            errorMessage
        )

        return nil
    end

    self.Elements[id] =
        element

    return element
end

------------------------------------------------------
-- SLIDER
------------------------------------------------------

function UI:AddSlider(
    group,
    id,
    options
)

    if not group then
        return nil
    end

    local element

    local success,
        errorMessage =
        xpcall(
            function()

                element =
                    group:AddSlider(
                        id,
                        options or {}
                    )

            end,

            function(err)
                return traceback(err)
            end
        )

    if not success then

        debugWarn(
            "Slider failed:",
            id
        )

        debugWarn(
            errorMessage
        )

        return nil
    end

    self.Elements[id] =
        element

    return element
end

------------------------------------------------------
-- DROPDOWN
------------------------------------------------------

function UI:AddDropdown(
    group,
    id,
    options
)

    if not group then
        return nil
    end

    local element

    local success,
        errorMessage =
        xpcall(
            function()

                element =
                    group:AddDropdown(
                        id,
                        options or {}
                    )

            end,

            function(err)
                return traceback(err)
            end
        )

    if not success then

        debugWarn(
            "Dropdown failed:",
            id
        )

        debugWarn(
            errorMessage
        )

        return nil
    end

    self.Elements[id] =
        element

    return element
end

------------------------------------------------------
-- LABEL
------------------------------------------------------

function UI:AddLabel(
    group,
    text,
    options
)

    if not group then
        return nil
    end

    local element

    local success,
        errorMessage =
        xpcall(
            function()

                if type(options)
                    == "table"
                then

                    options.Text =
                        text

                    element =
                        group:AddLabel(
                            options
                        )

                else

                    element =
                        group:AddLabel(
                            text,
                            options
                        )

                end

            end,

            function(err)
                return traceback(err)
            end
        )

    if not success then

        debugWarn(
            "Label failed:",
            tostring(text)
        )

        debugWarn(
            errorMessage
        )

        return nil
    end

    return element
end

------------------------------------------------------
-- DIVIDER
------------------------------------------------------

function UI:AddDivider(group)

    if not group then
        return nil
    end

    local element

    local success,
        errorMessage =
        xpcall(
            function()

                element =
                    group:AddDivider()

            end,

            function(err)
                return traceback(err)
            end
        )

    if not success then

        debugWarn(
            "Divider failed:"
        )

        debugWarn(
            errorMessage
        )

        return nil
    end

    return element
end

------------------------------------------------------
-- TABBOX
------------------------------------------------------

function UI:AddTabbox(
    tab,
    side,
    name
)

    if not tab then
        return nil
    end

    local tabbox

    local success,
        errorMessage =
        xpcall(
            function()

                if string.lower(
                    tostring(
                        side
                        or "Left"
                    )
                ) == "right"
                then

                    tabbox =
                        tab:AddRightTabbox(
                            name
                        )

                else

                    tabbox =
                        tab:AddLeftTabbox(
                            name
                        )

                end

            end,

            function(err)
                return traceback(err)
            end
        )

    if not success then

        debugWarn(
            "Tabbox failed:"
        )

        debugWarn(
            errorMessage
        )

        return nil
    end

    return tabbox
end

------------------------------------------------------
-- NOTIFY
------------------------------------------------------

function UI:Notify(options)

    return Notifications:Notify(
        options
    )

end

------------------------------------------------------
-- VISIBILITY
------------------------------------------------------

function UI:SetVisible(value)

    if not Window then
        return
    end

    pcall(function()

        Window:Toggle(
            value == true
        )

    end)

end

function UI:Toggle()

    if not Window then
        return
    end

    pcall(function()

        Window:Toggle()

    end)

end

function UI:IsVisible()

    if not Library then
        return false
    end

    return Library.Toggled
        == true

end

------------------------------------------------------
-- CORNER RADIUS
------------------------------------------------------

function UI:SetCornerRadius(value)

    if not Window then
        return
    end

    value =
        tonumber(value)

    if not value then
        return
    end

    Settings:Set(
        "UI.CornerRadius",
        value
    )

    pcall(function()

        Window:SetCornerRadius(
            value
        )

    end)

end

------------------------------------------------------
-- ALWAYS ON TOP
------------------------------------------------------

function UI:SetAlwaysOnTop(value)

    if not Window then
        return
    end

    value =
        value == true

    Settings:Set(
        "UI.AlwaysOnTop",
        value
    )

    pcall(function()

        Window:SetAlwaysOnTop(
            value
        )

    end)

end

------------------------------------------------------
-- NOTIFY SIDE
------------------------------------------------------

function UI:SetNotifySide(side)

    Notifications:SetSide(
        side
    )

end

------------------------------------------------------
-- SIDEBAR WIDTH
------------------------------------------------------

function UI:SetSidebarWidth(width)

    if not Window then
        return
    end

    width =
        tonumber(width)

    if not width then
        return
    end

    pcall(function()

        Window:SetSidebarWidth(
            width
        )

    end)

end

------------------------------------------------------
-- COMPACT
------------------------------------------------------

function UI:SetCompact(value)

    if not Window then
        return
    end

    pcall(function()

        Window:SetCompact(
            value == true
        )

    end)

end

------------------------------------------------------
-- UNLOAD CALLBACK
------------------------------------------------------

function UI:OnUnload(callback)

    if not Library then
        return
    end

    if type(callback)
        ~= "function"
    then
        return
    end

    pcall(function()

        Library:OnUnload(
            callback
        )

    end)

end

------------------------------------------------------
-- UNLOAD
------------------------------------------------------

function UI:Unload()

    if not Library then
        return
    end

    debugLog(
        "Unloading UI..."
    )

    pcall(function()

        Library:Unload()

    end)

    Library = nil
    Window = nil

    self.Library = nil
    self.Window = nil

    table.clear(
        self.Tabs
    )

    table.clear(
        self.Groups
    )

    table.clear(
        self.Elements
    )

    debugLog(
        "UI unloaded"
    )

end

------------------------------------------------------

return UI
