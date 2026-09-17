local Main = {}

local Core
local UI
local Notifications
local Connections

Main.Initialized = false
Main.Unloaded = false

Main.Tabs = {}
Main.Groups = {}
Main.Elements = {}

------------------------------------------------------
-- CREATE WINDOW
------------------------------------------------------

function Main:CreateWindow()
    if not UI then
        return nil
    end

    local window = UI:Create()

    if not window then
        return nil
    end

    return window
end

------------------------------------------------------
-- CREATE TABS
------------------------------------------------------

function Main:CreateTabs()
    if not UI or not UI.Window then
        return false
    end

    --------------------------------------------------
    -- IMPORTANT:
    -- This is the ONLY place where tabs are created.
    -- Keep this order.
    --------------------------------------------------

    self.Tabs.Lobby =
        UI:AddTab(
            "Lobby",
            "home",
            "Lobby features"
        )

    self.Tabs.Main =
        UI:AddTab(
            "Main",
            "user",
            "Main character features"
        )

    self.Tabs.Hotel =
        UI:AddTab(
            "Hotel",
            "door-open",
            "Hotel features"
        )

    self.Tabs.Mines =
        UI:AddTab(
            "Mines",
            "pickaxe",
            "Mines features"
        )

    self.Tabs.Backdoors =
        UI:AddTab(
            "Backdoors",
            "door-closed",
            "Backdoor features"
        )

    self.Tabs.Outdoors =
        UI:AddTab(
            "Outdoors",
            "trees",
            "Outdoors features"
        )

    self.Tabs.Archives =
        UI:AddTab(
            "Archives",
            "archive",
            "Archives features"
        )

    self.Tabs.Stairwell =
        UI:AddTab(
            "Stairwell",
            "stairs",
            "Stairwell features"
        )

    --------------------------------------------------
    -- VALIDATE
    --------------------------------------------------

    local required = {
        "Lobby",
        "Main",
        "Hotel",
        "Mines",
        "Backdoors",
        "Outdoors",
        "Archives",
        "Stairwell"
    }

    for _, name in ipairs(required) do
        if not self.Tabs[name] then
            warn(
                "[JustXDoors Main] Failed to create tab: "
                    .. name
            )

            return false
        end
    end

    return true
end

------------------------------------------------------
-- MAIN TAB
------------------------------------------------------

function Main:CreateMainTab()
    local tab = self.Tabs.Main

    if not tab then
        return false
    end

    --------------------------------------------------
    -- INFORMATION
    --------------------------------------------------

    local information =
        UI:AddLeftGroupbox(
            tab,
            "JustXDoors",
            "sparkles"
        )

    if information then
        UI:AddLabel(
            information,
            "JustXDoors"
        )

        UI:AddLabel(
            information,
            "Modular DOORS hub"
        )

        UI:AddDivider(
            information
        )

        UI:AddLabel(
            information,
            "Core systems loaded"
        )

        self.Groups.MainInformation =
            information
    end

    --------------------------------------------------
    -- STATUS
    --------------------------------------------------

    local status =
        UI:AddRightGroupbox(
            tab,
            "Status",
            "activity"
        )

    if status then
        UI:AddLabel(
            status,
            "Ready"
        )

        UI:AddLabel(
            status,
            "JustXDoors is initialized."
        )

        self.Groups.MainStatus =
            status
    end

    return true
end

------------------------------------------------------
-- FLOOR TAB PLACEHOLDERS
------------------------------------------------------

function Main:CreateFloorTabs()
    -- Tabs are already created by CreateTabs().
    -- Individual Game modules add their features
    -- into these existing tabs.

    return true
end

------------------------------------------------------
-- UNLOAD HANDLER
------------------------------------------------------

function Main:SetupUnload()
    if not UI then
        return
    end

    if type(UI.OnUnload) ~= "function" then
        return
    end

    UI:OnUnload(function()
        self:Unload(true)
    end)
end

------------------------------------------------------
-- UNLOAD
------------------------------------------------------

function Main:Unload(fromLibrary)
    if self.Unloaded then
        return
    end

    self.Unloaded = true

    --------------------------------------------------
    -- DISCONNECT CONNECTIONS
    --------------------------------------------------

    if Connections then
        pcall(function()
            Connections:DisconnectAll()
        end)
    end

    --------------------------------------------------
    -- DESTROY UI
    --------------------------------------------------

    if not fromLibrary and UI then
        pcall(function()
            UI:Unload()
        end)
    end

    --------------------------------------------------
    -- CLEAR STATE
    --------------------------------------------------

    self.Tabs = {}
    self.Groups = {}
    self.Elements = {}

    self.Initialized = false
end

------------------------------------------------------
-- INIT
------------------------------------------------------

function Main:Init(core)
    if self.Initialized then
        return self
    end

    if type(core) ~= "table" then
        return self
    end

    Core = core

    UI =
        Core.UI

    Notifications =
        Core.Notifications

    Connections =
        Core.Connections

    --------------------------------------------------
    -- WINDOW
    --------------------------------------------------

    local window =
        self:CreateWindow()

    if not window then
        warn(
            "[JustXDoors Main] Failed to create UI."
        )

        return self
    end

    --------------------------------------------------
    -- TABS
    --------------------------------------------------

    if not self:CreateTabs() then
        warn(
            "[JustXDoors Main] Failed to create tabs."
        )

        return self
    end

    --------------------------------------------------
    -- MAKE MAIN CONTENT
    --------------------------------------------------

    self:CreateMainTab()

    --------------------------------------------------
    -- FLOOR PLACEHOLDERS
    --------------------------------------------------

    self:CreateFloorTabs()

    --------------------------------------------------
    -- UNLOAD
    --------------------------------------------------

    self:SetupUnload()

    --------------------------------------------------
    -- STATE
    --------------------------------------------------

    self.Unloaded = false
    self.Initialized = true

    --------------------------------------------------
    -- NOTIFICATION
    --------------------------------------------------

    if Notifications then
        pcall(function()
            Notifications:Success(
                "JustXDoors",
                "Interface initialized."
            )
        end)
    end

    return self
end

return Main
