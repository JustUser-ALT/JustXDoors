local Main = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Player = Players.LocalPlayer

local Core
local Tab
local Connections = {}
local Elements = {}

local Character
local Humanoid
local RootPart

local OldJump = false
local OldSlide = false

local SpeedBoostEnabled = false
local CurrentSpeedBoost = 0

local FlyEnabled = false
local FlyBody
local CurrentFlySpeed = 20

local InfiniteJumpEnabled = false
local InfiniteJumpButtonConnection

local RemoveAccelEnabled = false
local PartProperties = {}
local CustomPhysics

local FullBrightEnabled = false
local NoFogEnabled = false
local CurrentBrightness = 35

local LightingBackup
local AtmosphereBackup = {}

local ModifiedPrompts = {}
local PromptProperties = {}
local NoclipEnabled = false
local NoclipProperties = {}
local DoorReachEnabled = false
local AutoTpNextDoorEnabled = false

local AnticheatBypassEnabled = false
local AnticheatDisabled = false
local VelocityManipulationEnabled = false
local VelocityManipulationMode = "Velocity"
local ManipulateBody
local PositionSpoofEnabled = false
local CrouchSpoofEnabled = false
local OldHipHeight = 2.396
local getFloor
local isCrouching
local InfiniteItemsEnabled = false
local InfiniteItemsSelection = {}
local InfiniteItemConnections = {}
local FakePrompts = {}
local InfinitePromptObjects = {}
local Collision
local CollisionClone
local CollisionPart
local CollisionPartClone
local OriginalC1
local InfiniteCrucifixEnabled = false
local InfinitePromptContainer
local InfiniteCrucifixRaycastParams = RaycastParams.new()
InfiniteCrucifixRaycastParams.FilterType = Enum.RaycastFilterType.Exclude

local CrouchThrottle = 0

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Connections, connection)
    return connection
end

local function disconnect(connection)
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
    end
end

local function disconnectAll()
    for _, connection in ipairs(Connections) do
        disconnect(connection)
    end

    table.clear(Connections)

    disconnect(InfiniteJumpButtonConnection)
    InfiniteJumpButtonConnection = nil
end

local function getCharacter()
    Character = Player.Character or Player.CharacterAdded:Wait()
    Humanoid = Character:FindFirstChildOfClass("Humanoid")
    RootPart = Character:FindFirstChild("HumanoidRootPart")

    return Character
end

local function getRemotes()
    return ReplicatedStorage:FindFirstChild("RemotesFolder")
end

local function isInfiniteItemSelected(name)
    if type(InfiniteItemsSelection) ~= "table" then
        return false
    end

    if #InfiniteItemsSelection > 0 then
        for _, value in ipairs(InfiniteItemsSelection) do
            if value == name then
                return true
            end
        end
        return false
    end

    return InfiniteItemsSelection[name] == true
end

local InfiniteItemNames = {
    Lockpick = "Lockpicks",
    SkeletonKey = "Skeleton Key",
    Shears = "Shears",
    Multitool = "Multitool",
}

local InfiniteCrucifixRanges = {
    RushMoving = 90,
    AmbushMoving = 160,
    A60 = 140,
    A120 = 99,
    GlitchRush = 150,
    GlitchAmbush = 110,
}

local function getSelectedInfiniteTool()
    if not Character then
        return nil, nil
    end

    for toolName, displayName in pairs(InfiniteItemNames) do
        local tool = Character:FindFirstChild(toolName)
        if tool and isInfiniteItemSelected(displayName) then
            return tool, displayName
        end
    end

    return nil, nil
end

local function firePrompt(prompt)
    if not prompt then
        return
    end

    if type(fireproximityprompt) == "function" then
        pcall(function()
            fireproximityprompt(prompt)
        end)
    end
end

local InfinitePromptNames = {
    UnlockPrompt = true,
    SkullPrompt = true,
    LockPrompt = true,
    ThingToEnable = true,
    FusesPrompt = true,
}

local InfiniteTargetParents = {
    Lock = true,
    ChestBoxLocked = true,
    Cellar = true,
    Chest_Vine = true,
    CuttableVines = true,
    SkullLock = true,
    Toolbox_Locked = true,
    Lock1 = true,
    Lock2 = true,
}

local function isInfiniteItemTarget(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then
        return false
    end

    if InfinitePromptNames[prompt.Name] then
        return true
    end

    local parent = prompt.Parent
    local parentName = parent and parent.Name
    local grandParentName = parent and parent.Parent and parent.Parent.Name

    if InfiniteTargetParents[parentName] or InfiniteTargetParents[grandParentName] then
        return true
    end

    if grandParentName == "Locker_Small_Locked" and prompt.Name == "ActivateEventPrompt" then
        return true
    end

    return false
end

local function clearInfinitePrompts()
    for fake, real in pairs(FakePrompts) do
        if fake then
            pcall(function() fake:Destroy() end)
        end
        FakePrompts[fake] = nil
    end

    table.clear(InfinitePromptObjects)
end

local function makeInfinitePrompt(prompt)
    if not InfiniteItemsEnabled or type(fireproximityprompt) ~= "function" then
        return
    end

    if not isInfiniteItemTarget(prompt) or FakePrompts[prompt] or prompt:GetAttribute("JustXDoors_RealPrompt") then
        return
    end

    if not prompt.Parent or prompt.Parent:FindFirstChild("JustXDoors_InfPrompt") then
        return
    end

    local fake = prompt:Clone()
    fake.Name = "JustXDoors_InfPrompt"
    fake:SetAttribute("FakePrompt", true)
    fake:SetAttribute("JustXDoors_RealPrompt", true)
    fake.Enabled = prompt.Enabled
    fake.HoldDuration = prompt.HoldDuration
    fake.RequiresLineOfSight = prompt.RequiresLineOfSight
    fake.MaxActivationDistance = prompt.MaxActivationDistance
    fake.Parent = prompt.Parent

    FakePrompts[fake] = prompt
    InfinitePromptObjects[prompt] = fake

    if not InfinitePromptContainer then
        InfinitePromptContainer = Instance.new("Folder")
        InfinitePromptContainer.Name = "JustXDoorsPromptContainer"
        InfinitePromptContainer.Parent = Player:FindFirstChildOfClass("PlayerGui") or Player
    end

    prompt.Parent = InfinitePromptContainer

    local enabledConnection = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
        if fake.Parent then
            fake.Enabled = prompt.Enabled
        end
    end)

    table.insert(InfiniteItemConnections, enabledConnection)

    prompt.Destroying:Once(function()
        disconnect(enabledConnection)
        FakePrompts[fake] = nil
        InfinitePromptObjects[prompt] = nil
        pcall(function() fake:Destroy() end)
    end)
