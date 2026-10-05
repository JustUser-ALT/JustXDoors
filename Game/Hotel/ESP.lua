local Module = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

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
local EntityVisualContainer

local Objects = {}
local ScanQueued = false
local ScanClock = 0
local LabelClock = 0

local MAX_DISTANCE = 300
local ITEM_VISUAL_DISTANCE = 500
local ENTITY_VISUAL_DISTANCE = 5000

local KINDS = {
    "Doors","Drawers","Closets","Key","Gold","Chest","LockedChest","Bed","GlitchCube","Bandage","Smoothie",
    "Flashlight","TipJar","Vitamins","Lighter","Candle","AlarmClock",
    "Lockpick","SkeletonKey","Shears","RiftCandle","RiftSmoothie","RiftJar",
    "Donut","Crucifix","SallyToy","ElectricalKey","BreakerPole","Battery",
    "Dupe","Eyes","SallyLingering","SallyMoving","Seek","Figure","Snare",
    "GlitchRush","GlitchAmbush","GlitchScreech","Screech","VentGate","Toolshed","Lever","Rush","Ambush","Dread"
}

for _, kind in ipairs(KINDS) do
    Objects[kind] = {}
end

local ITEM_KINDS = {
    Key=true, Gold=true, Bandage=true, Smoothie=true, Flashlight=true,
    TipJar=true, Vitamins=true, Lighter=true, Candle=true, AlarmClock=true,
    Lockpick=true, SkeletonKey=true, Shears=true, RiftCandle=true,
    RiftSmoothie=true, RiftJar=true, Donut=true, Crucifix=true,
    SallyToy=true, ElectricalKey=true, BreakerPole=true, Battery=true, GlitchCube=true, LibraryPaper=true, LibraryBook=true,
}

local ENTITY_KINDS = {
    Rush=true, Ambush=true, GlitchRush=true, GlitchAmbush=true, GlitchScreech=true, Dupe=true, Eyes=true, SallyLingering=true,
    SallyMoving=true, Seek=true, Figure=true, Snare=true, Screech=true, Dread=true,
}

local INTERACTABLE_KINDS = {
    Doors=true, Drawers=true, Closets=true, Chest=true, Bed=true,
    VentGate=true, Lever=true, Toolshed=true, LockedChest=true,
}

local DEFAULT_COLORS = {
    Doors=Color3.fromRGB(0,200,255),
    Drawers=Color3.fromRGB(255,170,70),
    Closets=Color3.fromRGB(125,75,45),
    Toolshed=Color3.fromRGB(180,110,55),
    GlitchCube=Color3.fromRGB(190,90,255),
    Chest=Color3.fromRGB(255,165,0),
    LockedChest=Color3.fromRGB(255,110,80),
    Bed=Color3.fromRGB(255,180,120),
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
    GlitchCube=Color3.fromRGB(190,90,255),
    LibraryPaper=Color3.fromRGB(255,255,255),
    LibraryBook=Color3.fromRGB(100,180,255),
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
    GlitchRush=Color3.fromRGB(255,80,255),
    GlitchAmbush=Color3.fromRGB(150,70,255),
    GlitchScreech=Color3.fromRGB(255,90,255),
    Dupe=Color3.fromRGB(255,140,40),
    Eyes=Color3.fromRGB(120,235,255),
    SallyLingering=Color3.fromRGB(255,105,210),
    SallyMoving=Color3.fromRGB(255,70,175),
    Seek=Color3.fromRGB(190,90,255),
    Figure=Color3.fromRGB(190,190,210),
    Snare=Color3.fromRGB(110,255,110),
    Screech=Color3.fromRGB(255,235,90),
    Dread=Color3.fromRGB(170,80,255),
}

