local GameUI = {}

function GameUI:Create(ctx)
    if not ctx.Tab then
        ctx.Tab = ctx.Core:Tab({
            Name = "Hotel",
            Icon = "building-2",
            Type = "Grid",
        })
    end
    if not ctx.Tab then return false end

    local section = ctx.Tab:Section({
        Title = "Game",
        Column = 1,
        Icon = "joystick",
    })
    if not section then return false end

    ctx.Elements.AutoInteract = section:Dropdown({
        Name = "Auto Interact",
        Flag = "Hotel_AutoInteract",
        Options = {},
        MultiSelect = true,
        MaxSelect = 8,
        Default = {},
        Search = true,
        Callback = function() end,
    })

    ctx.Elements.AutoLoot = section:Dropdown({
        Name = "Auto Loot",
        Flag = "Hotel_AutoLoot",
        Options = {},
        MultiSelect = true,
        MaxSelect = 8,
        Default = {},
        Search = true,
        Callback = function() end,
    })

    return true
end

return GameUI
