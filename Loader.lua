local BASE = "https://raw.githubusercontent.com/JustUser-ALT/JustXDoors/main/"

local function loadModule(path)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(BASE .. path))()
    end)

    if not ok then
        warn("[JustXDoors] Failed to load " .. path .. ": " .. tostring(result))
        return nil
    end

    return result
end

local Core = loadModule("Core.lua")
if not Core then
    return
end

local Main = loadModule("Game/Main.lua")
local Hotel = loadModule("Game/Hotel.lua")

local CoreInstance = Core:Create()

if not CoreInstance then
    warn("[JustXDoors] Failed to create Core.")
    return
end

if Main and Main.Init then
    local ok, err = pcall(function()
        Main:Init(CoreInstance)
    end)

    if not ok then
        warn("[JustXDoors] Main error: " .. tostring(err))
    end
end

if Hotel and Hotel.Init then
    local ok, err = pcall(function()
        Hotel:Init(CoreInstance)
    end)

    if not ok then
        warn("[JustXDoors] Hotel error: " .. tostring(err))
    end
end

if CoreInstance.CreateSettings then
    CoreInstance:CreateSettings()
end
