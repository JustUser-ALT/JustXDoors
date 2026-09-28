local Main = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Player = Players.LocalPlayer

local Core
local Tab
local Character
local Humanoid
local RootPart

local Connections = {}
local Elements = {}

local FlyVelocity
local FlyGyro
local FlyEnabled = false

local FullBrightEnabled = false
local NoFogEnabled = false

local LightingBackup = nil
local AtmosphereBackup = {}

local ModifiedPrompts = {}

local OldJump = false
local OldSlide = false

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Connections, connection)
    return connection
end

local function disconnectAll()
    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(Connections)
end

local function getCharacter()
    Character = Player.Character or Player.CharacterAdded:Wait()

    Humanoid = Character:FindFirstChildOfClass("Humanoid")
    RootPart = Character:FindFirstChild("HumanoidRootPart")

    return Character
end

local function getFloor()
    local gameData = ReplicatedStorage:FindFirstChild("GameData")

    if not gameData then
        return "Hotel"
    end

    local floor = gameData:FindFirstChild("Floor")

    if floor then
        return floor.Value
    end

    return "Hotel"
end

local function getLiveModifiers()
    return workspace:FindFirstChild("LiveModifiers")
        or ReplicatedStorage:FindFirstChild("LiveModifiers")
end

local function isCrouching()
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
        local ok, group = pcall(function()
            return collisionPart.CollisionGroup
        end)

        if ok and group == "PlayerCrouching" then
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

local function getSpeedBoost()
    local slider = Elements.SpeedBoost

    if not slider then
        return 0
    end

    local value = slider.Get and slider:Get()

    if type(value) == "number" then
        return value
    end

    if type(slider.Value) == "number" then
        return slider.Value
    end

    return 0
end

local function getToggleValue(element)
    if not element then
        return false
    end

    if type(element.Get) == "function" then
        local ok, value = pcall(function()
            return element:Get()
        end)

        if ok then
            return value == true
        end
    end

    return element.Value == true
end

local function speedEnabled()
    return getToggleValue(Elements.SpeedBoostToggle)
end

local function applySpeed()
    if not Humanoid or not Humanoid.Parent then
        return
    end

    if not speedEnabled() then
        Humanoid.WalkSpeed = getCurrentSpeed()
        return
    end

    local speed = getCurrentSpeed() + getSpeedBoost()

    Humanoid.WalkSpeed = math.max(speed, 0)
end

local function fireCrouchRemote()
    local remotes = ReplicatedStorage:FindFirstChild("RemotesFolder")
        or ReplicatedStorage:FindFirstChild("EntityInfo")
        or ReplicatedStorage:FindFirstChild("Bricks")

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

local function createFly()
    if FlyVelocity then
        pcall(function()
            FlyVelocity:Destroy()
        end)
    end

    if FlyGyro then
        pcall(function()
            FlyGyro:Destroy()
        end)
    end

    if not RootPart then
        return
    end

    FlyVelocity = Instance.new("BodyVelocity")
    FlyVelocity.Name = "JustXDoorsFlyVelocity"
    FlyVelocity.MaxForce = Vector3.new(
        math.huge,
        math.huge,
        math.huge
    )
    FlyVelocity.P = 10000
    FlyVelocity.Velocity = Vector3.zero
    FlyVelocity.Parent = RootPart

    FlyGyro = Instance.new("BodyGyro")
    FlyGyro.Name = "JustXDoorsFlyGyro"
    FlyGyro.MaxTorque = Vector3.new(
        math.huge,
        math.huge,
        math.huge
    )
    FlyGyro.P = 10000
    FlyGyro.D = 500
    FlyGyro.CFrame = RootPart.CFrame
    FlyGyro.Parent = RootPart
end

local function destroyFly()
    if FlyVelocity then
        pcall(function()
            FlyVelocity:Destroy()
        end)
        FlyVelocity = nil
    end

    if FlyGyro then
        pcall(function()
            FlyGyro:Destroy()
        end)
        FlyGyro = nil
    end

    if Humanoid then
        pcall(function()
            Humanoid.PlatformStand = false
            Humanoid.AutoRotate = true
        end)
    end
end

local function getFlySpeed()
    local slider = Elements.FlySpeed

    if not slider then
        return 20
    end

    if type(slider.Get) == "function" then
        local ok, value = pcall(function()
            return slider:Get()
        end)

        if ok and type(value) == "number" then
            return value
        end
    end

    if type(slider.Value) == "number" then
        return slider.Value
    end

    return 20
end

