local players = game:GetService("Players")
local runservice = game:GetService("RunService")
local localplayer = players.LocalPlayer
local playergui = localplayer:WaitForChild("PlayerGui")
local older = workspace:FindFirstChild("sixly_esp")
if older then older:Destroy() end
local old = playergui:FindFirstChild("sixly_esp")
if old then old:Destroy() end

local screen = Instance.new("ScreenGui")
screen.Name = "sixly_esp"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.DisplayOrder = 999
screen.ZIndexBehavior = Enum.ZIndexBehavior.Global
pcall(function()
    screen.ScreenInsets = Enum.ScreenInsets.None
    screen.ClipToDeviceSafeArea = false
end)
screen.Parent = playergui

local canvas = Instance.new("Frame")
canvas.Name = "Canvas"
canvas.BackgroundTransparency = 1
canvas.Size = UDim2.fromScale(1, 1)
canvas.BorderSizePixel = 0
canvas.ClipsDescendants = false
canvas.Parent = screen

local glowfolder = Instance.new("Folder")
glowfolder.Name = "Highlights"
glowfolder.Parent = workspace

local esp = {}
local cache = {}
local connections = {}
local closed = false
local rendername = "sixly_esp_projection_v3"

local enemycolor = Color3.fromRGB(255, 45, 45)
local teamcolor = Color3.fromRGB(65, 160, 255)
local tracecolor = Color3.fromRGB(60, 255, 95)
local black = Color3.fromRGB(12, 12, 12)

local r15 = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

local r6 = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"}
}

local function frame(name, parent, color, height)
    local object = Instance.new("Frame")
    object.Name = name
    object.BorderSizePixel = 0
    object.BackgroundColor3 = color
    object.BackgroundTransparency = 0
    object.AnchorPoint = Vector2.new(0.5, 0.5)
    object.Size = UDim2.fromOffset(0, height or 2)
    object.Visible = false
    object.ZIndex = 4
    object.Parent = parent
    return object
end

local function drawline(object, a, b, thickness)
    local delta = b - a
    local distance = delta.Magnitude
    if distance < 1 then
        object.Visible = false
        return
    end

    object.Position = UDim2.fromOffset((a.X + b.X) * 0.5, (a.Y + b.Y) * 0.5)
    object.Size = UDim2.fromOffset(distance, thickness or 1.5)
    object.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    object.Visible = true
end

local function create(player)
    if closed or player == localplayer or cache[player] then return end

    local container = Instance.new("Frame")
    container.Name = tostring(player.UserId)
    container.BackgroundTransparency = 1
    container.Size = UDim2.fromScale(1, 1)
    container.Parent = canvas

    local tracer = frame("Trace", container, tracecolor, 1.5)

    -- Endpoint dot makes it easy to verify the tracer lands on the torso.
    local dot = frame("Target", container, tracecolor, 3)
    dot.Size = UDim2.fromOffset(3, 3)

    local name = Instance.new("TextLabel")
    name.Name = "Name"
    name.AnchorPoint = Vector2.new(0.5, 1)
    name.BackgroundTransparency = 1
    name.Size = UDim2.fromOffset(200, 20)
    name.TextScaled = false
    name.TextSize = 14
    name.Font = Enum.Font.GothamBold
    name.TextStrokeColor3 = black
    name.TextStrokeTransparency = 0
    name.TextColor3 = enemycolor
    name.Text = player.Name
    name.Visible = false
    name.ZIndex = 6
    name.Parent = container

    local healthbg = Instance.new("Frame")
    healthbg.Name = "HealthBackground"
    healthbg.AnchorPoint = Vector2.new(0.5, 0)
    healthbg.BorderSizePixel = 0
    healthbg.Size = UDim2.fromOffset(76, 5)
    healthbg.BackgroundColor3 = black
    healthbg.Visible = false
    healthbg.ZIndex = 6
    healthbg.Parent = container

    local healthfill = Instance.new("Frame")
    healthfill.Name = "HealthFill"
    healthfill.BorderSizePixel = 0
    healthfill.BackgroundColor3 = enemycolor
    healthfill.Size = UDim2.fromScale(1, 1)
    healthfill.ZIndex = 7
    healthfill.Parent = healthbg

    local highlight = Instance.new("Highlight")
    highlight.Name = "Glow_" .. tostring(player.UserId)
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.OutlineColor = enemycolor
    highlight.Enabled = false
    highlight.Parent = glowfolder

    cache[player] = {
        container = container, tracer = tracer, dot = dot,
        name = name, healthbg = healthbg, healthfill = healthfill,
        highlight = highlight, skeleton = {},
        character = nil, humanoid = nil, head = nil, torso = nil,
        lasthealth = nil, lastcolor = nil
    }
