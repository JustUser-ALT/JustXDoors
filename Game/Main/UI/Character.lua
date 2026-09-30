local CharacterUI = {}

function CharacterUI:Create(ctx)
    if not ctx.Tab then
        ctx.Tab = ctx.Core:Tab({
            Name = "Main",
            Icon = "user",
            Type = "Grid",
        })
    end

    local pages = ctx.CharacterPages
    if not pages then
        pages = ctx.Tab:MultiSection({
            Pages = {"Character", "Bypass"},
            Column = 1,
            Icon = "user",
        })
        ctx.CharacterPages = pages
    end
    if not pages then return false end

    local page = pages:Page("Character")
    if not page then return false end

    local a = ctx.Actions
    local E = ctx.Elements

    E.SpeedBoost = page:Slider({
        Name = "Speed Boost",
        Flag = "Main_SpeedBoost",
        Min = 0, Max = 100, Step = 1, Default = 0,
        Callback = function(v) a.SetSpeedBoost(v) end,
    })

    E.FlySpeed = page:Slider({
        Name = "Fly Speed",
        Flag = "Main_FlySpeed",
        Min = 0, Max = 115, Step = 1, Default = 20,
        Callback = function(v) a.SetFlySpeed(v) end,
    })

    E.SpeedBoostToggle = page:Toggle({
        Name = "Enable Speed Boost",
        Flag = "Main_SpeedBoostToggle",
        Default = false,
        Callback = function(v) a.SetSpeedBoostEnabled(v) end,
    })

    E.RemoveAcceleration = page:Toggle({
        Name = "Remove Acceleration",
        Flag = "Main_RemoveAcceleration",
        Default = false,
        Callback = function(v) a.SetRemoveAcceleration(v) end,
    })

    E.Fly = page:Toggle({
        Name = "Fly",
        Flag = "Main_Fly",
        Default = false,
        Callback = function(v) a.SetFlyEnabled(v) end,
    })

    E.Noclip = page:Toggle({
        Name = "Noclip",
        Flag = "Main_Noclip",
        Default = false,
        Callback = function(v) a.SetNoclipEnabled(v) end,
    })

    page:Divider()

    E.EnableJump = page:Toggle({
        Name = "Enable Jumping",
        Flag = "Main_EnableJump",
        Default = false,
        Callback = function(v) a.SetJumpEnabled(v) end,
    })

    E.InfiniteJump = page:Toggle({
        Name = "Infinite Jump",
        Flag = "Main_InfiniteJump",
        Default = false,
        Callback = function(v) a.SetInfiniteJumpEnabled(v) end,
    })

    E.EnableSlide = page:Toggle({
        Name = "Enable Sliding",
        Flag = "Main_EnableSlide",
        Default = false,
        Callback = function(v) a.SetSlideEnabled(v) end,
    })

    return true
end

return CharacterUI