local LABEL_NAMES = {
    Doors="Door", Drawers="Drawer", Closets="Closet", Key="Key", Gold="Gold",
    Chest="Chest", LockedChest="Locked Chest", Bed="Bed", GlitchCube="Glitch Cube", Bandage="Bandage", Smoothie="Smoothie", Flashlight="Flashlight",
    TipJar="Tip Jar", Vitamins="Vitamins", Lighter="Lighter", Candle="Candle",
    AlarmClock="Alarm Clock", Lockpick="Lockpick", SkeletonKey="Skeleton Key",
    Shears="Shears", RiftCandle="Rift Candle", RiftSmoothie="Rift Smoothie",
    RiftJar="Rift Jar", Donut="Donut", Crucifix="Crucifix", SallyToy="Sally Toy",
    ElectricalKey="Electrical Key", BreakerPole="Breaker Pole", Battery="Battery",
    LibraryPaper="Library Paper", LibraryBook="Library Book",
    Dupe="Dupe", Eyes="Eyes", SallyLingering="Sally", SallyMoving="Sally",
    Seek="Seek", Figure="Figure", Snare="Snare", Screech="Screech",
    VentGate="Vent Gate", Toolshed="Toolshed", Lever="Lever",
    Rush="Rush", Ambush="Ambush", GlitchRush="Glitch Rush", GlitchAmbush="Glitch Ambush", GlitchScreech="Glitch Screech", Dread="Dread",
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
        GlitchRush={"RushNew","GlitchRush"},
        GlitchAmbush={"RushNew","AmbushNew","GlitchAmbush"},
        GlitchScreech={"SCJVEREECH","GlitchScreech","Screech"},
        Dupe={"DoorFake"},
        Eyes={"Eyes"},
        SallyLingering={"Sally"},
        SallyMoving={"Sally"},
        Seek={"Figure","SeekRig","SeekMovingNewClone","SeekMovingNew","Seek"},
        Figure={"HumanoidRootPart","UpperTorso","Torso","Head"},
        Snare={"Snare"},
        Screech={"Screech"},
        Dread={"Dread","Main"},
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

    if entry.EntityHumanoid then
        pcall(function() entry.EntityHumanoid:Destroy() end)
        entry.EntityHumanoid = nil
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
    if not drawer or #sources == 0 then
        destroyKeyProxy(entry)
        return false
    end

    -- A KeyObtain inside a Drawer is a special case. Highlight has a
    -- renderer conflict here when the parent Drawer also has a Highlight.
    -- Infinite Yield's partesp avoids that path entirely: it uses one
    -- BoxHandleAdornment per real BasePart with AlwaysOnTop enabled.
    -- Use the same primitive for hidden Drawer keys.
    destroyKeyProxy(entry)

    local boxes = {}
    local keyColor = Colors.Key or Color3.fromRGB(255,225,40)

    for index, source in ipairs(sources) do
        if source and source.Parent and source:IsA("BasePart") then
            local box = Instance.new("BoxHandleAdornment")
            box.Name = "JustXDoorsKeyDrawerESP_" .. tostring(index)
            box.Adornee = source
            box.AlwaysOnTop = true
            box.ZIndex = 10
            box.Size = source.Size
            box.Transparency = 0.3
            box.Color3 = keyColor
            box.Parent = VisualContainer
            boxes[#boxes + 1] = box
        end
    end

    if #boxes == 0 then
        return false
    end

    entry.KeyProxyBoxes = boxes
    -- Keep this field for compatibility with cleanup paths that already
    -- know about the old single-proxy Highlight.
    entry.KeyProxyHighlight = boxes

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

    -- ElectricalKeyObtain keeps its visible key geometry inside:
    --   ElectricalKeyObtain.Hitbox.Key
    --   ElectricalKeyObtain.Hitbox.inset
    --   ElectricalKeyObtain.Hitbox.end
    -- The normal item geometry filter intentionally ignores Hitbox/Prompt
    -- descendants, so ElectricalKey needs its own renderer.
    if kind == "ElectricalKey" then
        local hitbox = object:FindFirstChild("Hitbox", true)
        if not hitbox then
            return false
        end

        local sources = {}
        for _, child in ipairs(hitbox:GetDescendants()) do
            if child:IsA("BasePart")
                and (child.Name == "Key" or child.Name == "inset" or child.Name == "end")
                and child.Transparency < 1
                and child.Size.Magnitude > 0.05
            then
                sources[#sources + 1] = child
            end
        end

        if #sources == 0 then
            return false
        end

        -- Reuse the normal transparent helper-model technique, but only
        -- with the three actual Electrical Key geometry parts.
        if entry.ItemHelperModel and entry.Highlight and entry.ItemSources then
            local sameSources = true
            local count = 0

            for source in pairs(entry.ItemSources) do
                count += 1
                if not source.Parent then
                    sameSources = false
                    break
                end
            end

            if sameSources and count == #sources then
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
                entry.Highlight.Enabled = true
                entry.Highlight.FillColor = Colors[kind] or Color3.new(1,1,1)
                entry.Highlight.OutlineColor = Colors[kind] or Color3.new(1,1,1)
                return true
            end
        end

        destroyItemHelper(entry)

        local helperModel = Instance.new("Model")
        helperModel.Name = "JustXDoorsElectricalKeyESPModel"
        helperModel.Parent = VisualContainer

        local humanoid = Instance.new("Humanoid")
        humanoid.Name = "JustXDoorsElectricalKeyESPHumanoid"
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
                helper.Size = source.Size
            end

            helper.Name = "JustXDoorsElectricalKeyPart_" .. tostring(index)
            helper.CFrame = source.CFrame
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
            weld.Part0 = helper
            weld.Part1 = source
            weld.Parent = helper

            sourceMap[source] = helper
        end

        local highlight = Instance.new("Highlight")
        highlight.Name = "JustXDoorsElectricalKeyESP"
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

local function destroyEntityVisual(entry)
    if entry.EntityHighlight then
        pcall(function() entry.EntityHighlight:Destroy() end)
        entry.EntityHighlight = nil
    end

    if entry.EntityHumanoid then
        pcall(function() entry.EntityHumanoid:Destroy() end)
        entry.EntityHumanoid = nil
    end

    entry.EntitySources = nil
    entry.EntityProxy = nil
    entry.Highlight = nil
end

-- This is the important part copied from Abyssal's actual Doors Entity
-- path, not just its Highlight settings.
--
-- Rush/Ambush/Eyes use transparent entity geometry. Abyssal makes Roblox's
-- Highlight renderer recognize that geometry by:
--   1) adding a Humanoid to the Entity Model;
--   2) forcing the Entity PrimaryPart to Transparency = 0.999;
--   3) forcing its Material to Plastic.
--
-- Without this workaround the Highlight can exist correctly while producing
-- no visible outline. Items/Interactables use a different renderer and are
-- deliberately left untouched.
local function prepareEntityForHighlight(kind, object, entry)
    if not object:IsA("Model") then
        return
    end

    -- Match Abyssal exactly: this is a dedicated Humanoid used by the
    -- Roblox Highlight renderer. Do not skip it just because the Entity
    -- already contains another Humanoid.
    local humanoid = object:FindFirstChild("HighlightHumanoid")
    if not humanoid then
        humanoid = Instance.new("Humanoid")
        humanoid.Name = "HighlightHumanoid"
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
        humanoid.NameDisplayDistance = 0
        humanoid.Parent = object
    end
    entry.EntityHumanoid = humanoid

    -- Abyssal waits until PrimaryPart exists before registering Entity ESP.
    -- Our scanner can see the model a little earlier, so use the same Entity
    -- part mapping as the fallback PrimaryPart instead of creating a
    -- Highlight against an incompletely initialized model.
    local root = object.PrimaryPart
    if not root then
        local candidate = getEntityPart(kind, object)
        if candidate and candidate:IsA("BasePart") then
            pcall(function()
                object.PrimaryPart = candidate
            end)
            root = object.PrimaryPart
        end
    end

    if root and root:IsA("BasePart") then
        root.Transparency = 0.999
        root.Material = Enum.Material.Plastic
    end
