local AntiUI = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

local AntiRushEnabled = false
local AntiAmbushEnabled = false
local AntiDupeEnabled = false
local AntiDreadEnabled = false
local AntiScreechEnabled = false
local AntiGlitchScreechEnabled = false
local AntiHaltEnabled = false
local AntiSnareEnabled = false
local DetectionDistance = 150

local HeartbeatConnection
local CharacterConnection
local DupeConnection
local SnareConnection
local ScreechConnection
local GlitchScreechConnection
local CameraConnection
local SetPositionSpoof
local PositionSpoofState = false

local AntiEyesEnabled = false
local EyesRenderConnection
local EyesHookInstalled = false
local EyesCollisionBackup = setmetatable({}, {__mode = "k"})
local EntityConnection
local EntityRegistry = {}
local OriginalModuleNames = setmetatable({}, {__mode = "k"})
local SnareCanTouchBackup = setmetatable({}, {__mode = "k"})
local DupeCanTouchBackup = setmetatable({}, {__mode = "k"})

local function getFloorName()
    local gameData = game:GetService("ReplicatedStorage"):FindFirstChild("GameData")
    local floor = gameData and gameData:FindFirstChild("Floor")
    return floor and floor.Value or nil
end

local function eyesExists()
    return workspace:FindFirstChild("Eyes") ~= nil
end

local function applyEyesReplication(args)
    if not AntiEyesEnabled or not eyesExists() then
        return args
    end

    local floor = getFloorName()

    if floor == "Fools" or floor == "OldHotel" then
        args[1] = 0
        args[2] = -65
        args[3] = 0
        args[4] = false
    else
        args[1] = -650
        args[2] = nil
        args[3] = nil
        args[4] = nil
    end

    return args
end

local function syncEyesCollisionState()
    local character = Player.Character
    if not character then
        return
    end

    local collision = character:FindFirstChild("Collision")
    if collision and collision:IsA("BasePart") then
        if EyesCollisionBackup[collision] == nil then
            EyesCollisionBackup[collision] = collision.CanCollide
        end
        -- Abyssal keeps the main Collision part non-collidable on Hotel.
        collision.CanCollide = false
    end

    for _, object in ipairs(character:GetChildren()) do
        if object:IsA("BasePart") and object.Name ~= "HumanoidRootPart" then
            if EyesCollisionBackup[object] == nil then
                EyesCollisionBackup[object] = object.CanCollide
            end
            object.CanCollide = false
        end
    end
end

local function restoreEyesCollisionState()
    for object, value in pairs(EyesCollisionBackup) do
        if object and object.Parent then
            pcall(function()
                object.CanCollide = value
            end)
        end
        EyesCollisionBackup[object] = nil
    end
end

local function fireEyesBypass()
    if not AntiEyesEnabled or not eyesExists() then
        return
    end

    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("RemotesFolder")
    local motorReplication = remotes and remotes:FindFirstChild("MotorReplication")
    if not motorReplication or not motorReplication:IsA("RemoteEvent") then
        return
    end

    local floor = getFloorName()

    if floor == "Fools" or floor == "OldHotel" then
        motorReplication:FireServer(0, -65, 0, false)
    else
        motorReplication:FireServer(-650)
    end
end

local function installEyesHook()
    if EyesHookInstalled then
        return
    end

    if type(hookmetamethod) ~= "function"
        or type(getnamecallmethod) ~= "function"
        or type(newcclosure) ~= "function"
    then
        return
    end

    EyesHookInstalled = true

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()

        if AntiEyesEnabled
            and method == "FireServer"
            and self
            and self.Name == "MotorReplication"
            and eyesExists()
        then
            local args = { ... }
            applyEyesReplication(args)
            return oldNamecall(self, table.unpack(args))
        end

        return oldNamecall(self, ...)
    end))
end

