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

    -- JustLib Settings -> Close Hub destroys its ScreenGui directly.
    -- It does not call Window:Destroy() or shared._JLActive.destroy().
    -- ScreenGui.Destroying is therefore the reliable unload signal.
    pcall(function()
        local CoreGui = game:GetService("CoreGui")
        local PlayerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local gui = CoreGui:FindFirstChild("JustLib")
            or (PlayerGui and PlayerGui:FindFirstChild("JustLib"))

        if gui then
            self.GUI = gui
            self.GUIDestroyConnection = gui.Destroying:Connect(function()
                if not self.Destroying then
                    self:Destroy()
                end
            end)
        end
    end)

    -- JustLib's Settings -> Close Hub path does NOT call Window:Destroy().
    -- It calls shared._JLActive.destroy() directly. Hook that path as well,
    -- otherwise the UI disappears while Main/Hotel keep all runtime features.
    pcall(function()
        if type(shared) == "table" and type(shared._JLActive) == "table"
            and type(shared._JLActive.destroy) == "function" then

            local libraryDestroy = shared._JLActive.destroy
            self.LibraryDestroy = libraryDestroy

            shared._JLActive.destroy = function(...)
                if not self.Destroying then
                    self:Destroy()
                end
            end
        end
    end)

    -- Window:Destroy() is the second close path used by JustLib itself.
    -- Keep it wrapped as well so every unload route reaches Core cleanup.
    local rawWindowDestroy = Window.Destroy
    if type(rawWindowDestroy) == "function" then
        self.RawWindowDestroy = rawWindowDestroy

        pcall(function()
            Window.Destroy = function(window, ...)
                if window == self.Window and not self.Destroying then
                    self:Destroy()
                    return
                end

                return rawWindowDestroy(window, ...)
            end
        end)
    end

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

    local handlers = self.CleanupHandlers or {}
    local order = self.CleanupOrder or {}
    local ran = {}

    local function runCleanup(name, callback)
        if not callback or ran[name] then
            return
        end

        ran[name] = true

        local ok, err = pcall(callback)
        if not ok then
            warn("[JustXDoors Cleanup] " .. tostring(name) .. ":Destroy FAILED: " .. tostring(err))
        else
            warn("[JustXDoors Cleanup] " .. tostring(name) .. ":Destroy OK")
        end
    end

    -- Reverse order: dependent modules first.
    for index = #order, 1, -1 do
        local name = order[index]
        runCleanup(name, handlers[name])
    end

    -- Catch handlers that were registered without an order entry.
    for name, callback in pairs(handlers) do
        runCleanup(name, callback)
    end

    table.clear(handlers)
    self.CleanupOrder = {}

    local window = self.Window
    local rawWindowDestroy = self.RawWindowDestroy
    local guiDestroyConnection = self.GUIDestroyConnection

    if guiDestroyConnection then
        pcall(function()
            guiDestroyConnection:Disconnect()
        end)
    end

    self.GUIDestroyConnection = nil
    self.GUI = nil
    self.Window = nil

    if window and rawWindowDestroy then
        local ok, err = pcall(function()
            rawWindowDestroy(window)
        end)

        if not ok then
            warn("[JustXDoors Cleanup] Window destroy FAILED: " .. tostring(err))
        end
    elseif window and window.Destroy then
        local ok, err = pcall(function()
            window:Destroy()
        end)

        if not ok then
            warn("[JustXDoors Cleanup] Window destroy FAILED: " .. tostring(err))
        end
    end

    -- In case JustLib left its ScreenGui behind, remove it explicitly.
    pcall(function()
        local gui = game:GetService("CoreGui"):FindFirstChild("JustLib")
        if gui then
            gui:Destroy()
        end
    end)

    pcall(function()
        local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local gui = playerGui and playerGui:FindFirstChild("JustLib")
        if gui then
            gui:Destroy()
        end
    end)

    self.Library = nil
    self.Tabs = {}
    self.Sections = {}
    self.SettingsCreated = false
    self.RawWindowDestroy = nil

    -- Keep this true for the remainder of this cleanup call. This prevents
    -- GUI Destroying callbacks or other shutdown paths from starting cleanup
    -- a second time.
    self.Destroying = true

    warn("[JustXDoors Cleanup] Core cleanup finished")
end

return Core
