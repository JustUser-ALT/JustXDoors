local Notifications = {}

local Services = require("Core/Services")
local Connections = require("Core/Connections")

local Players = Services.Players
local TweenService = Services.TweenService

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local GUI_NAME = "JustXDoorsNotifications"

local DEFAULTS = {
    Duration = 4,
    MaxVisible = 5,
    Width = 310,
    Height = 72,
    Spacing = 8,
    TweenTime = 0.28
}

local COLORS = {
    Default = Color3.fromRGB(25, 25, 30),
    Success = Color3.fromRGB(55, 185, 105),
    Warning = Color3.fromRGB(220, 165, 65),
    Error = Color3.fromRGB(210, 75, 75),
    Info = Color3.fromRGB(75, 135, 220)
}

Notifications.Settings = table.clone(DEFAULTS)
Notifications._items = {}
Notifications._id = 0
Notifications._gui = nil
Notifications._container = nil

local function create(className, properties, parent)
    local object = Instance.new(className)

    for property, value in pairs(properties or {}) do
        object[property] = value
    end

    object.Parent = parent

    return object
end

local function getGui()
    if Notifications._gui and Notifications._gui.Parent then
        return Notifications._gui
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = GUI_NAME
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui

    local container = create("Frame", {
        Name = "Container",
        AnchorPoint = Vector2.new(1, 1),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -18, 1, -18),
        Size = UDim2.new(0, Notifications.Settings.Width, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, gui)

    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, Notifications.Settings.Spacing),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, container)

    Notifications._gui = gui
    Notifications._container = container

    return gui
end

local function getContainer()
    getGui()
    return Notifications._container
end

local function getColor(notificationType)
    return COLORS[notificationType] or COLORS.Default
end

local function updateLayout()
    local container = Notifications._container

    if not container then
        return
    end

    local visibleCount = 0

    for index = #Notifications._items, 1, -1 do
        local item = Notifications._items[index]

        if not item.Frame or not item.Frame.Parent then
            table.remove(Notifications._items, index)
        elseif not item.Hidden then
            visibleCount += 1
            item.Frame.LayoutOrder = visibleCount
        end
    end
end

local function removeItem(item, instant)
    if not item or item.Removed then
        return
    end

    item.Removed = true

    if item.TimerConnection then
        Connections:Disconnect(item.TimerConnection)
        item.TimerConnection = nil
    end

    if item.Frame and item.Frame.Parent then
        if instant then
            item.Frame:Destroy()
        else
            local tween = TweenService:Create(
                item.Frame,
                TweenInfo.new(
                    Notifications.Settings.TweenTime,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.In
                ),
                {
                    Position = UDim2.new(
                        1,
                        Notifications.Settings.Width + 30,
                        0,
                        0
                    ),
                    BackgroundTransparency = 1
                }
            )

            tween:Play()

            task.delay(Notifications.Settings.TweenTime, function()
                if item.Frame then
                    item.Frame:Destroy()
                end
            end)
        end
    end

    for index, existing in ipairs(Notifications._items) do
        if existing == item then
            table.remove(Notifications._items, index)
            break
        end
    end

    updateLayout()
end

local function enforceLimit()
    while #Notifications._items > Notifications.Settings.MaxVisible do
        local oldest = Notifications._items[1]

        if oldest then
            removeItem(oldest, false)
        else
            break
        end
    end
end

