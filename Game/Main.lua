local Main = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Core
local Window
local Character
local Humanoid
local Root

local Connections = {}
local CharacterConnections = {}

local FlyEnabled = false
local FlySpeed = 20
local FlyVelocity
local FlyGyro

local InfiniteJump = false
local InstantInteract = false
local EnableJump = false
local EnableSlide = false

local FullbrightEnabled = false
local NoFogEnabled = false
local FullbrightBrightness = 35

local SavedLighting = {
    Ambient = nil,
    OutdoorAmbient = nil,
    Brightness = nil,
    ClockTime = nil,
    FogStart = nil,
    FogEnd = nil,
    Atmospheres = {},
}

local ModifiedPrompts = {}

local function connect(signal, callback, bucket)
    local connection = signal:Connect(callback)
    table.insert(bucket or Connections, connection)
    return connection
end

local function disconnectBucket(bucket)
    for _, connection in ipairs(bucket) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(bucket)
end

local function getCharacter()
    Character = LocalPlayer.Character
    Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    Root = Character and Character:FindFirstChild("HumanoidRootPart")

    return Character, Humanoid, Root
end

local function getFloor()
    local floor = ReplicatedStorage:FindFirstChild("Floor")

    if floor and floor:IsA("StringValue") then
        return floor.Value
    end

    local value = workspace:GetAttribute("Floor")
    if value ~= nil then
        return tostring(value)
    end

    return ""
end

local function getRemotes()
    return ReplicatedStorage:FindFirstChild("RemotesFolder")
end

local function isCrouching()
    if not Character then
        return false
    end

    local floor = getFloor()

    if floor == "Fools" or floor == "OldHotel" then
        return Character:GetAttribute("Crouching") == true
    end

    local collisionPart = Character:FindFirstChild("CollisionPart")

    if collisionPart and collisionPart:IsA("BasePart") then
        local ok, group = pcall(function()
            return collisionPart.CollisionGroup
        end)

        if ok and group then
            return group == "PlayerCrouching"
        end
    end

    return Character:GetAttribute("Crouching") == true
end

local function getInjuriesSpeed()
    if not Humanoid then
        return 0
    end

    return 0.075 * math.max(0, Humanoid.MaxHealth - Humanoid.Health)
end

local function getCurrentSpeed()
    if not Character or not Humanoid then
        return 15
    end

    local speed = 15

    speed += Character:GetAttribute("SpeedBoost") or 0
    speed += Character:GetAttribute("SpeedBoostBehind") or 0
    speed += Character:GetAttribute("SpeedBoostExtra") or 0

    speed += getFloor() == "Party" and 10 or 0

    local modifiers = workspace:FindFirstChild("LiveModifiers")

    if modifiers then
        speed += modifiers:FindFirstChild("PlayerFast") and 3 or 0
        speed += modifiers:FindFirstChild("PlayerFaster") and 6 or 0
        speed += modifiers:FindFirstChild("PlayerFastest") and 20 or 0

        speed -= modifiers:FindFirstChild("PlayerSlow") and 3 or 0
        speed -= modifiers:FindFirstChild("PlayerSlowHealth") and getInjuriesSpeed() or 0

        if isCrouching() then
            if modifiers:FindFirstChild("PlayerCrouchSlow") then
                speed -= 8
            elseif modifiers:FindFirstChild("PlayerSlow") then
                speed -= 8
            else
                speed -= 5
            end
        end
    elseif isCrouching() then
        speed -= 5
    end

    return math.max(0, speed)
end

local function updateWalkSpeed()
    if not Humanoid or FlyEnabled then
        return
    end

    Humanoid.WalkSpeed = getCurrentSpeed()
end

local function sendCrouchState()
    local remotes = getRemotes()
    local crouch = remotes and remotes:FindFirstChild("Crouch")

    if not crouch then
        return
    end

    pcall(function()
        crouch:FireServer(isCrouching(), true)
    end)
end

