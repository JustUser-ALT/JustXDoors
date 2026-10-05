local GameUI = {}

local RunService = game:GetService("RunService")

local Context
local Connections = {}
local InteractTargets = {}
local LootTargets = {}
local InteractCompleted = setmetatable({}, {__mode = "k"})

local InteractEnabled = {
    Drawers = false,
    Chest = false,
    ["Locked Chest"] = false,
    Lever = false,
    Toolshed = false,
    Doors = false,
}

local AutoLootJeffShop = false

local InteractOptions = {
    "Drawers",
    "Chest",
    "Locked Chest",
    "Lever",
    "Toolshed",
    "Doors",
}

local LootOptions = {
    "Key",
    "Gold",
    "Bandage",
    "Smoothie",
    "Flashlight",
    "Tip Jar",
    "Vitamins",
    "Lighter",
    "Candle",
    "AlarmClock",
    "Lockpick",
    "Skeleton Key",
    "Shears",
    "Battery",
    "Rift Candle",
    "Rift Smoothie",
    "Rift Jar",
    "Donut",
    "Crucifix",
    "Sally Toy",
    "Electrical Key",
    "Breaker Pole",
    "Glitch Cube",
    "Library Paper",
    "Library Book",
}

local LootNames = {
    KeyObtain = "Key",
    GoldPile = "Gold",
    Bandage = "Bandage",
    Smoothie = "Smoothie",
    Flashlight = "Flashlight",
    TipJar = "Tip Jar",
    Vitamins = "Vitamins",
    Lighter = "Lighter",
    Candle = "Candle",
    AlarmClock = "AlarmClock",
    Lockpick = "Lockpick",
    SkeletonKey = "Skeleton Key",
    Shears = "Shears",
    Battery = "Battery",
    RiftCandle = "Rift Candle",
    RiftSmoothie = "Rift Smoothie",
    RiftJar = "Rift Jar",
    Donut = "Donut",
    Crucifix = "Crucifix",
    SallyToyObtain = "Sally Toy",
    ElectricalKeyObtain = "Electrical Key",
    LiveBreakerPolePickup = "Breaker Pole",
    GlitchCube = "Glitch Cube",
    LibraryHintPaper = "Library Paper",
    LiveHintBook = "Library Book",
}

local LootSelection = {}

local function disconnectAll()
    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(Connections)
end

local function clearTargets()
    table.clear(InteractTargets)
    table.clear(LootTargets)
end

local function getRooms()
    return workspace:FindFirstChild("CurrentRooms")
end

local function findRoom(object, rooms)
    local current = object

    while current and current ~= rooms do
        if current.Parent == rooms then
            return current
        end
        current = current.Parent
    end

    return nil
end

local function isJeffShop(object, room)
    local current = object

    while current and current ~= room do
        if current.Name == "RiftRoom_JeffShop" then
            return true
        end
        current = current.Parent
    end

    return false
end