end

local function restoreInfinitePrompts()
    for fake, real in pairs(FakePrompts) do
        if real then
            pcall(function()
                if not real.Parent and fake.Parent then
                    real.Parent = fake.Parent
                end
                real.Enabled = true
            end)
        end
        pcall(function() fake:Destroy() end)
    end

    table.clear(FakePrompts)
    table.clear(InfinitePromptObjects)

    for _, connection in ipairs(InfiniteItemConnections) do
        disconnect(connection)
    end
    table.clear(InfiniteItemConnections)
end

local function setupInfiniteItems()
    restoreInfinitePrompts()

    if not InfinitePromptContainer then
        InfinitePromptContainer = Instance.new("Folder")
        InfinitePromptContainer.Name = "JustXDoorsPromptContainer"
        InfinitePromptContainer.Parent = Player:FindFirstChildOfClass("PlayerGui") or Player
    end

    if not InfiniteItemsEnabled or type(fireproximityprompt) ~= "function" then
        return
    end

    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") then
            makeInfinitePrompt(object)
        end
    end
end

local function handleInfinitePrompt(fake)
    if not InfiniteItemsEnabled or not fake or not fake:GetAttribute("FakePrompt") then
        return
    end

    local realPrompt = FakePrompts[fake]
    if not realPrompt or not realPrompt.Parent then
        return
    end

    local tool
    local toolData

    local itemNames = {
        Lockpick = "Lockpicks",
        Shears = "Shears",
        SkeletonKey = "Skeleton Key",
        Multitool = "Multitool",
    }

    for toolName, displayName in pairs(itemNames) do
        local candidate = Character and Character:FindFirstChild(toolName)
        if candidate and isInfiniteItemSelected(displayName) then
            tool = candidate
            toolData = displayName
            break
        end
    end

    if not tool or not toolData then
        firePrompt(realPrompt)
        return
    end

    local remotes = getRemotes()
    local dropRemote = remotes and remotes:FindFirstChild("DropItem")
    local drops = workspace:FindFirstChild("Drops")

    if not dropRemote or not dropRemote:IsA("RemoteEvent") or not drops then
        firePrompt(realPrompt)
        return
    end

    local fired = false
    local childConnection

    childConnection = drops.ChildAdded:Connect(function(newTool)
        if fired or not newTool then
            return
        end

        if newTool.Name ~= tool.Name and newTool.Name ~= "Multitool" and newTool.Name ~= "Shears" then
            return
        end

        fired = true
        disconnect(childConnection)

        task.defer(function()
            local prompt = newTool:FindFirstChild("ModulePrompt", true)
            if prompt then
                firePrompt(prompt)
            end
            firePrompt(realPrompt)
        end)
    end)

    task.delay(2, function()
        if not fired then
            disconnect(childConnection)
        end
    end)

    pcall(function()
        dropRemote:FireServer(tool)
    end)
end

local function tryInfiniteCrucifix()
    if not InfiniteCrucifixEnabled or not Character or not RootPart then
        return
    end

    local tool = Character:FindFirstChild("Crucifix")
    if not tool then
        return
    end

    local entity = workspace:FindFirstChild("RushMoving")
        or workspace:FindFirstChild("AmbushMoving")
        or workspace:FindFirstChild("A60")
        or workspace:FindFirstChild("A120")
        or workspace:FindFirstChild("GlitchRush")
        or workspace:FindFirstChild("GlitchAmbush")

    if not entity or not entity.PrimaryPart then
        return
    end

    local distance = (RootPart.Position - entity.PrimaryPart.Position).Magnitude
    local range = InfiniteCrucifixRanges[entity.Name]

    if not range or distance > range then
        return
    end

    InfiniteCrucifixRaycastParams.FilterDescendantsInstances = {Character, entity}

    local hit = workspace:Raycast(
        RootPart.Position,
        entity.PrimaryPart.Position - RootPart.Position,
        InfiniteCrucifixRaycastParams
    )

    if hit then
        return
    end

    local remotes = getRemotes()
    local dropRemote = remotes and remotes:FindFirstChild("DropItem")
    if not dropRemote or not dropRemote:IsA("RemoteEvent") then
        return
    end

    dropRemote:FireServer(tool)
end

local function tryInfiniteCrucifix()
    if not InfiniteCrucifixEnabled or not Character or not RootPart then
        return
    end

    local tool = Character:FindFirstChild("Crucifix")
    if not tool then
        return
    end

    local origin = RootPart.Position

    for _, entity in ipairs(workspace:GetChildren()) do
        local maxRange = InfiniteCrucifixRanges[entity.Name]

        if maxRange and entity.PrimaryPart then
            local target = entity.PrimaryPart.Position
            local distance = (origin - target).Magnitude

            if distance < maxRange + 40 then
                InfiniteCrucifixRaycastParams.FilterDescendantsInstances = { Character, entity }

                local hit = workspace:Raycast(
                    origin,
                    target - origin,
                    InfiniteCrucifixRaycastParams
                )

                if not hit then
                    task.spawn(function()
                        local remotes = getRemotes()
                        local dropRemote = remotes and remotes:FindFirstChild("DropItem")

                        if not dropRemote or not dropRemote:IsA("RemoteEvent") then
                            return
                        end

                        pcall(function()
                            dropRemote:FireServer(tool)
                        end)

                        local startTime = tick()

                        repeat
                            task.wait(0.01)

                            local drops = workspace:FindFirstChild("Drops")
                            local drop = drops and drops:FindFirstChild("Crucifix")
                            local prompt = drop and drop:FindFirstChildWhichIsA("ProximityPrompt", true)

                            if prompt then
                                firePrompt(prompt)
                            end

                            if Character and Character:FindFirstChild("Crucifix") then
                                break
                            end
                        until tick() - startTime > 1.2
                    end)

                    break
                end
            end
        end
    end
end

local function applyPositionSpoof(enabled)
    if not Character or not RootPart or not Humanoid then
        return
    end

    if getFloor() == "Fools" or getFloor() == "OldHotel" then
        return
    end

    if enabled then
        RootPart.CFrame = RootPart.CFrame * CFrame.new(0, -2.346, 0)
        OldHipHeight = Humanoid.HipHeight
        Humanoid.HipHeight = 0.05

        local remotes = getRemotes()
        local crouch = remotes and remotes:FindFirstChild("Crouch")
        if crouch and crouch:IsA("RemoteEvent") then
            crouch:FireServer(true, true)
        end
    else
        RootPart.CFrame = RootPart.CFrame * CFrame.new(0, 2.346, 0)
        Humanoid.HipHeight = OldHipHeight
    end
