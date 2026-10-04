local Core = {}

local Players = game:GetService("Players")

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
    self.SettingsCreated = false
    self.CleanupHandlers = {}
    self.CleanupOrder = {}
    self.Destroying = false

    Window:Open()

    Window:HomeTab({
        WelcomeTitle = "JustXDoors",
        Tier = "Doors",
        ShowFriends = true,
    })

    return self
end

function Core:CreateSettings()
    if not self.Window or self.SettingsCreated then
        return
    end

    local ok, err = pcall(function()
        self.Window:Settings()
    end)

    if not ok then
        warn("[JustXDoors] Settings error: " .. tostring(err))
        return
    end

    self.SettingsCreated = true
end

function Core:Tab(options)
    if not self.Window then
        return nil
    end

    options = options or {}

    local name = options.Name or "Tab"

    local tab = self.Window:Tab({
        Name = name,
        Icon = options.Icon,
        Type = options.Type or "Grid",
    })

    if tab then
        self.Tabs[name] = tab
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

    pcall(function()
        self.Window:Notify(options or {})
    end)
end

function Core:Confirm(options)
    if not self.Library then
        return false
    end

    local ok, result = pcall(function()
        return self.Library:Confirm(options or {})
    end)

    if ok then
        return result
    end

    return false
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

function Core:RegisterCleanup(name, callback)
    if type(callback) ~= "function" then
        return false
    end

    self.CleanupHandlers = self.CleanupHandlers or {}
    self.CleanupOrder = self.CleanupOrder or {}

    local key = name or tostring(#self.CleanupOrder + 1)
    if self.CleanupHandlers[key] == nil then
        table.insert(self.CleanupOrder, key)
    end

    self.CleanupHandlers[key] = callback
    return true
end

function Core:UnregisterCleanup(name)
    if self.CleanupHandlers then
        self.CleanupHandlers[name] = nil
    end
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
    if self.Destroying then
        return
    end

    self.Destroying = true

    -- Modules must restore everything they changed before the UI disappears.
    -- Run cleanup handlers in reverse registration order so dependent systems
    -- (Hotel/Anti) are stopped before the shared Main systems are torn down.
    local handlers = self.CleanupHandlers or {}
    local order = self.CleanupOrder or {}

    for index = #order, 1, -1 do
        local name = order[index]
        local callback = handlers[name]
        if callback then
            pcall(callback)
        end
    end

    for name, callback in pairs(handlers) do
        local alreadyRun = false
        for _, orderedName in ipairs(order) do
            if orderedName == name then
                alreadyRun = true
                break
            end
        end

        if not alreadyRun and callback then
            pcall(callback)
        end
    end

    table.clear(handlers)
    self.CleanupOrder = {}

    if self.Window and self.Window.Destroy then
        pcall(function()
            self.Window:Destroy()
        end)
    end

    self.Window = nil
    self.Library = nil
    self.Tabs = {}
    self.Sections = {}
    self.SettingsCreated = false
    self.Destroying = false
end

return Core
