--[[
    JustXDoors
    Core/UI.lua

    Obsidian UI adapter
    Version: 3.0.0

    This module is intentionally independent from Environment.lua
    for loading external UI libraries.
]]

local UI = {}

UI.Version = "3.0.0"
UI.LibraryURL =
    "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"

UI.Library = nil
UI.Window = nil
UI.Loaded = false
UI.Unloaded = false
UI.LoadError = nil

local Environment
local Settings
local Notifications


--//==================================================
--// Safe utilities
--//==================================================

local function safeToString(value)
    local success, result = pcall(function()
        return tostring(value)
    end)

    if success then
        return result
    end

    return "<tostring failed>"
end


local function traceError(err)
    local message = safeToString(err)

    pcall(function()
        if debug and debug.traceback then
            message = message .. "\n" .. debug.traceback()
        end
    end)

    return message
end


local function log(...)
    print("[JustXDoors UI]", ...)
end


local function warnLog(...)
    warn("[JustXDoors UI]", ...)
end


--//==================================================
--// Load core references
--//==================================================

function UI:Init(core)

    core = core or {}

    Environment = core.Environment
    Settings = core.Settings
    Notifications = core.Notifications

    log("Init()")
    log("Environment:", typeof(Environment))
    log("Settings:", typeof(Settings))
    log("Notifications:", typeof(Notifications))

    return self
end


--//==================================================
--// Resolve loadstring
--//==================================================

local function resolveLoadstring()

    -- 1. Current environment
    local fn = nil

    pcall(function()
        fn = loadstring
    end)

    if type(fn) == "function" then
        return fn, "module environment"
    end


    -- 2. getgenv()
    pcall(function()

        if type(getgenv) == "function" then

            local genv = getgenv()

            if type(genv) == "table"
                and type(genv.loadstring) == "function"
            then
                fn = genv.loadstring
            end
        end

    end)

    if type(fn) == "function" then
        return fn, "getgenv"
    end


    -- 3. _G
    pcall(function()

        if type(_G) == "table"
            and type(_G.loadstring) == "function"
        then
            fn = _G.loadstring
        end

    end)

    if type(fn) == "function" then
        return fn, "_G"
    end


    -- 4. Environment module
    if Environment
        and type(Environment.Get) == "function"
    then

        pcall(function()

            fn = Environment:Get("loadstring")

        end)

        if type(fn) == "function" then
            return fn, "Environment:Get"
        end
    end


    return nil, "loadstring not found"
end


--//==================================================
--// HTTP
--//==================================================

local function httpGet(url)

    local errors = {}


    --================================================
    -- Roblox HttpGet
    --================================================

    local success, result = pcall(function()

        return game:HttpGet(url)

    end)

    if success
        and type(result) == "string"
        and result ~= ""
    then

        return result

    end

    if not success then
        table.insert(
            errors,
            "game:HttpGet: " .. safeToString(result)
        )
    else
        table.insert(
            errors,
            "game:HttpGet returned empty source"
        )
    end


    --================================================
    -- Executor request
    --================================================

    local requestFunctions = {
        "request",
        "http_request",
        "syn_request"
    }

    for _, name in ipairs(requestFunctions) do

        local requestFn = nil

        pcall(function()

            requestFn = _G[name]

        end)

        if type(requestFn) ~= "function" then

            pcall(function()

                if type(getgenv) == "function" then

                    local genv = getgenv()

                    if type(genv) == "table" then
                        requestFn = genv[name]
                    end

                end

            end)

        end


        if type(requestFn) == "function" then

            local requestSuccess, response =
                pcall(function()

                    return requestFn({
                        Url = url,
                        Method = "GET"
                    })

                end)


            if requestSuccess
                and type(response) == "table"
            then

                local status =
                    response.StatusCode
                    or response.Status
                    or response.status


                local body =
                    response.Body
                    or response.body


                if type(body) == "string"
                    and body ~= ""
                then

                    if status
                        and tonumber(status)
                        and tonumber(status) >= 400
                    then

                        table.insert(
                            errors,
                            name
                                .. " HTTP status "
                                .. safeToString(status)
                        )

                    else

                        return body

                    end

                else

                    table.insert(
                        errors,
                        name .. " returned empty body"
                    )

                end

            elseif not requestSuccess then

                table.insert(
                    errors,
                    name
                        .. ": "
                        .. safeToString(response)
                )

            end
        end
    end


    error(
        "Unable to download Obsidian.\n\n"
        .. "URL:\n"
        .. url
        .. "\n\n"
        .. table.concat(errors, "\n")
    )
