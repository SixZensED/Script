-- v2
local players = game:GetService("Players")
local runservice = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local localplayer = players.LocalPlayer
local playergui = localplayer:WaitForChild("PlayerGui")
local mouse = localplayer:GetMouse()
local env = (getgenv and getgenv()) or _G

if not Drawing or type(Drawing.new) ~= "function" then
    error("sixly esp: this executor does not support Drawing.new")
end

if env.sixly_esp_drawing and type(env.sixly_esp_drawing.destroy) == "function" then
    pcall(function()
        env.sixly_esp_drawing:destroy()
    end)
end

local oldgui = playergui:FindFirstChild("sixly_esp")
if oldgui then oldgui:Destroy() end

local pink = Color3.fromRGB(255, 38, 220)
local purple = Color3.fromRGB(172, 59, 255)
local cyan = Color3.fromRGB(65, 210, 255)
local white = Color3.fromRGB(250, 247, 255)
local dark = Color3.fromRGB(18, 9, 26)
local red = Color3.fromRGB(255, 65, 100)
local green = Color3.fromRGB(65, 255, 145)

local r6parts = {
    "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"
}

local r15parts = {
    "Head", "UpperTorso", "LowerTorso",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot"
}

local r6bones = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"}
}

local r15bones = {
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

local esp = {
    enabled = true,
    teamcheck = false,
    maxdistance = 1200,
    tracerorigin = "Top",
    tracertarget = "Root",
    offset = Vector2.new(0, 0),
    projectionmode = "Viewport",
    autoscale = true,
    scale = Vector2.new(1, 1),
    drawing = {
        scale = Vector2.new(1, 1),
        offset = Vector2.zero,
        autoscale = true,
        multiplier = Vector2.new(1, 1)
    },
    methods = {
        Glow = true, Box = true, Skeleton = true,
        Trace = true, Name = true, Health = true, Distance = true
    }
}

local drawingSize = Vector2.zero
local projectionScale = Vector2.new(1, 1)
local projectionOrigin = Vector2.zero
local gui = Instance.new("ScreenGui")
gui.Name = "sixly_projection_monitor"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = -100
local frame = Instance.new("Frame")
frame.BackgroundTransparency = 1
frame.Size = UDim2.fromScale(1, 1)
frame.Parent = gui
gui.Parent = playergui
local baselineRatio
local currentRatio
local function refreshProjection(camera)
    drawingSize = camera.ViewportSize
    local screenSize = frame.AbsoluteSize
    currentRatio = Vector2.new(1, 1)
    if drawingSize.X > 0 and drawingSize.Y > 0 and screenSize.X > 0 and screenSize.Y > 0 then
        currentRatio = Vector2.new(screenSize.X / drawingSize.X, screenSize.Y / drawingSize.Y)
    end
    local config = esp.drawing
    local ratio = config.autoscale and currentRatio or Vector2.new(1, 1)
    projectionScale = Vector2.new(ratio.X * config.multiplier.X, ratio.Y * config.multiplier.Y)
    config.scale = projectionScale
    config.offset = esp.offset
    esp.scale = projectionScale
    esp.autoscale = config.autoscale
end

local cache = {}
local connections = {}
local watched = {}
local closed = false
local lastcamera
local lastviewport
local localdeathconnection
local recoverygeneration = 0
local rendername = "sixly_drawing_esp_v9_fixed"

local highlights = Instance.new("Folder")
highlights.Name = "sixly_drawing_highlights"
highlights.Parent = workspace

local function newdrawing(objects, kind, properties)
    local object = Drawing.new(kind)
    object.Visible = false
    for key, value in properties do
        object[key] = value
    end
    objects.drawings[#objects.drawings + 1] = object
    return object
end

local function newline(objects, color, thickness, transparency)
    return newdrawing(objects, "Line", {
        Color = color,
        Thickness = thickness,
        Transparency = transparency or 1
    })
end

local function newbox(objects, color, filled, thickness, transparency)
    return newdrawing(objects, "Square", {
        Color = color,
        Filled = filled,
        Thickness = thickness or 1,
        Transparency = transparency or 1
    })
end

local function newtext(objects, size)
    return newdrawing(objects, "Text", {
        Text = "",
        Size = size,
        Color = white,
        Center = true,
        Outline = true,
        OutlineColor = dark,
        Font = 2,
        Transparency = 1
    })
end

local function create(target, isplayer)
    if closed or cache[target] or target == localplayer then return end

    local objects = {
        target = target,
        isplayer = isplayer,
        drawings = {},
        bones = {},
        model = nil
    }

    objects.boxglow = newbox(objects, purple, false, 3, 0.33)
    objects.box = newbox(objects, pink, false, 1.5, 1)
    objects.traceglow = newline(objects, purple, 3, 0.3)
    objects.trace = newline(objects, white, 1, 0.85)
    objects.name = newtext(objects, 13)
    objects.info = newtext(objects, 12)
    objects.healthback = newbox(objects, dark, true, 1, 0.92)
    objects.healthfill = newbox(objects, green, true, 1, 1)
    objects.healthborder = newbox(objects, purple, false, 1, 0.85)

    for i = 1, #r15bones do
        objects.bones[i] = {
            glow = newline(objects, purple, 3.4, 0.4),
            core = newline(objects, pink, 1.5, 1)
        }
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "SixlyGlow_" .. target.Name
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = pink
    highlight.OutlineColor = purple
    highlight.FillTransparency = 0.70
    highlight.OutlineTransparency = 0
    highlight.Enabled = false
    highlight.Parent = highlights

    objects.highlight = highlight
    cache[target] = objects
    return objects
end

local function hide(objects)
    objects.highlight.Enabled = false
    for _, object in objects.drawings do
        object.Visible = false
    end
end

local function remove(target)
    local objects = cache[target]
    if not objects then return end
    cache[target] = nil
    objects.highlight:Destroy()
    for _, object in objects.drawings do
        pcall(function() object:Remove() end)
    end
end

local function project(camera, world)
    local point, visible = camera:WorldToViewportPoint(world)
    if point.Z <= 0 then return nil, false end
    local pos = Vector2.new(point.X * esp.drawing.scale.X, point.Y * esp.drawing.scale.Y) + esp.drawing.offset
    return pos, visible
end

local function extendpart(camera, part, bounds)
    local cf = part.CFrame
    local half = part.Size * 0.5
    local corners = {}

    for ix = -1, 1, 2 do
        for iy = -1, 1, 2 do
            for iz = -1, 1, 2 do
                local world = cf:PointToWorldSpace(Vector3.new(
                    half.X * ix, half.Y * iy, half.Z * iz
                ))
                local point = project(camera, world)
                if not point then return false end
                corners[#corners + 1] = point
            end
        end
    end

    for _, point in corners do
        bounds.minx = math.min(bounds.minx, point.X)
        bounds.miny = math.min(bounds.miny, point.Y)
        bounds.maxx = math.max(bounds.maxx, point.X)
        bounds.maxy = math.max(bounds.maxy, point.Y)
    end
    return true
end

local function getbodybox(camera, model, humanoid)
    local names = humanoid.RigType == Enum.HumanoidRigType.R6 and r6parts or r15parts
    local bounds = {
        minx = math.huge, miny = math.huge,
        maxx = -math.huge, maxy = -math.huge
    }
    local count = 0

    for _, name in names do
        local part = model:FindFirstChild(name)
        if part and part:IsA("BasePart") and extendpart(camera, part, bounds) then
            count += 1
        end
    end

    if count < 2 then
        bounds.minx, bounds.miny = math.huge, math.huge
        bounds.maxx, bounds.maxy = -math.huge, -math.huge
        count = 0
        local root = model:FindFirstChild("HumanoidRootPart")
        for _, part in model:GetChildren() do
            if part:IsA("BasePart") and part ~= root
                and part.Name ~= "Hitbox" and part.Name ~= "Collision" then
                if part.Size.Magnitude <= 15 and extendpart(camera, part, bounds) then
                    count += 1
                end
            end
        end
    end

    if count == 0 then return nil end

    local width = bounds.maxx - bounds.minx
    local height = bounds.maxy - bounds.miny
    if width < 1 or height < 2 then return nil end

    if width > height * 1.8 then
        local mid = (bounds.minx + bounds.maxx) * 0.5
        width = height * 1.8
        bounds.minx = mid - width * 0.5
    end

    return Vector2.new(bounds.minx - 2, bounds.miny - 2),
        Vector2.new(width + 4, height + 4)
end

local function drawbone(bone, a, b, color, glowcolor)
    if not a or not b then
        bone.glow.Visible = false
        bone.core.Visible = false
        return
    end
    bone.glow.From = a
    bone.glow.To = b
    bone.core.From = a
    bone.core.To = b
    bone.glow.Color = glowcolor
    bone.core.Color = color
    bone.glow.Visible = true
    bone.core.Visible = true
end

local function update(target, objects, camera, localroot)
    local model
    if objects.isplayer then
        model = target.Character
    else
        model = target
    end
    if not model or not model:IsA("Model") or not model.Parent then
        hide(objects)
        objects.model = nil
        objects.highlight.Adornee = nil
        return
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
        or model.PrimaryPart
    if not humanoid or humanoid.Health <= 0
        or not root or not root:IsA("BasePart") then
        hide(objects)
        return
    end

    local teammate = false
    if objects.isplayer then
        teammate = target.Team ~= nil and target.Team == localplayer.Team
            and not target.Neutral and not localplayer.Neutral
    end
    if esp.teamcheck and teammate then hide(objects) return end

    local distance = localroot and (root.Position - localroot.Position).Magnitude or 0
    if esp.maxdistance > 0 and localroot and distance > esp.maxdistance then
        hide(objects)
        return
    end

    local root2d, rootvisible = project(camera, root.Position)
    if not root2d or not rootvisible then hide(objects) return end

    local head = model:FindFirstChild("Head")
    local head2d
    if head and head:IsA("BasePart") then
        head2d = project(camera, head.Position + Vector3.new(0, head.Size.Y * 0.7 + 0.12, 0))
    end

    local pos, size = getbodybox(camera, model, humanoid)
    if not pos then hide(objects) return end

    if objects.model ~= model then
        objects.model = model
        objects.highlight.Adornee = model
    end

    local methods = esp.methods
    local color = teammate and cyan or pink
    local glowcolor = teammate and cyan or purple

    objects.highlight.Enabled = methods.Glow == true
    objects.highlight.FillColor = color
    objects.highlight.OutlineColor = glowcolor

    local boxmiddle = pos.X + size.X * 0.5
    local boxbottom = pos.Y + size.Y
    local anchorx = head2d and head2d.X or root2d.X

    local showbox = methods.Box == true
    objects.box.Visible = showbox
    objects.boxglow.Visible = showbox
    if showbox then
        objects.box.Position, objects.box.Size = pos, size
        objects.boxglow.Position, objects.boxglow.Size = pos, size
        objects.box.Color = color
        objects.boxglow.Color = glowcolor
    end

    local showtrace = methods.Trace == true or methods.Line == true
    objects.trace.Visible = showtrace
    objects.traceglow.Visible = showtrace
    if showtrace then
        local from = Vector2.new(
            drawingSize.X * 0.5 * projectionScale.X + esp.offset.X,
            esp.tracerorigin == "Bottom" and (drawingSize.Y * projectionScale.Y + esp.offset.Y) or esp.offset.Y
        )
        local to = root2d
        if esp.tracertarget == "Head" then
            to = head2d or root2d
        elseif esp.tracertarget == "Feet" then
            to = Vector2.new(boxmiddle, boxbottom)
        end
        objects.trace.From, objects.trace.To = from, to
        objects.traceglow.From, objects.traceglow.To = from, to
    end

    local showname = methods.Name == true
    objects.name.Visible = showname
    if showname then
        objects.name.Text = objects.isplayer and target.Name or target.Name
        objects.name.Position = Vector2.new(anchorx, (head2d and head2d.Y or pos.Y) - 17)
        objects.name.Color = white
    end

    local showhealth = methods.Health == true
    objects.healthback.Visible = showhealth
    objects.healthfill.Visible = showhealth
    objects.healthborder.Visible = showhealth
    if showhealth then
        local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
        local barwidth = math.max(20, math.min(size.X, 85))
        local barpos = Vector2.new(boxmiddle - barwidth * 0.5, boxbottom + 5)
        local barsize = Vector2.new(barwidth, 4)
        objects.healthback.Position, objects.healthback.Size = barpos, barsize
        objects.healthfill.Position = barpos
        objects.healthfill.Size = Vector2.new(barwidth * ratio, 4)
        objects.healthfill.Color = red:Lerp(green, ratio)
        objects.healthborder.Position, objects.healthborder.Size = barpos, barsize
    end

    local showinfo = methods.Health == true or methods.Distance == true
    objects.info.Visible = showinfo
    if showinfo then
        local info = {}
        if methods.Health then
            info[#info + 1] = string.format("%d HP", math.ceil(humanoid.Health))
        end
        if methods.Distance and localroot then
            info[#info + 1] = string.format("%d studs", math.floor(distance + 0.5))
        end
        objects.info.Text = table.concat(info, " | ")
        objects.info.Position = Vector2.new(boxmiddle, boxbottom + (showhealth and 13 or 5))
    end

    local showbones = methods.Skeleton == true
    local names = humanoid.RigType == Enum.HumanoidRigType.R6 and r6bones or r15bones
    for i, bone in objects.bones do
        local pair = names[i]
        if not showbones or not pair then
            bone.glow.Visible = false
            bone.core.Visible = false
            continue
        end
        local a = model:FindFirstChild(pair[1])
        local b = model:FindFirstChild(pair[2])
        if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
            drawbone(bone, project(camera, a.Position), project(camera, b.Position), color, glowcolor)
        else
            drawbone(bone, nil, nil, color, glowcolor)
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

function esp:set_trace_target(value)
    self.tracertarget = (value == "Head" or value == "Feet") and value or "Root"
end

function esp:set_maxdistance(value)
    self.maxdistance = math.max(0, tonumber(value) or 0)
end

function esp:set_offset(value)
    if typeof(value) == "Vector2" then
        self.offset = value
        self.drawing.offset = value
    end
end

function esp:set_projection_mode(value)
    self.projectionmode = "Viewport"
end

function esp:set_auto_scale(value)
    self.drawing.autoscale = value == true
    self.autoscale = self.drawing.autoscale
end

function esp:set_projection_scale(value)
    if typeof(value) == "Vector2" and value.X > 0 and value.Y > 0 then
        self.drawing.multiplier = value
    end
end

function esp:get_projection_info()
    local camera = workspace.CurrentCamera
    return {
        cameraViewport = camera and camera.ViewportSize,
        mode = "Viewport (dynamic GUI ratio)",
        scale = self.drawing.multiplier,
        effectiveScale = projectionScale,
        guiSize = frame.AbsoluteSize,
        guiToViewportRatio = currentRatio,
        baselineRatio = baselineRatio,
        autoscale = self.autoscale,
        offset = self.offset,
        calibrationSamples = #(self._samples or {})
    }
end

function esp:clear_calibration()
    self._samples = {}
    self.drawing.multiplier = Vector2.new(1, 1)
    self.drawing.autoscale = true
    self.drawing.scale = Vector2.new(1, 1)
    self.drawing.offset = Vector2.zero
    self.offset = Vector2.zero
    self.autoscale = true
    self.scale = Vector2.new(1, 1)
    baselineRatio = nil
    projectionScale = self.scale
end

function esp:calibrate()
    self:clear_calibration()
end

function esp:add_model(model)
    if typeof(model) == "Instance" and model:IsA("Model") then
        create(model, false)
    end
end

function esp:remove_model(model)
    remove(model)
end

function esp:watch_npcs(folder)
    if typeof(folder) ~= "Instance" or watched[folder] then return end
    watched[folder] = true
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

function esp:refresh()
    if closed then return end
    recoverygeneration += 1
    baselineRatio = nil
    currentRatio = nil
    projectionScale = self.drawing.scale
    projectionOrigin = Vector2.zero
    lastcamera = nil
    lastviewport = nil
    local targets = {}
    for target, objects in cache do
        targets[#targets + 1] = {target, objects.isplayer}
    end
    for _, item in targets do
        remove(item[1])
    end
    for _, item in targets do
        if item[1] and (item[2] or item[1].Parent) then
            create(item[1], item[2])
        end
    end
end

local function scheduleRecovery()
    recoverygeneration += 1
    local generation = recoverygeneration
    task.defer(function()
        if closed or generation ~= recoverygeneration then return end
        esp:refresh()
    end)
end

local function bindLocalCharacter(character)
    if localdeathconnection then
        localdeathconnection:Disconnect()
        localdeathconnection = nil
    end
    scheduleRecovery()
    task.spawn(function()
        local humanoid = character:WaitForChild("Humanoid", 10)
        if closed or localplayer.Character ~= character or not humanoid then return end
        localdeathconnection = humanoid.Died:Connect(scheduleRecovery)
    end)
end

connections[#connections + 1] = localplayer.CharacterAdded:Connect(bindLocalCharacter)
if localplayer.Character then bindLocalCharacter(localplayer.Character) end
connections[#connections + 1] = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(scheduleRecovery)

function esp:destroy()
    if closed then return end
    if self._calibrationconnection then self._calibrationconnection:Disconnect() end
    if localdeathconnection then localdeathconnection:Disconnect() end
    closed = true
    runservice:UnbindFromRenderStep(rendername)
    for _, connection in connections do connection:Disconnect() end
    for target in cache do remove(target) end
    highlights:Destroy()
    gui:Destroy()
    if env.sixly_esp_drawing == self then env.sixly_esp_drawing = nil end
end

connections[#connections + 1] = players.PlayerAdded:Connect(function(player)
    create(player, true)
end)
connections[#connections + 1] = players.PlayerRemoving:Connect(remove)

for _, player in players:GetPlayers() do
    if player ~= localplayer then create(player, true) end
end

runservice:BindToRenderStep(rendername, Enum.RenderPriority.Camera.Value + 1, function()
    if closed or not esp.enabled then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    if lastcamera and (lastcamera ~= camera or lastviewport ~= viewport) then
        scheduleRecovery()
    end
    lastcamera = camera
    lastviewport = viewport
    refreshProjection(camera)
    local character = localplayer.Character
    local localroot = character and character:FindFirstChild("HumanoidRootPart")
    for target, objects in cache do
        if not objects.isplayer and not target.Parent then
            remove(target)
        else
            update(target, objects, camera, localroot)
        end
    end
end)

env.sixly_esp_drawing = esp
return esp
