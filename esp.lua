local players = game:GetService("Players")
local runservice = game:GetService("RunService")
local localplayer = players.LocalPlayer
local playergui = localplayer:WaitForChild("PlayerGui")
local env = (getgenv and getgenv()) or _G

if not Drawing or type(Drawing.new) ~= "function" then
    error("Sixly ESP: Drawing API is not supported by this executor")
end

if env.sixly_esp_drawing and type(env.sixly_esp_drawing.destroy) == "function" then
    pcall(function() env.sixly_esp_drawing:destroy() end)
end

local oldgui = playergui:FindFirstChild("sixly_esp")
if oldgui then oldgui:Destroy() end

local pink = Color3.fromRGB(255, 48, 230)
local purple = Color3.fromRGB(186, 67, 255)
local cyan = Color3.fromRGB(73, 209, 255)
local white = Color3.fromRGB(255, 250, 255)
local dark = Color3.fromRGB(18, 9, 25)
local red = Color3.fromRGB(255, 65, 100)
local green = Color3.fromRGB(72, 255, 144)

local r15 = {
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
    {"RightLowerLeg", "RightFoot"}
}

local r6 = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

local esp = {
    enabled = true,
    teamcheck = false,
    maxdistance = 1200,
    tracerorigin = "Top",
    offset = Vector2.zero,
    methods = {
        Glow = true, Box = true, Skeleton = true,
        Trace = true, Name = true, Health = true, Distance = true
    }
}

local cache = {}
local connections = {}
local closed = false
local rendername = "sixly_drawing_esp_v4"
local highlights = Instance.new("Folder")
highlights.Name = "sixly_esp_drawing_highlights"
highlights.Parent = workspace