end


--//==================================================
--// Compile external source
--//==================================================

local function compileSource(source, chunkName)

    local loadFn, sourceName =
        resolveLoadstring()


    if type(loadFn) ~= "function" then

        error(
            "loadstring is unavailable.\n"
            .. "Resolver: "
            .. safeToString(sourceName)
        )

    end


    log(
        "Using loadstring from:",
        sourceName
    )


    local success, fn, compileError =
        pcall(function()

            return loadFn(
                source,
                chunkName
            )

        end)


    if not success then

        error(
            "loadstring call failed:\n"
            .. safeToString(fn)
        )

    end


    if type(fn) ~= "function" then

        error(
            "Obsidian source compilation failed:\n"
            .. safeToString(compileError)
        )

    end


    return fn
end


--//==================================================
--// Execute external library
--//==================================================

local function executeSource(source)

    local chunk =
        compileSource(
            source,
            "@JustXDoors/Obsidian"
        )


    local success, result =
        xpcall(
            function()
                return chunk()
            end,
            function(err)
                return traceError(err)
            end
        )


    if not success then

        error(
            "Obsidian runtime error:\n"
            .. safeToString(result)
        )

    end


    if result == nil then

        error(
            "Obsidian Library.lua executed successfully "
            .. "but returned nil."
        )

    end


    if type(result) ~= "table" then

        error(
            "Obsidian Library.lua returned "
            .. type(result)
            .. " instead of table."
        )

    end


    return result
end


--//==================================================
--// Load Obsidian
--//==================================================

