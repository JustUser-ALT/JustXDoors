--[[
	Hotel tab  (Abysall Hub, JustLib build)

	Loaded by Main.luau:   local Hotel = Abysall.LoadModule("Hotel");  Hotel.Init(Shared) ... Hotel.Late(...)
	Columns: Automation | ESP / Notifications / Settings | Anti / No Damage.
	Automation = the groupbox that used to be on the General tab, together with all of its
	logic (Auto Breaker Box, Auto Library, Skip Seek, Auto Breaker Room, Auto Hotel, Auto Interact, Auto Closet ...).
	The code is moved 1:1 out of Main.luau.

-- Mutable Main state (Character, Humanoid, RemotesFolder, Floor, CustomPhysics, OldJump, OldSlide) is
-- read/written through Shared.<Name> so it always reflects Main's live value.
]]

local Module = {}

function Module.Init(Shared)
	local Connections, CurrentRooms, Functions, Globals, Groupboxes, LocalPlayer, Options, Services, Tabs, Toggles, Window
	   = Shared.Connections, Shared.CurrentRooms, Shared.Functions, Shared.Globals, Shared.Groupboxes, Shared.LocalPlayer, Shared.Options, Shared.Services, Shared.Tabs, Shared.Toggles, Shared.Window

	Tabs.Game = Window:AddTab("Game", "gamepad-2", { Columns = 3 })
	Tabs.Hotel = Window:AddTab("Hotel", "hotel", { Columns = 3 })

	-- right column: Anti / No Damage multisection (toggles moved from the Exploits tab and renamed "Anti ...")
	Groupboxes.Hotel_AntiTabbox = Tabs.Game:AddRightTabbox("Hotel")
	Groupboxes.Hotel_Anti = Groupboxes.Hotel_AntiTabbox:AddTab("Anti")
	Groupboxes.Hotel_NoDamage = Groupboxes.Hotel_AntiTabbox:AddTab("No Damage")

	Groupboxes.Game_MinesAnti = Tabs.Game:AddRightGroupbox("Mines")
	Groupboxes.Game_MinesAnti:AddToggle("BypassGiggle", { Text = "Anti Giggle", Default = false, Tooltip = "Prevents 'Giggle' from attacking you." })
	Groupboxes.Game_MinesAnti:AddToggle("BypassGloombatEggs", { Text = "Anti Gloombat Eggs", Default = false, Tooltip = "Prevents taking damage from stepping on 'Gloombat' eggs." })
	Groupboxes.Game_MinesAnti:AddToggle("RemoveFigureMines", {
		Text = "Anti Figure", Default = false, Tooltip = "Completely removes the entity 'Figure' (doesn't always work).",
		Risky = not (Shared.Floor == "Fools" or Shared.Floor == "OldHotel" or Shared.Floor == "Mines"),
		Disabled = not Functions.CheckCompatability({"isnetworkowner"}), DisabledTooltip = Globals.IncompatibleMessage
	})
	Groupboxes.Hotel_Anti:AddToggle("BypassDupe",           { Text = "Anti Dupe",             Default = false, Tooltip = "Prevents you from open 'Dupe' fake doors." })
	Groupboxes.Hotel_Anti:AddToggle("BypassEyes",           { Text = "Anti Eyes",             Default = false, Tooltip = "Prevents 'Eyes' from hurting you." })
	Groupboxes.Hotel_Anti:AddToggle("BypassSnare",          { Text = "Anti Snare",            Default = false, Tooltip = "Prevents 'Snare' from trapping you." })
	Groupboxes.Hotel_Anti:AddToggle("BypassSeekObstructions", { Text = "Anti Seek Obstructions", Default = false, Tooltip = "Prevents obstacles in the 'Seek' chase from harming you." })
	Groupboxes.Hotel_Anti:AddDivider()
	Groupboxes.Hotel_Anti:AddToggle("HotelAntiRush", {
		Text = "Anti Rush", Default = false,
		Tooltip = "Automatically enables Position Spoof when Rush is nearby."
	})
	Groupboxes.Hotel_Anti:AddToggle("HotelAntiAmbush", {
		Text = "Anti Ambush", Default = false,
		Tooltip = "Automatically enables Position Spoof when Ambush is nearby."
	})
	Groupboxes.Hotel_Anti:AddToggle("HotelAntiGlitchRush", {
		Text = "Anti RNIUSHCG==", Default = false,
		Tooltip = "Automatically enables Position Spoof when the glitch Rush variant is nearby."
	})
	Groupboxes.Hotel_Anti:AddToggle("HotelAntiGlitchAmbush", {
		Text = "Anti AR0xMBUSH", Default = false,
		Tooltip = "Automatically enables Position Spoof when the glitch Ambush variant is nearby."
	})

	-- All four protections share the existing Position Spoof toggle. Cache nested entity models
	-- because these entities may be inserted below folders instead of directly under Workspace.
	local HotelAntiModels = {}
	local HotelAntiRunning = true
	local HotelAntiElapsed = 0
	local HotelAutoEnabledPositionSpoof = false
	local HotelUserWantsPositionSpoof = Toggles.PositionSpoof and Toggles.PositionSpoof.Value == true or false
	local HotelChangingPositionSpoof = false
	local HotelEntityAntiConfig = {
		RushMoving = { Toggle = "HotelAntiRush", Distance = 85 },
		AmbushMoving = { Toggle = "HotelAntiAmbush", Distance = 150 },
		GlitchRush = { Toggle = "HotelAntiGlitchRush", Distance = 90 },
		GlitchAmbush = { Toggle = "HotelAntiGlitchAmbush", Distance = 175 },
	}
	local function RegisterHotelAntiModel(Object)
		if Object:IsA("Model") and HotelEntityAntiConfig[Object.Name] then
			HotelAntiModels[Object] = true
		end
	end
	for _, Object in Services.Workspace:GetDescendants() do RegisterHotelAntiModel(Object) end
	Connections.HotelAntiModelsAdded = Services.Workspace.DescendantAdded:Connect(RegisterHotelAntiModel)
	Connections.HotelAntiModelsRemoving = Services.Workspace.DescendantRemoving:Connect(function(Object)
		HotelAntiModels[Object] = nil
	end)

	local function HotelHasThreat()
		if Shared.Floor ~= "Hotel" then return false end
		local Character = LocalPlayer.Character
		local Root = Character and (Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart)
		if not Root then return false end
		for Model in HotelAntiModels do
			local Config = HotelEntityAntiConfig[Model.Name]
			local Toggle = Config and Toggles[Config.Toggle]
			if Config and Toggle and Toggle.Value and Model.Parent and Model:IsDescendantOf(Services.Workspace) then
				local EntityRoot = Model.PrimaryPart or Model:FindFirstChild("HumanoidRootPart", true) or Model:FindFirstChildWhichIsA("BasePart", true)
				if EntityRoot and (EntityRoot.Position - Root.Position).Magnitude <= Config.Distance then return true end
			end
		end
		return false
	end
	local function BlitzHasThreat()
		if not Toggles.BackdoorsAntiBlitz or not Toggles.BackdoorsAntiBlitz.Value then return false end
		local Character = LocalPlayer.Character
		local Root = Character and (Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart)
		if not Root then return false end
		for _, Model in Services.Workspace:GetDescendants() do
			if Model:IsA("Model") and Model.Name == "BackdoorRush" then
				local EntityRoot = Model.PrimaryPart or Model:FindFirstChild("HumanoidRootPart", true) or Model:FindFirstChildWhichIsA("BasePart", true)
				if EntityRoot and (EntityRoot.Position - Root.Position).Magnitude <= 150 then return true end
			end
		end
		return false
	end
	local function HotelSetPositionSpoof(Value)
		local Toggle = Toggles.PositionSpoof
		if not Toggle or Toggle.Value == Value then return Toggle ~= nil end
		HotelChangingPositionSpoof = true
		local Ok = pcall(function() Toggle:SetValue(Value) end)
		HotelChangingPositionSpoof = false
		return Ok and Toggle.Value == Value
	end
	if Toggles.PositionSpoof then
		Connections.HotelPositionSpoofChanged = Toggles.PositionSpoof:OnChanged(function(Value)
			if not HotelChangingPositionSpoof then HotelUserWantsPositionSpoof = Value == true end
		end)
	end
	Connections.HotelAntiSpoof = Services.RunService.Heartbeat:Connect(function(DeltaTime)
		if not HotelAntiRunning then return end
		HotelAntiElapsed += DeltaTime
		if HotelAntiElapsed < 0.1 then return end
		HotelAntiElapsed = 0
		local ThreatNearby = HotelHasThreat()
		local SpoofToggle = Toggles.PositionSpoof
		if ThreatNearby then
			if SpoofToggle and not SpoofToggle.Value then
				HotelAutoEnabledPositionSpoof = not HotelUserWantsPositionSpoof
				HotelSetPositionSpoof(true)
			end
		elseif HotelAutoEnabledPositionSpoof and not BlitzHasThreat() then
			if not HotelUserWantsPositionSpoof then HotelSetPositionSpoof(false) end
			HotelAutoEnabledPositionSpoof = false
		end
	end)
	Connections.HotelAntiCleanup = {
		Disconnect = function()
			HotelAntiRunning = false
			if HotelAutoEnabledPositionSpoof and not HotelUserWantsPositionSpoof and not BlitzHasThreat() then
				HotelSetPositionSpoof(false)
			end
			HotelAutoEnabledPositionSpoof = false
			table.clear(HotelAntiModels)
		end
	}

	-- middle column: ESP | Notifications | Settings. The entity lists below belong to this floor only; the global lists in
	-- the Visuals tab keep working, an entity is shown / announced when EITHER asks for it (see Functions.EntityESPWanted).
	Groupboxes.Hotel_InfoTabbox = Tabs.Hotel:AddMiddleTabbox("ESP / Notifications / Settings")
	Groupboxes.Hotel_ESP = Groupboxes.Hotel_InfoTabbox:AddTab("ESP")
	Groupboxes.Hotel_Notifications = Groupboxes.Hotel_InfoTabbox:AddTab("Notifications")
	Groupboxes.Hotel_Settings = Groupboxes.Hotel_InfoTabbox:AddTab("Settings")

	local HotelEntities = { "Rush", "Ambush", "Eyes", "Halt", "Sally", "Dupe", "Figure", "Snare", "AR0xMBUSH", "RNIUSHCG==" }

	Groupboxes.Hotel_ESP:AddToggle("HotelEntityESPToggle", {
		Text = "Entity ESP", Default = false, Tooltip = "Highlights the selected entities."
	})
	Groupboxes.Hotel_ESP:AddDropdown("HotelEntityESPList", {
		Text = "Entities", Values = HotelEntities, Multi = true, AllowNull = true
	})
	
	-- Hotel item / objective ESP. Keep only real lootable objects; decorative models without their pickup prompt are ignored.
	local HotelLootItems = { "Gold", "Glitch Fragment" }
	local HotelObjectiveItems = { "Key", "Electrical Key", "Book", "Hint Paper", "Breaker Pole" }
	local HotelRegularItems = {
		"Flashlight", "Candle", "Lighter", "Lockpick", "Vitamins", "Smoothie", "Bandage",
		"Battery", "Skeleton Key", "Shears", "Crucifix", "Alarm Clock", "Tip Jar", "Donut", "Sally Toy"
	}
	local HotelRiftItems = { "Rift Jar", "Rift Candle", "Rift Smoothie" }
	local HotelAllItems = { "--Loot--", "Gold", "Glitch Fragment", "--Objectives--", "Key", "Electrical Key", "Book", "Hint Paper", "Breaker Pole", "--Items--",
		"Flashlight", "Candle", "Lighter", "Lockpick", "Vitamins", "Smoothie", "Bandage", "Battery", "Skeleton Key", "Shears",
		"Crucifix", "Alarm Clock", "Tip Jar", "Donut", "Sally Toy", "--Rift--", "Rift Jar", "Rift Candle", "Rift Smoothie" }
	local HotelRealItems = {}
	for _, Name in HotelAllItems do
		if not Name:match("^%-%-.*%-%-$") then table.insert(HotelRealItems, Name) end
	end
	local HotelESPColorDefaults = {
		Loot = Color3.fromRGB(255, 210, 60),
		Objectives = Color3.fromRGB(80, 220, 120),
		Items = Color3.fromRGB(170, 100, 255),
		Rift = Color3.fromRGB(80, 190, 255),
	}
	local function HotelItemGroup(Name)
		if table.find(HotelLootItems, Name) then return "Loot" end
		if table.find(HotelObjectiveItems, Name) then return "Objectives" end
		if table.find(HotelRegularItems, Name) then return "Items" end
		return "Rift"
	end
	local function BuildHotelESPValues(Names)
		local Values = {}
		for _, Name in Names do
			if not Name:match("^%-%-.*%-%-$") then
				local Group = HotelItemGroup(Name)
				local Controls = { Mode = "Move" }
				table.insert(Controls, { Type = "Toggle", Name = "Always", Master = true, Default = false })
				table.insert(Controls, { Type = "Toggle", Name = "Previous", Default = false })
				table.insert(Controls, { Type = "Toggle", Name = "Current", Default = true })
				table.insert(Controls, { Type = "Toggle", Name = "Next", Default = false })
				table.insert(Controls, { Type = "ColorPicker", Name = "Color", Default = HotelESPColorDefaults[Group] })
				if Name == "Gold" then
					table.insert(Controls, { Type = "Divider", Name = "--Gold Level--" })
					table.insert(Controls, { Type = "Slider", Name = "Minimum Level", Min = 1, Max = 6, Step = 1, Default = 1 })
					table.insert(Controls, { Type = "Slider", Name = "Maximum Level", Min = 1, Max = 6, Step = 1, Default = 6 })
				end
				Values[Name] = Controls
			end
		end
		return Values
	end

	Groupboxes.Hotel_ESP:AddDivider()
	Groupboxes.Hotel_ESP:AddToggle("HotelItemESPToggle", {
		Text = "Items / Objectives ESP", Default = false,
		Tooltip = "Highlights loot and objectives without highlighting decorative props."
	})
	Groupboxes.Hotel_ESP:AddValueDropdown("HotelAllItemsESPList", {
		Text = "Items", Options = HotelAllItems, Multi = true, Values = BuildHotelESPValues(HotelAllItems)
	})
	Groupboxes.Hotel_ESP:AddToggle("HotelESPJeffItems", { Text = "ESP Jeff Items", Default = true })
	Groupboxes.Hotel_ESP:AddToggle("HotelESPDrops", { Text = "ESP Drops", Default = true })
	Groupboxes.Hotel_ESP:AddToggle("HotelESPRiftRooms", { Text = "ESP in Rift Rooms", Default = true })

	Groupboxes.Hotel_Notifications:AddToggle("HotelNotifyEntitiesToggle", {
		Text = "Notify Entities", Default = false, Tooltip = "Sends a notification when the selected entities spawn."
	})
	Groupboxes.Hotel_Notifications:AddDropdown("HotelNotifyEntitiesList", {
		Text = "Entities", Values = HotelEntities, Multi = true, AllowNull = true
	})

	-- Settings: notification settings + Show Entity Path (moved from the Visuals tab, the controls themselves are unchanged)
	Groupboxes.Hotel_Settings:AddToggle("EntityChatToggle", { Text = "Notify Chat", Default = false, Tooltip = "Sends a message in the chat when an entity spawns." })
	Groupboxes.Hotel_Settings:AddInput("EntityChatMessage", { Text = "Message", Default = "spawned!", Numeric = false, Placeholder = "Message" })
	Groupboxes.Hotel_Settings:AddDivider()
	Groupboxes.Hotel_Settings:AddDropdown("NotifyStyle", { Text = "Notify Style", Values = { "Abysall", "Doors", "STX", "Library" }, Default = 1 })
	Groupboxes.Hotel_Settings:AddSlider("NotifySoundVolume", { Text = "Sound Volume", Min = 0, Max = 10, Default = 3, Rounding = 1 })
	Groupboxes.Hotel_Settings:AddToggle("NotifyPlaySound", { Text = "Play Sound", Default = true, Tooltip = "Makes notifications play an alert sound." })
	Groupboxes.Hotel_Settings:AddToggle("NotifyKeepNotifications", { Text = "Keep Notifications", Default = false, Tooltip = "Certain notifications will stay on screen until they are no longer needed." })
	Groupboxes.Hotel_Settings:AddButton({ Text = "Test Notification", DoubleClick = false, Tooltip = "Sends a test notifcation, so you can see how your settings look.", Func = function()
		Functions.Notify({Title = "This is a test."})
	end})
	Groupboxes.Hotel_Settings:AddDivider()
	Groupboxes.Hotel_Settings:AddToggle("ShowEntityPath", {
	    Text = "Show Entity Path",
	    Default = false,
	    Tooltip = "Shows the path of entitys."
	})

	Groupboxes.Hotel_Settings:AddSlider("ShowEntityPathNodeTransparency", {
	    Text = "Node Transparency",
	    Default = 0,
	    Min = 0,
	    Max = 1,
	    Rounding = 2,
	    Compact = false,
	    Tooltip = "Transparency of the path nodes when shown"
	})

	Groupboxes.Hotel_Settings:AddSlider("ShowEntityPathLineTransparency", {
	    Text = "Line Transparency",
	    Default = 0.15,
	    Min = 0,
	    Max = 1,
	    Rounding = 2,
	    Compact = false,
	    Tooltip = "Transparency of the path lines"
	})

	Groupboxes.Hotel_Settings:AddSlider("ShowEntityPathLineThickness", {
	    Text = "Line Thickness",
	    Default = 0.3,
	    Min = 0.08,
	    Max = 1.2,
	    Rounding = 2
	})

	-- ESP colours: one for the whole list and one per entity (an entity follows the list colour until you change its own)
	Groupboxes.Hotel_Settings:AddDivider()
	Groupboxes.Hotel_Settings:AddLabel("Entity ESP Color"):AddColorPicker("HotelEntityESPColor", { Default = Color3.fromRGB(255, 0, 0) })
	local HotelColorNames = {}
	for _, Entity in HotelEntities do
		local Idx = "HotelEntityColor_" .. (Entity:gsub("[^%w]", ""))
		table.insert(HotelColorNames, Idx)
		Groupboxes.Hotel_Settings:AddLabel(Entity .. " Color"):AddColorPicker(Idx, { Default = Color3.fromRGB(255, 0, 0) })
	end

	table.insert(Globals.FloorEntityLists, {
		ESPToggle = "HotelEntityESPToggle", ESPList = "HotelEntityESPList", ColorPrefix = "HotelEntityColor_",
		NotifyToggle = "HotelNotifyEntitiesToggle", NotifyList = "HotelNotifyEntitiesList"
	})

	local function RefreshHotelEntities()
		if Functions.RefreshEntityESP then Functions.RefreshEntityESP() end
	end
	Toggles.HotelEntityESPToggle:OnChanged(RefreshHotelEntities)
	Options.HotelEntityESPList:OnChanged(RefreshHotelEntities)

	local PreviousHotelColor = Options.HotelEntityESPColor.Value
	Options.HotelEntityESPColor:OnChanged(function(New)
		for _, Idx in HotelColorNames do
			if Options[Idx].Value == PreviousHotelColor then Options[Idx]:SetValue(New) end
		end
		PreviousHotelColor = New
		if Functions.RecolorEntityESP then Functions.RecolorEntityESP() end
	end)
	for _, Idx in HotelColorNames do
		Options[Idx]:OnChanged(function()
			if Functions.RecolorEntityESP then Functions.RecolorEntityESP() end
		end)
	end