local function updateFly()
    if not FlyEnabled or not RootPart or not Humanoid then
        return
    end

    if not FlyVelocity or not FlyVelocity.Parent then
        createFly()
    end

    if not FlyVelocity then
        return
    end

    local camera = workspace.CurrentCamera

    if not camera then
        return
    end

    local move = Humanoid.MoveDirection

    local velocity = Vector3.zero

    if move.Magnitude > 0 then
        velocity = move.Unit * getFlySpeed()
    end

    local vertical = 0

    if Humanoid:GetState() == Enum.HumanoidStateType.Jumping then
        vertical += getFlySpeed()
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        vertical += getFlySpeed()
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.C)
    then
        vertical -= getFlySpeed()
    end

    velocity += Vector3.new(0, vertical, 0)

    FlyVelocity.Velocity = velocity

    local look = camera.CFrame.LookVector

    if look.Magnitude > 0 then
        FlyGyro.CFrame = CFrame.lookAt(
            RootPart.Position,
            RootPart.Position + look
        )
    end
end

local function enableFly()
    if FlyEnabled then
        return
    end

    getCharacter()

    if not RootPart or not Humanoid then
        return
    end

    FlyEnabled = true

    createFly()

    Humanoid.PlatformStand = true
    Humanoid.AutoRotate = false
end

local function disableFly()
    FlyEnabled = false
    destroyFly()
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

local function applyFullBright()
    if not FullBrightEnabled then
        return
    end

    saveLighting()

    Lighting.Ambient = Color3.new(1, 1, 1)
    Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    Lighting.Brightness = 3
    Lighting.ClockTime = 14
    Lighting.ExposureCompensation = 0

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

