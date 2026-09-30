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

local RemoveFootstepSoundsEnabled = false
local RemoveInteractingSoundsEnabled = false
local RemoveJamminMusicEnabled = false
local FootstepConnection
local JamMuffle

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
local CollisionCanCollideBackup = {}
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

local function setFootstepSoundVolume(sound, muted)
    if sound and sound:IsA("Sound") and sound.Name == "Sound" then
        sound.Volume = muted and 0 or sound:GetAttribute("JustXDoors_FootstepVolume") or sound.Volume
    end
end

local function applyRemoveFootstepSounds()
    if not Character then
        return
    end

    for _, object in ipairs(Character:GetChildren()) do
        if object:IsA("Sound") and object.Name == "Sound" then
            if object:GetAttribute("JustXDoors_FootstepVolume") == nil then
                object:SetAttribute("JustXDoors_FootstepVolume", object.Volume)
            end
            object.Volume = RemoveFootstepSoundsEnabled and 0 or object:GetAttribute("JustXDoors_FootstepVolume")
        end
    end
end

local function setupFootstepSounds()
    disconnect(FootstepConnection)
    FootstepConnection = nil

    if not Character then
        return
    end

    FootstepConnection = Character.ChildAdded:Connect(function(object)
        if object:IsA("Sound") and object.Name == "Sound" then
            if object:GetAttribute("JustXDoors_FootstepVolume") == nil then
                object:SetAttribute("JustXDoors_FootstepVolume", object.Volume)
            end

            if RemoveFootstepSoundsEnabled then
                object.Volume = 0
            end
        end
    end)

    applyRemoveFootstepSounds()
end

local function applyRemoveInteractingSounds()
    local playerGui = Player:FindFirstChildOfClass("PlayerGui")
    local mainUI = playerGui and playerGui:FindFirstChild("MainUI")
    local initiator = mainUI and mainUI:FindFirstChild("Initiator")
    local mainGame = initiator and initiator:FindFirstChild("Main_Game")

    if not mainGame then
        return
    end

    local promptService = mainGame:FindFirstChild("PromptService")
    if promptService then
        local triggered = promptService:FindFirstChild("Triggered")
        local holding = promptService:FindFirstChild("Holding")
        local notification = promptService:FindFirstChild("Notification")

        if triggered and triggered:IsA("Sound") then
            if triggered:GetAttribute("JustXDoors_OriginalVolume") == nil then
                triggered:SetAttribute("JustXDoors_OriginalVolume", triggered.Volume)
            end
            triggered.Volume = RemoveInteractingSoundsEnabled and 0 or triggered:GetAttribute("JustXDoors_OriginalVolume")
        end

        if holding and holding:IsA("Sound") then
            if holding:GetAttribute("JustXDoors_OriginalVolume") == nil then
                holding:SetAttribute("JustXDoors_OriginalVolume", holding.Volume)
            end
            holding.Volume = RemoveInteractingSoundsEnabled and 0 or holding:GetAttribute("JustXDoors_OriginalVolume")
        end

        if notification and notification:IsA("Sound") then
            if notification:GetAttribute("JustXDoors_OriginalVolume") == nil then
                notification:SetAttribute("JustXDoors_OriginalVolume", notification.Volume)
            end
            notification.Volume = RemoveInteractingSoundsEnabled and 0 or notification:GetAttribute("JustXDoors_OriginalVolume")
        end
    end

    local reminder = mainGame:FindFirstChild("Reminder")
    local caption = reminder and reminder:FindFirstChild("Caption")

    if caption and caption:IsA("Sound") then
        if caption:GetAttribute("JustXDoors_OriginalVolume") == nil then
            caption:SetAttribute("JustXDoors_OriginalVolume", caption.Volume)
        end
        caption.Volume = RemoveInteractingSoundsEnabled and 0 or caption:GetAttribute("JustXDoors_OriginalVolume")
    end
end

