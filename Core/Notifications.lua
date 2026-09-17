local Notifications = {}

local Services = require("Core/Services")
local Environment = require("Core/Environment")
local Settings = require("Core/Settings")

local Players = Services.Players
local TweenService = Services.TweenService

local LocalPlayer = Players.LocalPlayer

local gethui = Environment:Get("gethui")

Notifications.Library = nil
Notifications.Gui = nil
Notifications.Container = nil

Notifications.Active = {}
Notifications._counter = 0

Notifications._destroyed = false

local COLORS = {
    Default = Color3.fromRGB(
        95,
        140,
        255
    ),

    Success = Color3.fromRGB(
        75,
        205,
        125
    ),

    Warning = Color3.fromRGB(
        245,
        180,
        70
    ),

    Error = Color3.fromRGB(
        235,
        80,
        90
    ),

    Info = Color3.fromRGB(
        80,
        165,
        245
    )
}

local ICONS = {
    Default = "•",
    Success = "✓",
    Warning = "!",
    Error = "×",
    Info = "i"
}

local function safeNumber(value, fallback)
    value = tonumber(value)

    if value == nil then
        return fallback
    end

    return value
end

local function safeColor(value, fallback)
    if typeof(value) == "Color3" then
        return value
    end

    return fallback
end

local function create(className, properties)
    local instance =
        Instance.new(className)

    for property, value in pairs(properties or {}) do
        pcall(function()
            instance[property] = value
        end)
    end

    return instance
end

local function getGuiParent()
    if type(gethui) == "function" then
        local success, result =
            pcall(gethui)

        if success and result then
            return result
        end
    end

    if LocalPlayer then
        local playerGui =
            LocalPlayer:FindFirstChildOfClass(
                "PlayerGui"
            )

        if playerGui then
            return playerGui
        end
    end

    return nil
end

local function tween(instance, info, properties)
    local success, result =
        pcall(function()
            local animation =
                TweenService:Create(
                    instance,
                    info,
                    properties
                )

            animation:Play()

            return animation
        end)

    if success then
        return result
    end

    return nil
end

function Notifications:SetLibrary(library)
    self.Library = library

    if library then
        pcall(function()
            library:SetNotifySide(
                Settings:Get(
                    "Notifications.Side"
                )
            )
        end)
    end

    return true
end

function Notifications:GetProvider()
    return Settings:Get(
        "Notifications.Provider"
    )
end

function Notifications:SetProvider(provider)
    provider = tostring(provider)

    if provider ~= "JustXDoors"
        and provider ~= "Obsidian"
    then
        return false, "Invalid notification provider"
    end

    if provider == "Obsidian"
        and not self.Library
    then
        return false,
            "Obsidian library is not loaded"
    end

    Settings:Set(
        "Notifications.Provider",
        provider
    )

    if provider == "JustXDoors" then
        self:_CreateGui()
    else
        self:_DestroyGui()
    end

    return true
end

function Notifications:SetSide(side)
    side = tostring(side)

    if side ~= "Left"
        and side ~= "Right"
    then
        return false
    end

    Settings:Set(
        "Notifications.Side",
        side
    )

    Settings:Set(
        "UI.NotifySide",
        side
    )

    if self.Library then
        pcall(function()
            self.Library:SetNotifySide(
                side
            )
        end)
    end

    self:_UpdateContainerSide()

    return true
end

function Notifications:GetSide()
    return Settings:Get(
        "Notifications.Side"
    )
end

function Notifications:_UpdateContainerSide()
    local container = self.Container

    if not container then
        return
    end

    local side =
        self:GetSide()

    if side == "Left" then
        container.AnchorPoint =
            Vector2.new(0, 0)

        container.Position =
            UDim2.new(
                0,
                Settings:Get(
                    "Notifications.JustXDoors.Offset"
                ) or 14,
                0,
                Settings:Get(
                    "Notifications.JustXDoors.Offset"
                ) or 14
            )

        container.UIListLayout.HorizontalAlignment =
            Enum.HorizontalAlignment.Left
    else
        container.AnchorPoint =
            Vector2.new(1, 0)

        container.Position =
            UDim2.new(
                1,
                -(Settings:Get(
                    "Notifications.JustXDoors.Offset"
                ) or 14),
                0,
                Settings:Get(
                    "Notifications.JustXDoors.Offset"
                ) or 14
            )

        container.UIListLayout.HorizontalAlignment =
            Enum.HorizontalAlignment.Right
    end