function Notifications:Notify(options, text, duration)
    if type(options) == "string" then
        options = {
            Title = options,
            Text = text,
            Duration = duration
        }
    end

    options = options or {}

    local title = tostring(options.Title or "JustXDoors")
    local message = tostring(options.Text or "")
    local notificationType = options.Type or "Default"
    local displayDuration = tonumber(options.Duration) or self.Settings.Duration
    local icon = options.Icon
    local callback = options.Callback

    local container = getContainer()

    self._id += 1

    local item = {
        Id = self._id,
        Removed = false,
        Hidden = false
    }

    local frame = create("Frame", {
        Name = "Notification_" .. item.Id,
        BackgroundColor3 = getColor(notificationType),
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Position = UDim2.new(
            1,
            self.Settings.Width + 30,
            0,
            0
        ),
        Size = UDim2.new(
            0,
            self.Settings.Width,
            0,
            self.Settings.Height
        ),
        ClipsDescendants = true
    }, container)

    item.Frame = frame

    create("UICorner", {
        CornerRadius = UDim.new(0, 10)
    }, frame)

    local stroke = create("UIStroke", {
        Thickness = 1,
        Transparency = 0.65,
        Color = Color3.fromRGB(255, 255, 255)
    }, frame)

    local content = create("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(1, -24, 1, -16)
    }, frame)

    local titleLabel = create("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 20),
        Font = Enum.Font.GothamBold,
        Text = title,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center
    }, content)

    local messageLabel = create("TextLabel", {
        Name = "Text",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 21),
        Size = UDim2.new(1, 0, 1, -21),
        Font = Enum.Font.Gotham,
        Text = message,
        TextColor3 = Color3.fromRGB(235, 235, 240),
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top
    }, content)

    if icon then
        local image = create("ImageLabel", {
            Name = "Icon",
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -28, 0, 0),
            Size = UDim2.new(0, 20, 0, 20),
            Image = tostring(icon),
            ImageColor3 = Color3.fromRGB(255, 255, 255)
        }, content)

        titleLabel.Size = UDim2.new(1, -32, 0, 20)
        messageLabel.Size = UDim2.new(1, -32, 1, -21)
    end

    local progress = create("Frame", {
        Name = "Progress",
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 2)
    }, frame)

    create("UICorner", {
        CornerRadius = UDim.new(1, 0)
    }, progress)

    table.insert(self._items, item)

    updateLayout()
    enforceLimit()

    local enterTween = TweenService:Create(
        frame,
        TweenInfo.new(
            self.Settings.TweenTime,
            Enum.EasingStyle.Quart,
            Enum.EasingDirection.Out
        ),
        {
            Position = UDim2.new(1, 0, 0, 0)
        }
    )

    enterTween:Play()

    local progressTween = TweenService:Create(
        progress,
        TweenInfo.new(
            displayDuration,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.In
        ),
        {
            Size = UDim2.new(0, 0, 0, 2)
        }
    )

    progressTween:Play()

    if displayDuration > 0 then
        task.delay(displayDuration, function()
            removeItem(item, false)
        end)
    end

    if callback then
        task.spawn(function()
            pcall(callback, item)
        end)
    end

    return item
end

function Notifications:Success(title, text, duration)
    return self:Notify({
        Title = title,
        Text = text,
        Duration = duration,
        Type = "Success"
    })
end

function Notifications:Warning(title, text, duration)
    return self:Notify({
        Title = title,
        Text = text,
        Duration = duration,
        Type = "Warning"
    })
end

function Notifications:Error(title, text, duration)
    return self:Notify({
        Title = title,
        Text = text,
        Duration = duration,
        Type = "Error"
    })
end

function Notifications:Info(title, text, duration)
    return self:Notify({
        Title = title,
        Text = text,
        Duration = duration,
        Type = "Info"
    })
end

function Notifications:Remove(item, instant)
    removeItem(item, instant)
end

function Notifications:Clear(instant)
    for index = #self._items, 1, -1 do
        removeItem(self._items[index], instant)
    end
end

function Notifications:SetMaxVisible(value)
    value = math.max(1, math.floor(tonumber(value) or DEFAULTS.MaxVisible))

    self.Settings.MaxVisible = value

    enforceLimit()
end

function Notifications:SetDuration(value)
    value = tonumber(value)

    if value and value >= 0 then
        self.Settings.Duration = value
    end
end

function Notifications:SetPosition(position)
    local container = self._container

    if not container then
        return
    end

    if typeof(position) == "UDim2" then
        container.Position = position
    end
end

function Notifications:Destroy()
    self:Clear(true)

    if self._gui then
        self._gui:Destroy()
    end

    self._gui = nil
    self._container = nil
    self._items = {}
end

return Notifications