end

local function applyCrouchSpoof()
    local remotes = getRemotes()
    local crouch = remotes and remotes:FindFirstChild("Crouch")

    if crouch and crouch:IsA("RemoteEvent") then
        crouch:FireServer(CrouchSpoofEnabled and true or isCrouching(), true)
    end
end

local function setupManipulateBody()
    if ManipulateBody then
        pcall(function()
            ManipulateBody:Destroy()
        end)
    end

    ManipulateBody = Instance.new("BodyVelocity")
    ManipulateBody.Name = "JustXDoorsVelocityManipulation"
    ManipulateBody.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    ManipulateBody.Velocity = Vector3.zero
end

local function setupCollisionSpoof()
    if not Character then
        return
    end

    Collision = Character:FindFirstChild("Collision")
    CollisionPart = Character:FindFirstChild("CollisionPart") or Collision

    if not Collision or not Collision:IsA("BasePart") then
        return
    end

    if CollisionClone and CollisionClone.Parent ~= Character then
        CollisionClone = nil
    end

    if not CollisionClone then
        CollisionClone = Collision:Clone()
        CollisionClone.Name = "JustXDoorsCollisionClone"
        CollisionClone.Parent = Character
        CollisionClone.Massless = true
    end

    if CollisionPart and CollisionPart:IsA("BasePart") and not CollisionPartClone then
        CollisionPartClone = CollisionPart:Clone()
        CollisionPartClone.Name = "JustXDoorsCollisionPartClone"
        CollisionPartClone.CanCollide = false
        CollisionPartClone.Massless = true
        CollisionPartClone.Parent = Character
        local crouch = CollisionPartClone:FindFirstChild("CollisionCrouch")
        if crouch then crouch:Destroy() end
    end

    local lowerTorso = Character:FindFirstChild("LowerTorso")
    local rootMotor = lowerTorso and lowerTorso:FindFirstChild("Root")
    if rootMotor and OriginalC1 == nil then
        OriginalC1 = rootMotor.C1
    end
end

local function updateCollisionSpoof()
    if not Character or not RootPart then
        return
    end

    setupCollisionSpoof()

    if not Collision or not CollisionClone then
        return
    end

    if getFloor() == "Fools" or getFloor() == "OldHotel" then
        return
    end

    RootPart.CanCollide = false
    Collision.CanCollide = false

    local lowerTorso = Character:FindFirstChild("LowerTorso")
    local rootMotor = lowerTorso and lowerTorso:FindFirstChild("Root")

    if rootMotor and OriginalC1 then
        rootMotor.C1 = OriginalC1 * CFrame.new(0, PositionSpoofEnabled and -2.346 or 0, 0)
    end

    local spoofY = PositionSpoofEnabled and 2.328 or 0.18
    Collision.Position = RootPart.Position + Vector3.new(0, spoofY, 0)

    if CollisionPart and CollisionPart:IsA("BasePart") then
        CollisionPart.Position = RootPart.Position + Vector3.new(0, spoofY, 0)
    end

    local crouch = Collision:FindFirstChild("CollisionCrouch")
    local cloneCrouch = CollisionClone:FindFirstChild("CollisionCrouch")

    if crouch then
        crouch.CanCollide = false
        crouch.Position = RootPart.Position + Vector3.new(0, PositionSpoofEnabled and 1.328 or -0.982, 0)
    end

    if cloneCrouch then
        cloneCrouch.Position = RootPart.Position + Vector3.new(0, PositionSpoofEnabled and 0.75 or -0.982, 0)
    end

    CollisionClone.CollisionGroup = Collision.CollisionGroup
    CollisionClone.Position = RootPart.Position + Vector3.new(0, PositionSpoofEnabled and 1.75 or 0.18, 0)

    local crouching = isCrouching()
    CollisionClone.CanCollide = not (NoclipEnabled or VelocityManipulationEnabled or crouching)
    if cloneCrouch then
        cloneCrouch.CollisionGroup = Collision.CollisionGroup
        cloneCrouch.CanCollide = not (NoclipEnabled or VelocityManipulationEnabled or not crouching)
    end
end

local function resetAnticheatState()
    if AnticheatDisabled then
        local remotes = getRemotes()
        local climb = remotes and remotes:FindFirstChild("ClimbLadder")

        if climb and climb:IsA("RemoteEvent") then
            pcall(function()
                climb:FireServer()
            end)
        end
    end

    AnticheatDisabled = false
end

getFloor = function()
    local gameData = ReplicatedStorage:FindFirstChild("GameData")

    if not gameData then
        return "Hotel"
    end

    local floor = gameData:FindFirstChild("Floor")

    return floor and floor.Value or "Hotel"
end

local function getLiveModifiers()
    return workspace:FindFirstChild("LiveModifiers")
        or ReplicatedStorage:FindFirstChild("LiveModifiers")
end

isCrouching = function()
    if not Character then
        return false
    end

    local floor = getFloor()

    if floor == "Fools" or floor == "OldHotel" then
        return Character:GetAttribute("Crouching") == true
    end

    local collisionPart =
        Character:FindFirstChild("CollisionPart")
        or Character:FindFirstChild("Collision")

    if collisionPart and collisionPart:IsA("BasePart") then
        local success, group = pcall(function()
            return collisionPart.CollisionGroup
        end)

        if success and group == "PlayerCrouching" then
            return true
        end
    end

    return Character:GetAttribute("Crouching") == true
end

local function getInjuriesSpeed()
    if not Humanoid then
        return 0
    end

    return 0.075 * (Humanoid.MaxHealth - Humanoid.Health)
end

local function getCurrentSpeed()
    if not Character then
        return 15
    end

    local speed = 15

    speed += Character:GetAttribute("SpeedBoost") or 0
    speed += Character:GetAttribute("SpeedBoostBehind") or 0
    speed += Character:GetAttribute("SpeedBoostExtra") or 0

    if getFloor() == "Party" then
        speed += 10
    end

    local modifiers = getLiveModifiers()

    if modifiers then
        if modifiers:FindFirstChild("PlayerFast") then
            speed += 3
        end

        if modifiers:FindFirstChild("PlayerFaster") then
            speed += 6
        end

        if modifiers:FindFirstChild("PlayerFastest") then
            speed += 20
        end

        if modifiers:FindFirstChild("PlayerSlow") then
            speed -= 3
        end

        if modifiers:FindFirstChild("PlayerSlowHealth") then
            speed -= getInjuriesSpeed()
        end
    end

    if isCrouching() then
        if modifiers and modifiers:FindFirstChild("PlayerCrouchSlow") then
            speed -= 8
        elseif modifiers and modifiers:FindFirstChild("PlayerSlow") then
            speed -= 8
        else
            speed -= 5
        end
    end

    return math.max(speed, 0)