local function setAntiEyes(value)
    AntiEyesEnabled = value == true

    if EyesRenderConnection then
        EyesRenderConnection:Disconnect()
        EyesRenderConnection = nil
    end

    if not AntiEyesEnabled then
        restoreEyesCollisionState()
        return
    end

    -- Match Abyssal's Hotel behavior directly:
    -- while Eyes exists, send the MotorReplication bypass every render frame.
    -- No health spoofing is used.
    installEyesHook()

    EyesRenderConnection = RunService.RenderStepped:Connect(function()
        if not AntiEyesEnabled then
            return
        end

        if eyesExists() then
            syncEyesCollisionState()
            fireEyesBypass()
        else
            restoreEyesCollisionState()
        end
    end)
end

local EntityNames = {
    RushMoving = 85,
    AmbushMoving = 150,
    GlitchRush = 90,
    GlitchAmbush = 175,
}

local function getCharacterRoot()
    local character = Player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getEntityPosition(entity)
    -- Match Abyssal: entity distance is measured from the entity's
    -- PrimaryPart, not an arbitrary descendant BasePart.
    if not entity or not entity:IsA("Model") then
        return nil
    end

    local primary = entity.PrimaryPart
    return primary and primary.Position or nil
end

local function isEntityNearby(entityName, maxDistance)
    local rootPart = getCharacterRoot()
    if not rootPart then return false end

    for _, entity in ipairs(workspace:GetChildren()) do
        if entity.Name == entityName then
            local position = getEntityPosition(entity)
            if position and (rootPart.Position - position).Magnitude <= maxDistance then
                return true
            end
        end
    end
    return false
end

local function shouldPositionSpoof()
    return (AntiRushEnabled
        and (isEntityNearby("RushMoving", 85) or isEntityNearby("GlitchRush", 90)))
        or (AntiAmbushEnabled
        and (isEntityNearby("AmbushMoving", 150) or isEntityNearby("GlitchAmbush", 175)))
end

local function setPositionSpoof(value)
    value = value == true
    if PositionSpoofState == value then return end
    PositionSpoofState = value
    if SetPositionSpoof then SetPositionSpoof(value) end
end

local function applyDupeBypass(object)
    if not AntiDupeEnabled then
        return
    end

    if not object or not (object:IsA("Model") or object:IsA("Folder")) then
        return
    end

    if object.Name ~= "DoorFake" and object.Name ~= "FakeDoor" then
        return
    end

    local hidden = object:FindFirstChild("Hidden")
    if hidden and hidden:IsA("BasePart") then
        if DupeCanTouchBackup[hidden] == nil then
            DupeCanTouchBackup[hidden] = hidden.CanTouch
        end
        hidden.CanTouch = false
    end

    local lock = object:FindFirstChild("Lock")
    if lock then
        local unlockPrompt = lock:FindFirstChild("UnlockPrompt")
        if unlockPrompt and unlockPrompt:IsA("ProximityPrompt") then
            if DupePromptEnabledBackup[unlockPrompt] == nil then
                DupePromptEnabledBackup[unlockPrompt] = unlockPrompt.Enabled
            end
            unlockPrompt.Enabled = false
        end
    end
end

local function getUIModules()
    local playerGui = Player:FindFirstChildOfClass("PlayerGui")
    local mainUI = playerGui and playerGui:FindFirstChild("MainUI")
    local initiator = mainUI and mainUI:FindFirstChild("Initiator")
    local mainGame = initiator and initiator:FindFirstChild("Main_Game")
    local remoteListener = mainGame and mainGame:FindFirstChild("RemoteListener")
    return remoteListener and remoteListener:FindFirstChild("Modules")
end

local function getDreadModule()
    local modules = getUIModules()
    return modules and (modules:FindFirstChild("Dread") or modules:FindFirstChild("Dread_Disabled"))
end

local function getScreechModule()
    local modules = getUIModules()
    return modules and (modules:FindFirstChild("Screech") or modules:FindFirstChild("Screech_Disabled"))
end

