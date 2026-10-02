local Module = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Connections = {}
local RoomConnections = {}
local DropConnections = {}

local Context
local Enabled = {}
local Colors = {}
local Display = {Name = true, Distance = false}

local Objects = {}
local PendingRooms = {}
local PendingDrops = false
local ScanRequested = false
local ScanClock = 0
local LabelClock = 0
local Rooms
local Drops
local VisualContainer
local RoomsContainerConnection

-- Hotel ESP visibility limit. Objects beyond this distance are removed
-- from the ESP registry instead of continuing to display stale labels.
local MAX_ESP_DISTANCE = 300

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

local INTERACTABLES = {
    Doors=true, Drawers=true, Closets=true, Chest=true, VentGate=true,
    Lever=true, Toolshed=true, LockedChest=true,
}

local ENTITY_KINDS = {
    Rush=true, Ambush=true, Dupe=true, Eyes=true, SallyLingering=true,
    SallyMoving=true, Seek=true, Figure=true, Snare=true, Screech=true,
}

local ITEM_KINDS = {
    Key=true, Gold=true, Bandage=true, Smoothie=true, Flashlight=true,
    TipJar=true, Vitamins=true, Lighter=true, Candle=true, AlarmClock=true,
    Lockpick=true, SkeletonKey=true, Shears=true, RiftCandle=true,
    RiftSmoothie=true, RiftJar=true, Donut=true, Crucifix=true,
    SallyToy=true, ElectricalKey=true, BreakerPole=true, Battery=true,
}