end

local function makeEntityHighlight(kind, object, entry)
    if not object or not object.Parent or not EntityVisualContainer then
        return false
    end

    -- Dupe is NOT part of Abyssal's RusherAliases. Therefore it must use
    -- the normal AddESP path: Highlight.Adornee = the actual DoorFake /
    -- FakeDoor model, with the standard 0.75 fill and no special
    -- HighlightHumanoid/PrimaryPart workaround.
    if kind == "Dupe" then
        if not object:IsA("Model") then
            return false
        end

        local color = Colors[kind] or Color3.new(1, 1, 1)

        -- Figure, Seek and Sally are animated/custom rigs. Never inject the
        -- Abyssal Rusher HighlightHumanoid into them: doing so can interfere
        -- with their existing Humanoid/Animator and freeze their animation.
        if entry.EntityHumanoid then
            pcall(function() entry.EntityHumanoid:Destroy() end)
            entry.EntityHumanoid = nil
        end

        local highlight = entry.EntityHighlight

        if not highlight or not highlight.Parent then
            highlight = Instance.new("Highlight")
            highlight.Name = "JustXDoorsDupeESP"
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Adornee = object
            highlight.Parent = EntityVisualContainer
            entry.EntityHighlight = highlight
            entry.Highlight = highlight
        else
            highlight.Adornee = object
        end

        highlight.FillColor = color
        highlight.OutlineColor = color
        highlight.FillTransparency = 0.75
        highlight.OutlineTransparency = 0
        highlight.Enabled = true

        return true
    end

    -- Abyssal does NOT put Figure into RusherAliases, so Figure must
    -- use the normal AddESP path. In particular, NEVER inject a
    -- HighlightHumanoid into Figure: Figure already owns its animation
    -- Humanoid/Animator, and an extra Humanoid can leave the rig's
    -- animations frozen.
    if kind == "Figure" or kind == "Seek" or kind == "SallyLingering" or kind == "SallyMoving" then
        if not object:IsA("Model") then
            return false
        end

        local color = Colors[kind] or Color3.new(1, 1, 1)

        -- These are animated/custom rigs. Never leave the Rusher-style
        -- HighlightHumanoid attached to them, because it can interfere
        -- with their real Humanoid/Animator.
        if entry.EntityHumanoid then
            pcall(function() entry.EntityHumanoid:Destroy() end)
            entry.EntityHumanoid = nil
        end

        local highlight = entry.EntityHighlight

        if not highlight or not highlight.Parent then
            highlight = Instance.new("Highlight")
            highlight.Name = "JustXDoors" .. kind .. "ESP"
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Adornee = object
            highlight.Parent = EntityVisualContainer
            entry.EntityHighlight = highlight
            entry.Highlight = highlight
        else
            highlight.Adornee = object
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        end

        highlight.FillColor = color
        highlight.OutlineColor = color
        highlight.FillTransparency = 0.75
        highlight.OutlineTransparency = 0
        highlight.Enabled = true

        return true
    end

    -- Screech and Snare use the normal Abyssal AddESP style.
    -- Do NOT inject HighlightHumanoid into these entities.
    if kind == "Screech" or kind == "Snare" or kind == "GlitchRush" or kind == "GlitchAmbush" then
        if not (object:IsA("Model") or object:IsA("BasePart")) then
            return false
        end

        local color = Colors[kind] or Color3.new(1, 1, 1)

        if entry.EntityHumanoid then
            pcall(function() entry.EntityHumanoid:Destroy() end)
            entry.EntityHumanoid = nil
        end

        local highlight = entry.EntityHighlight

        if not highlight or not highlight.Parent then
            highlight = Instance.new("Highlight")
            highlight.Name = "JustXDoors" .. kind .. "ESP"
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Adornee = object
            highlight.Parent = EntityVisualContainer
            entry.EntityHighlight = highlight
            entry.Highlight = highlight
        else
            highlight.Adornee = object
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        end

        highlight.FillColor = color
        highlight.OutlineColor = color
        highlight.FillTransparency = 0.75
        highlight.OutlineTransparency = 0
        highlight.Enabled = true

        return true
    end

    -- Rush/Ambush/Eyes/Dread use the special Abyssal-compatible renderer.
    -- Abyssal registers the Entity MODEL itself with AddESP, then adds
    -- HighlightHumanoid and makes its PrimaryPart transparent.
    local target = object

    if not target:IsA("Model") then
        return false
    end

    local color = Colors[kind] or Color3.new(1, 1, 1)
    local highlight = entry.EntityHighlight

    -- Match Abyssal's actual AddESP order:
    -- create/register the Highlight first, then add HighlightHumanoid and
    -- apply the transparent PrimaryPart workaround.
    if not highlight or not highlight.Parent then
        highlight = Instance.new("Highlight")
        highlight.FillTransparency = 1
        highlight.OutlineTransparency = 1
        highlight.Name = "JustXDoorsEntityESP"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Adornee = target
        highlight.Parent = EntityVisualContainer

        entry.EntityHighlight = highlight
        entry.Highlight = highlight
    else
        highlight.Adornee = target
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Enabled = true
    end

    prepareEntityForHighlight(kind, object, entry)

    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.Enabled = true

    return true