local function applyRemoveJamminMusic()
    local playerGui = Player:FindFirstChildOfClass("PlayerGui")
    local mainUI = playerGui and playerGui:FindFirstChild("MainUI")
    local initiator = mainUI and mainUI:FindFirstChild("Initiator")
    local mainGame = initiator and initiator:FindFirstChild("Main_Game")
    local health = mainGame and mainGame:FindFirstChild("Health")
    local jam = health and health:FindFirstChild("Jam")

    if jam and jam:IsA("Sound") then
        if jam:GetAttribute("JustXDoors_OriginalVolume") == nil then
            jam:SetAttribute("JustXDoors_OriginalVolume", jam.Volume)
        end
        jam.Volume = RemoveJamminMusicEnabled and 0 or jam:GetAttribute("JustXDoors_OriginalVolume")
    end

    local soundService = game:GetService("SoundService")
    local main = soundService:FindFirstChild("Main")
    local jamming = main and main:FindFirstChild("Jamming")

    if jamming and jamming:IsA("EqualizerSoundEffect") then
        JamMuffle = jamming

        local liveModifiers = workspace:FindFirstChild("LiveModifiers")
            or ReplicatedStorage:FindFirstChild("LiveModifiers")

        jamming.Enabled =
            liveModifiers
            and liveModifiers:FindFirstChild("Jammin") ~= nil
            and not RemoveJamminMusicEnabled
            or false
    end
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

    if parent:GetAttribute("Locked") == true then
        return true
    end

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

    if not isInfiniteItemTarget(prompt) or InfinitePromptObjects[prompt] or prompt:GetAttribute("FakePrompt") then
        return
    end

    if not prompt.Parent then
        return
    end

    if prompt:GetAttribute("HoldDuration_Old") == nil then
        prompt:SetAttribute("HoldDuration_Old", prompt.HoldDuration)
    end
    if prompt:GetAttribute("RequiresLineOfSight_Old") == nil then
        prompt:SetAttribute("RequiresLineOfSight_Old", prompt.RequiresLineOfSight)
    end
    if prompt:GetAttribute("MaxActivationDistance_Old") == nil then
        prompt:SetAttribute("MaxActivationDistance_Old", prompt.MaxActivationDistance)
    end

    local originalEnabled = prompt.Enabled

    local fake = prompt:Clone()
    fake:SetAttribute("FakePrompt", true)

    fake:SetAttribute("HoldDuration_Old", prompt:GetAttribute("HoldDuration_Old"))
    fake:SetAttribute("RequiresLineOfSight_Old", prompt:GetAttribute("RequiresLineOfSight_Old"))
    fake:SetAttribute("MaxActivationDistance_Old", prompt:GetAttribute("MaxActivationDistance_Old"))

    fake.HoldDuration = prompt.HoldDuration
    fake.RequiresLineOfSight = prompt.RequiresLineOfSight
    fake.MaxActivationDistance = prompt.MaxActivationDistance

    FakePrompts[fake] = prompt
    InfinitePromptObjects[prompt] = fake

    fake.Parent = prompt.Parent
    fake.Enabled = originalEnabled

    local enabledConnection = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
        if fake.Parent and prompt.Enabled ~= false then
            fake.Enabled = prompt.Enabled
        end
    end)

    prompt.Enabled = false
    table.insert(InfiniteItemConnections, enabledConnection)

    prompt:GetPropertyChangedSignal("ActionText"):Once(function()
        if prompt.Parent == InfinitePromptContainer and fake.Parent then
            prompt.Parent = fake.Parent
        end
        pcall(function() fake:Destroy() end)
        FakePrompts[fake] = nil
        InfinitePromptObjects[prompt] = nil
        disconnect(enabledConnection)
    end)

    prompt.Destroying:Once(function()
        pcall(function() fake:Destroy() end)
        FakePrompts[fake] = nil
        InfinitePromptObjects[prompt] = nil
        disconnect(enabledConnection)
    end)

    table.insert(InfiniteItemConnections, enabledConnection)

    if fake.Parent and prompt.Parent then
        fake.Enabled = originalEnabled
    end
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
    if not InfiniteItemsEnabled or not fake or not fake:GetAttribute("FakePrompt") then return end

    local realPrompt = FakePrompts[fake]
    if not realPrompt or not realPrompt.Parent or not Character then return end

    local anyTool = Character:FindFirstChildOfClass("Tool")
    local toolData = anyTool and InfiniteItemNames[anyTool.Name]

    local parent = fake.Parent
    local parentName = parent and parent.Name
    local grandParentName = parent and parent.Parent and parent.Parent.Name

    local isLockPrompt =
        InfinitePromptNames[fake.Name]
        or (parent and parent:GetAttribute("Locked") == true)
        or (grandParentName == "Locker_Small_Locked" and fake.Name == "ActivateEventPrompt")

    if isLockPrompt and not anyTool then
        return
    end

    if (parentName == "CuttableVines" or parentName == "Chest_Vine" or parentName == "Cellar")
        and not Character:FindFirstChild("Shears")
        and not Character:FindFirstChild("Multitool") then
        return
    end

    if parentName == "SkullLock" and not Character:FindFirstChild("SkeletonKey") then
        return
    end

    if (parentName == "Lock1" or parentName == "Lock2")
        and not Character:FindFirstChild("Lockpick")
        and not Character:FindFirstChild("Multitool") then
        return
    end

    if anyTool and toolData and isInfiniteItemSelected(toolData) then
        local remotes = getRemotes()
        local dropRemote = remotes and remotes:FindFirstChild("DropItem")
        local drops = workspace:FindFirstChild("Drops")

        if not dropRemote or not dropRemote:IsA("RemoteEvent") or not drops then
            firePrompt(realPrompt)
            return
        end

        drops.ChildAdded:Once(function(newTool)
            if not newTool or newTool.Name ~= anyTool.Name then
                return
            end

            local prompt = newTool:FindFirstChild("ModulePrompt")
            if not prompt then
                return
            end

            firePrompt(prompt)
            firePrompt(realPrompt)
        end)

        dropRemote:FireServer(anyTool)
    else
        firePrompt(realPrompt)
    end
