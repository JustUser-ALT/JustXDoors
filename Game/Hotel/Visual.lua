-- Hotel visual/UI module.
-- ESP rendering lives in ESP.lua; this module owns non-ESP visual UI.
local Visual = {}

function Visual:Init(context)
    self.Context = context
end

return Visual