end

function Notifications:_CreateGui()
    if self.Gui
        and self.Gui.Parent
    then
        self:_UpdateContainerSide()
        return self.Gui
    end

    local parent = getGuiParent()

    if not parent then
        return nil
    end

    local gui =
        create("ScreenGui", {
            Name = "JustXDoorsNotifications",

            ResetOnSpawn = false,

            IgnoreGuiInset = true,

            ZIndexBehavior =
                Enum.ZIndexBehavior.Sibling,

            DisplayOrder = 999999
        })

    local container =
        create("Frame", {
            Name = "Container",

            BackgroundTransparency = 1,

            Size = UDim2.fromOffset(
                Settings:Get(
                    "Notifications.JustXDoors.Width"
                ) or 330,

                0
            ),

            AutomaticSize =
                Enum.AutomaticSize.Y,

            Parent = gui
        })

    local layout =
        create("UIListLayout", {
            Name = "UIListLayout",

            FillDirection =
                Enum.FillDirection.Vertical,

            SortOrder =
                Enum.SortOrder.LayoutOrder,

            Padding = UDim.new(
                0,
                Settings:Get(
                    "Notifications.JustXDoors.Gap"
                ) or 8
            ),

            HorizontalAlignment =
                Enum.HorizontalAlignment.Right,

            VerticalAlignment =
                Enum.VerticalAlignment.Top,

            Parent = container
        })

    create("UIPadding", {
        PaddingTop = UDim.new(0, 2),
        Parent = container
    })

    gui.Parent = parent

    self.Gui = gui
    self.Container = container

    self:_UpdateContainerSide()

    return gui
end

function Notifications:_DestroyGui()
    if self.Gui then
        pcall(function()
            self.Gui:Destroy()
        end)
    end

    self.Gui = nil
    self.Container = nil

    table.clear(self.Active)
end

function Notifications:_RemoveFromActive(notification)
    for index =
        #self.Active,
        1,
        -1
    do
        if self.Active[index]
            == notification
        then
            table.remove(
                self.Active,
                index
            )

            break
        end
    end
end

