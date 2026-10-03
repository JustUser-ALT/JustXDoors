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
local ITEM_VISUAL_DISTANCE = 90
local ENTITY_VISUAL_DISTANCE = 140

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

-- Forward declaration: cleanup can run before the Key Drawer proxy
-- helpers are declared below this section.
local destroyKeyProxy

local function destroyEntryVisual(entry)
    destroyKeyProxy(entry)

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

    if entry.DoorConnection then
        pcall(function() entry.DoorConnection:Disconnect() end)
        entry.DoorConnection = nil
    end

    if entry.DoorHelpers then
        for _, helper in ipairs(entry.DoorHelpers) do
            pcall(function() helper:Destroy() end)
        end
        entry.DoorHelpers = nil
    end
    if entry.DoorHumanoid then
        pcall(function() entry.DoorHumanoid:Destroy() end)
        entry.DoorHumanoid = nil
    end

    if entry.ItemHelperModel then
        pcall(function() entry.ItemHelperModel:Destroy() end)
        entry.ItemHelperModel = nil
    end
    entry.ItemSources = nil
    entry.ItemHumanoid = nil

    if entry.Box then
        pcall(function() entry.Box:Destroy() end)
        entry.Box = nil
    end

    if entry.Boxes then
        for _, box in ipairs(entry.Boxes) do
            pcall(function() box:Destroy() end)
        end
        entry.Boxes = nil
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
    highlight.FillTransparency = fillTransparency or 1
    highlight.OutlineTransparency = 0
    -- Keep every ESP Highlight outside the highlighted object's hierarchy.
    -- Roblox documents rendering issues when Highlight instances are nested
    -- through parent/child object relationships. This is especially
    -- important for Drawer + KeyObtain, because KeyObtain lives inside the
    -- Drawer and must have its own AlwaysOnTop Highlight.
    highlight.Parent = VisualContainer

    entry.Highlight = highlight
    return true
end

