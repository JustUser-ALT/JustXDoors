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
local AntiSnareEnabled = false
local DetectionDistance = 150

local HeartbeatConnection
local CharacterConnection
local DupeConnection
local SnareConnection
local SetPositionSpoof
local PositionSpoofState = false

local AntiEyesEnabled = false
local EyesConnection
local EyesHookInstalled = false
local OriginalNamecall
local EntityConnection
local EntityRegistry = {}
local OriginalModuleNames = setmetatable({}, {__mode = "k"})

local function getFloorName()
    local gameData = game:GetService("ReplicatedStorage"):FindFirstChild("GameData")
    local floor = gameData and gameData:FindFirstChild("Floor")
    return floor and floor.Value or nil
end

local function isEyesActive()
    for _, object in ipairs(workspace:GetChildren()) do
        if object.Name == "Eyes" then
            return true
        end
    end
    return false
end

local function applyEyesReplication(args)
    if not AntiEyesEnabled or not isEyesActive() then
        return args
    end

    local floor = getFloorName()
    if floor == "Fools" or floor == "OldHotel" then
        args[1] = 0
        args[2] = 65
        args[3] = 0
        args[4] = false
    else
        args[1] = -650
    end

    return args
end

local function fireEyesBypass()
    if not AntiEyesEnabled or not isEyesActive() then
        return
    end

    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("RemotesFolder")
    local motorReplication = remotes and remotes:FindFirstChild("MotorReplication")
    if not motorReplication or not motorReplication:IsA("RemoteEvent") then
        return
    end

    local floor = getFloorName()
    if floor == "Fools" or floor == "OldHotel" then
        motorReplication:FireServer(0, 65, 0, false)
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
            and isEyesActive()
        then
            local args = { ... }
            applyEyesReplication(args)
            return oldNamecall(self, table.unpack(args))
        end

        return oldNamecall(self, ...)
    end))

    OriginalNamecall = oldNamecall
end

local function setAntiEyes(value)
    AntiEyesEnabled = value == true

    if EyesConnection then
        EyesConnection:Disconnect()
        EyesConnection = nil
    end

    if AntiEyesEnabled then
        installEyesHook()
        fireEyesBypass()

        EyesConnection = workspace.ChildAdded:Connect(function(object)
            if object.Name ~= "Eyes" then
                return
            end

            task.defer(function()
                fireEyesBypass()
            end)
        end)
    end
end

local EntityNames = {
    RushMoving = 85,
    AmbushMoving = 150,
    ["RNIUSHCG=="] = 90,
    AR0xMBUSH = 175,
}

local function getCharacterRoot()
    local character = Player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getEntityPosition(entity)
    if not entity or not (entity:IsA("Model") or entity:IsA("BasePart")) then
        return nil
    end
    if entity:IsA("BasePart") then return entity.Position end
    local primary = entity.PrimaryPart
        or entity:FindFirstChild("RushNew")
        or entity:FindFirstChild("HumanoidRootPart")
        or entity:FindFirstChildWhichIsA("BasePart", true)
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
        and (isEntityNearby("RushMoving", 85) or isEntityNearby("RNIUSHCG==", 90)))
        or (AntiAmbushEnabled
        and (isEntityNearby("AmbushMoving", 150) or isEntityNearby("AR0xMBUSH", 175)))
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
        hidden.CanTouch = false
    end

    local lock = object:FindFirstChild("Lock")
    if lock then
        local unlockPrompt = lock:FindFirstChild("UnlockPrompt")
        if unlockPrompt and unlockPrompt:IsA("ProximityPrompt") then
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

local function setModuleDisabled(module, disabled, normalName)
    if not module or not module:IsA("ModuleScript") then return end
    module.Name = disabled and (normalName .. "_Disabled") or normalName
end

local function setAntiScreech(value)
    AntiScreechEnabled = value == true
    local module = getScreechModule()
    if module then setModuleDisabled(module, AntiScreechEnabled, "Screech") end
end

local function setAntiGlitchScreech(value)
    AntiGlitchScreechEnabled = value == true
    local module = getGlitchScreechModule()
    if module then setModuleDisabled(module, AntiGlitchScreechEnabled, "GlitchScreech") end
end

local function setAntiDread(value)
    AntiDreadEnabled = value == true
    local module = getDreadModule()
    if module then setModuleDisabled(module, AntiDreadEnabled, "Dread") end
end

local function applySnareBypass(object)
    if not AntiSnareEnabled or not object or object.Name ~= "Snare" then
        return
    end

    for _, part in ipairs(object:GetDescendants()) do
        if part:IsA("BasePart") then
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
        for _, object in ipairs(workspace:GetDescendants()) do
            if object.Name == "Snare" then
                for _, part in ipairs(object:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanTouch = true
                    end
                end
            end
        end
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
        -- Exact Abyssal behavior on disable: restore touch/prompt interaction.
        for _, object in ipairs(workspace:GetDescendants()) do
            if object.Name == "DoorFake" or object.Name == "FakeDoor" then
                local hidden = object:FindFirstChild("Hidden")
                if hidden and hidden:IsA("BasePart") then
                    hidden.CanTouch = true
                end

                local lock = object:FindFirstChild("Lock")
                if lock then
                    local unlockPrompt = lock:FindFirstChild("UnlockPrompt")
                    if unlockPrompt and unlockPrompt:IsA("ProximityPrompt") then
                        unlockPrompt.Enabled = true
                    end
                end
            end
        end
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
    local floorReplicated = replicatedStorage:FindFirstChild("FloorReplicated")

    local connections = {}

    if floorReplicated then
        table.insert(connections, floorReplicated.DescendantAdded:Connect(function(object)
            if AntiGlitchScreechEnabled
                and object.Name == "GlitchScreech"
                and object:IsA("ModuleScript")
            then
                task.defer(setAntiGlitchScreech, true)
            end
        end))
    end

    local modules = getUIModules()
    if modules then
        table.insert(connections, modules.DescendantAdded:Connect(function(object)
            if object:IsA("ModuleScript") then
                if AntiScreechEnabled
                    and (object.Name == "Screech" or object.Name == "Screech_Disabled")
                then
                    task.defer(setAntiScreech, true)
                elseif AntiDreadEnabled
                    and (object.Name == "Dread" or object.Name == "Dread_Disabled")
                then
                    task.defer(setAntiDread, true)
                end
            end
        end))
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
        end)
    end)

    if AntiScreechEnabled then setAntiScreech(true) end
    if AntiGlitchScreechEnabled then setAntiGlitchScreech(true) end
    if AntiDreadEnabled then setAntiDread(true) end
end

function AntiUI:Create(ctx)
    local pages = ctx.EntityPages
    if not pages then return false end

    local page = pages:Page("Anti")
    if not page then return false end

    SetPositionSpoof = ctx.SetPositionSpoof

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
        Text = "Anti Rush / Ambush uses Position Spoof within 150 studs. Anti Dupe disables fake-door damage. Anti Dread disables the Dread module. Anti Screech disables Screech. Anti Glitch Screech disables GlitchScreech. Anti Snare disables Snare touch damage. Anti Eyes bypasses Eyes only; Lookman is not affected.",
    })

    start()
    return true
end

function AntiUI:Destroy()
    AntiRushEnabled = false
    AntiAmbushEnabled = false
    AntiEyesEnabled = false
    AntiDreadEnabled = false
    AntiScreechEnabled = false
    AntiGlitchScreechEnabled = false
    AntiSnareEnabled = false

    setAntiEyes(false)
    setAntiDread(false)
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
end

return AntiUI