function Notifications:_CreateCustom(options)
    self:_CreateGui()

    if not self.Container then
        return nil
    end

    local settings =
        Settings.Data.Notifications

    local custom =
        settings.JustXDoors

    local maxVisible =
        safeNumber(
            settings.MaxVisible,
            5
        )

    while #self.Active >= maxVisible do
        local oldest =
            self.Active[1]

        if oldest
            and oldest.Destroy
        then
            oldest:Destroy()
        else
            table.remove(
                self.Active,
                1
            )
        end
    end

    self._counter += 1

    local title =
        tostring(
            options.Title
            or "JustXDoors"
        )

    local description =
        tostring(
            options.Description
            or options.Text
            or ""
        )

    local duration =
        safeNumber(
            options.Time
            or options.Duration,
            settings.DefaultDuration
        )

    local notificationType =
        tostring(
            options.Type
            or "Default"
        )

    local accent =
        safeColor(
            options.Color,
            COLORS[
                notificationType
            ]
            or COLORS.Default
        )

    local icon =
        tostring(
            options.Icon
            or ICONS[
                notificationType
            ]
            or ICONS.Default
        )

    local holder =
        create("Frame", {
            Name =
                "Notification_" ..
                tostring(self._counter),

            BackgroundTransparency = 1,

            Size = UDim2.new(
                1,
                0,
                0,
                custom.Height
            ),

            LayoutOrder =
                self._counter,

            Parent =
                self.Container
        })

    local card =
        create("Frame", {
            Name = "Card",

            BackgroundColor3 =
                Color3.fromRGB(
                    20,
                    22,
                    27
                ),

            BackgroundTransparency = 0.02,

            Size =
                UDim2.fromOffset(
                    custom.Width,
                    custom.Height
                ),

            AnchorPoint =
                Vector2.new(1, 0),

            Position =
                UDim2.new(
                    1,
                    custom.Width + 20,
                    0,
                    0
                ),

            Parent = holder
        })

    create("UICorner", {
        CornerRadius =
            UDim.new(
                0,
                custom.CornerRadius
            ),

        Parent = card
    })

    local stroke =
        create("UIStroke", {
            Color =
                Color3.fromRGB(
                    55,
                    59,
                    68
                ),

            Transparency = 0.35,

            Thickness = 1,

            Parent = card
        })

    local accentBar =
        create("Frame", {
            Name = "Accent",

            BackgroundColor3 =
                accent,

            BorderSizePixel = 0,

            Size =
                UDim2.new(
                    0,
                    3,
                    1,
                    -14
                ),

            Position =
                UDim2.fromOffset(
                    0,
                    7
                ),

            Parent = card
        })

    create("UICorner", {
        CornerRadius =
            UDim.new(
                0,
                2
            ),

        Parent = accentBar
    })

    local iconFrame =
        create("Frame", {
            Name = "IconFrame",

            BackgroundColor3 =
                accent,

            BackgroundTransparency =
                0.84,

            Size =
                UDim2.fromOffset(
                    34,
                    34
                ),

            Position =
                UDim2.fromOffset(
                    13,
                    13
                ),

            Parent = card
        })

    create("UICorner", {
        CornerRadius =
            UDim.new(
                0,
                9
            ),

        Parent = iconFrame
    })

    local iconLabel =
        create("TextLabel", {
            BackgroundTransparency = 1,

            Size =
                UDim2.fromScale(
                    1,
                    1
                ),

            Text = icon,

            TextColor3 =
                accent,

            Font =
                Enum.Font.GothamBold,

            TextSize = 17,

            Parent = iconFrame
        })

    local titleLabel =
        create("TextLabel", {
            Name = "Title",

            BackgroundTransparency = 1,

            Size =
                UDim2.new(
                    1,
                    -72,
                    0,
                    21
                ),

            Position =
                UDim2.fromOffset(
                    58,
                    10
                ),

            Text =
                title,

            TextColor3 =
                Color3.fromRGB(
                    245,
                    247,
                    250
                ),

            Font =
                Enum.Font.GothamSemibold,

            TextSize = 14,

            TextXAlignment =
                Enum.TextXAlignment.Left,

            TextTruncate =
                Enum.TextTruncate.AtEnd,

            Parent = card
        })

    local descriptionLabel =
        create("TextLabel", {
            Name = "Description",

            BackgroundTransparency = 1,

            Size =
                UDim2.new(
                    1,
                    -72,
                    0,
                    30
                ),

            Position =
                UDim2.fromOffset(
                    58,
                    31
                ),

            Text =
                description,

            TextColor3 =
                Color3.fromRGB(
                    165,
                    170,
                    180
                ),

            Font =
                Enum.Font.Gotham,

            TextSize = 12,

            TextWrapped = true,

            TextXAlignment =
                Enum.TextXAlignment.Left,

            TextYAlignment =
                Enum.TextYAlignment.Top,

            Parent = card
        })

    local progress

    if custom.ProgressBar then
        progress =
            create("Frame", {
                Name = "Progress",

                BackgroundColor3 =
                    accent,

                BorderSizePixel = 0,

                Size =
                    UDim2.new(
                        1,
                        -18,
                        0,
                        2
                    ),

                Position =
                    UDim2.new(
                        0,
                        9,
                        1,
                        -6
                    ),

                Parent = card
            })

        create("UICorner", {
            CornerRadius =
                UDim.new(
                    0,
                    1
                ),

            Parent = progress
        })
    end

    local clickButton

    if custom.ClickToDismiss then
        clickButton =
            create("TextButton", {
                Name = "Dismiss",

                BackgroundTransparency = 1,

                BorderSizePixel = 0,

                Size =
                    UDim2.fromScale(
                        1,
                        1
                    ),

                Text = "",

                AutoButtonColor = false,

                Parent = card
            })
    end

    local object = {}

    object.Holder = holder
    object.Card = card
    object.Title = titleLabel
    object.Description = descriptionLabel
    object.Progress = progress
    object.Destroyed = false

    local function destroy()
        if object.Destroyed then
            return
        end

        object.Destroyed = true

        self:_RemoveFromActive(
            object
        )

        local animation =
            tween(
                card,

                TweenInfo.new(
                    custom.AnimationTime,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.In
                ),

                {
                    Position =
                        UDim2.new(
                            1,
                            custom.Width + 25,
                            0,
                            0
                        ),

                    BackgroundTransparency = 1
                }
            )

        if animation then
            animation.Completed:Wait()
        end

        pcall(function()
            holder:Destroy()
        end)
    end

    object.Destroy = destroy

    if clickButton then
        clickButton.Activated:Connect(
            destroy
        )
    end

    table.insert(
        self.Active,
        object
    )

    tween(
        card,

        TweenInfo.new(
            custom.AnimationTime,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out
        ),

        {
            Position =
                UDim2.new(
                    1,
                    0,
                    0,
                    0
                )
        }
    )

    if progress
        and duration > 0
    then
        tween(
            progress,

            TweenInfo.new(
                duration,
                Enum.EasingStyle.Linear
            ),

            {
                Size =
                    UDim2.new(
                        0,
                        0,
                        0,
                        2
                    )
            }
        )
    end

    task.delay(
        math.max(
            duration,
            0.1
        ),
        function()
            if not object.Destroyed then
                destroy()
            end
        end
    )

    return object
