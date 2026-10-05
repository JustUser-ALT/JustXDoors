local GameUI = {}

local RunService = game:GetService("RunService")

local Context
local Connections = {}
local Targets = {}

local Enabled = {
    Dresser = false,
    Table = false,
    Chest = false,
    ["Locked Chest"] = false,
}

local TARGET_OPTIONS = {
    "Dresser",
    "Table",
    "Chest",
    "Locked Chest",
}

local function disconnectAll()
    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(Connections)
end

local function clearTargets()
    table.clear(Targets)
end

local function getRooms()
    return workspace:FindFirstChild("CurrentRooms")
end

local function getPrompt(container)
    if not container then
        return nil
    end

    local knobs = container:FindFirstChild("Knobs")
    if knobs then
        local prompt = knobs:FindFirstChild("ActivateEventPrompt")
        if prompt and prompt:IsA("ProximityPrompt") then
            return prompt
        end
    end

    local prompt = container:FindFirstChild("ActivateEventPrompt", true)
    if prompt and prompt:IsA("ProximityPrompt") then
        return prompt
    end

    return nil
end

local function hasLootHolder(container)
    if not container then
        return false
    end

    return container:FindFirstChild("LootHolder", true) ~= nil
end

local function firePrompt(prompt)
    if not prompt or not prompt.Parent then
        return false
    end

    if not prompt:IsA("ProximityPrompt") then
        return false
    end

    local fire = fireproximityprompt
    if type(fire) ~= "function" then
        return false
    end

    local ok = pcall(function()
        fire(prompt)
    end)

    return ok
end

local function registerDrawerContainer(kind, drawerContainer, room)
    if not drawerContainer
        or not drawerContainer.Parent
        or not drawerContainer:IsA("Instance")
    then
        return
    end

    local prompt = getPrompt(drawerContainer)

    Targets[drawerContainer] = {
        Kind = kind,
        Container = drawerContainer,
        Room = room,
        Prompt = prompt,
        LastFire = 0,
    }
end

local function registerFurniture(object, room)
    if not object or not object.Parent then
        return
    end

    local name = object.Name
    if name ~= "Dresser" and name ~= "Table" then
        return
    end

    local kind = name
    if not Enabled[kind] then
        return
    end

    -- Dresser/Table can contain 1, 2 or 3 DrawerContainers.
    -- Register every container separately so one opened drawer does not
    -- stop the remaining drawers from being processed.
    for _, descendant in ipairs(object:GetDescendants()) do
        if descendant.Name == "DrawerContainer" then
            registerDrawerContainer(kind, descendant, room)
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

    if not Enabled[kind] then
        return
    end

    local prompt = getPrompt(object)
    if prompt then
        Targets[object] = {
            Kind = kind,
            Container = object,
            Room = room,
            Prompt = prompt,
            LastFire = 0,
        }
    end
end

local function registerObject(object, room)
    if not object then
        return
    end

    if object.Name == "Dresser" or object.Name == "Table" then
        registerFurniture(object, room)
    elseif object.Name == "ChestBox"
        or object.Name == "LockedChestBox"
        or object.Name == "ChestBoxLocked"
    then
        registerChest(object, room)
    end
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

local function scanRooms()
    local rooms = getRooms()
    if not rooms then
        return
    end

    for _, room in ipairs(rooms:GetChildren()) do
        if tonumber(room.Name) then
            for _, object in ipairs(room:GetDescendants()) do
                registerObject(object, room)
            end
        end
    end
end

local function cleanupTargets()
    for object, data in pairs(Targets) do
        local container = data.Container

        if not container
            or not container.Parent
            or not data.Room
            or not data.Room.Parent
        then
            Targets[object] = nil
        elseif not container:IsDescendantOf(data.Room) then
            Targets[object] = nil
        end
    end
end

local function processTargets()
    local now = os.clock()

    for object, data in pairs(Targets) do
        local container = data.Container

        if not container or not container.Parent then
            Targets[object] = nil
            continue
        end

        if not Enabled[data.Kind] then
            Targets[object] = nil
            continue
        end

        -- LootHolder is the completion marker. Once it exists, this
        -- particular drawer/chest is permanently considered looted and
        -- its prompt will never be fired again.
        if hasLootHolder(container) then
            Targets[object] = nil
            continue
        end

        local prompt = data.Prompt
        if not prompt or not prompt.Parent then
            prompt = getPrompt(container)
            data.Prompt = prompt
        end

        if prompt
            and prompt.Enabled
            and now - data.LastFire >= 0.15
        then
            if firePrompt(prompt) then
                data.LastFire = now
            end
        end
    end
end

local function setSelection(selected)
    for _, option in ipairs(TARGET_OPTIONS) do
        Enabled[option] = false
    end

    if type(selected) == "string" then
        if Enabled[selected] ~= nil then
            Enabled[selected] = true
        end
    elseif type(selected) == "table" then
        if #selected > 0 then
            for _, value in ipairs(selected) do
                if Enabled[value] ~= nil then
                    Enabled[value] = true
                end
            end
        else
            for _, option in ipairs(TARGET_OPTIONS) do
                Enabled[option] = selected[option] == true
            end
        end
    end

    clearTargets()
    scanRooms()
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

    local section = ctx.Tab:Section({
        Title = "Game",
        Column = 1,
        Icon = "joystick",
    })
    if not section then return false end

    ctx.Elements.AutoInteract = section:Dropdown({
        Name = "Auto Interact",
        Flag = "Hotel_AutoInteract",
        Options = TARGET_OPTIONS,
        MultiSelect = true,
        MaxSelect = #TARGET_OPTIONS,
        Default = {},
        Search = true,
        Callback = function(selected)
            setSelection(selected)
        end,
    })

    ctx.Elements.AutoLoot = section:Dropdown({
        Name = "Auto Loot",
        Flag = "Hotel_AutoLoot",
        Options = {},
        MultiSelect = true,
        MaxSelect = 8,
        Default = {},
        Search = true,
        Callback = function() end,
    })

    disconnectAll()
    clearTargets()

    local rooms = getRooms()
    if rooms then
        table.insert(Connections, rooms.DescendantAdded:Connect(function(object)
            local room = findRoom(object, rooms)
            if room then
                registerObject(object, room)
            end
        end))

        table.insert(Connections, rooms.DescendantRemoving:Connect(function(object)
            if Targets[object] then
                Targets[object] = nil
            end
        end))

        table.insert(Connections, rooms.ChildAdded:Connect(function(room)
            if room and room.Parent == rooms then
                task.defer(function()
                    if room.Parent == rooms then
                        for _, object in ipairs(room:GetDescendants()) do
                            registerObject(object, room)
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
                    scanRooms()
                end
            end)
        end
    end))

    table.insert(Connections, RunService.Heartbeat:Connect(function(dt)
        GameUI._Elapsed = (GameUI._Elapsed or 0) + dt

        if GameUI._Elapsed >= 0.15 then
            GameUI._Elapsed = 0
            cleanupTargets()
            processTargets()
        end
    end))

    return true
end

function GameUI:ReapplyEnabledFeatures()
    local element = Context and Context.Elements and Context.Elements.AutoInteract
    if not element or type(element.Get) ~= "function" then
        return
    end

    local ok, selected = pcall(function()
        return element:Get()
    end)

    if ok then
        setSelection(selected)
    end
end

function GameUI:Destroy()
    disconnectAll()
    clearTargets()
    GameUI._Elapsed = 0

    for _, option in ipairs(TARGET_OPTIONS) do
        Enabled[option] = false
    end

    Context = nil
end

return GameUI
