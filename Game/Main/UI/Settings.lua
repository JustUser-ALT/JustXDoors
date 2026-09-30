local SettingsUI = {}

function SettingsUI:Create(ctx)
    -- Main settings are provided by Core:CreateSettings().
    -- This module intentionally remains the Main tab extension point for
    -- future Main-specific settings without mixing them into other sections.
    return true
end

return SettingsUI
