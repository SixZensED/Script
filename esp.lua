-- Sixly ESP v4: standalone module, compatible with the v3 public API.
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

local get_info_text = function(target, model, body, methods, distance, localroot)
    local label
    if methods.Distance == true and localroot then
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

local update = function(target, o, camera, localroot)
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

    local distance = localroot and (root.Position - localroot.Position).Magnitude or 0
    if esp.maxdistance > 0 and localroot and distance > esp.maxdistance then
        hide(o)
        return
    end

    local root2d, visible = project(camera, root.Position)
    if not root2d or not visible then
        hide(o)
        return
    end

    local methods = esp.methods
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
    local color = teammate and palette.ally or palette.primary
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
        local label = get_info_text(target, model, body, methods, distance, localroot)
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

runservice:BindToRenderStep(rendername, Enum.RenderPriority.Camera.Value + 1, function()
    if closed then
        return
    end

    local camera = workspace.CurrentCamera
    -- Projection is also shared by FOV circles while ESP is disabled.
    if camera then
        projection(camera)
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
        )
    then
        for _, o in cache do
            hide(o)
        end

        return
    end

    local localcharacter = characterof(localplayer, true)
    local localroot = typeof(localcharacter) == "Instance"
            and localcharacter:IsA("Model")
            and rootof(localplayer, localcharacter)
        or nil
    if typeof(localroot) ~= "Instance" or not localroot:IsA("BasePart") then
        localroot = nil
    end

    for target, o in cache do
        local ok, message = pcall(update, target, o, camera, localroot)
        if not ok then
            hide(o)
            report("render", message)
        end
    end
end)
env.sixly_esp_drawing = esp
return esp
