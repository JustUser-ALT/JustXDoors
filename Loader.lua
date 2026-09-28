local BASE = "https://raw.githubusercontent.com/JustUser-ALT/JustXDoors/main/"

local Core = loadstring(game:HttpGet(BASE .. "Core.lua"))()
local Main = loadstring(game:HttpGet(BASE .. "Game/Main.lua"))()

local CoreInstance = Core:Create()

if Main and Main.Init then
    Main:Init(CoreInstance)
end
