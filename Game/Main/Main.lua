local Main = {}

local Core
local Services
local Connections
local Settings
local Notifications
local UI

local initialized = false
local built = false

function Main:Init(CoreModules)
    if initialized then
        return self
    end

    initialized = true

    Core = CoreModules

    Services = Core.Services
    Connections = Core.Connections
    Settings = Core.Settings
    Notifications = Core.Notifications
    UI = Core.UI

    return self
end

function Main:Build()
    if built then
        return self
    end

    if not initialized then
        error("Game/Main/Main.lua was not initialized")
    end

    built = true

    -- Здесь позже подключим:
    -- Speed Boost
    -- Remove Acceleration
    -- Fly
    -- Noclip
    -- Jumping
    -- Sliding
    -- Infinite Jump
    -- Remove Closet Delay
    -- Door Reach
    -- Prompt Reach
    -- Instant Prompt
    -- Prompt Clip
    -- Disable Idle Kick
    -- Infinite Revives
    -- Position Spoof
    -- и т.д.

    return self
end

function Main:Destroy()
    Connections:DisconnectGroup("GameMain")

    initialized = false
    built = false

    Core = nil
    Services = nil
    Connections = nil
    Settings = nil
    Notifications = nil
    UI = nil
end

return Main
