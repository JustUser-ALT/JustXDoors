-- Visual feature module.
-- Kept independent so Visual features can be moved out of Main.lua without
-- changing unrelated Character/Misc behaviour.
local Visual = {}

function Visual:Init(context)
    self.Context = context
end

return Visual
