local AntiUI = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

local AntiRushEnabled = false
local AntiAmbushEnabled = false
local AntiDupeEnabled = false
local DetectionDistance = 150

local HeartbeatConnection
local CharacterConnection
local DupeConnection
local SetPositionSpoof
local PositionSpoofState = false

local AntiEyesEnabled = false
local EyesConnection
local EyesHookInstalled = false
local OriginalNamecall

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
    RushMoving = true,
    AmbushMoving = true,
}

local function getCharacterRoot()
    local character = Player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getEntityPosition(entity)
    if entity:IsA("BasePart") then
        return entity.Position
    end

    if not entity:IsA("Model") then
        return nil
    end

    local primary = entity.PrimaryPart
        or entity:FindFirstChild("RushNew")
        or entity:FindFirstChild("HumanoidRootPart")
        or entity:FindFirstChildWhichIsA("BasePart", true)

    return primary and primary:IsA("BasePart") and primary.Position or nil
end

local function isEntityNearby(entityName)
    local rootPart = getCharacterRoot()
    if not rootPart then
        return false
    end

    for _, object in ipairs(workspace:GetChildren()) do
        if object.Name == entityName
            and EntityNames[object.Name]
            and (object:IsA("Model") or object:IsA("BasePart"))
        then
            local position = getEntityPosition(object)

            if position and (rootPart.Position - position).Magnitude <= DetectionDistance then
                return true
            end
        end
    end

    return false
end

local function shouldPositionSpoof()
    return (AntiRushEnabled and isEntityNearby("RushMoving"))
        or (AntiAmbushEnabled and isEntityNearby("AmbushMoving"))
end

local function setPositionSpoof(value)
    value = value == true

    -- Avoid calling Main:SetPositionSpoof every Heartbeat when nothing changed.
    if PositionSpoofState == value then
        return
    end

    PositionSpoofState = value

    if SetPositionSpoof then
        SetPositionSpoof(value)
    end
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
    if HeartbeatConnection then
        HeartbeatConnection:Disconnect()
    end

    HeartbeatConnection = RunService.Heartbeat:Connect(updateAnti)

    if CharacterConnection then
        CharacterConnection:Disconnect()
    end

    CharacterConnection = Player.CharacterAdded:Connect(function()
        setPositionSpoof(false)

        if AntiRushEnabled or AntiAmbushEnabled then
            task.defer(updateAnti)
        end
    end)
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

    ctx.Elements.AntiDupe = page:Toggle({
        Name = "Anti Dupe",
        Flag = "Hotel_AntiDupe",
        Default = false,
        Callback = function(value)
            setDupeBypass(value)
        end,
    })

    page:Label({
        Text = "Anti Rush / Ambush uses Position Spoof within 150 studs. Anti Dupe disables fake-door damage. Anti Eyes bypasses Eyes only; Lookman is not affected.",
    })

    start()
    return true
end

function AntiUI:Destroy()
    AntiRushEnabled = false
    AntiAmbushEnabled = false
    AntiEyesEnabled = false

    setAntiEyes(false)
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