local function drawing(objects, kind, props)
    local object = Drawing.new(kind)
    object.Visible = false
    for key, value in props do
        object[key] = value
    end
    objects.drawings[#objects.drawings + 1] = object
    return object
end

local function line(objects, color, thickness, transparency)
    return drawing(objects, "Line", {
        Color = color,
        Thickness = thickness,
        Transparency = transparency or 1
    })
end

local function square(objects, color, filled, thickness, transparency)
    return drawing(objects, "Square", {
        Color = color,
        Filled = filled,
        Thickness = thickness or 1,
        Transparency = transparency or 1
    })
end

local function label(objects, color, size)
    return drawing(objects, "Text", {
        Color = color,
        Size = size,
        Center = true,
        Outline = true,
        OutlineColor = dark,
        Font = 2,
        Transparency = 1
    })
end

local function make(target, isplayer)
    if cache[target] or closed or target == localplayer then return end
    local objects = {
        target = target,
        isplayer = isplayer,
        drawings = {},
        bones = {},
        model = nil
    }

    objects.boxglow = square(objects, purple, false, 3, 0.3)
    objects.box = square(objects, pink, false, 1.3, 1)
    objects.traceglow = line(objects, purple, 3, 0.22)
    objects.trace = line(objects, white, 1, 0.82)
    objects.dot = drawing(objects, "Circle", {
        Color = white, Filled = true, Radius = 2,
        NumSides = 14, Thickness = 1, Transparency = 1
    })
    objects.name = label(objects, white, 13)
    objects.info = label(objects, white, 12)
    objects.healthbg = square(objects, dark, true, 1, 0.95)
    objects.healthfill = square(objects, pink, true, 1, 1)
    objects.healthoutline = square(objects, purple, false, 1, 0.8)

    for i = 1, #r15 do
        objects.bones[i] = {
            glow = line(objects, purple, 4, 0.4),
            core = line(objects, pink, 1.65, 1)
        }
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "Glow_" .. target.Name
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = pink
    highlight.OutlineColor = purple
    highlight.FillTransparency = 0.68
    highlight.OutlineTransparency = 0.04
    highlight.Enabled = false
    highlight.Parent = highlights
    objects.highlight = highlight
    cache[target] = objects
    return objects
end

local function hide(objects)
    objects.highlight.Enabled = false
    for _, item in objects.drawings do
        item.Visible = false
    end
end

local function remove(target)
    local objects = cache[target]
    if not objects then return end
    cache[target] = nil
    objects.highlight:Destroy()
    for _, item in objects.drawings do
        pcall(function() item:Remove() end)
    end
end

local function project(camera, world)
    local point, onscreen = camera:WorldToViewportPoint(world)
    if not onscreen or point.Z <= 0 then return nil end
    return Vector2.new(point.X, point.Y) + esp.offset
end

-- Bounding-box projection, including rotated characters/NPCs.
local function getbox(camera, model)
    local cf, size = model:GetBoundingBox()
    local half = size * 0.5
    local minx, miny = math.huge, math.huge
    local maxx, maxy = -math.huge, -math.huge
    local projected = 0

    for ix = -1, 1, 2 do
        for iy = -1, 1, 2 do
            for iz = -1, 1, 2 do
                local world = cf:PointToWorldSpace(Vector3.new(
                    half.X * ix, half.Y * iy, half.Z * iz
                ))
                local point = camera:WorldToViewportPoint(world)
                if point.Z > 0 then
                    minx = math.min(minx, point.X)
                    miny = math.min(miny, point.Y)
                    maxx = math.max(maxx, point.X)
                    maxy = math.max(maxy, point.Y)
                    projected += 1
                end
            end
        end
    end

    if projected ~= 8 then return nil end
    local top = Vector2.new(minx - 3, miny - 3) + esp.offset
    local size2d = Vector2.new(maxx - minx + 6, maxy - miny + 6)
    if size2d.X < 2 or size2d.Y < 2 then return nil end
    return top, size2d
end

local function drawbone(bone, a, b, color)
    if not a or not b then
        bone.glow.Visible = false
        bone.core.Visible = false
        return
    end
    bone.glow.From, bone.glow.To = a, b
    bone.core.From, bone.core.To = a, b
    bone.glow.Color = color == cyan and cyan or purple
    bone.core.Color = color
    bone.glow.Visible = true
    bone.core.Visible = true
end

local function update(target, objects, camera, localroot)
    local methods = esp.methods
    local model = objects.isplayer and target.Character or target
    if not model or not model.Parent then hide(objects) return end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
        or model.PrimaryPart
    if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
        hide(objects)
        return
    end

    local teammate = false
    if objects.isplayer then
        teammate = target.Team ~= nil and target.Team == localplayer.Team
            and not target.Neutral and not localplayer.Neutral
    end
    if teammate and esp.teamcheck then hide(objects) return end

    local color = teammate and cyan or pink
    local distance = localroot and (localroot.Position - root.Position).Magnitude or 0
    if esp.maxdistance > 0 and distance > esp.maxdistance then
        hide(objects)
        return
    end

    local root2d = project(camera, root.Position)
    if not root2d then hide(objects) return end

    if objects.model ~= model then
        objects.model = model
        objects.highlight.Adornee = model
    end
    objects.highlight.FillColor = color
    objects.highlight.OutlineColor = teammate and cyan or purple
    objects.highlight.Enabled = methods.Glow == true

    local pos, size = getbox(camera, model)
    if not pos then hide(objects) return end
    local middle = pos.X + size.X * 0.5
    local bottom = pos.Y + size.Y

    local showbox = methods.Box == true
    objects.boxglow.Visible = showbox
    objects.box.Visible = showbox
    if showbox then
        objects.boxglow.Position, objects.boxglow.Size = pos, size
        objects.box.Position, objects.box.Size = pos, size
        objects.box.Color = color
        objects.boxglow.Color = teammate and cyan or purple
    end

    local showtrace = methods.Trace == true or methods.Line == true
    objects.trace.Visible = showtrace
    objects.traceglow.Visible = showtrace
    objects.dot.Visible = showtrace
    if showtrace then
        local viewport = camera.ViewportSize
        local from = Vector2.new(viewport.X * 0.5,
            esp.tracerorigin == "Bottom" and viewport.Y or 0) + esp.offset
        local to = Vector2.new(middle, pos.Y)
        objects.trace.From, objects.trace.To = from, to
        objects.traceglow.From, objects.traceglow.To = from, to
        objects.dot.Position = to
    end

    local showname = methods.Name == true
    objects.name.Visible = showname
    if showname then
        objects.name.Text = objects.isplayer and target.DisplayName or target.Name
        objects.name.Position = Vector2.new(middle, pos.Y - 19)
        objects.name.Color = white
    end

    local showhealth = methods.Health == true
    objects.healthbg.Visible = showhealth
    objects.healthfill.Visible = showhealth
    objects.healthoutline.Visible = showhealth
    if showhealth then
        local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
        local width = math.max(10, size.X)
        local barpos = Vector2.new(middle - width * 0.5, bottom + 3)
        local barsize = Vector2.new(width, 4)
        objects.healthbg.Position, objects.healthbg.Size = barpos, barsize
        objects.healthfill.Position = barpos
        objects.healthfill.Size = Vector2.new(math.max(0.1, width * ratio), 4)
        objects.healthfill.Color = red:Lerp(green, ratio)
        objects.healthoutline.Position, objects.healthoutline.Size = barpos, barsize
    end

    local showinfo = methods.Distance == true or methods.Health == true
    objects.info.Visible = showinfo
    if showinfo then
        local parts = {}
        if methods.Health then
            parts[#parts + 1] = string.format("%d HP", math.ceil(humanoid.Health))
        end
        if methods.Distance then
            parts[#parts + 1] = string.format("%dm", math.floor(distance / 3.571 + 0.5))
        end
        objects.info.Text = table.concat(parts, " | ")
        objects.info.Position = Vector2.new(middle, bottom + (showhealth and 10 or 5))
    end

    local showbones = methods.Skeleton == true
    local bones = humanoid.RigType == Enum.HumanoidRigType.R6 and r6 or r15
    for i, bone in objects.bones do
        local pair = bones[i]
        if not showbones or not pair then
            bone.glow.Visible = false
            bone.core.Visible = false
            continue
        end
        local a = model:FindFirstChild(pair[1])
        local b = model:FindFirstChild(pair[2])
        if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
            drawbone(bone, project(camera, a.Position), project(camera, b.Position), color)
        else
            drawbone(bone, nil, nil, color)
        end
    end
end

function esp:set_enabled(value)
    self.enabled = value == true
    if not self.enabled then
        for _, objects in cache do hide(objects) end
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

function esp:set_trace_origin(value)
    self.tracerorigin = value == "Bottom" and "Bottom" or "Top"
end

function esp:set_maxdistance(value)
    self.maxdistance = math.max(0, tonumber(value) or 0)
end

function esp:set_offset(value)
    if typeof(value) == "Vector2" then self.offset = value end
end

function esp:add_model(model)
    if typeof(model) == "Instance" and model:IsA("Model") then
        make(model, false)
    end
end

function esp:remove_model(model)
    remove(model)
end

-- Optional NPC support, including NPCs spawned later.
function esp:watch_npcs(folder)
    if typeof(folder) ~= "Instance" then return end
    for _, descendant in folder:GetDescendants() do
        if descendant:IsA("Humanoid") and descendant.Parent:IsA("Model") then
            self:add_model(descendant.Parent)
        end
    end
    connections[#connections + 1] = folder.DescendantAdded:Connect(function(instance)
        if instance:IsA("Humanoid") and instance.Parent:IsA("Model") then
            self:add_model(instance.Parent)
        end
    end)
end

function esp:destroy()
    if closed then return end
    closed = true
    runservice:UnbindFromRenderStep(rendername)
    for _, connection in connections do connection:Disconnect() end
    for target in cache do remove(target) end
    highlights:Destroy()
    if env.sixly_esp_drawing == self then env.sixly_esp_drawing = nil end
end

connections[#connections + 1] = players.PlayerAdded:Connect(function(player)
    make(player, true)
end)
connections[#connections + 1] = players.PlayerRemoving:Connect(remove)

for _, player in players:GetPlayers() do
    if player ~= localplayer then make(player, true) end
end

runservice:BindToRenderStep(rendername, Enum.RenderPriority.Camera.Value + 1, function()
    if closed or not esp.enabled then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local character = localplayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    for target, objects in cache do
        if not objects.isplayer and not target.Parent then
            remove(target)
        else
            update(target, objects, camera, root)
        end
    end
end)

env.sixly_esp_drawing = esp
return esp