Groupboxes.Hotel_AutomationTabbox = Tabs.Hotel:AddLeftTabbox("Automation | Settings")
Groupboxes.Self_Automation = Groupboxes.Hotel_AutomationTabbox:AddTab("Automation")
Groupboxes.Hotel_AutomationSettings = Groupboxes.Hotel_AutomationTabbox:AddTab("Settings")

Groupboxes.Self_Automation:AddToggle("HotelAutoLootToggle", {
	Text = "Auto Loot", Default = false,
	Tooltip = "Automatically collects the selected items when their prompts are in range."
})
local function BuildHotelAutoLootValues(Names)
	local Values = {}
	for _, Name in Names do
		if not Name:match("^%-%-.*%-%-$") then
			local Controls = { Mode = "Move" }
			if Name == "Gold" then
				table.insert(Controls, { Type = "Divider", Name = "--Gold Level--" })
				table.insert(Controls, { Type = "Slider", Name = "Minimum Level", Min = 1, Max = 6, Step = 1, Default = 1 })
				table.insert(Controls, { Type = "Slider", Name = "Maximum Level", Min = 1, Max = 6, Step = 1, Default = 6 })
			end
			Values[Name] = Controls
		end
	end
	return Values
end
Groupboxes.Self_Automation:AddValueDropdown("HotelAutoLootList", {
	Text = "Auto Loot List", Options = HotelAllItems, Multi = true, Values = BuildHotelAutoLootValues(HotelAllItems)
})
Groupboxes.Hotel_AutomationSettings:AddToggle("HotelLootDroppedItems", {
	Text = "Loot Drops", Default = true,
	Tooltip = "When off, Auto Loot ignores items lying in workspace.Drops."
})
Groupboxes.Hotel_AutomationSettings:AddToggle("HotelBuyJeffShopItems", {
	Text = "Buy Jeff Shop Items", Default = false,
	Tooltip = "Allows Auto Loot to purchase selected items from Jeff's Shop."
})
Groupboxes.Hotel_AutomationSettings:AddToggle("HotelAutoLootInRiftRooms", {
	Text = "Auto Loot In Rift Rooms", Default = true,
	Tooltip = "Allows Auto Loot to collect selected items inside Rift Rooms."
})
Groupboxes.Self_Automation:AddToggle("AutoBreakerBox", {
	Text = "Auto Breaker Box", Default = false, Tooltip = "Automatically solves the breaker box."
})
Groupboxes.Self_Automation:AddToggle("AutoSolveAnchors", {
	Text = "Auto Solve Anchors", Default = false,
	Tooltip = "Automatically enters the correct code into anchors when you are near them."
})
Toggles.AutoBreakerBox:OnChanged(function(Value)
	if Value and CurrentRooms:FindFirstChild("ElevatorBreaker", true) then
		if not Globals.BreakerBoxInteracted then
			if not Globals.BreakerBoxNotified then
				Functions.Notify({ Title = "Interact with the breaker box.", Body = "It will be automatically solved." })
				Globals.BreakerBoxInteracted = true
			end
		else
			Shared.RemotesFolder.EBF:FireServer()
		end
	end
end)