local function getGlitchScreechModule()
    local floorReplicated = game:GetService("ReplicatedStorage"):FindFirstChild("FloorReplicated")
    if not floorReplicated then return nil end
    return floorReplicated:FindFirstChild("GlitchScreech", true) or floorReplicated:FindFirstChild("GlitchScreech_Disabled", true)
end

-- Abyssal's exact Remove Halt implementation:
-- ReplicatedStorage.ClientModules.EntityModules.Shade
-- is renamed to Shade_Disabled while the toggle is enabled.
local function getHaltModule()
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local clientModules = replicatedStorage:FindFirstChild("ClientModules")
    local entityModules = clientModules and clientModules:FindFirstChild("EntityModules")
    if not entityModules then
        return nil
    end

    return entityModules:FindFirstChild("Shade")
        or entityModules:FindFirstChild("Shade_Disabled")
end

local function setModuleDisabled(module, disabled, normalName)
    if not module or not module:IsA("ModuleScript") then return end
    module.Name = disabled and (normalName .. "_Disabled") or normalName
end

local function clearScreechConnections()
    if ScreechConnection then pcall(function() ScreechConnection:Disconnect() end) end
    if GlitchScreechConnection then pcall(function() GlitchScreechConnection:Disconnect() end) end
    if CameraConnection then pcall(function() CameraConnection:Disconnect() end) end
    ScreechConnection = nil
    GlitchScreechConnection = nil
    CameraConnection = nil
end

local function removeScreechChildren(cameraContainer)
    if not cameraContainer then return end

    for _, object in ipairs(cameraContainer:GetChildren()) do
        if (AntiScreechEnabled and object.Name == "Screech")
            or (AntiGlitchScreechEnabled and object.Name == "GlitchScreech")
        then
            pcall(function() object:Destroy() end)
        end
    end
end

local function bindScreechContainer(cameraContainer)
    if not cameraContainer then return end

    removeScreechChildren(cameraContainer)

    if AntiScreechEnabled then
        ScreechConnection = cameraContainer.ChildAdded:Connect(function(object)
            if object.Name == "Screech" then
                task.defer(function()
                    if AntiScreechEnabled and object.Parent == cameraContainer then
                        pcall(function() object:Destroy() end)
                    end
                end)
            end
        end)
    end

    if AntiGlitchScreechEnabled then
        GlitchScreechConnection = cameraContainer.ChildAdded:Connect(function(object)
            if object.Name == "GlitchScreech" then
                task.defer(function()
                    if AntiGlitchScreechEnabled and object.Parent == cameraContainer then
                        pcall(function() object:Destroy() end)
                    end
                end)
            end
        end)
    end
end

local function setAntiScreech(value)
    AntiScreechEnabled = value == true
    clearScreechConnections()

    if AntiScreechEnabled or AntiGlitchScreechEnabled then
        local cameraContainer = workspace:FindFirstChild("Camera")
        if cameraContainer then
            bindScreechContainer(cameraContainer)
        end

        CameraConnection = workspace.ChildAdded:Connect(function(object)
            if object.Name ~= "Camera" then return end
            task.defer(function()
                if AntiScreechEnabled or AntiGlitchScreechEnabled then
                    bindScreechContainer(object)
                end
            end)
        end)
    end
end

local function setAntiGlitchScreech(value)
    AntiGlitchScreechEnabled = value == true
    setAntiScreech(AntiScreechEnabled)
end

local function setAntiDread(value)
    AntiDreadEnabled = value == true
    local module = getDreadModule()
    if module then setModuleDisabled(module, AntiDreadEnabled, "Dread") end
end

local function setAntiHalt(value)
    AntiHaltEnabled = value == true

    local module = getHaltModule()
    if module then
        -- This is Remove Halt, not No Halt Damage.
        setModuleDisabled(module, AntiHaltEnabled, "Shade")
    end
end

