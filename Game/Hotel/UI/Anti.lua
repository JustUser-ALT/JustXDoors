local AntiUI = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

local AntiRushEnabled = false
local DetectionDistance = 150
local HeartbeatConnection
local CharacterConnection
local SetPositionSpoof

local function getCharacterRoot()
    local character = Player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
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

    return primary and primary:IsA("BasePart") and primary.Position or nil
end

local function isRushNearby()
    local rootPart = getCharacterRoot()
    if not rootPart then
        return false
    end

    for _, object in ipairs(workspace:GetChildren()) do
        if object.Name == "RushMoving" and (object:IsA("Model") or object:IsA("BasePart")) then
            local position = getRushPosition(object)

            if position and (rootPart.Position - position).Magnitude <= DetectionDistance then
                return true
            end
        end
    end

    return false
end

local function updateAntiRush()
    if SetPositionSpoof then
        SetPositionSpoof(AntiRushEnabled and isRushNearby())
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

    SetPositionSpoof = ctx.SetPositionSpoof

    ctx.Elements.AntiRush = page:Toggle({
        Name = "Anti Rush",
        Flag = "Hotel_AntiRush",
        Default = false,
        Callback = function(value)
            AntiRushEnabled = value == true
            updateAntiRush()
        end,
    })

    page:Label({
        Text = "Automatically activates Position Spoof when Rush is within 150 studs.",
    })

    start()
    return true
end

function AntiUI:Destroy()
    AntiRushEnabled = false

    if SetPositionSpoof then
        SetPositionSpoof(false)
    end

    if HeartbeatConnection then
        HeartbeatConnection:Disconnect()
        HeartbeatConnection = nil
    end

    if CharacterConnection then
        CharacterConnection:Disconnect()
        CharacterConnection = nil
    end

    SetPositionSpoof = nil
end

return AntiUI