end

local function applySpeed()
    if not Humanoid or not Humanoid.Parent then
        return
    end

    local speed = getCurrentSpeed()

    if SpeedBoostEnabled then
        speed += CurrentSpeedBoost
    end

    Humanoid.WalkSpeed = math.max(speed, 0)
end

local function fireCrouchRemote()
    local now = tick()

    if now - CrouchThrottle < 0.1 then
        return
    end

    CrouchThrottle = now

    local remotes = ReplicatedStorage:FindFirstChild("RemotesFolder")

    if not remotes then
        return
    end

    local crouch = remotes:FindFirstChild("Crouch")

    if not crouch or not crouch:IsA("RemoteEvent") then
        return
    end

    pcall(function()
        crouch:FireServer(isCrouching(), true)
    end)
end

local function buildCustomPhysics()
    if not RootPart then
        return
    end

    local properties = RootPart.CustomPhysicalProperties

    CustomPhysics = PhysicalProperties.new(
        100,
        properties.Friction,
        properties.Elasticity,
        properties.FrictionWeight,
        properties.ElasticityWeight
    )
end

local function snapshotPartProperties()
    table.clear(PartProperties)

    if not Character then
        return
    end

    for _, part in ipairs(Character:GetDescendants()) do
        if part:IsA("BasePart") then
            PartProperties[part] = part.CustomPhysicalProperties
        end
    end
end

local function applyRemoveAcceleration()
    if not CustomPhysics then
        return
    end

    for part, original in pairs(PartProperties) do
        if part and part.Parent then
            pcall(function()
                if RemoveAccelEnabled then
                    part.CustomPhysicalProperties = CustomPhysics
                else
                    part.CustomPhysicalProperties = original
                end
            end)
        end
    end
end

local function setupFlyBody()
    if FlyBody then
        pcall(function()
            FlyBody:Destroy()
        end)
    end

    FlyBody = Instance.new("BodyVelocity")
    FlyBody.Name = "JustXDoorsFly"
    FlyBody.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    FlyBody.Velocity = Vector3.zero
end

local function getFlyDirection()
    local camera = workspace.CurrentCamera

    if not camera or not Humanoid then
        return Vector3.zero
    end

    local direction = Humanoid.MoveDirection

    if direction.Magnitude <= 0 then
        return Vector3.zero
    end

    local cameraLook = camera.CFrame.LookVector
    local cameraRight = camera.CFrame.RightVector

    local forward = Vector3.new(cameraLook.X, 0, cameraLook.Z)

    if forward.Magnitude <= 0 then
        return Vector3.zero
    end

    forward = forward.Unit

    local right = Vector3.new(cameraRight.X, 0, cameraRight.Z)

    if right.Magnitude > 0 then
        right = right.Unit
    end

    local x = direction:Dot(right)
    local z = direction:Dot(forward)

    local result = right * x + forward * z

    if result.Magnitude <= 0 then
        return Vector3.zero
    end

    return result.Unit
end

local function enableFly()
    getCharacter()

    if not RootPart or not Humanoid then
        return
    end

    FlyEnabled = true

    if not FlyBody then
        setupFlyBody()
    end
end

local function disableFly()
    FlyEnabled = false

    if FlyBody then
        FlyBody.Parent = nil

        pcall(function()
            FlyBody:Destroy()
        end)

        FlyBody = nil
    end

    if Humanoid then
        pcall(function()
            Humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end
end

local function tickFly()
    if not FlyEnabled or not FlyBody or not RootPart or not Humanoid then
        return
    end

    FlyBody.Parent = RootPart

    local movement = getFlyDirection()
    local vertical = 0

    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        vertical = CurrentFlySpeed
    elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.C)
    then
        vertical = -CurrentFlySpeed
    end

    FlyBody.Velocity =
        movement * CurrentFlySpeed
        + Vector3.new(0, vertical, 0)
end

local function applyJump(enabled)
    if not Character then
        return
    end

    Character:SetAttribute(
        "CanJump",
        enabled and true or OldJump
    )
end

local function applySlide(enabled)
    if not Character then
        return
    end

    Character:SetAttribute(
        "CanSlide",
        enabled and true or OldSlide
    )
end

local function saveLighting()
    if LightingBackup then
        return
    end

    LightingBackup = {
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogStart = Lighting.FogStart,
        FogEnd = Lighting.FogEnd,
        ExposureCompensation = Lighting.ExposureCompensation,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
        ColorShift_Top = Lighting.ColorShift_Top,
        GlobalShadows = Lighting.GlobalShadows,
    }

    table.clear(AtmosphereBackup)

    for _, object in ipairs(Lighting:GetChildren()) do
        if object:IsA("Atmosphere") then
            AtmosphereBackup[object] = {
                Density = object.Density,
                Haze = object.Haze,
                Glare = object.Glare,
            }
        end
    end
end

local function restoreLighting()
    if not LightingBackup then
        return
    end

    if FullBrightEnabled or NoFogEnabled then
        return
    end

    local backup = LightingBackup

    pcall(function()
        Lighting.Ambient = backup.Ambient
        Lighting.OutdoorAmbient = backup.OutdoorAmbient
        Lighting.Brightness = backup.Brightness
        Lighting.ClockTime = backup.ClockTime
        Lighting.FogStart = backup.FogStart
        Lighting.FogEnd = backup.FogEnd
        Lighting.ExposureCompensation = backup.ExposureCompensation
        Lighting.ColorShift_Bottom = backup.ColorShift_Bottom
        Lighting.ColorShift_Top = backup.ColorShift_Top
        Lighting.GlobalShadows = backup.GlobalShadows
    end)

    for object, values in pairs(AtmosphereBackup) do
        if object and object.Parent then
            pcall(function()
                object.Density = values.Density
                object.Haze = values.Haze
                object.Glare = values.Glare
            end)
        end
    end

    LightingBackup = nil
    table.clear(AtmosphereBackup)
end

local function getBrightnessValues(value)
    local alpha = math.clamp((value - 25) / 75, 0, 1)

    local ambient = 0.25 + alpha * 0.75
    local brightness = 0.5 + alpha * 5
    local exposure = -0.5 + alpha * 2

    return ambient, brightness, exposure
end

