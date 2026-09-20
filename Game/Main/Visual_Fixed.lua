--[[
    JustXDoors
    Game/Visual/Visual.lua  (or Game/Main/Visual.lua — place wherever Loader expects)

    Visual tab — Camera sub-tab + Effects sub-tab
    Ported from Abyssal Hub / Abyssal Hub Continued.

    Lifecycle (called by Loader):
        Visual:Init(Core)
        Visual:Build()
        Visual:Destroy()
]]

local Visual = {}

------------------------------------------------------
-- CORE REFS
------------------------------------------------------

local Core
local Services
local Connections
local UI

------------------------------------------------------
-- STATE FLAGS
------------------------------------------------------

local Initialized = false
local Built       = false
local Connected   = false

local Tab                   -- Core.Main.Tabs.Main  (Visual section goes here)
local CameraGroupbox        -- AddLeftTabbox → Camera tab
local EffectsGroupbox       -- AddLeftTabbox → Effects tab

local Groups   = {}
local Elements = {}

------------------------------------------------------
-- CHARACTER / WORLD REFS
------------------------------------------------------

local Character
local Humanoid
local Camera

-- ThirdPerson: parts that should be shown in 3rd-person
local ThirdPersonParts = {}

-- Fog: snapshot old values so we can restore
local OldFog          = 0
local FogInstances    = {}   -- Atmosphere objects

-- HidingSpots: collected as rooms load (mirrors Objects.HidingSpots)
local HidingSpots     = {}

-- Modules: references to jumpscare / cutscene ModuleScripts
local Modules = {
    Glitch          = nil,
    SpiderJumpscare = nil,  -- Timothy
    Void            = nil,
    Jumpscares      = nil,  -- folder
}

-- MainUI / Initiator path (resolved in Init)
local RemoteListenerModules = nil
local RemoteListenerRoot    = nil
local CutsceneFolder        = nil
local FloorReplicated       = nil

local CurrentRooms = nil

-- Cutscene names that can be disabled (same list as Abyssal)
local CutsceneNames = {
    "IntroducingRush", "IntroducingAmbush", "IntroducingSeek",
    "IntroducingHalt", "IntroducingEyes", "Eyestalk",
    "EyestalkEnd", "EyestalkIntro", "DoorOpen",
}

------------------------------------------------------
-- HELPERS
------------------------------------------------------

local function getCamera()
    return Services and Services.Workspace and Services.Workspace.CurrentCamera
end

-- Safe connection wrapper. A missing Core connection manager or signal
-- must never prevent the Visual module from building.
local function safeConnect(signal, callback, groupName)
    if not Connections then
        return nil
    end

    if signal == nil then
        return nil
    end

    if type(Connections.Connect) ~= "function" then
        warn("[JustXDoors Visual] Core.Connections.Connect is unavailable.")
        return nil
    end

    local ok, result = pcall(function()
        return Connections:Connect(signal, callback, groupName)
    end)

    if not ok then
        warn("[JustXDoors Visual] Failed to connect event:", result)
        return nil
    end

    return result
end

local function getLocalPlayer()
    return Services and Services.LocalPlayer
end

local function refreshCharacter()
    local lp = getLocalPlayer()
    Character = lp and lp.Character
    Humanoid  = Character and Character:FindFirstChildOfClass("Humanoid")
    Camera    = getCamera()
end

-- Walk down PlayerGui to find MainUI
local function findMainUI()
    local lp = getLocalPlayer()
    if not lp then return nil end
    local pg = lp:FindFirstChild("PlayerGui")
    if not pg then return nil end
    return pg:FindFirstChild("MainUI")
end

-- Attempt to locate RemoteListener ModuleScript folder
local function findRemoteListenerRoot()
    local mainUI = findMainUI()
    if not mainUI then return nil end
    local init = mainUI:FindFirstChild("Initiator")
    if not init then return nil end
    local mg = init:FindFirstChild("Main_Game")
    if not mg then return nil end
    local rl = mg:FindFirstChild("RemoteListener")
    return rl
end

------------------------------------------------------
-- AMBIENT
------------------------------------------------------