local function restoreLighting()
    if not LightingBackup then
        return
    end

    if FullBrightEnabled or NoFogEnabled then
        return
    end

    pcall(function()
        Lighting.Ambient = LightingBackup.Ambient
        Lighting.OutdoorAmbient = LightingBackup.OutdoorAmbient
        Lighting.Brightness = LightingBackup.Brightness
        Lighting.ClockTime = LightingBackup.ClockTime
        Lighting.FogStart = LightingBackup.FogStart
        Lighting.FogEnd = LightingBackup.FogEnd
        Lighting.ExposureCompensation = LightingBackup.ExposureCompensation
        Lighting.ColorShift_Bottom = LightingBackup.ColorShift_Bottom
        Lighting.ColorShift_Top = LightingBackup.ColorShift_Top
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

local function applyPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") then
        return
    end

    if ModifiedPrompts[prompt] == nil then
        ModifiedPrompts[prompt] = prompt.HoldDuration
    end

    prompt.HoldDuration = 0
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

local function createUI()
    Tab = Core:Tab({
        Name = "Main",
        Icon = "user",
        Type = "Grid",
    })

    if not Tab then
        return false
    end

    local characterSection = Tab:Section({
        Title = "Character",
        Column = 1,
        Icon = "user",
    })

    local movementSection = Tab:Section({
        Title = "Movement",
        Column = 2,
        Icon = "move",
    })

    local visualSection = Tab:Section({
        Title = "Visual",
        Column = 3,
        Icon = "eye",
    })

    local miscSection = Tab:Section({
        Title = "Misc",
        Column = 1,
        Icon = "settings-2",
    })

    if not characterSection
        or not movementSection
        or not visualSection
        or not miscSection
    then
        return false
    end

    Elements.SpeedBoost = characterSection:Slider({
        Name = "Speed Boost",
        Min = 0,
        Max = 100,
        Default = 0,
        Flag = "Main_SpeedBoost",
        TextMode = "Smart",
    })

    Elements.SpeedBoostToggle = characterSection:Toggle({
        Name = "Enable Speed Boost",
        Default = false,
        Flag = "Main_SpeedBoostToggle",
        TextMode = "Smart",
        Callback = function(value)
            if value then
                applySpeed()
            else
                applySpeed()
            end
        end,
    })

    Elements.EnableJump = characterSection:Toggle({
        Name = "Enable Jumping",
        Default = false,
        Flag = "Main_EnableJump",
        TextMode = "Smart",
        Callback = function(value)
            applyJump(value)
        end,
    })

    Elements.InfiniteJump = characterSection:Toggle({
        Name = "Infinite Jump",
        Default = false,
        Flag = "Main_InfiniteJump",
        TextMode = "Smart",
    })

    Elements.EnableSlide = characterSection:Toggle({
        Name = "Enable Sliding",
        Default = false,
        Flag = "Main_EnableSlide",
        TextMode = "Smart",
        Callback = function(value)
            applySlide(value)
        end,
    })

    Elements.Fly = movementSection:Toggle({
        Name = "Fly",
        Default = false,
        Flag = "Main_Fly",
        TextMode = "Smart",
        Callback = function(value)
            if value then
                enableFly()
            else
                disableFly()
            end
        end,
    })

    Elements.FlySpeed = movementSection:Slider({
        Name = "Fly Speed",
        Min = 0,
        Max = 115,
        Default = 20,
        Flag = "Main_FlySpeed",
        TextMode = "Smart",
    })

    Elements.FullBright = visualSection:Toggle({
        Name = "Fullbright",
        Default = false,
        Flag = "Main_FullBright",
        TextMode = "Smart",
        Callback = function(value)
            FullBrightEnabled = value == true

            if FullBrightEnabled then
                saveLighting()
                applyFullBright()
            else
                if not NoFogEnabled then
                    restoreLighting()
                end
            end
        end,
    })

    Elements.NoFog = visualSection:Toggle({
        Name = "No Fog",
        Default = false,
        Flag = "Main_NoFog",
        TextMode = "Smart",
        Callback = function(value)
            NoFogEnabled = value == true

            if NoFogEnabled then
                saveLighting()
                applyNoFog()
            else
                if not FullBrightEnabled then
                    restoreLighting()
                end
            end
        end,
    })

    Elements.Brightness = visualSection:Slider({
        Name = "Brightness",
        Min = 25,
        Max = 100,
        Default = 35,
        Flag = "Main_Brightness",
        TextMode = "Smart",
    })

    Elements.InstantInteract = miscSection:Toggle({
        Name = "Instant Interact",
        Default = false,
        Flag = "Main_InstantInteract",
        TextMode = "Smart",
        Callback = function(value)
            if value then
                enableInstantInteract()
            else
                disableInstantInteract()
            end
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

    connect(
        Player.CharacterAdded,
        function(character)
            Character = character

            Humanoid = character:WaitForChild("Humanoid", 10)
            RootPart = character:WaitForChild("HumanoidRootPart", 10)

            OldJump = character:GetAttribute("CanJump") or false
            OldSlide = character:GetAttribute("CanSlide") or false

            if getToggleValue(Elements.EnableJump) then
                applyJump(true)
            end

            if getToggleValue(Elements.EnableSlide) then
                applySlide(true)
            end

            if FlyEnabled then
                task.defer(function()
                    createFly()

                    if Humanoid then
                        Humanoid.PlatformStand = true
                        Humanoid.AutoRotate = false
                    end
                end)
            end

            if speedEnabled() then
                task.defer(applySpeed)
            end
        end
    )

    connect(
        UserInputService.JumpRequest,
        function()
            if not getToggleValue(Elements.InfiniteJump) then
                return
            end

            if not Humanoid or Humanoid.Health <= 0 then
                return
            end

            pcall(function()
                Humanoid:ChangeState(
                    Enum.HumanoidStateType.Jumping
                )
            end)
        end
    )

    connect(
        workspace.DescendantAdded,
        function(object)
            if object:IsA("ProximityPrompt")
                and getToggleValue(Elements.InstantInteract)
            then
                task.defer(function()
                    if object.Parent then
                        applyPrompt(object)
                    end
                end)
            end
        end
    )

    connect(
        Lighting.ChildAdded,
        function(object)
            if not (FullBrightEnabled or NoFogEnabled) then
                return
            end

            if object:IsA("Atmosphere") then
                task.defer(function()
                    if FullBrightEnabled or NoFogEnabled then
                        object.Density = 0
                        object.Haze = 0
                        object.Glare = 0
                    end
                end)
            end
        end
    )

    connect(
        RunService.Heartbeat,
        function()
            if not Character or not Character.Parent then
                return
            end

            if not Humanoid or not Humanoid.Parent then
                return
            end

            if speedEnabled() then
                applySpeed()
                fireCrouchRemote()
            end

            if FlyEnabled then
                updateFly()
            end

            if FullBrightEnabled then
                applyFullBright()
            end

            if NoFogEnabled then
                applyNoFog()
            end
        end
    )

    connect(
        RunService.RenderStepped,
        function()
            if not FullBrightEnabled and not NoFogEnabled then
                return
            end

            if FullBrightEnabled then
                applyFullBright()
            end

            if NoFogEnabled then
                applyNoFog()
            end
        end
    )
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

    if not createUI() then
        warn("[JustXDoors Main] Failed to create Main UI.")
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

    FullBrightEnabled = false
    NoFogEnabled = false

    restoreLighting()

    disconnectAll()

    if Character then
        applyJump(false)
        applySlide(false)
    end

    Elements = {}
    Tab = nil
    Core = nil

    self.Initialized = false
end

return Main
