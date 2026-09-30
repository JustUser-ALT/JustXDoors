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

    local modules = {
        "Game/Main.lua",
        "Game/Hotel.lua",
    }

    for _, path in ipairs(modules) do
        local module = load(path)

        if module and module.Init then
            local ok, err = pcall(function()
                module:Init(CoreInstance)
            end)

            if not ok then
                warn("[JustXDoors] " .. path .. " error: " .. tostring(err))
            end
        end
    end

    if CoreInstance.CreateSettings then
        CoreInstance:CreateSettings()
    end

    return CoreInstance
end

return Connector
