local Services = require("Core/Services")
local Environment = require("Core/Environment")
local Settings = require("Core/Settings")

local Notifications = {}

Notifications.Library = nil
Notifications.Provider = "JustXDoors"

Notifications._gui = nil
Notifications._container = nil
Notifications._notifications = {}
Notifications._destroyed = false

local function getSetting(path, fallback)
    local value = Settings:Get(path)

    if value == nil then
        return fallback
    end

    return value
end

local function clamp(value, minValue, maxValue)
    return math.clamp(value, minValue, maxValue)
end

local function tween(instance, info, properties)
    local animation = Services.TweenService:Create(
        instance,
        info,
        properties
    )

    animation:Play()

    return animation
end

local function create(className, properties, parent)
    local instance = Instance.new(className)

    for property, value in pairs(properties or {}) do
        instance[property] = value
    end

    if parent then
        instance.Parent = parent
    end

    return instance
end

----------------------------------------------------------------
-- LIBRARY
----------------------------------------------------------------

function Notifications:SetLibrary(library)
    self.Library = library

    if self.Provider == "Obsidian" then
        return library ~= nil
    end

    return true
end

function Notifications:GetProvider()
    return self.Provider
end

function Notifications:SetProvider(provider)
    if provider ~= "JustXDoors"
        and provider ~= "Obsidian"
    then
        return false
    end

    if provider == "Obsidian"
        and not self.Library
    then
        return false
    end

    if provider == self.Provider then
        Settings:Set(
            "Notifications.Provider",
            provider
        )

        return true
    end

    if provider == "Obsidian" then
        self:_DestroyGui()
    else
        self:_CreateGui()
    end

    self.Provider = provider

    Settings:Set(
        "Notifications.Provider",
        provider
    )

    return true
end

----------------------------------------------------------------
-- SIDE
----------------------------------------------------------------

function Notifications:SetSide(side)
    if side ~= "Left"
        and side ~= "Right"
    then
        return false
    end

    Settings:Set(
        "Notifications.Side",
        side
    )

    self:_UpdateContainerSide()

    return true
end

function Notifications:_UpdateContainerSide()
    if not self._container then
        return
    end

    local side = getSetting(
        "Notifications.Side",
        "Right"
    )

    if side == "Left" then
        self._container.AnchorPoint =
            Vector2.new(0, 0)

        self._container.Position =
            UDim2.new(
                0,
                getSetting(
                    "Notifications.JustXDoors.Offset",
                    14
                ),
                0,
                getSetting(
                    "Notifications.JustXDoors.Offset",
                    14
                )
            )

        self._container.UIListLayout.HorizontalAlignment =
            Enum.HorizontalAlignment.Left
    else
        self._container.AnchorPoint =
            Vector2.new(1, 0)

        self._container.Position =
            UDim2.new(
                1,
                -getSetting(
                    "Notifications.JustXDoors.Offset",
                    14
                ),
                0,
                getSetting(
                    "Notifications.JustXDoors.Offset",
                    14
                )
            )

        self._container.UIListLayout.HorizontalAlignment =
            Enum.HorizontalAlignment.Right
    end
end

----------------------------------------------------------------
-- GUI
----------------------------------------------------------------

