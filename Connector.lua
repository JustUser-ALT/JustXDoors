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

    if CoreInstance.CreateSettings then
        CoreInstance:CreateSettings()
    end

    return CoreInstance
end

return Connector
