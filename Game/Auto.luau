--[[
    Auto: shared Loot ESP, Loot Notify, Auto Loot and Auto Interact.
    Automation switches and item filters are shared across every Main > Automation page.
]]

local Module = {}

local ItemDefs = {
    {Name="Gold", Names={"GoldPile"}, Category="Currencies", Gold=true},
    {Name="Stardust", Names={"StardustPickup"}, Category="Currencies"},
    {Name="Tip Jar", Names={"TipJar"}, Category="Currencies"},
    {Name="Coin Roll", Names={"CoinRoll"}, Category="Currencies"},

    {Name="Flashlight", Names={"Flashlight"}, Category="Light"},
    {Name="Battery", Names={"Battery"}, Category="Light"},
    {Name="Lighter", Names={"Lighter"}, Category="Light"},
    {Name="Candle", Names={"Candle"}, Category="Light"},
    {Name="Rift Candle", Names={"RiftCandle"}, Category="Light"},
    {Name="Straplight", Names={"Straplight"}, Category="Light"},
    {Name="Glowsticks", Names={"Glowsticks"}, Category="Light"},
    {Name="Bulklight", Names={"Bulklight"}, Category="Light"},
    {Name="Lantern", Names={"Lantern","LanternLitItem"}, Category="Light"},
    {Name="Shakelight", Names={"Shakelight"}, Category="Light"},

    {Name="Bandage", Names={"Bandage"}, Category="Healing"},
    {Name="Aloe Vera", Names={"AloeVera"}, Category="Healing"},
    {Name="Bandage Pack", Names={"BandagePack"}, Category="Healing"},
    {Name="Vitamins", Names={"Vitamins"}, Category="Healing"},

    {Name="Battery Pack", Names={"BatteryPack"}, Category="Utility"},
    {Name="Lockpick", Names={"Lockpick"}, Category="Utility"},
    {Name="Skeleton Key", Names={"SkeletonKey"}, Category="Utility"},
    {Name="Laser Pointer", Names={"LaserPointer"}, Category="Utility"},
    {Name="Shears", Names={"Shears"}, Category="Utility"},
    {Name="Alarm Clock", Names={"AlarmClock","AlarmClockModel"}, Category="Utility"},
    {Name="Rift Jar", Names={"RiftJar"}, Category="Utility"},
    {Name="Multitool", Names={"Multitool"}, Category="Utility"},
    {Name="Compass", Names={"Compass"}, Category="Utility"},
    {Name="Crucifix", Names={"Crucifix","CrucifixWall","CrucifixOnWall"}, Category="Utility"},
    {Name="Pocket Mirror", Names={"PocketMirror"}, Category="Utility"},
    {Name="Scanner", Names={"ObjectScanner","Scanner"}, Category="Utility"},

    {Name="Starlight Vial", Names={"StarVial"}, Category="Edible"},
    {Name="Starlight Bottle", Names={"StarBottle"}, Category="Edible"},
    {Name="Starlight Jug", Names={"StarJug"}, Category="Edible"},
    {Name="Smoothie", Names={"Smoothie"}, Category="Edible"},
    {Name="Donut", Names={"Donut"}, Category="Edible"},
    {Name="Gween Soda", Names={"GweenSoda"}, Category="Edible"},
    {Name="Bread", Names={"Bread"}, Category="Edible"},
    {Name="Cheese", Names={"Cheese"}, Category="Edible"},
    {Name="Rift Smoothie", Names={"RiftSmoothie"}, Category="Edible"},
    {Name="Nanner", Names={"Nanner"}, Category="Edible"},
    {Name="Pizza", Names={"Pizza"}, Category="Edible"},
    {Name="Peach Cobbler", Names={"PeachCobbler"}, Category="Edible"},

    {Name="Gold Blaster", Names={"GoldGun"}, Category="Battle"},
    {Name="Bomb", Names={"Bomb","Knockbomb"}, Category="Battle"},
    {Name="Big Bomb", Names={"BigBomb"}, Category="Battle"},
    {Name="Throwable Prop", Names={"ThrowableProp"}, Category="Battle"},
    {Name="Nanner Peel", Names={"NannerPeel"}, Category="Battle"},
    {Name="Hiding Box", Names={"SnakeBox"}, Category="Battle"},
    {Name="Stop Sign", Names={"StopSign"}, Category="Battle"},
    {Name="Boxing Gloves", Names={"BoxingGloves"}, Category="Battle"},

    {Name="Holy Grenade", Names={"HolyGrenade"}, Category="Events"},

    {Name="Electrical Key", Names={"KeyElectrical","ElectricalKeyObtain"}, Category="Keys"},
    {Name="Skeleton Key", Names={"SkeletonKey"}, Category="Keys"},

    {Name="Iron Key", Names={"KeyIron","IronKey","IronKeyForCrypt"}, Category="Keys"},
    {Name="Garage Key", Names={"KeyGarage","GarageKey"}, Category="Keys"},
    {Name="Jewelry Key", Names={"KeyJewelry"}, Category="Keys"},

    {Name="Translator Drive", Names={"Drive"}, Category="Drives", DriveLabel="TRANSLATOR"},
    {Name="Flashlight Drive", Names={"Drive"}, Category="Drives", DriveLabel="FLASHLIGHT"},
    {Name="Threat Detector Drive", Names={"Drive"}, Category="Drives", DriveLabel="THREAT DETECTOR"},
    {Name="Charles Drive", Names={"Drive"}, Category="Drives", DriveLabel="CHARLES"},

    {Name="Key", Names={"KeyObtain"}, Category="Objectives"},
    {Name="Book", Names={"HintBook","LibraryHintBook","BookHint"}, Category="Objectives"},
    {Name="Paper", Names={"HintPaper","LibraryHintPaper","LibraryHintPaperHard"}, Category="Objectives"},
    {Name="Fuse", Names={"FuseObtain","GeneratorFuse"}, Category="Objectives"},
}

