local Module = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Connections = {}
local RoomConnections = {}

local Context
local Enabled = {}
local Colors = {}
local Display = {Name = true, Distance = false}

local Rooms
local Drops
local VisualContainer

local Objects = {}
local ScanQueued = false
local ScanClock = 0
local LabelClock = 0

local MAX_DISTANCE = 300

local KINDS = {
    "Doors","Drawers","Closets","Key","Gold","Chest","Bandage","Smoothie",
    "Flashlight","TipJar","Vitamins","Lighter","Candle","AlarmClock",
    "Lockpick","SkeletonKey","Shears","RiftCandle","RiftSmoothie","RiftJar",
    "Donut","Crucifix","SallyToy","ElectricalKey","BreakerPole","Battery",
    "Dupe","Eyes","SallyLingering","SallyMoving","Seek","Figure","Snare",
    "Screech","VentGate","Toolshed","Lever","Rush","Ambush"
}

for _, kind in ipairs(KINDS) do
    Objects[kind] = {}
end

local ITEM_KINDS = {
    Key=true, Gold=true, Bandage=true, Smoothie=true, Flashlight=true,
    TipJar=true, Vitamins=true, Lighter=true, Candle=true, AlarmClock=true,
    Lockpick=true, SkeletonKey=true, Shears=true, RiftCandle=true,
    RiftSmoothie=true, RiftJar=true, Donut=true, Crucifix=true,
    SallyToy=true, ElectricalKey=true, BreakerPole=true, Battery=true,
}

local ENTITY_KINDS = {
    Rush=true, Ambush=true, Dupe=true, Eyes=true, SallyLingering=true,
    SallyMoving=true, Seek=true, Figure=true, Snare=true, Screech=true,
}

local INTERACTABLE_KINDS = {
    Doors=true, Drawers=true, Closets=true, Chest=true,
    VentGate=true, Lever=true, Toolshed=true, LockedChest=true,
}

local DEFAULT_COLORS = {
    Doors=Color3.fromRGB(0,200,255),
    Drawers=Color3.fromRGB(255,170,70),
    Closets=Color3.fromRGB(125,75,45),
    Toolshed=Color3.fromRGB(180,110,55),
    Chest=Color3.fromRGB(255,165,0),
    VentGate=Color3.fromRGB(125,190,255),
    Lever=Color3.fromRGB(255,150,40),

    Key=Color3.fromRGB(255,225,40),
    Gold=Color3.fromRGB(255,215,0),
    Bandage=Color3.fromRGB(95,255,120),
    Smoothie=Color3.fromRGB(255,105,180),
    Flashlight=Color3.fromRGB(220,245,255),
    TipJar=Color3.fromRGB(90,220,190),
    Vitamins=Color3.fromRGB(135,255,75),
    Lighter=Color3.fromRGB(255,155,60),
    Candle=Color3.fromRGB(255,240,175),
    AlarmClock=Color3.fromRGB(120,190,255),
    Lockpick=Color3.fromRGB(180,100,255),
    SkeletonKey=Color3.fromRGB(210,175,255),
    Shears=Color3.fromRGB(195,210,220),
    Battery=Color3.fromRGB(110,255,150),
    RiftCandle=Color3.fromRGB(255,85,210),
    RiftSmoothie=Color3.fromRGB(255,70,135),
    RiftJar=Color3.fromRGB(190,80,255),
    Donut=Color3.fromRGB(255,140,195),
    Crucifix=Color3.fromRGB(240,240,255),
    SallyToy=Color3.fromRGB(255,120,230),
    ElectricalKey=Color3.fromRGB(70,235,255),
    BreakerPole=Color3.fromRGB(255,135,45),

    Rush=Color3.fromRGB(255,60,60),
    Ambush=Color3.fromRGB(205,45,45),
    Dupe=Color3.fromRGB(255,140,40),
    Eyes=Color3.fromRGB(120,235,255),
    SallyLingering=Color3.fromRGB(255,105,210),
    SallyMoving=Color3.fromRGB(255,70,175),
    Seek=Color3.fromRGB(190,90,255),
    Figure=Color3.fromRGB(190,190,210),
    Snare=Color3.fromRGB(110,255,110),
    Screech=Color3.fromRGB(255,235,90),
}

