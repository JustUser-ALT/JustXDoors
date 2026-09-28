local Core = {}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LibraryURL = "https://raw.githubusercontent.com/JustUser-ALT/JustLib/refs/heads/main/JustLib.lua"
local IconURL = "https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua"

local function loadLibrary()
    local ok, source = pcall(function()
        return game:HttpGet(LibraryURL)
    end)

    if not ok or not source or source == "" then
        return nil, "Failed to download JustLib"
    end

    local okLoad, fn = pcall(loadstring, source)

    if not okLoad or not fn then
        return nil, "Failed to load JustLib"
    end

    local okInit, lib = pcall(fn)

    if not okInit or type(lib) ~= "table" then
        return nil, "Failed to initialize JustLib"
    end

    return lib
end

local function prepareFolders()
    if not makefolder then
        return
    end

    pcall(makefolder, "JustXLibrary")
    pcall(makefolder, "JustXLibrary/Doors")
end

function Core:Create()
    if self.Window then
        return self
    end

    prepareFolders()

    local JL, err = loadLibrary()

    if not JL then
        warn("[JustXDoors] " .. tostring(err))
        return nil
    end

    self.Library = JL

    pcall(function()
        JL:LoadIconPack(IconURL)
    end)

    local Window = JL:Window({
        Title = "JustXDoors",
        Icon = "door-open",
        Config = "JustXLibrary/Doors/JustXDoors",
        Width = 680,
        Height = 440,
        Columns = 3,
        Backdrop = true,
        Hotkey = Enum.KeyCode.RightShift,
        Settings = true,
    })

    if not Window then
        return nil
    end

    self.Window = Window
    self.Tabs = {}
    self.Sections = {}
    self.Flags = JL.Flags

    Window:Open()

    Window:HomeTab({
        WelcomeTitle = "JustXDoors",
        Tier = "Doors",
        ShowFriends = true,
    })

    Window:Settings()

    return self
end

function Core:Tab(options)
    if not self.Window then
        return nil
    end

    options = options or {}

    local tab = self.Window:Tab({
        Name = options.Name or "Tab",
        Icon = options.Icon,
        Type = options.Type or "Grid",
    })

    if tab then
        self.Tabs[options.Name] = tab
    end

    return tab
end

function Core:Section(tab, options)
    if not tab then
        return nil
    end

    local section = tab:Section(options or {})

    if section and options and options.Title then
        self.Sections[options.Title] = section
    end

    return section
end

function Core:Notify(options)
    if not self.Window then
        return
    end

    self.Window:Notify(options or {})
end

function Core:Confirm(options)
    if not self.Library then
        return false
    end

    return self.Library:Confirm(options or {})
end

function Core:GetTab(name)
    return self.Tabs and self.Tabs[name]
end

function Core:GetSection(name)
    return self.Sections and self.Sections[name]
end

function Core:GetLibrary()
    return self.Library
end

function Core:GetWindow()
    return self.Window
end

function Core:GetPlayer()
    return Players.LocalPlayer
end

function Core:GetCharacter()
    local player = Players.LocalPlayer

    return player and player.Character
end

function Core:GetHumanoid()
    local character = self:GetCharacter()

    return character and character:FindFirstChildOfClass("Humanoid")
end

function Core:GetRoot()
    local character = self:GetCharacter()

    return character and character:FindFirstChild("HumanoidRootPart")
end

function Core:Destroy()
    if self.Window and self.Window.Destroy then
        pcall(function()
            self.Window:Destroy()
        end)
    end

    self.Window = nil
    self.Library = nil
    self.Tabs = {}
    self.Sections = {}
end

return Core