local DefaultColors = {
    Currencies=Color3.fromRGB(255, 210, 70), Light=Color3.fromRGB(255, 245, 130),
    Healing=Color3.fromRGB(100, 255, 135), Utility=Color3.fromRGB(90, 190, 255),
    Edible=Color3.fromRGB(255, 145, 90), Battle=Color3.fromRGB(255, 85, 85),
    Events=Color3.fromRGB(255, 100, 210), Keys=Color3.fromRGB(255, 205, 90),
    Drives=Color3.fromRGB(185, 135, 255), Objectives=Color3.fromRGB(100, 235, 255)
}

local function makeOptions()
    local options, values = {}, {}
    local seen = {}
    local dividers = {}
    for _, def in ipairs(ItemDefs) do
        if not seen[def.Name] then
            if not dividers[def.Category] then
                table.insert(options, {Divider = def.Category})
                dividers[def.Category] = true
            end
            table.insert(options, def.Name)
            seen[def.Name] = true
            local dims = {
                {Type="ColorPicker", Name="ESP Color", Default=DefaultColors[def.Category] or Color3.fromRGB(170, 0, 255)}
            }
            if def.Gold then
                table.insert(dims, {Type="Slider", Name="Min Gold Level", Min=1, Max=6, Step=1, Default=1})
                table.insert(dims, {Type="Slider", Name="Max Gold Level", Min=1, Max=6, Step=1, Default=6})
            end
            values[def.Name] = dims
        end
    end
    return options, values
end

local function getDriveLabel(Object)
    local Label = Object:FindFirstChild("Label", true)
    if not Label then return "" end
    if Label:IsA("TextLabel") or Label:IsA("TextButton") then
        return tostring(Label.ContentText ~= nil and Label.ContentText or Label.Text):upper()
    end
    return ""
end

