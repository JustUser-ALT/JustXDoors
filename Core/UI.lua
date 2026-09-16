local UI = {}

local Environment = require("Core/Environment")
local Notifications = require("Core/Notifications")

local loadstring = Environment:Get("loadstring")
local request = Environment:Get("request")

local Library
local Window

UI.Library = nil
UI.Window = nil
UI.Tabs = {}
UI.Groups = {}
UI.Elements = {}

UI.Config = {
    Title = "JustXDoors",
    Footer = "DOORS",
    Icon = nil,

    Width = 720,
    Height = 520,

    Center = true,
    AutoShow = true,
    Resizable = true,

    MobileButtonsSide = "Right",
    NotifySide = "Right",

    ShowCustomCursor = false,
    AlwaysOnTop = true,

    CornerRadius = 8
}

local OBSIDIAN_URL =
    "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"

local function loadLibrary()
    if type(loadstring) ~= "function" then
        return nil, "loadstring is unavailable"
    end

    local success, result = pcall(function()
        local source = game:HttpGet(OBSIDIAN_URL)
        return loadstring(source)()
    end)

    if not success then
        return nil, result
    end

    return result
end

local function normalizeTabInfo(name, icon, description)
    if type(name) == "table" then
        return name
    end

    return {
        Name = tostring(name),
        Icon = icon,
        Description = description
    }
end

function UI:Load()
    if Library then
        return Library
    end

    local success, result = loadLibrary()

    if not success or not result then
        Notifications:Error(
            "JustXDoors",
            "Failed to load UI library"
        )

        return nil
    end

    Library = result
    self.Library = Library

    Library.ForceCheckbox = false
    Library.ShowToggleFrameInKeybinds = true
    Library.ShowCustomCursor = self.Config.ShowCustomCursor

    return Library
end

function UI:Create()
    if Window then
        return Window
    end

    local library = self:Load()

    if not library then
        return nil
    end

    local config = self.Config

    local success, result = pcall(function()
        return library:CreateWindow({
            Title = config.Title,
            Footer = config.Footer,

            Icon = config.Icon,

            Center = config.Center,
            AutoShow = config.AutoShow,
            Resizable = config.Resizable,

            MobileButtonsSide = config.MobileButtonsSide,
            NotifySide = config.NotifySide,

            ShowCustomCursor = config.ShowCustomCursor,
            AlwaysOnTop = config.AlwaysOnTop,

            Size = UDim2.fromOffset(
                config.Width,
                config.Height
            )
        })
    end)

    if not success then
        Notifications:Error(
            "JustXDoors",
            "Failed to create UI"
        )

        return nil
    end

    Window = result
    self.Window = Window

    pcall(function()
        Window:SetCornerRadius(config.CornerRadius)
    end)

    pcall(function()
        Window:SetAlwaysOnTop(config.AlwaysOnTop)
    end)

    pcall(function()
        library:SetNotifySide(config.NotifySide)
    end)

    return Window
end

function UI:AddTab(name, icon, description)
    if not Window then
        self:Create()
    end

    if not Window then
        return nil
    end

    local info = normalizeTabInfo(
        name,
        icon,
        description
    )

    local tab

    local success = pcall(function()
        tab = Window:AddTab(info)
    end)

    if not success or not tab then
        return nil
    end

    local tabName = info.Name or tostring(name)

    self.Tabs[tabName] = tab

    return tab
end

function UI:GetTab(name)
    return self.Tabs[name]
end

function UI:AddGroupbox(tab, name, side, icon, description)
    if not tab then
        return nil
    end

    local group

    local success = pcall(function()
        group = tab:AddGroupbox({
            Side = side or "Left",
            Name = name,
            IconName = icon,
            Description = description
        })
    end)

    if not success or not group then
        return nil
    end

    self.Groups[name] = group

    return group
end

function UI:AddLeftGroupbox(tab, name, icon, description)
    return self:AddGroupbox(
        tab,
        name,
        "Left",
        icon,
        description
    )
end

function UI:AddRightGroupbox(tab, name, icon, description)
    return self:AddGroupbox(
        tab,
        name,
        "Right",
        icon,
        description
    )
