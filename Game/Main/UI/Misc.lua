local MiscUI = {}

function MiscUI:Create(ctx)
    local Tab = ctx.Tab
    if not Tab then return false end

    local section = Tab:Section({
        Title = "Misc",
        Column = 3,
        Icon = "settings-2",
    })
    if not section then return false end

    local a = ctx.Actions
    local E = ctx.Elements

    E.InstantInteract = section:Toggle({
        Name = "Instant Interact",
        Flag = "Main_InstantInteract",
        Default = false,
        Callback = function(v) a.SetInstantInteract(v) end,
    })

    E.InteractNoclip = section:Toggle({
        Name = "Interact Noclip",
        Flag = "Main_InteractNoclip",
        Default = false,
        Callback = function(v) a.SetInteractNoclip(v) end,
    })

    E.InteractReach = section:Slider({
        Name = "Interact Reach",
        Flag = "Main_InteractReach",
        Min = 1, Max = 2, Step = 0.1, Default = 1,
        Callback = function(v) a.SetInteractReach(v) end,
    })

    section:Divider()

    E.DoorReach = section:Toggle({
        Name = "Door Reach",
        Flag = "Main_DoorReach",
        Default = false,
        Callback = function(v) a.SetDoorReach(v) end,
    })

    section:Divider()

    section:Button({
        Name = "Play Again",
        Callback = a.PlayAgain,
    })

    section:Button({
        Name = "Return to Lobby",
        Callback = a.ReturnToLobby,
    })

    section:Button({
        Name = "Revive",
        Callback = a.Revive,
    })

    section:Button({
        Name = "Reset Character",
        Callback = a.ResetCharacter,
    })

    local debug = Tab:Section({
        Title = "Debug",
        Column = 3,
        Icon = "bug",
    })
    if not debug then return false end

    debug:Button({
        Name = "Void",
        Callback = a.Void,
    })

    debug:Button({
        Name = "Exit Closet",
        Callback = a.ExitCloset,
    })

    debug:Button({
        Name = "Tp Next Door",
        Callback = a.TeleportNextDoor,
    })

    E.AutoTpNextDoor = debug:Toggle({
        Name = "Auto Tp Next Door",
        Flag = "Main_AutoTpNextDoor",
        Default = false,
        Callback = function(v) a.SetAutoTpNextDoor(v) end,
    })

    return true
end

return MiscUI