local function applySnareBypass(object)
    if not AntiSnareEnabled or not object or object.Name ~= "Snare" then
        return
    end

    for _, part in ipairs(object:GetDescendants()) do
        if part:IsA("BasePart") then
            if SnareCanTouchBackup[part] == nil then
                SnareCanTouchBackup[part] = part.CanTouch
            end
            part.CanTouch = false
        end
    end
end

local function setAntiSnare(value)
    AntiSnareEnabled = value == true

    if SnareConnection then
        SnareConnection:Disconnect()
        SnareConnection = nil
    end

    if AntiSnareEnabled then
        for _, object in ipairs(workspace:GetDescendants()) do
            if object.Name == "Snare" then
                applySnareBypass(object)
            end
        end

        SnareConnection = workspace.DescendantAdded:Connect(function(object)
            if object.Name ~= "Snare" then
                return
            end

            task.defer(function()
                applySnareBypass(object)
            end)
        end)
    else
        for part, original in pairs(SnareCanTouchBackup) do
            if part and part.Parent then
                pcall(function()
                    part.CanTouch = original
                end)
            end
        end
        table.clear(SnareCanTouchBackup)
    end
end

local function setDupeBypass(value)
    AntiDupeEnabled = value == true

    if DupeConnection then
        DupeConnection:Disconnect()
        DupeConnection = nil
    end

    if AntiDupeEnabled then
        -- Exact Abyssal behavior: update every existing fake Dupe door.
        for _, object in ipairs(workspace:GetDescendants()) do
            applyDupeBypass(object)
        end

        -- Keep the bypass active for Dupe doors that spawn later.
        DupeConnection = workspace.DescendantAdded:Connect(function(object)
            if object.Name ~= "DoorFake" and object.Name ~= "FakeDoor" then
                return
            end

            task.defer(function()
                applyDupeBypass(object)
            end)
        end)
    else
        -- Restore exactly what was present before Anti Dupe touched it.
        for part, original in pairs(DupeCanTouchBackup) do
            if part and part.Parent then
                pcall(function()
                    part.CanTouch = original
                end)
            end
        end
        table.clear(DupeCanTouchBackup)

        for prompt, original in pairs(DupePromptEnabledBackup) do
            if prompt and prompt.Parent then
                pcall(function()
                    prompt.Enabled = original
                end)
            end
        end
        table.clear(DupePromptEnabledBackup)
    end
end

local function updateAnti()
    setPositionSpoof(shouldPositionSpoof())
end