Groupboxes.Self_Automation:AddToggle("AutoHeartbeatMinigame", { Text = "Auto Heartbeat Minigame", Default = false, Tooltip = "Prevents the 'Figure' minigame from ever failing.", Disabled = not Functions.CheckCompatability({"hookmetamethod", "newcclosure", "getnamecallmethod"}), DisabledTooltip = Globals.IncompatibleMessage })
Groupboxes.Self_Automation:AddDivider()
Groupboxes.Self_Automation:AddToggle("AutoUnlockPadlockToggle", {
	Text = "Auto Unlock Padlock", Default = false, Tooltip = "Automatically enters the code into the library padlock."
})
Groupboxes.Self_Automation:AddSlider("AutoUnlockPadlockSlider", {
	Text = "Unlock Distance", Min = 1, Max = 50, Default = 10, Rounding = 0, Compact = true
})
Groupboxes.Self_Automation:AddToggle("AutoLibraryGuessCode", {
	Text = "Guess Library Code", Default = false,
	Tooltip = "Attempts to guess the library code, but collecting some books is also necessary."
})
Groupboxes.Self_Automation:AddDivider()
Groupboxes.Self_Automation:AddToggle("AutoLibrary", {
	Text = "Auto Library", Default = false,
	Tooltip = "Automatically gets books and paper."
})
Groupboxes.Self_Automation:AddToggle("SkipSeekHotel", {
	Text = "Skip Seek (Hotel)",
	Default = false,
	Tooltip = "Skips the entire Seek sections.",
})
Groupboxes.Self_Automation:AddToggle("AutoBreakerRoom", {
	Text = "Auto Breaker Room",
	Default = false,
	Tooltip = "Automatically completes the breaker sequence in Hotel Room 100.",
})
Groupboxes.Self_Automation:AddDivider()
Toggles.AutoHotel = Groupboxes.Self_Automation:AddToggle("AutoHotel", {
	Text = "Auto Hotel",
	Tooltip = "Automatically progresses through the hotel floor.",
	Risky = Shared.Floor ~= "Ballz",
	Default = false
})
Toggles.AutoHotelIgnoreEntities = Groupboxes.Self_Automation:AddToggle("AutoHotelIgnoreEntities", {
	Text = "Ignore Entities",
	Tooltip = "Skip all entity waits and pauses.",
	Default = false
})
Groupboxes.Self_Automation:AddDivider()
Groupboxes.Self_Automation:AddToggle("AutoInteractToggle", {
	Text = "Auto Interact", Default = false, Tooltip = "Automatically triggers nearby prompts."
})
Toggles.AutoInteractToggle:AddKeyPicker("AutoInteractKeybind", {
    Text = "Auto Interact",
    Default = "R",
    Mode = "Toggle",
    SyncToggleState = true
})
Groupboxes.Self_Automation:AddDropdown("AutoInteractIgnoreList", {
	Text = "Ignore List",
	Values = { "Glitch Fragments", "Jeff Items", "Dropped Items", "Currency", "Minecarts", "Locks" },
	Default = { "Glitch Fragments", "Jeff Items", "Dropped Items" },
	Multi = true, AllowNull = true
})

----------------------------------------------------------------------------------------------------
-- Hotel item / objective ESP + Auto Loot
----------------------------------------------------------------------------------------------------
local HotelObjectNames = {
	GoldPile = "Gold",
	GlitchCube = "Glitch Fragment",
	KeyObtain = "Key",
	ElectricalKeyObtain = "Electrical Key",
	LiveHintBook = "Book",
	LibraryHintPaper = "Hint Paper",
	LiveBreakerPolePickup = "Breaker Pole",
	Flashlight = "Flashlight",
	Candle = "Candle",
	Lighter = "Lighter",
	Lockpick = "Lockpick",
	Vitamins = "Vitamins",
	Smoothie = "Smoothie",
	Bandage = "Bandage",
	Battery = "Battery",
	SkeletonKey = "Skeleton Key",
	Shears = "Shears",
	Crucifix = "Crucifix",
	CrucifixWall = "Crucifix",
	CrucifixOnWall = "Crucifix",
	AlarmClock = "Alarm Clock",
	AlarmClockModel = "Alarm Clock",
	TipJar = "Tip Jar",
	Donut = "Donut",
	SallyToy = "Sally Toy",
	SallyToyObtain = "Sally Toy",
	RiftJar = "Rift Jar",
	RiftCandle = "Rift Candle",
	RiftSmoothie = "Rift Smoothie",
}
local HotelESPListForItem = {}
local HotelAutoLootListForItem = {}
for _, Name in HotelRealItems do
	HotelESPListForItem[Name] = "HotelAllItemsESPList"
	HotelAutoLootListForItem[Name] = "HotelAutoLootList"
end
local HotelEntries = {}
local HotelPrompts = {}
local HotelESPRefresh
local HotelESPRunning = true
local HotelESPRefreshQueued = false
local HotelLastLootTick = 0
local HotelPlayers = game:GetService("Players")

local function HotelIsInPlayerModel(Object)
	local Current = Object
	while Current and Current ~= Services.Workspace do
		if HotelPlayers:GetPlayerFromCharacter(Current) then return true end
		Current = Current.Parent
	end
	local Backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	return Backpack ~= nil and Object:IsDescendantOf(Backpack)
end

local function HotelFindItemRoot(Object)
	local Current = Object
	local Root, Label
	while Current and Current ~= Services.Workspace do
		if (Current:IsA("Model") or Current:IsA("BasePart")) and HotelObjectNames[Current.Name] then
			Root, Label = Current, HotelObjectNames[Current.Name]
		end
		Current = Current.Parent
	end
	return Root, Label
end

local function HotelRoomOf(Object)
	local Current = Object
	while Current and Current.Parent do
		if Current.Parent == CurrentRooms then return tonumber(Current.Name) end
		Current = Current.Parent
	end
	return nil
end

local function HotelInRoomRange(Room, Settings)
	if Room == nil then return true end
	Settings = type(Settings) == "table" and Settings or {}
	if Settings.Always then return true end
	local CurrentRoom = tonumber(LocalPlayer:GetAttribute("CurrentRoom"))
	if not CurrentRoom then return false end
	return (Settings.Previous and Room == CurrentRoom - 1)
		or (Settings.Current and Room == CurrentRoom)
		or (Settings.Next and Room == CurrentRoom + 1)
end

local function HotelIsVisiblePart(Part)
	return Part:IsA("BasePart") and Part.Transparency < 1 and Part.LocalTransparencyModifier < 1
end

local function HotelGoldLevel(GoldPile)
	local Level = 0
	for _, Layer in GoldPile:GetChildren() do
		local Number = tonumber(Layer.Name)
		if Number and Number >= 1 and Number <= 6 and Number % 1 == 0 then
			local Visible = false
			if Layer:IsA("BasePart") and HotelIsVisiblePart(Layer) then
				Visible = true
			else
				for _, Part in Layer:GetDescendants() do
					if HotelIsVisiblePart(Part) then Visible = true break end
				end
			end
			if Visible then Level = math.max(Level, Number) end
		end
	end
	if Level > 0 then return Level end
	local AttributeLevel = tonumber(GoldPile:GetAttribute("GoldLevel")) or tonumber(GoldPile:GetAttribute("Level"))
	return AttributeLevel and math.clamp(math.floor(AttributeLevel), 1, 6) or nil
end

local function HotelPromptName(Label)
	if Label == "Gold" then return "LootPrompt" end
	if Label == "Book" or Label == "Breaker Pole" then return "ActivateEventPrompt" end
	return "ModulePrompt"
end

local function HotelGetPrompt(Object, Label)
	local PromptName = HotelPromptName(Label)
	for _, Descendant in Object:GetDescendants() do
		if Descendant:IsA("ProximityPrompt") and Descendant.Name == PromptName then
			return Descendant
		end
	end
	return nil
end

local function HotelBuildProxy(Target)
	local Proxy = Instance.new("Model")
	Proxy.Name = "HotelItemESPProxy"
	local Humanoid = Instance.new("Humanoid")
	Humanoid.Name = "HighlightHumanoid"
	Humanoid.Parent = Proxy
	local Count = 0
	local function AddPart(Part)
		if Count >= 80 or not HotelIsVisiblePart(Part) then return end
		local Ok, Copy = pcall(function() return Part:Clone() end)
		if not Ok or not Copy then return end
		for _, Child in Copy:GetChildren() do
			if not Child:IsA("DataModelMesh") then Child:Destroy() end
		end
		Copy.Anchored = false
		Copy.CanCollide = false
		Copy.CanQuery = false
		Copy.CanTouch = false
		Copy.Massless = true
		Copy.CastShadow = false
		Copy.Transparency = 0.999
		Copy.LocalTransparencyModifier = 0
		Copy.Name = "ESPPart"
		local Weld = Instance.new("WeldConstraint")
		Weld.Part0 = Part
		Weld.Part1 = Copy
		Weld.Parent = Copy
		Copy.Parent = Proxy
		Count += 1
	end
	if Target:IsA("BasePart") then
		AddPart(Target)
	else
		for _, Descendant in Target:GetDescendants() do
			if Descendant:IsA("BasePart") then AddPart(Descendant) end
		end
	end
	if Count == 0 then Proxy:Destroy() return nil end
	Proxy.Parent = Services.Workspace
	return Proxy
end

local function HotelEntryColor(Entry)
	local ListId = HotelESPListForItem[Entry.Label]
	local Settings = ListId and Options[ListId] and Options[ListId].Value[Entry.Label]
	if type(Settings) == "table" and typeof(Settings.Color) == "Color3" then return Settings.Color end
	return Color3.fromRGB(255, 210, 60)
end

