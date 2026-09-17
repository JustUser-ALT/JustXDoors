--[[
    JustXDoors
    Core/UI.lua

    UI adapter for Obsidian
    Version: 2.1.0
]]

local UI = {}

--//==================================================
--// Dependencies
--//==================================================

local Environment =
    require("Core/Environment")

local Settings =
    require("Core/Settings")

local Notifications =
    require("Core/Notifications")


--//==================================================
--// Loadstring
--//==================================================

local loadstringFn =
    Environment:Get("loadstring")

-- Loader injects loadstring into the module environment.
if type(loadstringFn) ~= "function" then
    pcall(function()
        loadstringFn = loadstring
    end)
end


--//==================================================
--// State
--//==================================================

local Library = nil
local Window = nil

UI.Library = nil
UI.Window = nil

UI.Tabs = {}
UI.Groups = {}
UI.Elements = {}


--//==================================================
--// Obsidian
--//==================================================

local OBSIDIAN_URL =
    "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"


--//==================================================
--// Logging
--//==================================================

local function log(...)
    print(
        "[JustXDoors UI]",
        ...
    )
end


local function warnLog(...)
    warn(
        "[JustXDoors UI]",
        ...
    )
end


--//==================================================
--// Safe notification
--//==================================================

local function notifyError(title, text)
    pcall(function()
        Notifications:Error(
            title,
            text
        )
    end)
end


--//==================================================
--// Load Obsidian
--//==================================================

local function loadLibrary()

    log("===== OBSIDIAN LOAD START =====")

    --================================================
    -- loadstring
    --================================================

    log(
        "loadstring type:",
        type(loadstringFn)
    )

    if type(loadstringFn) ~= "function" then

        return nil,
            "loadstring is unavailable"

    end


    --================================================
    -- HTTP
    --================================================

    log(
        "Downloading Obsidian:",
        OBSIDIAN_URL
    )

    local httpSuccess
    local source

    httpSuccess, source =
        pcall(function()

            return game:HttpGet(
                OBSIDIAN_URL
            )

        end)


    if not httpSuccess then

        return nil,
            "game:HttpGet failed:\n"
            .. tostring(source)

    end


    if type(source) ~= "string" then

        return nil,
            "Obsidian HTTP response is not a string.\n"
            .. "Type: "
            .. tostring(type(source))

    end


    if source == "" then

        return nil,
            "Obsidian returned an empty source."

    end


    log(
        "Obsidian downloaded:",
        #source,
        "bytes"
    )


    --================================================
    -- Compile
    --================================================

    log(
        "Compiling Obsidian..."
    )

    local compileSuccess
    local chunk
    local compileError

    compileSuccess,
    chunk,
    compileError =
        pcall(function()

            return loadstringFn(
                source,
                "@JustXDoors/Obsidian/Library.lua"
            )

        end)


    if not compileSuccess then

        return nil,
            "Obsidian loadstring crashed:\n"
            .. tostring(chunk)

    end


    if type(chunk) ~= "function" then

        return nil,
            "Obsidian compilation failed:\n"
            .. tostring(compileError)

    end


    log(
        "Obsidian compiled successfully."
    )


    --================================================
    -- Execute
    --================================================

    log(
        "Executing Obsidian..."
    )

    local executeSuccess
    local library

    executeSuccess,
    library =
        pcall(function()

            return chunk()

        end)


    if not executeSuccess then

        return nil,
            "Obsidian execution failed:\n"
            .. tostring(library)

    end


    if library == nil then

        return nil,
            "Obsidian returned nil."

    end


    if type(library) ~= "table" then

        return nil,
            "Obsidian returned invalid type: "
            .. tostring(type(library))

    end


    log(
        "Obsidian Library created successfully."
    )

    log(
        "===== OBSIDIAN LOAD SUCCESS ====="
    )


    return library
end


--//==================================================
--// Load UI library
--//==================================================

