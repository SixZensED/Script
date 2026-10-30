local players = cloneref(game:GetService("Players"))
local runservice = cloneref(game:GetService("RunService"))
local localplayer = players.LocalPlayer
local playergui = localplayer:FindFirstChildOfClass("PlayerGui")
local previous_gui = playergui and playergui:FindFirstChild("sixly_esp")
if previous_gui then
    previous_gui:Destroy()
end

local previous = workspace:FindFirstChild("sixly_esp")
if previous then
    previous:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = "sixly_esp"
folder.Parent = workspace

local esp = {}
local cache = {}
local errors = {}
local connections = {}
local signs = {-1, 1}
local triangle_supported = true
local triangle_warned = false
local closed = false

local bones_r15 = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

local bones_r6 = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"},
}

local new_line = function()
    local line = Drawing.new("Line")
    line.Visible = false
    line.Thickness = 1.5
    line.Transparency = 1
    return line
end

local new_text = function()
    local label = Drawing.new("Text")
    label.Visible = false
    label.Center = true
    label.Outline = true
    label.Size = 14
    label.Font = 2
    label.Transparency = 1
    return label
end

local hide = function(objects)
    objects.glow.Enabled = false
    objects.trace.Visible = false
    objects.name.Visible = false

    for _, triangle in objects.fill do
        triangle.Visible = false
    end

    for _, segment in objects.skeleton do
        segment.Visible = false
    end
end

local create = function(player)
    if closed or player == localplayer or cache[player] then return end

    local glow = Instance.new("Highlight")
    glow.Name = "Glow_" .. player.UserId
    glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    glow.FillTransparency = 1
    glow.OutlineTransparency = 0
    glow.Enabled = false
    glow.Parent = folder

    local objects = {
        glow = glow,
        trace = new_line(),
        name = new_text(),
        fill = {},
        skeleton = {},
    }

    cache[player] = objects
end

local remove = function(player)
    local objects = cache[player]
    if not objects then return end
    hide(objects)
    objects.glow:Destroy()
    objects.trace:Remove()
    objects.name:Remove()

    for _, triangle in objects.fill do
        triangle:Remove()
    end

    for _, segment in objects.skeleton do
        segment:Remove()
    end

    cache[player] = nil
    errors[player] = nil
end

local cross = function(a, b, c)
    return (b.X - a.X) * (c.Y - a.Y) - (b.Y - a.Y) * (c.X - a.X)
end