local function applyCharacterState()
    getCharacter()

    if not Humanoid then
        return
    end

    updateWalkSpeed()

    if Humanoid.UseJumpPower then
        Humanoid.JumpPower = EnableJump and 50 or 0
    else
        Humanoid.JumpHeight = EnableJump and 7.2 or 0
    end

    Character:SetAttribute("CanJump", EnableJump)
    Character:SetAttribute("CanSlide", EnableSlide)
end

local function startFly()
    getCharacter()

    if not Character or not Humanoid or not Root then
        return
    end

    FlyEnabled = true
    Humanoid.PlatformStand = true
    Humanoid.AutoRotate = false

    FlyVelocity = Instance.new("BodyVelocity")
    FlyVelocity.Name = "JustXDoorsFlyVelocity"
    FlyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    FlyVelocity.Velocity = Vector3.zero
    FlyVelocity.Parent = Root

    FlyGyro = Instance.new("BodyGyro")
    FlyGyro.Name = "JustXDoorsFlyGyro"
    FlyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    FlyGyro.P = 9e4
    FlyGyro.D = 500
    FlyGyro.CFrame = Root.CFrame
    FlyGyro.Parent = Root
end

local function stopFly()
    FlyEnabled = false

    if Humanoid then
        Humanoid.PlatformStand = false
        Humanoid.AutoRotate = true
    end

    if FlyVelocity then
        FlyVelocity:Destroy()
        FlyVelocity = nil
    end

    if FlyGyro then
        FlyGyro:Destroy()
        FlyGyro = nil
    end

    updateWalkSpeed()
end

local function updateFly()
    if not FlyEnabled or not Root or not Humanoid then
        return
    end

    local move = Humanoid.MoveDirection
    local velocity = Vector3.zero

    if move.Magnitude > 0 then
        local cameraCF = Camera.CFrame
        local forward = cameraCF.LookVector
        local right = cameraCF.RightVector

        local horizontal = Vector3.new(move.X, 0, move.Z)

        if horizontal.Magnitude > 0 then
            local direction = (right * horizontal.X) + (forward * horizontal.Z)
            velocity = direction.Unit * FlySpeed
        end
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        velocity += Vector3.new(0, FlySpeed, 0)
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        velocity -= Vector3.new(0, FlySpeed, 0)
    end

    if FlyVelocity then
        FlyVelocity.Velocity = velocity
    end

    if FlyGyro then
        FlyGyro.CFrame = CFrame.lookAt(Root.Position, Root.Position + Camera.CFrame.LookVector)
    end
end

local function setJumpEnabled(state)
    EnableJump = state

    if Character then
        Character:SetAttribute("CanJump", state)
    end

    if Humanoid then
        if Humanoid.UseJumpPower then
            Humanoid.JumpPower = state and 50 or 0
        else
            Humanoid.JumpHeight = state and 7.2 or 0
        end
    end
end

local function setSlideEnabled(state)
    EnableSlide = state

    if Character then
        Character:SetAttribute("CanSlide", state)
    end
end

local function onJumpRequest()
    if not InfiniteJump or not Humanoid or not Character then
        return
    end

    Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end

local function saveLighting()
    if SavedLighting.Ambient ~= nil then
        return
    end

    SavedLighting.Ambient = Lighting.Ambient
    SavedLighting.OutdoorAmbient = Lighting.OutdoorAmbient
    SavedLighting.Brightness = Lighting.Brightness
    SavedLighting.ClockTime = Lighting.ClockTime
    SavedLighting.FogStart = Lighting.FogStart
    SavedLighting.FogEnd = Lighting.FogEnd

    table.clear(SavedLighting.Atmospheres)

    for _, object in ipairs(Lighting:GetChildren()) do
        if object:IsA("Atmosphere") then
            SavedLighting.Atmospheres[object] = {
                Density = object.Density,
                Offset = object.Offset,
                Color = object.Color,
                Decay = object.Decay,
                Glare = object.Glare,
                Haze = object.Haze,
                Enabled = object.Enabled,
            }
        end
    end
end