end

local function hide(objects)
    objects.highlight.Enabled = false
    objects.tracer.Visible = false
    objects.dot.Visible = false
    objects.name.Visible = false
    objects.healthbg.Visible = false
    for _, line in objects.skeleton do
        line.Visible = false
    end
end

local function remove(player)
    local objects = cache[player]
    if not objects then return end
    cache[player] = nil
    objects.highlight:Destroy()
    objects.container:Destroy()
end

local function attach(objects, character)
    objects.character = character
    objects.humanoid = character and character:FindFirstChildOfClass("Humanoid")
    objects.head = character and character:FindFirstChild("Head")
    objects.torso = character and (
        character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("HumanoidRootPart")
    )
    objects.highlight.Adornee = character
    objects.lasthealth = nil
end

-- All 3D-to-2D conversions go through one camera and one viewport.
-- Convert projected pixels to actual ScreenGui pixels (handles resized windows).
local function project(camera, world, scaleX, scaleY)
    local point, visible = camera:WorldToViewportPoint(world)
    if point.Z <= 0 or not visible then return nil end
    return Vector2.new(point.X * scaleX, point.Y * scaleY)
end

local function skeleton(objects, character, humanoid, camera, sx, sy, color)
    local bones = humanoid.RigType == Enum.HumanoidRigType.R6 and r6 or r15

    for index, pair in bones do
        local a = character:FindFirstChild(pair[1])
        local b = character:FindFirstChild(pair[2])
        local line = objects.skeleton[index]

        if not line then
            line = frame("Bone" .. index, objects.container, color, 1.5)
            objects.skeleton[index] = line
        end

        if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
            local p1 = project(camera, a.Position, sx, sy)
            local p2 = project(camera, b.Position, sx, sy)

            if p1 and p2 then
                line.BackgroundColor3 = color
                drawline(line, p1, p2, 1.5)
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
    end

    for i = #bones + 1, #objects.skeleton do
        objects.skeleton[i].Visible = false
    end
end

