--[[
    Main tab module.
    Loaded after General so the Main tab appears directly beneath General in the sidebar.
    The ESP / Notifications / Settings multisection was moved here from Hotel's middle column.
]]

local Module = {}

function Module.Init(Shared)
    local Functions, Globals, Groupboxes, Options, Tabs, Toggles, Window
        = Shared.Functions, Shared.Globals, Shared.Groupboxes, Shared.Options, Shared.Tabs, Shared.Toggles, Shared.Window

    Tabs.Main = Window:AddTab("Main", "gamepad-2", { Columns = 3 })

    Groupboxes.Main_InfoTabbox = Tabs.Main:AddMiddleTabbox("ESP / Notifications / Settings")
    Groupboxes.Main_ESP = Groupboxes.Main_InfoTabbox:AddTab("ESP")
    Groupboxes.Main_Notifications = Groupboxes.Main_InfoTabbox:AddTab("Notifications")
    Groupboxes.Main_Settings = Groupboxes.Main_InfoTabbox:AddTab("Settings")

    local HotelEntities = { "Rush", "Ambush", "Eyes", "Halt", "Sally", "Dupe", "Figure", "Snare", "AR0xMBUSH", "RNIUSHCG==" }

    Groupboxes.Main_ESP:AddToggle("HotelEntityESPToggle", {
        Text = "Entity ESP", Default = false, Tooltip = "Highlights the selected entities."
    })
    Groupboxes.Main_ESP:AddDropdown("HotelEntityESPList", {
        Text = "Entities", Values = HotelEntities, Multi = true, AllowNull = true
    })

    Groupboxes.Main_Notifications:AddToggle("HotelNotifyEntitiesToggle", {
        Text = "Notify Entities", Default = false, Tooltip = "Sends a notification when the selected entities spawn."
    })
    Groupboxes.Main_Notifications:AddDropdown("HotelNotifyEntitiesList", {
        Text = "Entities", Values = HotelEntities, Multi = true, AllowNull = true
    })

    Groupboxes.Main_Settings:AddToggle("EntityChatToggle", { Text = "Notify Chat", Default = false, Tooltip = "Sends a message in the chat when an entity spawns." })
    Groupboxes.Main_Settings:AddInput("EntityChatMessage", { Text = "Message", Default = "spawned!", Numeric = false, Placeholder = "Message" })
    Groupboxes.Main_Settings:AddDivider()
    Groupboxes.Main_Settings:AddDropdown("NotifyStyle", { Text = "Notify Style", Values = { "Abysall", "Doors", "STX", "Library" }, Default = 1 })
    Groupboxes.Main_Settings:AddSlider("NotifySoundVolume", { Text = "Sound Volume", Min = 0, Max = 10, Default = 3, Rounding = 1 })
    Groupboxes.Main_Settings:AddToggle("NotifyPlaySound", { Text = "Play Sound", Default = true, Tooltip = "Makes notifications play an alert sound." })
    Groupboxes.Main_Settings:AddToggle("NotifyKeepNotifications", { Text = "Keep Notifications", Default = false, Tooltip = "Certain notifications will stay on screen until they are no longer needed." })
    Groupboxes.Main_Settings:AddButton({ Text = "Test Notification", DoubleClick = false, Tooltip = "Sends a test notifcation, so you can see how your settings look.", Func = function()
        Functions.Notify({Title = "This is a test."})
    end})
    Groupboxes.Main_Settings:AddDivider()
    Groupboxes.Main_Settings:AddToggle("ShowEntityPath", {
        Text = "Show Entity Path",
        Default = false,
        Tooltip = "Shows the path of entitys."
    })
    Groupboxes.Main_Settings:AddSlider("ShowEntityPathNodeTransparency", {
        Text = "Node Transparency", Default = 0, Min = 0, Max = 1, Rounding = 2, Compact = false,
        Tooltip = "Transparency of the path nodes when shown"
    })
    Groupboxes.Main_Settings:AddSlider("ShowEntityPathLineTransparency", {
        Text = "Line Transparency", Default = 0.15, Min = 0, Max = 1, Rounding = 2, Compact = false,
        Tooltip = "Transparency of the path lines"
    })
    Groupboxes.Main_Settings:AddSlider("ShowEntityPathLineThickness", {
        Text = "Line Thickness", Default = 0.3, Min = 0.08, Max = 1.2, Rounding = 2
    })

    -- Keep the existing Hotel entity color options and behavior, now under Main > Settings.
    Groupboxes.Main_Settings:AddDivider()
    Groupboxes.Main_Settings:AddLabel("Entity ESP Color"):AddColorPicker("HotelEntityESPColor", { Default = Color3.fromRGB(255, 0, 0) })
    local HotelColorNames = {}
    for _, Entity in HotelEntities do
        local Idx = "HotelEntityColor_" .. (Entity:gsub("[^%w]", ""))
        table.insert(HotelColorNames, Idx)
        Groupboxes.Main_Settings:AddLabel(Entity .. " Color"):AddColorPicker(Idx, { Default = Color3.fromRGB(255, 0, 0) })
    end

    table.insert(Globals.FloorEntityLists, {
        ESPToggle = "HotelEntityESPToggle", ESPList = "HotelEntityESPList", ColorPrefix = "HotelEntityColor_",
        NotifyToggle = "HotelNotifyEntitiesToggle", NotifyList = "HotelNotifyEntitiesList"
    })

    local function RefreshHotelEntities()
        if Functions.RefreshEntityESP then Functions.RefreshEntityESP() end
    end
    Toggles.HotelEntityESPToggle:OnChanged(RefreshHotelEntities)
    Options.HotelEntityESPList:OnChanged(RefreshHotelEntities)

    local PreviousHotelColor = Options.HotelEntityESPColor.Value
    Options.HotelEntityESPColor:OnChanged(function(New)
        for _, Idx in HotelColorNames do
            if Options[Idx].Value == PreviousHotelColor then Options[Idx]:SetValue(New) end
        end
        PreviousHotelColor = New
        if Functions.RecolorEntityESP then Functions.RecolorEntityESP() end
    end)
    for _, Idx in HotelColorNames do
        Options[Idx]:OnChanged(function()
            if Functions.RecolorEntityESP then Functions.RecolorEntityESP() end
        end)
    end
end

return Module
