local SettingsUI = {}

function SettingsUI:Create(ctx)
    local pages = ctx.VisualPages
    if not pages then return false end

    local page = pages:Page("Settings")
    if not page then return false end

    ctx.Elements.DisplayName = page:Toggle({
        Name = "Display Name",
        Flag = "Hotel_DisplayName",
        Default = true,
        Callback = function(value)
            ctx.Display.Name = value
            ctx.RefreshLabels()
        end,
    })

    ctx.Elements.DisplayDistance = page:Toggle({
        Name = "Display Distance",
        Flag = "Hotel_DisplayDistance",
        Default = false,
        Callback = function(value)
            ctx.Display.Distance = value
            ctx.RefreshLabels()
        end,
    })

    for _, kind in ipairs({
        "Doors","Drawers","Closets","Key","Gold","Chest","Bandage","Smoothie",
        "Flashlight","TipJar","Vitamins","Lighter","Candle","AlarmClock",
        "Lockpick","SkeletonKey","Shears","Battery","RiftCandle","RiftSmoothie",
        "RiftJar","Donut","Crucifix","SallyToy","ElectricalKey","BreakerPole",
        "VentGate","Lever","Rush","Ambush","Dupe","Eyes","SallyLingering",
        "SallyMoving","Seek","Figure","Snare","Screech","Toolshed"
    }) do
        ctx.Elements[kind .. "Color"] = page:ColorPicker({
            Name = kind .. " ESP Color",
            Flag = "Hotel_" .. kind .. "Color",
            Default = ctx.Colors[kind],
            Callback = function(value)
                ctx.Colors[kind] = value
                for _, entry in pairs(ctx.ESP[kind]) do
                    for _, highlight in ipairs(entry.Highlights) do
                        if highlight and highlight.Parent then
                            highlight.FillColor = value
                            highlight.OutlineColor = value
                        end
                    end
                    local label = entry.Label and entry.Label:FindFirstChild("Text")
                    if label then label.TextColor3 = value end
                end
            end,
        })
    end

    return true
end

return SettingsUI
