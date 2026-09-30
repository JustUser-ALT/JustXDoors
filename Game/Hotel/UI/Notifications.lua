local NotificationsUI = {}

function NotificationsUI:Create(ctx)
    local pages = ctx.EntityPages
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
        Callback = function(value)
            if ctx.Notifications and ctx.Notifications.SetSelected then
                ctx.Notifications:SetSelected(value)
            end
        end,
    })

    ctx.Elements.NotifyEntities = page:Toggle({
        Name = "Notify Entities",
        Flag = "Hotel_NotifyEntities",
        Default = false,
        Callback = function(value)
            if ctx.Notifications and ctx.Notifications.SetEnabled then
                ctx.Notifications:SetEnabled(value)
            end
        end,
    })

    return true
end

return NotificationsUI