function Module.Init(Shared)
    local Abysall, Connections, Functions, Groupboxes, LocalPlayer, Options, Services, Toggles
        = Shared.Abysall, Shared.Connections, Shared.Functions, Shared.Groupboxes, Shared.LocalPlayer, Shared.Options, Shared.Services, Shared.Toggles

    local Automation = Groupboxes.Self_Automation
    local ESP = Groupboxes.Main_ESP
    local Notifications = Groupboxes.Main_Notifications
    local ItemOptions, ItemValues = makeOptions()
    local ItemByName = {}
    for _, def in ipairs(ItemDefs) do
        if not ItemByName[def.Name] then ItemByName[def.Name] = def end
    end

    Automation:AddToggle("AutoLootToggle", {
        Text="Auto Loot", Default=false, Pinned=true,
        Tooltip="Automatically picks up selected loot using its proximity prompt."
    })
    Automation:AddValueDropdown("AutoLootList", {
        Text="Auto Loot List", Options=ItemOptions, Values=ItemValues, Multi=true, Pinned=true
    })
    Automation:AddToggle("AutoInteractToggle", {
        Text="Auto Interact", Default=false, Pinned=true,
        Tooltip="Automatically activates selected loot prompts when in range."
    })

    ESP:AddDivider()
    ESP:AddToggle("LootESPToggle", {Text="Loot ESP", Default=false, Tooltip="Highlights selected loot items and currency."})
    local ESPSelection = {}
    ESP:AddValueDropdown("LootESPItems", {
        Text="Loot ESP Items", Options=ItemOptions, Values=ItemValues, Multi=true,
        Callback=function(Value) ESPSelection = Value or {} end
    })

    Notifications:AddDivider()
    Notifications:AddToggle("LootNotifyToggle", {Text="Loot Notify", Default=false, Tooltip="Notifies when selected loot appears."})
    local NotifySelection = {}
    Notifications:AddValueDropdown("LootNotifyItems", {
        Text="Loot Notify Items", Options=ItemOptions, Values=ItemValues, Multi=true,
        Callback=function(Value) NotifySelection = Value or {} end
    })

    local Selected = {}
    for _, def in ipairs(ItemDefs) do
        Selected[def.Name] = Selected[def.Name] or {ESPColor=DefaultColors[def.Category], ESP=false, Loot=false, Interact=false, Notify=false}
    end

    local function isPlayerCharacter(Object)
        local current = Object
        while current and current ~= workspace do
            if current:IsA("Model") and Services.Players:GetPlayerFromCharacter(current) then return true end
            current = current.Parent
        end
        return false
    end

    local function insideNonLootContainer(Object)
        local current = Object.Parent
        while current and current ~= workspace do
            if current.Name == "Backdoor_Wardrobe" or current.Name == "Wardrobe" or current.Name == "Closet" then
                return true
            end
            current = current.Parent
        end
        return false
    end

    local function driveMatches(Object, def)
        if not def.DriveLabel then return true end
        local text = getDriveLabel(Object)
        if def.DriveLabel == "CHARLES" then return text == "CHARLES" end
        return text:find(def.DriveLabel, 1, true) ~= nil
    end

    local function itemPrompt(Object)
        local prompt = Object:FindFirstChild("ModulePrompt", true)
        if prompt and prompt:IsA("ProximityPrompt") then return prompt end
        if Object.Name == "GoldPile" or Object.Name == "StardustPickup" then
            for _, child in ipairs(Object:GetDescendants()) do
                if child:IsA("ProximityPrompt") then return child end
            end
        end
        return nil
    end

    local function isSelected(Value, Name)
        if type(Value) ~= "table" then return Value == Name end
        if Value[Name] ~= nil and Value[Name] ~= false then return true end
        return table.find(Value, Name) ~= nil
    end

    local function isGoldInRange(Object, def)
        if not def.Gold then return true end
        local value = tonumber(Object:GetAttribute("GoldValue")) or 1
        local entry = ESPSelection["Gold"]
        local minGold = entry and type(entry) == "table" and entry["Min Gold Level"] or 1
        local maxGold = entry and type(entry) == "table" and entry["Max Gold Level"] or 6
        return value >= (tonumber(minGold) or 1) and value <= (tonumber(maxGold) or 6)
    end

    local Tracked = {}
    local InteractedPrompts = setmetatable({}, {__mode = "k"})
    local lastScan = 0
    local lastAuto = 0
    local function getItemDef(Object)
        for _, def in ipairs(ItemDefs) do
            for _, name in ipairs(def.Names) do
                if Object.Name == name and driveMatches(Object, def) then
                    return def
                end
            end
        end
        return nil
    end

    local function getLabel(Object, def)
        if def.Gold then return "Gold [" .. tostring(Object:GetAttribute("GoldValue") or "?") .. "]" end
        return def.Name
    end

    local function refreshESP(Object, def, data)
        local selected = ESPSelection[def.Name]
        local wanted = Toggles.LootESPToggle.Value and selected ~= nil and isGoldInRange(Object, def)
        local color = DefaultColors[def.Category] or Color3.fromRGB(170, 0, 255)
        if type(selected) == "table" and selected["ESP Color"] then color = selected["ESP Color"] end
        if wanted and not data.Shown then
            data.Shown = true
            Functions.AddESP({Object=Object, Text=getLabel(Object, def), Color=color}, Object:GetAttribute("ParentRoom") ~= nil)
        elseif wanted and data.Shown then
            pcall(function() Abysall.ESPLibrary:UpdateObjectColor(Object, color) end)
        elseif not wanted and data.Shown then
            data.Shown = false
            Functions.RemoveESP(Object)
        end
    end

    local function scan()
        local candidates = {}
        local roots = {}
        local dropsRoot = workspace:FindFirstChild("Drops")
        local roomsRoot = workspace:FindFirstChild("CurrentRooms")
        if dropsRoot then table.insert(roots, dropsRoot) end
        if roomsRoot then table.insert(roots, roomsRoot) end
        for _, root in ipairs(roots) do
            for _, object in ipairs(root:GetDescendants()) do
                    if object:IsA("Model") or object:IsA("BasePart") then
                        local def = getItemDef(object)
                        if def and not isPlayerCharacter(object) and not insideNonLootContainer(object) then
                            local prompt = itemPrompt(object)
                            if prompt then
                                -- Prefer the outermost canonical item object with a prompt; nested same-name parts are ignored.
                                local parent = object.Parent
                                local nested = false
                                while parent and parent ~= root do
                                    if parent.Name == object.Name and (parent:IsA("Model") or parent:IsA("BasePart")) then nested = true break end
                                    parent = parent.Parent
                                end
                                if not nested then candidates[object] = {Def=def, Prompt=prompt} end
                            end
                        end
                    end
                end
            end
        local workspaceAlarm = workspace:FindFirstChild("AlarmClockModel")
        if workspaceAlarm and not candidates[workspaceAlarm] then
            local def = ItemByName["Alarm Clock"]
            local prompt = itemPrompt(workspaceAlarm)
            if def and prompt then candidates[workspaceAlarm] = {Def=def, Prompt=prompt} end
        end

        for object, data in pairs(Tracked) do
            if not object.Parent or not candidates[object] then
                if data.Shown then Functions.RemoveESP(object) end
                Tracked[object] = nil
            end
        end
        for object, info in pairs(candidates) do
            local data = Tracked[object]
            if not data then
                data = {Def=info.Def, Prompt=info.Prompt, Shown=false, LastNotify=0, LastFire=0}
                Tracked[object] = data
                if Toggles.LootNotifyToggle.Value and NotifySelection[info.Def.Name] then
                    Functions.Notify({Title="Loot found: " .. getLabel(object, info.Def)})
                    data.LastNotify = tick()
                end
            else
                data.Prompt = info.Prompt
            end
            refreshESP(object, info.Def, data)
        end
    end

    local function withinRange(Prompt)
        if not Prompt or not Prompt.Parent or not Prompt.Enabled then return false end
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then return false end
        local part = Prompt.Parent:IsA("BasePart") and Prompt.Parent or Prompt.Parent:FindFirstAncestorWhichIsA("BasePart")
        if not part then
            local model = Prompt.Parent:FindFirstAncestorWhichIsA("Model")
            if model then return (root.Position - model:GetPivot().Position).Magnitude <= Prompt.MaxActivationDistance end
            return false
        end
        return (root.Position - part.Position).Magnitude <= Prompt.MaxActivationDistance
    end

    Connections.AutoLootModule = Services.RunService.Heartbeat:Connect(function()
        if tick() - lastScan >= 0.65 then
            lastScan = tick()
            scan()
        end
        if tick() - lastAuto < 0.12 then return end
        lastAuto = tick()
        if not Toggles.AutoLootToggle.Value and not Toggles.AutoInteractToggle.Value then return end
        local character = LocalPlayer.Character
        if not character or character:GetAttribute("Hiding") == true then return end

        for object, data in pairs(Tracked) do
            local def, prompt = data.Def, data.Prompt
            if not object.Parent or not prompt or not prompt.Parent or not prompt.Enabled then continue end
            if not withinRange(prompt) or tick() - data.LastFire < 0.5 then continue end
            local lootSelected = Toggles.AutoLootToggle.Value and isSelected(Options.AutoLootList.Value, def.Name)
            if not lootSelected then continue end
            if def.Gold and not isGoldInRange(object, def) then continue end
            data.LastFire = tick()
            task.spawn(function()
                if Functions.FirePrompt then
                    Functions.FirePrompt(prompt)
                elseif Abysall.Environment.fireproximityprompt then
                    Abysall.Environment.fireproximityprompt(prompt)
                end
            end)
        end

        -- Auto Interact is global: activate any enabled ProximityPrompt in range, not just loot.
        if Toggles.AutoInteractToggle.Value then
            for _, prompt in ipairs(workspace:GetDescendants()) do
                if not prompt:IsA("ProximityPrompt") or not prompt.Enabled then continue end
                if not withinRange(prompt) then continue end
                local last = InteractedPrompts[prompt] or 0
                if tick() - last < 0.75 then continue end
                InteractedPrompts[prompt] = tick()
                task.spawn(function()
                    if Functions.FirePrompt then
                        Functions.FirePrompt(prompt)
                    elseif Abysall.Environment.fireproximityprompt then
                        Abysall.Environment.fireproximityprompt(prompt)
                    end
                end)
            end
        end
    end)

    Toggles.LootESPToggle:OnChanged(function()
        for object, data in pairs(Tracked) do refreshESP(object, data.Def, data) end
    end)
    Toggles.LootNotifyToggle:OnChanged(function() end)
    Options.LootESPItems:OnChanged(function(Value)
        ESPSelection = Value or {}
        for object, data in pairs(Tracked) do refreshESP(object, data.Def, data) end
    end)
    Options.LootNotifyItems:OnChanged(function(Value) NotifySelection = Value or {} end)

    -- Refresh selected item colors and the enabled list after changing the nested value dropdown.
    local _ = ESPSelection
end

return Module