end

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
    if not drawer or #sources == 0 then
        destroyKeyProxy(entry)
        return false
    end

    -- A KeyObtain inside a Drawer is a special case. Highlight has a
    -- renderer conflict here when the parent Drawer also has a Highlight.
    -- Infinite Yield's partesp avoids that path entirely: it uses one
    -- BoxHandleAdornment per real BasePart with AlwaysOnTop enabled.
    -- Use the same primitive for hidden Drawer keys.
    destroyKeyProxy(entry)

    local boxes = {}
    local keyColor = Colors.Key or Color3.fromRGB(255,225,40)

    for index, source in ipairs(sources) do
        if source and source.Parent and source:IsA("BasePart") then
            local box = Instance.new("BoxHandleAdornment")
            box.Name = "JustXDoorsKeyDrawerESP_" .. tostring(index)
            box.Adornee = source
            box.AlwaysOnTop = true
            box.ZIndex = 10
            box.Size = source.Size
            box.Transparency = 0.3
            box.Color3 = keyColor
            box.Parent = VisualContainer
            boxes[#boxes + 1] = box
        end
    end

    if #boxes == 0 then
        return false
    end

    entry.KeyProxyBoxes = boxes
    -- Keep this field for compatibility with cleanup paths that already
    -- know about the old single-proxy Highlight.
    entry.KeyProxyHighlight = boxes

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

local function destroyEntityVisual(entry)
    if entry.EntityHighlight then
        pcall(function() entry.EntityHighlight:Destroy() end)
        entry.EntityHighlight = nil
    end

    if entry.EntityProxy then
        pcall(function() entry.EntityProxy:Destroy() end)
        entry.EntityProxy = nil
    end

    if entry.EntityHumanoid then
        pcall(function() entry.EntityHumanoid:Destroy() end)
        entry.EntityHumanoid = nil
    end

    entry.EntitySources = nil
    entry.Highlight = nil
end

local function buildEntityProxy(kind, object, entry)
    if not object or not object.Parent or not VisualContainer then
        return false
    end

    local target = object
    if kind == "Dread" then
        target = object:FindFirstChild("Main", true) or object
    end

    -- Build an isolated proxy from the entity's real BaseParts. This avoids
    -- relying on the game's own materials/transparency/renderer and leaves
    -- the original Entity completely untouched.
    local sources = {}
    if target:IsA("BasePart") then
        sources[1] = target
    elseif target:IsA("Model") then
        for _, descendant in ipairs(target:GetDescendants()) do
            if descendant:IsA("BasePart") and descendant.Size.Magnitude > 0.05 then
                sources[#sources + 1] = descendant
            end
        end
    end

    if #sources == 0 then
        return false
    end

    local proxy = entry.EntityProxy
    if not proxy or not proxy.Parent then
        if proxy then
            pcall(function() proxy:Destroy() end)
        end

        proxy = Instance.new("Model")
        proxy.Name = "JustXDoorsEntityProxy"

        local humanoid = Instance.new("Humanoid")
        humanoid.Name = "JustXDoorsEntityHighlightHumanoid"
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
        humanoid.NameDisplayDistance = 0
        humanoid.AutoRotate = false
        humanoid.Parent = proxy
        entry.EntityHumanoid = humanoid

        proxy.Parent = VisualContainer
        entry.EntityProxy = proxy
        entry.EntitySources = {}
    end

    -- Rebuild only when the source set changes.
    local sourceSet = entry.EntitySources or {}
    local same = true
    local count = 0
    for source in pairs(sourceSet) do
        count += 1
        if not source.Parent then
            same = false
            break
        end
    end
    if same and count ~= #sources then
        same = false
    end
    if same then
        for _, source in ipairs(sources) do
            if not sourceSet[source] then
                same = false
                break
            end
        end
    end

    if not same or count == 0 then
        for _, child in ipairs(proxy:GetChildren()) do
            if child:IsA("BasePart") then
                child:Destroy()
            end
        end

        sourceSet = {}
        for index, source in ipairs(sources) do
            local clone = source:Clone()
            clone.Name = "EntityProxyPart_" .. index
            clone.Transparency = 0.999
            clone.CanCollide = false
            clone.CanTouch = false
            clone.CanQuery = false
            clone.CastShadow = false
            clone.Anchored = false
            clone.Massless = true
            clone.Parent = proxy

            local weld = Instance.new("WeldConstraint")
            weld.Part0 = clone
            weld.Part1 = source
            weld.Parent = clone

            sourceSet[source] = clone
        end

        entry.EntitySources = sourceSet
    end

    local color = Colors[kind] or Color3.new(1, 1, 1)

    if not entry.EntityHighlight or not entry.EntityHighlight.Parent then
        local highlight = Instance.new("Highlight")
        highlight.Name = "JustXDoorsEntityESP"
        highlight.Adornee = proxy
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = color
        highlight.OutlineColor = color
        highlight.FillTransparency = 1
        highlight.OutlineTransparency = 0
        highlight.Enabled = true
        highlight.Parent = VisualContainer
        entry.EntityHighlight = highlight
    else
        entry.EntityHighlight.Adornee = proxy
        entry.EntityHighlight.FillColor = color
        entry.EntityHighlight.OutlineColor = color
        entry.EntityHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        entry.EntityHighlight.Enabled = true
    end

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
    local visualDistance = ENTITY_KINDS[kind] and ENTITY_VISUAL_DISTANCE or ITEM_KINDS[kind] and ITEM_VISUAL_DISTANCE or MAX_DISTANCE
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

    -- Entities use the direct Abyssal-style renderer.
    -- Items and Interactables below remain completely unchanged.
    if ENTITY_KINDS[kind] then
        if not near then
            destroyEntityVisual(entry)
            updateLabel(kind, object, entry)
            return true
        end

        if makeEntityHighlight(kind, object, entry) then
            updateLabel(kind, object, entry)
            return true
        end

        return false
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
        if kind == "Gold" then
            local goldHighlight = entry.Highlight
            if not goldHighlight or not goldHighlight.Parent or goldHighlight.Adornee ~= object then
                if goldHighlight then pcall(function() goldHighlight:Destroy() end) end
                goldHighlight = Instance.new("Highlight")
                goldHighlight.Name = "JustXDoorsGoldESP"
                goldHighlight.Adornee = object
                goldHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                goldHighlight.FillColor = Colors.Gold or Color3.fromRGB(255,215,0)
                goldHighlight.OutlineColor = Colors.Gold or Color3.fromRGB(255,215,0)
                goldHighlight.FillTransparency = 1
                goldHighlight.OutlineTransparency = 0
                goldHighlight.Enabled = true
                goldHighlight.Parent = VisualContainer
                entry.Highlight = goldHighlight
            else
                goldHighlight.FillColor = Colors.Gold or Color3.fromRGB(255,215,0)
                goldHighlight.OutlineColor = Colors.Gold or Color3.fromRGB(255,215,0)
                goldHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                goldHighlight.Enabled = true
            end
            updateLabel(kind, object, entry)
            return true
        end

        if ITEM_KINDS[kind] then
            -- Item ESP keeps its existing helper renderer. Entity ESP is
            -- deliberately excluded here: its renderer is the direct
            -- Abyssal-style Entity Highlight above.
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

    -- Items/interactables use outline-only Highlight. This is substantially
    -- cheaper visually than creating SelectionBoxes for every object.
    local adornee = object:IsA("Model") and object or getPart(object)
    if not adornee then return false end

    -- Some interactables use live interaction/prompt parts that can take
    -- over the Highlight renderer when the mobile finger prompt appears.
    -- Use the same isolated helper geometry as Items for those objects.
    -- Do not apply this to Drawers/Closets: their live Highlight behavior is
    -- intentionally kept because of the Key-inside-Drawer workaround.
    local HELPER_INTERACTABLES = {
        VentGate = true,
        Lever = true,
        Toolshed = true,
        Chest = true,
        LockedChest = true,
        Bed = true,
        Gold = true,
        Closets = true,
        GlitchCube = true,
    }

    if ITEM_KINDS[kind] or HELPER_INTERACTABLES[kind] then
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

        if Enabled.Drawers and (name == "Dresser" or name == "Dresser_Single" or name == "Table" or name == "Rolltop_Desk") then
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

        if name == "ChestBox" and Enabled.Chest then
            seen.Chest[object] = true
            addObject("Chest", object, room)
        elseif (name == "ChestBoxLocked" or name == "LockedChestBox") and Enabled.LockedChest then
            seen.LockedChest[object] = true
            addObject("LockedChest", object, room)
        end

        if Enabled.Bed and name == "Bed" then
            seen.Bed[object] = true
            addObject("Bed", object, room)
        end

        if Enabled.Key and name == "KeyObtain" then
            -- A key inside a Drawer can be missing ModulePrompt while it is
            -- stored/hidden by the drawer interaction system. The KeyObtain
            -- object itself is still the reliable marker.
            seen.Key[object] = true
            addObject("Key", object, room)
        end

        if Enabled.Gold and name == "GoldPile" then
            local minLevel = math.clamp(tonumber(Module.GoldMinLevel) or 1, 1, 6)
            local maxLevel = math.clamp(tonumber(Module.GoldMaxLevel) or 6, minLevel, 6)
            local hasNumericLevel = false
            local matchesRange = false

            for _, child in ipairs(object:GetChildren()) do
                local level = tonumber(child.Name)
                if level then
                    hasNumericLevel = true
                    if level >= minLevel and level <= maxLevel then
                        matchesRange = true
                    end
                end
            end

            -- The original working Gold ESP targeted GoldPile itself.
            -- Keep that target: its visible geometry is provided by the
            -- GoldVisualHolder hierarchy, while the numeric child is only
            -- the level selector.
            if matchesRange or not hasNumericLevel then
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

        if Enabled.Flashlight and name == "Flashlight" then
            local cursor = object.Parent
            local inRiftShop = false

            while cursor and cursor ~= room do
                if cursor.Name:lower():find("riftroom", 1, true) then
                    inRiftShop = true
                    break
                end
                cursor = cursor.Parent
            end

            if inRiftShop then
                seen.Flashlight[object] = true
                addObject("Flashlight", object, room)
            end
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

        if Enabled.GlitchCube and name == "GlitchCube" then
            seen.GlitchCube[object] = true
            addObject("GlitchCube", object, room)
        end

        if Enabled.LibraryPaper and name == "LibraryHintPaper" and room.Name == "50" then
            seen.LibraryPaper[object] = true
            addObject("LibraryPaper", object, room)
        end

        if Enabled.LibraryBook and name == "LiveHintBook" and room.Name == "50" then
            seen.LibraryBook[object] = true
            addObject("LibraryBook", object, room)
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

        -- Abyssal treats Dupe as an Entity and registers every FakeDoor /
        -- DoorFake instance individually. Do not use FindFirstChild here:
        -- one room can contain multiple Dupes with the same name.
        if Enabled.Dupe
            and (name == "DoorFake" or name == "FakeDoor")
            and object:FindFirstChild("Hidden")
        then
            seen.Dupe[object] = true
            addObject("Dupe", object, room)
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
    -- Entity instances can spawn multiple times at once. Do not use
    -- FindFirstChild here: it returns only one sibling with a given name.
    -- Abyssal-style ESP keeps an entry for every spawned entity.
    local globals = {
        RushMoving="Rush",
        AmbushMoving="Ambush",
        GlitchRush="GlitchRush",
        GlitchAmbush="GlitchAmbush",
        Eyes="Eyes",
        -- Lookman is intentionally not mapped here. It is a different
        -- entity and must not become Eyes ESP.
        Dread="Dread",
        SallyLingering="SallyLingering",
        SallyMoving="SallyMoving",
    }

    for _, object in ipairs(workspace:GetChildren()) do
        local kind = globals[object.Name]
        if kind and Enabled[kind] then
            seen[kind][object] = true
            addObject(kind, object, nil)
        end
    end

    -- Screech and GlitchScreech are rendered as physical models under
    -- workspace.Camera in the actual game. Keep their scan local to that
    -- container instead of searching every Workspace descendant.
    local cameraContainer = workspace:FindFirstChild("Camera")
    if cameraContainer then
        if Enabled.Screech then
            for _, object in ipairs(cameraContainer:GetChildren()) do
                if object.Name == "Screech"
                    and (object:IsA("Model") or object:IsA("BasePart"))
                then
                    seen.Screech[object] = true
                    addObject("Screech", object, nil)
                end
            end
        end

        if Enabled.GlitchScreech then
            for _, object in ipairs(cameraContainer:GetChildren()) do
                if object.Name == "GlitchScreech"
                    and (object:IsA("Model") or object:IsA("BasePart"))
                then
                    seen.GlitchScreech[object] = true
                    addObject("GlitchScreech", object, nil)
                end
            end
        end
    end

    if Enabled.Seek then
        -- SeekMovingNewClone is spawned directly under workspace in the
        -- observed hierarchy:
        --   workspace.SeekMovingNewClone
        --       ├─ SeekRig
        --       └─ Figure (MeshPart)
        -- Therefore scanning only CurrentRooms can never find it.
        -- Register the whole container so one Highlight covers both the
        -- Seek rig and its separate Figure MeshPart, without changing either
        -- animated object.
        for _, object in ipairs(workspace:GetDescendants()) do
            if object:IsA("Model") and object.Name == "SeekMovingNewClone" then
                local seekRig = object:FindFirstChild("SeekRig")
                local figurePart = object:FindFirstChild("Figure", true)

                if (seekRig and seekRig:IsA("Model"))
                    or (figurePart and figurePart:IsA("BasePart"))
                then
                    seen.Seek[object] = true
                    addObject("Seek", object, nil)
                end
            end
        end
    end

    if Rooms then
        for _, room in ipairs(Rooms:GetChildren()) do
            if Enabled.Figure then
                -- A room can contain FigureRig, Figure and FigureRagdoll
                -- instances. Abyssal registers all three names individually.
                for _, object in ipairs(room:GetDescendants()) do
                    if object:IsA("Model")
                        and (
                            object.Name == "FigureRig"
                            or object.Name == "Figure"
                            or object.Name == "FigureRagdoll"
                        )
                    then
                        seen.Figure[object] = true
                        addObject("Figure", object, room)
                    end
                end
            end

            if Enabled.Snare then
                -- There may be several Snares in the same room. Register
                -- every matching instance instead of only FindFirstChild().
                for _, object in ipairs(room:GetDescendants()) do
                    if object.Name == "Snare"
                        and (object:IsA("Model") or object:IsA("BasePart"))
                        and not (object.Parent and object.Parent.Name == "Snare")
                    then
                        seen.Snare[object] = true
                        addObject("Snare", object, room)
                    end
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
        Chest="Chest", LockedChest="LockedChest", Bed="Bed",
        ["Vent Gate"]="VentGate", Lever="Lever", Toolshed="Toolshed",
    }

    if state.All then
        for _, kind in pairs(map) do state[kind] = true end
    end

    for label, kind in pairs(map) do
        -- ValueDropdown items with sliders return their selected value/table
        -- instead of boolean true. Gold now has two sliders, so checking
        -- only == true silently disables Gold ESP.
        Enabled[kind] = state[label] ~= nil or state[kind] ~= nil
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
        ["Glitch Cube"]="GlitchCube", ["Library Paper"]="LibraryPaper", ["Library Book"]="LibraryBook",
    }

    for label, kind in pairs(map) do
        Enabled[kind] = state[label] == true or state[kind] == true
    end

    -- Gold has ValueDropdown dimensions now, so selected.Gold can be a
    -- table of slider values instead of boolean true.
    if type(selected) == "table" and selected.Gold ~= nil then
        Enabled.Gold = true
        local value = selected.Gold

        if type(value) == "table" then
            local minLevel = tonumber(
                value["Min Level"]
                or value.MinLevel
                or value.Min
                or value[1]
            )
            local maxLevel = tonumber(
                value["Max Level"]
                or value.MaxLevel
                or value.Max
                or value[2]
            )

            Module.GoldMinLevel = math.clamp(minLevel or Module.GoldMinLevel or 1, 1, 6)
            Module.GoldMaxLevel = math.clamp(maxLevel or Module.GoldMaxLevel or 6, 1, 6)
        else
            -- Backward compatibility with the old single Gold slider.
            Module.GoldMinLevel = math.clamp(tonumber(value) or 1, 1, 6)
            Module.GoldMaxLevel = math.max(Module.GoldMaxLevel or 6, Module.GoldMinLevel)
        end
    elseif state.Gold then
        Module.GoldMinLevel = Module.GoldMinLevel or 1
        Module.GoldMaxLevel = Module.GoldMaxLevel or 6
    end

    if Module.GoldMaxLevel < Module.GoldMinLevel then
        Module.GoldMaxLevel = Module.GoldMinLevel
    end

    queueScan()