local function applyFullBright()
    if not FullBrightEnabled then
        return
    end

    saveLighting()

    local ambient, brightness, exposure =
        getBrightnessValues(CurrentBrightness)

    Lighting.Ambient = Color3.new(
        ambient,
        ambient,
        ambient
    )

    Lighting.OutdoorAmbient = Color3.new(
        ambient,
        ambient,
        ambient
    )

    Lighting.Brightness = brightness
    Lighting.ExposureCompensation = exposure
    Lighting.ClockTime = 14
    Lighting.GlobalShadows = false

    for _, object in ipairs(Lighting:GetChildren()) do
        if object:IsA("Atmosphere") then
            object.Density = 0
            object.Haze = 0
            object.Glare = 0
        end
    end
end

local function applyNoFog()
    if not NoFogEnabled then
        return
    end

    saveLighting()

    Lighting.FogStart = 0
    Lighting.FogEnd = 1000000

    for _, object in ipairs(Lighting:GetChildren()) do
        if object:IsA("Atmosphere") then
            object.Density = 0
            object.Haze = 0
            object.Glare = 0
        end
    end
end

local function applyPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") then
        return
    end

    if ModifiedPrompts[prompt] == nil then
        ModifiedPrompts[prompt] = prompt.HoldDuration
    end

    prompt.HoldDuration = 0
end

local function applyPromptReach(prompt, multiplier)
    if not prompt:IsA("ProximityPrompt") then
        return
    end

    if PromptProperties[prompt] == nil then
        PromptProperties[prompt] = {
            MaxActivationDistance = prompt.MaxActivationDistance,
            RequiresLineOfSight = prompt.RequiresLineOfSight,
        }
    end

    local original = PromptProperties[prompt]
    prompt.MaxActivationDistance = original.MaxActivationDistance * multiplier
end

local function applyPromptClip(prompt, enabled)
    if not prompt:IsA("ProximityPrompt") then
        return
    end

    if PromptProperties[prompt] == nil then
        PromptProperties[prompt] = {
            MaxActivationDistance = prompt.MaxActivationDistance,
            RequiresLineOfSight = prompt.RequiresLineOfSight,
        }
    end

    local original = PromptProperties[prompt]
    prompt.RequiresLineOfSight = enabled and false or original.RequiresLineOfSight
end

local function restorePromptProperties()
    for prompt, values in pairs(PromptProperties) do
        if prompt and prompt.Parent then
            pcall(function()
                prompt.MaxActivationDistance = values.MaxActivationDistance
                prompt.RequiresLineOfSight = values.RequiresLineOfSight
            end)
        end
    end
    table.clear(PromptProperties)
end

local function applyNoclip()
    if not Character or not Character.Parent then
        return
    end

    for _, object in ipairs(Character:GetDescendants()) do
        if object:IsA("BasePart") then
            if NoclipProperties[object] == nil then
                NoclipProperties[object] = object.CanCollide
            end

            if NoclipEnabled then
                object.CanCollide = false
            else
                object.CanCollide = NoclipProperties[object]
            end
        end
    end

    if not NoclipEnabled then
        table.clear(NoclipProperties)
    end
end

local function getNextClosedDoor()
    if not Character then
        return nil
    end

    local gameData = ReplicatedStorage:FindFirstChild("GameData")
    local latestRoom = gameData and gameData:FindFirstChild("LatestRoom")
    if not latestRoom then
        return nil
    end

    local startRoom = tonumber(latestRoom.Value)
    if not startRoom then
        return nil
    end

    local bestDoor
    local bestNumber = math.huge

    for _, object in ipairs(workspace:GetDescendants()) do
        if object.Name == "Door" and object:IsA("Model") then
            local open = object:GetAttribute("Open")
            if open == false or open == nil then
                local room = object.Parent
                local roomNumber = tonumber(room and room.Name)

                if roomNumber and roomNumber >= startRoom and roomNumber < bestNumber then
                    bestNumber = roomNumber
                    bestDoor = object
                end
            end
        end
    end

    return bestDoor
end

local function teleportNextDoor()
    getCharacter()

    local door = getNextClosedDoor()
    if not door or not Character then
        return
    end

    Character:PivotTo(door:GetPivot())
end