local LABEL_NAMES = {
    Doors="Door", Drawers="Drawer", Closets="Closet", Key="Key", Gold="Gold",
    Chest="Chest", Bandage="Bandage", Smoothie="Smoothie", Flashlight="Flashlight",
    TipJar="Tip Jar", Vitamins="Vitamins", Lighter="Lighter", Candle="Candle",
    AlarmClock="Alarm Clock", Lockpick="Lockpick", SkeletonKey="Skeleton Key",
    Shears="Shears", RiftCandle="Rift Candle", RiftSmoothie="Rift Smoothie",
    RiftJar="Rift Jar", Donut="Donut", Crucifix="Crucifix", SallyToy="Sally Toy",
    ElectricalKey="Electrical Key", BreakerPole="Breaker Pole", Battery="Battery",
    Dupe="Dupe", Eyes="Eyes", SallyLingering="Sally", SallyMoving="Sally",
    Seek="Seek", Figure="Figure", Snare="Snare", Screech="Screech",
    VentGate="Vent Gate", Toolshed="Toolshed", Lever="Lever",
    Rush="Rush", Ambush="Ambush",
}

local function connect(signal, callback)
    local ok, connection = pcall(function()
        return signal:Connect(callback)
    end)
    if ok and connection then
        table.insert(Connections, connection)
        return connection
    end
end