function UI:Load()

    if self.Library then

        log("Library already loaded.")

        return self.Library
    end


    log("========================================")
    log("Obsidian loading started")
    log("URL:", self.LibraryURL)
    log("========================================")


    self.LoadError = nil


    local success, result =
        xpcall(
            function()

                local source =
                    httpGet(
                        self.LibraryURL
                    )


                log(
                    "Obsidian source downloaded.",
                    "bytes:",
                    #source
                )


                if #source < 100 then

                    error(
                        "Downloaded Obsidian source is suspiciously small."
                    )

                end


                -- Detect common HTTP error pages
                local firstPart =
                    source:sub(1, 500):lower()


                if firstPart:find("<html")
                    or firstPart:find("404")
                    or firstPart:find("not found")
                then

                    warnLog(
                        "Downloaded source looks like an HTTP error page."
                    )

                end


                local library =
                    executeSource(
                        source
                    )


                if type(library.CreateWindow) ~= "function" then

                    error(
                        "Obsidian Library loaded, "
                        .. "but CreateWindow is missing."
                    )

                end


                log(
                    "Obsidian loaded successfully."
                )

                log(
                    "CreateWindow:",
                    type(library.CreateWindow)
                )


                return library

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        self.LoadError =
            safeToString(result)


        warnLog(
            "FAILED TO LOAD OBSIDIAN"
        )

        warnLog(
            self.LoadError
        )


        return nil
    end


    self.Library = result
    self.Loaded = true


    -- Pass library to notification system
    if Notifications
        and type(Notifications.SetLibrary) == "function"
    then

        pcall(function()

            Notifications:SetLibrary(
                self.Library
            )

        end)

    end


    return self.Library
end


--//==================================================
--// Create window
--//==================================================

function UI:Create()

    log("Create() started.")


    if self.Unloaded then

        warnLog(
            "Create() called after UI was unloaded."
        )

        return nil
    end


    local library =
        self:Load()


    if not library then

        warnLog(
            "Create(): Library is nil."
        )

        if self.LoadError then

            warnLog(
                "Actual load error:"
            )

            warnLog(
                self.LoadError
            )

        end

        return nil
    end


    log(
        "Create(): Library acquired."
    )


    local config = {
        Title = "JustXDoors",
        Footer = "DOORS",

        Center = true,
        AutoShow = true,
        Resizable = true,

        MobileButtonsSide = "Right",

        ShowCustomCursor = false,

        NotifySide = "Right",

        AlwaysOnTop = true,

        Size = UDim2.fromOffset(
            720,
            520
        )
    }


    --================================================
    -- Read settings
    --================================================

    if Settings
        and type(Settings.Get) == "function"
    then

        local success, result =
            pcall(function()

                return Settings:Get(
                    "UI"
                )

            end)


        if success
            and type(result) == "table"
        then

            local uiSettings = result


            if type(uiSettings.Title) == "string" then
                config.Title =
                    uiSettings.Title
            end


            if type(uiSettings.Footer) == "string" then
                config.Footer =
                    uiSettings.Footer
            end


            if type(uiSettings.Center) == "boolean" then
                config.Center =
                    uiSettings.Center
            end


            if type(uiSettings.AutoShow) == "boolean" then
                config.AutoShow =
                    uiSettings.AutoShow
            end


            if type(uiSettings.Resizable) == "boolean" then
                config.Resizable =
                    uiSettings.Resizable
            end


            if type(uiSettings.AlwaysOnTop) == "boolean" then
                config.AlwaysOnTop =
                    uiSettings.AlwaysOnTop
            end


            if type(uiSettings.MobileButtonsSide) == "string" then
                config.MobileButtonsSide =
                    uiSettings.MobileButtonsSide
            end


            if type(uiSettings.NotifySide) == "string" then
                config.NotifySide =
                    uiSettings.NotifySide
            end


            if type(uiSettings.ShowCustomCursor) == "boolean" then
                config.ShowCustomCursor =
                    uiSettings.ShowCustomCursor
            end


            if type(uiSettings.Width) == "number"
                and type(uiSettings.Height) == "number"
            then

                config.Size =
                    UDim2.fromOffset(
                        math.floor(uiSettings.Width),
                        math.floor(uiSettings.Height)
                    )

            end


            if uiSettings.Icon ~= nil then

                config.Icon =
                    uiSettings.Icon

            end

        end
    end


    log(
        "Creating Obsidian window..."
    )


    log(
        "Title:",
        config.Title
    )


    log(
        "Size:",
        config.Size
    )


    local success, window =
        xpcall(
            function()

                return library:CreateWindow(
                    config
                )

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        warnLog(
            "CreateWindow FAILED:"
        )

        warnLog(
            safeToString(window)
        )

        return nil
    end


    if not window then

        warnLog(
            "CreateWindow returned nil."
        )

        return nil
    end


    self.Window = window
    self.Unloaded = false


    log(
        "Window created successfully."
    )


    return window
end


--//==================================================
--// Tabs
--//==================================================

function UI:AddTab(name, icon, description)

    if not self.Window then
        return nil
    end


    local success, result =
        xpcall(
            function()

                return self.Window:AddTab(
                    name,
                    icon,
                    description
                )

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        warnLog(
            "AddTab failed:",
            name
        )

        warnLog(
            result
        )

        return nil
    end


    return result
end


--//==================================================
--// Groupboxes
--//==================================================

function UI:AddLeftGroupbox(tab, name, icon)

    if not tab then
        return nil
    end


    local success, result =
        xpcall(
            function()

                return tab:AddLeftGroupbox(
                    name,
                    icon
                )

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        warnLog(
            "AddLeftGroupbox failed:",
            name
        )

        warnLog(result)

        return nil
    end


    return result
end


function UI:AddRightGroupbox(tab, name, icon)

    if not tab then
        return nil
    end


    local success, result =
        xpcall(
            function()

                return tab:AddRightGroupbox(
                    name,
                    icon
                )

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        warnLog(
            "AddRightGroupbox failed:",
            name
        )

        warnLog(result)

        return nil
    end


    return result
end


--==================================================
-- Generic groupbox
--==================================================

function UI:AddGroupbox(tab, side, name, icon)

    if not tab then
        return nil
    end


    local success, result =
        xpcall(
            function()

                if side == "Right"
                    or side == "right"
                then

                    return tab:AddRightGroupbox(
                        name,
                        icon
                    )

                end


                return tab:AddLeftGroupbox(
                    name,
                    icon
                )

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        warnLog(
            "AddGroupbox failed:",
            name
        )

        warnLog(result)

        return nil
    end


    return result
end


--//==================================================
--// Labels
--//==================================================

function UI:AddLabel(groupbox, text)

    if not groupbox then
        return nil
    end


    local success, result =
        xpcall(
            function()

                return groupbox:AddLabel(
                    tostring(text or "")
                )

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        warnLog(
            "AddLabel failed:"
        )

        warnLog(result)

        return nil
    end


    return result
end


--//==================================================
--// Divider
--//==================================================

function UI:AddDivider(groupbox)

    if not groupbox then
        return nil
    end


    local success, result =
        xpcall(
            function()

                return groupbox:AddDivider()

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        warnLog(
            "AddDivider failed:"
        )

        warnLog(result)

        return nil
    end


    return result
end


--//==================================================
--// Button
--//==================================================

function UI:AddButton(groupbox, index, options)

    if not groupbox then
        return nil
    end


    local success, result =
        xpcall(
            function()

                if type(index) == "table"
                    and options == nil
                then

                    return groupbox:AddButton(
                        index
                    )

                end


                if type(options) == "table" then

                    if type(index) == "string" then

                        options.Text =
                            options.Text
                            or index

                    end

                    return groupbox:AddButton(
                        options
                    )

                end


                return groupbox:AddButton({
                    Text = tostring(index or "Button")
                })

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        warnLog(
            "AddButton failed:"
        )

        warnLog(result)

        return nil
    end


    return result
end


--//==================================================
--// Toggle
--//==================================================

function UI:AddToggle(groupbox, index, options)

    if not groupbox then
        return nil
    end


    local success, result =
        xpcall(
            function()

                return groupbox:AddToggle(
                    index,
                    options or {}
                )

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        warnLog(
            "AddToggle failed:",
            safeToString(index)
        )

        warnLog(result)

        return nil
    end


    return result
end


--//==================================================
--// Slider
--//==================================================

function UI:AddSlider(groupbox, index, options)

    if not groupbox then
        return nil
    end


    local success, result =
        xpcall(
            function()

                return groupbox:AddSlider(
                    index,
                    options or {}
                )

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        warnLog(
            "AddSlider failed:",
            safeToString(index)
        )

        warnLog(result)

        return nil
    end


    return result
end


--//==================================================
--// Dropdown
--//==================================================

function UI:AddDropdown(groupbox, index, options)

    if not groupbox then
        return nil
    end


    local success, result =
        xpcall(
            function()

                return groupbox:AddDropdown(
                    index,
                    options or {}
                )

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        warnLog(
            "AddDropdown failed:",
            safeToString(index)
        )

        warnLog(result)

        return nil
    end


    return result
end


--//==================================================
--// Input
--//==================================================

function UI:AddInput(groupbox, index, options)

    if not groupbox then
        return nil
    end


    local success, result =
        xpcall(
            function()

                return groupbox:AddInput(
                    index,
                    options or {}
                )

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        warnLog(
            "AddInput failed:",
            safeToString(index)
        )

        warnLog(result)

        return nil
    end


    return result
end


--//==================================================
--// Paragraph
--//==================================================

function UI:AddParagraph(groupbox, title, description)

    if not groupbox then
        return nil
    end


    local success, result =
        xpcall(
            function()

                return groupbox:AddLabel(
                    {
                        Text =
                            tostring(title or "")
                            .. "\n"
                            .. tostring(description or ""),
                        DoesWrap = true
                    }
                )

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        warnLog(
            "AddParagraph failed:"
        )

        warnLog(result)

        return nil
    end


    return result
end


--//==================================================
--// Key picker
--//==================================================

function UI:AddKeyPicker(element, index, options)

    if not element then
        return nil
    end


    if type(element.AddKeyPicker) ~= "function" then

        warnLog(
            "AddKeyPicker is unavailable."
        )

        return nil
    end


    local success, result =
        xpcall(
            function()

                return element:AddKeyPicker(
                    index,
                    options or {}
                )

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        warnLog(
            "AddKeyPicker failed:"
        )

        warnLog(result)

        return nil
    end


    return result
end


--//==================================================
--// Tabbox
--//==================================================

function UI:AddLeftTabbox(tab, name)

    if not tab then
        return nil
    end


    if type(tab.AddLeftTabbox) ~= "function" then

        warnLog(
            "AddLeftTabbox is unavailable."
        )

        return nil
    end


    local success, result =
        xpcall(
            function()

                if name then
                    return tab:AddLeftTabbox(name)
                end

                return tab:AddLeftTabbox()

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        warnLog(
            "AddLeftTabbox failed:"
        )

        warnLog(result)

        return nil
    end


    return result
end


function UI:AddRightTabbox(tab, name)

    if not tab then
        return nil
    end


    if type(tab.AddRightTabbox) ~= "function" then

        warnLog(
            "AddRightTabbox is unavailable."
        )

        return nil
    end


    local success, result =
        xpcall(
            function()

                if name then
                    return tab:AddRightTabbox(name)
                end

                return tab:AddRightTabbox()

            end,

            function(err)

                return traceError(err)

            end
        )


    if not success then

        warnLog(
            "AddRightTabbox failed:"
        )

        warnLog(result)

        return nil
    end


    return result
end


--//==================================================
--// Unload callback
--//==================================================

function UI:OnUnload(callback)

    if not self.Library then
        return false
    end


    if type(self.Library.OnUnload) ~= "function" then

        warnLog(
            "Library:OnUnload is unavailable."
        )

        return false
    end


    local success, err =
        pcall(function()

            self.Library:OnUnload(
                callback
            )

        end)


    if not success then

        warnLog(
            "OnUnload failed:"
        )

        warnLog(err)

        return false
    end


    return true
end


--//==================================================
--// Toggle
--//==================================================

function UI:Toggle(value)

    if not self.Window then
        return false
    end


    if type(self.Window.Toggle) ~= "function" then
        return false
    end


    local success =
        pcall(function()

            self.Window:Toggle(
                value
            )

        end)


    return success
end


--//==================================================
--// Unload
--//==================================================

function UI:Unload()

    if self.Unloaded then
        return
    end


    self.Unloaded = true


    if self.Library then

        local success, err =
            pcall(function()

                if type(self.Library.Unload) == "function" then

                    self.Library:Unload()

                end

            end)


        if not success then

            warnLog(
                "Library unload failed:"
            )

            warnLog(err)

        end
    end


    self.Window = nil
    self.Library = nil
    self.Loaded = false
end


--//==================================================
--// Destroy
--//==================================================

function UI:Destroy()

    self:Unload()

end


--//==================================================
--// Debug information
--//==================================================

function UI:GetInfo()

    return {
        Version = self.Version,

        LibraryLoaded =
            self.Library ~= nil,

        WindowCreated =
            self.Window ~= nil,

        Unloaded =
            self.Unloaded,

        LoadError =
            self.LoadError,

        LibraryURL =
            self.LibraryURL
    }
end


print(
    "[JustXDoors UI] UI module loaded. Version:",
    UI.Version
)


return UI