local function HotelWantsEntry(Entry)
	local Object, Label = Entry.Object, Entry.Label
	if Shared.Floor ~= "Hotel" or not Object.Parent or not Object:IsDescendantOf(Services.Workspace) then return false end
	if HotelIsInPlayerModel(Object) then return false end
	if not HotelSourceAllowed(Object, true) then return false end
	local Prompt = HotelGetPrompt(Object, Label)
	if not Prompt or not Prompt.Parent then return false end
	if Label == "Glitch Fragment" then
		local Handle = Object:FindFirstChild("Handle") or Object:FindFirstChildWhichIsA("BasePart", true)
		if Handle and Handle.LocalTransparencyModifier >= 0.8 then return false end
	end
	local ListId = HotelESPListForItem[Label]
	local Settings = ListId and Options[ListId] and Options[ListId].Value[Label]
	if not (Toggles.HotelItemESPToggle.Value and type(Settings) == "table") then return false end
	if not HotelInRoomRange(HotelRoomOf(Object), Settings) then return false end
	if Label == "Gold" then
		local Level = HotelGoldLevel(Object)
		Entry.GoldLevel = Level
		if not Level then return false end
		local Minimum = tonumber(Settings["Minimum Level"]) or 1
		local Maximum = tonumber(Settings["Maximum Level"]) or 6
		if Level < math.min(Minimum, Maximum) or Level > math.max(Minimum, Maximum) then return false end
	else
		Entry.GoldLevel = nil
	end
	return true
end

local function HotelHideEntry(Entry)
	if not Entry.Shown then return end
	Entry.Shown = false
	if Entry.Proxy then
		Functions.RemoveESP(Entry.Proxy)
		pcall(function() Entry.Proxy:Destroy() end)
		Entry.Proxy = nil
	end
	Entry.LastColor = nil
end

local function HotelShowEntry(Entry)
	local Proxy = HotelBuildProxy(Entry.Object)
	if not Proxy then return end
	local Color = HotelEntryColor(Entry)
	local Label = Entry.Label
	if Label == "Gold" then
		local GoldValue = Entry.Object:GetAttribute("GoldValue")
		if GoldValue ~= nil then Label = "Gold [" .. tostring(GoldValue) .. "]" end
	end
	Entry.Proxy = Proxy
	Entry.LastColor = Color
	Entry.Shown = true
	Functions.AddESP({ Object = Proxy, Text = Label, Color = Color })
end

local function HotelApplyEntry(Entry)
	if Entry.Shown and Entry.Proxy and (not Entry.Proxy.Parent or (Abysall and Abysall.ESPLibrary and Abysall.ESPLibrary.ElementsEnabled[Entry.Proxy] ~= true)) then
		HotelHideEntry(Entry)
	end
	local PreviousLevel = Entry.GoldLevel
	local Want = HotelWantsEntry(Entry)
	local Color = Want and HotelEntryColor(Entry) or nil
	local LevelChanged = Entry.Label == "Gold" and Entry.Shown and PreviousLevel ~= Entry.GoldLevel
	if Want and (not Entry.Shown or Entry.LastColor ~= Color or LevelChanged) then
		HotelHideEntry(Entry)
		HotelShowEntry(Entry)
	elseif not Want and Entry.Shown then
		HotelHideEntry(Entry)
	end
end

HotelESPRefresh = function()
	if HotelESPRefreshQueued then return end
	HotelESPRefreshQueued = true
	task.defer(function()
		HotelESPRefreshQueued = false
		if not HotelESPRunning then return end
		for _, Entry in HotelEntries do
			pcall(HotelApplyEntry, Entry)
		end
	end)
end

local function HotelTrackObject(Object)
	local Root, Label = HotelFindItemRoot(Object)
	if not Root or not Label or not Root:IsDescendantOf(Services.Workspace) then return end
	if HotelEntries[Root] then return end
	local Entry = { Object = Root, Label = Label, Shown = false, Proxy = nil, LastColor = nil, Conns = {} }
	HotelEntries[Root] = Entry
	table.insert(Entry.Conns, Root.AncestryChanged:Connect(HotelESPRefresh))
	if Label == "Glitch Fragment" then
		local Handle = Root:FindFirstChild("Handle") or Root:FindFirstChildWhichIsA("BasePart", true)
		if Handle then
			table.insert(Entry.Conns, Handle:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(HotelESPRefresh))
		end
	end
	table.insert(Entry.Conns, Root.Destroying:Connect(function()
		HotelHideEntry(Entry)
		for _, Conn in Entry.Conns do pcall(function() Conn:Disconnect() end) end
		HotelEntries[Root] = nil
	end))
	HotelESPRefresh()
end

local function HotelTrackPrompt(Prompt)
	if not Prompt:IsA("ProximityPrompt") then return end
	HotelTrackObject(Prompt)
	if HotelPrompts[Prompt] then return end
	HotelPrompts[Prompt] = { LastFire = 0 }
	Prompt.Destroying:Once(function() HotelPrompts[Prompt] = nil end)
end

for _, Object in Services.Workspace:GetDescendants() do
	HotelTrackObject(Object)
	if Object:IsA("ProximityPrompt") then HotelTrackPrompt(Object) end
end
Connections.HotelItemDescendantAdded = Services.Workspace.DescendantAdded:Connect(function(Object)
	HotelTrackObject(Object)
	if Object:IsA("ProximityPrompt") then HotelTrackPrompt(Object) end
end)
Connections.HotelItemDescendantRemoving = Services.Workspace.DescendantRemoving:Connect(function(Object)
	if HotelEntries[Object] then
		local Entry = HotelEntries[Object]
		HotelHideEntry(Entry)
		for _, Conn in Entry.Conns do pcall(function() Conn:Disconnect() end) end
		HotelEntries[Object] = nil
	end
	if HotelPrompts[Object] then HotelPrompts[Object] = nil end
end)
Toggles.HotelItemESPToggle:OnChanged(HotelESPRefresh)
Options.HotelAllItemsESPList:OnChanged(HotelESPRefresh)
for _, ToggleId in { "HotelESPJeffItems", "HotelESPDrops", "HotelESPRiftRooms" } do
	Toggles[ToggleId]:OnChanged(HotelESPRefresh)
end
Connections.HotelItemRoomChanged = LocalPlayer:GetAttributeChangedSignal("CurrentRoom"):Connect(HotelESPRefresh)

-- Re-scan periodically: prompts may be parented after their item model and transparency may change during pickup.
task.spawn(function()
	while HotelESPRunning do
		task.wait(0.75)
		if not HotelESPRunning then break end
		for _, Object in Services.Workspace:GetDescendants() do
			if Object:IsA("ProximityPrompt") then
				HotelTrackPrompt(Object)
			elseif HotelFindItemRoot(Object) then
				HotelTrackObject(Object)
			end
		end
		HotelESPRefresh()
	end
end)

local function HotelAutoLootSelected(Label)
	local ListId = HotelAutoLootListForItem[Label]
	local Settings = ListId and Options[ListId] and Options[ListId].Value[Label]
	return type(Settings) == "table"
end

local function HotelAutoLootGoldAllowed(Object)
	local Level = HotelGoldLevel(Object)
	if not Level then return false end
	local Settings = Options.HotelAutoLootList and Options.HotelAutoLootList.Value.Gold
	Settings = type(Settings) == "table" and Settings or {}
	local Minimum = tonumber(Settings["Minimum Level"]) or 1
	local Maximum = tonumber(Settings["Maximum Level"]) or 6
	return Level >= math.min(Minimum, Maximum) and Level <= math.max(Minimum, Maximum)
end

local function HotelSourceOf(Object)
	local Current = Object
	while Current and Current ~= Services.Workspace do
		if Current.Name:match("^RiftRoom_") then return "Rift" end
		if Current.Name == "JeffShop" then return "JeffShop" end
		if Current.Name == "Drops" then return "Drops" end
		Current = Current.Parent
	end
	return "Room"
end

local function HotelSourceAllowed(Object, ForESP)
	local Source = HotelSourceOf(Object)
	if Source == "JeffShop" then
		return ForESP and Toggles.HotelESPJeffItems.Value or (not ForESP and Toggles.HotelBuyJeffShopItems.Value)
	elseif Source == "Drops" then
		return ForESP and Toggles.HotelESPDrops.Value or (not ForESP and Toggles.HotelLootDroppedItems.Value)
	elseif Source == "Rift" then
		return ForESP and Toggles.HotelESPRiftRooms.Value or (not ForESP and Toggles.HotelAutoLootInRiftRooms.Value)
	end
	return true
end

Connections.HotelAutoLoot = Services.RunService.Heartbeat:Connect(function()
	if not Toggles.HotelAutoLootToggle.Value or Shared.Floor ~= "Hotel" then return end
	if tick() - HotelLastLootTick < 0.12 then return end
	HotelLastLootTick = tick()
	local Character = LocalPlayer.Character
	if not Character or Character:GetAttribute("Hiding") == true then return end
	local RootPart = Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart
	if not RootPart then return end
	local BestPrompt, BestDistance
	for Prompt, Info in HotelPrompts do
		if not Prompt.Parent or not Prompt.Enabled or not Prompt:IsDescendantOf(Services.Workspace) then continue end
		if HotelIsInPlayerModel(Prompt) then continue end
		local ItemRoot, Label = HotelFindItemRoot(Prompt)
		if not ItemRoot or not Label or not HotelAutoLootSelected(Label) then continue end
		if not HotelSourceAllowed(ItemRoot, false) then continue end
		if Label == "Gold" and not HotelAutoLootGoldAllowed(ItemRoot) then continue end
		if Label == "Glitch Fragment" then
			local Handle = ItemRoot:FindFirstChild("Handle") or ItemRoot:FindFirstChildWhichIsA("BasePart", true)
			if Handle and Handle.LocalTransparencyModifier >= 0.8 then continue end
		end
		local CorrectPrompt = HotelGetPrompt(ItemRoot, Label)
		if CorrectPrompt ~= Prompt then continue end
		local Position
		if Prompt.Parent:IsA("BasePart") then
			Position = Prompt.Parent.Position
		else
			Position = ItemRoot:GetPivot().Position
		end
		local Distance = (Position - RootPart.Position).Magnitude
		if Distance > Prompt.MaxActivationDistance then continue end
		if tick() - (Info.LastFire or 0) < 0.65 then continue end
		if not BestDistance or Distance < BestDistance then
			BestPrompt, BestDistance = Prompt, Distance
		end
	end
	if BestPrompt then
		HotelPrompts[BestPrompt].LastFire = tick()
		task.spawn(Functions.FirePrompt, BestPrompt)
	end
end)

Connections.HotelItemCleanup = {
	Disconnect = function()
		HotelESPRunning = false
		for _, Entry in HotelEntries do
			HotelHideEntry(Entry)
			for _, Conn in Entry.Conns do pcall(function() Conn:Disconnect() end) end
		end
		table.clear(HotelEntries)
		table.clear(HotelPrompts)
	end
}

Groupboxes.Self_Automation:AddDivider()
Groupboxes.Self_Automation:AddToggle("AutoClosetToggle", {
	Text = "Auto Closet", Default = false,
	Tooltip = "Automatically hides in a nearby closet when an entity is near."
})
Toggles.AutoClosetToggle:AddKeyPicker("AutoClosetKeybind", {
	Text = "Auto Closet", Default = "Q", Mode = "Toggle", SyncToggleState = true
})
Groupboxes.Self_Automation:AddDropdown("AutoClosetEntityList", {
	Text = "Ignore List",
	Values = { "Rush", "Ambush", "Blitz", "DronesStampede", "Scribbles", "A-60", "A-120", "AR0xMBUSH", "RNIUSHCG==" },
	Multi = true, AllowNull = true
})
Groupboxes.Self_Automation:AddToggle("SpectateEntityToggle", {
	Text = "Spectate Entity",
	Default = false,
	Tooltip = "Spectates the entity while auto hiding."
})
Groupboxes.Self_Automation:AddDropdown("SpecateEntityMode", {
	Values = {"Player to Entity", "Entity to Player"},
	Default = 1,
	AllowNull = true
})