end

local InfiniteCrucifixBusy = false
local InfiniteCrucifixNext = 0

local function tryInfiniteCrucifix()
    if not InfiniteCrucifixEnabled or InfiniteCrucifixBusy or tick() < InfiniteCrucifixNext then return end
    if not Character or not RootPart then return end

    local tool = Character:FindFirstChild("Crucifix")
    if not tool then return end

    local origin = RootPart.Position

    for _, entity in ipairs(workspace:GetChildren()) do
        local maxRange = InfiniteCrucifixRanges[entity.Name]
        if maxRange and entity.PrimaryPart then
            local target = entity.PrimaryPart.Position

            if (origin - target).Magnitude <= maxRange then
                InfiniteCrucifixRaycastParams.FilterDescendantsInstances = {Character, entity}

                if not workspace:Raycast(origin, target - origin, InfiniteCrucifixRaycastParams) then
                    InfiniteCrucifixBusy = true
                    InfiniteCrucifixNext = tick() + 0.5

                    task.spawn(function()
                        local remotes = getRemotes()
                        local dropRemote = remotes and remotes:FindFirstChild("DropItem")

                        if dropRemote and dropRemote:IsA("RemoteEvent") then
                            dropRemote:FireServer(tool)

                            local deadline = tick() + 2.5
                            local activated = false

                            while tick() < deadline and Character and Character.Parent do
                                local drops = workspace:FindFirstChild("Drops")
                                local drop = drops and drops:FindFirstChild("Crucifix")
                                local prompt = drop and drop:FindFirstChild("ModulePrompt", true)

                                if not prompt then
                                    prompt = drop and drop:FindFirstChildWhichIsA("ProximityPrompt", true)
                                end

                                if prompt then
                                    for _ = 1, 3 do
                                        firePrompt(prompt)
                                        task.wait(0.05)
                                    end
                                    activated = true
                                    break
                                end

                                task.wait(0.02)
                            end

                            if not activated and Character and Character:FindFirstChild("Crucifix") then
                                InfiniteCrucifixNext = tick() + 0.15
                            end
                        end

                        InfiniteCrucifixBusy = false
                    end)

                    break
                end
            end
        end
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

