--[[
    Main tab module.
    Loaded after General so the Main tab appears directly beneath General in the sidebar.
    The ESP / Notifications / Settings multisection was moved here from Hotel's middle column.
]]

local Module = {}

function Module.Init(Shared)
    local Functions, Globals, Groupboxes, Options, Tabs, Toggles, Window
        = Shared.Functions, Shared.Globals, Shared.Groupboxes, Shared.Options, Shared.Tabs, Shared.Toggles, Shared.Window

    Tabs.Main = Window:AddTab("Main", "gamepad-2", { Columns = 3 })

    Groupboxes.Main_InfoTabbox = Tabs.Main:AddMiddleTabbox("Visual")
    Groupboxes.Main_ESP = Groupboxes.Main_InfoTabbox:AddTab("ESP")

    Groupboxes.Main_AutomationTabbox = Tabs.Main:AddLeftTabbox("Automation")
    Groupboxes.Self_Automation = Groupboxes.Main_AutomationTabbox:AddTab("Hotel")
    Groupboxes.Mines_Automation = Groupboxes.Main_AutomationTabbox:AddTab("Mines")
    -- Reserved floor pages in the 3x3 Automation multisection layout.
    Groupboxes.Backdoors_Automation = Groupboxes.Main_AutomationTabbox:AddTab("Backdoors")
    Groupboxes.Outdoors_Automation = Groupboxes.Main_AutomationTabbox:AddTab("Outdoors")
    Groupboxes.Archives_Automation = Groupboxes.Main_AutomationTabbox:AddTab("Archives")
    Groupboxes.Stairwell_Automation = Groupboxes.Main_AutomationTabbox:AddTab("Stairwell")

    -- Pinned controls are rendered in the shared area above the Hotel/Mines pages.
    Groupboxes.Self_Automation:AddToggle("AutoClosetToggle", {
        Text = "Auto Closet", Default = false, Pinned = true,
        Tooltip = "Automatically hides in a nearby closet when an entity is near."
    })
    Groupboxes.Self_Automation:AddDropdown("AutoClosetEntityList", {
        Text = "Ignore List", Pinned = true,
        Values = {"Rush", "Ambush", "Blitz", "DronesStampede", "Scribbles", "A-60", "A-120", "AR0xMBUSH", "RNIUSHCG=="},
        Multi = true, AllowNull = true
    })
    Groupboxes.Self_Automation:AddToggle("SpectateEntityToggle", {
        Text = "Spectate Entity", Default = false, Pinned = true,
        Tooltip = "Spectates the entity while auto hiding."
    })
    Groupboxes.Self_Automation:AddDropdown("SpecateEntityMode", {
        Text = "Spectate Entity Mode", Pinned = true,
        Values = {"Player to Entity", "Entity to Player"}, Default = 1, AllowNull = true
    })
    Groupboxes.Main_Notifications = Groupboxes.Main_InfoTabbox:AddTab("Notifications")
    Groupboxes.Main_Settings = Groupboxes.Main_InfoTabbox:AddTab("Settings")

    Groupboxes.Main_AntiTabbox = Tabs.Main:AddRightTabbox("Anti / No Damage")
    Groupboxes.Main_Anti = Groupboxes.Main_AntiTabbox:AddTab("Anti")
    Groupboxes.Main_NoDamage = Groupboxes.Main_AntiTabbox:AddTab("No Damage")

    Groupboxes.Main_Anti:AddToggle("BypassLookman", {
        Text = "Anti Lookman", Default = false,
        Tooltip = "Prevents 'Lookman' from hurting you."
    })
    Groupboxes.Main_Anti:AddToggle("BypassWater", { Text = "Anti Electrical Water", Default = false, Tooltip = "Prevents electric water from hurting you." })
    Groupboxes.Main_Anti:AddToggle("BypassAlma", { Text = "Anti Alma", Default = false, Tooltip = "Prevents Alma from spawning." })
    Groupboxes.Main_Anti:AddToggle("BypassDrones", { Text = "Anti Drones", Default = false, Tooltip = "Prevents Drones from attacking you." })
    Groupboxes.Main_Anti:AddToggle("AntiScribbles", { Text = "Anti Scribbles", Default = false, Tooltip = "Prevents Scribbles from attacking you." })
    Groupboxes.Main_Anti:AddToggle("BypassDronesStampede", { Text = "Anti Stampede", Default = false, Tooltip = "Prevents The Drones Stampede from attacking you." })
    Groupboxes.Main_Anti:AddToggle("AntiRansom", { Text = "Anti Ransom", Default = false, Tooltip = "Prevents Ransom from attacking you." })
    Groupboxes.Main_Anti:AddToggle("AntiClosetTrash", { Text = "Anti Closet Trash", Default = false, Tooltip = "Prevents Closet Trash from spawning." })
    Groupboxes.Main_Anti:AddToggle("DisableStairwellCrusherCollision", { Text = "Anti Crusher", Default = false, Tooltip = "Disables crusher collisions and removes their trigger parts." })
    Groupboxes.Main_Anti:AddToggle("MeldRemover", { Text = "Anti Meld", Default = false, Tooltip = "Removes Meld objects." })
    Groupboxes.Main_Anti:AddToggle("BypassVacuum", {
        Text = "Anti Vacuum", Default = false,
        Tooltip = "Prevents you from falling into 'Vacuum' fake doors."
    })
    Groupboxes.Main_Anti:AddToggle("BypassGiggle", {
        Text = "Anti Giggle", Default = false,
        Tooltip = "Prevents 'Giggle' from attacking you."
    })
    Groupboxes.Main_Anti:AddToggle("BypassGloombatEggs", {
        Text = "Anti Gloombat Eggs", Default = false,
        Tooltip = "Prevents taking damage from stepping on 'Gloombat' eggs."
    })
    Groupboxes.Main_Anti:AddToggle("RemoveFigureMines", {
        Text = "Anti Figure", Default = false,
        Tooltip = "Completely removes the entity 'Figure' (doesn't always work).",
        Risky = not (Shared.Floor == "Fools" or Shared.Floor == "OldHotel" or Shared.Floor == "Mines"),
        Disabled = not Functions.CheckCompatability({"isnetworkowner"}),
        DisabledTooltip = Globals.IncompatibleMessage
    })
    Groupboxes.Main_Anti:AddToggle("RemoveSurge", {
        Text = "Anti Surge", Default = false,
        Tooltip = "Prevents 'Surge' from spawning."
    })
    Groupboxes.Main_NoDamage:AddToggle("NoSurgeDamage", {
        Text = "No Surge Damage", Default = false,
        Tooltip = "Prevents 'Surge' from hurting you."
    })

    -- Shared entity options for Main ESP and Notifications. Vision entities live in Visions.
    local EntityOptions = {
        { Divider = "Hotel" },
        "Rush", "Ambush", "Eyes", "Halt", "Dupe", "Figure", "Snare", "Sally",

        { Divider = "Mines" },
        "Rush", "Ambush", "Eyes", "Halt", "Dupe", "Giggle", "Gloombat Eggs", "Grumble", "Figure", "Snare",

        { Divider = "Backdoors" },
        "Blitz", "Lookman",

        { Divider = "Outdoors" },
        "Groundskeeper", "Monument", "Bramble", "Mandrake Hole",

        { Divider = "Archives" },
        "Bash", "Scribbles", "Teller", "DronesStampede", "Portrait",

        { Divider = "Stairwell" },
        "Creak", "Noise", "Noise_TV", "Balls",

        { Divider = "Glitch" },
        "Glitch Ambush", "Glitch Rush",
    }

    Groupboxes.Main_ESP:AddToggle("HotelEntityESPToggle", {
        Text = "Entity ESP", Default = false, Tooltip = "Highlights the selected entities."
    })
    Groupboxes.Main_ESP:AddDropdown("HotelEntityESPList", {
        Text = "Entities", Values = EntityOptions, Multi = true, AllowNull = true
    })

    Groupboxes.Main_ESP:AddDivider()
    Groupboxes.Main_ESP:AddToggle("ShowSeekPathToggle", {
        Text = "Show Seek Path", Default = false, Tooltip = "Shows you the correct path in Seek chases.",
        Risky = Shared.Floor ~= "Mines"
    })
    Toggles.ShowSeekPathToggle:AddColorPicker("ShowSeekPathColor", { Text = "Seek Path", Default = Color3.fromRGB(0, 255, 0), Transparency = 0 })
    Groupboxes.Main_ESP:AddToggle("ShowEyestalkPathToggle", {
        Text = "Show Eyestalk Path", Default = false, Tooltip = "Shows you the correct path in the Eyestalk chase.",
        Risky = Shared.Floor ~= "Garden"
    })
    Toggles.ShowEyestalkPathToggle:AddColorPicker("ShowEyestalkPathColor", { Text = "Eyestalk Path", Default = Color3.fromRGB(0, 255, 0), Transparency = 0 })

    Groupboxes.Main_Notifications:AddToggle("NotifyLibraryCode", {
        Text = "Notify Library Code", Default = false,
        Tooltip = "Automatically solves the code for the library padlock."
    })
    Groupboxes.Main_Notifications:AddToggle("NotifyOxygen", {
        Text = "Notify Oxygen Level", Default = false,
        Tooltip = "Shows how much oxygen you have remaining."
    })
    Groupboxes.Main_Notifications:AddDivider()
    Groupboxes.Main_Notifications:AddToggle("HotelNotifyEntitiesToggle", {
        Text = "Notify Entities", Default = false, Tooltip = "Sends a notification when the selected entities spawn."
    })
    Groupboxes.Main_Notifications:AddDropdown("HotelNotifyEntitiesList", {
        Text = "Entities", Values = EntityOptions, Multi = true, AllowNull = true
    })

    Groupboxes.Main_Settings:AddToggle("EntityChatToggle", { Text = "Notify Chat", Default = false, Tooltip = "Sends a message in the chat when an entity spawns." })
    Groupboxes.Main_Settings:AddInput("EntityChatMessage", { Text = "Message", Default = "spawned!", Numeric = false, Placeholder = "Message" })
    Groupboxes.Main_Settings:AddDivider()
    Groupboxes.Main_Settings:AddDropdown("NotifyStyle", { Text = "Notify Style", Values = { "Abysall", "Doors", "STX", "Library" }, Default = 1 })
    Groupboxes.Main_Settings:AddSlider("NotifySoundVolume", { Text = "Sound Volume", Min = 0, Max = 10, Default = 3, Rounding = 1 })
    Groupboxes.Main_Settings:AddToggle("NotifyPlaySound", { Text = "Play Sound", Default = true, Tooltip = "Makes notifications play an alert sound." })
    Groupboxes.Main_Settings:AddToggle("NotifyKeepNotifications", { Text = "Keep Notifications", Default = false, Tooltip = "Certain notifications will stay on screen until they are no longer needed." })
    Groupboxes.Main_Settings:AddButton({ Text = "Test Notification", DoubleClick = false, Tooltip = "Sends a test notifcation, so you can see how your settings look.", Func = function()
        Functions.Notify({Title = "This is a test."})
    end})
    Groupboxes.Main_Settings:AddDivider()
    Groupboxes.Main_Settings:AddToggle("ShowEntityPath", {
        Text = "Show Entity Path",
        Default = false,
        Tooltip = "Shows the path of entitys."
    })
    Groupboxes.Main_Settings:AddSlider("ShowEntityPathNodeTransparency", {
        Text = "Node Transparency", Default = 0, Min = 0, Max = 1, Rounding = 2, Compact = false,
        Tooltip = "Transparency of the path nodes when shown"
    })
    Groupboxes.Main_Settings:AddSlider("ShowEntityPathLineTransparency", {
        Text = "Line Transparency", Default = 0.15, Min = 0, Max = 1, Rounding = 2, Compact = false,
        Tooltip = "Transparency of the path lines"
    })
    Groupboxes.Main_Settings:AddSlider("ShowEntityPathLineThickness", {
        Text = "Line Thickness", Default = 0.3, Min = 0.08, Max = 1.2, Rounding = 2
    })

    Groupboxes.Main_Settings:AddDivider()
    Groupboxes.Main_Settings:AddToggle("ESPRainbow",     { Text = "Rainbow Effect", Default = false, Tooltip = "Makes the esp objects change colour like a rainbow." })
    Groupboxes.Main_Settings:AddToggle("ESPShowDistance",{ Text = "Show Distance",  Default = true,  Tooltip = "Shows how far away your character is from the object." })
    Groupboxes.Main_Settings:AddDivider()
    Groupboxes.Main_Settings:AddSlider("ESPFillTransparency",        { Text = "Fill Transparency",         Min = 0, Max = 1, Default = 0.75, Rounding = 2, Compact = true })
    Groupboxes.Main_Settings:AddSlider("ESPOutlineTransparency",     { Text = "Outline Transparency",      Min = 0, Max = 1, Default = 0,    Rounding = 2, Compact = true })
    Groupboxes.Main_Settings:AddSlider("ESPTextTransparency",        { Text = "Text Transparency",         Min = 0, Max = 1, Default = 0,    Rounding = 2, Compact = true })
    Groupboxes.Main_Settings:AddSlider("ESPTextOutlineTransparency", { Text = "Text Outline Transparency", Min = 0, Max = 1, Default = 0,    Rounding = 2, Compact = true })
    Groupboxes.Main_Settings:AddSlider("ESPFadeTime",                { Text = "Fade Time",                 Min = 0, Max = 1, Default = 0.25, Rounding = 2, Compact = true })
    Groupboxes.Main_Settings:AddSlider("ESPRenderLimit",             { Text = "Render Limit",              Min = 30, Max = 240, Default = 240, Rounding = 0, Compact = true })
    Groupboxes.Main_Settings:AddSlider("ESPTextSize",                { Text = "Text Size",                 Min = 12, Max = 24, Default = 20, Rounding = 0, Compact = true })
    Groupboxes.Main_Settings:AddDropdown("ESPTextFont", {
        Text = "Text Font",
        Values = { "Legacy","Arial","ArialBold","SourceSans","SourceSansBold","SourceSansLight","SourceSansItalic","Bodoni","Garamond","Cartoon","Code","Highway","SciFi","Arcade","Fantasy","Antique","SourceSansSemibold","Gotham","GothamMedium","GothamBold","GothamBlack","AmaticSC","Bangers","Creepster","DenkOne","Fondamento","FredokaOne","GrenzeGotisch","IndieFlower","JosefinSans","Jura","Kalam","LuckiestGuy","Merriweather","Michroma","Nunito","Oswald","PatrickHand","PermanentMarker","Roboto","RobotoCondensed","RobotoMono","Sarpanch","SpecialElite","TitilliumWeb","Ubuntu","BuilderSans","BuilderSansMedium","BuilderSansBold","BuilderSansExtraBold","Arimo","ArimoBold" },
        Default = 12
    })
    Groupboxes.Main_Settings:AddDivider()
    Groupboxes.Main_Settings:AddDropdown("ESPTracersOrigin",  { Text = "Tracer Origin", Values = { "Bottom","Center","Top","Mouse" }, Default = 1 })
    Groupboxes.Main_Settings:AddSlider("ESPTracerThickness",  { Text = "Tracer Thickness", Min = 0.5, Max = 2, Default = 0.75, Rounding = 2, Compact = true })
    Groupboxes.Main_Settings:AddToggle("ESPTracersToggle",    { Text = "Enable Tracers", Default = false, Tooltip = "Draws a line to highlighted objects." })
    Groupboxes.Main_Settings:AddDivider()
    Groupboxes.Main_Settings:AddSlider("ESPArrowsRadius",     { Text = "Arrow Radius", Min = 100, Max = 500, Default = 250, Rounding = 0, Compact = true })
    Groupboxes.Main_Settings:AddToggle("ESPArrowsToggle",     { Text = "Enable Arrows", Default = false, Tooltip = "Shows arrow that point to off-screen objects." })


    -- Entity ESP uses the global ESP color; no per-entity color pickers here.

    table.insert(Globals.FloorEntityLists, {
        ESPToggle = "HotelEntityESPToggle", ESPList = "HotelEntityESPList",
        NotifyToggle = "HotelNotifyEntitiesToggle", NotifyList = "HotelNotifyEntitiesList"
    })

    local function RefreshHotelEntities()
        if Functions.RefreshEntityESP then Functions.RefreshEntityESP() end
    end
    Toggles.HotelEntityESPToggle:OnChanged(RefreshHotelEntities)
    Options.HotelEntityESPList:OnChanged(RefreshHotelEntities)


end

return Module