Toggles.SkipSeekHotel:OnChanged(function(Value)
	if not Value then return end
	if Shared.Floor ~= "Hotel" then return end

	task.spawn(function()
		print("started")

		local currentRooms

		repeat
			if not Toggles.SkipSeekHotel.Value or Shared.Floor ~= "Hotel" then
				return
			end
			currentRooms = workspace:FindFirstChild("CurrentRooms")
			task.wait()
		until currentRooms

		print("got currentrooms")

		local lastTriggerRoom = nil

		while Toggles.SkipSeekHotel.Value and Shared.Floor == "Hotel" do
			local triggerRoom = nil

			print("waiting for trigger")

			repeat
				if not Toggles.SkipSeekHotel.Value or Shared.Floor ~= "Hotel" then
					return
				end

				currentRooms = workspace:FindFirstChild("CurrentRooms")
				local currentRoomNum = tonumber(LocalPlayer:GetAttribute("CurrentRoom"))

				if currentRoomNum and currentRoomNum ~= lastTriggerRoom then
					local room = currentRooms and currentRooms:FindFirstChild(tostring(currentRoomNum))
					if room then
						local trigger = room:WaitForChild("TriggerEventCollision", 0.5)
						if trigger then
							triggerRoom = currentRoomNum
							print("found trigger in", triggerRoom)
						end
					end
				end

				task.wait()
			until triggerRoom

			lastTriggerRoom = triggerRoom

			local roomNum = triggerRoom

			while Toggles.SkipSeekHotel.Value and Shared.Floor == "Hotel" do
				roomNum += 1
				print("looking for room", roomNum)

				local room
				repeat
					if not Toggles.SkipSeekHotel.Value or Shared.Floor ~= "Hotel" then
						return
					end
					currentRooms = workspace:FindFirstChild("CurrentRooms")
					room = currentRooms and currentRooms:FindFirstChild(tostring(roomNum))
					task.wait()
				until room

				print("found room", roomNum)

				local hasSeekArm = false
				local assets = room:FindFirstChild("Assets")
				if assets then
					for _, child in ipairs(assets:GetChildren()) do
						if child.Name == "Seek_Arm" then
							hasSeekArm = true
							print("found seek arm")
							break
						end
					end
				end

				local door
				repeat
					if not Toggles.SkipSeekHotel.Value or Shared.Floor ~= "Hotel" then
						return
					end
					door = room:FindFirstChild("Door", true)
					task.wait()
				until door

				print("found door, teleporting")

				repeat
					if not Toggles.SkipSeekHotel.Value or Shared.Floor ~= "Hotel" then
						return
					end
					if Shared.Character then
						Shared.Character:PivotTo(door:GetPivot())
					end
					task.wait()
				until door:GetAttribute("Opened") == true

				print("door opened")

				if hasSeekArm then
					if not Shared.Character then
						return
					end

					print("voiding")

					local voidCFrame = Shared.Character:GetPivot() + Vector3.new(0, -2500, 0)

					task.wait(0.25)

					for _ = 1, 20 do
						Shared.Character:PivotTo(voidCFrame)
						task.wait()
					end

					task.wait(0.3)

					for _ = 1, 15 do
						Shared.Character:PivotTo(voidCFrame)
						task.wait()
					end

					task.wait(0.2)

					for _ = 1, 10 do
						Shared.Character:PivotTo(voidCFrame)
						task.wait()
					end

					print("done voiding")
					break
				end
			end
		end
	end)
end)

Toggles.AutoLibrary:OnChanged(function(AutoLibraryEnabled)
	if AutoLibraryConnection then
		task.cancel(AutoLibraryConnection)
		AutoLibraryConnection = nil
	end

	if AutoLibraryRoomConnection then
		AutoLibraryRoomConnection:Disconnect()
		AutoLibraryRoomConnection = nil
	end

	if not AutoLibraryEnabled then
		return
	end

	AutoLibraryConnection = task.spawn(function()
		local AutoLibraryPlayers = game:GetService("Players")
		local AutoLibraryLocalPlayer = AutoLibraryPlayers.LocalPlayer
		local AutoLibraryCharacter = AutoLibraryLocalPlayer.Character or AutoLibraryLocalPlayer.CharacterAdded:Wait()
		local AutoLibraryHumanoidRootPart = AutoLibraryCharacter:WaitForChild("HumanoidRootPart")

		local AutoLibraryCurrentRooms = workspace:WaitForChild("CurrentRooms")
		local AutoLibraryRoom50 = AutoLibraryCurrentRooms:WaitForChild("50")
		local AutoLibraryLiveHintBooks = {}
		local AutoLibraryHintPaperObtained = false

		local function AutoLibraryIsInRoom50(AutoLibraryObject)
			return AutoLibraryObject
				and AutoLibraryObject:IsDescendantOf(AutoLibraryRoom50)
				and AutoLibraryObject:IsDescendantOf(AutoLibraryCurrentRooms)
				and AutoLibraryObject:IsDescendantOf(workspace)
		end

		local function AutoLibraryIsActuallyInRoom50()
			return tonumber(AutoLibraryLocalPlayer:GetAttribute("CurrentRoom")) == 50
		end

		while AutoLibraryEnabled and not AutoLibraryIsActuallyInRoom50() do
			task.wait(0.05)
		end

		if not AutoLibraryEnabled then
			return
		end

		local function AutoLibraryHasHintPaper()
			AutoLibraryCharacter = AutoLibraryLocalPlayer.Character

			if not AutoLibraryCharacter then
				return false
			end

			local AutoLibraryBackpackPaper = AutoLibraryLocalPlayer.Backpack:FindFirstChild("LibraryHintPaper", true)
			local AutoLibraryCharacterPaper = AutoLibraryCharacter:FindFirstChild("LibraryHintPaper", true)

			return AutoLibraryBackpackPaper ~= nil or AutoLibraryCharacterPaper ~= nil
		end

		local function AutoLibraryGetObjectCFrame(AutoLibraryObject)
			if not AutoLibraryIsActuallyInRoom50() then
				return nil
			end

			if not AutoLibraryIsInRoom50(AutoLibraryObject) then
				return nil
			end

			if AutoLibraryObject:IsA("Model") then
				return AutoLibraryObject:GetPivot()
			elseif AutoLibraryObject:IsA("BasePart") then
				return AutoLibraryObject.CFrame
			end

			local AutoLibraryObjectPart = AutoLibraryObject:FindFirstChildWhichIsA("BasePart", true)

			if AutoLibraryObjectPart then
				return AutoLibraryObjectPart.CFrame
			end

			return nil
		end

		local function AutoLibraryFindBooks(AutoLibraryObject)
			if not AutoLibraryIsActuallyInRoom50() then
				return
			end

			if not AutoLibraryIsInRoom50(AutoLibraryObject) then
				return
			end

			if AutoLibraryObject.Name == "LiveHintBook" then
				if not table.find(AutoLibraryLiveHintBooks, AutoLibraryObject) then
					table.insert(AutoLibraryLiveHintBooks, AutoLibraryObject)
				end
			end

			for _, AutoLibraryDescendant in ipairs(AutoLibraryObject:GetDescendants()) do
				if AutoLibraryDescendant.Name == "LiveHintBook"
					and AutoLibraryIsInRoom50(AutoLibraryDescendant) then

					if not table.find(AutoLibraryLiveHintBooks, AutoLibraryDescendant) then
						table.insert(AutoLibraryLiveHintBooks, AutoLibraryDescendant)
					end
				end
			end
		end

		for _, AutoLibraryDescendant in ipairs(AutoLibraryRoom50:GetDescendants()) do
			if not AutoLibraryEnabled or not AutoLibraryIsActuallyInRoom50() then
				return
			end

			if AutoLibraryDescendant.Name == "LiveHintBook"
				and AutoLibraryIsInRoom50(AutoLibraryDescendant) then

				if not table.find(AutoLibraryLiveHintBooks, AutoLibraryDescendant) then
					table.insert(AutoLibraryLiveHintBooks, AutoLibraryDescendant)
				end
			end
		end

		AutoLibraryRoomConnection = AutoLibraryRoom50.DescendantAdded:Connect(function(AutoLibraryAddedObject)
			if not AutoLibraryEnabled then
				return
			end

			if not AutoLibraryIsActuallyInRoom50() then
				return
			end

			if not AutoLibraryIsInRoom50(AutoLibraryAddedObject) then
				return
			end

			AutoLibraryFindBooks(AutoLibraryAddedObject)
		end)

		while AutoLibraryEnabled
			and AutoLibraryIsActuallyInRoom50()
			and #AutoLibraryLiveHintBooks < 3 do

			for _, AutoLibraryDescendant in ipairs(AutoLibraryRoom50:GetDescendants()) do
				if not AutoLibraryEnabled or not AutoLibraryIsActuallyInRoom50() then
					return
				end

				if AutoLibraryDescendant.Name == "LiveHintBook"
					and AutoLibraryIsInRoom50(AutoLibraryDescendant)
					and not table.find(AutoLibraryLiveHintBooks, AutoLibraryDescendant) then

					table.insert(AutoLibraryLiveHintBooks, AutoLibraryDescendant)
				end
			end

			if #AutoLibraryLiveHintBooks >= 3 then
				break
			end

			task.wait(0.05)
		end

		while AutoLibraryEnabled
			and AutoLibraryIsActuallyInRoom50()
			and not AutoLibraryHintPaperObtained do

			if AutoLibraryHasHintPaper() then
				AutoLibraryHintPaperObtained = true
				break
			end

			for AutoLibraryIndex = #AutoLibraryLiveHintBooks, 1, -1 do
				if not AutoLibraryIsActuallyInRoom50() then
					return
				end

				local AutoLibraryLiveHintBook = AutoLibraryLiveHintBooks[AutoLibraryIndex]

				if not AutoLibraryIsInRoom50(AutoLibraryLiveHintBook) then
					table.remove(AutoLibraryLiveHintBooks, AutoLibraryIndex)
					continue
				end

				while AutoLibraryEnabled
					and AutoLibraryIsActuallyInRoom50()
					and not AutoLibraryHintPaperObtained
					and AutoLibraryLiveHintBook.Parent
					and AutoLibraryIsInRoom50(AutoLibraryLiveHintBook) do

					if AutoLibraryHasHintPaper() then
						AutoLibraryHintPaperObtained = true
						break
					end

					AutoLibraryCharacter = AutoLibraryLocalPlayer.Character or AutoLibraryLocalPlayer.CharacterAdded:Wait()
					AutoLibraryHumanoidRootPart = AutoLibraryCharacter:FindFirstChild("HumanoidRootPart")

					if not AutoLibraryHumanoidRootPart then
						task.wait()
						continue
					end

					local AutoLibraryBookCFrame = AutoLibraryGetObjectCFrame(AutoLibraryLiveHintBook)

					if AutoLibraryBookCFrame
						and AutoLibraryIsActuallyInRoom50()
						and AutoLibraryIsInRoom50(AutoLibraryLiveHintBook) then

						AutoLibraryHumanoidRootPart.CFrame = AutoLibraryBookCFrame
					end

					for _, AutoLibraryPromptDescendant in ipairs(AutoLibraryLiveHintBook:GetDescendants()) do
						if AutoLibraryPromptDescendant:IsA("ProximityPrompt")
							and AutoLibraryIsInRoom50(AutoLibraryPromptDescendant)
							and AutoLibraryIsActuallyInRoom50() then

							fireproximityprompt(AutoLibraryPromptDescendant)
						end
					end

					task.wait(0.05)
				end

				if AutoLibraryHintPaperObtained then
					break
				end
			end

			if AutoLibraryHasHintPaper() then
				AutoLibraryHintPaperObtained = true
				break
			end

			local AutoLibraryHintPaper = AutoLibraryRoom50:FindFirstChild("LibraryHintPaper", true)

			if AutoLibraryHintPaper
				and AutoLibraryIsInRoom50(AutoLibraryHintPaper)
				and AutoLibraryIsActuallyInRoom50() then

				while AutoLibraryEnabled
					and AutoLibraryIsActuallyInRoom50()
					and not AutoLibraryHintPaperObtained
					and AutoLibraryHintPaper.Parent
					and AutoLibraryIsInRoom50(AutoLibraryHintPaper) do

					if AutoLibraryHasHintPaper() then
						AutoLibraryHintPaperObtained = true
						break
					end

					AutoLibraryCharacter = AutoLibraryLocalPlayer.Character or AutoLibraryLocalPlayer.CharacterAdded:Wait()
					AutoLibraryHumanoidRootPart = AutoLibraryCharacter:FindFirstChild("HumanoidRootPart")

					if not AutoLibraryHumanoidRootPart then
						task.wait()
						continue
					end

					local AutoLibraryPaperCFrame = AutoLibraryGetObjectCFrame(AutoLibraryHintPaper)

					if AutoLibraryPaperCFrame
						and AutoLibraryIsActuallyInRoom50()
						and AutoLibraryIsInRoom50(AutoLibraryHintPaper) then

						AutoLibraryHumanoidRootPart.CFrame = AutoLibraryPaperCFrame * CFrame.new(0, 5, 0)
					end

					for _, AutoLibraryPromptDescendant in ipairs(AutoLibraryHintPaper:GetDescendants()) do
						if AutoLibraryPromptDescendant:IsA("ProximityPrompt")
							and AutoLibraryIsInRoom50(AutoLibraryPromptDescendant)
							and AutoLibraryIsActuallyInRoom50() then

							fireproximityprompt(AutoLibraryPromptDescendant)
						end
					end

					task.wait(0.05)
				end
			end

			task.wait(0.05)
		end
	end)
end)

