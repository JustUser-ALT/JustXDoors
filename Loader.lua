local BASE = "https://raw.githubusercontent.com/JustUser-ALT/JustXDoors/main/"

local Core = loadstring(game:HttpGet(BASE .. "Core.lua"))()
local Main = loadstring(game:HttpGet(BASE .. "Game/Main.lua"))()
local Hotel = loadstring(game:HttpGet(BASE .. "Game/Hotel.lua"))()

local CoreInstance = Core:Create()

if not CoreInstance then
    return
end

if Main and Main.Init then
    Main:Init(CoreInstance)
end

if Hotel and Hotel.Init then
    Hotel:Init(CoreInstance)
end

if CoreInstance.CreateSettings then
    CoreInstance:CreateSettings()
end
