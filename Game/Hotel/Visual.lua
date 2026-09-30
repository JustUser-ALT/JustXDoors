local Visual = {}

function Visual:CreateUI(ctx)
    local Core = ctx.Core
    local Elements = ctx.Elements
    local Enabled = ctx.Enabled
    local Colors = ctx.Colors
    local ESP = ctx.ESP

    local Tab = Core:Tab({
        Name = "Hotel",
        Icon = "building-2",
        Type = "Grid",
    })

    if not Tab then return false end

    local gameSection = Tab:Section({
        Title = "Game",
        Column = 1,
        Icon = "joystick",
    })

    if not gameSection then return false end

    Elements.AutoInteract = gameSection:Dropdown({
        Name = "Auto Interact",
        Flag = "Hotel_AutoInteract",
        Options = {},
        MultiSelect = true,
        MaxSelect = 8,
        Default = {},
        Search = true,
        Callback = function() end,
    })

    Elements.AutoLoot = gameSection:Dropdown({
        Name = "Auto Loot",
        Flag = "Hotel_AutoLoot",
        Options = {},
        MultiSelect = true,
        MaxSelect = 8,
        Default = {},
        Search = true,
        Callback = function() end,
    })

    local visualPages = Tab:MultiSection({
        Pages = { "Visual", "Settings" },
        Column = 2,
        Icon = "eye",
    })

    local visualPage = visualPages:Page("Visual")
    local settingsPage = visualPages:Page("Settings")

    Elements.Interactables = visualPage:ValueDropdown({
        Name = "Interactables",
        Flag = "Hotel_Interactables",
        Options = {"Doors","Drawers","Closets","Chest","LockedChest","Vent Gate","Lever","Toolshed","All"},
        MultiSelect = true,
        MaxSelect = 8,
        Default = {},
        Search = true,
        Callback = function(selected)
            ctx.ApplyInteractables(selected)
        end,
    })

    Elements.Items = visualPage:ValueDropdown({
        Name = "Items",
        Flag = "Hotel_Items",
        Options = {"Key","Gold","Bandage","Smoothie","Flashlight","Tip Jar","Vitamins","Lighter","Candle","AlarmClock","Lockpick","Skeleton Key","Shears","Battery","Rift Candle","Rift Smoothie","Rift Jar","Donut","Crucifix","Sally Toy","Electrical Key","Breaker Pole"},
        Values = {Gold = {Min = 1, Max = 6, Default = 1}},
        MultiSelect = true,
        MaxSelect = 24,
        Default = {},
        Search = true,
        Callback = function(selected)
            ctx.ApplyItems(selected)
        end,
    })

    Elements.DisplayName = settingsPage:Toggle({
        Name = "Display Name",
        Flag = "Hotel_DisplayName",
        Default = true,
        Callback = function(value)
            ctx.Display.Name = value
            ctx.RefreshLabels()
        end,
    })

    Elements.DisplayDistance = settingsPage:Toggle({
        Name = "Display Distance",
        Flag = "Hotel_DisplayDistance",
        Default = false,
        Callback = function(value)
            ctx.Display.Distance = value
            ctx.RefreshLabels()
        end,
    })

    for _, kind in ipairs({
        "Doors","Drawers","Closets","Key","Gold","Chest","Bandage","Smoothie",
        "Flashlight","TipJar","Vitamins","Lighter","Candle","AlarmClock",
        "Lockpick","SkeletonKey","Shears","Battery","RiftCandle","RiftSmoothie",
        "RiftJar","Donut","Crucifix","SallyToy","ElectricalKey","BreakerPole",
        "VentGate","Lever","Rush","Ambush","Dupe","Eyes","SallyLingering",
        "SallyMoving","Seek","Figure","Snare","Screech","Toolshed"
    }) do
        Elements[kind .. "Color"] = settingsPage:ColorPicker({
            Name = kind .. " ESP Color",
            Flag = "Hotel_" .. kind .. "Color",
            Default = Colors[kind],
            Callback = function(value)
                Colors[kind] = value
                for _, entry in pairs(ESP[kind]) do
                    for _, highlight in ipairs(entry.Highlights) do
                        if highlight and highlight.Parent then
                            highlight.FillColor = value
                            highlight.OutlineColor = value
                        end
                    end
                    local label = entry.Label and entry.Label:FindFirstChild("Text")
                    if label then label.TextColor3 = value end
                end
            end,
        })
    end

    local entityPages = Tab:MultiSection({
        Pages = {"Entity","Notifications","Anti"},
        Column = 3,
        Icon = "shield",
    })

    local entityPage = entityPages:Page("Entity")
    Elements.Entities = entityPage:Dropdown({
        Name = "Entities",
        Flag = "Hotel_Entities",
        Options = {"Rush","Ambush","Dupe","Eyes","Sally","Seek","Figure","Snare","Screech"},
        MultiSelect = true,
        MaxSelect = 9,
        Default = {},
        Search = true,
        Callback = function(selected)
            ctx.SetEntities(selected)
        end,
    })

    entityPage:Label({Text = "Entity ESP"})

    local notificationsPage = entityPages:Page("Notifications")
    Elements.NotificationEntities = notificationsPage:Dropdown({
        Name = "Entities",
        Flag = "Hotel_NotificationEntities",
        Options = {"Rush","Ambush","Dupe","Eyes","Sally","Seek","Figure","Screech"},
        MultiSelect = true,
        MaxSelect = 8,
        Default = {},
        Search = true,
        Callback = function() end,
    })

    Elements.NotifyEntities = notificationsPage:Toggle({
        Name = "Notify Entities",
        Flag = "Hotel_NotifyEntities",
        Default = false,
        Callback = function() end,
    })

    entityPages:Page("Anti"):Label({Text = "Anti features."})

    return true
end

function Visual:Init(ctx)
    self.Context = ctx
end

return Visual
