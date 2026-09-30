local Hotel = {}

local Core
local Elements = {}
local Connections = {}

function Hotel:Init(core, modules)
    if self.Initialized then return self end
    if type(core) ~= "table" then
        warn("[JustXDoors Hotel] Core is missing.")
        return self
    end

    Core = core
    modules = modules or {}

    local ESP = modules.ESP
    local Notifications = modules.Notifications

    if type(ESP) ~= "table" or type(ESP.Init) ~= "function" then
        warn("[JustXDoors Hotel] ESP module is missing.")
        return self
    end

    ESP:Init({ Core = Core })

    self.ESP = ESP
    self.Notifications = Notifications

    local ctx = {
        Core = Core,
        Elements = Elements,
        Enabled = ESP.Enabled,
        Colors = ESP.Colors,
        ESP = ESP.Objects,
        Display = ESP.Display,
        Tab = nil,
        VisualPages = nil,
        EntityPages = nil,
        ApplyInteractables = function(selected) ESP:ApplyInteractables(selected) end,
        ApplyItems = function(selected) ESP:ApplyItems(selected) end,
        RefreshLabels = function() ESP:RefreshLabels() end,
        SetEntities = function(selected)
            local state = {
                Rush=false, Ambush=false, Dupe=false, Eyes=false, Sally=false,
                Seek=false, Figure=false, Snare=false, Screech=false,
            }
            if type(selected) == "table" then
                if #selected > 0 then
                    for _, value in ipairs(selected) do
                        if state[value] ~= nil then state[value] = true end
                    end
                else
                    for name in pairs(state) do state[name] = selected[name] == true end
                end
            elseif state[selected] ~= nil then
                state[selected] = true
            end
            ESP:SetEntities(state)
        end,
        Notifications = Notifications,
    }

    if type(Notifications) == "table" and type(Notifications.Init) == "function" then
        ctx.NotifyEntities = function() end
        Notifications:Init({
            Core = Core,
            Elements = Elements,
        })
    end

    Hotel.UI = modules.UI
    if type(Hotel.UI) ~= "table" then
        warn("[JustXDoors Hotel] UI modules are missing.")
        return self
    end

    local order = {
        Hotel.UI.Game,
        Hotel.UI.Visual,
        Hotel.UI.Settings,
        Hotel.UI.Entities,
        Hotel.UI.Notifications,
        Hotel.UI.Anti,
    }

    for _, module in ipairs(order) do
        if module and type(module.Create) == "function" then
            local ok, result = pcall(function() return module:Create(ctx) end)
            if not ok or result == false then
                warn("[JustXDoors Hotel] Failed to create UI module: " .. tostring(result))
                return self
            end
        end
    end

    self.Initialized = true
    return self
end

function Hotel:Destroy()
    if Hotel.UI then
        -- UI is owned by Core/JustLib and is intentionally not destroyed here.
    end
    if self.ESP and type(self.ESP.Destroy) == "function" then
        self.ESP:Destroy()
    end
    if self.Notifications and type(self.Notifications.Destroy) == "function" then
        self.Notifications:Destroy()
    end
    self.ESP = nil
    self.Notifications = nil
    self.Initialized = false
    table.clear(Elements)
    table.clear(Connections)
    Core = nil
end

return Hotel