local function start()
    if HeartbeatConnection then HeartbeatConnection:Disconnect() end
    if EntityConnection then EntityConnection:Disconnect() end

    HeartbeatConnection = RunService.Heartbeat:Connect(updateAnti)

    local replicatedStorage = game:GetService("ReplicatedStorage")
    local connections = {}

    -- Screech and GlitchScreech are actual runtime models under
    -- workspace.Camera. Anti simply removes those models instead of
    -- renaming ModuleScripts.
    local function removeCameraEntity(object)
        if not object then return end
        if AntiScreechEnabled and object.Name == "Screech" then
            pcall(function() object:Destroy() end)
            return
        end
        if AntiGlitchScreechEnabled and object.Name == "GlitchScreech" then
            pcall(function() object:Destroy() end)
        end
    end

    local function scanCameraEntities()
        local cameraContainer = workspace:FindFirstChild("Camera")
        if not cameraContainer then return end

        for _, object in ipairs(cameraContainer:GetDescendants()) do
            removeCameraEntity(object)
        end
    end

    local function bindCameraContainer(cameraContainer)
        if not cameraContainer then return end

        table.insert(connections, cameraContainer.DescendantAdded:Connect(function(object)
            task.defer(removeCameraEntity, object)
        end))

        scanCameraEntities()
    end

    local cameraContainer = workspace:FindFirstChild("Camera")
    if cameraContainer then
        bindCameraContainer(cameraContainer)
    end

    table.insert(connections, workspace.ChildAdded:Connect(function(object)
        if object.Name ~= "Camera" then return end

        task.defer(function()
            if not object:IsA("Model") and not object:IsA("Folder") then return end
            bindCameraContainer(object)
        end)
    end))

    -- Dread remains module-based.
    local function handleDreadModule(object)
        if not object or not object:IsA("ModuleScript") then
            return
        end

        if AntiDreadEnabled
            and (object.Name == "Dread" or object.Name == "Dread_Disabled")
        then
            setModuleDisabled(object, true, "Dread")
        end
    end

    local function handleHaltModule(object)
        if not object or not object:IsA("ModuleScript") then
            return
        end

        if AntiHaltEnabled
            and (object.Name == "Shade" or object.Name == "Shade_Disabled")
            and object.Parent
            and object.Parent.Name == "EntityModules"
        then
            -- Exact Abyssal behavior: disable the Shade module by name.
            setModuleDisabled(object, true, "Shade")
        end
    end

    table.insert(connections, replicatedStorage.DescendantAdded:Connect(function(object)
        if object.Name == "Dread" or object.Name == "Dread_Disabled" then
            task.defer(handleDreadModule, object)
        end

        if object.Name == "Shade" or object.Name == "Shade_Disabled" then
            task.defer(handleHaltModule, object)
        end
    end))

    local playerGui = Player:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        table.insert(connections, playerGui.DescendantAdded:Connect(function(object)
            if object.Name == "Dread" or object.Name == "Dread_Disabled" then
                task.defer(handleDreadModule, object)
            end
        end))
    end

    local modules = getUIModules()
    if modules then
        for _, object in ipairs(modules:GetChildren()) do
            handleDreadModule(object)
        end
    end

    local haltModule = getHaltModule()
    if haltModule and AntiHaltEnabled then
        setModuleDisabled(haltModule, true, "Shade")
    end

    EntityConnection = {
        Disconnect = function()
            for _, connection in ipairs(connections) do
                pcall(function() connection:Disconnect() end)
            end
        end
    }

    if CharacterConnection then CharacterConnection:Disconnect() end
    CharacterConnection = Player.CharacterAdded:Connect(function()
        setPositionSpoof(false)
        task.defer(function()
            if AntiScreechEnabled then setAntiScreech(true) end
            if AntiGlitchScreechEnabled then setAntiGlitchScreech(true) end
            if AntiDreadEnabled then setAntiDread(true) end
            if AntiHaltEnabled then setAntiHalt(true) end
            if AntiEyesEnabled and eyesExists() then
                fireEyesBypass()
            end
        end)
    end)

    if AntiScreechEnabled then setAntiScreech(true) end
    if AntiGlitchScreechEnabled then setAntiGlitchScreech(true) end
    if AntiDreadEnabled then setAntiDread(true) end
    if AntiHaltEnabled then setAntiHalt(true) end
end

