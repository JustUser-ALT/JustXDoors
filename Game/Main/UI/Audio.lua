local AudioUI = {}

function AudioUI:Create(ctx)
    local pages = ctx.VisualPages
    if not pages then return false end

    local page = pages:Page("Audio")
    if not page then return false end

    local a = ctx.Actions
    local E = ctx.Elements

    E.RemoveFootstepSounds = page:Toggle({
        Name = "Remove Footstep Sounds",
        Flag = "Main_RemoveFootstepSounds",
        Default = false,
        Callback = function(v) a.SetRemoveFootstepSounds(v) end,
    })

    E.RemoveInteractingSounds = page:Toggle({
        Name = "Remove Interacting Sounds",
        Flag = "Main_RemoveInteractingSounds",
        Default = false,
        Callback = function(v) a.SetRemoveInteractingSounds(v) end,
    })

    page:Divider()

    E.RemoveJamminMusic = page:Toggle({
        Name = "Remove Jammin Music",
        Flag = "Main_RemoveJamminMusic",
        Default = false,
        Callback = function(v) a.SetRemoveJamminMusic(v) end,
    })

    return true
end

return AudioUI