-- Item ESP uses its own helper geometry instead of adorning the live
-- DOORS item. Some mobile interactions create/reparent interaction parts
-- (the on-screen finger/prompt is one visible symptom), which can make a
-- Highlight attached directly to the item disappear.
local function getItemParts(object, kind)
    local parts = {}

    if not object then return parts end

    -- Keys need a stricter geometry selection than normal Items.
    -- KeyObtain contains an interaction Hitbox, and using its parts first
    -- can produce a flat/circular outline whose orientation follows the
    -- interaction volume rather than the visible key.
    if kind == "Key" then
        local hitbox = object:FindFirstChild("Hitbox", true)

        local function isInsideInteractionVolume(part)
            local parent = part.Parent
            while parent and parent ~= object do
                if parent == hitbox
                    or parent.Name == "PromptHitbox"
                    or parent.Name == "ModulePrompt"
                then
                    return true
                end
                parent = parent.Parent
            end
            return false
        end

        local candidates = {}
        for _, child in ipairs(object:GetDescendants()) do
            if child:IsA("BasePart")
                and child.Size.Magnitude > 0.05
                and child.Name ~= "PromptHitbox"
                and child.Name ~= "ModulePrompt"
                and not isInsideInteractionVolume(child)
            then
                candidates[#candidates + 1] = child
            end
        end

        for _, child in ipairs(candidates) do
            if child:IsA("MeshPart")
                or child.Name == "Key"
                or child.Name == "Handle"
                or child.Name == "Mesh"
            then
                parts[#parts + 1] = child
            end
        end

        if #parts == 0 then
            for _, child in ipairs(candidates) do
                if child.Transparency < 1 then
                    parts[#parts + 1] = child
                end
            end
        end

        if #parts == 0 and hitbox then
            for _, child in ipairs(hitbox:GetDescendants()) do
                if child:IsA("MeshPart")
                    and child.Name ~= "Hitbox"
                    and child.Name ~= "PromptHitbox"
                    and child.Size.Magnitude > 0.05
                then
                    parts[#parts + 1] = child
                end
            end
        end

        return parts
    end

    if object:IsA("BasePart") then
        if object.Transparency < 1 and object.Size.Magnitude > 0.05 then
            parts[1] = object
        end
        return parts
    end

    local function isInteractionPart(part)
        local parent = part.Parent

        while parent and parent ~= object do
            local name = string.lower(parent.Name)

            if parent.Name == "PromptHitbox"
                or parent.Name == "ModulePrompt"
                or parent.Name == "Hitbox"
                or string.find(name, "prompt", 1, true)
                or string.find(name, "interaction", 1, true)
            then
                return true
            end

            parent = parent.Parent
        end

        local partName = string.lower(part.Name)
        if part.Name == "PromptHitbox"
            or part.Name == "ModulePrompt"
            or part.Name == "Hitbox"
            or string.find(partName, "prompt", 1, true)
        then
            return true
        end

        return false
    end

    for _, child in ipairs(object:GetDescendants()) do
        if child:IsA("BasePart")
            and child.Transparency < 1
            and child.Size.Magnitude > 0.05
            and not isInteractionPart(child)
        then
            parts[#parts + 1] = child
        end
    end

    return parts
end

local function findContainingDrawer(object)
    if not object then return nil end

    local current = object.Parent
    while current and current ~= Rooms do
        local name = string.lower(current.Name)

        -- DOORS can store a KeyObtain directly under a drawer/container
        -- branch rather than directly under the Dresser model. Accept the
        -- actual drawer containers as well as the known furniture roots.
        if current.Name == "DrawerContainer"
            or string.find(name, "drawer", 1, true)
        then
            return current
        end

        if current:IsA("Model")
            and (
                current.Name == "Dresser"
                or current.Name == "Table"
                or current.Name == "Rolltop_Desk"
            )
            and current:FindFirstChild("DrawerContainer", true)
        then
            return current
        end

        current = current.Parent
    end

    return nil
end

destroyKeyProxy = function(entry)
    if entry.KeyProxyHighlight then
        pcall(function() entry.KeyProxyHighlight:Destroy() end)
        entry.KeyProxyHighlight = nil
    end

    if entry.KeyProxyPart then
        pcall(function() entry.KeyProxyPart:Destroy() end)
        entry.KeyProxyPart = nil
    end
end

local function makeKeyDrawerProxy(object, entry, sources)
    if not object or not VisualContainer then return false end

    local drawer = findContainingDrawer(object)
    if not drawer then
        destroyKeyProxy(entry)
        return false
    end

    -- For a key stored in a Drawer, adorn the real KeyObtain model.
    -- No transparent proxy geometry or cloned key mesh is used.
    -- This matches the important part of the Abyssal-style approach:
    -- Highlight the actual KeyObtain object with AlwaysOnTop.
    destroyKeyProxy(entry)

    local highlight = Instance.new("Highlight")
    highlight.Name = "JustXDoorsKeyDrawerESP"
    highlight.Adornee = object
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Colors.Key or Color3.fromRGB(255,225,40)
    highlight.OutlineColor = Colors.Key or Color3.fromRGB(255,225,40)
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.Enabled = true
    highlight.Parent = VisualContainer

    entry.KeyProxyHighlight = highlight

    return true
end
local function destroyItemHelper(entry, keepKeyProxy)
    if not keepKeyProxy then
        destroyKeyProxy(entry)
    end

    if entry.Highlight then
        pcall(function() entry.Highlight:Destroy() end)
        entry.Highlight = nil
    end

    if entry.ItemHelperModel then
        pcall(function() entry.ItemHelperModel:Destroy() end)
        entry.ItemHelperModel = nil
    end

    entry.ItemSources = nil
    entry.ItemHumanoid = nil
end

local function makeItemHighlight(kind, object, entry)
    if not object or not VisualContainer then return false end

    local sources = getItemParts(object, kind)
    if #sources == 0 then
        if kind == "Key" then
            destroyKeyProxy(entry)
        end
        return false
    end

    if kind == "Key" and makeKeyDrawerProxy(object, entry, sources) then
        -- Hidden keys use the lightweight proxy above. Do not clone the key
        -- mesh into the normal Item helper; the Drawer remains fully outlined.
        destroyItemHelper(entry, true)
        return true
    elseif kind == "Key" then
        destroyKeyProxy(entry)
    end

    -- Do not rebuild the helper on every reconciliation scan. Mobile
    -- interaction prompts can cause DescendantAdded/Removing activity while
    -- the finger UI is visible. Recreating the Highlight during that burst
    -- is what makes some item ESPs flicker or fragment into tiny dots.
    -- Keep the existing helper when its source geometry is unchanged.
    if entry.ItemHelperModel
        and entry.Highlight
        and entry.ItemSources
    then
        local sameSources = true
        local sourceCount = 0

        for source in pairs(entry.ItemSources) do
            sourceCount += 1
            if not source.Parent then
                sameSources = false
                break
            end
        end

        if sameSources and sourceCount == #sources then
            for _, source in ipairs(sources) do
                if not entry.ItemSources[source] then
                    sameSources = false
                    break
                end
            end
        else
            sameSources = false
        end

        if sameSources then
            entry.Highlight.FillColor = Colors[kind] or Color3.new(1,1,1)
            entry.Highlight.OutlineColor = Colors[kind] or Color3.new(1,1,1)
            entry.Highlight.Enabled = true
            return true
        end
    end

    destroyItemHelper(entry)

    local helperModel = Instance.new("Model")
    helperModel.Name = "JustXDoorsItemHighlightModel"
    helperModel.Parent = VisualContainer

    -- Same transparent-model technique used by the working Door ESP.
    -- The helper parts are almost completely invisible, while the Highlight
    -- is rendered from their actual geometry.
    local humanoid = Instance.new("Humanoid")
    humanoid.Name = "JustXDoorsItemHighlightHumanoid"
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    humanoid.NameDisplayDistance = 0
    humanoid.Parent = helperModel

    local sourceMap = {}

    for index, source in ipairs(sources) do
        local helper

        local ok, clone = pcall(function()
            return source:Clone()
        end)

        if ok and clone and clone:IsA("BasePart") then
            helper = clone

            -- Keep only geometry-related mesh objects. Never copy prompts,
            -- touch transmitters, scripts, constraints, etc. from the item.
            for _, child in ipairs(helper:GetDescendants()) do
                if not (
                    child:IsA("SpecialMesh")
                    or child:IsA("BlockMesh")
                    or child:IsA("CylinderMesh")
                ) then
                    pcall(function() child:Destroy() end)
                end
            end
        else
            helper = Instance.new("Part")
            helper.Shape = Enum.PartType.Block
            helper.Size = source.Size
        end

        helper.Name = "JustXDoorsItemHighlightPart_" .. tostring(index)
        helper.CFrame = source.CFrame

        -- Texture/surface details are irrelevant to the ESP and can make
        -- transparent MeshPart highlights produce noisy pixel artifacts.
        if helper:IsA("MeshPart") then
            pcall(function() helper.TextureID = "" end)
        end

        helper.Transparency = 0.999
        helper.CanCollide = false
        helper.CanTouch = false
        helper.CanQuery = false
        helper.CastShadow = false
        helper.Anchored = false
        helper.Massless = true
        helper.Material = Enum.Material.Plastic
        helper.Parent = helperModel

        local weld = Instance.new("WeldConstraint")
        weld.Name = "JustXDoorsItemHighlightWeld"
        weld.Part0 = helper
        weld.Part1 = source
        weld.Parent = helper

        sourceMap[source] = helper
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "JustXDoorsItemESP"
    highlight.Adornee = helperModel
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Colors[kind] or Color3.new(1,1,1)
    highlight.OutlineColor = Colors[kind] or Color3.new(1,1,1)
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.Enabled = true
    highlight.Parent = VisualContainer

    entry.ItemHelperModel = helperModel
    entry.ItemHumanoid = humanoid
    entry.ItemSources = sourceMap
    entry.Highlight = highlight

    return true
end

local function createVisual(kind, object, entry)
    if not object or not object.Parent then return false end

    local root = getRoot()
    local part = ENTITY_KINDS[kind] and getEntityPart(kind, object) or getPart(object)

    -- Keep labels available farther away, but only render 3D ESP near the player.
    -- This is the main FPS optimization: SelectionBox is kept for doors only;
    -- items/entities use the lighter Highlight path and are distance-culled.
    -- Item ESP must stay visible even when the player is standing directly
    -- beside the item. Only entities use distance-based 3D culling.
    local visualDistance = ENTITY_VISUAL_DISTANCE
    local near = true

    if ENTITY_KINDS[kind] and root and part then
        near = (root.Position - part.Position).Magnitude <= visualDistance
    end

    if kind == "Doors" then
        -- Abyssal-style helper geometry: invisible, non-colliding parts copy
        -- the real door geometry and are used as Highlight Adornees.
        local doorParts = {}

        for _, child in ipairs(object:GetChildren()) do
            if child.Name == "Door" and child:IsA("BasePart") then
                table.insert(doorParts, child)
            end
        end

        if #doorParts == 0 then
            local source = object:FindFirstChild("Door")
            if source and source:IsA("BasePart") then
                table.insert(doorParts, source)
            end
        end

        if not near then
            if entry.Highlights then
                for _, highlight in ipairs(entry.Highlights) do
                    pcall(function() highlight:Destroy() end)
                end
                entry.Highlights = nil
            end
            if entry.DoorHelpers then
                for _, helper in ipairs(entry.DoorHelpers) do
                    pcall(function() helper:Destroy() end)
                end
                entry.DoorHelpers = nil
            end
            entry.Highlight = nil
            updateLabel(kind, object, entry)
            return true
        end

        if not entry.DoorHelpers or #entry.DoorHelpers ~= #doorParts then
            if entry.Highlights then
                for _, highlight in ipairs(entry.Highlights) do
                    pcall(function() highlight:Destroy() end)
                end
            end
            if entry.DoorHelpers then
                for _, helper in ipairs(entry.DoorHelpers) do
                    pcall(function() helper:Destroy() end)
                end
            end

            entry.DoorHelpers = {}
            entry.Highlights = {}

            if object:IsA("Model") and not object:FindFirstChild("JustXDoorsHighlightHumanoid") then
                local humanoid = Instance.new("Humanoid")
                humanoid.Name = "JustXDoorsHighlightHumanoid"
                humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
                humanoid.NameDisplayDistance = 0
                humanoid.Parent = object
                entry.DoorHumanoid = humanoid
            end

            for index, source in ipairs(doorParts) do
                local helper = Instance.new("Part")
                helper.Name = "JustXDoorsDoorHighlightPart"
                helper.Transparency = 0.999
                helper.CanCollide = false
                helper.CanTouch = false
                helper.CanQuery = false
                helper.CastShadow = false
                helper.Anchored = false
                helper.Massless = true
                helper.Material = Enum.Material.Plastic
                helper.Size = source.Size
                helper.CFrame = source.CFrame
                helper.Parent = object

                local weld = Instance.new("WeldConstraint")
                weld.Part0 = helper
                weld.Part1 = source
                weld.Parent = helper

                local highlight = Instance.new("Highlight")
                highlight.Name = "JustXDoorsDoorHighlight"
                highlight.Adornee = helper
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.FillColor = Colors[kind] or Color3.new(1,1,1)
                highlight.OutlineColor = Colors[kind] or Color3.new(1,1,1)
                highlight.FillTransparency = 0.78
                highlight.OutlineTransparency = 0
                highlight.Parent = helper

                entry.DoorHelpers[index] = helper
                table.insert(entry.Highlights, highlight)
            end
        else
            for _, helper in ipairs(entry.DoorHelpers) do
                local weld = helper:FindFirstChildOfClass("WeldConstraint")
                local source = weld and weld.Part1
                if source and source.Parent then
                    helper.Size = source.Size
                    helper.CFrame = source.CFrame
                end
            end

            for _, highlight in ipairs(entry.Highlights or {}) do
                highlight.FillColor = Colors[kind] or Color3.new(1,1,1)
                highlight.OutlineColor = Colors[kind] or Color3.new(1,1,1)
                highlight.FillTransparency = 0.78
                highlight.OutlineTransparency = 0
            end
        end

        updateLabel(kind, object, entry)
        return true
    end

    -- If an object moved outside the render radius, remove only its 3D visual.
    -- The Billboard label is intentionally kept.
    if not near then
        if entry.Highlight then
            pcall(function() entry.Highlight:Destroy() end)
            entry.Highlight = nil
        end
        if entry.Box then
            pcall(function() entry.Box:Destroy() end)
            entry.Box = nil
        end
        if entry.Highlights then
            for _, h in ipairs(entry.Highlights) do
                pcall(function() h:Destroy() end)
            end
            entry.Highlights = nil
        end
        updateLabel(kind, object, entry)
        return true
    end

    if kind == "Key" then
        local sources = getItemParts(object, kind)
        if makeKeyDrawerProxy(object, entry, sources) then
            destroyItemHelper(entry, true)
            updateLabel(kind, object, entry)
            return true
        elseif entry.KeyProxyPart or entry.KeyProxyHighlight then
            destroyKeyProxy(entry)
        end
    end

    if entry.Highlight and entry.Highlight.Parent then
        if ITEM_KINDS[kind] then
            -- Validate the helper against the current item geometry. The
            -- helper is welded to the real parts, so the mobile finger/prompt
            -- can reparent or rebuild interaction objects without owning the
            -- ESP Highlight.
            local sources = getItemParts(object, kind)
            local valid = entry.ItemHelperModel
                and entry.ItemHelperModel.Parent == VisualContainer
                and entry.Highlight.Parent == VisualContainer
                and entry.Highlight.Adornee == entry.ItemHelperModel
                and entry.Highlight.Enabled
                and entry.ItemSources ~= nil

            if valid and #sources ~= (function()
                local count = 0
                for _ in pairs(entry.ItemSources) do count += 1 end
                return count
            end)() then
                valid = false
            end

            if valid then
                for _, source in ipairs(sources) do
                    if not source.Parent or not entry.ItemSources[source] then
                        valid = false
                        break
                    end
                end
            end

            if not valid then
                destroyItemHelper(entry)
                makeItemHighlight(kind, object, entry)
            else
                entry.Highlight.FillColor = Colors[kind] or Color3.new(1,1,1)
                entry.Highlight.OutlineColor = Colors[kind] or Color3.new(1,1,1)
                entry.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            end
        end

        if entry.Highlight then
            updateLabel(kind, object, entry)
            return true
        end
    end

    if entry.Box and entry.Box.Parent then
        updateLabel(kind, object, entry)
        return true
    end

    if ENTITY_KINDS[kind] then
        local target = getEntityPart(kind, object)
        if not target then return false end

        -- Use a real Highlight on the entity/model. No transparent Humanoid
        -- proxy is created, which avoids the previous entity FPS problem.
        local adornee = object:IsA("Model") and object or target
        makeHighlight(kind, adornee, entry, 1)
        updateLabel(kind, object, entry)
        return true
    end

    -- Items/interactables use outline-only Highlight. This is substantially
    -- cheaper visually than creating SelectionBoxes for every object.
    local adornee = object:IsA("Model") and object or getPart(object)
    if not adornee then return false end

    if ITEM_KINDS[kind] then
        makeItemHighlight(kind, object, entry)
    else
        makeHighlight(kind, adornee, entry, 1)
    end

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

    -- Doors and Items are intentionally not limited by physical distance.
    -- Their visibility is controlled by room rules instead. Entities keep
    -- the distance limit for performance.
    if kind ~= "Doors" and not ITEM_KINDS[kind]
        and part and root
        and (root.Position - part.Position).Magnitude > MAX_DISTANCE
    then
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
        if not object.Parent then
            clearEntry(kind, object)
        elseif entry.Room and not roomVisible(kind, entry.Room) then
            -- Do not rely on the scan's seen table for room visibility.
            -- Objects can still be discovered in an old room, so they may
            -- otherwise remain alive after the player changes rooms.
            clearEntry(kind, object)
        elseif not seen[object] then
            if entry.Room and Rooms and object:IsDescendantOf(Rooms) then
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

        if Enabled.Key and name == "KeyObtain" then
            -- A key inside a Drawer can be missing ModulePrompt while it is
            -- stored/hidden by the drawer interaction system. The KeyObtain
            -- object itself is still the reliable marker.
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

        if Enabled.SallyToy and name == "SallyToyObtain" then
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
        SallyToy="SallyToy",
    }

    for _, object in ipairs(Drops:GetDescendants()) do
        local kind = map[object.Name]

        if kind and Enabled[kind] then
            -- Always resolve the top-level Drop under workspace.Drops.
            -- Some Drops contain a child with the same name as the Drop
            -- itself (for example Drops.Candle.Handle.Candle). Scanning
            -- every descendant without climbing through BaseParts can create
            -- a second ESP entry for that inner object.
            local root = object
            while root.Parent and root.Parent ~= Drops do
                root = root.Parent
            end

            -- Only the actual top-level Drop is valid for this kind.
            -- Example: Drops.BatteryPack.Handle.Battery must NOT become
            -- a Battery ESP, because BatteryPack is a different item.
            -- The same-name nested object in Drops.Candle/RiftCandle is
            -- harmless because its resolved root keeps the matching name.
            if root.Name == object.Name then
                seen[kind][root] = true
                addObject(kind, root, nil)
            end
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
        if ScanQueued and ScanClock >= 0.15 then
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