local function applyAmbient(enabled)
    local toggle = Elements.AmbientToggle
    local picker = Elements.AmbientColor
    if not Services or not Services.TweenService then return end

    local targetColor
    if enabled then
        targetColor = picker and picker.Value or Color3.fromRGB(255, 255, 255)
    else
        -- Restore from current room attribute
        local lp = getLocalPlayer()
        if CurrentRooms and lp then
            local roomNum = tostring(lp:GetAttribute("CurrentRoom") or "")
            local roomFolder = CurrentRooms:FindFirstChild(roomNum)
            if roomFolder then
                targetColor = roomFolder:GetAttribute("Ambient")
            end
        end
        if not targetColor then
            targetColor = Services.Lighting.Ambient
        end
    end

    pcall(function()
        Services.TweenService:Create(
            Services.Lighting,
            TweenInfo.new(0.2, Enum.EasingStyle.Exponential),
            { Ambient = targetColor }
        ):Play()
    end)
end

------------------------------------------------------
-- REMOVE FOG
-- Covers all fog types:
--   FogEnd (Lighting property)
--   Atmosphere.Density
-- We watch Density changes to prevent the game restoring fog.
------------------------------------------------------

local FogDensityConnections = {}

local function snapshotFog()
    OldFog = Services.Lighting.FogEnd

    FogInstances = {}
    for _, obj in Services.Lighting:GetChildren() do
        if obj:IsA("Atmosphere") then
            obj:SetAttribute("Density_Old", obj.Density)
            table.insert(FogInstances, obj)
        end
    end
end

