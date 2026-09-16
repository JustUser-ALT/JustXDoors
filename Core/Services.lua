local Services = {}

Services.Players = game:GetService("Players")
Services.Workspace = game:GetService("Workspace")
Services.Lighting = game:GetService("Lighting")
Services.RunService = game:GetService("RunService")
Services.UserInputService = game:GetService("UserInputService")
Services.TweenService = game:GetService("TweenService")
Services.ReplicatedStorage = game:GetService("ReplicatedStorage")
Services.ReplicatedFirst = game:GetService("ReplicatedFirst")
Services.ServerScriptService = game:GetService("ServerScriptService")
Services.ServerStorage = game:GetService("ServerStorage")
Services.StarterGui = game:GetService("StarterGui")
Services.StarterPlayer = game:GetService("StarterPlayer")
Services.SoundService = game:GetService("SoundService")
Services.CollectionService = game:GetService("CollectionService")
Services.Debris = game:GetService("Debris")
Services.HttpService = game:GetService("HttpService")
Services.GuiService = game:GetService("GuiService")
Services.ContextActionService = game:GetService("ContextActionService")
Services.TextChatService = game:GetService("TextChatService")
Services.ProximityPromptService = game:GetService("ProximityPromptService")
Services.TeleportService = game:GetService("TeleportService")
Services.VirtualInputManager = game:GetService("VirtualInputManager")

Services.LocalPlayer = Services.Players.LocalPlayer

function Services:GetCharacter()
    local player = self.LocalPlayer

    if not player then
        return nil
    end

    return player.Character
end

function Services:GetHumanoid()
    local character = self:GetCharacter()

    if not character then
        return nil
    end

    return character:FindFirstChildOfClass("Humanoid")
end

function Services:GetRootPart()
    local character = self:GetCharacter()

    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
end

function Services:GetCamera()
    return self.Workspace.CurrentCamera
end

return Services
