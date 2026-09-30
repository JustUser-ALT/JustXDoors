-- Hotel notification module.
-- Entity and item notifications are kept together so the Notifications
-- MultiSection can be extended without touching ESP internals.
local Notifications = {}

function Notifications:Init(context)
    self.Context = context
end

return Notifications
