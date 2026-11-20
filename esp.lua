-- Sixly ESP v6
local players = game:GetService("Players")
local runservice = game:GetService("RunService")
local localplayer = players.LocalPlayer
local env = (getgenv and getgenv()) or _G

assert(Drawing and type(Drawing.new) == "function", "sixly esp: Drawing.new required")

if env.sixly_esp_drawing and type(env.sixly_esp_drawing.destroy) == "function" then
    pcall(function()
        env.sixly_esp_drawing:destroy()
    end)
end

local palette = {
    primary = Color3.fromHex("#8A34A7"),
    ally = Color3.fromHex("#BC79D4"),
    outline = Color3.fromHex("#0F0F0F"),
    text = Color3.fromHex("#D9D9DE"),
    muted = Color3.fromHex("#85858F"),
    low = Color3.fromRGB(255, 85, 105),
    health = Color3.fromRGB(85, 230, 155),
}

local r6parts = {
    "Head",
    "Torso",
    "Left Arm",
    "Right Arm",
    "Left Leg",
    "Right Leg",
}

local r15parts = {
    "Head",
    "UpperTorso",
    "LowerTorso",
    "LeftUpperArm",
    "LeftLowerArm",
    "LeftHand",
    "RightUpperArm",
    "RightLowerArm",
    "RightHand",
    "LeftUpperLeg",
    "LeftLowerLeg",
    "LeftFoot",
    "RightUpperLeg",
    "RightLowerLeg",
    "RightFoot",
}

local r6bones = {
    { "head", "neck" },
    { "neck", "chest" },
    { "left_shoulder", "right_shoulder" },
    { "left_shoulder", "left_hip" },
    { "right_shoulder", "right_hip" },
    { "left_hip", "right_hip" },
    { "left_shoulder", "left_hand" },
    { "right_shoulder", "right_hand" },
    { "left_hip", "left_foot" },
    { "right_hip", "right_foot" },
}

local r15bones = {
    { "head", "neck" },
    { "neck", "chest" },
    { "left_shoulder", "right_shoulder" },
    { "left_shoulder", "left_hip" },
    { "right_shoulder", "right_hip" },
    { "left_hip", "right_hip" },
    { "left_shoulder", "left_elbow" },
    { "left_elbow", "left_wrist" },
    { "left_wrist", "left_hand" },
    { "right_shoulder", "right_elbow" },
    { "right_elbow", "right_wrist" },
    { "right_wrist", "right_hand" },
    { "left_hip", "left_knee" },
    { "left_knee", "left_ankle" },
    { "left_ankle", "left_foot" },
    { "right_hip", "right_knee" },
    { "right_knee", "right_ankle" },
    { "right_ankle", "right_foot" },
}

-- Joint entries: node, parent part, child part, attachment, fallback size fractions.
local r6joints = {
    { "neck", "Torso", "Head", "NeckRigAttachment", 0, -0.5, 0 },
    { "left_shoulder", "Torso", "Left Arm", "LeftShoulderRigAttachment", 0.5, 0.25, 0 },
    { "right_shoulder", "Torso", "Right Arm", "RightShoulderRigAttachment", -0.5, 0.25, 0 },
    { "left_hip", "Torso", "Left Leg", "LeftHipRigAttachment", 0, 0.5, 0 },
    { "right_hip", "Torso", "Right Leg", "RightHipRigAttachment", 0, 0.5, 0 },
}

local r15joints = {
    { "neck", "UpperTorso", "Head", "NeckRigAttachment", 0, -0.5, 0 },
    { "left_shoulder", "UpperTorso", "LeftUpperArm", "LeftShoulderRigAttachment", 0, 0.5, 0 },
    { "left_elbow", "LeftUpperArm", "LeftLowerArm", "LeftElbowRigAttachment", 0, 0.5, 0 },
    { "left_wrist", "LeftLowerArm", "LeftHand", "LeftWristRigAttachment", 0, 0.5, 0 },
    { "right_shoulder", "UpperTorso", "RightUpperArm", "RightShoulderRigAttachment", 0, 0.5, 0 },
    { "right_elbow", "RightUpperArm", "RightLowerArm", "RightElbowRigAttachment", 0, 0.5, 0 },
    { "right_wrist", "RightLowerArm", "RightHand", "RightWristRigAttachment", 0, 0.5, 0 },
    { "left_hip", "LowerTorso", "LeftUpperLeg", "LeftHipRigAttachment", 0, 0.5, 0 },
    { "left_knee", "LeftUpperLeg", "LeftLowerLeg", "LeftKneeRigAttachment", 0, 0.5, 0 },
    { "left_ankle", "LeftLowerLeg", "LeftFoot", "LeftAnkleRigAttachment", 0, 0.5, 0 },
    { "right_hip", "LowerTorso", "RightUpperLeg", "RightHipRigAttachment", 0, 0.5, 0 },
    { "right_knee", "RightUpperLeg", "RightLowerLeg", "RightKneeRigAttachment", 0, 0.5, 0 },
    { "right_ankle", "RightLowerLeg", "RightFoot", "RightAnkleRigAttachment", 0, 0.5, 0 },
}

local unit = Vector2.new(1, 1)
local studs_to_meters = 0.28

-- Corner anchor (0/1) and segment direction along each edge.
local box_segments = {
    { 0, 0, 1, 0 },
    { 0, 0, 0, 1 },
    { 1, 0, -1, 0 },
    { 1, 0, 0, 1 },
    { 0, 1, 1, 0 },
    { 0, 1, 0, -1 },
    { 1, 1, -1, 0 },
    { 1, 1, 0, -1 },
}

local esp = {
    enabled = false,
    teamcheck = false,
    maxdistance = 1200,
    arrowradius = 180,
    arrowsize = 10,
    tracerorigin = "Top",
    tracertarget = "Root",
    offset = Vector2.zero,
    projectionmode = "Viewport",
    autoscale = true,
    scale = unit,
    drawing = {
        scale = unit,
        offset = Vector2.zero,
        autoscale = true,
        multiplier = unit,
    },
    methods = {
        Glow = false,
        Box = false,
        Skeleton = false,
        Trace = false,
        Name = false,
        Health = false,
        Distance = false,
        Weapon = false,
        Arrow = false,
    },
    custom = {},
}

local cache, connections, watched, warnings = {}, {}, {}, {}
local closed = false
local rendername = "sixly_custom_esp_render"
local drawingSize, currentRatio, projectionScale = Vector2.zero, unit, unit

local gui = Instance.new("ScreenGui")
gui.Name = "sixly_projection_monitor"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = -100
gui.Parent = localplayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1)
frame.BackgroundTransparency = 1
frame.Parent = gui

local highlights = Instance.new("Folder")
highlights.Name = "sixly_drawing_highlights"
highlights.Parent = workspace

