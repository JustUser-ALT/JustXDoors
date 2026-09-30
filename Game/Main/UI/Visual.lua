local VisualUI = {}

function VisualUI:Create(ctx)
    local pages = ctx.VisualPages
    if not pages then
        pages = ctx.Tab:MultiSection({
            Pages = {"Visual", "Audio"},
            Column = 2,
            Icon = "eye",
        })
        ctx.VisualPages = pages
    end
    if not pages then return false end

    local page = pages:Page("Visual")
    if not page then return false end

    local a = ctx.Actions
    local E = ctx.Elements

    E.FullBright = page:Toggle({
        Name = "Fullbright",
        Flag = "Main_FullBright",
        Default = false,
        Callback = function(v) a.SetFullBright(v) end,
    })

    E.Brightness = page:Slider({
        Name = "Brightness",
        Flag = "Main_Brightness",
        Min = 25, Max = 100, Step = 1, Default = 35,
        Callback = function(v) a.SetBrightness(v) end,
    })

    E.NoFog = page:Toggle({
        Name = "No Fog",
        Flag = "Main_NoFog",
        Default = false,
        Callback = function(v) a.SetNoFog(v) end,
    })

    return true
end

return VisualUI