local function applyFullbright()
    if not FullbrightEnabled then
        return
    end

    saveLighting()

    local value = math.clamp(FullbrightBrightness / 100, 0, 1)

    Lighting.Brightness = 1 + value * 2
    Lighting.Ambient = Color3.new(value, value, value)
    Lighting.OutdoorAmbient = Color3.new(value, value, value)
    Lighting.ClockTime = 14

    if NoFogEnabled then
        Lighting.FogStart = 0
        Lighting.FogEnd = 1e6
    end

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
    Lighting.FogEnd = 1e6

    for _, object in ipairs(Lighting:GetChildren()) do
        if object:IsA("Atmosphere") then
            object.Density = 0
            object.Haze = 0
            object.Glare = 0
        end
    end
end

local function restoreLighting()
    if FullbrightEnabled or NoFogEnabled then
        return
    end

    if SavedLighting.Ambient == nil then
        return
    end

    Lighting.Ambient = SavedLighting.Ambient
    Lighting.OutdoorAmbient = SavedLighting.OutdoorAmbient
    Lighting.Brightness = SavedLighting.Brightness
    Lighting.ClockTime = SavedLighting.ClockTime
    Lighting.FogStart = SavedLighting.FogStart
    Lighting.FogEnd = SavedLighting.FogEnd

    for object, data in pairs(SavedLighting.Atmospheres) do
        if object and object.Parent then
            object.Density = data.Density
            object.Offset = data.Offset
            object.Color = data.Color
            object.Decay = data.Decay
            object.Glare = data.Glare
            object.Haze = data.Haze
            object.Enabled = data.Enabled
        end
    end

    table.clear(SavedLighting.Atmospheres)

    SavedLighting.Ambient = nil
    SavedLighting.OutdoorAmbient = nil
    SavedLighting.Brightness = nil
    SavedLighting.ClockTime = nil
    SavedLighting.FogStart = nil
    SavedLighting.FogEnd = nil
end

local function refreshLighting()
    if FullbrightEnabled then
        applyFullbright()
    elseif NoFogEnabled then
        applyNoFog()
    else
        restoreLighting()
    end
end

local function setPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") then
        return
    end

    if ModifiedPrompts[prompt] == nil then
        ModifiedPrompts[prompt] = prompt.HoldDuration
    end

    prompt.HoldDuration = 0
end

local function restorePrompts()
    for prompt, duration in pairs(ModifiedPrompts) do
        if prompt and prompt.Parent then
            prompt.HoldDuration = duration
        end
    end

    table.clear(ModifiedPrompts)
end

local function setInstantInteract(state)
    InstantInteract = state

    if state then
        for _, object in ipairs(workspace:GetDescendants()) do
            if object:IsA("ProximityPrompt") then
                setPrompt(object)
            end
        end
    else
        restorePrompts()
    end
end

local function setupCharacter()
    disconnectBucket(CharacterConnections)

    getCharacter()

    if not Character then
        return
    end

    connect(Character:GetAttributeChangedSignal("SpeedBoost"), updateWalkSpeed, CharacterConnections)
    connect(Character:GetAttributeChangedSignal("SpeedBoostBehind"), updateWalkSpeed, CharacterConnections)
    connect(Character:GetAttributeChangedSignal("SpeedBoostExtra"), updateWalkSpeed, CharacterConnections)
    connect(Character:GetAttributeChangedSignal("Crouching"), function()
        updateWalkSpeed()
        sendCrouchState()
    end, CharacterConnections)

    if Humanoid then
        connect(Humanoid:GetPropertyChangedSignal("Health"), updateWalkSpeed, CharacterConnections)
        connect(Humanoid:GetPropertyChangedSignal("MaxHealth"), updateWalkSpeed, CharacterConnections)
    end

    applyCharacterState()
end

