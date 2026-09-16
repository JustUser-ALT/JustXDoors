local Notifications = {}

local Services = require("Core/Services")

local TweenService = Services.TweenService
local Players = Services.Players

Notifications.Config = {
    DefaultDuration = 4,

    MaxVisible = 5,

    Side = "Right",

    UseObsidian = true,

    SoundEnabled = false,
    SoundId = nil,
    SoundVolume = 0.5,

    Colors = {
        Success = Color3.fromRGB(75, 210, 125),
        Warning = Color3.fromRGB(245, 190, 75),
        Error = Color3.fromRGB(235, 85, 95),
        Info = Color3.fromRGB(90, 155, 255),
        Default = Color3.fromRGB(150, 150, 165)
    }
}

Notifications._Library = nil
Notifications._Gui = nil
Notifications._Holder = nil

Notifications._Active = {}
Notifications._Ids = 0

--------------------------------------------------
-- INTERNAL
--------------------------------------------------

local function nextId()
    Notifications._Ids += 1
    return Notifications._Ids
end

local function getColor(notificationType)
    return Notifications.Config.Colors[
        notificationType
    ] or Notifications.Config.Colors.Default
end

local function normalize(options)
    if type(options) ~= "table" then
        return {
            Title = "JustXDoors",
            Text = tostring(options or ""),
            Type = "Info",
            Duration = Notifications.Config.DefaultDuration
        }
    end

    return {
        Title = tostring(
            options.Title
            or "JustXDoors"
        ),

        Text = tostring(
            options.Text
            or options.Description
            or ""
        ),

        Type = tostring(
            options.Type
            or "Info"
        ),

        Duration = tonumber(
            options.Duration
            or options.Time
            or Notifications.Config.DefaultDuration
        ) or Notifications.Config.DefaultDuration,

        Icon = options.Icon,

        Persist = options.Persist == true,

        SoundId = options.SoundId,

        SoundVolume = tonumber(
            options.SoundVolume
        ) or Notifications.Config.SoundVolume,

        Key = options.Key,

        OnClick = options.OnClick,

        OnDestroy = options.OnDestroy
    }
end

--------------------------------------------------
-- OBSIDIAN
--------------------------------------------------

function Notifications:SetLibrary(library)
    self._Library = library

    if library then
        pcall(function()
            library:SetNotifySide(
                self.Config.Side
            )
        end)
    end
end

function Notifications:SetSide(side)
    side = tostring(side)

    if side ~= "Left"
        and side ~= "Right"
    then
        return false
    end

    self.Config.Side = side

    if self._Library then
        pcall(function()
            self._Library:SetNotifySide(side)
        end)
    end

    return true
end

function Notifications:_NotifyObsidian(options)
    if not self._Library then
        return nil
    end

    if self.Config.UseObsidian ~= true then
        return nil
    end

    local color = getColor(
        options.Type
    )

    local success, result = pcall(function()

        return self._Library:Notify({
            Title = options.Title,

            Description = options.Text,

            Time =
                options.Persist
                and math.huge
                or options.Duration,

            Icon = options.Icon,

            IconColor = color,

            Persist = options.Persist,

            SoundId =
                options.SoundId
                or (
                    self.Config.SoundEnabled
                    and self.Config.SoundId
                ),

            Volume =
                options.SoundVolume
        })

    end)

    if success then
        return result
    end

    return nil
end

--------------------------------------------------
-- CUSTOM FALLBACK UI
--------------------------------------------------

function Notifications:_CreateGui()

    if self._Gui
        and self._Gui.Parent
    then
        return
    end

    local player =
        Players.LocalPlayer

    if not player then
        return
    end

    local playerGui =
        player:FindFirstChildOfClass(
            "PlayerGui"
        )

    if not playerGui then
        return
    end

    local gui =
        Instance.new("ScreenGui")

    gui.Name =
        "JustXDoorsNotifications"

    gui.ResetOnSpawn = false

    gui.IgnoreGuiInset = true

    gui.DisplayOrder = 999999

    gui.ZIndexBehavior =
        Enum.ZIndexBehavior.Sibling

    gui.Parent = playerGui

    local holder =
        Instance.new("Frame")

    holder.Name = "Holder"

    holder.BackgroundTransparency = 1

    holder.AnchorPoint =
        Vector2.new(1, 0)

    holder.Position =
        UDim2.new(
            1,
            -14,
            0,
            14
        )

    holder.Size =
        UDim2.new(
            0,
            330,
            1,
            -28
        )

    holder.Parent = gui

    local layout =
        Instance.new("UIListLayout")

    layout.FillDirection =
        Enum.FillDirection.Vertical

    layout.HorizontalAlignment =
        Enum.HorizontalAlignment.Right

    layout.VerticalAlignment =
        Enum.VerticalAlignment.Top

    layout.Padding =
        UDim.new(0, 8)

    layout.SortOrder =
        Enum.SortOrder.LayoutOrder

    layout.Parent = holder

    self._Gui = gui
    self._Holder = holder