local hull = function(points)
    table.sort(points, function(a, b)
        return a.X == b.X and a.Y < b.Y or a.X < b.X
    end)

    local lower = {}
    for _, point in points do
        while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], point) <= 0 do
            table.remove(lower)
        end
        lower[#lower + 1] = point
    end

    local upper = {}
    for i = #points, 1, -1 do
        local point = points[i]
        while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], point) <= 0 do
            table.remove(upper)
        end
        upper[#upper + 1] = point
    end

    table.remove(lower)
    table.remove(upper)
    for _, point in upper do
        lower[#lower + 1] = point
    end
    return lower
end

local clip_bottom = function(polygon, cutoff)
    local result = {}
    for i = 1, #polygon do
        local a = polygon[i]
        local b = polygon[i % #polygon + 1]
        local inside_a = a.Y >= cutoff
        local inside_b = b.Y >= cutoff

        if inside_a then
            result[#result + 1] = a
        end
        if inside_a ~= inside_b then
            local t = (cutoff - a.Y) / (b.Y - a.Y)
            result[#result + 1] = a + (b - a) * t
        end
    end
    return result
end

local project_part = function(part, camera)
    local cf = part.CFrame
    local half = part.Size * 0.5
    local points = {}

    for _, x in signs do
        for _, y in signs do
            for _, z in signs do
                local world = cf:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
                local screen = camera:WorldToViewportPoint(world)
                if screen.Z <= 0 then return end
                points[#points + 1] = Vector2.new(screen.X, screen.Y)
            end
        end
    end
    return hull(points)
end

local fill_triangle = function(objects, index, a, b, c, color)
    local triangle = objects.fill[index]
    if not triangle then
        if not triangle_supported then return false end
        local ok, object = pcall(Drawing.new, "Triangle")
        if not ok or not object then
            triangle_supported = false
            if not triangle_warned then
                triangle_warned = true
                warn("[sixly_esp] Drawing.Triangle is unsupported: silhouette health fill unavailable")
            end
            return false
        end
        triangle = object
        triangle.Filled = true
        triangle.Transparency = 0.65
        objects.fill[index] = triangle
    end

    triangle.PointA = a
    triangle.PointB = b
    triangle.PointC = c
    triangle.Color = color
    triangle.Visible = true
    return true
end

local draw_health = function(character, humanoid, camera, objects, color)
    if not triangle_supported then return end
    local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
    if ratio <= 0 then return end

    local polygons = {}
    local top, bottom = math.huge, -math.huge

    for _, part in character:GetChildren() do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
            local polygon = project_part(part, camera)
            if polygon and #polygon >= 3 then
                polygons[#polygons + 1] = polygon
                for _, point in polygon do
                    top = math.min(top, point.Y)
                    bottom = math.max(bottom, point.Y)
                end
            end
        end
    end

    if #polygons == 0 or bottom - top <= 1 then return end
    if bottom - top > camera.ViewportSize.Y * 3 then return end

    local cutoff = bottom - (bottom - top) * ratio
    local index = 0
    for _, polygon in polygons do
        local clipped = clip_bottom(polygon, cutoff)
        for i = 2, #clipped - 1 do
            index += 1
            if not fill_triangle(objects, index, clipped[1], clipped[i], clipped[i + 1], color) then
                return
            end
        end
    end
end

local draw_skeleton = function(character, humanoid, camera, objects, color)
    local bones = humanoid.RigType == Enum.HumanoidRigType.R6 and bones_r6 or bones_r15
    for i, pair in bones do
        local a = character:FindFirstChild(pair[1])
        local b = character:FindFirstChild(pair[2])
        if a and b then
            local p1 = camera:WorldToViewportPoint(a.Position)
            local p2 = camera:WorldToViewportPoint(b.Position)
            if p1.Z > 0 and p2.Z > 0 then
                local line = objects.skeleton[i]
                if not line then
                    line = new_line()
                    objects.skeleton[i] = line
                end
                line.From = Vector2.new(p1.X, p1.Y)
                line.To = Vector2.new(p2.X, p2.Y)
                line.Color = color
                line.Visible = true
            end
        end
    end
end

local update = function(player, objects, camera)
    hide(objects)
    if not esp.enabled or not esp.methods then return end

    local character = player.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return end

    local teammate = player.Team ~= nil and player.Team == localplayer.Team
        and not player.Neutral and not localplayer.Neutral
    if esp.teamcheck and teammate then return end

    local rootpoint, onscreen = camera:WorldToViewportPoint(root.Position)
    if not onscreen or rootpoint.Z <= 0 then return end

    local color = teammate and Color3.fromRGB(65, 160, 255) or Color3.fromRGB(255, 30, 30)
    local methods = esp.methods

    if methods.Glow then
        objects.glow.Adornee = character
        objects.glow.OutlineColor = color
        objects.glow.Enabled = true
    end

    if methods.Trace then
        local viewport = camera.ViewportSize
        local foot = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y * 0.5, 0)
        local endpoint = camera:WorldToViewportPoint(foot)
        if endpoint.Z > 0 then
            objects.trace.From = Vector2.new(viewport.X * 0.5, viewport.Y - 2)
            objects.trace.To = Vector2.new(endpoint.X, endpoint.Y)
            objects.trace.Color = Color3.fromRGB(60, 255, 95)
            objects.trace.Thickness = 1.5
            objects.trace.Visible = true
        end
    end

    if methods.Name then
        local head = character:FindFirstChild("Head")
        local target = head and head.Position + Vector3.new(0, head.Size.Y * 0.75 + 0.3, 0)
            or root.Position + Vector3.new(0, 3, 0)
        local point = camera:WorldToViewportPoint(target)
        if point.Z > 0 then
            objects.name.Text = player.DisplayName
            objects.name.Color = color
            objects.name.Position = Vector2.new(point.X, point.Y - 9)
            objects.name.Visible = true
        end
    end

    if methods.Skeleton then
        draw_skeleton(character, humanoid, camera, objects, color)
    end

    if methods.Health then
        draw_health(character, humanoid, camera, objects, color)
    end
end

function esp:set_enabled(value)
    self.enabled = value == true
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

local cleanup = function()
    if closed then return end
    closed = true
    for _, connection in connections do
        connection:Disconnect()
    end
    for player in cache do
        remove(player)
    end
end

function esp:destroy()
    cleanup()
    if folder.Parent then
        folder:Destroy()
    end
end

connections[#connections + 1] = folder.Destroying:Connect(cleanup)
connections[#connections + 1] = players.PlayerAdded:Connect(create)
connections[#connections + 1] = players.PlayerRemoving:Connect(remove)

for _, player in players:GetPlayers() do
    create(player)
end

local accumulator = 0
connections[#connections + 1] = runservice.RenderStepped:Connect(function(dt)
    accumulator += dt
    if accumulator < 1 / 30 then return end
    accumulator = 0

    local camera = workspace.CurrentCamera
    if not camera or closed then return end
    for player, objects in cache do
        local ok, err = pcall(update, player, objects, camera)
        if not ok then
            hide(objects)
            if errors[player] ~= tostring(err) then
                errors[player] = tostring(err)
                warn("[sixly_esp] " .. player.Name .. ": " .. tostring(err))
            end
        end
    end
end)

return esp