local function createCharacterTab()
    local tab = Core:Tab({
        Name = "Main",
        Icon = "house",
        Type = "Grid",
    })

    if not tab then
        return
    end

    local characterSection = Core:Section(tab, {
        Title = "Character",
        Column = 1,
        Icon = "person-standing",
    })

    characterSection:Slider({
        Name = "Speed Boost",
        Flag = "SpeedBoost",
        Min = 0,
        Max = 85,
        Step = 1,
        Default = 0,
        Suffix = "",
        Callback = function(value)
            local remotes = getRemotes()
            local crouch = remotes and remotes:FindFirstChild("Crouch")

            if crouch then
                pcall(function()
                    crouch:FireServer(isCrouching(), true)
                end)
            end

            if Character then
                Character:SetAttribute("SpeedBoost", value)
            end

            updateWalkSpeed()
        end,
    })

    characterSection:Toggle({
        Name = "Fly",
        Flag = "Fly",
        Default = false,
        Callback = function(value)
            if value then
                startFly()
            else
                stopFly()
            end
        end,
    })

    characterSection:Slider({
        Name = "Fly Speed",
        Flag = "FlySpeed",
        Min = 0,
        Max = 115,
        Step = 1,
        Default = 20,
        Suffix = "",
        Callback = function(value)
            FlySpeed = value
        end,
    })

    characterSection:Divider()

    characterSection:Toggle({
        Name = "Enable Jump",
        Flag = "EnableJump",
        Default = false,
        Callback = setJumpEnabled,
    })

    characterSection:Toggle({
        Name = "Infinite Jump",
        Flag = "InfiniteJump",
        Default = false,
        Callback = function(value)
            InfiniteJump = value
        end,
    })

    characterSection:Toggle({
        Name = "Enable Slide",
        Flag = "EnableSlide",
        Default = false,
        Callback = setSlideEnabled,
    })

    local visualSection = Core:Section(tab, {
        Title = "Visual",
        Column = 2,
        Icon = "eye",
    })

    visualSection:Slider({
        Name = "Brightness",
        Flag = "FullbrightBrightness",
        Min = 25,
        Max = 100,
        Step = 1,
        Default = 35,
        Suffix = "%",
        Callback = function(value)
            FullbrightBrightness = value

            if FullbrightEnabled then
                applyFullbright()
            end
        end,
    })

    visualSection:Toggle({
        Name = "Fullbright",
        Flag = "Fullbright",
        Default = false,
        Callback = function(value)
            FullbrightEnabled = value
            refreshLighting()
        end,
    })

    visualSection:Toggle({
        Name = "No Fog",
        Flag = "NoFog",
        Default = false,
        Callback = function(value)
            NoFogEnabled = value
            refreshLighting()
        end,
    })

    local miscSection = Core:Section(tab, {
        Title = "Misc",
        Column = 3,
        Icon = "settings-2",
    })

    miscSection:Toggle({
        Name = "Instant Interact",
        Flag = "InstantInteract",
        Default = false,
        Callback = setInstantInteract,
    })
end

function Main:Init(core)
    if self.Initialized then
        return self
    end

    Core = core

    if not Core then
        return nil
    end

    Window = Core:GetWindow()

    if not Window then
        return nil
    end

    self.Initialized = true

    getCharacter()
    setupCharacter()
    createCharacterTab()

    connect(LocalPlayer.CharacterAdded:Connect(function()
        task.wait()
        setupCharacter()
    end))

    connect(UserInputService.JumpRequest, onJumpRequest)

    connect(RunService.RenderStepped, function()
        updateFly()

        if not FlyEnabled then
            updateWalkSpeed()
        end

        if FullbrightEnabled or NoFogEnabled then
            refreshLighting()
        end
    end)

    connect(workspace.DescendantAdded, function(object)
        if InstantInteract and object:IsA("ProximityPrompt") then
            task.defer(function()
                if object.Parent then
                    setPrompt(object)
                end
            end)
        end
    end)

    connect(Lighting.ChildAdded, function(object)
        if FullbrightEnabled or NoFogEnabled then
            task.defer(refreshLighting)
        end
    end)

    Core:Notify({
        Title = "Main",
        Desc = "Character, Visual and Misc loaded",
        Type = "Success",
        Duration = 3,
    })

    return self
end

function Main:Destroy()
    stopFly()
    restorePrompts()

    FullbrightEnabled = false
    NoFogEnabled = false

    restoreLighting()

    disconnectBucket(CharacterConnections)
    disconnectBucket(Connections)

    self.Initialized = false
end

return Main