local function restoreCollisionSpoof()
    for part, original in pairs(CollisionCanCollideBackup) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide = original
            end)
        end
    end

    table.clear(CollisionCanCollideBackup)

    if Collision then
        Collision.CanCollide = false
    end

    if CollisionClone then
        CollisionClone.CanCollide = false
        local cloneCrouch = CollisionClone:FindFirstChild("CollisionCrouch")
        if cloneCrouch then
            cloneCrouch.CanCollide = false
        end
    end

    if CollisionPartClone then
        CollisionPartClone.CanCollide = false
    end

    if Character and OriginalC1 then
        local lowerTorso = Character:FindFirstChild("LowerTorso")
        local rootMotor = lowerTorso and lowerTorso:FindFirstChild("Root")
        if rootMotor then
            pcall(function()
                rootMotor.C1 = OriginalC1
            end)
        end
    end
end

local function updateCollisionSpoof()
    if not VelocityManipulationEnabled then
        restoreCollisionSpoof()
        return
    end

    if not Character or not RootPart then
        return
    end

    setupCollisionSpoof()

    if not Collision or not CollisionClone then
        return
    end

    if getFloor() == "Fools" or getFloor() == "OldHotel" then
        restoreCollisionSpoof()
        return
    end

    for _, part in ipairs(Character:GetChildren()) do
        if part:IsA("BasePart") then
            if CollisionCanCollideBackup[part] == nil then
                CollisionCanCollideBackup[part] = part.CanCollide
            end
            part.CanCollide = false
        end
    end

    RootPart.CanCollide = false
    Collision.CanCollide = false

    local lowerTorso = Character:FindFirstChild("LowerTorso")
    local rootMotor = lowerTorso and lowerTorso:FindFirstChild("Root")

    if rootMotor and OriginalC1 then
        rootMotor.C1 = OriginalC1
    end

    Collision.Position = RootPart.Position + Vector3.new(0, 0.18, 0)

    if CollisionPart and CollisionPart:IsA("BasePart") then
        CollisionPart.Position = RootPart.Position + Vector3.new(0, 0.18, 0)
    end

    local crouch = Collision:FindFirstChild("CollisionCrouch")
    local cloneCrouch = CollisionClone:FindFirstChild("CollisionCrouch")

    if crouch then
        crouch.CanCollide = false
        crouch.Position = RootPart.Position + Vector3.new(0, -0.982, 0)
    end

    if cloneCrouch then
        cloneCrouch.Position = RootPart.Position + Vector3.new(0, -0.982, 0)
    end

    CollisionClone.CollisionGroup = Collision.CollisionGroup
    CollisionClone.Position = RootPart.Position + Vector3.new(0, 0.18, 0)

    local crouching = isCrouching()
    CollisionClone.CanCollide = not (NoclipEnabled or FlyEnabled or crouching)

    if cloneCrouch then
        cloneCrouch.CollisionGroup = Collision.CollisionGroup
        cloneCrouch.CanCollide = not (NoclipEnabled or FlyEnabled or not crouching)
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

    local look = camera.CFrame.LookVector
    local right = camera.CFrame.RightVector

    local flatRight = Vector3.new(right.X, 0, right.Z)
    if flatRight.Magnitude <= 0.001 then
        flatRight = Vector3.xAxis
    else
        flatRight = flatRight.Unit
    end

    -- Derive a stable horizontal forward vector from the camera's right vector.
    -- The full LookVector is then used for forward/backward movement so
    -- looking up/down makes the fly direction move vertically as well.
    local flatForward = Vector3.yAxis:Cross(flatRight)
    if flatForward.Magnitude <= 0.001 then
        return Vector3.zero
    end
    flatForward = flatForward.Unit

    local x = direction:Dot(flatRight)
    local z = direction:Dot(flatForward)

    local result = flatRight * x + look * z

    if result.Magnitude <= 0.001 then
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

    local original = prompt:GetAttribute("HoldDuration_Old")
    if original == nil then
        original = prompt.HoldDuration
        prompt:SetAttribute("HoldDuration_Old", original)
    end

    if ModifiedPrompts[prompt] == nil then
        ModifiedPrompts[prompt] = original
    end

    prompt.HoldDuration = 0

    local real = FakePrompts[prompt]
    local fake = InfinitePromptObjects[prompt]

    if real and real.Parent and real:GetAttribute("HoldDuration_Old") == nil then
        real:SetAttribute("HoldDuration_Old", original)
    end

    if fake and fake.Parent then
        if fake:GetAttribute("HoldDuration_Old") == nil then
            fake:SetAttribute("HoldDuration_Old", original)
        end
        if ModifiedPrompts[fake] == nil then
            ModifiedPrompts[fake] = original
        end
        fake.HoldDuration = 0
    end
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
                local original = prompt:GetAttribute("HoldDuration_Old")
                prompt.HoldDuration = original ~= nil and original or duration
            end)
        end
    end

    for fake, real in pairs(FakePrompts) do
        if fake and fake.Parent and real then
            pcall(function()
                local original = real:GetAttribute("HoldDuration_Old")
                if original ~= nil then
                    fake.HoldDuration = original
                end
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

local function createUI(modules)
    if type(modules) ~= "table" then
        warn("[JustXDoors Main] UI modules are missing.")
        return false
    end

    local actions = {
        SetSpeedBoost = function(value)
            CurrentSpeedBoost = value
            if SpeedBoostEnabled then applySpeed() end
        end,

        SetFlySpeed = function(value)
            CurrentFlySpeed = value
        end,

        SetSpeedBoostEnabled = function(value)
            SpeedBoostEnabled = value
            applySpeed()
            fireCrouchRemote()
        end,

        SetRemoveAcceleration = function(value)
            RemoveAccelEnabled = value
            if not CustomPhysics then
                buildCustomPhysics()
                snapshotPartProperties()
            end
            applyRemoveAcceleration()
        end,

        SetFlyEnabled = function(value)
            FlyEnabled = value
            if value then enableFly() else disableFly() end
        end,

        SetNoclipEnabled = function(value)
            NoclipEnabled = value
            applyNoclip()
        end,

        SetJumpEnabled = function(value)
            applyJump(value)
        end,

        SetInfiniteJumpEnabled = function(value)
            InfiniteJumpEnabled = value
            if value then
                bindInfiniteJumpButton()
            else
                disconnect(InfiniteJumpButtonConnection)
                InfiniteJumpButtonConnection = nil
            end
        end,

        SetSlideEnabled = function(value)
            applySlide(value)
        end,

        SetAnticheatBypass = function(value)
            AnticheatBypassEnabled = value
            if not value then resetAnticheatState() end
        end,

        SetVelocityManipulation = function(value)
            VelocityManipulationEnabled = value
            if value and not ManipulateBody then setupManipulateBody() end
            if not value then
                if ManipulateBody then ManipulateBody.Parent = nil end
                restoreCollisionSpoof()
            end
        end,

        SetVelocityMode = function(value)
            if type(value) == "table" then
                value = value[1] or value.Value
            end
            VelocityManipulationMode = value or "Velocity"
        end,

        SetInfiniteItems = function(value)
            InfiniteItemsEnabled = value
            setupInfiniteItems()
        end,

        SetInfiniteItemsSelection = function(value)
            InfiniteItemsSelection = value or {}
        end,

        SetInfiniteCrucifix = function(value)
            InfiniteCrucifixEnabled = value
        end,

        SetCrouchSpoof = function(value)
            CrouchSpoofEnabled = value
            applyCrouchSpoof()
        end,

        SetFullBright = function(value)
            FullBrightEnabled = value
            if value then
                applyFullBright()
            elseif not NoFogEnabled then
                restoreLighting()
            end
        end,

        SetBrightness = function(value)
            CurrentBrightness = value
            if FullBrightEnabled then applyFullBright() end
        end,

        SetNoFog = function(value)
            NoFogEnabled = value
            if value then
                applyNoFog()
                if FullBrightEnabled then applyFullBright() end
            elseif not FullBrightEnabled then
                restoreLighting()
            end
        end,

        SetRemoveFootstepSounds = function(value)
            RemoveFootstepSoundsEnabled = value
            applyRemoveFootstepSounds()
        end,

        SetRemoveInteractingSounds = function(value)
            RemoveInteractingSoundsEnabled = value
            applyRemoveInteractingSounds()
        end,

        SetRemoveJamminMusic = function(value)
            RemoveJamminMusicEnabled = value
            applyRemoveJamminMusic()
        end,

        SetInstantInteract = function(value)
            if value then enableInstantInteract() else disableInstantInteract() end
        end,

        SetInteractNoclip = function(value)
            for _, prompt in ipairs(workspace:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") then
                    applyPromptClip(prompt, value)
                end
            end
        end,

        SetInteractReach = function(value)
            for _, prompt in ipairs(workspace:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") then
                    applyPromptReach(prompt, value)
                end
            end
        end,

        SetDoorReach = function(value)
            DoorReachEnabled = value
        end,

        SetAutoTpNextDoor = function(value)
            AutoTpNextDoorEnabled = value
        end,

        PlayAgain = function()
            local remotes = ReplicatedStorage:FindFirstChild("RemotesFolder")
            local remote = remotes and remotes:FindFirstChild("PlayAgain")
            if remote and remote:IsA("RemoteEvent") then remote:FireServer() end
        end,

        ReturnToLobby = function()
            local remotes = ReplicatedStorage:FindFirstChild("RemotesFolder")
            local remote = remotes and remotes:FindFirstChild("Lobby")
            if remote and remote:IsA("RemoteEvent") then remote:FireServer() end
        end,

        Revive = function()
            local remotes = ReplicatedStorage:FindFirstChild("RemotesFolder")
            local remote = remotes and remotes:FindFirstChild("Revive")
            if remote and remote:IsA("RemoteEvent") then remote:FireServer() end
        end,

        ResetCharacter = function()
            local remotes = ReplicatedStorage:FindFirstChild("RemotesFolder")
            local underwater = remotes and remotes:FindFirstChild("Underwater")
            if underwater and underwater:IsA("RemoteEvent") then
                underwater:FireServer(true)
            elseif Humanoid then
                Humanoid.Health = 0
            end
        end,

        Void = function()
            if not Character then return end
            local pivot = Character:GetPivot()
            local target = pivot + Vector3.new(0, -120 - pivot.Position.Y, 0)
            for _ = 1, 22 do Character:PivotTo(target) end
        end,

        ExitCloset = function()
            local remotes = ReplicatedStorage:FindFirstChild("RemotesFolder")
            local camLock = remotes and remotes:FindFirstChild("CamLock")
            if camLock and camLock:IsA("RemoteEvent") then camLock:FireServer() end
        end,

        TeleportNextDoor = teleportNextDoor,
    }

    local ctx = {
        Core = Core,
        Elements = Elements,
        Actions = actions,
        Tab = nil,
    }

    local order = {
        modules.Character,
        modules.Bypass,
        modules.Visual,
        modules.Audio,
        modules.Misc,
        modules.Settings,
    }

    for _, module in ipairs(order) do
        if module and type(module.Create) == "function" then
            local ok, result = pcall(function()
                return module:Create(ctx)
            end)
            if not ok or result == false then
                warn("[JustXDoors Main] Failed to create UI module: " .. tostring(result))
                return false
            end
        end
    end

    Tab = ctx.Tab
    return Tab ~= nil
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
    setupFootstepSounds()
    applyRemoveInteractingSounds()
    applyRemoveJamminMusic()

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
        setupFootstepSounds()
        applyRemoveInteractingSounds()
        applyRemoveJamminMusic()

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
            applyRemoveInteractingSounds()
            applyRemoveJamminMusic()
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

        if CrouchSpoofEnabled then
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

function Main:Init(core, modules)
    if self.Initialized then
        return self
    end

    if type(core) ~= "table" then
        warn("[JustXDoors Main] Core is missing.")
        return self
    end

    Core = core

    local success, result = pcall(createUI, modules)

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
    CrouchSpoofEnabled = false
    InfiniteItemsEnabled = false
    InfiniteItemsSelection = {}
    InfiniteCrucifixEnabled = false
    restoreInfinitePrompts()
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
    RemoveFootstepSoundsEnabled = false
    RemoveInteractingSoundsEnabled = false
    RemoveJamminMusicEnabled = false

    disconnect(FootstepConnection)
    FootstepConnection = nil

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
