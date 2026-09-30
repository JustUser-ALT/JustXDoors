local AudioUI = {}

function AudioUI:Create(ctx)
    local Tab = ctx.Tab
    if not Tab then return false end

    local section = Tab:Section({
        Title = "Audio",
        Column = 2,
        Icon = "volume-2",
    })
    if not section then return false end

    local a = ctx.Actions
    local E = ctx.Elements

    E.RemoveFootstepSounds = section:Toggle({
        Name = "Remove Footstep Sounds",
        Flag = "Main_RemoveFootstepSounds",
        Default = false,
        Callback = function(v) a.SetRemoveFootstepSounds(v) end,
    })

    E.RemoveInteractingSounds = section:Toggle({
        Name = "Remove Interacting Sounds",
        Flag = "Main_RemoveInteractingSounds",
        Default = false,
        Callback = function(v) a.SetRemoveInteractingSounds(v) end,
    })

    section:Divider()

    E.RemoveJamminMusic = section:Toggle({
        Name = "Remove Jammin Music",
        Flag = "Main_RemoveJamminMusic",
        Default = false,
        Callback = function(v) a.SetRemoveJamminMusic(v) end,
    })

    return true
end

return AudioUI
