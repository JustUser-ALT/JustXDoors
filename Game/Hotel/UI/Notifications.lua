local NotificationsUI = {}

function NotificationsUI:Create(ctx)
    local pages = ctx.VisualPages
    if not pages then return false end

    local page = pages:Page("Notifications")
    if not page then return false end

    ctx.Elements.NotificationEntities = page:Dropdown({
        Name = "Entities",
        Flag = "Hotel_NotificationEntities",
        Options = {"Rush","Ambush","Dupe","Eyes","Sally","Seek","Figure","Screech"},
        MultiSelect = true,
        MaxSelect = 8,
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
