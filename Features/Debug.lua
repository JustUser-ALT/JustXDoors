local Debug = {}

local Services
local Environment
local Connections
local Notifications
local UI
local Settings

local Elements = {}

local Built = false
local Refreshing = false

------------------------------------------------------
-- HELPERS
------------------------------------------------------

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return false
    end

    local success, result = pcall(callback, ...)

    if not success then
        warn(
            "[JustXDoors Debug] "
                .. tostring(result)
        )

        return false
    end

    return true, result
end

local function notifyInfo(title, description, time)
    if not Notifications then
        return
    end

    safeCall(
        function()
            Notifications:Info(
                title,
                description,
                time or 4
            )
        end
    )
end

local function notifySuccess(description)
    if not Notifications then
        return
    end

    safeCall(
        function()
            Notifications:Success(
                "Debug",
                description,
                4
            )
        end
    )
end

local function notifyWarning(description)
    if not Notifications then
        return
    end

    safeCall(
        function()
            Notifications:Warning(
                "Debug",
                description,
                4
            )
        end
    )
end

local function notifyError(description)
    if not Notifications then
        return
    end

    safeCall(
        function()
            Notifications:Error(
                "Debug",
                description,
                5
            )
        end
    )
end

local function getPlayer()
    if Services and Services.LocalPlayer then
        return Services.LocalPlayer
    end

    return game:GetService("Players").LocalPlayer
end

local function getCharacter()
    if Services
        and type(Services.GetCharacter) == "function"
    then
        return Services:GetCharacter()
    end

    local player = getPlayer()

    if player then
        return player.Character
    end

    return nil
end

local function getHumanoid()
    if Services
        and type(Services.GetHumanoid) == "function"
    then
        return Services:GetHumanoid()
    end

    local character = getCharacter()

    if not character then
        return nil
    end

    return character:FindFirstChildOfClass(
        "Humanoid"
    )
end

local function getRootPart()
    if Services
        and type(Services.GetRootPart) == "function"
    then
        return Services:GetRootPart()
    end

    local character = getCharacter()

    if not character then
        return nil
    end

    return character:FindFirstChild(
        "HumanoidRootPart"
    )
end

------------------------------------------------------
-- INIT
------------------------------------------------------

function Debug:Init(Core)
    if type(Core) ~= "table" then
        return false
    end

    Services = Core.Services
    Environment = Core.Environment
    Connections = Core.Connections
    Notifications = Core.Notifications
    UI = Core.UI
    Settings = Core.Settings

    Elements = {}

    Built = false
    Refreshing = false

    return true
end

------------------------------------------------------
-- ENVIRONMENT
------------------------------------------------------

function Debug:GetEnvironmentInfo()
    if not Environment then
        return nil
    end

    local info

    safeCall(
        function()
            info = Environment:GetInfo()
        end
    )

    return info
end

function Debug:ShowExecutorInfo()
    if not Environment then
        notifyError(
            "Environment module is unavailable."
        )

        return
    end

    local name = "Unknown"
    local version = "Unknown"

    safeCall(
        function()
            name =
                Environment:GetExecutorName()
                or "Unknown"

            version =
                Environment:GetExecutorVersion()
                or "Unknown"
        end
    )

    notifyInfo(
        "Executor",
        "Name: "
            .. tostring(name)
            .. "\nVersion: "
            .. tostring(version),
        6
    )
end

