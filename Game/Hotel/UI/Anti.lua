local AntiUI = {}

function AntiUI:Create(ctx)
    local pages = ctx.EntityPages
    if not pages then return false end

    local page = pages:Page("Anti")
    if not page then return false end

    page:Label({Text = "Anti features."})
    return true
end

return AntiUI
