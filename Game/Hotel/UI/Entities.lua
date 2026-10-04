local EntitiesUI = {}

function EntitiesUI:Create(ctx)
    if not ctx.Tab then return false end

    local pages = ctx.EntityPages
    if not pages then
        pages = ctx.Tab:MultiSection({
            Pages = {"Entity", "Anti"},
            Column = 3,
            Icon = "shield",
        })
        ctx.EntityPages = pages
    end
    if not pages then return false end

    local page = pages:Page("Entity")
    if not page then return false end

    ctx.Elements.Entities = page:Dropdown({
        Name = "Entities",
        Flag = "Hotel_Entities",
        Options = {"Rush","Ambush","Glitch Rush","Glitch Ambush","Dupe","Eyes","Dread","Sally","Seek","Figure","Snare","Screech"},
        MultiSelect = true,
        MaxSelect = 12,
        Default = {},
        Search = true,
        Callback = function(selected)
            ctx.SetEntities(selected)
        end,
    })

    page:Label({Text = "Entity ESP"})
    return true
end

return EntitiesUI