function Notifications:_CreateGui()
    if self._gui then
        return
    end

    local playerGui = Services.LocalPlayer
        and Services.LocalPlayer:FindFirstChildOfClass(
            "PlayerGui"
        )

    if not playerGui then
        return
    end

    local guiParent = playerGui

    if Environment:Has("GetHui") then
        local gethui = Environment:Get("gethui")

        if gethui then
            local success, result = pcall(gethui)

            if success and result then
                guiParent = result
            end
        end
    end

    self._gui = create(
        "ScreenGui",
        {
            Name = "JustXDoorsNotifications",
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        },
        guiParent
    )

    self._container = create(
        "Frame",
        {
            Name = "Container",

            BackgroundTransparency = 1,

            Size = UDim2.new(
                0,
                getSetting(
                    "Notifications.JustXDoors.Width",
                    330
                ),
                1,
                -28
            ),

            Position = UDim2.new(
                1,
                -14,
                0,
                14
            ),

            AnchorPoint = Vector2.new(1, 0)
        },
        self._gui
    )

    create(
        "UIListLayout",
        {
            Name = "UIListLayout",

            FillDirection =
                Enum.FillDirection.Vertical,

            HorizontalAlignment =
                Enum.HorizontalAlignment.Right,

            VerticalAlignment =
                Enum.VerticalAlignment.Top,

            Padding = UDim.new(
                0,
                getSetting(
                    "Notifications.JustXDoors.Gap",
                    8
                )
            ),

            SortOrder =
                Enum.SortOrder.LayoutOrder
        },
        self._container
    )

    self:_UpdateContainerSide()
end

function Notifications:_DestroyGui()
    for _, notification in ipairs(
        self._notifications
    ) do
        if notification
            and notification.Gui
        then
            notification.Gui:Destroy()
        end
    end

    table.clear(self._notifications)

    if self._gui then
        self._gui:Destroy()
    end

    self._gui = nil
    self._container = nil
end

----------------------------------------------------------------
-- SOUND
----------------------------------------------------------------

function Notifications:_PlaySound()
    if not getSetting(
        "Notifications.SoundEnabled",
        false
    ) then
        return
    end

    local soundId =
        getSetting(
            "Notifications.SoundId",
            nil
        )

    if not soundId then
        return
    end

    local volume =
        clamp(
            tonumber(
                getSetting(
                    "Notifications.SoundVolume",
                    0.5
                )
            ) or 0.5,
            0,
            1
        )

    local sound = create(
        "Sound",
        {
            SoundId = tostring(soundId),
            Volume = volume,

            RollOffMaxDistance = 100,

            Parent = Services.SoundService
        }
    )

    sound:Play()

    Services.Debris:AddItem(
        sound,
        10
    )
end

----------------------------------------------------------------
-- CUSTOM NOTIFICATION
----------------------------------------------------------------