function UI:Load()

    if Library then
        return Library
    end


    log(
        "===== UI LOAD START ====="
    )


    --================================================
    -- IMPORTANT:
    -- pcall may return:
    --
    -- success, library
    --
    -- OR
    --
    -- success, nil, errorMessage
    --
    -- We MUST capture all results.
    --================================================

    local success
    local result
    local loadError

    success,
    result,
    loadError =
        pcall(function()

            return loadLibrary()

        end)


    log(
        "loadLibrary pcall:",
        success
    )

    log(
        "Library result type:",
        type(result)
    )

    log(
        "Library error:",
        tostring(loadError)
    )


    --================================================
    -- Hard crash
    --================================================

    if not success then

        warnLog(
            "loadLibrary crashed:"
        )

        warnLog(
            tostring(result)
        )

        notifyError(
            "JustXDoors",
            "Obsidian crashed while loading.\n"
            .. tostring(result)
        )

        return nil
    end


    --================================================
    -- Normal failure
    --================================================

    if not result then

        local reason =
            tostring(
                loadError
                or "Unknown Obsidian loading error"
            )


        warnLog(
            "Obsidian failed to load:"
        )

        warnLog(
            reason
        )


        notifyError(
            "JustXDoors",
            "Failed to load Obsidian.\n"
            .. reason
        )


        return nil
    end


    --================================================
    -- Validate
    --================================================

    if type(result) ~= "table" then

        warnLog(
            "Obsidian returned invalid type:",
            type(result)
        )

        notifyError(
            "JustXDoors",
            "Obsidian returned invalid library type."
        )

        return nil
    end


    --================================================
    -- Save
    --================================================

    Library =
        result

    self.Library =
        Library


    --================================================
    -- Notifications
    --================================================

    pcall(function()

        Notifications:SetLibrary(
            Library
        )

    end)


    --================================================
    -- Obsidian settings
    --================================================

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


    log(
        "===== UI LOAD SUCCESS ====="
    )


    return Library
end


--//==================================================
--// Create Window
--//==================================================

function UI:Create()

    log(
        "Create() started"
    )


    if Window then

        log(
            "Existing Window returned"
        )

        return Window
    end


    --================================================
    -- Load library
    --================================================

    local library =
        self:Load()


    if not library then

        warnLog(
            "Create(): library is nil"
        )

        return nil
    end


    --================================================
    -- Config
    --================================================

    local config =
        Settings.Data.UI


    if type(config) ~= "table" then

        warnLog(
            "Settings.Data.UI is invalid"
        )

        config = {}
    end


    local title =
        config.Title
        or "JustXDoors"

    local footer =
        config.Footer
        or "DOORS"

    local width =
        tonumber(config.Width)
        or 720

    local height =
        tonumber(config.Height)
        or 520

    local center =
        config.Center ~= false

    local autoShow =
        config.AutoShow ~= false

    local resizable =
        config.Resizable ~= false

    local mobileButtonsSide =
        config.MobileButtonsSide
        or "Right"

    local notifySide =
        config.NotifySide
        or "Right"

    local alwaysOnTop =
        config.AlwaysOnTop ~= false

    local showCursor =
        config.ShowCustomCursor == true


    --================================================
    -- Window configuration
    --================================================

    log(
        "Creating window..."
    )

    log(
        "Title:",
        title
    )

    log(
        "Size:",
        width,
        "x",
        height
    )


    local windowConfig = {

        Title = title,

        Footer = footer,

        Icon =
            config.Icon,

        Center =
            center,

        AutoShow =
            autoShow,

        Resizable =
            resizable,

        MobileButtonsSide =
            mobileButtonsSide,

        NotifySide =
            notifySide,

        ShowCustomCursor =
            showCursor,

        AlwaysOnTop =
            alwaysOnTop,

        Size =
            UDim2.fromOffset(
                width,
                height
            )
    }


    --================================================
    -- Create
    --================================================

    local success
    local result

    success,
    result =
        pcall(function()

            return library:CreateWindow(
                windowConfig
            )

        end)


    if not success then

        warnLog(
            "CreateWindow failed:"
        )

        warnLog(
            tostring(result)
        )

        notifyError(
            "JustXDoors",
            "UI window failed to create.\n"
            .. tostring(result)
        )

        return nil
    end


    if not result then

        warnLog(
            "CreateWindow returned nil"
        )

        notifyError(
            "JustXDoors",
            "UI window returned nil."
        )

        return nil
    end


    --================================================
    -- Save Window
    --================================================

    Window =
        result

    self.Window =
        Window


    --================================================
    -- Optional configuration
    --================================================

    pcall(function()

        Window:SetCornerRadius(
            tonumber(
                config.CornerRadius
            ) or 8
        )

    end)


    pcall(function()

        Window:SetAlwaysOnTop(
            alwaysOnTop
        )

    end)


    pcall(function()

        library:SetNotifySide(
            notifySide
        )

    end)


    log(
        "Window created successfully."
    )


    return Window
