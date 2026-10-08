local Connector = {}

local BASE = "https://raw.githubusercontent.com/JustUser-ALT/JustXDoors/main/"

local function load(path)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(BASE .. path))()
    end)

    if not ok then
        warn("[JustXDoors] Failed to load " .. path .. ": " .. tostring(result))
        return nil
    end

    return result
end

function Connector:Load()
    local environment = _G

    if type(getgenv) == "function" then
        local ok, globalEnvironment = pcall(getgenv)
        if ok and type(globalEnvironment) == "table" then
            environment = globalEnvironment
        end
    end

    -- A new loader execution must tear down the previous session first.
    -- This prevents old ESP connections, Heartbeats, hooks and modified
    -- properties from surviving when the hub is executed again.
    local previousSession = environment.__JustXDoorsSession
    if type(previousSession) == "table" and type(previousSession.Cleanup) == "function" then
        pcall(previousSession.Cleanup)
    end
    environment.__JustXDoorsSession = nil

    local Core = load("Core.lua")
    if not Core then return end

    local CoreInstance = Core:Create()
    if not CoreInstance then
        warn("[JustXDoors] Failed to create Core.")
        return
    end

    local Main = load("Game/Main.lua")
    local MainCharacterUI = load("Game/Main/UI/Character.lua")
    local MainBypassUI = load("Game/Main/UI/Bypass.lua")
    local MainVisualUI = load("Game/Main/UI/Visual.lua")
    local MainAudioUI = load("Game/Main/UI/Audio.lua")
    local MainMiscUI = load("Game/Main/UI/Misc.lua")
    local MainSettingsUI = load("Game/Main/UI/Settings.lua")

    if Main and Main.Init then
        local MainUIModules = {
            Character = MainCharacterUI,
            Bypass = MainBypassUI,
            Visual = MainVisualUI,
            Audio = MainAudioUI,
            Misc = MainMiscUI,
            Settings = MainSettingsUI,
        }

        local ok, err = pcall(function()
            Main:Init(CoreInstance, MainUIModules)
        end)

        if not ok then
            warn("[JustXDoors] Game/Main.lua error: " .. tostring(err))
        end
    end

    local HotelGame = load("Game/Hotel/Game.lua")
    local HotelESP = load("Game/Hotel/ESP.lua")
    local HotelNotifications = load("Game/Hotel/Notifications.lua")

    local HotelGameUI = load("Game/Hotel/UI/Game.lua")
    local HotelVisualUI = load("Game/Hotel/UI/Visual.lua")
    local HotelSettingsUI = load("Game/Hotel/UI/Settings.lua")
    local HotelEntitiesUI = load("Game/Hotel/UI/Entities.lua")
    local HotelNotificationsUI = load("Game/Hotel/UI/Notifications.lua")
    local HotelAntiUI = load("Game/Hotel/UI/Anti.lua")

    local Hotel = load("Game/Hotel.lua")

    local HotelModules = {
        Main = Main,
        Game = HotelGame,
        ESP = HotelESP,
        Notifications = HotelNotifications,
        UI = {
            Game = HotelGameUI,
            Visual = HotelVisualUI,
            Settings = HotelSettingsUI,
            Entities = HotelEntitiesUI,
            Notifications = HotelNotificationsUI,
            Anti = HotelAntiUI,
        },
    }

    if Hotel and Hotel.Init then
        local ok, err = pcall(function()
            Hotel:Init(CoreInstance, HotelModules)
        end)

        if not ok then
            warn("[JustXDoors] Game/Hotel.lua error: " .. tostring(err))
        end
    end

    -- Register module cleanup BEFORE creating JustLib Settings.
    -- The Settings -> Unload button can be used immediately after the UI
    -- appears, so cleanup must already exist before Settings is built.
    if CoreInstance.RegisterCleanup then
        if Main and Main.Destroy then
            CoreInstance:RegisterCleanup("Main", function()
                Main:Destroy()
            end)
        end

        if Hotel and Hotel.Destroy then
            CoreInstance:RegisterCleanup("Hotel", function()
                Hotel:Destroy()
            end)
        end
    end

    if CoreInstance.CreateSettings then
        CoreInstance:CreateSettings()
    end

    -- JustLib applies the selected Auto Load preset asynchronously after
    -- Settings has been built. Wait briefly before syncing runtime features,
    -- so callbacks read the final saved toggle values rather than defaults.
    task.delay(0.75, function()
        if Main and Main.ReapplyEnabledFeatures then
            pcall(function() Main:ReapplyEnabledFeatures() end)
        end
        if Hotel and Hotel.ReapplyEnabledFeatures then
            pcall(function() Hotel:ReapplyEnabledFeatures() end)
        end
    end)

    local session = {
        Core = CoreInstance,
    }

    function session:Cleanup()
        if self.Core then
            self.Core:Destroy()
        end
    end

    environment.__JustXDoorsSession = session

    return CoreInstance
end

return Connector