local function watchAtmosphere(obj)
    -- Keep Density = 0 while RemoveFog is on (mirrors Abyssal's AtmoConnection)
    local conn = obj:GetPropertyChangedSignal("Density"):Connect(function()
        if obj.Density ~= 0 then
            obj:SetAttribute("Density_Old", obj.Density)
        end
        if Elements.RemoveCameraFog and Elements.RemoveCameraFog.Value then
            obj.Density = 0
        end
    end)
    table.insert(FogDensityConnections, conn)
end

local function applyRemoveFog(enabled)
    pcall(function()
        Services.Lighting.FogEnd = enabled and 1e7 or OldFog
    end)
    for _, obj in FogInstances do
        pcall(function()
            obj.Density = enabled and 0 or (obj:GetAttribute("Density_Old") or obj.Density)
        end)
    end
end

------------------------------------------------------
-- FOV
------------------------------------------------------

local function applyFOV()
    local toggle = Elements.FOVToggle
    local slider = Elements.FieldOfView
    if not slider then return end
    local cam = getCamera()
    if not cam then return end

    if toggle and toggle.Value then
        cam.FieldOfView = slider.Value
    else
        cam.FieldOfView = 70  -- Roblox default
    end
end

------------------------------------------------------
-- THIRD PERSON
------------------------------------------------------

local RayParams
local function ensureRayParams()
    if not RayParams then
        RayParams = RaycastParams.new()
        RayParams.FilterType = Enum.RaycastFilterType.Exclude
    end
    if Character then
        RayParams.FilterDescendantsInstances = { Character }
    end
end

local function buildThirdPersonParts()
    ThirdPersonParts = {}
    if not Character then return end
    for _, obj in Character:GetDescendants() do
        if obj:IsA("Accessory") then
            local handle = obj:FindFirstChild("Handle")
            if handle then table.insert(ThirdPersonParts, handle) end
        end
    end
    local head = Character:FindFirstChild("Head")
    if head then table.insert(ThirdPersonParts, head) end
end

local function updateThirdPersonVisibility(active)
    for _, part in ThirdPersonParts do
        pcall(function()
            part.Transparency              = active and 0 or 1
            part.LocalTransparencyModifier = active and 0 or 1
        end)
    end
end

------------------------------------------------------
-- VIEWMODEL OFFSET
-- Adjusts the tool / viewmodel CFrame offset in Main_Game module.
-- Requires `require` executor support (same caveat as Abyssal).
-- If Main_Game is unavailable we silently skip.
------------------------------------------------------

local Main_Game = nil  -- resolved lazily

local function findMainGame()
    if Main_Game then return Main_Game end
    local rl = findRemoteListenerRoot()
    if not rl then return nil end
    -- Main_Game is typically at Initiator.Main_Game (LocalScript, not Module)
    -- The lua table is exposed via a shared / upvalue in Abyssal.
    -- In JustXDoors we attempt to read it from _G or just skip if unavailable.
    pcall(function()
        if _G and _G.Main_Game then Main_Game = _G.Main_Game end
    end)
    return Main_Game
end

local function applyViewmodelOffset()
    local toggle = Elements.ViewmodelOffsetToggle
    local mg     = findMainGame()
    if not mg then return end
    if toggle and toggle.Value then
        local x = Elements.ViewmodelOffsetX and Elements.ViewmodelOffsetX.Value or 0
        local y = Elements.ViewmodelOffsetY and Elements.ViewmodelOffsetY.Value or 0
        local z = Elements.ViewmodelOffsetZ and Elements.ViewmodelOffsetZ.Value or 0
        pcall(function() mg.tooloffset = Vector3.new(x, y, z) end)
    else
        pcall(function() mg.tooloffset = Vector3.new(0, 0, 0) end)
    end
end

------------------------------------------------------
-- CAMERA SHAKE / BOBBING
-- Main_Game exposes:
--   .csgo  — camera shake (CFrame)
--   .spring.Speed — camera bobbing speed (9e9 to disable)
------------------------------------------------------

local function applyCameraShake(disabled)
    local mg = findMainGame()
    if not mg then return end
    if disabled then
        -- Override every frame (done in Heartbeat below)
        pcall(function() mg.csgo = CFrame.new() end)
    end
end

local function applyCameraBobbing(disabled)
    local mg = findMainGame()
    if not mg then return end
    pcall(function()
        mg.spring.Speed = disabled and 9e9 or 8
    end)
end

------------------------------------------------------
-- REMOVE CUTSCENES
------------------------------------------------------

local function applyCutscenes(disabled)
    local rl = findRemoteListenerRoot()
    if not rl then return end

    local cutscenes = rl:FindFirstChild("Cutscenes")
    if cutscenes then
        for _, obj in pairs(cutscenes:GetChildren()) do
            if obj:IsA("ModuleScript") then
                local originalName = obj:GetAttribute("OriginalName") or obj.Name:gsub("_Disabled$", "")
                if table.find(CutsceneNames, originalName) then
                    if disabled then
                        if not obj.Name:find("_Disabled") then
                            obj:SetAttribute("OriginalName", obj.Name)
                            obj.Name = obj.Name .. "_Disabled"
                        end
                    else
                        obj.Name = originalName
                    end
                end
            end
        end
    end

    -- Also patch FloorReplicated (same as Abyssal)
    if FloorReplicated then
        for _, obj in pairs(FloorReplicated:GetChildren()) do
            if obj:IsA("ModuleScript") then
                local originalName = obj:GetAttribute("OriginalName") or obj.Name:gsub("_Disabled$", "")
                if table.find(CutsceneNames, originalName) then
                    if disabled then
                        if not obj.Name:find("_Disabled") then
                            obj:SetAttribute("OriginalName", obj.Name)
                            obj.Name = obj.Name .. "_Disabled"
                        end
                    else
                        obj.Name = originalName
                    end
                end
            end
        end
    end
end

------------------------------------------------------
-- TRANSPARENT HIDING SPOTS
------------------------------------------------------

local function applyHidingTransparency(enabled, alpha)
    for _, obj in HidingSpots do
        -- Check if this spot contains the local player
        local isHiding = false
        for _, child in obj:GetDescendants() do
            if child.Name == "HiddenPlayer" and child.Value == getLocalPlayer() then
                isHiding = true
                break
            end
        end

        for _, part in obj:GetDescendants() do
            if part:IsA("BasePart") and part:GetAttribute("Transparency_Old") then
                local target = (enabled and isHiding) and alpha or part:GetAttribute("Transparency_Old")
                pcall(function()
                    Services.TweenService:Create(
                        part,
                        TweenInfo.new(0.25, Enum.EasingStyle.Linear),
                        { Transparency = target }
                    ):Play()
                end)
            end
        end
    end
end

-- Register a hiding spot and snapshot part transparencies
local function handleHidingTransparency(obj)
    for _, part in obj:GetDescendants() do
        if part:IsA("BasePart") and not part:GetAttribute("Transparency_Old") then
            part:SetAttribute("Transparency_Old", part.Transparency)
        end
    end
end

------------------------------------------------------
-- JUMPSCARES
------------------------------------------------------

local function resolveModules()
    local rl = findRemoteListenerRoot()
    if not rl then return end

    local mods = rl:FindFirstChild("Modules")
    if not mods then return end

    RemoteListenerModules = mods

    Modules.Glitch          = mods:FindFirstChild("Glitch")
    Modules.SpiderJumpscare = mods:FindFirstChild("SpiderJumpscare")
    Modules.Void            = mods:FindFirstChild("Void")
    Modules.Jumpscares      = rl:FindFirstChild("Jumpscares")
                           or rl:FindFirstChild("Jumpscares_Disabled")
end

local function applyGlitchJumpscare(disabled)
    resolveModules()
    local m = Modules.Glitch
    if not m then return end
    pcall(function()
        m.Name = disabled and "Glitch_Disabled" or "Glitch"
    end)
end

local function applyTimothyJumpscare(disabled)
    resolveModules()
    local m = Modules.SpiderJumpscare
    if not m then return end
    pcall(function()
        m.Name = disabled and "SpiderJumpscare_Disabled" or "SpiderJumpscare"
    end)
end

local function applyVoidJumpscare(disabled)
    resolveModules()
    local m = Modules.Void
    if not m then return end
    pcall(function()
        m.Name = disabled and "Void_Disabled" or "Void"
    end)
end

local function applyEntityJumpscares(disabled)
    resolveModules()
    local folder = Modules.Jumpscares
    if not folder then return end
    pcall(function()
        folder.Name = disabled and "Jumpscares_Disabled" or "Jumpscares"
    end)
end

------------------------------------------------------
-- BUILD — Camera tab
------------------------------------------------------

local function buildCamera()
    local box = CameraGroupbox
    if not box then return false end

    -- Ambient toggle + color picker
    Elements.AmbientToggle = UI:AddToggle(box, "AmbientToggle", {
        Text    = "Ambient",
        Default = false,
        Tooltip = "Changes the lighting color to the specified value.",
    })

    if Elements.AmbientToggle and type(Elements.AmbientToggle.AddColorPicker) == "function" then
        Elements.AmbientColor = Elements.AmbientToggle:AddColorPicker("AmbientColor", {
            Text        = "Ambient",
            Default     = Color3.fromRGB(255, 255, 255),
            Transparency = 0,
        })
    end

    -- Remove Fog
    Elements.RemoveCameraFog = UI:AddToggle(box, "RemoveCameraFog", {
        Text    = "Remove Fog",
        Default = false,
        Tooltip = "Removes all fog types (FogEnd + Atmosphere density). Restored on toggle off.",
    })

    UI:AddDivider(box)

    -- FOV Slider + Custom FOV Toggle
    Elements.FieldOfView = UI:AddSlider(box, "FieldOfView", {
        Text     = "Field of View",
        Min      = 1,
        Max      = 120,
        Default  = 70,
        Rounding = 0,
    })

    Elements.FOVToggle = UI:AddToggle(box, "FOVToggle", {
        Text    = "Custom FOV",
        Default = false,
        Tooltip = "Applies the Field of View slider value to the camera.",
    })

    -- Third Person
    Elements.ThirdPersonToggle = UI:AddToggle(box, "ThirdPersonToggle", {
        Text    = "Third Person",
        Default = false,
        Tooltip = "Zooms out your camera so you can see your character from behind.",
    })

    Elements.ThirdPersonOffsetX = UI:AddSlider(box, "ThirdPersonOffsetX", {
        Text     = "X Offset",
        Min      = -10, Max = 10, Default = 1.5,
        Rounding = 1,   Compact = true,
    })

    Elements.ThirdPersonOffsetY = UI:AddSlider(box, "ThirdPersonOffsetY", {
        Text     = "Y Offset",
        Min      = -10, Max = 10, Default = 1,
        Rounding = 1,   Compact = true,
    })

    Elements.ThirdPersonOffsetZ = UI:AddSlider(box, "ThirdPersonOffsetZ", {
        Text     = "Z Offset",
        Min      = -10, Max = 10, Default = 5,
        Rounding = 1,   Compact = true,
    })

    -- Wall Check (under Third Person)
    Elements.ThirdPersonWallCheck = UI:AddToggle(box, "ThirdPersonWallCheck", {
        Text    = "Wall Check",
        Default = false,
        Tooltip = "Prevents the third-person camera from clipping through walls.",
    })

    UI:AddDivider(box)

    --[[
        VIEWMODEL OFFSET
        — What is it?
          The "viewmodel" is the first-person hand/tool model you see in front of
          the camera. Offsetting it lets you move it left/right, up/down, or
          closer/further so it doesn't block your view or just looks better to you.
        — Why would you want it?
          Mostly aesthetic: left-handed feel, move the tool out of the way for
          a clearer view, or match a preferred screen position.
        — Caveat: requires Main_Game.tooloffset to be writable (executor-level
          or shared via _G). If Main_Game can't be found the sliders do nothing.
    ]]

    Elements.ViewmodelOffsetToggle = UI:AddToggle(box, "ViewmodelOffsetToggle", {
        Text    = "Viewmodel Offset",
        Default = false,
        Tooltip = "Offsets the first-person hand/tool model position.",
    })

    Elements.ViewmodelOffsetX = UI:AddSlider(box, "ViewmodelOffsetX", {
        Text     = "X Offset",
        Min      = -10, Max = 10, Default = 0,
        Rounding = 1,   Compact = true,
    })

    Elements.ViewmodelOffsetY = UI:AddSlider(box, "ViewmodelOffsetY", {
        Text     = "Y Offset",
        Min      = -10, Max = 10, Default = 0,
        Rounding = 1,   Compact = true,
    })

    Elements.ViewmodelOffsetZ = UI:AddSlider(box, "ViewmodelOffsetZ", {
        Text     = "Z Offset",
        Min      = -10, Max = 10, Default = 0,
        Rounding = 1,   Compact = true,
    })

    UI:AddDivider(box)

    --[[
        REMOVE CAMERA BOBBING
        — What is it?
          Camera bobbing is the slight up-and-down sway of the camera while
          walking — it mimics a real person's head movement.
        — Why remove it?
          Some players get motion-sick from it; others just prefer a stable
          crosshair / field of view for precision play.
    ]]

    Elements.RemoveCameraShake = UI:AddToggle(box, "RemoveCameraShake", {
        Text    = "Remove Camera Shake",
        Default = false,
        Tooltip = "Removes the camera shake effect from entities and events.",
    })

    Elements.RemoveCameraBobbing = UI:AddToggle(box, "RemoveCameraBobbing", {
        Text    = "Remove Camera Bobbing",
        Default = false,
        Tooltip = "Removes the walking head-bob. Useful against motion sickness.",
    })

    Elements.RemoveCutscenes = UI:AddToggle(box, "RemoveCutscenes", {
        Text    = "Remove Cutscenes",
        Default = false,
        Tooltip = "Removes all non-essential cutscenes.",
    })

    return true
end

------------------------------------------------------
-- BUILD — Effects tab
------------------------------------------------------

local function buildEffects()
    local box = EffectsGroupbox
    if not box then return false end

    -- Transparent Hiding Spots
    Elements.TransparentHidingSpotsToggle = UI:AddToggle(box, "TransparentHidingSpotsToggle", {
        Text    = "Transparent Hiding Spots",
        Default = false,
        Tooltip = "Makes a hiding spot transparent when you are inside it.",
    })

    Elements.TransparentHidingSpotsSlider = UI:AddSlider(box, "TransparentHidingSpotsSlider", {
        Text     = "Transparency",
        Min      = 0, Max = 1, Default = 0.5,
        Rounding = 2, Compact = true,
    })

    UI:AddDivider(box)

    -- Jumpscares
    Elements.DisableTimothyJumpscare = UI:AddToggle(box, "DisableTimothyJumpscare", {
        Text    = "Disable Timothy Jumpscare",
        Default = false,
        Tooltip = "Disables the jumpscare from 'Timothy'.",
    })

    Elements.DisableGlitchJumpscare = UI:AddToggle(box, "DisableGlitchJumpscare", {
        Text    = "Disable Glitch Jumpscare",
        Default = false,
        Tooltip = "Disables the jumpscare from 'Glitch'.",
    })

    Elements.DisableVoidJumpscare = UI:AddToggle(box, "DisableVoidJumpscare", {
        Text    = "Disable Void Jumpscare",
        Default = false,
        Tooltip = "Disables the jumpscare from 'Void'.",
    })

    Elements.DisableEntityJumpscares = UI:AddToggle(box, "DisableEntityJumpscares", {
        Text    = "Disable Entity Jumpscares",
        Default = false,
        Tooltip = "Disables jumpscares from entities like Rush and Ambush.",
    })

    return true
end

------------------------------------------------------
-- CONNECTIONS
------------------------------------------------------

function Visual:Connect()
    if Connected then return end
    if not Services then return end
    Connected = true

    -- Ambient
    if Elements.AmbientToggle and type(Elements.AmbientToggle.OnChanged) == "function" then
        Elements.AmbientToggle:OnChanged(function(v) applyAmbient(v) end)
    end
    if Elements.AmbientColor and type(Elements.AmbientColor.OnChanged) == "function" then
        Elements.AmbientColor:OnChanged(function()
            if Elements.AmbientToggle and Elements.AmbientToggle.Value then
                applyAmbient(true)
            end
        end)
    end

    -- Remove Fog
    if Elements.RemoveCameraFog and type(Elements.RemoveCameraFog.OnChanged) == "function" then
        Elements.RemoveCameraFog:OnChanged(function(v) applyRemoveFog(v) end)
    end

    -- FOV
    if Elements.FOVToggle and type(Elements.FOVToggle.OnChanged) == "function" then
        Elements.FOVToggle:OnChanged(function() applyFOV() end)
    end
    if Elements.FieldOfView and type(Elements.FieldOfView.OnChanged) == "function" then
        Elements.FieldOfView:OnChanged(function() applyFOV() end)
    end

    -- Camera Bobbing
    if Elements.RemoveCameraBobbing and type(Elements.RemoveCameraBobbing.OnChanged) == "function" then
        Elements.RemoveCameraBobbing:OnChanged(function(v) applyCameraBobbing(v) end)
    end

    -- Cutscenes
    if Elements.RemoveCutscenes and type(Elements.RemoveCutscenes.OnChanged) == "function" then
        Elements.RemoveCutscenes:OnChanged(function(v) applyCutscenes(v) end)
    end

    -- Viewmodel Offset
    local vmChanged = function() applyViewmodelOffset() end
    for _, key in { "ViewmodelOffsetToggle", "ViewmodelOffsetX", "ViewmodelOffsetY", "ViewmodelOffsetZ" } do
        local el = Elements[key]
        if el and type(el.OnChanged) == "function" then
            el:OnChanged(vmChanged)
        end
    end

    -- Transparent Hiding Spots
    if Elements.TransparentHidingSpotsToggle and type(Elements.TransparentHidingSpotsToggle.OnChanged) == "function" then
        Elements.TransparentHidingSpotsToggle:OnChanged(function(v)
            local alpha = Elements.TransparentHidingSpotsSlider and Elements.TransparentHidingSpotsSlider.Value or 0.5
            applyHidingTransparency(v, alpha)
        end)
    end
    if Elements.TransparentHidingSpotsSlider and type(Elements.TransparentHidingSpotsSlider.OnChanged) == "function" then
        Elements.TransparentHidingSpotsSlider:OnChanged(function(v)
            local on = Elements.TransparentHidingSpotsToggle and Elements.TransparentHidingSpotsToggle.Value or false
            applyHidingTransparency(on, v)
        end)
    end

    -- Jumpscares
    if Elements.DisableGlitchJumpscare and type(Elements.DisableGlitchJumpscare.OnChanged) == "function" then
        Elements.DisableGlitchJumpscare:OnChanged(function(v) applyGlitchJumpscare(v) end)
    end
    if Elements.DisableTimothyJumpscare and type(Elements.DisableTimothyJumpscare.OnChanged) == "function" then
        Elements.DisableTimothyJumpscare:OnChanged(function(v) applyTimothyJumpscare(v) end)
    end
    if Elements.DisableVoidJumpscare and type(Elements.DisableVoidJumpscare.OnChanged) == "function" then
        Elements.DisableVoidJumpscare:OnChanged(function(v) applyVoidJumpscare(v) end)
    end
    if Elements.DisableEntityJumpscares and type(Elements.DisableEntityJumpscares.OnChanged) == "function" then
        Elements.DisableEntityJumpscares:OnChanged(function(v) applyEntityJumpscares(v) end)
    end

    -- Watch for new Atmosphere objects added to Lighting at runtime
    safeConnect(
        Services.Lighting and Services.Lighting.ChildAdded,
        function(child)
            if child:IsA("Atmosphere") then
                child:SetAttribute("Density_Old", child.Density)
                table.insert(FogInstances, child)
                watchAtmosphere(child)
                if Elements.RemoveCameraFog and Elements.RemoveCameraFog.Value then
                    child.Density = 0
                end
            end
        end,
        "GameVisual"
    )

    -- Watch for new HidingSpots as rooms load
    if Services.Workspace then
        local currentRooms = Services.Workspace:FindFirstChild("CurrentRooms")
        if currentRooms then
            safeConnect(
                currentRooms.ChildAdded,
                function(room)
                    -- Defer to let the room fully replicate
                    task.defer(function()
                        for _, obj in room:GetDescendants() do
                            local name = obj.Name:lower()
                            if name:find("hidingspot")
                                or obj:FindFirstChild("HidingPrompt")
                                or obj:FindFirstChild("HidePrompt")
                            then
                                handleHidingTransparency(obj)
                                table.insert(HidingSpots, obj)
                            end
                        end
                    end)
                end,
                "GameVisual"
            )
        end
    end

    -- CharacterAdded — rebuild ThirdPerson parts
    local lp = Services.LocalPlayer
    if lp then
        safeConnect(
            lp.CharacterAdded,
            function(char)
                Character = char
                Humanoid  = char:WaitForChild("Humanoid",         10)
                task.defer(function()
                    refreshCharacter()
                    buildThirdPersonParts()
                    snapshotFog()
                end)
            end,
            "GameVisual"
        )
    end

    --------------------------------------------------
    -- RenderStepped — camera overrides
    -- (same loop as Abyssal's RenderStepped block)
    --------------------------------------------------

    safeConnect(
        Services.RunService and Services.RunService.RenderStepped,
        function()
            Camera = getCamera()
            if not Camera then return end

            -- FOV enforcement
            if Elements.FOVToggle and Elements.FOVToggle.Value then
                local fov = Elements.FieldOfView and Elements.FieldOfView.Value or 70
                Camera.FieldOfView = fov
            end

            -- Camera Shake suppression
            if Elements.RemoveCameraShake and Elements.RemoveCameraShake.Value then
                pcall(function()
                    local mg = findMainGame()
                    if mg then mg.csgo = CFrame.new() end
                end)
            end

            -- Viewmodel
            if Elements.ViewmodelOffsetToggle and Elements.ViewmodelOffsetToggle.Value then
                applyViewmodelOffset()
            end

            -- Third Person
            local tpActive = Elements.ThirdPersonToggle and Elements.ThirdPersonToggle.Value
            if tpActive and Character then
                ensureRayParams()

                local ox = Elements.ThirdPersonOffsetX and Elements.ThirdPersonOffsetX.Value or 1.5
                local oy = Elements.ThirdPersonOffsetY and Elements.ThirdPersonOffsetY.Value or 1
                local oz = Elements.ThirdPersonOffsetZ and Elements.ThirdPersonOffsetZ.Value or 5

                local tpOffset  = CFrame.new(ox, oy, oz)
                local direction = (Camera.CFrame * tpOffset).Position - Camera.CFrame.Position
                local wallCheck = Elements.ThirdPersonWallCheck and Elements.ThirdPersonWallCheck.Value

                if wallCheck then
                    local result = pcall(function()
                        local hit = Services.Workspace:Spherecast(Camera.CFrame.Position, 0.2, direction, RayParams)
                        if hit and hit.Instance.CanCollide then
                            local newPos = Camera.CFrame.Position + direction.Unit * hit.Distance
                            Camera.CFrame = CFrame.new(newPos, newPos + Camera.CFrame.LookVector)
                        else
                            Camera.CFrame = Camera.CFrame * tpOffset
                        end
                    end)
                    if not result then
                        Camera.CFrame = Camera.CFrame * tpOffset
                    end
                else
                    Camera.CFrame = Camera.CFrame * tpOffset
                end
            end

            updateThirdPersonVisibility(tpActive or false)
        end,
        "GameVisual"
    )
end

------------------------------------------------------
-- INIT
------------------------------------------------------

function Visual:Init(CoreModules)
    if Initialized then return self end
    if type(CoreModules) ~= "table" then return self end

    Core        = CoreModules
    Services    = Core.Services
    Connections = Core.Connections
    UI          = Core.UI

    if not Services or not UI then
        warn("[JustXDoors Visual] Core Services/UI modules missing.")
        return self
    end

    if not Connections then
        warn("[JustXDoors Visual] Core.Connections is unavailable; event hooks will be skipped.")
    end

    -- Snapshot fog state before any toggles run
    if Services.Lighting then
        snapshotFog()
        for _, obj in Services.Lighting:GetChildren() do
            if obj:IsA("Atmosphere") then
                watchAtmosphere(obj)
            end
        end
    end

    -- CurrentRooms
    if Services.Workspace then
        CurrentRooms = Services.Workspace:FindFirstChild("CurrentRooms")
    end

    -- FloorReplicated (for cutscenes)
    if Services.ReplicatedStorage then
        FloorReplicated = Services.ReplicatedStorage:FindFirstChild("FloorReplicated")
    end

    refreshCharacter()
    buildThirdPersonParts()

    Initialized = true
    return self
end

------------------------------------------------------
-- BUILD
------------------------------------------------------

function Visual:Build()
    if Built then return self end
    if not Initialized then return self end

    -- Grab Main tab
    if Core and Core.Main and Core.Main.Tabs then
        Tab = Core.Main.Tabs.Main
    end

    if not Tab then
        warn("[JustXDoors Visual] Core.Main.Tabs.Main is missing.")
        return self
    end

    -- Create a Left Tabbox for Camera / Effects (mirrors Abyssal's Visuals_LeftTab)
    local leftTabbox = UI:AddLeftTabbox(Tab, "Visual")
    if not leftTabbox then
        warn("[JustXDoors Visual] Could not create Visual tabbox.")
        return self
    end

    CameraGroupbox  = leftTabbox:AddTab("Camera")
    EffectsGroupbox = leftTabbox:AddTab("Effects")

    if not buildCamera() then
        warn("[JustXDoors Visual] Failed to build Camera tab.")
        return self
    end

    if not buildEffects() then
        warn("[JustXDoors Visual] Failed to build Effects tab.")
        return self
    end

    self:Connect()

    -- Initial deferred pass
    task.defer(function()
        refreshCharacter()
        buildThirdPersonParts()
        resolveModules()

        -- Re-apply toggles that might have been on from saved config
        if Elements.RemoveCameraFog   and Elements.RemoveCameraFog.Value   then applyRemoveFog(true)        end
        if Elements.RemoveCameraBobbing and Elements.RemoveCameraBobbing.Value then applyCameraBobbing(true) end
        if Elements.RemoveCutscenes   and Elements.RemoveCutscenes.Value   then applyCutscenes(true)         end
        if Elements.FOVToggle         and Elements.FOVToggle.Value         then applyFOV()                   end
    end)

    Built = true
    return self
end

------------------------------------------------------
-- DESTROY
------------------------------------------------------

function Visual:Destroy()
    -- Restore fog
    applyRemoveFog(false)

    -- Restore FOV
    local cam = getCamera()
    if cam then
        pcall(function() cam.FieldOfView = 70 end)
    end

    -- Restore third-person visibility
    updateThirdPersonVisibility(false)

    -- Restore camera bobbing
    applyCameraBobbing(false)

    -- Restore cutscenes
    applyCutscenes(false)

    -- Disconnect Density watchers
    for _, conn in FogDensityConnections do
        pcall(function() conn:Disconnect() end)
    end
    FogDensityConnections = {}

    if Connections then
        Connections:DisconnectGroup("GameVisual")
    end

    -- Reset all state
    Groups               = {}
    Elements             = {}
    ThirdPersonParts     = {}
    HidingSpots          = {}
    FogInstances         = {}
    Modules              = { Glitch=nil, SpiderJumpscare=nil, Void=nil, Jumpscares=nil }

    Tab             = nil
    CameraGroupbox  = nil
    EffectsGroupbox = nil

    Character       = nil
    Humanoid        = nil
    Camera          = nil
    CurrentRooms    = nil
    FloorReplicated = nil
    Main_Game       = nil

    OldFog = 0

    Initialized = false
    Built       = false
    Connected   = false

    Core        = nil
    Services    = nil
    Connections = nil
    UI          = nil
end

------------------------------------------------------
-- RETURN
------------------------------------------------------

return Visual
