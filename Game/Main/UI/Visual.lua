local VisualUI = {}

function VisualUI:Create(ctx)
    local Tab = ctx.Tab
    if not Tab then return false end

    local section = Tab:Section({
        Title = "Visual",
        Column = 2,
        Icon = "eye",
    })
    if not section then return false end

    local a = ctx.Actions
    local E = ctx.Elements

    E.FullBright = section:Toggle({
        Name = "Fullbright",
        Flag = "Main_FullBright",
        Default = false,
        Callback = function(v) a.SetFullBright(v) end,
    })

    E.Brightness = section:Slider({
        Name = "Brightness",
        Flag = "Main_Brightness",
        Min = 25, Max = 100, Step = 1, Default = 35,
        Callback = function(v) a.SetBrightness(v) end,
    })

    E.NoFog = section:Toggle({
        Name = "No Fog",
        Flag = "Main_NoFog",
        Default = false,
        Callback = function(v) a.SetNoFog(v) end,
    })

    return true
end

return VisualUI