Toggles.AutoBreakerRoom:OnChanged(function(AutoBreakerRoomEnabled)
	if AutoBreakerRoomConnection then
		task.cancel(AutoBreakerRoomConnection)
		AutoBreakerRoomConnection = nil
	end

	if AutoBreakerRoomRoomConnection then
		AutoBreakerRoomRoomConnection:Disconnect()
		AutoBreakerRoomRoomConnection = nil
	end

	if not AutoBreakerRoomEnabled then
		return
	end

	local AutoBreakerRoomGateFireTime = 5
	local AutoBreakerRoomWaitAfterLever = 5
	local AutoBreakerRoomBreakerSecondTime = 10
	local AutoBreakerRoomWaitBeforeWeb = 4
	local AutoBreakerRoomWebDuration = 20

	AutoBreakerRoomConnection = task.spawn(function()
		local AutoBreakerRoomPlayers = game:GetService("Players")
		local AutoBreakerRoomCurrentRooms = workspace:WaitForChild("CurrentRooms")
		local AutoBreakerRoom100 = AutoBreakerRoomCurrentRooms:WaitForChild("100")

		local function AutoBreakerRoomIsActuallyInRoom100()
			return tonumber(AutoBreakerRoomPlayers.LocalPlayer:GetAttribute("CurrentRoom")) == 100
		end

		local function AutoBreakerRoomIsInRoom100(AutoBreakerRoomObject)
			return AutoBreakerRoomObject
				and AutoBreakerRoomObject.Parent
				and AutoBreakerRoomObject:IsDescendantOf(AutoBreakerRoom100)
				and AutoBreakerRoomObject:IsDescendantOf(AutoBreakerRoomCurrentRooms)
		end

		local function AutoBreakerRoomGetObjectCFrame(AutoBreakerRoomObject)
			if not AutoBreakerRoomIsActuallyInRoom100() or not AutoBreakerRoomIsInRoom100(AutoBreakerRoomObject) then
				return nil
			end

			if AutoBreakerRoomObject:IsA("Model") then
				return AutoBreakerRoomObject:GetPivot()
			elseif AutoBreakerRoomObject:IsA("BasePart") then
				return AutoBreakerRoomObject.CFrame
			end

			local AutoBreakerRoomPart = AutoBreakerRoomObject:FindFirstChildWhichIsA("BasePart", true)
			return AutoBreakerRoomPart and AutoBreakerRoomPart.CFrame
		end

		local function AutoBreakerRoomGetHRP()
			local AutoBreakerRoomCharacter = AutoBreakerRoomPlayers.LocalPlayer.Character
			return AutoBreakerRoomCharacter and AutoBreakerRoomCharacter:FindFirstChild("HumanoidRootPart")
		end

		local function AutoBreakerRoomActivate(AutoBreakerRoomObject)
			if not AutoBreakerRoomObject then
				return
			end

			if AutoBreakerRoomObject:IsA("ProximityPrompt") then
				fireproximityprompt(AutoBreakerRoomObject)
				return
			end

			for _, AutoBreakerRoomDescendant in ipairs(AutoBreakerRoomObject:GetDescendants()) do
				if AutoBreakerRoomDescendant:IsA("ProximityPrompt") then
					fireproximityprompt(AutoBreakerRoomDescendant)
				end
			end
		end

		local function AutoBreakerRoomConstantTPAndActivate(AutoBreakerRoomTarget, AutoBreakerRoomDuration, AutoBreakerRoomInterval, AutoBreakerRoomOffset)
			AutoBreakerRoomInterval = AutoBreakerRoomInterval or 0.04
			AutoBreakerRoomOffset = AutoBreakerRoomOffset or CFrame.new()
			local AutoBreakerRoomEndTime = os.clock() + (AutoBreakerRoomDuration or 3)

			while AutoBreakerRoomEnabled
				and AutoBreakerRoomIsActuallyInRoom100()
				and AutoBreakerRoomIsInRoom100(AutoBreakerRoomTarget)
				and os.clock() < AutoBreakerRoomEndTime do

				local AutoBreakerRoomHRP = AutoBreakerRoomGetHRP()
				local AutoBreakerRoomCF = AutoBreakerRoomGetObjectCFrame(AutoBreakerRoomTarget)

				if AutoBreakerRoomHRP and AutoBreakerRoomCF then
					AutoBreakerRoomHRP.CFrame = AutoBreakerRoomCF * AutoBreakerRoomOffset
				end

				AutoBreakerRoomActivate(AutoBreakerRoomTarget)
				task.wait(AutoBreakerRoomInterval)
			end
		end

		while AutoBreakerRoomEnabled do
			while AutoBreakerRoomEnabled and not AutoBreakerRoomIsActuallyInRoom100() do
				task.wait(0.1)
			end

			if not AutoBreakerRoomEnabled then
				return
			end

			local AutoBreakerRoomPoles = {}

			while AutoBreakerRoomEnabled and AutoBreakerRoomIsActuallyInRoom100() do
				AutoBreakerRoomPoles = {}

				for _, AutoBreakerRoomDescendant in ipairs(AutoBreakerRoom100:GetDescendants()) do
					if AutoBreakerRoomDescendant.Name == "LiveBreakerPolePickup" and AutoBreakerRoomIsInRoom100(AutoBreakerRoomDescendant) then
						if not table.find(AutoBreakerRoomPoles, AutoBreakerRoomDescendant) then
							table.insert(AutoBreakerRoomPoles, AutoBreakerRoomDescendant)
						end
					end
				end

				if #AutoBreakerRoomPoles == 0 then
					break
				end

				for _, AutoBreakerRoomPole in ipairs(AutoBreakerRoomPoles) do
					if not AutoBreakerRoomEnabled or not AutoBreakerRoomIsActuallyInRoom100() then
						break
					end

					if AutoBreakerRoomIsInRoom100(AutoBreakerRoomPole) then
						AutoBreakerRoomConstantTPAndActivate(AutoBreakerRoomPole, 2.8, 0.03)
						task.wait(0.12)
					end
				end

				task.wait(0.05)
			end

			if not AutoBreakerRoomEnabled or not AutoBreakerRoomIsActuallyInRoom100() then
				continue
			end

			local AutoBreakerRoomIndustrialGate = AutoBreakerRoom100:FindFirstChild("IndustrialGate")
			local AutoBreakerRoomBox = AutoBreakerRoomIndustrialGate and AutoBreakerRoomIndustrialGate:FindFirstChild("Box")
			local AutoBreakerRoomLever = AutoBreakerRoomBox and AutoBreakerRoomBox:FindFirstChild("Lever")
			local AutoBreakerRoomActivateEventPrompt = AutoBreakerRoomBox and AutoBreakerRoomBox:FindFirstChild("ActivateEventPrompt")

			if AutoBreakerRoomActivateEventPrompt and AutoBreakerRoomLever then
				local function AutoBreakerRoomGetLeverCFrame()
					if AutoBreakerRoomLever:IsA("Model") then
						return AutoBreakerRoomLever:GetPivot()
					elseif AutoBreakerRoomLever:IsA("BasePart") then
						return AutoBreakerRoomLever.CFrame
					end
					local AutoBreakerRoomPart = AutoBreakerRoomLever:FindFirstChildWhichIsA("BasePart", true)
					return AutoBreakerRoomPart and AutoBreakerRoomPart.CFrame
				end

				local AutoBreakerRoomInitialLeverCFrame = AutoBreakerRoomGetLeverCFrame()
				local AutoBreakerRoomLeverEndTime = os.clock() + 10

				while AutoBreakerRoomEnabled
					and AutoBreakerRoomIsActuallyInRoom100()
					and AutoBreakerRoomIsInRoom100(AutoBreakerRoomLever)
					and os.clock() < AutoBreakerRoomLeverEndTime do

					local AutoBreakerRoomCurrentLeverCFrame = AutoBreakerRoomGetLeverCFrame()

					if AutoBreakerRoomCurrentLeverCFrame and AutoBreakerRoomInitialLeverCFrame
						and AutoBreakerRoomCurrentLeverCFrame ~= AutoBreakerRoomInitialLeverCFrame then
						break
					end

					local AutoBreakerRoomHRP = AutoBreakerRoomGetHRP()
					local AutoBreakerRoomCF = AutoBreakerRoomGetObjectCFrame(AutoBreakerRoomBox)

					if AutoBreakerRoomHRP and AutoBreakerRoomCF then
						AutoBreakerRoomHRP.CFrame = AutoBreakerRoomCF
					end

					AutoBreakerRoomActivate(AutoBreakerRoomActivateEventPrompt)
					task.wait(0.04)
				end
			end

			if not AutoBreakerRoomEnabled or not AutoBreakerRoomIsActuallyInRoom100() then
				continue
			end

			task.wait(AutoBreakerRoomWaitAfterLever)

			if not AutoBreakerRoomEnabled or not AutoBreakerRoomIsActuallyInRoom100() then
				continue
			end

			local AutoBreakerRoomElevatorBreakerEmpty = AutoBreakerRoom100:FindFirstChild("ElevatorBreakerEmpty")
			if not AutoBreakerRoomElevatorBreakerEmpty then
				continue
			end

			local AutoBreakerRoomBreakerPrompt = AutoBreakerRoomElevatorBreakerEmpty:FindFirstChild("Prompt")
			if not AutoBreakerRoomBreakerPrompt then
				continue
			end

			local AutoBreakerRoomBreakerOffset = CFrame.new(0, -1.8, 0)

			while AutoBreakerRoomEnabled and AutoBreakerRoomIsActuallyInRoom100() do
				if AutoBreakerRoomElevatorBreakerEmpty:FindFirstChild("BreakerSwitchInBox") then
					break
				end

				local AutoBreakerRoomHRP = AutoBreakerRoomGetHRP()
				local AutoBreakerRoomCF = AutoBreakerRoomGetObjectCFrame(AutoBreakerRoomElevatorBreakerEmpty)

				if AutoBreakerRoomHRP and AutoBreakerRoomCF then
					AutoBreakerRoomHRP.CFrame = AutoBreakerRoomCF * AutoBreakerRoomBreakerOffset
				end

				AutoBreakerRoomActivate(AutoBreakerRoomBreakerPrompt)
				task.wait(0.04)
			end

			if not AutoBreakerRoomEnabled or not AutoBreakerRoomIsActuallyInRoom100() then
				continue
			end

			task.wait(10)

			AutoBreakerRoomConstantTPAndActivate(
				AutoBreakerRoomElevatorBreakerEmpty,
				AutoBreakerRoomBreakerSecondTime,
				0.04,
				AutoBreakerRoomBreakerOffset
			)

			task.wait(AutoBreakerRoomWaitBeforeWeb)

			if not AutoBreakerRoomEnabled or not AutoBreakerRoomIsActuallyInRoom100() then
				continue
			end

			local AutoBreakerRoomElevatorCar = AutoBreakerRoom100:FindFirstChild("ElevatorCar")
			local AutoBreakerRoomWeb = AutoBreakerRoomElevatorCar and AutoBreakerRoomElevatorCar:FindFirstChild("Web", true)

			if AutoBreakerRoomWeb then
				local AutoBreakerRoomEndTime = os.clock() + AutoBreakerRoomWebDuration

				while AutoBreakerRoomEnabled and AutoBreakerRoomIsActuallyInRoom100() and os.clock() < AutoBreakerRoomEndTime do
					local AutoBreakerRoomHRP = AutoBreakerRoomGetHRP()
					local AutoBreakerRoomCF = AutoBreakerRoomGetObjectCFrame(AutoBreakerRoomWeb)

					if AutoBreakerRoomHRP and AutoBreakerRoomCF then
						AutoBreakerRoomHRP.CFrame = AutoBreakerRoomCF
					end

					task.wait(0.04)
				end
			end

			while AutoBreakerRoomEnabled and AutoBreakerRoomIsActuallyInRoom100() do
				task.wait(0.5)
			end
		end
	end)
end)