function Debug:ShowCapabilities()
    if not Environment then
        notifyError(
            "Environment module is unavailable."
        )

        return
    end

    local capabilities

    safeCall(
        function()
            capabilities =
                Environment.Capabilities
        end
    )

    if type(capabilities) ~= "table" then
        notifyError(
            "Capabilities are unavailable."
        )

        return
    end

    local enabled = {}
    local disabled = {}

    for name, value in pairs(
        capabilities
    ) do
        if value == true then
            table.insert(
                enabled,
                tostring(name)
            )
        else
            table.insert(
                disabled,
                tostring(name)
            )
        end
    end

    table.sort(enabled)
    table.sort(disabled)

    local text =
        "Enabled: "
        .. tostring(#enabled)

    if #enabled > 0 then
        text =
            text
            .. "\n"
            .. table.concat(
                enabled,
                ", "
            )
    end

    notifyInfo(
        "Capabilities",
        text,
        8
    )
end

------------------------------------------------------
-- CONNECTIONS
------------------------------------------------------

function Debug:ShowConnections()
    if not Connections then
        notifyError(
            "Connections module is unavailable."
        )

        return
    end

    local count = 0

    safeCall(
        function()
            count =
                Connections:Count()
        end
    )

    notifyInfo(
        "Connections",
        "Active connections: "
            .. tostring(count),
        5
    )
end

------------------------------------------------------
-- PLAYER INFO
------------------------------------------------------

function Debug:ShowPlayerInfo()
    local player = getPlayer()

    if not player then
        notifyError(
            "LocalPlayer is unavailable."
        )

        return
    end

    local character =
        getCharacter()

    local humanoid =
        getHumanoid()

    local root =
        getRootPart()

    local characterName =
        character
        and character.Name
        or "None"

    local health = "N/A"
    local maxHealth = "N/A"
    local walkspeed = "N/A"
    local jumpPower = "N/A"

    if humanoid then
        health =
            string.format(
                "%.1f",
                humanoid.Health
            )

        maxHealth =
            string.format(
                "%.1f",
                humanoid.MaxHealth
            )

        walkspeed =
            string.format(
                "%.1f",
                humanoid.WalkSpeed
            )

        jumpPower =
            string.format(
                "%.1f",
                humanoid.JumpPower
            )
    end

    local position = "N/A"

    if root then
        local p = root.Position

        position =
            string.format(
                "%.1f, %.1f, %.1f",
                p.X,
                p.Y,
                p.Z
            )
    end

    notifyInfo(
        "Player",
        "Name: "
            .. tostring(player.Name)
            .. "\nCharacter: "
            .. tostring(characterName)
            .. "\nHealth: "
            .. health
            .. " / "
            .. maxHealth
            .. "\nWalkSpeed: "
            .. walkspeed
            .. "\nJumpPower: "
            .. jumpPower
            .. "\nPosition: "
            .. position,
        8
    )
end

------------------------------------------------------
-- PERFORMANCE
------------------------------------------------------

function Debug:GetFPS()
    local RunService

    if Services then
        RunService =
            Services.RunService
    end

    if not RunService then
        RunService =
            game:GetService(
                "RunService"
            )
    end

    local start = os.clock()
    local frames = 0

    while os.clock() - start < 0.25 do
        RunService.RenderStepped:Wait()
        frames += 1
    end

    local elapsed =
        os.clock() - start

    if elapsed <= 0 then
        return 0
    end

    return frames / elapsed
end

function Debug:ShowPerformance()
    local fps = self:GetFPS()

    local memory = "N/A"

    safeCall(
        function()
            if gcinfo then
                memory =
                    string.format(
                        "%.1f MB",
                        gcinfo()
                    )
            end
        end
    )

    local ping = "N/A"

    local player = getPlayer()

    if player then
        safeCall(
            function()
                local stats =
                    player:FindFirstChild(
                        "PlayerScripts"
                    )

                if stats then
                    -- Kept intentionally safe.
                    -- Actual ping can vary between
                    -- executor/game environments.
                end
            end
        )
    end

    notifyInfo(
        "Performance",
        string.format(
            "FPS: %.0f\nMemory: %s\nPing: %s",
            fps,
            memory,
            ping
        ),
        6
    )
end

------------------------------------------------------
-- NOTIFICATIONS
------------------------------------------------------

function Debug:TestNotifications()
    if not Notifications then
        return
    end

    Notifications:Info(
        "Information",
        "Information notification test.",
        3
    )

    task.delay(
        0.25,
        function()
            if Notifications then
                Notifications:Success(
                    "Success",
                    "Success notification test.",
                    3
                )
            end
        end
    )

    task.delay(
        0.5,
        function()
            if Notifications then
                Notifications:Warning(
                    "Warning",
                    "Warning notification test.",
                    3
                )
            end
        end
    )

    task.delay(
        0.75,
        function()
            if Notifications then
                Notifications:Error(
                    "Error",
                    "Error notification test.",
                    3
                )
            end
        end
    )
end

function Debug:ClearNotifications()
    if not Notifications then
        return
    end

    safeCall(
        function()
            Notifications:Clear()
        end
    )

    notifySuccess(
        "All notifications cleared."
    )
end

------------------------------------------------------
-- UI
------------------------------------------------------

function Debug:ReloadUI()
    if not UI then
        notifyError(
            "UI module is unavailable."
        )

        return
    end

    notifyWarning(
        "Reloading UI..."
    )

    task.defer(
        function()
            safeCall(
                function()
                    UI:Unload()
                end
            )

            task.wait(0.2)

            local loaded =
                safeCall(
                    function()
                        return UI:Load()
                    end
                )

            if not loaded then
                notifyError(
                    "Failed to load UI."
                )

                return
            end

            task.wait(0.15)

            local created =
                safeCall(
                    function()
                        return UI:Create()
                    end
                )

            if created then
                notifySuccess(
                    "UI reloaded."
                )
            else
                notifyError(
                    "Failed to create UI."
                )
            end
        end
    )
end

------------------------------------------------------
-- FULL STATUS
------------------------------------------------------

function Debug:ShowStatus()
    local player =
        getPlayer()

    local character =
        getCharacter()

    local connectionCount = 0

    if Connections then
        safeCall(
            function()
                connectionCount =
                    Connections:Count()
            end
        )
    end

    local executor = "Unknown"

    if Environment then
        safeCall(
            function()
                executor =
                    Environment:GetExecutorName()
                    or "Unknown"
            end
        )
    end

    local debugMode = false

    if Settings then
        debugMode =
            Settings:Get(
                "General.Debug"
            ) == true
    end

    notifyInfo(
        "JustXDoors Status",
        "Executor: "
            .. tostring(executor)
            .. "\nPlayer: "
            .. tostring(
                player
                    and player.Name
                    or "None"
            )
            .. "\nCharacter: "
            .. tostring(
                character
                    and character.Name
                    or "None"
            )
            .. "\nConnections: "
            .. tostring(connectionCount)
            .. "\nDebug Mode: "
            .. tostring(debugMode),
        8
    )
end

------------------------------------------------------
-- BUILD
------------------------------------------------------

function Debug:Build()
    if Built then
        return true
    end

    if not UI then
        return false
    end

    local tab =
        UI:AddTab(
            "Debug",
            "bug"
        )

    if not tab then
        return false
    end

    --------------------------------------------------
    -- Runtime
    --------------------------------------------------

    local runtimeGroup =
        UI:AddLeftGroupbox(
            tab,
            "Runtime"
        )

    runtimeGroup:AddButton(
        {
            Text = "Status",

            Func = function()
                self:ShowStatus()
            end
        }
    )

    runtimeGroup:AddButton(
        {
            Text = "Player Info",

            Func = function()
                self:ShowPlayerInfo()
            end
        }
    )

    runtimeGroup:AddButton(
        {
            Text = "Performance",

            Func = function()
                task.spawn(
                    function()
                        self:ShowPerformance()
                    end
                )
            end
        }
    )

    runtimeGroup:AddButton(
        {
            Text = "Connections",

            Func = function()
                self:ShowConnections()
            end
        }
    )

    --------------------------------------------------
    -- Environment
    --------------------------------------------------

    local environmentGroup =
        UI:AddRightGroupbox(
            tab,
            "Environment"
        )

    environmentGroup:AddButton(
        {
            Text = "Executor Info",

            Func = function()
                self:ShowExecutorInfo()
            end
        }
    )

    environmentGroup:AddButton(
        {
            Text = "Capabilities",

            Func = function()
                self:ShowCapabilities()
            end
        }
    )

    environmentGroup:AddButton(
        {
            Text = "Environment Info",

            Func = function()
                local info =
                    self:GetEnvironmentInfo()

                if type(info) ~= "table" then
                    notifyError(
                        "Environment information unavailable."
                    )

                    return
                end

                local executor =
                    info.Executor
                    or "Unknown"

                notifyInfo(
                    "Environment",
                    "Executor: "
                        .. tostring(executor),
                    5
                )
            end
        }
    )

    --------------------------------------------------
    -- Notifications
    --------------------------------------------------

    local notificationsGroup =
        UI:AddLeftGroupbox(
            tab,
            "Notifications"
        )

    notificationsGroup:AddButton(
        {
            Text = "Test All",

            Func = function()
                self:TestNotifications()
            end
        }
    )

    notificationsGroup:AddButton(
        {
            Text = "Clear",

            Func = function()
                self:ClearNotifications()
            end
        }
    )

    --------------------------------------------------
    -- UI
    --------------------------------------------------

    local uiGroup =
        UI:AddRightGroupbox(
            tab,
            "Interface"
        )

    uiGroup:AddButton(
        {
            Text = "Reload UI",

            Func = function()
                self:ReloadUI()
            end
        }
    )

    --------------------------------------------------
    -- Debug Mode
    --------------------------------------------------

    local debugGroup =
        UI:AddLeftGroupbox(
            tab,
            "Debug Options"
        )

    debugGroup:AddToggle(
        "DebugMode",
        {
            Text = "Debug Mode",

            Default =
                Settings
                and Settings:Get(
                    "General.Debug"
                )
                or false,

            Callback = function(value)
                if Refreshing then
                    return
                end

                if Settings then
                    Settings:Set(
                        "General.Debug",
                        value
                    )
                end
            end
        }
    )

    Elements.DebugMode =
        debugGroup:Get(
            "DebugMode"
        )

    Built = true

    return true
end

------------------------------------------------------
-- REFRESH
------------------------------------------------------

function Debug:Refresh()
    if not Settings then
        return false
    end

    if not Elements.DebugMode then
        return false
    end

    Refreshing = true

    pcall(
        function()
            Elements.DebugMode:SetValue(
                Settings:Get(
                    "General.Debug"
                )
            )
        end
    )

    Refreshing = false

    return true
end

------------------------------------------------------
-- DESTROY
------------------------------------------------------

function Debug:Destroy()
    Elements = {}

    Built = false
    Refreshing = false

    return true
end

return Debug