end

function Notifications:_NotifyObsidian(options)
    if not self.Library then
        return nil, "Obsidian library unavailable"
    end

    local settings =
        Settings.Data.Notifications

    local duration =
        safeNumber(
            options.Time
            or options.Duration,
            settings.DefaultDuration
        )

    local data = {
        Title =
            options.Title
            or "JustXDoors",

        Description =
            options.Description
            or options.Text
            or "",

        Time = duration,

        Icon = options.Icon
    }

    if settings.SoundEnabled
        and settings.SoundId
    then
        data.SoundId =
            settings.SoundId

        data.Volume =
            settings.SoundVolume
    elseif options.SoundId then
        data.SoundId =
            options.SoundId

        data.Volume =
            options.Volume
    end

    local success, result =
        pcall(function()
            return self.Library:Notify(
                data
            )
        end)

    if success then
        return result
    end

    return nil, result
end

function Notifications:Notify(options)
    options =
        type(options) == "table"
        and options
        or {}

    local provider =
        self:GetProvider()

    if provider == "Obsidian" then
        local result, errorMessage =
            self:_NotifyObsidian(
                options
            )

        if result then
            return result
        end

        warn(
            "[JustXDoors Notifications] " ..
            "Obsidian failed: " ..
            tostring(errorMessage)
        )
    end

    return self:_CreateCustom(
        options
    )
end

function Notifications:Success(
    title,
    description,
    duration
)
    return self:Notify({
        Title = title,
        Description = description,
        Duration = duration,
        Type = "Success"
    })
end

function Notifications:Warning(
    title,
    description,
    duration
)
    return self:Notify({
        Title = title,
        Description = description,
        Duration = duration,
        Type = "Warning"
    })
end

function Notifications:Error(
    title,
    description,
    duration
)
    return self:Notify({
        Title = title,
        Description = description,
        Duration = duration,
        Type = "Error"
    })
end

function Notifications:Info(
    title,
    description,
    duration
)
    return self:Notify({
        Title = title,
        Description = description,
        Duration = duration,
        Type = "Info"
    })
end

function Notifications:Remove(notification)
    if notification
        and type(
            notification.Destroy
        ) == "function"
    then
        notification:Destroy()
    end
end

function Notifications:Clear()
    for index =
        #self.Active,
        1,
        -1
    do
        local notification =
            self.Active[index]

        if notification
            and notification.Destroy
        then
            notification:Destroy()
        end
    end

    table.clear(self.Active)
end

function Notifications:Destroy()
    self:Clear()

    self:_DestroyGui()

    self.Library = nil

    self._destroyed = true
end

return Notifications