local function update(player, objects, camera, size, sx, sy)
    local methods = esp.methods
    if not esp.enabled or not methods then
        hide(objects)
        return
    end

    local character = player.Character
    if objects.character ~= character or (character and (not objects.torso or not objects.head or not objects.humanoid)) then
        attach(objects, character)
    end

    local humanoid, head, torso = objects.humanoid, objects.head, objects.torso
    if not character or not humanoid or humanoid.Health <= 0
        or not head or not torso or not head:IsA("BasePart") or not torso:IsA("BasePart") then
        hide(objects)
        return
    end

    local teammate = player.Team ~= nil and player.Team == localplayer.Team
        and not player.Neutral and not localplayer.Neutral
    if esp.teamcheck and teammate then
        hide(objects)
        return
    end

    local color = teammate and teamcolor or enemycolor
    local torso2d = project(camera, torso.Position, sx, sy)
    if not torso2d then
        hide(objects)
        return
    end

    if objects.lastcolor ~= color then
        objects.lastcolor = color
        objects.highlight.OutlineColor = color
        objects.highlight.FillColor = color
        objects.name.TextColor3 = color
    end

    local showglow = methods.Glow == true or methods.Health == true
    objects.highlight.Enabled = showglow
    objects.highlight.OutlineTransparency = methods.Glow and 0 or 1
    objects.highlight.FillTransparency = methods.Health and 0.78 or 1

    local showtrace = methods.Trace == true or methods.Line == true
    if showtrace then
        -- Same GUI surface for both endpoints: no Drawing API inset drift.
        drawline(objects.tracer, Vector2.new(size.X * 0.5, size.Y - 1), torso2d, 1.5)
        objects.dot.Position = UDim2.fromOffset(torso2d.X, torso2d.Y)
        objects.dot.Visible = true
    else
        objects.tracer.Visible = false
        objects.dot.Visible = false
    end

    local showname = methods.Name == true
    local showhealth = methods.Health == true
    if showname or showhealth then
        local headtop = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.6, 0)
        local head2d = project(camera, headtop, sx, sy)
        if head2d then
            objects.name.Visible = showname
            objects.name.Position = UDim2.fromOffset(head2d.X, head2d.Y - (showhealth and 5 or 0))

            objects.healthbg.Visible = showhealth
            objects.healthbg.Position = UDim2.fromOffset(head2d.X, head2d.Y + (showname and 2 or 0))
            if showhealth then
                local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
                if objects.lasthealth ~= ratio then
                    objects.lasthealth = ratio
                    objects.healthfill.Size = UDim2.fromScale(ratio, 1)
                    objects.healthfill.BackgroundColor3 = Color3.fromRGB(255, 55, 55):Lerp(Color3.fromRGB(65, 240, 110), ratio)
                end
            end
        else
            objects.name.Visible = false
            objects.healthbg.Visible = false
        end
    else
        objects.name.Visible = false
        objects.healthbg.Visible = false
    end

    if methods.Skeleton then
        skeleton(objects, character, humanoid, camera, sx, sy, color)
    else
        for _, line in objects.skeleton do
            line.Visible = false
        end
    end
end

function esp:set_enabled(value)
    self.enabled = value == true
    if not self.enabled then
        for _, objects in cache do
            hide(objects)
        end
    end
end

function esp:set_methods(value)
    local selected = {}
    if type(value) == "string" then
        selected[value] = true
    elseif type(value) == "table" then
        for key, item in value do
            if type(item) == "string" then
                selected[item] = true
            elseif type(key) == "string" and item == true then
                selected[key] = true
            end
        end
    end
    self.methods = selected
end

function esp:set_teamcheck(value)
    self.teamcheck = value == true
end

local function cleanup()
    if closed then return end
    closed = true
    runservice:UnbindFromRenderStep(rendername)
    for _, connection in connections do
        connection:Disconnect()
    end
    for player in cache do
        remove(player)
    end
    glowfolder:Destroy()
end

function esp:destroy()
    cleanup()
    screen:Destroy()
end

connections[#connections + 1] = screen.Destroying:Connect(cleanup)
connections[#connections + 1] = players.PlayerAdded:Connect(create)
connections[#connections + 1] = players.PlayerRemoving:Connect(remove)

for _, player in players:GetPlayers() do
    create(player)
end

runservice:BindToRenderStep(rendername, Enum.RenderPriority.Camera.Value + 1, function()
    if closed or not esp.enabled or not esp.methods then return end
    local camera = workspace.CurrentCamera
    if not camera then return end

    local viewport = camera.ViewportSize
    local size = canvas.AbsoluteSize
    if viewport.X <= 0 or viewport.Y <= 0 or size.X <= 0 or size.Y <= 0 then return end

    local sx = size.X / viewport.X
    local sy = size.Y / viewport.Y

    for player, objects in cache do
        update(player, objects, camera, size, sx, sy)
    end
end)

return esp