local function getPrompt(container, names)
    if not container then
        return nil
    end

    names = names or {"ActivateEventPrompt"}

    for _, name in ipairs(names) do
        local direct = container:FindFirstChild(name)
        if direct and direct:IsA("ProximityPrompt") then
            return direct
        end
    end

    for _, descendant in ipairs(container:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") then
            for _, name in ipairs(names) do
                if descendant.Name == name then
                    return descendant
                end
            end
        end
    end

    return nil
end

local function getPromptPosition(prompt)
    if not prompt or not prompt.Parent then
        return nil
    end

    local parent = prompt.Parent
    if parent:IsA("Attachment") then
        return parent.WorldPosition
    end
    if parent:IsA("BasePart") then
        return parent.Position
    end

    local part = parent:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

local function isPromptInRange(prompt)
    local character = game:GetService("Players").LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local position = getPromptPosition(prompt)

    if not root or not position then
        return false
    end

    local maxDistance = tonumber(prompt.MaxActivationDistance) or 10
    return (root.Position - position).Magnitude <= maxDistance
end

local function hasLootHolder(container)
    return container and container:FindFirstChild("LootHolder", true) ~= nil
end

local function firePrompt(prompt)
    if not prompt or not prompt.Parent or not prompt:IsA("ProximityPrompt") then
        return false
    end

    local fire = fireproximityprompt
    if type(fire) ~= "function" then
        return false
    end

    -- Do not force a disabled prompt back on. DOORS uses Enabled=false
    -- while an interaction is being processed; forcing it back on makes
    -- Auto Interact repeatedly fire the same prompt and can block manual
    -- interaction on mobile.
    if not prompt.Enabled then
        return false
    end

    local ok = pcall(function()
        fire(prompt)
    end)

    return ok
end

local function registerDrawerContainer(drawerContainer, room)
    if not drawerContainer or not drawerContainer.Parent then
        return
    end

    local prompt = getPrompt(drawerContainer, {"ActivateEventPrompt"})
    if not prompt then
        return
    end

    if InteractCompleted[drawerContainer] then
        return
    end

    InteractTargets[drawerContainer] = {
        Kind = "Drawers",
        Container = drawerContainer,
        Room = room,
        Prompt = prompt,
        LastFire = 0,
        Waiting = false,
        InitialInteractions = prompt:GetAttribute("Interactions"),
        HadLootHolder = hasLootHolder(drawerContainer),
    }
end

local function registerFurniture(object, room)
    if not object or not object.Parent then
        return
    end

    local name = object.Name

    -- Dresser, Table, Dresser_Single and Rolltop_Desk are one Auto Interact
    -- category. Register every DrawerContainer/RolltopContainer separately.
    if name ~= "Dresser"
        and name ~= "Dresser_Single"
        and name ~= "Table"
        and name ~= "Rolltop_Desk"
    then
        return
    end

    for _, descendant in ipairs(object:GetDescendants()) do
        if descendant.Name == "DrawerContainer"
            or descendant.Name == "RolltopContainer"
        then
            registerDrawerContainer(descendant, room)
        end
    end
end

local function registerChest(object, room)
    if not object or not object.Parent then
        return
    end

    local kind

    if object.Name == "ChestBox" then
        kind = "Chest"
    elseif object.Name == "LockedChestBox" or object.Name == "ChestBoxLocked" then
        kind = "Locked Chest"
    else
        return
    end

    if not InteractEnabled[kind] then
        return
    end

    local prompt = getPrompt(object, {"ActivateEventPrompt"})
    if prompt and not InteractCompleted[object] then
        InteractTargets[object] = {
            Kind = kind,
            Container = object,
            Room = room,
            Prompt = prompt,
            LastFire = 0,
            Waiting = false,
            InitialInteractions = prompt:GetAttribute("Interactions"),
            HadLootHolder = hasLootHolder(object),
        }
    end
end

local function registerInteractObject(object, room)
    if not object then
        return
    end

    if object.Name == "Dresser"
        or object.Name == "Dresser_Single"
        or object.Name == "Table"
        or object.Name == "Rolltop_Desk"
    then
        if InteractEnabled.Drawers then
            registerFurniture(object, room)
        end
        return
    end

    if object.Name == "DrawerContainer"
        or object.Name == "RolltopContainer"
    then
        if InteractEnabled.Drawers then
            registerDrawerContainer(object, room)
        end
        return
    end

    if object.Name == "ChestBox"
        or object.Name == "LockedChestBox"
        or object.Name == "ChestBoxLocked"
    then
        registerChest(object, room)
        return
    end

    if object.Name == "LeverForGate" and InteractEnabled.Lever then
        local prompt = getPrompt(object, {"ActivateEventPrompt"})
        if prompt and not InteractCompleted[object] then
            InteractTargets[object] = {
                Kind = "Lever",
                Container = object,
                Room = room,
                Prompt = prompt,
                LastFire = 0,
                Waiting = false,
                InitialInteractions = prompt:GetAttribute("Interactions"),
                HadLootHolder = hasLootHolder(object),
            }
        end
        return
    end

    if object.Name == "Door" and InteractEnabled.Doors then
        local lock = object:FindFirstChild("Lock")
        local prompt = lock and lock:FindFirstChild("UnlockPrompt")
        if prompt and prompt:IsA("ProximityPrompt") and not InteractCompleted[object] then
            InteractTargets[object] = {
                Kind = "Doors",
                Container = object,
                Room = room,
                Prompt = prompt,
                LastFire = 0,
                Waiting = false,
                InitialInteractions = prompt:GetAttribute("Interactions"),
                HadLootHolder = false,
            }
        end
        return
    end

    if (object.Name == "Toolshed_Small" or object.Name == "Small_Toolshed")
        and InteractEnabled.Toolshed
    then
        local prompt = getPrompt(object, {"ActivateEventPrompt"})
        if prompt and not InteractCompleted[object] then
            InteractTargets[object] = {
                Kind = "Toolshed",
                Container = object,
                Room = room,
                Prompt = prompt,
                LastFire = 0,
                Waiting = false,
                InitialInteractions = prompt:GetAttribute("Interactions"),
                HadLootHolder = hasLootHolder(object),
            }
        end
    end
end

local function scanInteractRooms()
    local rooms = getRooms()
    if not rooms then
        return
    end

    for _, room in ipairs(rooms:GetChildren()) do
        if tonumber(room.Name) then
            for _, object in ipairs(room:GetDescendants()) do
                registerInteractObject(object, room)
            end
        end
    end
end

local function cleanupInteractTargets()
    for object, data in pairs(InteractTargets) do
        local container = data.Container

        if not container
            or not container.Parent
            or not data.Room
            or not data.Room.Parent
            or not container:IsDescendantOf(data.Room)
        then
            InteractTargets[object] = nil
        end
    end
end

local function processInteractTargets()
    local now = os.clock()
    local bestObject, bestData, bestDistance = nil, nil, math.huge

    -- Process exactly one interaction at a time. This prevents two nearby
    -- DrawerContainers/Dressers from competing and leaving one unopened.
    for object, data in pairs(InteractTargets) do
        local container = data.Container
        if not container or not container.Parent or not data.Room or not data.Room.Parent
            or not container:IsDescendantOf(data.Room)
        then
            InteractTargets[object] = nil
            continue
        end

        if not InteractEnabled[data.Kind] or InteractCompleted[container] then
            InteractTargets[object] = nil
            continue
        end

        local interactions = data.Prompt and data.Prompt:GetAttribute("Interactions")
        if data.InitialInteractions ~= nil
            and interactions ~= nil
            and interactions ~= data.InitialInteractions
        then
            InteractCompleted[container] = true
            InteractTargets[object] = nil
            continue
        end

        if not data.HadLootHolder and hasLootHolder(container) then
            InteractCompleted[container] = true
            InteractTargets[object] = nil
            continue
        end

        local prompt = data.Prompt
        if not prompt or not prompt.Parent then
            prompt = getPrompt(container, {"ActivateEventPrompt"})
            data.Prompt = prompt
        end

        if prompt then
            local position = getPromptPosition(prompt)
            local root = game:GetService("Players").LocalPlayer.Character
                and game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if position and root then
                local distance = (root.Position - position).Magnitude
                local maxDistance = tonumber(prompt.MaxActivationDistance) or 10
                if distance <= maxDistance and distance < bestDistance then
                    bestObject, bestData, bestDistance = object, data, distance
                end
            end
        end
    end

    if not bestObject or not bestData then
        return
    end

    local prompt = bestData.Prompt
    if not prompt or not prompt.Parent then
        return
    end

    -- Some Doors prompts become disabled while their interaction is being
    -- processed. Re-enable only the single selected target, never all prompts.
    if not prompt.Enabled then
        if now - bestData.LastFire >= 0.35 then
            pcall(function() prompt.Enabled = true end)
        end
        return
    end

    if now - bestData.LastFire < 0.35 then
        return
    end

    if firePrompt(prompt) then
        bestData.LastFire = now
        bestData.Waiting = true
        InteractCompleted[bestData.Container] = true
        InteractTargets[bestObject] = nil
    end
end

local function findLootPrompt(object)
    if not object or not object.Parent then
        return nil
    end

    if object.Name == "GoldPile" then
        return getPrompt(object, {"ModulePrompt", "ActivateEventPrompt"})
    end

    if object.Name == "LiveHintBook" then
        return getPrompt(object, {"ActivateEventPrompt"})
    end

    if object.Name == "LibraryHintPaper" then
        return getPrompt(object, {"ModulePrompt"})
    end

    return getPrompt(object, {"ModulePrompt"})
end

local function registerLootObject(object, room)
    if not object or not object.Parent then
        return
    end

    local label = LootNames[object.Name]
    if not label or not LootSelection[label] then
        return
    end

    if room and isJeffShop(object, room) and not AutoLootJeffShop then
        return
    end

    -- Tip Jar is never an Auto Loot target inside Jeff's Shop.
    if room and isJeffShop(object, room) and object.Name == "TipJar" then
        return
    end

    if object.Name == "LiveHintBook" and (not room or room.Name ~= "50") then
        return
    end

    if object.Name == "LibraryHintPaper" and (not room or room.Name ~= "50") then
        return
    end

    local prompt = findLootPrompt(object)
    if not prompt then
        return
    end

    LootTargets[prompt] = {
        Item = object,
        Kind = label,
        Room = room,
        LastFire = 0,
    }
end

local function registerDropRoot(object)
    if not object then
        return
    end

    local drops = workspace:FindFirstChild("Drops")
    if not drops then
        return
    end

    local root = object
    while root.Parent and root.Parent ~= drops do
        root = root.Parent
    end

    if root.Parent == drops then
        registerLootObject(root, nil)
    end
end

local function scanLootRooms()
    local rooms = getRooms()
    if not rooms then
        return
    end

    for _, room in ipairs(rooms:GetChildren()) do
        if tonumber(room.Name) then
            for _, object in ipairs(room:GetDescendants()) do
                registerLootObject(object, room)
            end
        end
    end

    local drops = workspace:FindFirstChild("Drops")
    if drops then
        for _, object in ipairs(drops:GetChildren()) do
            registerLootObject(object, nil)
        end
    end
end

local function cleanupLootTargets()
    for prompt, data in pairs(LootTargets) do
        local item = data.Item

        if not prompt
            or not prompt.Parent
            or not item
            or not item.Parent
        then
            LootTargets[prompt] = nil
        elseif data.Room
            and (not data.Room.Parent or not item:IsDescendantOf(data.Room))
        then
            LootTargets[prompt] = nil
        elseif data.Room and isJeffShop(item, data.Room) and not AutoLootJeffShop then
            LootTargets[prompt] = nil
        elseif data.Room and isJeffShop(item, data.Room) and item.Name == "TipJar" then
            LootTargets[prompt] = nil
        end
    end
end

local function processLootTargets()
    local now = os.clock()
    local bestPrompt, bestData, bestDistance = nil, nil, math.huge

    -- Auto Loot also uses the real prompt range and one target at a time.
    -- This removes the old room-wide prompt spam.
    for prompt, data in pairs(LootTargets) do
        local item = data.Item

        if not item or not item.Parent or not prompt or not prompt.Parent then
            LootTargets[prompt] = nil
            continue
        end

        if not LootSelection[data.Kind] then
            LootTargets[prompt] = nil
            continue
        end

        if data.Room and isJeffShop(item, data.Room) then
            if not AutoLootJeffShop or item.Name == "TipJar" then
                LootTargets[prompt] = nil
                continue
            end
        end

        local position = getPromptPosition(prompt)
        local character = game:GetService("Players").LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if position and root and prompt.Enabled then
            local distance = (root.Position - position).Magnitude
            local maxDistance = tonumber(prompt.MaxActivationDistance) or 10
            if distance <= maxDistance and distance < bestDistance then
                bestPrompt, bestData, bestDistance = prompt, data, distance
            end
        end
    end

    if not bestPrompt or not bestData or now - bestData.LastFire < 0.5 then
        return
    end

    if firePrompt(bestPrompt) then
        bestData.LastFire = now
    end
end

local function applySelection(selected)
    local state = {}

    if type(selected) == "table" then
        if #selected > 0 then
            for _, value in ipairs(selected) do
                state[value] = true
            end
        else
            for value, enabled in pairs(selected) do
                if enabled == true then
                    state[value] = true
                end
            end
        end
    elseif type(selected) == "string" then
        state[selected] = true
    end

    return state
end

local function setInteractSelection(selected)
    local state = applySelection(selected)

    for _, option in ipairs(InteractOptions) do
        InteractEnabled[option] = state[option] == true
    end

    table.clear(InteractTargets)
    scanInteractRooms()
end

local function setLootSelection(selected)
    LootSelection = applySelection(selected)

    table.clear(LootTargets)
    scanLootRooms()
end

function GameUI:Create(ctx)
    Context = ctx

    if not ctx.Tab then
        ctx.Tab = ctx.Core:Tab({
            Name = "Hotel",
            Icon = "building-2",
            Type = "Grid",
        })
    end
    if not ctx.Tab then return false end

    local pages = ctx.GamePages
    if not pages then
        pages = ctx.Tab:MultiSection({
            Pages = {"Main", "Settings"},
            Column = 1,
            Icon = "joystick",
        })
        ctx.GamePages = pages
    end
    if not pages then return false end

    local main = pages:Page("Main")
    local settings = pages:Page("Settings")
    if not main or not settings then return false end

    ctx.Elements.AutoInteract = main:ValueDropdown({
        Name = "Auto Interact",
        Flag = "Hotel_AutoInteract",
        Options = InteractOptions,
        MultiSelect = true,
        MaxSelect = #InteractOptions,
        Default = {},
        Search = true,
        Callback = function(selected)
            setInteractSelection(selected)
        end,
    })

    ctx.Elements.AutoLoot = main:ValueDropdown({
        Name = "Auto Loot",
        Flag = "Hotel_AutoLoot",
        Options = LootOptions,
        MultiSelect = true,
        MaxSelect = #LootOptions,
        Default = {},
        Search = true,
        Callback = function(selected)
            setLootSelection(selected)
        end,
    })

    ctx.Elements.AutoLootJeffShop = settings:Toggle({
        Name = "Auto Loot JeffShop",
        Flag = "Hotel_AutoLootJeffShop",
        Default = false,
        Callback = function(value)
            AutoLootJeffShop = value == true
            table.clear(LootTargets)
            scanLootRooms()
        end,
    })

    settings:Label({
        Text = "Auto Interact uses the real prompt range and processes one target at a time.\nAuto Loot only fires prompts inside their real range.\nTip Jar is always excluded from Jeff's Shop.",
    })

    disconnectAll()
    clearTargets()

    local rooms = getRooms()

    if rooms then
        table.insert(Connections, rooms.DescendantAdded:Connect(function(object)
            local room = findRoom(object, rooms)
            if not room then return end

            registerInteractObject(object, room)
            registerLootObject(object, room)

            if object:IsA("ProximityPrompt") then
                local current = object.Parent
                for _ = 1, 8 do
                    if not current or current == room then break end
                    registerInteractObject(current, room)
                    registerLootObject(current, room)
                    current = current.Parent
                end
            end
        end))

        table.insert(Connections, rooms.DescendantRemoving:Connect(function(object)
            InteractTargets[object] = nil

            for prompt, data in pairs(LootTargets) do
                if data.Item == object then
                    LootTargets[prompt] = nil
                end
            end
        end))

        table.insert(Connections, rooms.ChildAdded:Connect(function(room)
            if room and room.Parent == rooms then
                task.defer(function()
                    if room.Parent == rooms then
                        for _, object in ipairs(room:GetDescendants()) do
                            registerInteractObject(object, room)
                            registerLootObject(object, room)
                        end
                    end
                end)
            end
        end))
    end

    table.insert(Connections, workspace.ChildAdded:Connect(function(object)
        if object.Name == "CurrentRooms" then
            task.defer(function()
                if object.Parent == workspace then
                    clearTargets()
                    scanInteractRooms()
                    scanLootRooms()
                end
            end)
        elseif object.Name == "Drops" then
            task.defer(function()
                if object.Parent == workspace then
                    for _, drop in ipairs(object:GetChildren()) do
                        registerDropRoot(drop)
                    end
                end
            end)
        end
    end))

    local drops = workspace:FindFirstChild("Drops")
    if drops then
        table.insert(Connections, drops.ChildAdded:Connect(function(object)
            task.defer(function()
                if object.Parent == drops then
                    registerDropRoot(object)
                end
            end)
        end))
    end

    table.insert(Connections, RunService.Heartbeat:Connect(function(dt)
        GameUI._Elapsed = (GameUI._Elapsed or 0) + dt

        if GameUI._Elapsed >= 0.10 then
            GameUI._Elapsed = 0
            cleanupInteractTargets()
            processInteractTargets()
            cleanupLootTargets()
            processLootTargets()
        end
    end))

    return true
end

function GameUI:ReapplyEnabledFeatures()
    local interact = Context and Context.Elements and Context.Elements.AutoInteract
    if interact and type(interact.Get) == "function" then
        local ok, selected = pcall(function()
            return interact:Get()
        end)

        if ok then
            setInteractSelection(selected)
        end
    end

    local loot = Context and Context.Elements and Context.Elements.AutoLoot
    if loot and type(loot.Get) == "function" then
        local ok, selected = pcall(function()
            return loot:Get()
        end)

        if ok then
            setLootSelection(selected)
        end
    end

    local jeff = Context and Context.Elements and Context.Elements.AutoLootJeffShop
    if jeff and type(jeff.Get) == "function" then
        local ok, value = pcall(function()
            return jeff:Get()
        end)
        if ok then
            AutoLootJeffShop = value == true
            table.clear(LootTargets)
            scanLootRooms()
        end
    end
end

function GameUI:Destroy()
    disconnectAll()
    clearTargets()
    GameUI._Elapsed = 0
    Context = nil
    table.clear(LootSelection)
    table.clear(InteractCompleted)

    for _, option in ipairs(InteractOptions) do
        InteractEnabled[option] = false
    end
    AutoLootJeffShop = false
end

return GameUI
