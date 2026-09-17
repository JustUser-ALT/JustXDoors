local UI = {}

local Environment =
    require("Core/Environment")

local Settings =
    require("Core/Settings")

local Notifications =
    require("Core/Notifications")

local loadstring =
    Environment:Get("loadstring")

local Library
local Window

UI.Library = nil
UI.Window = nil

UI.Tabs = {}
UI.Groups = {}
UI.Elements = {}

local OBSIDIAN_URL =
    "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"

local function debugLog(...)
    if Settings:Get("General.Debug") then
        print(
            "[JustXDoors UI]",
            ...
        )
    end
end

local function debugWarn(...)
    if Settings:Get("General.Debug") then
        warn(
            "[JustXDoors UI]",
            ...
        )
    end
end

local function loadLibrary()
    if type(loadstring) ~= "function" then
        return nil,
            "loadstring is unavailable"
    end

    debugLog(
        "Loading Obsidian..."
    )

    local success, result =
        pcall(function()
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
        end)

    if not success then
        debugWarn(
            "Failed to load Obsidian:"
        )

        debugWarn(result)

        return nil, result
    end

    return result
end

function UI:Load()
    if Library then
        return Library
    end

    local success, result =
        pcall(function()
            return loadLibrary()
        end)

    if not success then
        debugWarn(
            "loadLibrary crashed:"
        )

        debugWarn(result)

        Notifications:Error(
            "JustXDoors",
            "Failed to load UI library.\nCheck console."
        )

        return nil
    end

    if not result then
        debugWarn(
            "loadLibrary returned nil"
        )

        Notifications:Error(
            "JustXDoors",
            "Failed to load UI library.\nCheck console."
        )

        return nil
    end

    Library = result
    self.Library = Library

    Notifications:SetLibrary(
        Library
    )

    pcall(function()
        Library.ForceCheckbox = false
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
        Library.NotifyOnError = true
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

function UI:Create()
    if Window then
        return Window
    end

    local library =
        self:Load()

    if not library then
        return nil
    end

    local config =
        Settings.Data.UI

    debugLog(
        "Creating window..."
    )

    local success, result =
        pcall(function()
            return library:CreateWindow({
                Title = config.Title,

                Footer = config.Footer,

                Icon = config.Icon,

                Center = config.Center,

                AutoShow = config.AutoShow,

                Resizable =
                    config.Resizable,

                MobileButtonsSide =
                    config.MobileButtonsSide,

                NotifySide =
                    config.NotifySide,

                ShowCustomCursor =
                    config.ShowCustomCursor,

                AlwaysOnTop =
                    config.AlwaysOnTop,

                Size = UDim2.fromOffset(
                    config.Width,
                    config.Height
                )
            })
        end)

    if not success then
        debugWarn(
            "CreateWindow failed:"
        )

        debugWarn(result)

        Notifications:Error(
            "JustXDoors",
            "UI window failed to create.\nCheck console."
        )

        return nil
    end

    if not result then
        debugWarn(
            "CreateWindow returned nil"
        )

        Notifications:Error(
            "JustXDoors",
            "UI window returned nil."
        )

        return nil
    end

    Window = result
    self.Window = Window

    pcall(function()
        Window:SetCornerRadius(
            config.CornerRadius
        )
    end)

    pcall(function()
        Window:SetAlwaysOnTop(
            config.AlwaysOnTop
        )
    end)

    pcall(function()
        library:SetNotifySide(
            config.NotifySide
        )
    end)

    debugLog(
        "Window created successfully"
    )

    return Window
end

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
        pcall(function()
            if description then
                tab =
                    Window:AddTab({
                        Name = tabName,
                        Icon = icon,
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

    self.Tabs[tabName] = tab

    debugLog(
        "Tab created:",
        tabName
    )

    return tab
end

function UI:GetTab(name)
    return self.Tabs[name]
end

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
        pcall(function()
            group =
                tab:AddGroupbox({
                    Side =
                        side or "Left",

                    Name = name,

                    IconName = icon,

                    Description =
                        description
                })
        end)

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

    self.Groups[name] = group

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

    local success,
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
        self.Groups[name] = group
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

    local success,
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
        self.Groups[name] = group
    end

    return group
end

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
        pcall(function()
            element =
                group:AddToggle(
                    id,
                    options or {}
                )
        end)

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

    self.Elements[id] = element

    return element
end

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
        pcall(function()
            element =
                group:AddCheckbox(
                    id,
                    options or {}
                )
        end)

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

    self.Elements[id] = element

    return element
end

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
        pcall(function()
            element =
                group:AddButton({
                    Text = tostring(id),

                    Func =
                        type(callback)
                        == "function"
                        and callback
                        or function()
                        end
                })
        end)

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

    self.Elements[id] = element

    return element
end

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
        pcall(function()
            element =
                group:AddInput(
                    id,
                    options or {}
                )
        end)

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

    self.Elements[id] = element

    return element
end

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
        pcall(function()
            element =
                group:AddSlider(
                    id,
                    options or {}
                )
        end)

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

    self.Elements[id] = element

    return element
end

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
        pcall(function()
            element =
                group:AddDropdown(
                    id,
                    options or {}
                )
        end)

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

    self.Elements[id] = element

    return element
end

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
        pcall(function()
            if type(options) == "table" then
                options.Text = text

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

function UI:AddDivider(group)
    if not group then
        return nil
    end

    local element

    local success,
        errorMessage =
        pcall(function()
            element =
                group:AddDivider()
        end)

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

function UI:Notify(options)
    return Notifications:Notify(
        options
    )
end

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

function UI:SetCornerRadius(value)
    if not Window then
        return
    end

    value = tonumber(value)

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

    value = value == true

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
    Notifications:SetSide(
        side
    )
end

function UI:SetSidebarWidth(width)
    if not Window then
        return
    end

    width = tonumber(width)

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

return UI