local AutoHotelConnection
local AutoHotelLibraryConnection
local AutoHotelLibraryRoomConnection
local AutoHotelSeekConnection
local AutoHotelEntityPause = false
local AutoHotelRoomProcessTime = 0.5
local AutoHotelProcessedRooms = {}

local AutoHotelEntityNames = {
	["RushMoving"] = true,
	["Scribbles"] = true,
	["BashMoving"] = true,
	["DronesStampede"] = true,
	["AmbushMoving"] = true,
	["A60"] = true,
	["A120"] = true,
	["GlitchRush"] = true,
	["GlitchAmbush"] = true,
	["BackdoorRush"] = true,
	["CustomEntity"] = true,
}

local function AutoHotelIsEntityPresent()
	if Toggles.AutoHotelIgnoreEntities and Toggles.AutoHotelIgnoreEntities.Value then
		return false
	end
	for _, AutoHotelChild in ipairs(workspace:GetChildren()) do
		if AutoHotelEntityNames[AutoHotelChild.Name] then
			return true
		end
	end
	return false
end

local function AutoHotelWaitForEntities(AutoHotelSeconds)
	if Toggles.AutoHotelIgnoreEntities and Toggles.AutoHotelIgnoreEntities.Value then
		return
	end

	task.wait(AutoHotelSeconds or 5)

	while AutoHotelIsEntityPresent() do
		task.wait(0.15)
	end
end

local function AutoHotelGetNextClosedDoor()
	if not Shared.Character then return nil, nil end

	local AutoHotelGameData = game:GetService("ReplicatedStorage"):FindFirstChild("GameData")
	if not AutoHotelGameData then return nil, nil end

	local AutoHotelLatestRoom = AutoHotelGameData:FindFirstChild("LatestRoom")
	if not AutoHotelLatestRoom then return nil, nil end

	local AutoHotelStartRoom = AutoHotelLatestRoom.Value
	local AutoHotelBestDoor, AutoHotelBestNumber = nil, math.huge
	local AutoHotelCurrentRooms = workspace:FindFirstChild("CurrentRooms")

	if AutoHotelCurrentRooms then
		for _, AutoHotelRoom in ipairs(AutoHotelCurrentRooms:GetChildren()) do
			local AutoHotelRoomNum = tonumber(AutoHotelRoom.Name)
			if AutoHotelRoomNum and AutoHotelRoomNum ~= 100 and AutoHotelRoomNum >= AutoHotelStartRoom and AutoHotelRoomNum < AutoHotelBestNumber then
				local AutoHotelDoor = AutoHotelRoom:FindFirstChild("Door")
				if AutoHotelDoor and AutoHotelDoor:IsA("Model") then
					local AutoHotelOpenAttr = AutoHotelDoor:GetAttribute("Open")
					if AutoHotelOpenAttr == false or AutoHotelOpenAttr == nil then
						AutoHotelBestNumber = AutoHotelRoomNum
						AutoHotelBestDoor = AutoHotelDoor
					end
				end
			end
		end
	end

	return AutoHotelBestDoor, AutoHotelBestNumber
end

local function AutoHotelFindKeyObtain(AutoHotelRoom)
	local AutoHotelFound = nil
	local function AutoHotelScan(AutoHotelParent)
		if AutoHotelFound then return end
		for _, AutoHotelChild in ipairs(AutoHotelParent:GetChildren()) do
			if AutoHotelChild.Name == "KeyObtain" then
				AutoHotelFound = AutoHotelChild
				return
			end
			AutoHotelScan(AutoHotelChild)
			if AutoHotelFound then return end
		end
	end
	AutoHotelScan(AutoHotelRoom)
	return AutoHotelFound
end

local function AutoHotelHandleKey(AutoHotelRoomNum)
	local AutoHotelCurrentRooms = workspace:FindFirstChild("CurrentRooms")
	if not AutoHotelCurrentRooms then return false end

	local AutoHotelRoom = AutoHotelCurrentRooms:FindFirstChild(tostring(AutoHotelRoomNum))
	if not AutoHotelRoom then return false end

	local AutoHotelDoor = AutoHotelRoom:FindFirstChild("Door")
	if not AutoHotelDoor or not AutoHotelDoor:FindFirstChild("Lock") then
		return false
	end

	local AutoHotelKeyObtain = AutoHotelFindKeyObtain(AutoHotelRoom)
	if not AutoHotelKeyObtain then return false end

	local AutoHotelStart = tick()
	while tick() - AutoHotelStart < 12 do
		if LocalPlayer.Backpack:FindFirstChild("Key") or (Shared.Character and Shared.Character:FindFirstChild("Key")) then
			return true
		end

		if Shared.Character then
			Shared.Character:PivotTo(AutoHotelKeyObtain:GetPivot())
		end

		for _, AutoHotelDesc in ipairs(AutoHotelKeyObtain:GetDescendants()) do
			if AutoHotelDesc:IsA("ProximityPrompt") then
				fireproximityprompt(AutoHotelDesc)
			end
		end

		task.wait(0.12)
	end
	return false
end

local function AutoHotelProcessRoom(AutoHotelRoomNum)
	if AutoHotelProcessedRooms[AutoHotelRoomNum] then
		return
	end
	task.wait(AutoHotelRoomProcessTime)
	AutoHotelProcessedRooms[AutoHotelRoomNum] = true
end