end

local function setEntities(selected)
    local state = applySelection(selected)

    Enabled.Rush = state.Rush == true
    Enabled.Ambush = state.Ambush == true
    Enabled.GlitchRush = state["Glitch Rush"] == true or state.GlitchRush == true
    Enabled.GlitchAmbush = state["Glitch Ambush"] == true or state.GlitchAmbush == true
    Enabled.GlitchScreech = state["Glitch Screech"] == true or state.GlitchScreech == true
    Enabled.Dupe = state.Dupe == true
    Enabled.Eyes = state.Eyes == true
    Enabled.SallyLingering = state.Sally == true or state.SallyLingering == true
    Enabled.SallyMoving = state.Sally == true or state.SallyMoving == true
    Enabled.Seek = state.Seek == true
    Enabled.Figure = state.Figure == true
    Enabled.Snare = state.Snare == true
    Enabled.Screech = state.Screech == true
    Enabled.Dread = state.Dread == true

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

    local function isPromptNoise(object)
        if not object then return false end

        local name = object.Name
        if name == "ProximityPrompt"
            or name == "PromptHitbox"
            or name == "ModulePrompt"
            or name == "TouchInterest"
            or name == "TouchTransmitter"
        then
            return true
        end

        local className = object.ClassName
        return className == "ProximityPrompt"
    end

    local function onChange(object)
        -- Mobile ProximityPrompt/finger UI can create/remove helper objects.
        -- Those are deliberately excluded from item geometry, so rescanning
        -- the entire room for them only adds FPS spikes and can recreate
        -- visual state unnecessarily.
        if isPromptNoise(object) then
            return
        end
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
    connect(container.DescendantAdded, function(object)
        if object.Name ~= "ProximityPrompt"
            and object.Name ~= "PromptHitbox"
            and object.Name ~= "ModulePrompt"
        then
            queueScan()
        end
    end)

    connect(container.DescendantRemoving, function(object)
        if object.Name ~= "ProximityPrompt"
            and object.Name ~= "PromptHitbox"
            and object.Name ~= "ModulePrompt"
        then
            queueScan()
        end
    end)

    queueScan()