function Notifications:_CreateCustom(options)
    self:_CreateGui()

    if not self._container then
        return nil
    end

    local maxVisible = clamp(
        tonumber(
            getSetting(
                "Notifications.MaxVisible",
                5
            )
        ) or 5,
        1,
        20
    )

    while #self._notifications >= maxVisible do
        local oldest =
            table.remove(
                self._notifications,
                1
            )

        if oldest
            and oldest.Destroy
        then
            oldest:Destroy()
        end
    end

    local width =
        getSetting(
            "Notifications.JustXDoors.Width",
            330
        )

    local height =
        getSetting(
            "Notifications.JustXDoors.Height",
            72
        )

    local radius =
        getSetting(
            "Notifications.JustXDoors.CornerRadius",
            10
        )

    local animationTime =
        getSetting(
            "Notifications.JustXDoors.AnimationTime",
            0.22
        )

    local progressEnabled =
        getSetting(
            "Notifications.JustXDoors.ProgressBar",
            true
        )

    local clickToDismiss =
        getSetting(
            "Notifications.JustXDoors.ClickToDismiss",
            true
        )

    local duration =
        tonumber(options.Time)
        or tonumber(
            getSetting(
                "Notifications.DefaultDuration",
                4
            )
        )
        or 4

    local card = create(
        "Frame",
        {
            Name = "Notification",

            Size = UDim2.new(
                0,
                width,
                0,
                height
            ),

            BackgroundColor3 =
                Color3.fromRGB(
                    19,
                    19,
                    24
                ),

            BackgroundTransparency = 0,

            BorderSizePixel = 0,

            ClipsDescendants = true,

            LayoutOrder = #self._notifications + 1,

            Position =
                UDim2.new(
                    1,
                    30,
                    0,
                    0
                )
        },
        self._container
    )

    create(
        "UICorner",
        {
            CornerRadius =
                UDim.new(
                    0,
                    radius
                )
        },
        card
    )

    create(
        "UIStroke",
        {
            Color =
                Color3.fromRGB(
                    255,
                    255,
                    255
                ),

            Transparency = 0.92,

            Thickness = 1
        },
        card
    )

    local accentColor =
        options.Color
        or Color3.fromRGB(
            125,
            90,
            255
        )

    create(
        "Frame",
        {
            Name = "Accent",

            Size = UDim2.new(
                0,
                3,
                1,
                0
            ),

            BackgroundColor3 =
                accentColor,

            BorderSizePixel = 0
        },
        card
    )

    local icon = create(
        "TextLabel",
        {
            Name = "Icon",

            BackgroundTransparency = 1,

            Position = UDim2.new(
                0,
                15,
                0,
                12
            ),

            Size = UDim2.new(
                0,
                34,
                0,
                34
            ),

            Font =
                Enum.Font.GothamBold,

            Text =
                options.Icon
                or "●",

            TextColor3 =
                accentColor,

            TextSize = 18,

            TextXAlignment =
                Enum.TextXAlignment.Center,

            TextYAlignment =
                Enum.TextYAlignment.Center
        },
        card
    )

    local title = create(
        "TextLabel",
        {
            Name = "Title",

            BackgroundTransparency = 1,

            Position = UDim2.new(
                0,
                58,
                0,
                11
            ),

            Size = UDim2.new(
                1,
                -72,
                0,
                22
            ),

            Font =
                Enum.Font.GothamBold,

            Text =
                tostring(
                    options.Title
                    or "JustXDoors"
                ),

            TextColor3 =
                options.TitleColor
                or Color3.fromRGB(
                    255,
                    255,
                    255
                ),

            TextSize = 14,

            TextXAlignment =
                Enum.TextXAlignment.Left
        },
        card
    )

    local description = create(
        "TextLabel",
        {
            Name = "Description",

            BackgroundTransparency = 1,

            Position = UDim2.new(
                0,
                58,
                0,
                32
            ),

            Size = UDim2.new(
                1,
                -72,
                0,
                28
            ),

            Font =
                Enum.Font.Gotham,

            Text =
                tostring(
                    options.Description
                    or ""
                ),

            TextColor3 =
                options.DescriptionColor
                or Color3.fromRGB(
                    185,
                    185,
                    195
                ),

            TextSize = 12,

            TextWrapped = true,

            TextXAlignment =
                Enum.TextXAlignment.Left,

            TextYAlignment =
                Enum.TextYAlignment.Top
        },
        card
    )

    local progress

    if progressEnabled then
        progress = create(
            "Frame",
            {
                Name = "Progress",

                AnchorPoint =
                    Vector2.new(
                        0,
                        1
                    ),

                Position =
                    UDim2.new(
                        0,
                        0,
                        1,
                        0
                    ),

                Size =
                    UDim2.new(
                        1,
                        0,
                        0,
                        2
                    ),

                BackgroundColor3 =
                    accentColor,

                BorderSizePixel = 0
            },
            card
        )
    end

    local clickButton

    if clickToDismiss then
        clickButton = create(
            "TextButton",
            {
                Name = "Dismiss",

                BackgroundTransparency = 1,

                Size = UDim2.new(
                    1,
                    0,
                    1,
                    0
                ),

                Text = "",

                AutoButtonColor = false,

                ZIndex = 10
            },
            card
        )
    end

    local object = {}

    object.Gui = card
    object.Destroyed = false

    function object:Destroy()
        if self.Destroyed then
            return
        end

        self.Destroyed = true

        local index

        for i, notification in ipairs(
            Notifications._notifications
        ) do
            if notification == self then
                index = i
                break
            end
        end

        if index then
            table.remove(
                Notifications._notifications,
                index
            )
        end

        if card
            and card.Parent
        then
            local animation = tween(
                card,
                TweenInfo.new(
                    animationTime,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.In
                ),
                {
                    Position =
                        UDim2.new(
                            1,
                            30,
                            0,
                            0
                        ),

                    BackgroundTransparency = 1
                }
            )

            animation.Completed:Wait()

            if card then
                card:Destroy()
            end
        end
    end

    table.insert(
        self._notifications,
        object
    )

    if clickButton then
        clickButton.MouseButton1Click:Connect(
            function()
                object:Destroy()
            end
        )
    end

    card.BackgroundTransparency = 1
    card.Position =
        UDim2.new(
            1,
            30,
            0,
            0
        )

    tween(
        card,
        TweenInfo.new(
            animationTime,
            Enum.EasingStyle.Quart,
            Enum.EasingDirection.Out
        ),
        {
            Position =
                UDim2.new(
                    0,
                    0,
                    0,
                    0
                ),

            BackgroundTransparency = 0
        }
    )

    self:_PlaySound()

    if progress then
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
        duration,
        function()
            if object
                and not object.Destroyed
            then
                object:Destroy()
            end
        end
    )

    return object