local function AutoHotelRunLibrary()
	local AutoHotelCurrentRooms = workspace:WaitForChild("CurrentRooms")
	local AutoHotelRoom50 = AutoHotelCurrentRooms:WaitForChild("50")
	local AutoHotelLiveHintBooks = {}
	local AutoHotelHintPaperObtained = false

	local function AutoHotelIsInRoom50(AutoHotelObj)
		return AutoHotelObj and AutoHotelObj:IsDescendantOf(AutoHotelRoom50)
	end

	local function AutoHotelIsActuallyInRoom50()
		return tonumber(LocalPlayer:GetAttribute("CurrentRoom")) == 50
	end

	while Toggles.AutoHotel.Value and not AutoHotelIsActuallyInRoom50() do
		task.wait(0.1)
	end
	if not Toggles.AutoHotel.Value then return end

	AutoHotelWaitForEntities(5)

	local function AutoHotelHasHintPaper()
		local AutoHotelChar = LocalPlayer.Character
		if not AutoHotelChar then return false end
		return LocalPlayer.Backpack:FindFirstChild("LibraryHintPaper", true) or AutoHotelChar:FindFirstChild("LibraryHintPaper", true)
	end

	local function AutoHotelGetCFrame(AutoHotelObj)
		if not AutoHotelIsActuallyInRoom50() or not AutoHotelIsInRoom50(AutoHotelObj) then return nil end
		if AutoHotelObj:IsA("Model") then return AutoHotelObj:GetPivot() end
		if AutoHotelObj:IsA("BasePart") then return AutoHotelObj.CFrame end
		local AutoHotelPart = AutoHotelObj:FindFirstChildWhichIsA("BasePart", true)
		return AutoHotelPart and AutoHotelPart.CFrame
	end

	local function AutoHotelCollectBooks()
		for _, AutoHotelDesc in ipairs(AutoHotelRoom50:GetDescendants()) do
			if AutoHotelDesc.Name == "LiveHintBook" and AutoHotelIsInRoom50(AutoHotelDesc) and not table.find(AutoHotelLiveHintBooks, AutoHotelDesc) then
				table.insert(AutoHotelLiveHintBooks, AutoHotelDesc)
			end
		end
	end

	AutoHotelCollectBooks()

	AutoHotelLibraryRoomConnection = AutoHotelRoom50.DescendantAdded:Connect(function(AutoHotelAdded)
		if Toggles.AutoHotel.Value and AutoHotelIsActuallyInRoom50() and AutoHotelIsInRoom50(AutoHotelAdded) then
			if AutoHotelAdded.Name == "LiveHintBook" and not table.find(AutoHotelLiveHintBooks, AutoHotelAdded) then
				table.insert(AutoHotelLiveHintBooks, AutoHotelAdded)
			end
		end
	end)

	while Toggles.AutoHotel.Value and AutoHotelIsActuallyInRoom50() and #AutoHotelLiveHintBooks < 3 do
		AutoHotelCollectBooks()
		if #AutoHotelLiveHintBooks >= 3 then break end
		task.wait(0.1)
	end

	while Toggles.AutoHotel.Value and AutoHotelIsActuallyInRoom50() and not AutoHotelHintPaperObtained do
		if AutoHotelHasHintPaper() then
			AutoHotelHintPaperObtained = true
			break
		end

		for AutoHotelIndex = #AutoHotelLiveHintBooks, 1, -1 do
			local AutoHotelBook = AutoHotelLiveHintBooks[AutoHotelIndex]
			if not AutoHotelIsInRoom50(AutoHotelBook) then
				table.remove(AutoHotelLiveHintBooks, AutoHotelIndex)
				continue
			end

			while Toggles.AutoHotel.Value and AutoHotelIsActuallyInRoom50() and not AutoHotelHintPaperObtained and AutoHotelBook.Parent and AutoHotelIsInRoom50(AutoHotelBook) do
				if AutoHotelHasHintPaper() then
					AutoHotelHintPaperObtained = true
					break
				end

				local AutoHotelChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
				local AutoHotelHRP = AutoHotelChar:FindFirstChild("HumanoidRootPart")
				if not AutoHotelHRP then
					task.wait()
					continue
				end

				local AutoHotelCF = AutoHotelGetCFrame(AutoHotelBook)
				if AutoHotelCF then
					AutoHotelHRP.CFrame = AutoHotelCF
				end

				for _, AutoHotelPrompt in ipairs(AutoHotelBook:GetDescendants()) do
					if AutoHotelPrompt:IsA("ProximityPrompt") then
						fireproximityprompt(AutoHotelPrompt)
					end
				end
				task.wait(0.08)
			end
			if AutoHotelHintPaperObtained then break end
		end

		if AutoHotelHasHintPaper() then
			AutoHotelHintPaperObtained = true
			break
		end

		local AutoHotelPaper = AutoHotelRoom50:FindFirstChild("LibraryHintPaper", true)
		if AutoHotelPaper and AutoHotelIsInRoom50(AutoHotelPaper) then
			while Toggles.AutoHotel.Value and AutoHotelIsActuallyInRoom50() and not AutoHotelHintPaperObtained and AutoHotelPaper.Parent do
				if AutoHotelHasHintPaper() then
					AutoHotelHintPaperObtained = true
					break
				end

				local AutoHotelChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
				local AutoHotelHRP = AutoHotelChar:FindFirstChild("HumanoidRootPart")
				if AutoHotelHRP then
					local AutoHotelCF = AutoHotelGetCFrame(AutoHotelPaper)
					if AutoHotelCF then
						AutoHotelHRP.CFrame = AutoHotelCF * CFrame.new(0, 5, 0)
					end
				end

				for _, AutoHotelPrompt in ipairs(AutoHotelPaper:GetDescendants()) do
					if AutoHotelPrompt:IsA("ProximityPrompt") then
						fireproximityprompt(AutoHotelPrompt)
					end
				end
				task.wait(0.08)
			end
		end
		task.wait(0.1)
	end
end

local function AutoHotelHandleSeek()
	local AutoHotelLastTriggerRoom = nil

	while Toggles.AutoHotel.Value do
		local AutoHotelCurrentRooms = workspace:FindFirstChild("CurrentRooms")
		if not AutoHotelCurrentRooms then
			task.wait(0.2)
			continue
		end

		local TriggerRoomNum = nil

		for _, Room in ipairs(AutoHotelCurrentRooms:GetChildren()) do
			local Num = tonumber(Room.Name)
			if Num and Num ~= AutoHotelLastTriggerRoom then
				local Trigger = Room:FindFirstChild("TriggerEventCollision")
					or Room:FindFirstChild("TriggerEventCollision", true)

				if Trigger then
					TriggerRoomNum = Num
					break
				end
			end
		end

		if not TriggerRoomNum then
			task.wait(0.15)
			continue
		end

		AutoHotelLastTriggerRoom = TriggerRoomNum

		AutoHotelEntityPause = true
		AutoHotelWaitForEntities(10)
		AutoHotelEntityPause = false
	end
end

Toggles.AutoHotel:OnChanged(function(AutoHotelEnabled)
	if AutoHotelConnection then
		task.cancel(AutoHotelConnection)
		AutoHotelConnection = nil
	end
	if AutoHotelLibraryConnection then
		task.cancel(AutoHotelLibraryConnection)
		AutoHotelLibraryConnection = nil
	end
	if AutoHotelLibraryRoomConnection then
		AutoHotelLibraryRoomConnection:Disconnect()
		AutoHotelLibraryRoomConnection = nil
	end
	if AutoHotelSeekConnection then
		task.cancel(AutoHotelSeekConnection)
		AutoHotelSeekConnection = nil
	end

	AutoHotelEntityPause = false
	table.clear(AutoHotelProcessedRooms)

	if not AutoHotelEnabled then return end

	if Options.AutoHotelRoomProcess then
		AutoHotelRoomProcessTime = Options.AutoHotelRoomProcess.Value
		Options.AutoHotelRoomProcess:OnChanged(function(Value)
			AutoHotelRoomProcessTime = Value
		end)
	end

	local AutoHotelCurrentRooms = workspace:FindFirstChild("CurrentRooms")
	if AutoHotelCurrentRooms then
		AutoHotelCurrentRooms.ChildAdded:Connect(function(AutoHotelChild)
			local AutoHotelNum = tonumber(AutoHotelChild.Name)
			if AutoHotelNum then
				AutoHotelProcessRoom(AutoHotelNum)
			end
		end)
	end

	AutoHotelSeekConnection = task.spawn(AutoHotelHandleSeek)

	task.spawn(function()
		while Toggles.AutoHotel.Value do
			if AutoHotelIsEntityPresent() then
				AutoHotelEntityPause = true
				while AutoHotelIsEntityPresent() and Toggles.AutoHotel.Value do
					task.wait(0.15)
				end
				AutoHotelEntityPause = false
			end
			task.wait(0.2)
		end
	end)

	AutoHotelConnection = task.spawn(function()
		while Toggles.AutoHotel.Value do
			if AutoHotelEntityPause then
				task.wait(0.1)
				continue
			end

			local AutoHotelDoor, AutoHotelRoomNum = AutoHotelGetNextClosedDoor()

			if AutoHotelDoor and AutoHotelRoomNum and Shared.Character then
				if AutoHotelRoomNum == 50 then
					if not AutoHotelLibraryConnection then
						AutoHotelLibraryConnection = task.spawn(function()
							AutoHotelRunLibrary()
							AutoHotelLibraryConnection = nil
						end)
					end
					task.wait(0.4)
				else
					AutoHotelProcessRoom(AutoHotelRoomNum)
					AutoHotelHandleKey(AutoHotelRoomNum)
					if Shared.Character and not AutoHotelEntityPause then
						Shared.Character:PivotTo(AutoHotelDoor:GetPivot() * CFrame.new(0, -1, 0))
					end
				end
			end
			task.wait(0.15)
		end
	end)
end)



	Tabs.Hotel:UpdateWarningBox({
		Visible = true,
		Title = "Risk Warning",
		Text = "Features highlighted in red are risky.",
	})
end

-- Anti Screech / Halt / Dread and the No Damage toggles with their handlers (moved from the Exploits "Remove" groupbox).
-- Main.luau calls Module.Late(Shared) at the position where this code used to live.
function Module.Late(Shared)
	local FakeEvents, Groupboxes, Toggles
	   = Shared.FakeEvents, Shared.Groupboxes, Shared.Toggles

Groupboxes.Hotel_Anti:AddToggle("RemoveScreech", { Text = "Anti Screech",  Default = false, Tooltip = "Prevents 'Screech' from spawning." })
Groupboxes.Hotel_Anti:AddToggle("RemoveHalt",    { Text = "Anti Halt",     Default = false, Tooltip = "Prevents 'Halt' from spawning." })
Groupboxes.Hotel_Anti:AddToggle("RemoveDread",   { Text = "Anti Dread",    Default = false, Tooltip = "Prevents 'Dread' from spawning." })
Groupboxes.Hotel_NoDamage:AddToggle("NoScreechDamage", { Text = "No Screech Damage", Default = false, Tooltip = "Prevents 'Screech' from hurting you." })
Groupboxes.Hotel_NoDamage:AddToggle("NoHaltDamage",    { Text = "No Halt Damage",    Default = false, Tooltip = "Prevents 'Halt' from hurting you." })

Toggles.NoScreechDamage:OnChanged(function(Value)
	if Value then
		FakeEvents.Screech.Parent = Shared.RemotesFolder
		FakeEvents.Screech_Real.Parent = nil
	else
		FakeEvents.Screech_Real.Parent = Shared.RemotesFolder
		FakeEvents.Screech.Parent = nil
	end
end)
Toggles.NoHaltDamage:OnChanged(function(Value)
	if Value then
		FakeEvents.Shade.Parent = Shared.RemotesFolder
		FakeEvents.Shade_Real.Parent = nil
	else
		FakeEvents.Shade_Real.Parent = Shared.RemotesFolder
		FakeEvents.Shade.Parent = nil
	end
end)

Toggles.RemoveScreech:OnChanged(function(Value)
	if Value then
		task.spawn(function()
			while Toggles.RemoveScreech.Value do
				local Camera = workspace:FindFirstChild("Camera")

				if Camera then
					local Screech = Camera:FindFirstChild("Screech")

					if Screech then
						Screech:Destroy()
					end
				end

				task.wait()
			end
		end)
	end
end)
Toggles.RemoveHalt:OnChanged(function(Value)
	Shared.Modules.Shade.Name = Value and "Shade_Disabled" or "Shade"
end)
Toggles.RemoveDread:OnChanged(function(Value)
	if Shared.Modules.Dread then
		Shared.Modules.Dread.Name = Value and "Dread_Disabled" or "Dread"
	end
end)
end

return Module