end

function Notifications:_CreateCustom(options)

    self:_CreateGui()

    if not self._Holder then
        return nil
    end

    --------------------------------------------------
    -- Limit visible notifications
    --------------------------------------------------

    while #self._Active >=
        self.Config.MaxVisible
    do

        local oldest =
            self._Active[1]

        if oldest then
            self:Remove(oldest.Id)
        else
            break
        end
    end

    --------------------------------------------------
    -- Root
    --------------------------------------------------

    local id = nextId()

    local color =
        getColor(options.Type)

    local root =
        Instance.new("TextButton")

    root.Name =
        "Notification_" .. id

    root.AutoButtonColor = false

    root.BackgroundColor3 =
        Color3.fromRGB(
            19,
            20,
            25
        )

    root.BackgroundTransparency = 0.04

    root.BorderSizePixel = 0

    root.Size =
        UDim2.new(
            1,
            0,
            0,
            72
        )

    root.Text = ""

    root.LayoutOrder = id

    root.Parent =
        self._Holder

    --------------------------------------------------
    -- Corner
    --------------------------------------------------

    local corner =
        Instance.new("UICorner")

    corner.CornerRadius =
        UDim.new(0, 10)

    corner.Parent = root

    --------------------------------------------------
    -- Stroke
    --------------------------------------------------

    local stroke =
        Instance.new("UIStroke")

    stroke.Color =
        Color3.fromRGB(
            55,
            57,
            68
        )

    stroke.Transparency = 0.25

    stroke.Thickness = 1

    stroke.Parent = root

    --------------------------------------------------
    -- Accent
    --------------------------------------------------

    local accent =
        Instance.new("Frame")

    accent.Name = "Accent"

    accent.BackgroundColor3 =
        color

    accent.BorderSizePixel = 0

    accent.Size =
        UDim2.new(
            0,
            3,
            1,
            -16
        )

    accent.Position =
        UDim2.new(
            0,
            8,
            0,
            8
        )

    accent.Parent = root

    local accentCorner =
        Instance.new("UICorner")

    accentCorner.CornerRadius =
        UDim.new(1, 0)

    accentCorner.Parent =
        accent

    --------------------------------------------------
    -- Icon
    --------------------------------------------------

    local icon =
        Instance.new("TextLabel")

    icon.Name = "Icon"

    icon.BackgroundTransparency = 1

    icon.Position =
        UDim2.new(
            0,
            22,
            0,
            15
        )

    icon.Size =
        UDim2.fromOffset(
            32,
            32
        )

    icon.Font =
        Enum.Font.GothamBold

    icon.TextSize = 17

    icon.TextColor3 = color

    icon.Text =

        options.Type == "Success"
        and "✓"

        or options.Type == "Warning"
        and "!"

        or options.Type == "Error"
        and "×"

        or "i"

    icon.Parent = root

    --------------------------------------------------
    -- Title
    --------------------------------------------------

    local title =
        Instance.new("TextLabel")

    title.Name = "Title"

    title.BackgroundTransparency = 1

    title.Position =
        UDim2.new(
            0,
            62,
            0,
            12
        )

    title.Size =
        UDim2.new(
            1,
            -76,
            0,
            20
        )

    title.Font =
        Enum.Font.GothamSemibold

    title.TextSize = 14

    title.TextXAlignment =
        Enum.TextXAlignment.Left

    title.TextColor3 =
        Color3.fromRGB(
            245,
            245,
            248
        )

    title.Text =
        options.Title

    title.Parent = root

    --------------------------------------------------
    -- Description
    --------------------------------------------------

    local description =
        Instance.new("TextLabel")

    description.Name =
        "Description"

    description.BackgroundTransparency = 1

    description.Position =
        UDim2.new(
            0,
            62,
            0,
            34
        )

    description.Size =
        UDim2.new(
            1,
            -76,
            0,
            26
        )

    description.Font =
        Enum.Font.Gotham

    description.TextSize = 12

    description.TextWrapped = true

    description.TextXAlignment =
        Enum.TextXAlignment.Left

    description.TextYAlignment =
        Enum.TextYAlignment.Top

    description.TextColor3 =
        Color3.fromRGB(
            165,
            168,
            180
        )

    description.Text =
        options.Text

    description.Parent = root

    --------------------------------------------------
    -- Progress bar
    --------------------------------------------------

    local progressBackground =
        Instance.new("Frame")

    progressBackground.Name =
        "ProgressBackground"

    progressBackground.BackgroundColor3 =
        Color3.fromRGB(
            45,
            46,
            55
        )

    progressBackground.BorderSizePixel = 0

    progressBackground.Position =
        UDim2.new(
            0,
            62,
            1,
            -7
        )

    progressBackground.Size =
        UDim2.new(
            1,
            -76,
            0,
            2
        )

    progressBackground.Parent = root

    local progress =
        Instance.new("Frame")

    progress.Name =
        "Progress"

    progress.BackgroundColor3 =
        color

    progress.BorderSizePixel = 0

    progress.Size =
        UDim2.fromScale(
            1,
            1
        )

    progress.Parent =
        progressBackground

    --------------------------------------------------
    -- Object
    --------------------------------------------------

    local notification = {
        Id = id,

        Instance = root,

        Title = title,

        Description = description,

        Progress = progress,

        Destroyed = false
    }

    table.insert(
        self._Active,
        notification
    )

    --------------------------------------------------
    -- Click
    --------------------------------------------------

    root.Activated:Connect(function()

        if type(options.OnClick)
            == "function"
        then
            task.spawn(
                options.OnClick,
                notification
            )
        end

        self:Remove(id)
    end)

    --------------------------------------------------
    -- Entrance
    --------------------------------------------------

    root.Size =
        UDim2.new(
            1,
            0,
            0,
            0
        )

    root.BackgroundTransparency = 1

    TweenService:Create(
        root,
        TweenInfo.new(
            0.22,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out
        ),
        {
            Size = UDim2.new(
                1,
                0,
                0,
                72
            ),

            BackgroundTransparency = 0.04
        }
    ):Play()

    --------------------------------------------------
    -- Timer
    --------------------------------------------------

    if not options.Persist
        and options.Duration > 0
    then

        TweenService:Create(
            progress,
            TweenInfo.new(
                options.Duration,
                Enum.EasingStyle.Linear
            ),
            {
                Size =
                    UDim2.new(
                        0,
                        0,
                        1,
                        0
                    )
            }
        ):Play()

        task.delay(
            options.Duration,
            function()

                if not notification.Destroyed then
                    self:Remove(id)
                end

            end
        )
    end

    return notification