end

----------------------------------------------------------------
-- OBSIDIAN
----------------------------------------------------------------

function Notifications:_NotifyObsidian(options)
    if not self.Library then
        return false
    end

    local success =
        pcall(
            function()
                self.Library:Notify({
                    Title =
                        options.Title
                        or "JustXDoors",

                    Description =
                        options.Description
                        or "",

                    Time =
                        options.Time
                        or getSetting(
                            "Notifications.DefaultDuration",
                            4
                        ),

                    SoundId =
                        getSetting(
                            "Notifications.SoundId",
                            nil
                        ),

                    Volume =
                        getSetting(
                            "Notifications.SoundVolume",
                            0.5
                        )
                })
            end
        )

    return success
end

----------------------------------------------------------------
-- MAIN NOTIFY
----------------------------------------------------------------

function Notifications:Notify(options)
    options = options or {}

    local provider =
        Settings:Get(
            "Notifications.Provider"
        )
        or self.Provider
        or "JustXDoors"

    if provider == "Obsidian" then
        local success =
            self:_NotifyObsidian(options)

        if success then
            return true
        end

        Settings:Set(
            "Notifications.Provider",
            "JustXDoors"
        )

        self.Provider = "JustXDoors"
    end

    return self:_CreateCustom(options)
end

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------

function Notifications:Success(
    title,
    description,
    time
)
    return self:Notify({
        Title = title or "Success",
        Description = description or "",
        Time = time,
        Color =
            Color3.fromRGB(
                80,
                210,
                120
            ),
        Icon = "✓"
    })
end

function Notifications:Warning(
    title,
    description,
    time
)
    return self:Notify({
        Title = title or "Warning",
        Description = description or "",
        Time = time,
        Color =
            Color3.fromRGB(
                245,
                180,
                70
            ),
        Icon = "!"
    })
end

function Notifications:Error(
    title,
    description,
    time
)
    return self:Notify({
        Title = title or "Error",
        Description = description or "",
        Time = time,
        Color =
            Color3.fromRGB(
                235,
                80,
                90
            ),
        Icon = "×"
    })
end

function Notifications:Info(
    title,
    description,
    time
)
    return self:Notify({
        Title = title or "Info",
        Description = description or "",
        Time = time,
        Color =
            Color3.fromRGB(
                90,
                150,
                255
            ),
        Icon = "i"
    })
end

----------------------------------------------------------------
-- REMOVE / CLEAR
----------------------------------------------------------------

function Notifications:Remove(notification)
    if not notification then
        return
    end

    if type(notification) == "table"
        and notification.Destroy
    then
        notification:Destroy()
    end
end

function Notifications:Clear()
    for index = #self._notifications, 1, -1 do
        local notification =
            self._notifications[index]

        if notification
            and notification.Destroy
        then
            task.spawn(function()
                notification:Destroy()
            end)
        end
    end
end

function Notifications:Destroy()
    self._destroyed = true

    self:Clear()
    self:_DestroyGui()

    self.Library = nil
end

return Notifications
