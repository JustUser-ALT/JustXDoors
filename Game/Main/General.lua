--[[
    JustXDoors
    Game/Main/General.lua

    Main tab — left tabbox: "General" + "Bypass"
    Right side: Misc, Debug, Audio groupboxes

    Lifecycle: Init → Build → Destroy
]]

local General = {}

local Core, Services, Connections, Notifications, UI

local Initialized = false
local Built       = false
local Connected   = false

local Tab
local GeneralGroupbox   -- left tabbox → General tab
local BypassGroupbox    -- left tabbox → Bypass tab

local Groups   = {}
local Elements = {}

------------------------------------------------------
-- CHARACTER / WORLD
------------------------------------------------------

local Character, Humanoid, RootPart
local RemotesFolder
local GameData
local LiveModifiers

local function refreshCharacter()
    if not Services then return end
    Character = Services.LocalPlayer and Services.LocalPlayer.Character
    Humanoid  = Character and Character:FindFirstChildOfClass("Humanoid")
    RootPart  = Character and Character:FindFirstChild("HumanoidRootPart")
end

local function getFloor()
    if not GameData then return nil end
    local v = GameData:FindFirstChild("Floor")
    return v and v.Value
end

------------------------------------------------------
-- OBJECTS — collected per-room (same as Abyssal's Objects table)
-- Populated by DescendantAdded watchers in Connect()
------------------------------------------------------

local Objects = {
    Prompts           = {},  -- ProximityPrompt
    Entities          = {},  -- entity models
    Obstructions      = {},  -- killbricks / lava / scarywall
    SeekObstructions  = {},  -- seek floatlines
    SeekBridges       = {},  -- seek bridges
}

------------------------------------------------------
-- PROMPT HELPERS
------------------------------------------------------

local function snapshotPrompt(p)
    if p:GetAttribute("HoldDuration_Old") then return end  -- already done
    p:SetAttribute("HoldDuration_Old",           p.HoldDuration)
    p:SetAttribute("RequiresLineOfSight_Old",     p.RequiresLineOfSight)
    p:SetAttribute("MaxActivationDistance_Old",   p.MaxActivationDistance)
end

local function applyPromptSettings(p)
    snapshotPrompt(p)

    local reach   = Elements.PromptReachSlider    and Elements.PromptReachSlider.Value    or 1
    local instant = Elements.InstantPrompts       and Elements.InstantPrompts.Value       or false
    local clip    = Elements.PromptClip           and Elements.PromptClip.Value           or false

    p.MaxActivationDistance = p:GetAttribute("MaxActivationDistance_Old") * reach
    p.HoldDuration          = instant and 0 or p:GetAttribute("HoldDuration_Old")
    p.RequiresLineOfSight   = clip    and false or p:GetAttribute("RequiresLineOfSight_Old")
end

local function refreshAllPrompts()
    for _, p in Objects.Prompts do
        pcall(applyPromptSettings, p)
    end
end

------------------------------------------------------
-- REMOVE CLOSET DELAY
-- Fires CamLock remote when player tries to move while
-- anchored inside a closet — identical to Abyssal's
-- RenderStepped check.
------------------------------------------------------

local function checkClosetDelay()
    if not (Elements.RemoveClosetDelay and Elements.RemoveClosetDelay.Value) then return end
    if not (Character and Humanoid and RootPart) then return end
    if not (RemotesFolder and RemotesFolder:FindFirstChild("CamLock")) then return end

    local CollisionPart = Character:FindFirstChild("CollisionPart")
        or Character:FindFirstChild("Collision")

    if not CollisionPart then return end

    if Humanoid.MoveDirection ~= Vector3.zero
        and (CollisionPart.Anchored or RootPart.Anchored)
        and Character:GetAttribute("AnimatingClient") ~= true
        and Character:GetAttribute("Hiding") == true
    then
        pcall(function() RemotesFolder.CamLock:FireServer() end)
    end
end

------------------------------------------------------
-- DOOR REACH
-- Fires ClientOpen on rooms within 75 studs while
-- DoorReachToggle is on — mirrors Abyssal's per-room
-- Heartbeat connector.
-- We use a single global loop instead of per-room
-- connections because JustXDoors doesn't expose the
-- room DescendantAdded hook here.
------------------------------------------------------

local LastDoorFire = 0

local function checkDoorReach()
    if not (Elements.DoorReachToggle and Elements.DoorReachToggle.Value) then return end
    if not (Services and Services.LocalPlayer and Character) then return end
    if tick() - LastDoorFire <= 0.1 then return end

    local currentRooms = Services.Workspace and Services.Workspace:FindFirstChild("CurrentRooms")
    if not currentRooms then return end

    for _, room in currentRooms:GetChildren() do
        local doorModel = room:FindFirstChild("Door")
        if doorModel then
            local doorPart = doorModel:FindFirstChild("Door")
            local clientOpen = doorModel:FindFirstChild("ClientOpen")
            if doorPart and clientOpen then
                local dist = Services.LocalPlayer:DistanceFromCharacter(doorPart.Position)
                if dist < 75 then
                    pcall(function() clientOpen:FireServer() end)
                    LastDoorFire = tick()
                end
            end
        end
    end
end

------------------------------------------------------
-- BYPASS HELPERS
------------------------------------------------------


------------------------------------------------------
-- MISC ACTIONS
------------------------------------------------------

local function doResetCharacter()
    if not Character then return end
    -- Try replicatesignal first (executor-level)
    local ok = pcall(function()
        if type(replicatesignal) == "function" then
            replicatesignal(Services.LocalPlayer.Kill)
        end
    end)
    if not ok then
        -- Fallback: Underwater remote or zero health
        if RemotesFolder and RemotesFolder:FindFirstChild("Underwater") then
            pcall(function() RemotesFolder.Underwater:FireServer(true) end)
        elseif Humanoid then
            pcall(function() Humanoid.Health = 0 end)
        end
    end
end

------------------------------------------------------
-- DEBUG HELPERS
------------------------------------------------------

local TpNextDoorThread = nil

local function getNextClosedDoor()
    if not Character or not Services then return nil end
    local RS = Services.ReplicatedStorage
    if not RS then return nil end
    local gd = RS:FindFirstChild("GameData")
    if not gd then return nil end
    local lr = gd:FindFirstChild("LatestRoom")
    if not lr then return nil end

    local startRoom = lr.Value
    local bestDoor, bestNum = nil, math.huge

    for _, obj in Services.Workspace:GetDescendants() do
        if obj.Name == "Door" and obj:IsA("Model") then
            local open = obj:GetAttribute("Open")
            if open == false or open == nil then
                local roomNum = tonumber(obj.Parent and obj.Parent.Name)
                if roomNum and roomNum >= startRoom and roomNum < bestNum then
                    bestNum  = roomNum
                    bestDoor = obj
                end
            end
        end
    end
    return bestDoor
end

local function startAutoTpNextDoor()
    if TpNextDoorThread then task.cancel(TpNextDoorThread) end
    TpNextDoorThread = task.spawn(function()
        while Elements.AutoTpNextDoor and Elements.AutoTpNextDoor.Value do
            local door = getNextClosedDoor()
            if door and Character then
                pcall(function() Character:PivotTo(door:GetPivot()) end)
            end
            task.wait(0.15)
        end
        TpNextDoorThread = nil
    end)
end

------------------------------------------------------
-- AUDIO HELPERS
------------------------------------------------------

local JamMuffle = nil  -- EqualizerSoundEffect resolved lazily

local function resolveJamMuffle()
    if JamMuffle then return JamMuffle end
    local main = Services.SoundService and Services.SoundService:FindFirstChild("Main")
    if main then
        JamMuffle = main:FindFirstChild("Jamming") or Instance.new("EqualizerSoundEffect")
    end
    return JamMuffle
end

local function findMainGame()
    local lp = Services and Services.LocalPlayer
    if not lp then return nil end
    local pg = lp:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local mui = pg:FindFirstChild("MainUI")
    if not mui then return nil end
    local init = mui:FindFirstChild("Initiator")
    if not init then return nil end
    return init:FindFirstChild("Main_Game")
end

local function applyRemoveJamminMusic(value)
    local mg = findMainGame()
    if not mg then return end
    local health = mg:FindFirstChild("Health")
    if not health then return end
    local jam = health:FindFirstChild("Jam")
    if not jam then return end
    pcall(function()
        jam.Volume = value and 0 or 0.45
        local muffle = resolveJamMuffle()
        if muffle then
            muffle.Enabled = (LiveModifiers and LiveModifiers:FindFirstChild("Jammin") ~= nil) and not value or false
        end
    end)
end

local function applyRemoveInteractingSounds(value)
    local mg = findMainGame()
    if not mg then return end
    pcall(function()
        local ps = mg:FindFirstChild("PromptService")
        if ps then
            if ps:FindFirstChild("Triggered")    then ps.Triggered.Volume    = value and 0 or 0.04  end
            if ps:FindFirstChild("Holding")      then ps.Holding.Volume      = value and 0 or 0.1   end
            if ps:FindFirstChild("Notification") then ps.Notification.Volume = value and 0 or 0.03  end
        end
        local reminder = mg:FindFirstChild("Reminder")
        if reminder then
            local caption = reminder:FindFirstChild("Caption")
            if caption then caption.Volume = value and 0 or 0.1 end
        end
    end)
end

local function applyRemoveFootstepSounds(value)
    -- Footstep sounds live in the Main_Game Footstep Sound instances
    local mg = findMainGame()
    if not mg then return end
    pcall(function()
        for _, obj in mg:GetDescendants() do
            if obj:IsA("Sound") and obj.Name:lower():find("foot") then
                obj.Volume = value and 0 or obj:GetAttribute("Volume_Old") or 1
                if not obj:GetAttribute("Volume_Old") and not value then
                    obj:SetAttribute("Volume_Old", obj.Volume)
                end
            end
        end
    end)
end

------------------------------------------------------
-- BUILD — General tab (left tabbox)
------------------------------------------------------

local function buildGeneral()
    local box = GeneralGroupbox
    if not box then return false end

    -- Door Reach
    Elements.DoorReachToggle = UI:AddToggle(box, "DoorReachToggle", {
        Text    = "Door Reach",
        Default = false,
        Tooltip = "Allows you to open doors from further away (within 75 studs).",
    })

    -- Prompt Reach Multiplier
    Elements.PromptReachSlider = UI:AddSlider(box, "PromptReachSlider", {
        Text     = "Prompt Reach Multiplier",
        Min      = 1, Max = 2, Default = 1,
        Rounding = 1, Compact = true,
    })

    -- Instant Prompts
    Elements.InstantPrompts = UI:AddToggle(box, "InstantPrompts", {
        Text    = "Instant Prompts",
        Default = false,
        Tooltip = "Allows you to trigger all prompts instantly.",
    })

    -- Prompt Clip
    Elements.PromptClip = UI:AddToggle(box, "PromptClip", {
        Text    = "Prompt Clip",
        Default = false,
        Tooltip = "Allows you to interact with prompts through walls.",
    })

    UI:AddDivider(box)

    -- Remove Closet Delay
    Elements.RemoveClosetDelay = UI:AddToggle(box, "RemoveClosetDelay", {
        Text    = "Remove Closet Delay",
        Default = false,
        Tooltip = "Removes the window where you can't exit a closet after the animation.",
    })

    return true
end

------------------------------------------------------
-- BYPASS RUNTIME STATE
------------------------------------------------------

local ManipulateBody = nil   -- BodyVelocity for Velocity mode
local AnticheatDisabled = false
local DefaultHipHeight  = 2.396
local InfCrucifixConn   = nil

local InfCrucifixDropTable = {
    RushMoving   = 54,  AmbushMoving = 67, A60         = 70,
    GlitchRush   = 120, GlitchAmbush = 155, A120       = 75,
}

------------------------------------------------------
-- BUILD — Bypass tab (left tabbox)
------------------------------------------------------

local function buildBypass()
    local box = BypassGroupbox
    if not box then return false end

    --------------------------------------------------
    -- Anticheat Bypass
    --------------------------------------------------
    Elements.DisableAnticheat = UI:AddToggle(box, "DisableAnticheat", {
        Text    = "Anticheat Bypass",
        Default = false,
        Tooltip = "Completely disables the anticheat, after interacting with a ladder.",
    })

    --------------------------------------------------
    -- Velocity Manipulation + Method Dropdown
    --------------------------------------------------
    Elements.VelocityManipulationToggle = UI:AddToggle(box, "VelocityManipulationToggle", {
        Text    = "Velocity Manipulation",
        Default = false,
        Tooltip = "Moves your character forward slowly, mitigating the game's anti-noclip.",
    })

    Elements.VelocityManipulationMode = UI:AddDropdown(box, "VelocityManipulationMode", {
        Text    = "Manipulation Method",
        Values  = { "Velocity", "Pivot" },
        Default = 1,
    })

    UI:AddDivider(box)

    --------------------------------------------------
    -- Infinite Items + Item List dropdown
    --------------------------------------------------
    local hasFirePrompt = type(fireproximityprompt) == "function"

    Elements.InfiniteItemsToggle = UI:AddToggle(box, "InfiniteItemsToggle", {
        Text     = "Infinite Items",
        Default  = false,
        Tooltip  = "Allows certain items to be used without draining their uses.",
        Disabled = not hasFirePrompt,
        DisabledTooltip = "Requires 'fireproximityprompt' executor support.",
    })

    Elements.InfiniteItemsList = UI:AddDropdown(box, "InfiniteItemsList", {
        Text     = "Item List",
        Values   = { "Lockpicks", "Skeleton Key", "Shears", "Multitool" },
        Multi    = true,
        AllowNull = true,
        Disabled = not hasFirePrompt,
        DisabledTooltip = "Requires 'fireproximityprompt' executor support.",
    })

    --------------------------------------------------
    -- Infinite Crucifix
    --------------------------------------------------
    Elements.InfCrucifix = UI:AddToggle(box, "InfCrucifix", {
        Text    = "Infinite Crucifix",
        Default = false,
        Tooltip = "Risky! You can die or lose the Crucifix.",
    })

    UI:AddDivider(box)

    --------------------------------------------------
    -- Position Spoof + Crouch Spoof
    --------------------------------------------------
    Elements.PositionSpoof = UI:AddToggle(box, "PositionSpoof", {
        Text    = "Position Spoof",
        Default = false,
        Tooltip = "Makes your character appear underground on the server, protecting you from rush-like entities.",
    })

    Elements.CrouchSpoof = UI:AddToggle(box, "CrouchSpoof", {
        Text    = "Crouch Spoof",
        Default = false,
        Tooltip = "Makes the game think you are always crouching.",
    })


    return true
end

------------------------------------------------------
-- BUILD — Miscellaneous (right groupbox)
------------------------------------------------------

local function buildMisc()
    local box = UI:AddRightGroupbox(Tab, "Miscellaneous", "list")
    if not box then return false end
    Groups.Misc = box

    UI:AddButton(box, {
        Text       = "Play Again",
        Tooltip    = "Makes you join a new run. Double-click to confirm.",
        DoubleClick = true,
        Func        = function()
            if RemotesFolder and RemotesFolder:FindFirstChild("PlayAgain") then
                pcall(function() RemotesFolder.PlayAgain:FireServer() end)
            end
        end,
    })

    UI:AddButton(box, {
        Text        = "Return to Lobby",
        Tooltip     = "Teleports you back to the lobby. Double-click to confirm.",
        DoubleClick = true,
        Func        = function()
            if RemotesFolder and RemotesFolder:FindFirstChild("Lobby") then
                pcall(function() RemotesFolder.Lobby:FireServer() end)
            end
        end,
    })

    UI:AddButton(box, {
        Text        = "Revive",
        Tooltip     = "Revives you if you have a revive available. Double-click to confirm.",
        DoubleClick = true,
        Func        = function()
            if RemotesFolder and RemotesFolder:FindFirstChild("Revive") then
                pcall(function() RemotesFolder.Revive:FireServer() end)
            end
        end,
    })

    UI:AddButton(box, {
        Text        = "Reset Character",
        Tooltip     = "Kills your character on the server. Double-click to confirm.",
        DoubleClick = true,
        Func        = doResetCharacter,
    })

    return true
end

------------------------------------------------------
-- BUILD — Debug (right groupbox)
------------------------------------------------------

local function buildDebug()
    local box = UI:AddRightGroupbox(Tab, "Debug", "bug")
    if not box then return false end
    Groups.Debug = box

    UI:AddButton(box, {
        Text    = "Void",
        Tooltip = "Teleports your character to Y -120.",
        Func    = function()
            if not Character then return end
            local pivot = Character:GetPivot()
            local target = pivot + Vector3.new(0, -120 - pivot.Position.Y, 0)
            -- Multiple PivotTo calls to overcome server rubber-banding
            for _ = 1, 22 do
                pcall(function() Character:PivotTo(target) end)
            end
        end,
    })

    UI:AddButton(box, {
        Text    = "Exit Closet",
        Tooltip = "Exits the current closet.",
        Func    = function()
            if RemotesFolder and RemotesFolder:FindFirstChild("CamLock") then
                pcall(function() RemotesFolder.CamLock:FireServer() end)
            end
        end,
    })

    UI:AddButton(box, {
        Text    = "Tp Next Door",
        Tooltip = "Teleports you to the next sequential unopened door.",
        Func    = function()
            local door = getNextClosedDoor()
            if door and Character then
                pcall(function() Character:PivotTo(door:GetPivot()) end)
            end
        end,
    })

    Elements.AutoTpNextDoor = UI:AddToggle(box, "AutoTpNextDoor", {
        Text    = "Auto Tp Next Door",
        Default = false,
        Tooltip = "Continuously teleports you to the next sequential unopened door.",
    })

    return true
end

------------------------------------------------------
-- BUILD — Audio (right groupbox)
------------------------------------------------------

local function buildAudio()
    local box = UI:AddRightGroupbox(Tab, "Audio", "volume-2")
    if not box then return false end
    Groups.Audio = box

    Elements.RemoveFootstepSounds = UI:AddToggle(box, "RemoveFootstepSounds", {
        Text    = "Remove Footstep Sounds",
        Default = false,
        Tooltip = "Removes the sounds when walking.",
    })

    Elements.RemoveJamminMusic = UI:AddToggle(box, "RemoveJamminMusic", {
        Text    = "Remove Jammin Music",
        Default = false,
        Tooltip = "Removes the music and muffle effect from the 'Jammin' modifier.",
    })

    Elements.RemoveInteractingSounds = UI:AddToggle(box, "RemoveInteractingSounds", {
        Text    = "Remove Interacting Sounds",
        Default = false,
        Tooltip = "Removes sounds when interacting with proximity prompts.",
    })

    return true
end

------------------------------------------------------
-- LIFECYCLE
------------------------------------------------------

function General:Init(CoreModules)
    if Initialized then return self end

    Core = CoreModules or {}
    Services = Core.Services
    Connections = Core.Connections
    Notifications = Core.Notifications
    UI = Core.UI

    if not Services or not Connections or not UI then
        warn("[JustXDoors General] Core modules are missing.")
        return self
    end

    -- General uses the already-created Main tab from root Main.lua.
    if Core.Main and Core.Main.Tabs then
        Tab = Core.Main.Tabs.Main
    end

    if not Tab then
        warn("[JustXDoors General] Core.Main.Tabs.Main is missing.")
        return self
    end

    local RS = Services.ReplicatedStorage
    if RS then
        GameData = RS:FindFirstChild("GameData")
        LiveModifiers = RS:FindFirstChild("LiveModifiers")
        RemotesFolder = RS:FindFirstChild("RemotesFolder") or RS:WaitForChild("RemotesFolder", 10)
    end

    refreshCharacter()

    Initialized = true
    return self
end

function General:Build()
    if Built then return self end
    if not Initialized then
        warn("[JustXDoors General] Build() called before Init().")
        return self
    end

    -- Left side: General + Bypass
    local leftTabbox
    local ok, result = pcall(function()
        return Tab:AddLeftTabbox("General")
    end)

    if ok and result then
        leftTabbox = result
        GeneralGroupbox = leftTabbox:AddTab("General")
        BypassGroupbox = leftTabbox:AddTab("Bypass")
    else
        -- Fallback for environments where tabboxes are unavailable.
        warn("[JustXDoors General] AddLeftTabbox unavailable, using normal groupboxes.")
        GeneralGroupbox = UI:AddLeftGroupbox(Tab, "General", "settings-2")
        BypassGroupbox = UI:AddLeftGroupbox(Tab, "Bypass", "shield")
    end

    local builders = {
        {"General", buildGeneral},
        {"Bypass", buildBypass},
        {"Miscellaneous", buildMisc},
        {"Debug", buildDebug},
        {"Audio", buildAudio},
    }

    for _, entry in ipairs(builders) do
        local name, builder = entry[1], entry[2]
        local buildOk, buildResult = pcall(builder)
        if not buildOk then
            warn("[JustXDoors General] " .. name .. " Build failed: " .. tostring(buildResult))
        elseif buildResult == false then
            warn("[JustXDoors General] " .. name .. " section could not be created.")
        end
    end

    self:Connect()

    Built = true
    return self
end

------------------------------------------------------
-- CONNECTIONS
------------------------------------------------------

function General:Connect()
    if Connected then return end
    if not Services or not Connections then return end
    Connected = true

    local lp = Services.LocalPlayer

    -- CharacterAdded
    if lp then
        Connections:Connect(lp.CharacterAdded, function(char)
            Character = char
            Humanoid  = char:WaitForChild("Humanoid",         10)
            RootPart  = char:WaitForChild("HumanoidRootPart", 10)

            -- Setup ManipulateBody for VelocityManipulation
            task.defer(function()
                if ManipulateBody then pcall(function() ManipulateBody:Destroy() end) end
                ManipulateBody = Instance.new("BodyVelocity")
                ManipulateBody.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                ManipulateBody.Velocity  = Vector3.zero
            end)
        end, "GameGeneral")
    end

    --------------------------------------------------
    -- General toggles
    --------------------------------------------------

    local function onPromptSetting()
        refreshAllPrompts()
    end

    for _, key in { "PromptReachSlider", "InstantPrompts", "PromptClip" } do
        local el = Elements[key]
        if el and type(el.OnChanged) == "function" then
            el:OnChanged(onPromptSetting)
        end
    end

    --------------------------------------------------
    -- BYPASS connections
    --------------------------------------------------

    -- Anticheat Bypass — restore on toggle off by firing ClimbLadder
    local el_ac = Elements.DisableAnticheat
    if el_ac and type(el_ac.OnChanged) == "function" then
        el_ac:OnChanged(function(v)
            if not v and AnticheatDisabled then
                if RemotesFolder and RemotesFolder:FindFirstChild("ClimbLadder") then
                    pcall(function() RemotesFolder.ClimbLadder:FireServer() end)
                end
                AnticheatDisabled = false
            end
        end)
    end

    -- Position Spoof
    local el_ps = Elements.PositionSpoof
    if el_ps and type(el_ps.OnChanged) == "function" then
        el_ps:OnChanged(function(v)
            if not RootPart or not Humanoid then return end
            local floor = getFloor()
            if floor == "Fools" or floor == "OldHotel" then return end
            if v then
                pcall(function()
                    RootPart.CFrame  = RootPart.CFrame * CFrame.new(0, -2.346, 0)
                    Humanoid.HipHeight = 0.05
                end)
                if RemotesFolder and RemotesFolder:FindFirstChild("Crouch") then
                    pcall(function() RemotesFolder.Crouch:FireServer(true, true) end)
                end
            else
                pcall(function()
                    RootPart.CFrame  = RootPart.CFrame * CFrame.new(0, 2.346, 0)
                    Humanoid.HipHeight = DefaultHipHeight
                end)
            end
        end)
    end

    -- Crouch Spoof
    local el_cs = Elements.CrouchSpoof
    if el_cs and type(el_cs.OnChanged) == "function" then
        el_cs:OnChanged(function(v)
            if RemotesFolder and RemotesFolder:FindFirstChild("Crouch") then
                pcall(function() RemotesFolder.Crouch:FireServer(v or false, true) end)
            end
        end)
    end



    Built = true
    return self
end

------------------------------------------------------
-- DESTROY
------------------------------------------------------

function General:Destroy()
    if TpNextDoorThread then
        task.cancel(TpNextDoorThread)
        TpNextDoorThread = nil
    end

    if InfCrucifixConn then
        InfCrucifixConn:Disconnect()
        InfCrucifixConn = nil
    end


    -- Restore ManipulateBody
    if ManipulateBody then
        pcall(function() ManipulateBody:Destroy() end)
        ManipulateBody = nil
    end

    -- Restore Position Spoof
    if Elements.PositionSpoof and Elements.PositionSpoof.Value then
        if RootPart and Humanoid then
            pcall(function()
                RootPart.CFrame    = RootPart.CFrame * CFrame.new(0, 2.346, 0)
                Humanoid.HipHeight = DefaultHipHeight
            end)
        end
    end

    -- Restore prompts
    for _, p in Objects.Prompts do
        pcall(function()
            p.HoldDuration          = p:GetAttribute("HoldDuration_Old")         or p.HoldDuration
            p.RequiresLineOfSight   = p:GetAttribute("RequiresLineOfSight_Old")   or p.RequiresLineOfSight
            p.MaxActivationDistance = p:GetAttribute("MaxActivationDistance_Old") or p.MaxActivationDistance
        end)
    end

    applyRemoveJamminMusic(false)
    applyRemoveInteractingSounds(false)

    if Connections then Connections:DisconnectGroup("GameGeneral") end

    Objects = { Prompts={}, Entities={}, Obstructions={}, SeekObstructions={}, SeekBridges={} }
    Groups, Elements = {}, {}
    Tab, GeneralGroupbox, BypassGroupbox = nil, nil, nil
    Character, Humanoid, RootPart = nil, nil, nil
    RemotesFolder, GameData, LiveModifiers = nil, nil, nil
    LastDoorFire, JamMuffle = 0, nil
    AnticheatDisabled = false

    Initialized, Built, Connected = false, false, false
    Core, Services, Connections, Notifications, UI = nil, nil, nil, nil, nil
end

return General