local function disconnectAll()
    for _, connection in ipairs(Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(Connections)

    for _, list in pairs(RoomConnections) do
        for _, connection in ipairs(list) do
            pcall(function() connection:Disconnect() end)
        end
    end
    table.clear(RoomConnections)
end

local function getRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getRooms()
    return workspace:FindFirstChild("CurrentRooms")
end

local function getPart(object)
    if not object then return nil end
    if object:IsA("BasePart") then return object end

    if object:IsA("Model") then
        if object.PrimaryPart and object.PrimaryPart:IsA("BasePart") then
            return object.PrimaryPart
        end

        for _, name in ipairs({"Handle","Main","Root","HumanoidRootPart","RushNew","Key","Mesh"}) do
            local part = object:FindFirstChild(name, true)
            if part and part:IsA("BasePart") then
                return part
            end
        end
    end

    return object:FindFirstChildWhichIsA("BasePart", true)
end

local function getEntityPart(kind, object)
    if not object then return nil end

    local names = {
        Rush={"RushNew"},
        Ambush={"RushNew","AmbushNew"},
        Dupe={"DoorFake"},
        Eyes={"Eyes"},
        SallyLingering={"Sally"},
        SallyMoving={"Sally"},
        Seek={"Seek"},
        Figure={"HumanoidRootPart"},
        Snare={"Snare"},
        Screech={"Screech"},
    }

    for _, name in ipairs(names[kind] or {}) do
        local part = object:FindFirstChild(name, true)
        if part and part:IsA("BasePart") then return part end
    end

    return getPart(object)
end

local function getRoom(object)
    if not object or not Rooms then return nil end

    local current = object
    while current and current ~= workspace do
        if current.Parent == Rooms and tonumber(current.Name) then
            return current
        end
        current = current.Parent
    end

    return nil
end

local function isInventoryObject(object)
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack and object:IsDescendantOf(backpack) then return true end

    local character = LocalPlayer.Character
    if character and object:IsDescendantOf(character) then
        return object:FindFirstAncestorWhichIsA("Tool") ~= nil
    end

    return false
end

local function roomVisible(kind, room)
    if not room then return true end

    local current = tonumber(LocalPlayer:GetAttribute("CurrentRoom"))
    local number = tonumber(room.Name)
    if not current or not number then return true end

    if kind == "Doors" then
        return number == current or number == current + 1
    end

    if ITEM_KINDS[kind] then
        return number >= current - 1 and number <= current + 1
    end

    return number == current
end

local function getDoorNumber(room)
    local door = room and room:FindFirstChild("Door")
    local sign = door and door:FindFirstChild("Sign")
    local stinker = sign and sign:FindFirstChild("Stinker")

    if stinker then
        local ok, value = pcall(function() return stinker.Text end)
        if ok and type(value) == "string" then
            local number = tonumber(value:match("%d+"))
            if number then return string.format("%04d", number) end
        end
    end

    local number = room and tonumber(room.Name)
    return number and string.format("%04d", number + 1) or "????"
end

local function labelName(kind, object)
    if kind == "Doors" then
        local roomNumber = object:GetAttribute("JustXDoorsRoom")
        local room = Rooms and Rooms:FindFirstChild(tostring(roomNumber))
        return "Door • " .. getDoorNumber(room)
    end

    return LABEL_NAMES[kind] or kind
end

local function destroyEntryVisual(entry)
    if entry.Highlight then
        pcall(function() entry.Highlight:Destroy() end)
        entry.Highlight = nil
    end

    if entry.Highlights then
        for _, highlight in ipairs(entry.Highlights) do
            pcall(function() highlight:Destroy() end)
        end
        entry.Highlights = nil
    end

    if entry.Box then
        pcall(function() entry.Box:Destroy() end)
        entry.Box = nil
    end

    if entry.Label then
        pcall(function() entry.Label:Destroy() end)
        entry.Label = nil
    end
end

local function updateLabel(kind, object, entry)
    if not Display.Name and not Display.Distance then
        if entry.Label then entry.Label.Enabled = false end
        return
    end

    local part = ENTITY_KINDS[kind] and getEntityPart(kind, object) or getPart(object)
    if not part then return end

    local label = entry.Label
    if not label or not label.Parent then
        label = Instance.new("BillboardGui")
        label.Name = "JustXDoorsESPLabel"
        label.AlwaysOnTop = true
        label.LightInfluence = 0
        label.MaxDistance = 1500
        label.Size = UDim2.fromOffset(190, 26)
        label.StudsOffset = Vector3.new(0, 2.5, 0)
        label.Adornee = part
        label.Parent = VisualContainer
        entry.Label = label

        local text = Instance.new("TextLabel")
        text.Name = "Text"
        text.BackgroundTransparency = 1
        text.Size = UDim2.fromScale(1, 1)
        text.Font = Enum.Font.GothamBold
        text.TextSize = 13
        text.TextStrokeTransparency = 0.35
        text.TextColor3 = Colors[kind] or Color3.new(1,1,1)
        text.Parent = label
    else
        label.Adornee = part
    end

    local text = label:FindFirstChild("Text")
    if not text then return end

    local values = {}
    if Display.Name then values[#values + 1] = labelName(kind, object) end

    if Display.Distance then
        local root = getRoot()
        if root then
            values[#values + 1] = tostring(math.floor(
                (root.Position - part.Position).Magnitude + 0.5
            ))
        end
    end

    text.Text = table.concat(values, " • ")
    text.TextColor3 = Colors[kind] or Color3.new(1,1,1)
    label.Enabled = true
end

local function makeHighlight(kind, adornee, entry, fillTransparency)
    if not adornee then return false end

    local highlight = Instance.new("Highlight")
    highlight.Name = "JustXDoorsESP"
    highlight.Adornee = adornee
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Colors[kind] or Color3.new(1,1,1)
    highlight.OutlineColor = Colors[kind] or Color3.new(1,1,1)
    highlight.FillTransparency = fillTransparency
    highlight.OutlineTransparency = 0
    highlight.Parent = VisualContainer

    entry.Highlight = highlight
    return true
end

local function createVisual(kind, object, entry)
    if not object or not object.Parent then return false end

    if kind == "Doors" then
        debugDoorStructure(object)
    end

    if entry.Highlight and entry.Highlight.Parent then
        updateLabel(kind, object, entry)
        return true
    end

    if entry.Highlights then
        local valid = false
        for _, h in ipairs(entry.Highlights) do
            if h and h.Parent then valid = true break end
        end
        if valid then
            updateLabel(kind, object, entry)
            return true
        end
    end

    local color = Colors[kind] or Color3.new(1,1,1)

    if kind == "Doors" then
        -- IMPORTANT:
        -- The outer Door model contains helper geometry such as:
        --   Hidden     -> large helper volume (causes the giant rectangle)
        --   Collision  -> collision volume
        --   Hinge      -> transparent helper
        --
        -- The actual visible door is the BasePart named "Door" inside
        -- the outer Door model. Highlight that real door first, then add
        -- only its smaller visible decorative pieces.
        local visualDoor = object:IsA("Model") and object:FindFirstChild("Door")
        local parts = {}

        if visualDoor and visualDoor:IsA("BasePart") then
            table.insert(parts, visualDoor)

            for _, child in ipairs(visualDoor:GetDescendants()) do
                if child:IsA("BasePart")
                    and child.Transparency < 1
                    and child.Name ~= "Hidden"
                    and child.Name ~= "Collision"
                    and child.Name ~= "Hinge"
                then
                    local size = child.Size
                    local volume = size.X * size.Y * size.Z

                    -- Ignore another room-sized helper, but keep real
                    -- door details such as Plate / Knob / Sign / CrossBoards.
                    if math.max(size.X, size.Y, size.Z) <= 8
                        and volume <= 350
                    then
                        table.insert(parts, child)
                    end
                end
            end
        else
            -- Fallback for floors/variants where Door itself is a Part.
            local fallback = getPart(object)
            if fallback and fallback:IsA("BasePart") then
                table.insert(parts, fallback)
            end
        end

        if #parts == 0 then return false end

        entry.Highlights = {}
        for _, part in ipairs(parts) do
            local highlight = Instance.new("Highlight")
            highlight.Name = "JustXDoorsDoorESP"
            highlight.Adornee = part
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillColor = color
            highlight.OutlineColor = color
            highlight.FillTransparency = 1
            highlight.OutlineTransparency = 0
            highlight.Parent = VisualContainer
            table.insert(entry.Highlights, highlight)
        end

        updateLabel(kind, object, entry)
        return true
    end

    if ENTITY_KINDS[kind] then
        local target = getEntityPart(kind, object)
        if not target then return false end

        -- Prefer the actual entity/model. No transparent Humanoid proxy is
        -- created, avoiding the large FPS cost seen with the old workaround.
        local adornee = object:IsA("Model") and object or target
        makeHighlight(kind, adornee, entry, 0.65)
        updateLabel(kind, object, entry)
        return true
    end

    -- One Highlight per complete item/interactable, including Drops.
    makeHighlight(kind, object, entry, ITEM_KINDS[kind] and 0.55 or 1)
    updateLabel(kind, object, entry)
    return true
end

local function clearEntry(kind, object)
    local entry = Objects[kind] and Objects[kind][object]
    if not entry then return end

    destroyEntryVisual(entry)
    Objects[kind][object] = nil
end

local function addObject(kind, object, room)
    if not Enabled[kind] or not object or not object.Parent then return end

    if not ENTITY_KINDS[kind] and not ITEM_KINDS[kind]
        and not roomVisible(kind, room)
    then
        return
    end

    if ITEM_KINDS[kind] and isInventoryObject(object) then
        return
    end

    local part = ENTITY_KINDS[kind] and getEntityPart(kind, object) or getPart(object)
    local root = getRoot()

    if part and root and (root.Position - part.Position).Magnitude > MAX_DISTANCE then
        clearEntry(kind, object)
        return
    end

    local entry = Objects[kind][object]
    if not entry then
        entry = {Room = room}
        Objects[kind][object] = entry
    elseif room then
        entry.Room = room
    end

    if kind == "Doors" and room then
        object:SetAttribute("JustXDoorsRoom", tonumber(room.Name))
    end

    createVisual(kind, object, entry)
end

local function clearKind(kind)
    local copy = {}
    for object in pairs(Objects[kind]) do
        copy[#copy + 1] = object
    end
    for _, object in ipairs(copy) do
        clearEntry(kind, object)
    end
end

local function reconcile(kind, seen)
    for object, entry in pairs(Objects[kind]) do
        if not object.Parent or not seen[object] then
            if entry.Room and Rooms and object:IsDescendantOf(Rooms) then
                -- Room objects are only removed when they are no longer
                -- present/visible in the current reconciliation.
                clearEntry(kind, object)
            elseif entry.Room == nil then
                if not Drops or not object:IsDescendantOf(Drops) then
                    clearEntry(kind, object)
                end
            elseif not object:IsDescendantOf(workspace) then
                clearEntry(kind, object)
            end
        end
    end
end

local function findItemRoot(object, room)
    local root = object
    local parent = object.Parent

    while parent and parent ~= room do
        if parent.Name == object.Name then
            root = parent
        end
        parent = parent.Parent
    end

    return root
end

local function scanRoom(room, seen)
    if not room or not room.Parent or not tonumber(room.Name) then return end

    -- Use the complete room Door container for discovery. The visual
    -- filter below keeps the real upper/middle/lower door geometry while
    -- rejecting room-sized helper parts.
    local door = room:FindFirstChild("Door")

    if Enabled.Doors and door and roomVisible("Doors", room) then
        seen.Doors[door] = true
        addObject("Doors", door, room)
    end

    for _, object in ipairs(room:GetDescendants()) do
        local name = object.Name

        if Enabled.Drawers and (name == "Dresser" or name == "Table" or name == "Rolltop_Desk") then
            if name == "Rolltop_Desk" or object:FindFirstChild("DrawerContainer", true) then
                seen.Drawers[object] = true
                addObject("Drawers", object, room)
            end
        end

        if Enabled.Closets and (name == "Wardrobe" or name == "Toolshed") then
            seen.Closets[object] = true
            addObject("Closets", object, room)
        end

        if Enabled.Toolshed and name == "Toolshed_Small" then
            seen.Toolshed[object] = true
            addObject("Toolshed", object, room)
        end

        if Enabled.Chest and (name == "ChestBox" or name == "ChestBoxLocked") then
            seen.Chest[object] = true
            addObject("Chest", object, room)
        end

        if Enabled.Key and name == "KeyObtain"
            and object:FindFirstChild("ModulePrompt", true)
        then
            seen.Key[object] = true
            addObject("Key", object, room)
        end

        if Enabled.Gold and name == "GoldPile" then
            local foundLevel = false
            for _, child in ipairs(object:GetChildren()) do
                local level = tonumber(child.Name)
                if level and level >= (Module.GoldLevel or 1)
                    and (child:IsA("Model") or child:IsA("BasePart"))
                then
                    foundLevel = true
                    seen.Gold[child] = true
                    addObject("Gold", child, room)
                end
            end

            -- Some versions expose GoldPile itself as the visible object.
            if not foundLevel then
                seen.Gold[object] = true
                addObject("Gold", object, room)
            end
        end

        if Enabled.Bandage and name == "Bandage" then
            seen.Bandage[object] = true
            addObject("Bandage", object, room)
        end

        if Enabled.Smoothie and name == "Smoothie" then
            seen.Smoothie[object] = true
            addObject("Smoothie", object, room)
        end

        local special = {
            Vitamins="Vitamins", Lighter="Lighter", Candle="Candle",
            AlarmClock="AlarmClock", Lockpick="Lockpick", SkeletonKey="SkeletonKey",
            Shears="Shears", RiftCandle="RiftCandle", RiftSmoothie="RiftSmoothie",
            RiftJar="RiftJar", Donut="Donut", Crucifix="Crucifix",
        }

        local kind = special[name]
        if kind and Enabled[kind]
            and findItemRoot(object, room) == object
            and object:FindFirstChild("ModulePrompt", true)
        then
            seen[kind][object] = true
            addObject(kind, object, room)
        end

        if Enabled.VentGate and name == "VentGrate" then
            seen.VentGate[object] = true
            addObject("VentGate", object, room)
        end

        if Enabled.Lever and name == "LeverForGate" then
            seen.Lever[object] = true
            addObject("Lever", object, room)
        end

        if Enabled.BreakerPole and name == "LiveBreakerPolePickup" then
            seen.BreakerPole[object] = true
            addObject("BreakerPole", object, room)
        end

        if Enabled.SallyToy and name == "SallyToyObtain" and room.Name == "28" then
            seen.SallyToy[object] = true
            addObject("SallyToy", object, room)
        end

        if Enabled.ElectricalKey and name == "ElectricalKeyObtain" and room.Name == "100" then
            seen.ElectricalKey[object] = true
            addObject("ElectricalKey", object, room)
        end
    end

    if Enabled.Crucifix and room.Name == "1" then
        local wall = room:FindFirstChild("CrucifixWall", true)
        if wall then
            seen.Crucifix[wall] = true
            addObject("Crucifix", wall, room)
        end
    end
end

local function scanDrops(seen)
    if not Drops then return end

    local map = {
        Vitamins="Vitamins", Lighter="Lighter", Candle="Candle",
        AlarmClock="AlarmClock", Lockpick="Lockpick", SkeletonKey="SkeletonKey",
        Shears="Shears", Battery="Battery", Bandage="Bandage",
        Smoothie="Smoothie", Flashlight="Flashlight", TipJar="TipJar",
        RiftCandle="RiftCandle", RiftSmoothie="RiftSmoothie", RiftJar="RiftJar",
        Donut="Donut", Crucifix="Crucifix",
    }

    for _, object in ipairs(Drops:GetDescendants()) do
        local kind = map[object.Name]

        if kind and Enabled[kind] then
            -- Use the complete dropped model when possible. This prevents the
            -- ESP from vanishing when a Drop creates/reparents its internals.
            local root = object
            while root.Parent and root.Parent ~= Drops do
                if root.Parent:IsA("Model") then
                    root = root.Parent
                else
                    break
                end
            end

            seen[kind][root] = true
            addObject(kind, root, nil)
        end
    end
end

local function scanEntities(seen)
    local globals = {
        RushMoving="Rush", AmbushMoving="Ambush",
        Eyes="Eyes", SallyLingering="SallyLingering",
        SallyMoving="SallyMoving",
    }

    for name, kind in pairs(globals) do
        if Enabled[kind] then
            local object = workspace:FindFirstChild(name)
            if object then
                seen[kind][object] = true
                addObject(kind, object, nil)
            end
        end
    end

    if Enabled.Screech then
        local camera = workspace:FindFirstChild("Camera")
        local object = camera and camera:FindFirstChild("Screech")
        if object then
            seen.Screech[object] = true
            addObject("Screech", object, nil)
        end
    end

    if Rooms then
        for _, room in ipairs(Rooms:GetChildren()) do
            if Enabled.Dupe then
                local object = room:FindFirstChild("SideroomDupe", true)
                if object then
                    seen.Dupe[object] = true
                    addObject("Dupe", object, room)
                end
            end

            if Enabled.Seek then
                local object = room:FindFirstChild("SeekMovingNewClone", true)
                if object then
                    seen.Seek[object] = true
                    addObject("Seek", object, room)
                end
            end

            if Enabled.Figure then
                local object = room:FindFirstChild("FigureRig", true)
                if object then
                    seen.Figure[object] = true
                    addObject("Figure", object, room)
                end
            end

            if Enabled.Snare then
                local object = room:FindFirstChild("Snare", true)
                if object then
                    seen.Snare[object] = true
                    addObject("Snare", object, room)
                end
            end
        end
    end
end

local function newSeen()
    local seen = {}
    for _, kind in ipairs(KINDS) do
        seen[kind] = {}
    end
    return seen
end

local function scanAll()
    Rooms = getRooms()
    Drops = workspace:FindFirstChild("Drops")

    local seen = newSeen()

    if Rooms then
        for _, room in ipairs(Rooms:GetChildren()) do
            scanRoom(room, seen)
        end
    end

    scanDrops(seen)
    scanEntities(seen)

    for _, kind in ipairs(KINDS) do
        if Enabled[kind] then
            reconcile(kind, seen[kind])
        else
            clearKind(kind)
        end
    end

    ScanQueued = false
end

local function queueScan()
    ScanQueued = true
end

local function applySelection(selected)
    local state = {}

    if type(selected) == "table" then
        if #selected > 0 then
            for _, value in ipairs(selected) do state[value] = true end
        else
            for value, enabled in pairs(selected) do
                if enabled == true then state[value] = true end
            end
        end
    elseif type(selected) == "string" then
        state[selected] = true
    end

    return state
end

local function applyInteractables(selected)
    local state = applySelection(selected)

    local map = {
        Doors="Doors", Drawers="Drawers", Closets="Closets",
        Chest="Chest", LockedChest="LockedChest",
        ["Vent Gate"]="VentGate", Lever="Lever", Toolshed="Toolshed",
    }

    if state.All then
        for _, kind in pairs(map) do state[kind] = true end
    end

    for label, kind in pairs(map) do
        Enabled[kind] = state[label] == true or state[kind] == true
    end

    queueScan()
end

local function applyItems(selected)
    local state = applySelection(selected)

    local map = {
        Key="Key", Gold="Gold", Bandage="Bandage", Smoothie="Smoothie",
        Flashlight="Flashlight", ["Tip Jar"]="TipJar", Vitamins="Vitamins",
        Lighter="Lighter", Candle="Candle", AlarmClock="AlarmClock",
        Lockpick="Lockpick", ["Skeleton Key"]="SkeletonKey", Shears="Shears",
        Battery="Battery", ["Rift Candle"]="RiftCandle",
        ["Rift Smoothie"]="RiftSmoothie", ["Rift Jar"]="RiftJar",
        Donut="Donut", Crucifix="Crucifix", ["Sally Toy"]="SallyToy",
        ["Electrical Key"]="ElectricalKey", ["Breaker Pole"]="BreakerPole",
    }

    for label, kind in pairs(map) do
        Enabled[kind] = state[label] == true or state[kind] == true
    end

    if type(selected) == "table" and selected.Gold ~= nil then
        Module.GoldLevel = tonumber(selected.Gold) or 1
    elseif state.Gold then
        Module.GoldLevel = Module.GoldLevel or 1
    end

    queueScan()
end

local function setEntities(selected)
    local state = applySelection(selected)

    Enabled.Rush = state.Rush == true
    Enabled.Ambush = state.Ambush == true
    Enabled.Dupe = state.Dupe == true
    Enabled.Eyes = state.Eyes == true
    Enabled.SallyLingering = state.Sally == true or state.SallyLingering == true
    Enabled.SallyMoving = state.Sally == true or state.SallyMoving == true
    Enabled.Seek = state.Seek == true
    Enabled.Figure = state.Figure == true
    Enabled.Snare = state.Snare == true
    Enabled.Screech = state.Screech == true

    queueScan()
end

local function refreshLabels()
    for kind, objects in pairs(Objects) do
        for object, entry in pairs(objects) do
            if object.Parent then
                updateLabel(kind, object, entry)
            else
                clearEntry(kind, object)
            end
        end
    end
end

local function hookRoom(room)
    if not room or not room.Parent or RoomConnections[room] then return end

    local list = {}
    RoomConnections[room] = list

    local function onChange()
        queueScan()
    end

    table.insert(list, room.DescendantAdded:Connect(onChange))
    table.insert(list, room.DescendantRemoving:Connect(onChange))
    table.insert(list, room.AncestryChanged:Connect(function(_, parent)
        if not parent then
            RoomConnections[room] = nil
            queueScan()
        end
    end))
end

local function hookRooms(container)
    Rooms = container

    for room, list in pairs(RoomConnections) do
        for _, connection in ipairs(list) do
            pcall(function() connection:Disconnect() end)
        end
        RoomConnections[room] = nil
    end

    if not container then return end

    connect(container.ChildAdded, function(room)
        hookRoom(room)
        queueScan()
    end)

    connect(container.ChildRemoved, function()
        queueScan()
    end)

    for _, room in ipairs(container:GetChildren()) do
        hookRoom(room)
    end

    queueScan()
end

local function hookDrops(container)
    Drops = container
    if not container then return end

    connect(container.ChildAdded, function()
        queueScan()
    end)

    connect(container.ChildRemoved, function()
        queueScan()
    end)

    -- A Drop can build its model after the root is replicated.
    connect(container.DescendantAdded, function()
        queueScan()
    end)

    connect(container.DescendantRemoving, function()
        queueScan()
    end)

    queueScan()
end

local function setup()
    if VisualContainer then
        pcall(function() VisualContainer:Destroy() end)
    end

    VisualContainer = Instance.new("Folder")
    VisualContainer.Name = "JustXDoors_HotelESP"
    VisualContainer.Parent = workspace

    Rooms = getRooms()
    Drops = workspace:FindFirstChild("Drops")

    hookRooms(Rooms)
    if Drops then hookDrops(Drops) end

    connect(workspace.ChildAdded, function(object)
        if object.Name == "CurrentRooms" then
            hookRooms(object)
        elseif object.Name == "Drops" then
            hookDrops(object)
        else
            queueScan()
        end
    end)

    connect(workspace.ChildRemoved, function(object)
        if object == Rooms or object == Drops then
            queueScan()
        end
    end)

    connect(LocalPlayer:GetAttributeChangedSignal("CurrentRoom"), function()
        queueScan()
    end)

    connect(LocalPlayer.CharacterAdded, function()
        queueScan()
    end)

    connect(RunService.Heartbeat, function(dt)
        ScanClock += dt
        LabelClock += dt

        -- Reconciliation is deliberately slow and centralized. Object-added
        -- events only queue a scan; they never create hundreds of Highlights.
        if ScanQueued and ScanClock >= 0.10 then
            ScanClock = 0
            scanAll()
        elseif ScanClock >= 0.50 then
            ScanClock = 0
            scanAll()
        end

        if LabelClock >= 0.05 then
            LabelClock = 0
            if Display.Distance then
                refreshLabels()
            end
        end
    end)

    queueScan()
end

function Module:Init(context)
    Module:Destroy()

    Context = context or {}
    Enabled = Context.Enabled or {}
    Colors = Context.Colors or {}
    Display = Context.Display or {Name=true, Distance=false}

    for _, kind in ipairs(KINDS) do
        if Colors[kind] == nil then
            Colors[kind] = DEFAULT_COLORS[kind] or Color3.new(1,1,1)
        end
    end

    Module.GoldLevel = Module.GoldLevel or 1

    setup()

    Module.Enabled = Enabled
    Module.Colors = Colors
    Module.Display = Display
    Module.Objects = Objects

    return Module
end

function Module:ApplyInteractables(selected)
    applyInteractables(selected)
end

function Module:ApplyItems(selected)
    applyItems(selected)
end

function Module:SetEntities(selected)
    setEntities(selected)
end

function Module:RefreshLabels()
    refreshLabels()
end

function Module:ScanAll()
    queueScan()
    scanAll()
end

function Module:Destroy()
    disconnectAll()

    for _, kind in ipairs(KINDS) do
        clearKind(kind)
    end

    if VisualContainer then
        pcall(function() VisualContainer:Destroy() end)
        VisualContainer = nil
    end

    Rooms = nil
    Drops = nil
    ScanQueued = false
end

return Module