local finite = function(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local report = function(key, message)
    local now = os.clock()
    if warnings[key] and now - warnings[key] < 5 then
        return
    end

    warnings[key] = now
    warn("[Sixly ESP] " .. key .. ": " .. tostring(message))
end

local call = function(name, ...)
    local fn = esp.custom[name]
    if type(fn) ~= "function" then
        return nil
    end

    local ok, a, b = pcall(fn, ...)
    if ok then
        return a, b
    end
    report(name, a)
end

local characterof = function(target, isplayer)
    if not isplayer then
        return target
    end

    local value = call("get_character", target)
    if typeof(value) == "Instance" then
        return value
    end

    return target.Character
end

local rootof = function(target, model, body)
    local part = call("get_root", target, model)
    if typeof(part) == "Instance" and part:IsA("BasePart") then
        return part
    end

    if body then
        return body.named.HumanoidRootPart or body.named.UpperTorso or body.named.Torso or model.PrimaryPart
    end

    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
        or model.PrimaryPart
end

local get_distance_origin = function(camera)
    local origin = call("get_distance_origin", localplayer, camera)
    if typeof(origin) == "Vector3" and finite(origin.X) and finite(origin.Y) and finite(origin.Z) then
        return origin
    end

    local character = characterof(localplayer, true)
    if typeof(character) == "Instance" and character:IsA("Model") then
        local root = rootof(localplayer, character)
        if typeof(root) == "Instance" and root:IsA("BasePart") then
            return root.Position
        end
    end

    return camera.CFrame.Position
end

local get_weapon = function(target, model, body)
    local value
    if type(esp.custom.get_weapon) == "function" then
        value = call("get_weapon", target, model)
    else
        local tool = body.tool
        if tool and tool.Parent == model then
            value = tool.Name
        end
    end

    if type(value) ~= "string" then
        return nil
    end

    value = string.gsub(value, "%c", " ")
    value = string.match(value, "^%s*(.-)%s*$")

    return value ~= "" and value or nil
end

local get_info_text = function(target, model, body, methods, distance, origin)
    local label
    if methods.Distance == true and origin then
        label = string.format("%dm", math.floor(distance * studs_to_meters + 0.5))
    end

    if methods.Weapon == true then
        local weapon = get_weapon(target, model, body)
        if weapon then
            label = label and (label .. " " .. weapon) or weapon
        end
    end

    return label
end

-- Cache Drawing properties to avoid redundant writes across the Drawing API.
local set = function(drawing, key, value)
    if drawing.state[key] ~= value then
        drawing.object[key] = value
        drawing.state[key] = value
    end
end

local newdrawing = function(group, kind, properties)
    local drawing = {
        object = Drawing.new(kind),
        kind = kind,
        state = {},
    }

    group[#group + 1] = drawing
    set(drawing, "Visible", false)
    for key, value in properties do
        set(drawing, key, value)
    end

    return drawing
end

local line = function(group, thickness, color, alpha)
    return newdrawing(group, "Line", { Thickness = thickness, Color = color, Transparency = alpha or 1 })
end

local square = function(group, filled, thickness, color)
    return newdrawing(group, "Square", { Filled = filled, Thickness = thickness, Color = color, Transparency = 1 })
end

local text = function(group, size, color)
    return newdrawing(group, "Text", {
        Text = "",
        Size = size,
        Color = color,
        Center = true,
        Outline = true,
        OutlineColor = palette.outline,
        Font = 2,
        Transparency = 1,
        ZIndex = 4,
    })
end

local show = function(group, visible)
    if not group or group.visible == visible then
        return
    end

    for _, drawing in ipairs(group) do
        set(drawing, "Visible", visible)
    end

    group.visible = visible
end

local hide = function(o)
    if not o.visible then
        return
    end

    o.visible = false
    o.offscreen = false
    if o.highlight then
        o.highlight.Enabled = false
    end

    for _, group in o.groups do
        show(group, false)
    end
end

local disconnect = function(list)
    for _, connection in list do
        connection:Disconnect()
    end

    table.clear(list)
end

local unbindmodel = function(o)
    disconnect(o.modelconnections)
    o.model, o.body = nil, nil
    if o.highlight then
        o.highlight.Adornee = nil
    end
end

-- Topology is rebuilt on model/child changes; animated transforms stay live.
local bodyof = function(o, model)
    if o.model ~= model then
        unbindmodel(o)
        o.model, o.dirty = model, true
        local invalidate = function(item)
            if item:IsA("BasePart")
                or item:IsA("Humanoid")
                or item:IsA("Motor6D")
                or item:IsA("Attachment")
                or item:IsA("Tool")
            then
                o.dirty = true
            end
        end

        o.modelconnections[1] = model.DescendantAdded:Connect(invalidate)
        o.modelconnections[2] = model.DescendantRemoving:Connect(invalidate)
        if o.highlight then
            o.highlight.Adornee = model
        end
    end

    if not o.dirty then
        return o.body
    end

    local body = {
        named = {},
        parts = {},
        points = {},
        worldpoints = {},
        fallback = {},
    }

    for _, child in model:GetChildren() do
        if child:IsA("BasePart") then
            body.named[child.Name] = child
            if child.Name ~= "HumanoidRootPart" and child.Name ~= "Hitbox" and child.Name ~= "Collision" then
                body.fallback[#body.fallback + 1] = child
            end
        elseif child:IsA("Humanoid") then
            body.humanoid = child
        elseif child:IsA("Tool") and not body.tool then
            body.tool = child
        end
    end

    local r15 = body.named.UpperTorso ~= nil
        and not (body.humanoid and body.humanoid.RigType == Enum.HumanoidRigType.R6)
    body.r15 = r15

    for _, name in (r15 and r15parts or r6parts) do
        local part = body.named[name]
        if part then
            body.parts[#body.parts + 1] = part
        end
    end

    o.body, o.dirty = body, false
    return body
end

local remove = function(target)
    local o = cache[target]
    if not o then
        return
    end

    cache[target] = nil
    unbindmodel(o)
    disconnect(o.connections)
    if o.highlight then
        o.highlight:Destroy()
    end

    for _, group in o.groups do
        for _, drawing in ipairs(group) do
            pcall(function()
                drawing.object:Remove()
            end)
        end
    end
end

local create = function(target, isplayer)
    if closed or cache[target] or target == localplayer then
        return
    end

    local o = {
        target = target,
        isplayer = isplayer,
        groups = {},
        modelconnections = {},
        connections = {},
        visible = false,
    }

    cache[target] = o
    if not isplayer then
        o.connections[1] = target.AncestryChanged:Connect(function()
            if not target.Parent then
                remove(target)
            end
        end)
    end
end

local projection = function(camera)
    drawingSize = camera.ViewportSize
    local size = frame.AbsoluteSize
    currentRatio = unit
    if size.X > 0 and size.Y > 0 and drawingSize.X > 0 and drawingSize.Y > 0 then
        currentRatio = Vector2.new(size.X / drawingSize.X, size.Y / drawingSize.Y)
    end

    local cfg = esp.drawing
    local ratio = cfg.autoscale and currentRatio or unit
    projectionScale = Vector2.new(ratio.X * cfg.multiplier.X, ratio.Y * cfg.multiplier.Y)
    cfg.scale, cfg.offset = projectionScale, esp.offset
    esp.scale, esp.autoscale = projectionScale, cfg.autoscale
end

local project = function(camera, world)
    local point, visible = camera:WorldToViewportPoint(world)
    if point.Z <= 0 then
        return nil, false
    end

    return Vector2.new(point.X * projectionScale.X + esp.offset.X, point.Y * projectionScale.Y + esp.offset.Y), visible
end

-- Accumulate corners without allocating eight-point tables per body part.
local extendpart = function(camera, part, minx, miny, maxx, maxy)
    local cf, half = part.CFrame, part.Size * 0.5
    local left, top, right, bottom = minx, miny, maxx, maxy
    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = -1, 1, 2 do
                local p =
                    camera:WorldToViewportPoint(cf:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z)))
                if p.Z <= 0 then
                    return minx, miny, maxx, maxy, false
                end
                left, top = math.min(left, p.X), math.min(top, p.Y)
                right, bottom = math.max(right, p.X), math.max(bottom, p.Y)
            end
        end
    end

    return left, top, right, bottom, true
end

local bodybox = function(camera, body)
    local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
    local count = 0
    for _, part in body.parts do
        local included
        minx, miny, maxx, maxy, included = extendpart(camera, part, minx, miny, maxx, maxy)
        if included then
            count = count + 1
        end
    end

    if count < 2 then
        minx, miny, maxx, maxy, count = math.huge, math.huge, -math.huge, -math.huge, 0
        for _, part in body.fallback do
            if part.Size.Magnitude <= 15 then
                local included
                minx, miny, maxx, maxy, included = extendpart(camera, part, minx, miny, maxx, maxy)
                if included then
                    count = count + 1
                end
            end
        end
    end

    if count == 0 then
        return nil
    end
    minx, miny = minx * projectionScale.X + esp.offset.X, miny * projectionScale.Y + esp.offset.Y
    maxx, maxy = maxx * projectionScale.X + esp.offset.X, maxy * projectionScale.Y + esp.offset.Y
    local width, height = maxx - minx, maxy - miny
    if width < 1 or height < 2 then
        return nil
    end

    if width > height * 1.8 then
        minx = (minx + maxx) * 0.5 - height * 0.9
        width = height * 1.8
    end

    return Vector2.new(math.floor(minx - 2), math.floor(miny - 2)),
        Vector2.new(math.ceil(width + 4), math.ceil(height + 4))
end

local getbox = function(camera, target, model, root, head, body)
    local pos, size = call("get_box", target, model, camera)
    if
        typeof(pos) == "Vector2"
        and typeof(size) == "Vector2"
        and finite(pos.X)
        and finite(pos.Y)
        and finite(size.X)
        and finite(size.Y)
        and size.X > 0
        and size.Y > 0
    then
        -- Custom boxes already use Drawing coordinates (e.g. Phantom Forces).
        return pos, size
    end

    if esp.custom.box_mode == "Root" then
        local origin = root.Position
        local top = project(
            camera,
            head and head.Position + Vector3.new(0, head.Size.Y * 0.65, 0) or origin + Vector3.new(0, 2.6, 0)
        )
        local bottom = project(camera, origin - Vector3.new(0, 3, 0))
        if top and bottom then
            local height = math.abs(bottom.Y - top.Y)
            if height >= 2 then
                local width = height * 0.48
                return Vector2.new((top.X + bottom.X - width) * 0.5, math.min(top.Y, bottom.Y)),
                    Vector2.new(width, height)
            end
        end
    end

    return bodybox(camera, body)
end

local groupof = function(o, name)
    local group = o.groups[name]
    if group then
        return group
    end
    group = { visible = false }
    o.groups[name] = group
    if name == "box" then
        local back = square(group, false, 3, palette.outline)
        local guide = square(group, false, 1, palette.primary)
        set(back, "Transparency", 0.2)
        set(guide, "Transparency", 0.25)

        for _ = 1, #box_segments do
            line(group, 3, palette.outline, 0.85)
            line(group, 1, palette.primary)
        end
    elseif name == "arrow" then
        group.outline = newdrawing(group, "Triangle", {
            Filled = false,
            Thickness = 2,
            Color = palette.outline,
            Transparency = 1,
            ZIndex = 3,
        })
        group.fill = newdrawing(group, "Triangle", {
            Filled = true,
            Thickness = 1,
            Color = palette.primary,
            Transparency = 1,
            ZIndex = 4,
        })
        group.label = text(group, 11, palette.text)
    elseif name == "trace" then
        line(group, 3, palette.outline, 0.7)
        line(group, 1, palette.primary, 0.85)
    elseif name == "health" then
        square(group, true, 1, palette.outline)
        square(group, true, 1, palette.health)
    elseif name == "name" or name == "info" then
        group.background = square(group, true, 1, palette.outline)
        set(group.background, "Transparency", 0.72)
        set(group.background, "ZIndex", 3)
        group.label = text(group, name == "name" and 12 or 11, palette.text)
    elseif name == "head" then
        newdrawing(group, "Circle", {
            Radius = 2.5,
            NumSides = 12,
            Filled = true,
            Color = palette.outline,
            Transparency = 0.9,
        })

        newdrawing(group, "Circle", {
            Radius = 1.25,
            NumSides = 12,
            Filled = true,
            Color = palette.primary,
            Transparency = 1,
        })
    end

    return group
end

local drawbox = function(o, pos, size, color)
    local group = groupof(o, "box")
    local horizontal = math.min(size.X * 0.22, 16)
    local vertical = math.min(size.Y * 0.12, 20)

    for i = 1, 2 do
        set(group[i], "Position", pos)
        set(group[i], "Size", size)
    end

    set(group[2], "Color", color)

    for i, segment in ipairs(box_segments) do
        local anchor = pos + Vector2.new(size.X * segment[1], size.Y * segment[2])
        local endpoint = anchor + Vector2.new(horizontal * segment[3], vertical * segment[4])
        local back, core = group[i * 2 + 1], group[i * 2 + 2]

        set(back, "From", anchor)
        set(back, "To", endpoint)
        set(core, "From", anchor)
        set(core, "To", endpoint)
        set(core, "Color", color)
    end

    show(group, true)
end

local drawtrace = function(o, from, to)
    local group = groupof(o, "trace")
    for _, drawing in ipairs(group) do
        set(drawing, "From", from)
        set(drawing, "To", to)
    end

    show(group, true)
end

local drawtext = function(o, name, label, position)
    local group = groupof(o, name)
    local drawing = group.label
    set(drawing, "Text", label)
    set(drawing, "Position", position)

    local bounds = drawing.object.TextBounds
    if typeof(bounds) ~= "Vector2" or bounds.X <= 0 or bounds.Y <= 0 then
        bounds = Vector2.new((utf8.len(label) or #label) * drawing.state.Size * 0.6, drawing.state.Size)
    end

    set(group.background, "Position", Vector2.new(position.X - bounds.X * 0.5 - 4, position.Y - 2))
    set(group.background, "Size", Vector2.new(bounds.X + 8, bounds.Y + 4))
    show(group, true)
end

local drawarrow = function(o, camera, position, distance, color)
    local look = camera.CFrame.LookVector
    local forward = Vector2.new(look.X, look.Z)
    if forward.Magnitude < 0.001 then
        local right = camera.CFrame.RightVector
        forward = Vector2.new(right.Z, -right.X)
    end
    if forward.Magnitude < 0.001 then
        return false
    end

    forward = forward.Unit
    local delta = position - camera.CFrame.Position
    local direction = Vector2.new(
        delta.X * -forward.Y + delta.Z * forward.X,
        -(delta.X * forward.X + delta.Z * forward.Y)
    )
    if not finite(direction.X) or not finite(direction.Y) then
        return false
    end

    -- A target directly above/below has no horizontal bearing.
    direction = direction.Magnitude > 0.001 and direction.Unit or Vector2.new(0, -1)
    local viewport = Vector2.new(drawingSize.X * projectionScale.X, drawingSize.Y * projectionScale.Y)
    local shortest = math.min(viewport.X, viewport.Y)
    if shortest < 120 then
        return false
    end

    local scale = math.min(projectionScale.X, projectionScale.Y)
    local size = math.clamp(finite(esp.arrowsize) and esp.arrowsize or 10, 4, 24) * scale
    local radius = math.min(
        math.clamp(finite(esp.arrowradius) and esp.arrowradius or 180, 40, 600) * scale,
        shortest * 0.5 - size * 2 - 28
    )
    if radius <= size * 2 then
        return false
    end

    local center = viewport * 0.5 + esp.offset
    local tip = center + direction * radius
    local base = tip - direction * size * 1.4
    local side = Vector2.new(-direction.Y, direction.X) * size * 0.9
    local group = groupof(o, "arrow")

    for i = 1, 2 do
        local drawing = group[i]
        set(drawing, "PointA", tip)
        set(drawing, "PointB", base + side)
        set(drawing, "PointC", base - side)
    end
    set(group.fill, "Color", color)
    set(group.label, "Text", string.format("%dm", math.floor(distance * studs_to_meters + 0.5)))

    local bounds = group.label.object.TextBounds
    if typeof(bounds) ~= "Vector2" or bounds.X <= 0 or bounds.Y <= 0 then
        bounds = Vector2.new(#group.label.state.Text * 6.6, 11)
    end
    local gap = math.abs(direction.X) * (bounds.X * 0.5 + 8) + math.abs(direction.Y) * (bounds.Y * 0.5 + 8)
    set(group.label, "Position", base - direction * gap - Vector2.new(0, bounds.Y * 0.5))
    show(group, true)
    return true
end

local drawhealth = function(o, pos, size, health, maximum)
    local group = groupof(o, "health")
    local ratio = math.clamp(health / math.max(maximum, 1), 0, 1)
    local height = math.max(1, math.floor(size.Y))
    local filled = math.max(1, math.floor(height * ratio + 0.5))
    local x, y = math.floor(pos.X - 5), math.floor(pos.Y)

    set(group[1], "Position", Vector2.new(x - 1, y - 1))
    set(group[1], "Size", Vector2.new(4, height + 2))
    set(group[2], "Position", Vector2.new(x, y + height - filled))
    set(group[2], "Size", Vector2.new(2, filled))
    set(group[2], "Color", palette.low:Lerp(palette.health, ratio))

    show(group, true)
    set(group[2], "Visible", ratio > 0)
end

local build_skeleton = function(body)
    local nodes, motors = {}, {}

    for _, part in body.named do
        for _, child in part:GetChildren() do
            if child:IsA("Motor6D") and child.Part1 then
                motors[child.Part1] = child
            end
        end
    end

    for _, joint in (body.r15 and r15joints or r6joints) do
        local parent, part = body.named[joint[2]], body.named[joint[3]]
        if parent and part then
            local attachment = part:FindFirstChild(joint[4])
            if not attachment or not attachment:IsA("Attachment") then
                attachment = parent:FindFirstChild(joint[4])
            end

            if attachment and not attachment:IsA("Attachment") then
                attachment = nil
            end

            local motor = motors[part]
            if motor and motor.Part0 ~= parent then
                motor = nil
            end

            nodes[joint[1]] = {
                part = part,
                parent = parent,
                attachment = attachment,
                motor = motor,
                offset = Vector3.new(joint[5], joint[6], joint[7]),
            }
        end
    end

    local add_tip = function(name, partname, x, y, z)
        local part = body.named[partname]
        if part then
            nodes[name] = { part = part, offset = Vector3.new(x, y, z) }
        end
    end

    add_tip("head", "Head", 0, 0, 0)
    add_tip("left_hand", body.r15 and "LeftHand" or "Left Arm", 0, -0.5, 0)
    add_tip("right_hand", body.r15 and "RightHand" or "Right Arm", 0, -0.5, 0)
    add_tip("left_foot", body.r15 and "LeftFoot" or "Left Leg", 0, body.r15 and 0 or -0.5, body.r15 and -0.5 or 0)
    add_tip("right_foot", body.r15 and "RightFoot" or "Right Leg", 0, body.r15 and 0 or -0.5, body.r15 and -0.5 or 0)

    local torso = body.named.UpperTorso or body.named.Torso
    if torso then
        nodes.chest = {
            part = torso,
            offset = Vector3.new(0, 0.25, 0),
            a = nodes.left_shoulder,
            b = nodes.right_shoulder,
        }
    end

    body.head = nodes.head
    body.bones = {}
    for _, pair in (body.r15 and r15bones or r6bones) do
        local a, b = nodes[pair[1]], nodes[pair[2]]
        if a and b then
            body.bones[#body.bones + 1] = { a, b }
        end
    end
end

local joint_world = function(node)
    if node.attachment and node.attachment.Parent then
        return node.attachment.WorldPosition
    end

    if node.motor and node.motor.Parent and node.motor.Part1 == node.part and node.motor.Part0 == node.parent then
        -- The child-side joint follows the rendered pose, including animation.
        return node.part.CFrame:PointToWorldSpace(node.motor.C1.Position)
    end

    local size, offset = node.part.Size, node.offset
    return node.part.CFrame:PointToWorldSpace(Vector3.new(size.X * offset.X, size.Y * offset.Y, size.Z * offset.Z))
end

local node_world = function(node, points)
    if points[node] then
        return points[node]
    end

    local position
    if node.a and node.b then
        local a = points[node.a] or joint_world(node.a)
        local b = points[node.b] or joint_world(node.b)
        points[node.a], points[node.b] = a, b
        position = (a + b) * 0.5
    else
        position = joint_world(node)
    end

    points[node] = position
    return position
end

local jointpoint = function(camera, body, node)
    if body.points[node] == nil then
        body.points[node] = project(camera, node_world(node, body.worldpoints)) or false
    end

    return body.points[node]
end

local drawskeleton = function(o, camera, body, color)
    if not body.bones then
        build_skeleton(body)
    end

    local group = groupof(o, "skeleton")
    group.visible = true
    table.clear(body.points)
    table.clear(body.worldpoints)

    for i, pair in body.bones do
        local back, core = group[i * 2 - 1], group[i * 2]
        if not back then
            back = line(group, 2, palette.outline, 0.55)
            core = line(group, 1, color, 0.95)
        end

        local a, b = jointpoint(camera, body, pair[1]), jointpoint(camera, body, pair[2])
        if a and b then
            set(back, "From", a)
            set(back, "To", b)
            set(core, "From", a)
            set(core, "To", b)
            set(core, "Color", color)
        end

        set(back, "Visible", a ~= false and b ~= false)
        set(core, "Visible", a ~= false and b ~= false)
    end

    for i = #body.bones * 2 + 1, #group do
        set(group[i], "Visible", false)
    end

    local head = body.head and jointpoint(camera, body, body.head)
    if head then
        local marker = groupof(o, "head")
        set(marker[1], "Position", head)
        set(marker[2], "Position", head)
        set(marker[2], "Color", color)
        show(marker, true)
    else
        show(o.groups.head, false)
    end
end

local drawglow = function(o, enabled, color)
    if not enabled then
        if o.highlight then
            o.highlight.Enabled = false
        end

        return
    end

    if not o.highlight then
        local highlight = Instance.new("Highlight")
        highlight.Enabled = false
        highlight.Name = "SixlyGlow_" .. o.target.Name
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = 0.82
        highlight.OutlineTransparency = 0.15
        highlight.Adornee = o.model
        highlight.Parent = highlights
        o.highlight = highlight
    end

    local highlight = o.highlight
    if highlight.FillColor ~= color then
        highlight.FillColor = color
        highlight.OutlineColor = color
    end

    if not highlight.Enabled then
        highlight.Enabled = true
    end
end

local update = function(target, o, camera, origin)
    local model = characterof(target, o.isplayer)
    if typeof(model) ~= "Instance" or not model:IsA("Model") or not model.Parent then
        hide(o)
        if o.model then
            unbindmodel(o)
        end

        return
    end

    local body = bodyof(o, model)
    local humanoid = body.humanoid
    local health, maximum = call("get_health", target, model, humanoid)
    if not finite(health) then
        health, maximum = humanoid and humanoid.Health or 100, humanoid and humanoid.MaxHealth or 100
    end

    if not finite(maximum) then
        maximum = 100
    end

    local alive = call("is_alive", target, model, humanoid)
    if type(alive) ~= "boolean" then
        alive = humanoid == nil or health > 0
    end

    local root = rootof(target, model, body)
    if not alive or not root or not root:IsA("BasePart") then
        hide(o)
        return
    end

    local teammate = call("is_teammate", target, model)
    if type(teammate) ~= "boolean" then
        teammate = o.isplayer
                and target.Team ~= nil
                and target.Team == localplayer.Team
                and not target.Neutral
                and not localplayer.Neutral
            or false
    end

    if esp.teamcheck and teammate then
        hide(o)
        return
    end

    local distance = (root.Position - origin).Magnitude
    if esp.maxdistance > 0 and distance > esp.maxdistance then
        hide(o)
        return
    end

    local methods = esp.methods
    local color = teammate and palette.ally or palette.primary
    local root2d, visible = project(camera, root.Position)
    if not root2d or not visible then
        if methods.Arrow == true then
            if not o.offscreen then
                hide(o)
            end
            if drawarrow(o, camera, root.Position, distance, color) then
                o.visible, o.offscreen = true, true
            else
                hide(o)
            end
        else
            hide(o)
        end
        return
    end

    if o.offscreen then
        show(o.groups.arrow, false)
        o.offscreen = false
    end
    local box = methods.Box == true
    local name = methods.Name == true
    local healthbar = methods.Health == true
    local distanceinfo = methods.Distance == true
    local weaponinfo = methods.Weapon == true
    local trace = methods.Trace == true or methods.Line == true
    local head, head2d = body.named.Head, nil
    if head and (name or (trace and esp.tracertarget == "Head")) then
        head2d = project(camera, head.Position + Vector3.new(0, head.Size.Y * 0.7 + 0.12, 0))
    end

    local pos, size
    if box
        or (name and not head2d)
        or healthbar
        or distanceinfo
        or weaponinfo
        or (trace and esp.tracertarget == "Feet")
    then
        pos, size = getbox(camera, target, model, root, head, body)
    end

    o.visible = true
    drawglow(o, methods.Glow == true, color)
    if box and pos then
        drawbox(o, pos, size, color)
    else
        show(o.groups.box, false)
    end

    if trace then
        local from = Vector2.new(
            drawingSize.X * 0.5 * projectionScale.X + esp.offset.X,
            esp.tracerorigin == "Bottom" and drawingSize.Y * projectionScale.Y + esp.offset.Y or esp.offset.Y
        )
        local to = root2d
        if esp.tracertarget == "Head" then
            to = head2d or root2d
        elseif esp.tracertarget == "Feet" and pos then
            to = Vector2.new(pos.X + size.X * 0.5, pos.Y + size.Y)
        end

        drawtrace(o, from, to)
    else
        show(o.groups.trace, false)
    end

    if name and (head2d or pos) then
        local label = call("get_name", target, model)
        local x = pos and pos.X + size.X * 0.5 or head2d.X
        local y = math.min(head2d and head2d.Y or pos.Y, pos and pos.Y or head2d.Y) - 18
        drawtext(o, "name", type(label) == "string" and label or target.Name, Vector2.new(x, y))
    else
        show(o.groups.name, false)
    end

    if healthbar and pos then
        drawhealth(o, pos, size, health, maximum)
    else
        show(o.groups.health, false)
    end

    if (distanceinfo or weaponinfo) and pos then
        local label = get_info_text(target, model, body, methods, distance, origin)
        if label then
            drawtext(o, "info", label, Vector2.new(pos.X + size.X * 0.5, pos.Y + size.Y + 5))
        else
            show(o.groups.info, false)
        end
    else
        show(o.groups.info, false)
    end

    if methods.Skeleton == true then
        drawskeleton(o, camera, body, color)
    else
        show(o.groups.skeleton, false)
        show(o.groups.head, false)
    end
end

esp.fov = {
    enabled = false,
    marker = true,
    line = true,
    radius = 150,
    thickness = 1,
    color = Color3.fromRGB(250, 250, 255),
    accent = palette.primary,
    animation = "Both",
    speed = 0.65,
    teamcheck = true,
    wallcheck = true,
    method = "Head",
}

local fov = esp.fov
local fov_ring = { visible = false }
local fov_marker = { visible = false }
local fov_trace = { visible = false }
local fov_outer, fov_inner = {}, {}
local fov_outer_backs = {}
local fov_sources = {}
local fov_priority = {"SilentAim", "Aimbot", "Default"}
local fov_phase = 0
local fov_rotation = 0
local fov_auto_target
local fov_next_scan = 0
local fov_last_target
local fov_marker_position
local fov_last_visibility_check = -math.huge

for i = 1, 36 do
    fov_outer_backs[i] = line(fov_ring, 3.5, palette.outline, 0.55)
    fov_outer[i] = line(fov_ring, 1.8, fov.color, 1)
    set(fov_outer_backs[i], "ZIndex", 5)
    set(fov_outer[i], "ZIndex", 6)
end

for i = 1, 18 do
    fov_inner[i] = line(fov_ring, 1, fov.accent, 0.62)
    set(fov_inner[i], "ZIndex", 6)
end

local fov_backdrop = Color3.fromRGB(10, 8, 19)

local fov_dot_back = newdrawing(fov_marker, "Circle", {
    Filled = true,
    Radius = 6,
    NumSides = 24,
    Color = fov_backdrop,
    Transparency = 1,
    ZIndex = 17,
})

local fov_dot_mid = newdrawing(fov_marker, "Circle", {
    Filled = true,
    Radius = 4.2,
    NumSides = 24,
    Color = fov.accent,
    Transparency = 1,
    ZIndex = 18,
})

local fov_dot = newdrawing(fov_marker, "Circle", {
    Filled = true,
    Radius = 2.3,
    NumSides = 24,
    Color = fov.color,
    Transparency = 1,
    ZIndex = 19,
})

local fov_focus_back = newdrawing(fov_marker, "Circle", {
    Filled = false,
    Radius = 18,
    NumSides = 48,
    Thickness = 5.2,
    Color = fov_backdrop,
    Transparency = 0.96,
    ZIndex = 12,
})

local fov_focus = newdrawing(fov_marker, "Circle", {
    Filled = false,
    Radius = 18,
    NumSides = 48,
    Thickness = 2.8,
    Color = fov.color,
    Transparency = 1,
    ZIndex = 15,
})

local fov_focus_outer = newdrawing(fov_marker, "Circle", {
    Filled = false,
    Radius = 23,
    NumSides = 48,
    Thickness = 1.7,
    Color = fov.accent,
    Transparency = 0.98,
    ZIndex = 14,
})

local fov_trace_back = line(fov_trace, 9, fov_backdrop, 0.97)
local fov_trace_middle = line(fov_trace, 5.5, fov.accent, 1)
local fov_trace_front = line(fov_trace, 2.8, fov.color, 1)
set(fov_trace_back, "ZIndex", 9)
set(fov_trace_middle, "ZIndex", 10)
set(fov_trace_front, "ZIndex", 11)
local hide_fov = function()
    show(fov_ring, false)
    show(fov_marker, false)
    show(fov_trace, false)
    fov_last_target = nil
    fov_marker_position = nil
end

local get_fov_part = function(character, method)
    if method == "Head" then
        return character:FindFirstChild("Head")
            or character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("HumanoidRootPart")
    end

    return character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("HumanoidRootPart")
end

local fov_screen_position = function(camera, part)
    if typeof(part) ~= "Instance" or not part:IsA("BasePart")
        or not part:IsDescendantOf(workspace) then return nil end

    local character = part.Parent
    if not character or character == localplayer.Character then return nil end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end

    local screen, visible = camera:WorldToViewportPoint(part.Position)
    if not visible or screen.Z <= 0 then return nil end

    local center = camera.ViewportSize * 0.5
    local distance = (Vector2.new(screen.X, screen.Y) - center).Magnitude
    if distance > fov.radius then return nil end

    return Vector2.new(
        screen.X * projectionScale.X + esp.offset.X,
        screen.Y * projectionScale.Y + esp.offset.Y
    )
end

local fov_can_hit = function(origin, part, character)
    local direction = part.Position - origin
    if direction.Magnitude <= 0.01 then return false end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true

    local filter = {}
    if localplayer.Character then filter[#filter + 1] = localplayer.Character end
    if workspace.CurrentCamera then filter[#filter + 1] = workspace.CurrentCamera end
    params.FilterDescendantsInstances = filter

    local result = workspace:Raycast(origin, direction, params)
    return not result or result.Instance:IsDescendantOf(character)
end

local find_fov_target = function(camera, method, teamcheck, wallcheck, range)
    local center = camera.ViewportSize * 0.5
    local origin = camera.CFrame.Position
    local nearest = math.huge
    local selected

    for _, player in players:GetPlayers() do
        if player == localplayer then continue end
        if teamcheck and localplayer.Team and player.Team == localplayer.Team then continue end

        local character = player.Character
        if not character then continue end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        local part = get_fov_part(character, method)
        if not part or not part:IsA("BasePart") then continue end

        local distance3d = (part.Position - origin).Magnitude
        if distance3d <= 0.01 or distance3d > range then continue end

        local screen, visible = camera:WorldToViewportPoint(part.Position)
        if not visible or screen.Z <= 0 then continue end

        local distance = (Vector2.new(screen.X, screen.Y) - center).Magnitude
        if distance > fov.radius or distance >= nearest then continue end
        if wallcheck and not fov_can_hit(origin, part, character) then continue end

        nearest = distance
        selected = part
    end

    return selected
end

local get_fov_selected = function(camera)
    local now = os.clock()

    for _, name in fov_priority do
        local source = fov_sources[name]
        if source then
            if now <= source.expires and fov_screen_position(camera, source.part) then
                return source.part
            elseif now > source.expires then
                fov_sources[name] = nil
            end
        end
    end

    if now >= fov_next_scan then
        fov_next_scan = now + 0.065
        fov_auto_target = find_fov_target(camera, fov.method, fov.teamcheck, fov.wallcheck, math.huge)
    end

    if fov_auto_target and fov_screen_position(camera, fov_auto_target) then
        return fov_auto_target
    end

    return nil
end

local update_fov_ring = function(camera, radius, angle, acquired)
    local center = Vector2.new(
        camera.ViewportSize.X * 0.5 * projectionScale.X + esp.offset.X,
        camera.ViewportSize.Y * 0.5 * projectionScale.Y + esp.offset.Y
    )

    local draw_arc = function(drawing, a, b, r, color, alpha, thickness)
        set(drawing, "From", center + Vector2.new(
            math.cos(a) * r * projectionScale.X,
            math.sin(a) * r * projectionScale.Y
        ))
        set(drawing, "To", center + Vector2.new(
            math.cos(b) * r * projectionScale.X,
            math.sin(b) * r * projectionScale.Y
        ))
        set(drawing, "Thickness", thickness)
        set(drawing, "Color", color)
        set(drawing, "Transparency", alpha)
    end

    local step = math.pi * 2 / #fov_outer
    for i, drawing in fov_outer do
        local a = (i - 1) * step + angle
        local b = a + step * 0.57
        local color = i % 3 == 0 and fov.accent or fov.color
        draw_arc(fov_outer_backs[i], a, b, radius, palette.outline, 0.62, fov.thickness + 2.1)
        draw_arc(drawing, a, b, radius, color, acquired and 1 or 0.93, fov.thickness + 0.6)
    end

    local inner_step = math.pi * 2 / #fov_inner
    for i, drawing in fov_inner do
        local a = (i - 1) * inner_step - angle * 0.45
        draw_arc(drawing, a, a + inner_step * 0.36, math.max(1, radius - 4),
            i % 2 == 0 and fov.color or fov.accent, 0.75, math.max(1, fov.thickness * 0.85))
    end

    show(fov_ring, true)
end

local update_fov_marker = function(camera, part, dt, phase)
    local position = fov_screen_position(camera, part)
    if not position then
        show(fov_marker, false)
        fov_last_target = nil
        fov_marker_position = nil
        return nil
    end

    if part ~= fov_last_target then
        fov_marker_position = position
        fov_last_target = part
    else
        local alpha = 1 - math.exp(-22 * math.clamp(dt or 1 / 60, 0, 0.1))
        fov_marker_position = fov_marker_position:Lerp(position, alpha)
    end

    local center = fov_marker_position
    local pulse = fov.animation == "Pulse" or fov.animation == "Both"
    local size = 16 + (pulse and math.sin(phase * 3) * 1.1 or 0)
    set(fov_dot_back, "Position", center)
    set(fov_dot_mid, "Position", center)
    set(fov_dot_mid, "Color", fov.accent)
    set(fov_dot, "Position", center)
    set(fov_dot, "Color", fov.color)
    set(fov_focus_back, "Position", center)
    set(fov_focus_back, "Radius", size + 3)
    set(fov_focus, "Position", center)
    set(fov_focus, "Radius", size + 3)
    set(fov_focus, "Color", fov.color)
    set(fov_focus_outer, "Position", center)
    set(fov_focus_outer, "Radius", size + 8)
    set(fov_focus_outer, "Color", fov.accent)

    show(fov_marker, true)
    return center
end

local update_fov_trace = function(camera, position, phase)
    if not fov.line or not position then
        show(fov_trace, false)
        return
    end

    local origin = Vector2.new(
        camera.ViewportSize.X * 0.5 * projectionScale.X + esp.offset.X,
        camera.ViewportSize.Y * 0.5 * projectionScale.Y + esp.offset.Y
    )
    local delta = position - origin
    local distance = delta.Magnitude
    if distance <= 32 then
        show(fov_trace, false)
        return
    end

    local direction = delta / distance
    local from = origin + direction * 11
    local to = position - direction * 22
    set(fov_trace_back, "From", from)
    set(fov_trace_back, "To", to)
    set(fov_trace_middle, "From", from)
    set(fov_trace_middle, "To", to)
    set(fov_trace_middle, "Color", fov.accent)
    set(fov_trace_front, "From", from)
    set(fov_trace_front, "To", to)
    set(fov_trace_front, "Color", fov.color)
    show(fov_trace, true)
end

local refresh_fov_drawings = function()
    local now = os.clock()
    if now - fov_last_visibility_check < 0.7 then return end
    fov_last_visibility_check = now

    for _, group in {fov_ring, fov_marker, fov_trace} do
        if not group.visible then continue end
        for _, drawing in group do
            local ok, visible = pcall(function()
                return drawing.object.Visible
            end)
            if not ok then
                local state = drawing.state
                local created, object = pcall(Drawing.new, drawing.kind)
                if created then
                    drawing.object = object
                    drawing.state = {}
                    for key, value in state do
                        set(drawing, key, value)
                    end
                end
            elseif not visible then
                drawing.state.Visible = false
                set(drawing, "Visible", true)
            end
        end
    end
end

local update_fov = function(camera, dt)
    if not fov.enabled then
        hide_fov()
        return
    end

    dt = math.clamp(type(dt) == "number" and dt or 1 / 60, 0, 0.1)
    local speed = fov.speed
    fov_phase = (fov_phase + dt * speed) % (math.pi * 2)
    fov_rotation = (fov_rotation + dt * speed * 0.32) % (math.pi * 2)

    local rotate = fov.animation == "Rotate" or fov.animation == "Both"
    local pulse = fov.animation == "Pulse" or fov.animation == "Both"
    local angle = rotate and fov_rotation or 0
    local radius = fov.radius + (pulse and math.sin(fov_phase * 3) * 1.8 or 0)

    refresh_fov_drawings()
    update_fov_ring(camera, radius, angle, false)

    if not fov.marker then
        show(fov_marker, false)
        show(fov_trace, false)
        refresh_fov_drawings()
        return
    end

    local ok, target = pcall(get_fov_selected, camera)
    if not ok then
        fov_auto_target = nil
        fov_next_scan = 0
        report("fov_target", target)
        target = nil
    end

    if target then
        local success, position = pcall(update_fov_marker, camera, target, dt, fov_phase)
        if success then
            local line_ok, line_error = pcall(update_fov_trace, camera, position, fov_phase)
            if not line_ok then
                show(fov_trace, false)
                report("fov_line", line_error)
            end
        else
            show(fov_marker, false)
            show(fov_trace, false)
            fov_last_target = nil
            fov_marker_position = nil
            report("fov_marker", position)
        end
    else
        show(fov_marker, false)
        show(fov_trace, false)
        fov_last_target = nil
        fov_marker_position = nil
    end

    refresh_fov_drawings()
end

local destroy_fov = function()
    for _, group in {fov_ring, fov_marker, fov_trace} do
        for _, drawing in group do
            pcall(function()
                drawing.object:Remove()
            end)
        end
    end
    table.clear(fov_sources)
end


esp.set_fov_enabled = function(self, value)
    if closed then return end
    self.fov.enabled = value == true
    if not self.fov.enabled then hide_fov() end
end

esp.set_fov_radius = function(self, value)
    value = tonumber(value)
    if finite(value) then self.fov.radius = math.clamp(value, 1, 1000) end
end

esp.set_fov_thickness = function(self, value)
    value = tonumber(value)
    if finite(value) then self.fov.thickness = math.clamp(value, 1, 10) end
end

esp.set_fov_animation = function(self, value)
    if type(value) == "boolean" then
        self.fov.animation = value and "Both" or "None"
    elseif value == "Both" or value == "Rotate" or value == "Pulse" or value == "None" then
        self.fov.animation = value
    end
end

esp.set_fov_speed = function(self, value)
    value = tonumber(value)
    if finite(value) then self.fov.speed = math.clamp(value, 0, 5) end
end

esp.set_fov_color = function(self, value)
    if typeof(value) == "Color3" then self.fov.color = value end
end

esp.set_fov_accent = function(self, value)
    if typeof(value) == "Color3" then self.fov.accent = value end
end

esp.set_fov_marker = function(self, value)
    self.fov.marker = value == true
    if not self.fov.marker then
        show(fov_marker, false)
        show(fov_trace, false)
    end
end

esp.set_fov_line = function(self, value)
    self.fov.line = value == true
    if not self.fov.line then show(fov_trace, false) end
end

esp.set_fov_teamcheck = function(self, value)
    self.fov.teamcheck = value == true
    fov_next_scan = 0
end

esp.set_fov_wallcheck = function(self, value)
    self.fov.wallcheck = value == true
    fov_next_scan = 0
end

esp.set_fov_method = function(self, value)
    self.fov.method = value == "Torso" and "Torso" or "Head"
    fov_next_scan = 0
end

esp.get_fov_target = function(self, method, teamcheck, wallcheck, range)
    local camera = workspace.CurrentCamera
    if closed or not camera then return nil end
    return find_fov_target(camera,
        method == "Torso" and "Torso" or "Head",
        teamcheck ~= false,
        wallcheck ~= false,
        tonumber(range) or math.huge
    )
end

esp.set_fov_target = function(self, part, source, duration)
    if closed then return end
    source = (source == "SilentAim" or source == "Aimbot") and source or "Default"
    if part == nil then
        fov_sources[source] = nil
        return
    end
    if typeof(part) ~= "Instance" or not part:IsA("BasePart") then return end

    duration = tonumber(duration)
    if not finite(duration) then duration = 0.25 end
    fov_sources[source] = {
        part = part,
        expires = os.clock() + math.clamp(duration, 0.02, 3),
    }
end

esp.clear_fov_target = function(self, source)
    if type(source) == "string" then
        fov_sources[source] = nil
    else
        table.clear(fov_sources)
    end
end

esp.get_fov_radius = function(self)
    return self.fov.radius
end

-- Public API: keep existing callers, custom adapters and FOV projection consumers.
esp.set_enabled = function(self, value)
    if closed then
        return
    end
    self.enabled = value == true
    if not self.enabled then
        for _, o in cache do
            hide(o)
        end
    end
end

esp.set_methods = function(self, value)
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
    for _, o in cache do
        hide(o)
    end
end

esp.set_custom = function(self, data)
    self.custom = type(data) == "table" and data or {}
    table.clear(warnings)
    self:refresh()
end

esp.set_teamcheck = function(self, value)
    self.teamcheck = value == true
end

esp.set_trace_origin = function(self, value)
    self.tracerorigin = value == "Bottom" and "Bottom" or "Top"
end

esp.set_trace_target = function(self, value)
    self.tracertarget = (value == "Head" or value == "Feet") and value or "Root"
end

esp.set_maxdistance = function(self, value)
    value = tonumber(value)
    self.maxdistance = finite(value) and math.max(0, value) or 0
end

esp.set_offset = function(self, value)
    if typeof(value) == "Vector2" and finite(value.X) and finite(value.Y) then
        self.offset, self.drawing.offset = value, value
    end
end

esp.set_projection_mode = function(self, value)
    self.projectionmode = "Viewport"
end

esp.set_auto_scale = function(self, value)
    self.drawing.autoscale = value == true
    self.autoscale = self.drawing.autoscale
end

esp.set_projection_scale = function(self, value)
    if typeof(value) == "Vector2" and finite(value.X) and finite(value.Y) and value.X > 0 and value.Y > 0 then
        self.drawing.multiplier = value
    end
end

esp.get_projection_info = function(self)
    local camera = workspace.CurrentCamera
    return {
        cameraViewport = camera and camera.ViewportSize,
        mode = "Viewport (dynamic GUI ratio)",
        scale = self.drawing.multiplier,
        effectiveScale = projectionScale,
        guiSize = frame.AbsoluteSize,
        guiToViewportRatio = currentRatio,
        autoscale = self.autoscale,
        offset = self.offset,
    }
end

esp.clear_calibration = function(self)
    self.drawing.multiplier, self.drawing.autoscale, self.drawing.scale, self.drawing.offset =
        unit, true, unit, Vector2.zero
    self.offset, self.autoscale, self.scale = Vector2.zero, true, unit
    projectionScale = unit
end

esp.calibrate = function(self)
    self:clear_calibration()
end

esp.add_model = function(self, model)
    if typeof(model) == "Instance" and model:IsA("Model") then
        create(model, false)
    end
end

esp.remove_model = function(self, model)
    remove(model)
end

esp.watch_npcs = function(self, folder)
    if closed or typeof(folder) ~= "Instance" or watched[folder] then
        return
    end

    local list = {}
    watched[folder] = list
    local added = function(item)
        if item:IsA("Humanoid") and item.Parent and item.Parent:IsA("Model") then
            self:add_model(item.Parent)
        end
    end
    list[1] = folder.DescendantAdded:Connect(added)
    list[2] = folder.DescendantRemoving:Connect(function(item)
        if item:IsA("Model") then
            remove(item)
        elseif item:IsA("Humanoid") and item.Parent then
            remove(item.Parent)
        end
    end)
    list[3] = folder.Destroying:Connect(function()
        disconnect(list)
        watched[folder] = nil
    end)
    for _, item in folder:GetDescendants() do
        added(item)
    end
end

esp.refresh = function(self)
    if closed then
        return
    end

    for _, o in cache do
        hide(o)
        unbindmodel(o)
    end
end

esp.destroy = function(self)
    if closed then
        return
    end
    closed, self.enabled = true, false
    runservice:UnbindFromRenderStep(rendername)
    disconnect(connections)
    for _, list in watched do
        disconnect(list)
    end

    table.clear(watched)
    for target in cache do
        remove(target)
    end

    destroy_fov()
    highlights:Destroy()
    gui:Destroy()
    if env.sixly_esp_drawing == self then
        env.sixly_esp_drawing = nil
    end
end

connections[1] = players.PlayerAdded:Connect(function(player)
    create(player, true)
end)
connections[2] = players.PlayerRemoving:Connect(remove)
for _, player in players:GetPlayers() do
    create(player, true)
end

runservice:BindToRenderStep(rendername, Enum.RenderPriority.Camera.Value + 1, function(dt)
    if closed then
        return
    end

    local camera = workspace.CurrentCamera
    -- Projection is also shared by FOV circles while ESP is disabled.
    if camera then
        projection(camera)
        local ok, message = pcall(update_fov, camera, dt)
        if not ok then
            report("fov", message)
        end
    else
        hide_fov()
    end

    if not esp.enabled then
        return
    end

    local methods = esp.methods
    if
        not camera
        or not (
            methods.Glow
            or methods.Box
            or methods.Skeleton
            or methods.Trace
            or methods.Line
            or methods.Name
            or methods.Health
            or methods.Distance
            or methods.Weapon
            or methods.Arrow
        )
    then
        for _, o in cache do
            hide(o)
        end

        return
    end

    local origin = get_distance_origin(camera)

    for target, o in cache do
        local ok, message = pcall(update, target, o, camera, origin)
        if not ok then
            hide(o)
            report("render", message)
        end
    end
end)
env.sixly_esp_drawing = esp
return esp
