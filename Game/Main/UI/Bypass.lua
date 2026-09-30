local BypassUI = {}

function BypassUI:Create(ctx)
    local pages = ctx.CharacterPages
    if not pages then return false end

    local page = pages:Page("Bypass")
    if not page then return false end

    local a = ctx.Actions
    local E = ctx.Elements

    E.AnticheatBypass = page:Toggle({
        Name = "Anticheat Bypass",
        Flag = "Main_AnticheatBypass",
        Default = false,
        Callback = function(v) a.SetAnticheatBypass(v) end,
    })

    E.VelocityManipulation = page:Toggle({
        Name = "Velocity Manipulation",
        Flag = "Main_VelocityManipulation",
        Default = false,
        Callback = function(v) a.SetVelocityManipulation(v) end,
    })

    E.VelocityManipulationMode = page:Dropdown({
        Name = "Manipulation Method",
        Flag = "Main_VelocityManipulationMode",
        Options = {"Velocity", "Pivot"},
        Default = "Velocity",
        Search = true,
        Callback = function(v) a.SetVelocityMode(v) end,
    })

    page:Divider()

    E.InfiniteItems = page:Toggle({
        Name = "Infinite Items",
        Flag = "Main_InfiniteItems",
        Default = false,
        Callback = function(v) a.SetInfiniteItems(v) end,
    })

    E.InfiniteItemsList = page:ValueDropdown({
        Name = "Item List",
        Flag = "Main_InfiniteItemsList",
        Options = {"Lockpicks", "Skeleton Key", "Shears", "Multitool"},
        MultiSelect = true,
        MaxSelect = 4,
        Default = {},
        Search = true,
        Callback = function(v) a.SetInfiniteItemsSelection(v) end,
    })

    page:Divider()

    E.InfiniteCrucifix = page:Toggle({
        Name = "Infinite Crucifix",
        Flag = "Main_InfiniteCrucifix",
        Default = false,
        Callback = function(v) a.SetInfiniteCrucifix(v) end,
    })

    page:Divider()

    E.CrouchSpoof = page:Toggle({
        Name = "Crouch Spoof",
        Flag = "Main_CrouchSpoof",
        Default = false,
        Callback = function(v) a.SetCrouchSpoof(v) end,
    })

    return true
end

return BypassUI
