local BASE = "https://raw.githubusercontent.com/JustUser-ALT/JustXDoors/main/"

local ok, source = pcall(function()
    return game:HttpGet(BASE .. "Connector.lua")
end)

if not ok or not source or source == "" then
    warn("[JustXDoors] Failed to download Connector.")
    return
end

local okLoad, connector = pcall(loadstring, source)
if not okLoad or type(connector) ~= "function" then
    warn("[JustXDoors] Failed to compile Connector.")
    return
end

local okInit, module = pcall(connector)
if not okInit or type(module) ~= "table" or not module.Load then
    warn("[JustXDoors] Failed to initialize Connector.")
    return
end

module:Load()
