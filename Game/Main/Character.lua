-- Character feature module.
-- The current Main implementation is intentionally kept intact while the hub
-- is migrated feature-by-feature. New Character features belong here.
local Character = {}

function Character:Init(context)
    self.Context = context
end

return Character