end

function UI:AddToggle(group, id, options)
    if not group then
        return nil
    end

    local element

    local success = pcall(function()
        element = group:AddToggle(id, options or {})
    end)

    if not success then
        return nil
    end

    self.Elements[id] = element

    return element
end

function UI:AddCheckbox(group, id, options)
    if not group then
        return nil
    end

    local element

    local success = pcall(function()
        element = group:AddCheckbox(id, options or {})
    end)

    if not success then
        return nil
    end

    self.Elements[id] = element

    return element
end

function UI:AddButton(group, id, callback)
    if not group then
        return nil
    end

    local element

    local success = pcall(function()
        element = group:AddButton(id, callback)
    end)

    if not success then
        return nil
    end

    self.Elements[id] = element

    return element
end

function UI:AddInput(group, id, options)
    if not group then
        return nil
    end

    local element

    local success = pcall(function()
        element = group:AddInput(id, options or {})
    end)

    if not success then
        return nil
    end

    self.Elements[id] = element

    return element
end

function UI:AddSlider(group, id, options)
    if not group then
        return nil
    end

    local element

    local success = pcall(function()
        element = group:AddSlider(id, options or {})
    end)

    if not success then
        return nil
    end

    self.Elements[id] = element

    return element
end

function UI:AddDropdown(group, id, options)
    if not group then
        return nil
    end

    local element

    local success = pcall(function()
        element = group:AddDropdown(id, options or {})
    end)

    if not success then
        return nil
    end

    self.Elements[id] = element

    return element
end

function UI:AddLabel(group, text, options)
    if not group then
        return nil
    end

    local element

    local success = pcall(function()
        if type(options) == "table" then
            options.Text = text
            element = group:AddLabel(options)
        else
            element = group:AddLabel(text, options)
        end
    end)

    if not success then
        return nil
    end

    return element
end

function UI:AddDivider(group)
    if not group then
        return nil
    end

    local element

    local success = pcall(function()
        element = group:AddDivider()
    end)

    if not success then
        return nil
    end

    return element
end

function UI:AddTabbox(tab, side, name)
    if not tab then
        return nil
    end

    local tabbox

    local success = pcall(function()
        if string.lower(side or "Left") == "right" then
            tabbox = tab:AddRightTabbox(name)
        else
            tabbox = tab:AddLeftTabbox(name)
        end
    end)

    if not success then
        return nil
    end

    return tabbox
end

function UI:Notify(options)
    if not Library then
        return Notifications:Notify(options)
    end

    local success, result = pcall(function()
        return Library:Notify({
            Title = options.Title or "JustXDoors",
            Description = options.Text or options.Description or "",
            Time = options.Duration or 4,
            Icon = options.Icon
        })
    end)

    if success then
        return result
    end

    return Notifications:Notify(options)
end

function UI:SetVisible(value)
    if not Window then
        return
    end

    pcall(function()
        Window:Toggle(value)
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

    pcall(function()
        Window:SetCornerRadius(value)
    end)
end

function UI:SetAlwaysOnTop(value)
    if not Window then
        return
    end

    pcall(function()
        Window:SetAlwaysOnTop(value == true)
    end)
end

function UI:SetNotifySide(side)
    side = tostring(side)

    if Library then
        pcall(function()
            Library:SetNotifySide(side)
        end)
    end

    self.Config.NotifySide = side
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
        Window:SetSidebarWidth(width)
    end)
end

function UI:SetCompact(value)
    if not Window then
        return
    end

    pcall(function()
        Window:SetCompact(value == true)
    end)
end

function UI:OnUnload(callback)
    if not Library then
        return
    end

    if type(callback) ~= "function" then
        return
    end

    pcall(function()
        Library:OnUnload(callback)
    end)
end

function UI:Unload()
    if not Library then
        return
    end

    pcall(function()
        Library:Unload()
    end)

    Library = nil
    Window = nil

    self.Library = nil
    self.Window = nil

    table.clear(self.Tabs)
    table.clear(self.Groups)
    table.clear(self.Elements)
end

return UI