local DEFAULT_COLORS = {
    Doors = Color3.fromRGB(0, 200, 255),
    Drawers = Color3.fromRGB(255, 170, 70),
    Closets = Color3.fromRGB(125, 75, 45),
    Toolshed = Color3.fromRGB(180, 110, 55),
    Chest = Color3.fromRGB(255, 165, 0),
    VentGate = Color3.fromRGB(125, 190, 255),
    Lever = Color3.fromRGB(255, 150, 40),

    Key = Color3.fromRGB(255, 225, 40),
    Gold = Color3.fromRGB(255, 215, 0),
    Bandage = Color3.fromRGB(95, 255, 120),
    Smoothie = Color3.fromRGB(255, 105, 180),
    Flashlight = Color3.fromRGB(220, 245, 255),
    TipJar = Color3.fromRGB(90, 220, 190),
    Vitamins = Color3.fromRGB(135, 255, 75),
    Lighter = Color3.fromRGB(255, 155, 60),
    Candle = Color3.fromRGB(255, 240, 175),
    AlarmClock = Color3.fromRGB(120, 190, 255),
    Lockpick = Color3.fromRGB(180, 100, 255),
    SkeletonKey = Color3.fromRGB(210, 175, 255),
    Shears = Color3.fromRGB(195, 210, 220),
    Battery = Color3.fromRGB(110, 255, 150),
    RiftCandle = Color3.fromRGB(255, 85, 210),
    RiftSmoothie = Color3.fromRGB(255, 70, 135),
    RiftJar = Color3.fromRGB(190, 80, 255),
    Donut = Color3.fromRGB(255, 140, 195),
    Crucifix = Color3.fromRGB(240, 240, 255),
    SallyToy = Color3.fromRGB(255, 120, 230),
    ElectricalKey = Color3.fromRGB(70, 235, 255),
    BreakerPole = Color3.fromRGB(255, 135, 45),

    Rush = Color3.fromRGB(255, 60, 60),
    Ambush = Color3.fromRGB(205, 45, 45),
    Dupe = Color3.fromRGB(255, 140, 40),
    Eyes = Color3.fromRGB(120, 235, 255),
    SallyLingering = Color3.fromRGB(255, 105, 210),
    SallyMoving = Color3.fromRGB(255, 70, 175),
    Seek = Color3.fromRGB(190, 90, 255),
    Figure = Color3.fromRGB(190, 190, 210),
    Snare = Color3.fromRGB(110, 255, 110),
    Screech = Color3.fromRGB(255, 235, 90),
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

local function disconnect(connection)
    if connection then
        pcall(function() connection:Disconnect() end)
    end
end

local function disconnectList(list)
    for _, connection in ipairs(list) do
        disconnect(connection)
    end
    table.clear(list)
end

local function getRooms()
    return workspace:FindFirstChild("CurrentRooms")
end

local function getRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isInventoryObject(object)
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack and object:IsDescendantOf(backpack) then
        return true
    end

    -- Some DOORS items can temporarily become descendants of the character
    -- while the interaction/hold state is being created. Do not remove their
    -- ESP just because the player walked close to them.
    local character = LocalPlayer.Character
    if character and object:IsDescendantOf(character) then
        return object:FindFirstAncestorWhichIsA("Tool") ~= nil
    end

    return false
end

local function getPart(object)
    if not object then return nil end

    if object:IsA("BasePart") then
        return object
    end

    if object:IsA("Model") then
        local primary = object.PrimaryPart
        if primary and primary:IsA("BasePart") then
            return primary
        end

        for _, name in ipairs({"Handle","Main","Root","Hitbox","Key","Mesh","RushNew"}) do
            local part = object:FindFirstChild(name, true)
            if part and part:IsA("BasePart") then
                return part
            end
        end
    end

    return object:FindFirstChildWhichIsA("BasePart", true)
end

local function getRoom(object)
    if not object then return nil end

    local room = object:FindFirstAncestorWhichIsA("Model")
    while room and room.Parent ~= Rooms do
        room = room.Parent and room:FindFirstAncestorWhichIsA("Model")
    end

    if room and Rooms and room.Parent == Rooms and tonumber(room.Name) then
        return room
    end

    local current = object
    while current and current ~= workspace do
        if current.Parent == Rooms and tonumber(current.Name) then
            return current
        end
        current = current.Parent
    end

    return nil
end

local function roomVisible(kind, room)
    if not room then return true end

    local current = tonumber(LocalPlayer:GetAttribute("CurrentRoom"))
    local number = tonumber(room.Name)
    if not current or not number then return true end

    if kind == "Doors" then
        return number == current or number == current + 1
    end

    -- Items persist across previous/current/next rooms.
    if ITEM_KINDS[kind] then
        return number >= current - 1 and number <= current + 1
    end

    return number == current
end

local function doorNumber(room)
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
    local names = {
        Doors="Door", Drawers="Drawer", Closets="Closet", Key="Key",
        Gold="Gold", Chest="Chest", Bandage="Bandage", Smoothie="Smoothie",
        Flashlight="Flashlight", TipJar="Tip Jar", Vitamins="Vitamins",
        Lighter="Lighter", Candle="Candle", AlarmClock="Alarm Clock",
        Lockpick="Lockpick", SkeletonKey="Skeleton Key", Shears="Shears",
        RiftCandle="Rift Candle", RiftSmoothie="Rift Smoothie", RiftJar="Rift Jar",
        Donut="Donut", Crucifix="Crucifix", SallyToy="Sally Toy",
        ElectricalKey="Electrical Key", BreakerPole="Breaker Pole",
        Battery="Battery", Dupe="Dupe", Eyes="Eyes", SallyLingering="Sally",
        SallyMoving="Sally", Seek="Seek", Figure="Figure", Snare="Snare",
        Screech="Screech", VentGate="Vent Gate", Toolshed="Toolshed",
        Lever="Lever", Rush="Rush", Ambush="Ambush"
    }

    if kind == "Doors" then
        local room = object:GetAttribute("JustXDoorsRoom")
        local roomObject = Rooms and Rooms:FindFirstChild(tostring(room))
        return "Door • " .. doorNumber(roomObject)
    end

    return names[kind] or kind
end

local function isIgnoredVisualPart(part)
    if not part or not part:IsA("BasePart") then return true end
    local name = part.Name:lower()
    return part.Transparency >= 1
        or name:find("hitbox", 1, true)
        or name:find("collision", 1, true)
        or name:find("trigger", 1, true)
        or name == "humanoidrootpart"
end

local function getVisualParts(object)
    if not object then return {} end
    if object:IsA("BasePart") then
        return isIgnoredVisualPart(object) and {} or {object}
    end
    if not object:IsA("Model") then return {} end

    local result = {}
    for _, part in ipairs(object:GetDescendants()) do
        if part:IsA("BasePart") and not isIgnoredVisualPart(part) then
            table.insert(result, part)
        end
    end
    return result
end

local function getTargetPart(kind, object)
    if not object then return nil end
    if object:IsA("BasePart") then return object end
    if object:IsA("Model") and object.PrimaryPart then return object.PrimaryPart end
    return object:FindFirstChildWhichIsA("BasePart", true)
end

local function getEntityPart(kind, object)
    if not object then return nil end

    local preferred = {
        Rush = {"RushNew"},
        Ambush = {"RushNew", "AmbushNew"},
        Dupe = {"DoorFake"},
        Seek = {"Seek"},
        Figure = {"HumanoidRootPart", "FigureRagdoll"},
        Eyes = {"Eyes"},
        SallyLingering = {"Sally"},
        SallyMoving = {"Sally"},
        Snare = {"Snare"},
        Screech = {"Screech"},
    }

    local names = preferred[kind]
    if names then
        for _, name in ipairs(names) do
            local part = object:FindFirstChild(name, true)
            if part and part:IsA("BasePart") then
                return part
            end
        end
    end

    return getTargetPart(kind, object)
end

local function calculateBounds(parts)
    if #parts == 0 then return nil end

    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge

    for _, part in ipairs(parts) do
        local cf = part.CFrame
        local half = part.Size * 0.5

        for _, sx in ipairs({-1, 1}) do
            for _, sy in ipairs({-1, 1}) do
                for _, sz in ipairs({-1, 1}) do
                    local p = cf:PointToWorldSpace(Vector3.new(
                        half.X * sx, half.Y * sy, half.Z * sz
                    ))
                    minX = math.min(minX, p.X)
                    minY = math.min(minY, p.Y)
                    minZ = math.min(minZ, p.Z)
                    maxX = math.max(maxX, p.X)
                    maxY = math.max(maxY, p.Y)
                    maxZ = math.max(maxZ, p.Z)
                end
            end
        end
    end

    local min = Vector3.new(minX, minY, minZ)
    local max = Vector3.new(maxX, maxY, maxZ)
    return (min + max) * 0.5, max - min
end

local function updateBoxEntry(entry, object, entity)
    if not entry.BoxProxy or not entry.BoxProxy.Parent then return end

    local center, size
    if entity then
        if object:IsA("Model") then
            local ok, cf, s = pcall(function()
                return object:GetBoundingBox()
            end)
            if ok and cf and s then
                center, size = cf.Position, s
                entry.BoxProxy.CFrame = cf
            end
        elseif object:IsA("BasePart") then
            center, size = object.Position, object.Size
            entry.BoxProxy.CFrame = object.CFrame
        end
    else
        center, size = calculateBounds(getVisualParts(object))
        if center and size then
            entry.BoxProxy.CFrame = CFrame.new(center)
        end
    end

    if center and size then
        entry.BoxProxy.Size = size
        entry.Box.CFrame = CFrame.new()
        if entry.Box:IsA("WireframeHandleAdornment") then
            addWireCubeLines(entry.Box, size)
        end
    end
end

local function updateLabel(kind, object, entry)
    local part = ENTITY_KINDS[kind] and getEntityPart(kind, object)
        or getTargetPart(kind, object)
    if not part then return end

    if not Display.Name and not Display.Distance then
        if entry.Label then entry.Label.Enabled = false end
        return
    end

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

    label.Enabled = true

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
end

local function addWireCubeLines(wire, size)
    local h = size * 0.5
    local p = {
        Vector3.new(-h.X, -h.Y, -h.Z), Vector3.new(h.X, -h.Y, -h.Z),
        Vector3.new(h.X, h.Y, -h.Z), Vector3.new(-h.X, h.Y, -h.Z),
        Vector3.new(-h.X, -h.Y, h.Z), Vector3.new(h.X, -h.Y, h.Z),
        Vector3.new(h.X, h.Y, h.Z), Vector3.new(-h.X, h.Y, h.Z),
    }

    wire:Clear()
    wire:AddLines({
        p[1],p[2], p[2],p[3], p[3],p[4], p[4],p[1],
        p[5],p[6], p[6],p[7], p[7],p[8], p[8],p[5],
        p[1],p[5], p[2],p[6], p[3],p[7], p[4],p[8],
    })
end

local function createBox(entry, color)
    local proxy = Instance.new("Part")
    proxy.Name = "JustXDoorsESPProxy"
    proxy.Anchored = true
    proxy.CanCollide = false
    proxy.CanTouch = false
    proxy.CanQuery = false
    proxy.CastShadow = false
    proxy.Transparency = 1
    proxy.Size = Vector3.one
    proxy.Parent = VisualContainer

    local box = Instance.new("WireframeHandleAdornment")
    box.Name = "JustXDoorsESPBox"
    box.Adornee = proxy
    box.AlwaysOnTop = true
    box.Thickness = 2
    box.Color3 = color
    box.Transparency = 0
    box.Parent = proxy
    addWireCubeLines(box, Vector3.one)

    entry.BoxProxy = proxy
    entry.Box = box
end

local function destroyVisual(entry)
    if entry.Highlight then
        pcall(function() entry.Highlight:Destroy() end)
        entry.Highlight = nil
    end
    if entry.Box then
        pcall(function() entry.Box:Destroy() end)
        entry.Box = nil
    end
    if entry.BoxProxy then
        pcall(function() entry.BoxProxy:Destroy() end)
        entry.BoxProxy = nil
    end
    if entry.Label then
        pcall(function() entry.Label:Destroy() end)
        entry.Label = nil
    end
end

local function createVisual(kind, object, entry)
    if not object or not object.Parent then return false end

    if entry.Highlight and entry.Highlight.Parent then
        updateLabel(kind, object, entry)
        return true
    end

    if entry.Box and entry.Box.Parent then
        updateBoxEntry(entry, object, ENTITY_KINDS[kind] == true)
        updateLabel(kind, object, entry)
        return true
    end

    local color = Colors[kind] or Color3.new(1,1,1)

    if kind == "Doors" then
        createBox(entry, color)
        updateBoxEntry(entry, object, false)
        updateLabel(kind, object, entry)
        return true
    end

    if ENTITY_KINDS[kind] then
        local target = getEntityPart(kind, object)

        if target and target.Transparency <= 0.01 then
            local highlight = Instance.new("Highlight")
            highlight.Name = "JustXDoorsEntityESP"
            highlight.Adornee = target
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillColor = color
            highlight.OutlineColor = color
            highlight.FillTransparency = 0.65
            highlight.OutlineTransparency = 0
            highlight.Parent = VisualContainer
            entry.Highlight = highlight
        elseif target then
            local wire = Instance.new("WireframeHandleAdornment")
            wire.Name = "JustXDoorsEntityESP"
            wire.Adornee = target
            wire.AlwaysOnTop = true
            wire.Thickness = 2
            wire.Color3 = color
            wire.Transparency = 0
            addWireCubeLines(wire, target.Size)
            wire.Parent = VisualContainer
            entry.Box = wire
        else
            return false
        end

        updateLabel(kind, object, entry)
        return true
    end

    -- One Highlight per object. This is the same basic architecture used
    -- by current DOORS ESP implementations and avoids the FPS hit caused
    -- by one Highlight per MeshPart.
    local highlight = Instance.new("Highlight")
    highlight.Name = "JustXDoorsESP"
    highlight.Adornee = object
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = ITEM_KINDS[kind] and 0.55 or 1
    highlight.OutlineTransparency = 0
    highlight.Parent = VisualContainer
    entry.Highlight = highlight

    updateLabel(kind, object, entry)
    return true
end

local function clearEntry(kind, object)
    local entry = Objects[kind] and Objects[kind][object]
    if not entry then return end

    destroyVisual(entry)
    Objects[kind][object] = nil
end

local function addObject(kind, object, room)
    if not object or not object.Parent or not Enabled[kind] then
        return
    end

    if not ITEM_KINDS[kind] and not ENTITY_KINDS[kind]
        and not roomVisible(kind, room)
    then
        return
    end

    if ITEM_KINDS[kind] and isInventoryObject(object) then
        return
    end

    local entry = Objects[kind][object]
    if not entry then
        entry = {Room = room}
        Objects[kind][object] = entry
    else
        entry.Room = room or entry.Room
    end

    if kind == "Doors" and room then
        object:SetAttribute("JustXDoorsRoom", tonumber(room.Name))
    end

    if not createVisual(kind, object, entry) then
        return
    end

    updateLabel(kind, object, entry)
end

local function clearKind(kind)
    for object in pairs(Objects[kind]) do
        clearEntry(kind, object)
    end
end

local function clearStale(kind, seen, domain)
    for object in pairs(Objects[kind]) do
        local keep = seen[object] and object.Parent

        local tooFar = false
        local part = getTargetPart(kind, object) or getPart(object)
        local root = getRoot()
        if part and root then
            tooFar = (root.Position - part.Position).Magnitude > MAX_ESP_DISTANCE
        end

        if keep == true and not tooFar then
            continue
        end

        local shouldClear = true
        local entry = Objects[kind][object]

        if domain == "Drops" then
            -- Only reconcile entries that originated from Drops.
            if entry and entry.Room == nil then
                shouldClear = not Drops or not object:IsDescendantOf(Drops)
            else
                shouldClear = false
            end
        elseif domain == "Rooms" then
            local room = entry and entry.Room
            if room ~= nil then
                shouldClear = not object.Parent
                    or not object:IsDescendantOf(workspace)
                    or not room.Parent
                    or not roomVisible(kind, room)
            else
                shouldClear = false
            end
        elseif domain == "Global" then
            shouldClear = true
        end

        if ITEM_KINDS[kind] and isInventoryObject(object) then
            shouldClear = true
        end

        if shouldClear then
            clearEntry(kind, object)
        end
    end
end

local function hasDrawerContainer(object)
    return object and object:FindFirstChild("DrawerContainer", true) ~= nil
end

local function findItemRoot(object, room)
    local root = object
    local parent = object.Parent

    while parent and parent ~= room do
        if parent.Name == object.Name
            and parent:FindFirstChild("ModulePrompt", true)
        then
            root = parent
        end
        parent = parent.Parent
    end

    return root
end

local function registerRoom(room, seen)
    if not room or not room.Parent then return end

    local doorContainer = room:FindFirstChild("Door")
    local door = doorContainer and (doorContainer:FindFirstChild("Door") or doorContainer)
    if Enabled.Doors and door and roomVisible("Doors", room) then
        seen.Doors[door] = true
        addObject("Doors", door, room)
    end

    local itemMap = {
        Vitamins="Vitamins", Lighter="Lighter", Candle="Candle",
        AlarmClock="AlarmClock", Lockpick="Lockpick", SkeletonKey="SkeletonKey",
        Shears="Shears", RiftCandle="RiftCandle", RiftSmoothie="RiftSmoothie",
        RiftJar="RiftJar", Donut="Donut", Crucifix="Crucifix",
    }

    for _, object in ipairs(room:GetDescendants()) do
        local name = object.Name

        if not object:IsA("Model") and not object:IsA("BasePart") and name ~= "GoldPile" then
            continue
        end

        if Enabled.Drawers and roomVisible("Drawers", room)
            and (name == "Dresser" or name == "Table" or name == "Rolltop_Desk")
            and (name == "Rolltop_Desk" or hasDrawerContainer(object))
        then
            seen.Drawers[object] = true
            addObject("Drawers", object, room)
        end

        if Enabled.Closets and roomVisible("Closets", room)
            and (name == "Wardrobe" or name == "Toolshed")
        then
            seen.Closets[object] = true
            addObject("Closets", object, room)
        end

        if Enabled.Toolshed and roomVisible("Toolshed", room)
            and name == "Toolshed_Small"
        then
            seen.Toolshed[object] = true
            addObject("Toolshed", object, room)
        end

        if roomVisible("Chest", room) then
            if Enabled.Chest and (name == "ChestBox" or name == "ChestBoxLocked") then
                seen.Chest[object] = true
                addObject("Chest", object, room)
            elseif Enabled.LockedChest and name == "LockedChestBox" then
                seen.Chest[object] = true
                addObject("Chest", object, room)
            end
        end

        if Enabled.Key and roomVisible("Key", room) and name == "KeyObtain"
            and object:FindFirstChild("ModulePrompt", true)
        then
            seen.Key[object] = true
            addObject("Key", object, room)
        end

        if Enabled.Gold and roomVisible("Gold", room) and name == "GoldPile" then
            local value = tonumber(object:GetAttribute("GoldValue"))
            if not value or value >= (Module.GoldLevel or 1) then
                seen.Gold[object] = true
                addObject("Gold", object, room)
            end
        end

        if Enabled.Bandage and name == "Bandage" then
            seen.Bandage[object] = true
            addObject("Bandage", object, room)
        elseif Enabled.Smoothie and name == "Smoothie" then
            seen.Smoothie[object] = true
            addObject("Smoothie", object, room)
        end

        if room.Name == "9" and (Enabled.Flashlight or Enabled.TipJar) then
            local shop = room:FindFirstChild("RiftRoom_JeffShop")
            if shop then
                local flashlight = shop:FindFirstChild("Flashlight")
                local tipJar = shop:FindFirstChild("TipJar")
                if Enabled.Flashlight and flashlight then
                    seen.Flashlight[flashlight] = true
                    addObject("Flashlight", flashlight, room)
                end
                if Enabled.TipJar and tipJar then
                    seen.TipJar[tipJar] = true
                    addObject("TipJar", tipJar, room)
                end
            end
        end

        local kind = itemMap[name]
        local insideBatteryPack = object:FindFirstAncestor("BatteryPack") ~= nil
        local decorativeBookcaseLighter =
            kind == "Lighter" and object:FindFirstAncestor("Bookcase") ~= nil
        local itemRoot = kind and findItemRoot(object, room) or object

        if kind and Enabled[kind] and itemRoot == object
            and not insideBatteryPack
            and not decorativeBookcaseLighter
            and (object:GetAttribute("Pickup") ~= nil
                or object:GetAttribute("PropType") ~= nil
                or object:FindFirstChild("ModulePrompt", true))
            and roomVisible(kind, room)
        then
            seen[kind][object] = true
            addObject(kind, object, room)
        end

        if Enabled.VentGate and name == "VentGrate" and roomVisible("VentGate", room) then
            seen.VentGate[object] = true
            addObject("VentGate", object, room)
        end

        if Enabled.Lever and name == "LeverForGate" and roomVisible("Lever", room) then
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

local function newSeen()
    local seen = {}
    for _, kind in ipairs(KINDS) do
        seen[kind] = {}
    end
    return seen
end

local function scanRooms()
    Rooms = getRooms()
    local seen = newSeen()

    if Rooms then
        for _, room in ipairs(Rooms:GetChildren()) do
            if tonumber(room.Name) then
                registerRoom(room, seen)
            end
        end
    end

    local roomKinds = {
        "Doors","Drawers","Closets","Toolshed","Chest","Key","Gold",
        "Bandage","Smoothie","Flashlight","TipJar","Vitamins","Lighter",
        "Candle","AlarmClock","Lockpick","SkeletonKey","Shears","RiftCandle",
        "RiftSmoothie","RiftJar","Donut","Crucifix","SallyToy","ElectricalKey",
        "BreakerPole","VentGate","Lever"
    }

    for _, kind in ipairs(roomKinds) do
        if Enabled[kind] then
            clearStale(kind, seen[kind], "Rooms")
        else
            clearKind(kind)
        end
    end
end

local DROP_MAP = {
    Vitamins="Vitamins", Lighter="Lighter", Candle="Candle",
    AlarmClock="AlarmClock", Lockpick="Lockpick", SkeletonKey="SkeletonKey",
    Shears="Shears", Battery="Battery", Bandage="Bandage",
    Smoothie="Smoothie", Flashlight="Flashlight", TipJar="TipJar",
    RiftCandle="RiftCandle", RiftSmoothie="RiftSmoothie", RiftJar="RiftJar",
    Donut="Donut", Crucifix="Crucifix",
}

local function scanDrops()
    Drops = workspace:FindFirstChild("Drops")
    local seen = newSeen()

    if Drops then
        for _, object in ipairs(Drops:GetChildren()) do
            local kind = DROP_MAP[object.Name]

            if kind and Enabled[kind] then
                seen[kind][object] = true
                addObject(kind, object, nil)
            elseif object.Name == "BandagePack" and Enabled.Bandage then
                local bandage = object:FindFirstChild("Bandage", true)
                if bandage then
                    seen.Bandage[bandage] = true
                    addObject("Bandage", bandage, nil)
                end
            end
        end
    end

    local kinds = {
        "Vitamins","Lighter","Candle","AlarmClock","Lockpick","SkeletonKey",
        "Shears","Battery","Bandage","Smoothie","Flashlight","TipJar",
        "RiftCandle","RiftSmoothie","RiftJar","Donut","Crucifix"
    }

    for _, kind in ipairs(kinds) do
        if Enabled[kind] then
            clearStale(kind, seen[kind], "Drops")
        end
    end
end

local function scanEntities()
    local seen = newSeen()

    local function register(kind, object)
        if not Enabled[kind] or not object or not object.Parent then return end
        seen[kind][object] = true
        addObject(kind, object, getRoom(object))
    end

    local entityNames = {
        RushMoving = "Rush",
        AmbushMoving = "Ambush",
        Eyes = "Eyes",
        SallyLingering = "SallyLingering",
        SallyMoving = "SallyMoving",
        Screech = "Screech",
        SideroomDupe = "Dupe",
        SeekMovingNewClone = "Seek",
        FigureRig = "Figure",
        Snare = "Snare",
    }

    -- Entity instances used by Hotel are normally exposed through these
    -- direct/global references. Avoid walking every Workspace descendant
    -- repeatedly because entity models can contain large animated trees.
    for _, kindName in ipairs({"RushMoving", "AmbushMoving", "Eyes", "SallyLingering", "SallyMoving"}) do
        local kind = entityNames[kindName]
        if kind and Enabled[kind] then
            register(kind, workspace:FindFirstChild(kindName))
        end
    end

    if Enabled.Rush or Enabled.Ambush then
        for _, object in ipairs(workspace:GetChildren()) do
            if object.Name == "RushMoving" and Enabled.Rush then
                register("Rush", object)
            elseif object.Name == "AmbushMoving" and Enabled.Ambush then
                register("Ambush", object)
            end
        end
    end

    if Enabled.Eyes then register("Eyes", workspace:FindFirstChild("Eyes")) end
    if Enabled.SallyLingering then register("SallyLingering", workspace:FindFirstChild("SallyLingering")) end
    if Enabled.SallyMoving then register("SallyMoving", workspace:FindFirstChild("SallyMoving")) end

    if Enabled.Screech then
        local camera = workspace:FindFirstChild("Camera")
        register("Screech", camera and camera:FindFirstChild("Screech"))
    end

    if Rooms then
        for _, room in ipairs(Rooms:GetChildren()) do
            if Enabled.Dupe then register("Dupe", room:FindFirstChild("SideroomDupe", true)) end
            if Enabled.Seek then register("Seek", room:FindFirstChild("SeekMovingNewClone", true)) end
            if Enabled.Figure then register("Figure", room:FindFirstChild("FigureRig", true)) end
            if Enabled.Snare then register("Snare", room:FindFirstChild("Snare", true)) end
        end
    end

    for _, kind in ipairs({"Rush","Ambush","Dupe","Eyes","SallyLingering","SallyMoving","Seek","Figure","Snare","Screech"}) do
        if Enabled[kind] then
            clearStale(kind, seen[kind], "Global")
        else
            clearKind(kind)
        end
    end
end

local function scanAll()
    scanRooms()
    scanDrops()
    scanEntities()
    ScanRequested = false
end

local function requestScan()
    ScanRequested = true
end

local function requestRoom(room)
    if room and room.Parent then
        PendingRooms[room] = true
    end
    ScanRequested = true
end

local function refreshPendingRooms()
    for room in pairs(PendingRooms) do
        PendingRooms[room] = nil
        if room.Parent then
            -- Full reconciliation is intentionally used for room changes:
            -- CurrentRooms can replace several descendants in one replication step.
            scanRooms()
        end
    end
end

local function hookRoom(room)
    if not room or not room.Parent then return end

    local list = {}
    RoomConnections[room] = list

    table.insert(list, room.DescendantAdded:Connect(function(object)
        local interesting = {
            Door=true, Dresser=true, Table=true, Rolltop_Desk=true,
            Wardrobe=true, DrawerContainer=true, KeyObtain=true, GoldPile=true,
            Bandage=true, Smoothie=true, Toolshed=true, Toolshed_Small=true,
            CrucifixWall=true, SallyToyObtain=true, ElectricalKeyObtain=true,
            LiveBreakerPolePickup=true, VentGrate=true, LeverForGate=true,
            Vitamins=true, Lighter=true, Candle=true, AlarmClock=true,
            Lockpick=true, SkeletonKey=true, Shears=true, RiftCandle=true,
            RiftSmoothie=true, RiftJar=true, Donut=true, SideroomDupe=true,
            SeekMovingNewClone=true, FigureRig=true, Snare=true,
        }
        if interesting[object.Name] then
            requestRoom(room)
        end
    end))

    table.insert(list, room.DescendantRemoving:Connect(function()
        requestRoom(room)
    end))

    table.insert(list, room.AncestryChanged:Connect(function(_, parent)
        if not parent then
            RoomConnections[room] = nil
            table.clear(list)
            requestScan()
        end
    end))
end

local function hookRooms(container)
    disconnect(RoomsContainerConnection)
    RoomsContainerConnection = nil

    for room, list in pairs(RoomConnections) do
        if room ~= container then
            disconnectList(list)
            RoomConnections[room] = nil
        end
    end

    Rooms = container
    if not container then return end

    RoomsContainerConnection = container.ChildAdded:Connect(function(room)
        if tonumber(room.Name) then
            hookRoom(room)
            requestRoom(room)
        end
    end)
    table.insert(Connections, RoomsContainerConnection)

    local removedConnection = container.ChildRemoved:Connect(function()
        requestScan()
    end)
    table.insert(Connections, removedConnection)

    for _, room in ipairs(container:GetChildren()) do
        if tonumber(room.Name) then hookRoom(room) end
    end

    requestScan()
end

local function hookDrops(container)
    disconnectList(DropConnections)
    Drops = container
    if not container then return end

    table.insert(DropConnections, container.ChildAdded:Connect(function()
        PendingDrops = true
        ScanRequested = true
    end))

    table.insert(DropConnections, container.ChildRemoved:Connect(function()
        PendingDrops = true
        ScanRequested = true
    end))

    table.insert(DropConnections, container.DescendantAdded:Connect(function()
        PendingDrops = true
        ScanRequested = true
    end))

    table.insert(DropConnections, container.DescendantRemoving:Connect(function()
        PendingDrops = true
        ScanRequested = true
    end))

    scanDrops()
end

local function setup()
    VisualContainer = Instance.new("Folder")
    VisualContainer.Name = "JustXDoors_HotelESP"
    VisualContainer.Parent = workspace

    hookRooms(getRooms())
    hookDrops(workspace:FindFirstChild("Drops"))

    local function hookInventory(container)
        if not container then return end
        connect(container.ChildAdded, function()
            requestScan()
        end)
        connect(container.ChildRemoved, function()
            requestScan()
        end)
        connect(container.DescendantAdded, function()
            requestScan()
        end)
        connect(container.DescendantRemoving, function()
            requestScan()
        end)
    end

    hookInventory(LocalPlayer:FindFirstChildOfClass("Backpack"))
    if LocalPlayer.Character then
        hookInventory(LocalPlayer.Character)
    end

    connect(LocalPlayer.CharacterAdded, function(character)
        hookInventory(character)
        requestScan()
    end)

    connect(LocalPlayer.ChildAdded, function(object)
        if object:IsA("Backpack") then
            hookInventory(object)
            requestScan()
        end
    end)

    connect(workspace.ChildAdded, function(object)
        if object.Name == "CurrentRooms" then
            hookRooms(object)
            return
        end

        if object.Name == "Drops" then
            hookDrops(object)
            return
        end

        if object.Name == "RushMoving" or object.Name == "AmbushMoving"
            or object.Name == "Eyes" or object.Name == "SallyLingering"
            or object.Name == "SallyMoving" or object.Name == "Screech"
        then
            requestScan()
        end
    end)

    connect(workspace.ChildRemoved, function(object)
        if object == Rooms or object == Drops then
            requestScan()
        elseif object.Name == "RushMoving" or object.Name == "AmbushMoving"
            or object.Name == "Eyes" or object.Name == "SallyLingering"
            or object.Name == "SallyMoving"
        then
            requestScan()
        end
    end)

    connect(workspace.DescendantAdded, function(object)
        if object:IsA("ProximityPrompt") then return end

        if Drops and object:IsDescendantOf(Drops) then
            PendingDrops = true
            ScanRequested = true
            return
        end

        local interesting = {
            KeyObtain=true, GoldPile=true, Door=true, Dresser=true,
            Table=true, Wardrobe=true, DrawerContainer=true, Bandage=true,
            Smoothie=true, SideroomDupe=true, FigureRig=true, Snare=true,
            SeekMovingNewClone=true, RushMoving=true, AmbushMoving=true,
            Eyes=true, SallyLingering=true, SallyMoving=true, Screech=true,
            VentGrate=true, LeverForGate=true, Toolshed=true,
            Toolshed_Small=true, LiveBreakerPolePickup=true,
            CrucifixWall=true, SallyToyObtain=true, ElectricalKeyObtain=true,
        }

        if interesting[object.Name] then
            local room = getRoom(object)
            if room then
                requestRoom(room)
            else
                requestScan()
            end
        end
    end)

    connect(workspace.DescendantRemoving, function(object)
        if Objects then
            requestScan()
        end
    end)

    connect(LocalPlayer:GetAttributeChangedSignal("CurrentRoom"), function()
        requestScan()
    end)

    connect(RunService.Heartbeat, function(dt)
        ScanClock += dt
        LabelClock += dt

        if ScanClock >= 0.12 then
            ScanClock = 0

            if ScanRequested or PendingDrops then
                PendingDrops = false
                refreshPendingRooms()
                scanAll()
            end
        end

        -- Door boxes use a proxy because their visible geometry can
        -- contain several parts. Entity ESP is attached directly to the
        -- moving entity part and therefore needs no per-frame bounds pass.
        for object, entry in pairs(Objects.Doors) do
            if object.Parent and entry.Box then
                updateBoxEntry(entry, object, false)
            end
        end

        -- Distance is refreshed every frame, independently of discovery.
        -- This prevents 55 -> 51 -> 44 style jumps caused by scan intervals.
        if LabelClock >= 0.033 then
            LabelClock = 0
            if Display.Distance then
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
        end
    end)

    requestScan()
end

local function parseSelection(selected)
    local result = {}

    if type(selected) == "table" then
        if #selected > 0 then
            for _, value in ipairs(selected) do
                result[value] = true
            end
        else
            for value, state in pairs(selected) do
                if state == true then result[value] = true end
            end
        end
    elseif type(selected) == "string" then
        result[selected] = true
    end

    return result
end

local function applyInteractables(selected)
    local state = parseSelection(selected)

    local map = {
        Doors="Doors", Drawers="Drawers", Closets="Closets",
        Chest="Chest", LockedChest="LockedChest",
        ["Vent Gate"]="VentGate", Lever="Lever", Toolshed="Toolshed"
    }

    if state.All then
        for _, kind in pairs(map) do state[kind] = true end
    end

    for label, kind in pairs(map) do
        Enabled[kind] = state[label] == true or state[kind] == true
    end

    requestScan()
end

local function applyItems(selected)
    local state = parseSelection(selected)

    local map = {
        Key="Key", Gold="Gold", Bandage="Bandage", Smoothie="Smoothie",
        Flashlight="Flashlight", ["Tip Jar"]="TipJar",
        Vitamins="Vitamins", Lighter="Lighter", Candle="Candle",
        AlarmClock="AlarmClock", Lockpick="Lockpick",
        ["Skeleton Key"]="SkeletonKey", Shears="Shears", Battery="Battery",
        ["Rift Candle"]="RiftCandle", ["Rift Smoothie"]="RiftSmoothie",
        ["Rift Jar"]="RiftJar", Donut="Donut", Crucifix="Crucifix",
        ["Sally Toy"]="SallyToy", ["Electrical Key"]="ElectricalKey",
        ["Breaker Pole"]="BreakerPole"
    }

    for label, kind in pairs(map) do
        Enabled[kind] = state[label] == true or state[kind] == true
    end

    if type(selected) == "table" and not selected[1]
        and selected.Gold ~= nil and selected.Gold ~= false
    then
        Module.GoldLevel = tonumber(selected.Gold) or 1
    elseif state.Gold then
        Module.GoldLevel = Module.GoldLevel or 1
    end

    requestScan()
end

function Module:Init(context)
    if VisualContainer then
        pcall(function() VisualContainer:Destroy() end)
    end

    Context = context or {}
    Enabled = Context.Enabled or {}
    Colors = Context.Colors or {}

    for _, kind in ipairs(KINDS) do
        if Colors[kind] == nil then
            Colors[kind] = DEFAULT_COLORS[kind] or Color3.new(1, 1, 1)
        end
    end

    Display = Context.Display or Display
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
    local state = parseSelection(selected)

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

    requestScan()
end

function Module:RefreshLabels()
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

function Module:ScanAll()
    requestScan()
    scanAll()
end

function Module:Destroy()
    for _, kind in ipairs(KINDS) do
        clearKind(kind)
    end

    disconnectList(Connections)
    disconnectList(DropConnections)

    for room, list in pairs(RoomConnections) do
        disconnectList(list)
        RoomConnections[room] = nil
    end

    table.clear(PendingRooms)
    PendingDrops = false
    ScanRequested = false

    if VisualContainer then
        pcall(function() VisualContainer:Destroy() end)
        VisualContainer = nil
    end

    disconnect(RoomsContainerConnection)
    RoomsContainerConnection = nil
    Rooms = nil
    Drops = nil
end

return Module