end

local function getEntityHiddenUI()
    -- Abyssal uses gethui() when available, otherwise CoreGui in executor
    -- environments and PlayerGui in ordinary Roblox LocalScript context.
    local ok, hidden = pcall(function()
        if type(gethui) == "function" then
            return gethui()
        end

        if type(getgenv) == "function" then
            return CoreGui
        end

        return LocalPlayer:FindFirstChildOfClass("PlayerGui")
    end)

    if ok and hidden then
        return hidden
    end

    return LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

local function setup()
    if VisualContainer then
        pcall(function() VisualContainer:Destroy() end)
    end
    if EntityVisualContainer then
        local screenGui = EntityVisualContainer.Parent
        pcall(function()
            if screenGui then screenGui:Destroy() end
        end)
        EntityVisualContainer = nil
    end

    VisualContainer = Instance.new("Folder")
    VisualContainer.Name = "JustXDoors_HotelESP"
    VisualContainer.Parent = workspace

    -- Use the same hidden UI route as Abyssal so Highlight is outside the
    -- game's Workspace hierarchy.
    local hiddenUI = getEntityHiddenUI()
    if hiddenUI then
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "JustXDoors_EntityESP"
        screenGui.ResetOnSpawn = false
        screenGui.IgnoreGuiInset = true
        screenGui.DisplayOrder = 32767

        local parented = pcall(function()
            screenGui.Parent = hiddenUI
        end)

        if parented and screenGui.Parent then
            EntityVisualContainer = Instance.new("Folder")
            EntityVisualContainer.Name = "Highlights"
            EntityVisualContainer.Parent = screenGui
        else
            pcall(function() screenGui:Destroy() end)
            EntityVisualContainer = nil
        end
    else
        EntityVisualContainer = nil
    end

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

    Module.GoldMinLevel = Module.GoldMinLevel or 1
    Module.GoldMaxLevel = Module.GoldMaxLevel or 6

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

    if EntityVisualContainer then
        local screenGui = EntityVisualContainer.Parent
        pcall(function()
            if screenGui then screenGui:Destroy() end
        end)
        EntityVisualContainer = nil
    end

    Rooms = nil
    Drops = nil
    ScanQueued = false
end

return Module