local function fireDoorReach()
    local currentRooms = workspace:FindFirstChild("CurrentRooms")
    local current = tonumber(Player:GetAttribute("CurrentRoom"))
    if not currentRooms or not current then
        return
    end

    local room = currentRooms:FindFirstChild(tostring(current))
    local door = room and room:FindFirstChild("Door")
    local openRemote = door and door:FindFirstChild("ClientOpen")
    local part = door and (door:FindFirstChild("Door") or door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart", true))

    if not openRemote or not openRemote:IsA("RemoteEvent") or not part or not RootPart then
        return
    end

    if (RootPart.Position - part.Position).Magnitude <= 75 then
        pcall(function()
            openRemote:FireServer()
        end)
    end
end

local function enableInstantInteract()
    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") then
            applyPrompt(object)
        end
    end
end

local function disableInstantInteract()
    for prompt, duration in pairs(ModifiedPrompts) do
        if prompt and prompt.Parent then
            pcall(function()
                prompt.HoldDuration = duration
            end)
        end
    end

    table.clear(ModifiedPrompts)
end

local function bindInfiniteJumpButton()
    disconnect(InfiniteJumpButtonConnection)
    InfiniteJumpButtonConnection = nil

    if not InfiniteJumpEnabled then
        return
    end

    local playerGui = Player:FindFirstChildOfClass("PlayerGui")

    if not playerGui then
        return
    end

    local mainUI = playerGui:FindFirstChild("MainUI")

    if not mainUI then
        return
    end

    local mainFrame = mainUI:FindFirstChild("MainFrame")

    if not mainFrame then
        return
    end

    local mobileButtons = mainFrame:FindFirstChild("MobileButtons")

    if not mobileButtons then
        return
    end

    local jumpButton = mobileButtons:FindFirstChild("JumpButton")

    if not jumpButton then
        return
    end

    InfiniteJumpButtonConnection =
        jumpButton.MouseButton1Down:Connect(function()
            if not InfiniteJumpEnabled then
                return
            end

            if not Humanoid or Humanoid.Health <= 0 then
                return
            end

            pcall(function()
                Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
        end)
end

local function createUI()
    Tab = Core:Tab({
        Name = "Main",
        Icon = "user",
        Type = "Grid",
    })

    if not Tab then
        return false
    end

    local characterPages = Tab:MultiSection({
        Pages = { "Character", "Bypass" },
        Column = 1,
        Icon = "user",
    })

    local character = characterPages:Page("Character")

    Elements.SpeedBoost = character:Slider({
        Name = "Speed Boost",
        Flag = "Main_SpeedBoost",
        Min = 0,
        Max = 100,
        Step = 1,
        Default = 0,

        Callback = function(value)
            CurrentSpeedBoost = value

            if SpeedBoostEnabled then
                applySpeed()
            end
        end,
    })

    Elements.FlySpeed = character:Slider({
        Name = "Fly Speed",
        Flag = "Main_FlySpeed",
        Min = 0,
        Max = 115,
        Step = 1,
        Default = 20,

        Callback = function(value)
            CurrentFlySpeed = value
        end,
    })

    Elements.SpeedBoostToggle = character:Toggle({
        Name = "Enable Speed Boost",
        Flag = "Main_SpeedBoostToggle",
        Default = false,

        Callback = function(value)
            SpeedBoostEnabled = value
            applySpeed()
            fireCrouchRemote()
        end,
    })

    Elements.RemoveAcceleration = character:Toggle({
        Name = "Remove Acceleration",
        Flag = "Main_RemoveAcceleration",
        Default = false,

        Callback = function(value)
            RemoveAccelEnabled = value

            if not CustomPhysics then
                buildCustomPhysics()
                snapshotPartProperties()
            end

            applyRemoveAcceleration()
        end,
    })

    Elements.Fly = character:Toggle({
        Name = "Fly",
        Flag = "Main_Fly",
        Default = false,

        Callback = function(value)
            if value then
                enableFly()
            else
                disableFly()
            end
        end,
    })

    Elements.Noclip = character:Toggle({
        Name = "Noclip",
        Flag = "Main_Noclip",
        Default = false,

        Callback = function(value)
            NoclipEnabled = value
            applyNoclip()
        end,
    })

    character:Divider()

    Elements.EnableJump = character:Toggle({
        Name = "Enable Jumping",
        Flag = "Main_EnableJump",
        Default = false,

        Callback = function(value)
            applyJump(value)
        end,
    })

    Elements.InfiniteJump = character:Toggle({
        Name = "Infinite Jump",
        Flag = "Main_InfiniteJump",
        Default = false,

        Callback = function(value)
            InfiniteJumpEnabled = value

            if value then
                bindInfiniteJumpButton()
            else
                disconnect(InfiniteJumpButtonConnection)
                InfiniteJumpButtonConnection = nil
            end
        end,
    })

    Elements.EnableSlide = character:Toggle({
        Name = "Enable Sliding",
        Flag = "Main_EnableSlide",
        Default = false,

        Callback = function(value)
            applySlide(value)
        end,
    })

    local bypass = characterPages:Page("Bypass")

    Elements.AnticheatBypass = bypass:Toggle({
        Name = "Anticheat Bypass",
        Flag = "Main_AnticheatBypass",
        Default = false,

        Callback = function(value)
            AnticheatBypassEnabled = value
            if not value then
                resetAnticheatState()
            end
        end,
    })

    Elements.VelocityManipulation = bypass:Toggle({
        Name = "Velocity Manipulation",
        Flag = "Main_VelocityManipulation",
        Default = false,

        Callback = function(value)
            VelocityManipulationEnabled = value
            if value and not ManipulateBody then
                setupManipulateBody()
            end
            if not value and ManipulateBody then
                ManipulateBody.Parent = nil
            end
        end,
    })

    Elements.VelocityManipulationMode = bypass:Dropdown({
        Name = "Manipulation Method",
        Flag = "Main_VelocityManipulationMode",
        Options = { "Velocity", "Pivot" },
        Default = "Velocity",
        Search = true,
        Callback = function(value)
            if type(value) == "table" then
                value = value[1] or value.Value
            end
            VelocityManipulationMode = value or "Velocity"
        end,
    })

    bypass:Divider()

    Elements.InfiniteItems = bypass:Toggle({
        Name = "Infinite Items",
        Flag = "Main_InfiniteItems",
        Default = false,

        Callback = function(value)
            InfiniteItemsEnabled = value
            setupInfiniteItems()
        end,
    })

    Elements.InfiniteItemsList = bypass:ValueDropdown({
        Name = "Item List",
        Flag = "Main_InfiniteItemsList",
        Options = {
            "Lockpicks",
            "Skeleton Key",
            "Shears",
            "Multitool",
        },
        MultiSelect = true,
        MaxSelect = 4,
        Default = {},
        Search = true,
        Callback = function(value)
            InfiniteItemsSelection = value or {}
        end,
    })

    bypass:Divider()

    Elements.InfiniteCrucifix = bypass:Toggle({
        Name = "Infinite Crucifix",
        Flag = "Main_InfiniteCrucifix",
        Default = false,

        Callback = function(value)
            InfiniteCrucifixEnabled = value
        end,
    })

    bypass:Divider()

    Elements.PositionSpoof = bypass:Toggle({
        Name = "Position Spoof",
        Flag = "Main_PositionSpoof",
        Default = false,

        Callback = function(value)
            PositionSpoofEnabled = value
            applyPositionSpoof(value)
        end,
    })

    Elements.CrouchSpoof = bypass:Toggle({
        Name = "Crouch Spoof",
        Flag = "Main_CrouchSpoof",
        Default = false,

        Callback = function(value)
            CrouchSpoofEnabled = value
            applyCrouchSpoof()
        end,
    })

    local visualPages = Tab:MultiSection({
        Pages = { "Visual", "Audio" },
        Column = 2,
        Icon = "eye",
    })

    local visual = visualPages:Page("Visual")

    Elements.FullBright = visual:Toggle({
        Name = "Fullbright",
        Flag = "Main_FullBright",
        Default = false,

        Callback = function(value)
            FullBrightEnabled = value

            if value then
                applyFullBright()
            elseif not NoFogEnabled then
                restoreLighting()
            end
        end,
    })

    Elements.Brightness = visual:Slider({
        Name = "Brightness",
        Flag = "Main_Brightness",
        Min = 25,
        Max = 100,
        Step = 1,
        Default = 35,

        Callback = function(value)
            CurrentBrightness = value

            if FullBrightEnabled then
                applyFullBright()
            end
        end,
    })

    Elements.NoFog = visual:Toggle({
        Name = "No Fog",
        Flag = "Main_NoFog",
        Default = false,

        Callback = function(value)
            NoFogEnabled = value

            if value then
                applyNoFog()

                if FullBrightEnabled then
                    applyFullBright()
                end
            elseif not FullBrightEnabled then
                restoreLighting()
            end
        end,
    })

    local audio = visualPages:Page("Audio")

    audio:Label({
        Text = "Audio features.",
    })

    local misc = Tab:Section({
        Title = "Misc",
        Column = 3,
        Icon = "settings-2",
    })

    if not misc then
        return false
    end

    Elements.InstantInteract = misc:Toggle({
        Name = "Instant Interact",
        Flag = "Main_InstantInteract",
        Default = false,

        Callback = function(value)
            if value then
                enableInstantInteract()
            else
                disableInstantInteract()
            end
        end,
    })

    Elements.InteractNoclip = misc:Toggle({
        Name = "Interact Noclip",
        Flag = "Main_InteractNoclip",
        Default = false,

        Callback = function(value)
            for _, prompt in ipairs(workspace:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") then
                    applyPromptClip(prompt, value)
                end
            end
        end,
    })

    Elements.InteractReach = misc:Slider({
        Name = "Interact Reach",
        Flag = "Main_InteractReach",
        Min = 1,
        Max = 2,
        Step = 0.1,
        Default = 1,

        Callback = function(value)
            for _, prompt in ipairs(workspace:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") then
                    applyPromptReach(prompt, value)
                end
            end
        end,
    })

    misc:Divider()

    Elements.DoorReach = misc:Toggle({
        Name = "Door Reach",
        Flag = "Main_DoorReach",
        Default = false,

        Callback = function(value)
            DoorReachEnabled = value
        end,
    })

    local gameSection = Tab:Section({
        Title = "Game",
        Column = 3,
        Icon = "gamepad-2",
    })

    if not gameSection then
        return false
    end

    gameSection:Button({
        Name = "Play Again",
        Callback = function()
            local remotes = ReplicatedStorage:FindFirstChild("RemotesFolder")
            local remote = remotes and remotes:FindFirstChild("PlayAgain")
            if remote and remote:IsA("RemoteEvent") then
                remote:FireServer()
            end
        end,
    })

    gameSection:Button({
        Name = "Return to Lobby",
        Callback = function()
            local remotes = ReplicatedStorage:FindFirstChild("RemotesFolder")
            local remote = remotes and remotes:FindFirstChild("Lobby")
            if remote and remote:IsA("RemoteEvent") then
                remote:FireServer()
            end
        end,
    })

    gameSection:Button({
        Name = "Revive",
        Callback = function()
            local remotes = ReplicatedStorage:FindFirstChild("RemotesFolder")
            local remote = remotes and remotes:FindFirstChild("Revive")
            if remote and remote:IsA("RemoteEvent") then
                remote:FireServer()
            end
        end,
    })

    gameSection:Button({
        Name = "Reset Character",
        Callback = function()
            local remotes = ReplicatedStorage:FindFirstChild("RemotesFolder")
            local underwater = remotes and remotes:FindFirstChild("Underwater")

            if underwater and underwater:IsA("RemoteEvent") then
                underwater:FireServer(true)
            elseif Humanoid then
                Humanoid.Health = 0
            end
        end,
    })

    local debugSection = Tab:Section({
        Title = "Debug",
        Column = 3,
        Icon = "bug",
    })

    if not debugSection then
        return false
    end

    debugSection:Button({
        Name = "Void",
        Callback = function()
            if not Character then
                return
            end

            local pivot = Character:GetPivot()
            local target = pivot + Vector3.new(0, -120 - pivot.Position.Y, 0)

            for _ = 1, 22 do
                Character:PivotTo(target)
            end
        end,
    })

    debugSection:Button({
        Name = "Exit Closet",
        Callback = function()
            local remotes = ReplicatedStorage:FindFirstChild("RemotesFolder")
            local camLock = remotes and remotes:FindFirstChild("CamLock")

            if camLock and camLock:IsA("RemoteEvent") then
                camLock:FireServer()
            end
        end,
    })

    debugSection:Button({
        Name = "Tp Next Door",
        Callback = teleportNextDoor,
    })

    Elements.AutoTpNextDoor = debugSection:Toggle({
        Name = "Auto Tp Next Door",
        Flag = "Main_AutoTpNextDoor",
        Default = false,
        Callback = function(value)
            AutoTpNextDoorEnabled = value
        end,
    })

    return true
end

local function setupConnections()
    getCharacter()

    if not Character then
        return
    end

    OldJump = Character:GetAttribute("CanJump") or false
    OldSlide = Character:GetAttribute("CanSlide") or false

    buildCustomPhysics()
    snapshotPartProperties()
    setupFlyBody()
    setupCollisionSpoof()

    connect(Player.CharacterAdded, function(character)
        Character = character

        Humanoid = character:WaitForChild("Humanoid", 10)
        RootPart = character:WaitForChild("HumanoidRootPart", 10)

        OldJump = character:GetAttribute("CanJump") or false
        OldSlide = character:GetAttribute("CanSlide") or false
        table.clear(NoclipProperties)

        task.wait(0.25)

        buildCustomPhysics()
        snapshotPartProperties()
        Collision = nil
        CollisionClone = nil
        CollisionPart = nil
        CollisionPartClone = nil
        OriginalC1 = nil
        setupCollisionSpoof()

        if FlyEnabled then
            disableFly()
            enableFly()
        end

        if RemoveAccelEnabled then
            applyRemoveAcceleration()
        end

        if SpeedBoostEnabled then
            applySpeed()
        end

        if Elements.EnableJump and Elements.EnableJump:Get() then
            applyJump(true)
        end

        if Elements.EnableSlide and Elements.EnableSlide:Get() then
            applySlide(true)
        end

        if NoclipEnabled then
            applyNoclip()
        end

        setupManipulateBody()

        if PositionSpoofEnabled then
            task.defer(function()
                applyPositionSpoof(true)
            end)
        end

        bindInfiniteJumpButton()
    end)

    connect(UserInputService.InputBegan, function(input, processed)
        if processed then
            return
        end

        if input.KeyCode ~= Enum.KeyCode.Space then
            return
        end

        if not InfiniteJumpEnabled then
            return
        end

        if not Humanoid or Humanoid.Health <= 0 then
            return
        end

        pcall(function()
            Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end)

    connect(UserInputService.JumpRequest, function()
        if not InfiniteJumpEnabled then
            return
        end

        if not Humanoid or Humanoid.Health <= 0 then
            return
        end

        task.defer(function()
            if InfiniteJumpEnabled and Humanoid and Humanoid.Health > 0 then
                pcall(function()
                    Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end)
            end
        end)
    end)

    connect(Character:GetAttributeChangedSignal("Climbing"), function()
        if AnticheatBypassEnabled and Character:GetAttribute("Climbing") == true and not AnticheatDisabled then
            task.wait(0.25)
            if AnticheatBypassEnabled and Character and Character.Parent and Character:GetAttribute("Climbing") == true then
                Character:SetAttribute("Climbing", false)
                AnticheatDisabled = true
            end
        end
    end)

    local remotes = getRemotes()
    if remotes then
        local cutscene = remotes:FindFirstChild("Cutscene")
        if cutscene and cutscene:IsA("RemoteEvent") then
            connect(cutscene.OnClientEvent, function(cutsceneName)
                if AnticheatDisabled and type(cutsceneName) == "string" and not cutsceneName:find("SewerSeek") then
                    AnticheatDisabled = false
                    if Core then
                        Core:Notify({
                            Title = "Anticheat",
                            Desc = "Anticheat re-enabled.",
                            Type = "Warning",
                            Duration = 3,
                        })
                    end
                end
            end)
        end

        local useEnemy = remotes:FindFirstChild("UseEnemyModule")
        if useEnemy and useEnemy:IsA("RemoteEvent") then
            connect(useEnemy.OnClientEvent, function(moduleName)
                if moduleName == "Void" or moduleName == "Glitch" then
                    AnticheatDisabled = false
                    local latestRoom = ReplicatedStorage:FindFirstChild("GameData")
                    latestRoom = latestRoom and latestRoom:FindFirstChild("LatestRoom")
                    if latestRoom then
                        pcall(function()
                            Player:SetAttribute("CurrentRoom", latestRoom.Value)
                        end)
                    end
                end
            end)
        end
    end

    connect(Player.PlayerGui.ChildAdded, function(object)
        if object.Name == "MainUI" then
            task.wait(0.1)
            bindInfiniteJumpButton()
        end
    end)

    connect(workspace.DescendantAdded, function(object)
        if object:IsA("ProximityPrompt") then
            task.defer(function()
                if not object.Parent then
                    return
                end

                if InfiniteItemsEnabled then
                    makeInfinitePrompt(object)
                end

                if Elements.InstantInteract and Elements.InstantInteract:Get() then
                    applyPrompt(object)
                end

                if Elements.InteractNoclip and Elements.InteractNoclip:Get() then
                    applyPromptClip(object, true)
                end

                if Elements.InteractReach then
                    applyPromptReach(object, Elements.InteractReach:Get() or 1)
                end
            end)
        end
    end)

    connect(ProximityPromptService.PromptTriggered, function(object)
        handleInfinitePrompt(object)
    end)

    connect(Lighting.ChildAdded, function(object)
        if object:IsA("Atmosphere")
            and (FullBrightEnabled or NoFogEnabled)
        then
            task.defer(function()
                object.Density = 0
                object.Haze = 0
                object.Glare = 0
            end)
        end
    end)

    connect(RunService.Heartbeat, function()
        if not Character or not Character.Parent then
            return
        end

        if not Humanoid or not Humanoid.Parent then
            return
        end

        if SpeedBoostEnabled then
            applySpeed()
            fireCrouchRemote()
        end

        if FlyEnabled then
            tickFly()
        elseif FlyBody and FlyBody.Parent then
            FlyBody.Parent = nil
        end

        if NoclipEnabled then
            applyNoclip()
        end

        if DoorReachEnabled then
            fireDoorReach()
        end

        if AutoTpNextDoorEnabled then
            local now = tick()
            if not Main._LastAutoTp or now - Main._LastAutoTp >= 0.15 then
                Main._LastAutoTp = now
                teleportNextDoor()
            end
        else
            Main._LastAutoTp = nil
        end
    end)

    connect(RunService.RenderStepped, function()
        updateCollisionSpoof()

        if VelocityManipulationEnabled and RootPart and Character then
            if not ManipulateBody then
                setupManipulateBody()
            end

            if VelocityManipulationMode == "Velocity" then
                ManipulateBody.Parent = RootPart
                ManipulateBody.Velocity = RootPart.CFrame.LookVector * 2.25
            else
                ManipulateBody.Parent = nil
                if getFloor() ~= "Fools" and getFloor() ~= "OldHotel" then
                    Character:PivotTo(workspace.CurrentCamera:GetPivot() * CFrame.new(0, 0, 2560))
                end
            end
        elseif ManipulateBody then
            ManipulateBody.Parent = nil
        end



        if InfiniteCrucifixEnabled then
            tryInfiniteCrucifix()
        end

        if CrouchSpoofEnabled or PositionSpoofEnabled then
            if tick() - CrouchThrottle > 0.1 then
                CrouchThrottle = tick()
                local remotes = getRemotes()
                local crouch = remotes and remotes:FindFirstChild("Crouch")
                if crouch and crouch:IsA("RemoteEvent") then
                    crouch:FireServer(true, true)
                end
            end
        end

        if FullBrightEnabled then
            applyFullBright()
        end

        if NoFogEnabled then
            applyNoFog()
        end
    end)

    task.defer(function()
        bindInfiniteJumpButton()
    end)
end

function Main:Init(core)
    if self.Initialized then
        return self
    end

    if type(core) ~= "table" then
        warn("[JustXDoors Main] Core is missing.")
        return self
    end

    Core = core

    local success, result = pcall(createUI)

    if not success or not result then
        warn("[JustXDoors Main] Failed to create UI: " .. tostring(result))
        return self
    end

    setupConnections()

    self.Initialized = true

    Core:Notify({
        Title = "Main",
        Desc = "Main module loaded.",
        Type = "Success",
        Duration = 3,
    })

    return self
end

function Main:Destroy()
    disableFly()
    disableInstantInteract()
    restorePromptProperties()
    NoclipEnabled = false
    table.clear(NoclipProperties)
    DoorReachEnabled = false
    AutoTpNextDoorEnabled = false
    AnticheatBypassEnabled = false
    resetAnticheatState()
    VelocityManipulationEnabled = false
    PositionSpoofEnabled = false
    CrouchSpoofEnabled = false
    InfiniteItemsEnabled = false
    InfiniteItemsSelection = {}
    InfiniteCrucifixEnabled = false
    restoreAllInfinitePrompts()
    for _, connection in ipairs(InfiniteItemConnections) do
        disconnect(connection)
    end
    table.clear(InfiniteItemConnections)

    if ManipulateBody then
        pcall(function()
            ManipulateBody:Destroy()
        end)
        ManipulateBody = nil
    end

    RemoveAccelEnabled = false
    applyRemoveAcceleration()

    FullBrightEnabled = false
    NoFogEnabled = false

    restoreLighting()

    disconnectAll()

    if Character then
        applyJump(false)
        applySlide(false)
    end

    table.clear(Elements)
    table.clear(PartProperties)
    table.clear(ModifiedPrompts)

    Tab = nil
    Core = nil

    self.Initialized = false
end

return Main
