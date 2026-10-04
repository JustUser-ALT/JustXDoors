local AntiUI = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

local AntiRushEnabled = false
local PositionSpoofActive = false
local DetectionDistance = 150
local HeartbeatConnection
local CharacterConnection

local POSITION_SPOOF_OFFSET = 2.346
local POSITION_SPOOF_HIP_HEIGHT = 0.05
local NORMAL_HIP_HEIGHT = 2.396

local function getCharacter()
    local character = Player.Character
    if not character or not character.Parent then
        return nil, nil, nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not rootPart then
        return character, humanoid, rootPart
    end

    return character, humanoid, rootPart
end

local function getRemotes()
    local remotes = ReplicatedStorage:FindFirstChild("RemotesFolder")
    return remotes
end

local function isSupportedFloor()
    local gameData = ReplicatedStorage:FindFirstChild("GameData")
    local floor = gameData and gameData:FindFirstChild("Floor")

    if not floor then
        return true
    end

    return floor.Value ~= "Fools" and floor.Value ~= "OldHotel"
end

local function setPositionSpoof(enabled)
    if enabled == PositionSpoofActive then
        return
    end

    local _, humanoid, rootPart = getCharacter()

    if not humanoid or not rootPart or humanoid.Health <= 0 or not isSupportedFloor() then
        PositionSpoofActive = false
        return
    end

    if enabled then
        rootPart.CFrame = rootPart.CFrame * CFrame.new(0, -POSITION_SPOOF_OFFSET, 0)
        humanoid.HipHeight = POSITION_SPOOF_HIP_HEIGHT

        local remotes = getRemotes()
        local crouch = remotes and remotes:FindFirstChild("Crouch")

        if crouch and crouch:IsA("RemoteEvent") then
            crouch:FireServer(true, true)
        end

        PositionSpoofActive = true
    else
        rootPart.CFrame = rootPart.CFrame * CFrame.new(0, POSITION_SPOOF_OFFSET, 0)
        humanoid.HipHeight = NORMAL_HIP_HEIGHT
        PositionSpoofActive = false
    end
end

local function getRushPosition(rush)
    if rush:IsA("BasePart") then
        return rush.Position
    end

    if not rush:IsA("Model") then
        return nil
    end

    local primary = rush.PrimaryPart
        or rush:FindFirstChild("RushNew")
        or rush:FindFirstChild("HumanoidRootPart")
        or rush:FindFirstChildWhichIsA("BasePart", true)

    if primary and primary:IsA("BasePart") then
        return primary.Position
    end

    return nil
end

local function isRushObject(object)
    if not object then
        return false
    end

    if object.Name == "RushMoving" then
        return object:IsA("Model") or object:IsA("BasePart")
    end

    return false
end

local function isRushNearby()
    local _, _, rootPart = getCharacter()
    if not rootPart then
        return false
    end

    local closestDistance = math.huge

    for _, object in ipairs(workspace:GetChildren()) do
        if isRushObject(object) then
            local position = getRushPosition(object)

            if position then
                local distance = (rootPart.Position - position).Magnitude

                if distance < closestDistance then
                    closestDistance = distance
                end

                if distance <= DetectionDistance then
                    return true
                end
            end
        end
    end

    return false
end

local function updateAntiRush()
    if not AntiRushEnabled then
        if PositionSpoofActive then
            setPositionSpoof(false)
        end
        return
    end

    if not isSupportedFloor() then
        if PositionSpoofActive then
            setPositionSpoof(false)
        end
        return
    end

    local rushNearby = isRushNearby()

    if rushNearby then
        if not PositionSpoofActive then
            setPositionSpoof(true)
        end
    elseif PositionSpoofActive then
        setPositionSpoof(false)
    end
end

local function start()
    if HeartbeatConnection then
        HeartbeatConnection:Disconnect()
    end

    HeartbeatConnection = RunService.Heartbeat:Connect(updateAntiRush)

    if CharacterConnection then
        CharacterConnection:Disconnect()
    end

    CharacterConnection = Player.CharacterAdded:Connect(function()
        PositionSpoofActive = false

        if AntiRushEnabled then
            task.defer(updateAntiRush)
        end
    end)
end

function AntiUI:Create(ctx)
    local pages = ctx.EntityPages
    if not pages then return false end

    local page = pages:Page("Anti")
    if not page then return false end

    ctx.Elements.AntiRush = page:Toggle({
        Name = "Anti Rush",
        Flag = "Hotel_AntiRush",
        Default = false,
        Callback = function(value)
            AntiRushEnabled = value == true

            if not AntiRushEnabled then
                setPositionSpoof(false)
            else
                updateAntiRush()
            end
        end,
    })

    page:Label({
        Text = "Automatically activates Position Spoof when Rush is within 150 studs.",
    })

    DetectionDistance = 150
    start()

    return true
end

function AntiUI:Destroy()
    AntiRushEnabled = false

    if PositionSpoofActive then
        setPositionSpoof(false)
    end

    if HeartbeatConnection then
        HeartbeatConnection:Disconnect()
        HeartbeatConnection = nil
    end

    if CharacterConnection then
        CharacterConnection:Disconnect()
        CharacterConnection = nil
    end
end

return AntiUI