function AntiUI:Create(ctx)
    local pages = ctx.EntityPages
    if not pages then return false end

    local page = pages:Page("Anti")
    if not page then return false end

    SetPositionSpoof = ctx.SetPositionSpoof
    ctxElements = ctx.Elements

    ctx.Elements.AntiRush = page:Toggle({
        Name = "Anti Rush",
        Flag = "Hotel_AntiRush",
        Default = false,
        Callback = function(value)
            AntiRushEnabled = value == true
            updateAnti()
        end,
    })

    ctx.Elements.AntiAmbush = page:Toggle({
        Name = "Anti Ambush",
        Flag = "Hotel_AntiAmbush",
        Default = false,
        Callback = function(value)
            AntiAmbushEnabled = value == true
            updateAnti()
        end,
    })

    ctx.Elements.AntiEyes = page:Toggle({
        Name = "Anti Eyes",
        Flag = "Hotel_AntiEyes",
        Default = false,
        Callback = function(value)
            setAntiEyes(value)
        end,
    })

    ctx.Elements.AntiDread = page:Toggle({
        Name = "Anti Dread",
        Flag = "Hotel_AntiDread",
        Default = false,
        Callback = function(value)
            setAntiDread(value)
        end,
    })

    ctx.Elements.RemoveHalt = page:Toggle({
        Name = "Remove Halt",
        Flag = "Hotel_RemoveHalt",
        Default = false,
        Callback = function(value)
            setAntiHalt(value)
        end,
    })

    ctx.Elements.AntiScreech = page:Toggle({
        Name = "Anti Screech",
        Flag = "Hotel_AntiScreech",
        Default = false,
        Callback = function(value)
            setAntiScreech(value)
        end,
    })

    ctx.Elements.AntiGlitchScreech = page:Toggle({
        Name = "Anti Glitch Screech",
        Flag = "Hotel_AntiGlitchScreech",
        Default = false,
        Callback = function(value)
            setAntiGlitchScreech(value)
        end,
    })

    ctx.Elements.AntiSnare = page:Toggle({
        Name = "Anti Snare",
        Flag = "Hotel_AntiSnare",
        Default = false,
        Callback = function(value)
            setAntiSnare(value)
        end,
    })

    ctx.Elements.AntiDupe = page:Toggle({
        Name = "Anti Dupe",
        Flag = "Hotel_AntiDupe",
        Default = false,
        Callback = function(value)
            setDupeBypass(value)
        end,
    })

    page:Label({
        Text = "Anti Rush / Ambush uses Position Spoof within 150 studs. Anti Dupe disables fake-door damage. Anti Dread disables the Dread module. Remove Halt disables the Shade module so Halt does not spawn. Anti Screech disables Screech. Anti Glitch Screech disables GlitchScreech. Anti Snare disables Snare touch damage. Anti Eyes bypasses Eyes only; Lookman is not affected.",
    })

    start()
    return true
end

function AntiUI:ReapplyEnabledFeatures()
    local function enabled(element)
        if not element or type(element.Get) ~= "function" then return false end
        local ok, value = pcall(function() return element:Get() end)
        return ok and value == true
    end

    if ctxElements then
        setAntiEyes(enabled(ctxElements.AntiEyes))
        setAntiDread(enabled(ctxElements.AntiDread))
        setAntiHalt(enabled(ctxElements.RemoveHalt))
        setAntiScreech(enabled(ctxElements.AntiScreech))
        setAntiGlitchScreech(enabled(ctxElements.AntiGlitchScreech))
        setAntiSnare(enabled(ctxElements.AntiSnare))
        setDupeBypass(enabled(ctxElements.AntiDupe))
        AntiRushEnabled = enabled(ctxElements.AntiRush)
        AntiAmbushEnabled = enabled(ctxElements.AntiAmbush)
        updateAnti()
    end
end

function AntiUI:Destroy()
    clearScreechConnections()
    AntiRushEnabled = false
    AntiAmbushEnabled = false
    AntiEyesEnabled = false
    AntiDreadEnabled = false
    AntiHaltEnabled = false
    AntiScreechEnabled = false
    AntiGlitchScreechEnabled = false
    AntiSnareEnabled = false

    setAntiEyes(false)
    setAntiDread(false)
    setAntiHalt(false)
    setAntiScreech(false)
    setAntiGlitchScreech(false)
    setAntiSnare(false)
    setPositionSpoof(false)
    setDupeBypass(false)

    if HeartbeatConnection then
        HeartbeatConnection:Disconnect()
        HeartbeatConnection = nil
    end

    if CharacterConnection then
        CharacterConnection:Disconnect()
        CharacterConnection = nil
    end

    SetPositionSpoof = nil
    PositionSpoofState = false

    table.clear(SnareCanTouchBackup)
    table.clear(DupeCanTouchBackup)
    table.clear(DupePromptEnabledBackup)
    table.clear(OriginalModuleNames)
end

return AntiUI
