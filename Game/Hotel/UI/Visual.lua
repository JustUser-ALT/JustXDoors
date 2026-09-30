local VisualUI = {}

function VisualUI:Create(ctx)
    if not ctx.Tab then return false end

    local pages = ctx.VisualPages
    if not pages then
        pages = ctx.Tab:MultiSection({
            Pages = {"Visual", "Notifications", "Settings"},
            Column = 2,
            Icon = "eye",
        })
        ctx.VisualPages = pages
    end
    if not pages then return false end

    -- Create both Hotel MultiSections here so their containers are guaranteed
    -- to exist before the later Entity/Anti modules populate their pages.
    if not ctx.EntityPages then
        ctx.EntityPages = ctx.Tab:MultiSection({
            Pages = {"Entity", "Anti"},
            Column = 2,
            Icon = "shield",
        })
    end

    local page = pages:Page("Visual")
    if not page then return false end

    ctx.Elements.Interactables = page:ValueDropdown({
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

    ctx.Elements.Items = page:ValueDropdown({
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

    return true
end

return VisualUI
