local NotificationsUI = {}

function NotificationsUI:Create(ctx)
    local pages = ctx.VisualPages
    if not pages then return false end

    local page = pages:Page("Notifications")
    if not page then return false end

    ctx.Elements.NotificationEntities = page:Dropdown({
        Name = "Entities",
        Flag = "Hotel_NotificationEntities",
        Options = {
            "Rush","Ambush","Glitch Rush","Glitch Ambush","Glitch Screech",
            "Dupe","Eyes","Sally","Seek","Figure","Dread","Snare","Screech",
        },
        MultiSelect = true,
        MaxSelect = 13,
        Default = {},
        Search = true,
        Callback = function() end,
    })

    ctx.Elements.NotificationItems = page:Dropdown({
        Name = "Items",
        Flag = "Hotel_NotificationItems",
        Options = {
            "Key","Gold","Bandage","Smoothie","Vitamins","Lighter","Candle",
            "Alarm Clock","Lockpick","Skeleton Key","Shears","Rift Candle",
            "Rift Smoothie","Rift Jar","Donut","Crucifix","Sally Toy",
            "Electrical Key","Breaker Pole","Glitch Cube",
        },
        MultiSelect = true,
        MaxSelect = 21,
        Default = {},
        Search = true,
        Callback = function() end,
    })

    ctx.Elements.NotifyEntities = page:Toggle({
        Name = "Notify Entities",
        Flag = "Hotel_NotifyEntities",
        Default = false,
        Callback = function() end,
    })

    return true
end

return NotificationsUI
