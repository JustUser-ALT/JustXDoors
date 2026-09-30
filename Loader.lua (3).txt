local BASE = "https://raw.githubusercontent.com/JustUser-ALT/JustXDoors/main/"

local Core  = loadstring(game:HttpGet(BASE .. "Core.lua"))()
local Main  = loadstring(game:HttpGet(BASE .. "Game/Main.lua"))()
local Hotel = loadstring(game:HttpGet(BASE .. "Game/Hotel.lua"))()

local CoreInstance = Core:Create()

if not CoreInstance then
    warn("[JustXDoors] Core failed to initialize.")
    return
end

if Main and Main.Init then
    Main:Init(CoreInstance)
end

-- Load Hotel only when actually on the Hotel floor
local function getFloor()
    local gd = game:GetService("ReplicatedStorage"):FindFirstChild("GameData")
    if not gd then return nil end
    local f = gd:FindFirstChild("Floor")
    return f and f.Value
end

local floor = getFloor()
if floor == "Hotel" or floor == nil then   -- nil = still loading, default to Hotel
    if Hotel and Hotel.Init then
        Hotel:Init(CoreInstance)
    end
end
