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

    if Main and Main.Init then
        local ok, err = pcall(function()
            Main:Init(CoreInstance)
        end)

        if not ok then
            warn("[JustXDoors] Game/Main.lua error: " .. tostring(err))
        end
    end

    local HotelVisual = load("Game/Hotel/Visual.lua")
    local HotelGame = load("Game/Hotel/Game.lua")
    local HotelESP = load("Game/Hotel/ESP.lua")
    local HotelNotifications = load("Game/Hotel/Notifications.lua")
    local Hotel = load("Game/Hotel.lua")

    local HotelModules = {
        Visual = HotelVisual,
        Game = HotelGame,
        ESP = HotelESP,
        Notifications = HotelNotifications,
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