end


--//==================================================
--// Tabs
--//==================================================

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


    local success
    local errorMessage


    success,
    errorMessage =
        pcall(function()

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

        end)


    if not success then

        warnLog(
            "Failed to create tab:",
            tabName
        )

        warnLog(
            tostring(errorMessage)
        )

        return nil
    end


    if not tab then

        warnLog(
            "Tab returned nil:",
            tabName
        )

        return nil
    end


    self.Tabs[tabName] =
        tab


    log(
        "Tab created:",
        tabName
    )


    return tab
end


function UI:GetTab(name)

    return self.Tabs[name]
end


--//==================================================
--// Groupbox
--//==================================================

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


    local success
    local errorMessage


    success,
    errorMessage =
        pcall(function()

            group =
                tab:AddGroupbox({

                    Side =
                        side or "Left",

                    Name =
                        name,

                    IconName =
                        icon,

                    Description =
                        description
                })

        end)


    if not success then

        warnLog(
            "Failed to create groupbox:",
            name
        )

        warnLog(
            tostring(errorMessage)
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


    local success
    local errorMessage


    success,
    errorMessage =
        pcall(function()

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

        end)


    if not success then

        warnLog(
            "Failed to create left groupbox:",
            name
        )

        warnLog(
            tostring(errorMessage)
        )

        return nil
    end


    if group then

        self.Groups[name] =
            group

    end


    return group
end


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


    local success
    local errorMessage


    success,
    errorMessage =
        pcall(function()

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

        end)


    if not success then

        warnLog(
            "Failed to create right groupbox:",
            name
        )

        warnLog(
            tostring(errorMessage)
        )

        return nil
    end


    if group then

        self.Groups[name] =
            group

    end


    return group
end


--//==================================================
--// Toggle
--//==================================================

function UI:AddToggle(
    group,
    id,
    options
)

    if not group then
        return nil
    end


    local element


    local success
    local errorMessage


    success,
    errorMessage =
        pcall(function()

            element =
                group:AddToggle(
                    id,
                    options or {}
                )

        end)


    if not success then

        warnLog(
            "Toggle failed:",
            id
        )

        warnLog(
            tostring(errorMessage)
        )

        return nil
    end


    self.Elements[id] =
        element


    return element
end


--//==================================================
--// Checkbox
--//==================================================

function UI:AddCheckbox(
    group,
    id,
    options
)

    if not group then
        return nil
    end


    local element


    local success
    local errorMessage


    success,
    errorMessage =
        pcall(function()

            element =
                group:AddCheckbox(
                    id,
                    options or {}
                )

        end)


    if not success then

        warnLog(
            "Checkbox failed:",
            id
        )

        warnLog(
            tostring(errorMessage)
        )

        return nil
    end


    self.Elements[id] =
        element


    return element
end


--//==================================================
--// Button
--//==================================================

function UI:AddButton(
    group,
    id,
    callback
)

    if not group then
        return nil
    end


    local element


    local success
    local errorMessage


    success,
    errorMessage =
        pcall(function()

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

        end)


    if not success then

        warnLog(
            "Button failed:",
            id
        )

        warnLog(
            tostring(errorMessage)
        )

        return nil
    end


    self.Elements[id] =
        element


    return element
end


--//==================================================
--// Input
--//==================================================

function UI:AddInput(
    group,
    id,
    options
)

    if not group then
        return nil
    end


    local element


    local success
    local errorMessage


    success,
    errorMessage =
        pcall(function()

            element =
                group:AddInput(
                    id,
                    options or {}
                )

        end)


    if not success then

        warnLog(
            "Input failed:",
            id
        )

        warnLog(
            tostring(errorMessage)
        )

        return nil
    end


    self.Elements[id] =
        element


    return element
end


--//==================================================
--// Slider
--//==================================================

function UI:AddSlider(
    group,
    id,
    options
)

    if not group then
        return nil
    end


    local element


    local success
    local errorMessage


    success,
    errorMessage =
        pcall(function()

            element =
                group:AddSlider(
                    id,
                    options or {}
                )

        end)


    if not success then

        warnLog(
            "Slider failed:",
            id
        )

        warnLog(
            tostring(errorMessage)
        )

        return nil
    end


    self.Elements[id] =
        element


    return element
end


--//==================================================
--// Dropdown
--//==================================================

function UI:AddDropdown(
    group,
    id,
    options
)

    if not group then
        return nil
    end


    local element


    local success
    local errorMessage


    success,
    errorMessage =
        pcall(function()

            element =
                group:AddDropdown(
                    id,
                    options or {}
                )

        end)


    if not success then

        warnLog(
            "Dropdown failed:",
            id
        )

        warnLog(
            tostring(errorMessage)
        )

        return nil
    end


    self.Elements[id] =
        element


    return element
end


--//==================================================
--// Label
--//==================================================

function UI:AddLabel(
    group,
    text,
    options
)

    if not group then
        return nil
    end


    local element


    local success
    local errorMessage


    success,
    errorMessage =
        pcall(function()

            if type(options) == "table" then

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

        end)


    if not success then

        warnLog(
            "Label failed:",
            tostring(text)
        )

        warnLog(
            tostring(errorMessage)
        )

        return nil
    end


    return element
end


--//==================================================
--// Divider
--//==================================================

function UI:AddDivider(group)

    if not group then
        return nil
    end


    local element


    local success
    local errorMessage


    success,
    errorMessage =
        pcall(function()

            element =
                group:AddDivider()

        end)


    if not success then

        warnLog(
            "Divider failed:"
        )

        warnLog(
            tostring(errorMessage)
        )

        return nil
    end


    return element
end


--//==================================================
--// Tabbox
--//==================================================

function UI:AddTabbox(
    tab,
    side,
    name
)

    if not tab then
        return nil
    end


    local tabbox


    local success
    local errorMessage


    success,
    errorMessage =
        pcall(function()

            if string.lower(
                tostring(
                    side or "Left"
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

        end)


    if not success then

        warnLog(
            "Tabbox failed:"
        )

        warnLog(
            tostring(errorMessage)
        )

        return nil
    end


    return tabbox
end


--//==================================================
--// Notifications
--//==================================================

function UI:Notify(options)

    return Notifications:Notify(
        options
    )
end


--//==================================================
--// Visibility
--//==================================================

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


    return Library.Toggled == true
end


--//==================================================
--// Window settings
--//==================================================

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


function UI:SetNotifySide(side)

    side =
        tostring(side or "Right")


    Settings:Set(
        "UI.NotifySide",
        side
    )


    Settings:Set(
        "Notifications.Side",
        side
    )


    pcall(function()

        Notifications:SetSide(
            side
        )

    end)


    pcall(function()

        if Library then

            Library:SetNotifySide(
                side
            )

        end

    end)
end


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


--//==================================================
--// Unload
--//==================================================

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


function UI:Unload()

    if not Library then

        self.Library =
            nil

        self.Window =
            nil

        return
    end


    log(
        "Unloading UI..."
    )


    pcall(function()

        Library:Unload()

    end)


    Library =
        nil

    Window =
        nil


    self.Library =
        nil

    self.Window =
        nil


    table.clear(
        self.Tabs
    )

    table.clear(
        self.Groups
    )

    table.clear(
        self.Elements
    )


    log(
        "UI unloaded"
    )
end


--//==================================================
--// Debug information
--//==================================================

function UI:GetLibrary()

    return Library
end


function UI:GetWindow()

    return Window
end


function UI:IsLoaded()

    return Library ~= nil
end


function UI:IsCreated()

    return Window ~= nil
end


function UI:GetState()

    return {

        Loaded =
            Library ~= nil,

        Created =
            Window ~= nil,

        LibraryType =
            type(Library),

        WindowType =
            type(Window)
    }
end


--//==================================================
--// Return
--//==================================================

log(
    "UI module loaded. Version: 2.1.0"
)


return UI