end

--------------------------------------------------
-- PUBLIC
--------------------------------------------------

function Notifications:Notify(options)

    options = normalize(options)

    local result =
        self:_NotifyObsidian(options)

    if result then
        return result
    end

    return self:_CreateCustom(options)
end

function Notifications:Success(title, text, duration)

    return self:Notify({
        Title = title,
        Text = text,
        Type = "Success",
        Duration =
            duration
            or self.Config.DefaultDuration
    })
end

function Notifications:Warning(title, text, duration)

    return self:Notify({
        Title = title,
        Text = text,
        Type = "Warning",
        Duration =
            duration
            or self.Config.DefaultDuration
    })
end

function Notifications:Error(title, text, duration)

    return self:Notify({
        Title = title,
        Text = text,
        Type = "Error",
        Duration =
            duration
            or self.Config.DefaultDuration
    })
end

function Notifications:Info(title, text, duration)

    return self:Notify({
        Title = title,
        Text = text,
        Type = "Info",
        Duration =
            duration
            or self.Config.DefaultDuration
    })
end

--------------------------------------------------
-- REMOVE
--------------------------------------------------

function Notifications:Remove(id)

    for index, notification
        in ipairs(self._Active)
    do

        if notification.Id == id then

            notification.Destroyed = true

            local instance =
                notification.Instance

            if instance
                and instance.Parent
            then

                local tween =
                    TweenService:Create(
                        instance,

                        TweenInfo.new(
                            0.18,
                            Enum.EasingStyle.Quint,
                            Enum.EasingDirection.In
                        ),

                        {
                            Size =
                                UDim2.new(
                                    1,
                                    0,
                                    0,
                                    0
                                ),

                            BackgroundTransparency = 1
                        }
                    )

                tween:Play()

                task.delay(
                    0.2,
                    function()
                        if instance then
                            instance:Destroy()
                        end
                    end
                )
            end

            table.remove(
                self._Active,
                index
            )

            return true
        end
    end

    return false
end

function Notifications:Clear()

    for index =
        #self._Active,
        1,
        -1
    do

        local notification =
            self._Active[index]

        notification.Destroyed = true

        if notification.Instance then
            notification.Instance:Destroy()
        end

        self._Active[index] = nil
    end
end

--------------------------------------------------
-- DESTROY
--------------------------------------------------

function Notifications:Destroy()

    self:Clear()

    if self._Gui then
        self._Gui:Destroy()
    end

    self._Gui = nil
    self._Holder = nil
    self._Library = nil
end

return Notifications
