local players = cloneref(game:GetService("Players"))
local runservice = cloneref(game:GetService("RunService"))
local localplayer = players.LocalPlayer
local playergui = localplayer:WaitForChild("PlayerGui")

local old = playergui:FindFirstChild("sixly_esp")
if old then
    old:Destroy()
end

local marker = Instance.new("Folder")
marker.Name = "sixly_esp"
marker.Parent = playergui

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

local signs = {-1, 1}
local esp = {cache = {}, connections = {}, errors = {}}

local newdrawing = function(kind)
    local object = Drawing.new(kind)
    object.Visible = false
    object.Transparency = 1
    object.Thickness = 1.5
    object.Color = Color3.new(1, 1, 1)
    if kind == "Square" then
        object.Filled = false
    end
    return object
end

local hide = function(objects)
    objects.box.Visible = false
    objects.line.Visible = false
    objects.trace.Visible = false
    objects.healthbg.Visible = false
    objects.health.Visible = false
    for _, line in objects.skeleton do
        line.Visible = false
    end
end

local create = function(player)
    if player == localplayer or esp.cache[player] or esp.destroyed then return end

    local objects = {
        box = newdrawing("Square"),
        line = newdrawing("Line"),
        trace = newdrawing("Line"),
        healthbg = newdrawing("Line"),
        health = newdrawing("Line"),
        skeleton = {},
    }

    for i = 1, #bones_r15 do
        objects.skeleton[i] = newdrawing("Line")
    end

    esp.cache[player] = objects
end

local remove = function(player)
    local objects = esp.cache[player]
    if not objects then return end

    for key, object in objects do
        if key == "skeleton" then
            for _, line in object do
                line:Remove()
            end
        else
            object:Remove()
        end
    end

    esp.cache[player] = nil
    esp.errors[player] = nil
end

local bounds = function(character, camera)
    local cf, size = character:GetBoundingBox()
    local half = size * 0.5
    local minx, miny = math.huge, math.huge
    local maxx, maxy = -math.huge, -math.huge

    for _, x in signs do
        for _, y in signs do
            for _, z in signs do
                local world = cf:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
                local screen = camera:WorldToViewportPoint(world)
                if screen.Z <= 0 then return end
                minx = math.min(minx, screen.X)
                miny = math.min(miny, screen.Y)
                maxx = math.max(maxx, screen.X)
                maxy = math.max(maxy, screen.Y)
            end
        end
    end

    local viewport = camera.ViewportSize
    local width, height = maxx - minx, maxy - miny
    if width <= 1 or height <= 1 then return end
    if width > viewport.X * 3 or height > viewport.Y * 3 then return end
    return minx, miny, maxx, maxy
end

local update = function(player, objects, camera)
    hide(objects)
    if not esp.enabled or not esp.methods then return end

    local character = player.Character
    if not character then return end

    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return end

    local teammate = player.Team ~= nil
        and player.Team == localplayer.Team
        and not player.Neutral
        and not localplayer.Neutral
    if esp.teamcheck and teammate then return end

    local rootpoint, onscreen = camera:WorldToViewportPoint(root.Position)
    if not onscreen or rootpoint.Z <= 0 then return end

    local color = teammate and Color3.fromRGB(85, 170, 255) or Color3.fromRGB(255, 85, 85)
    local viewport = camera.ViewportSize
    local bottom = rootpoint.Y

    if esp.methods.Box or esp.methods.Health then
        local minx, miny, maxx, maxy = bounds(character, camera)
        if minx then
            local height = maxy - miny
            bottom = maxy

            if esp.methods.Box then
                objects.box.Position = Vector2.new(minx, miny)
                objects.box.Size = Vector2.new(maxx - minx, height)
                objects.box.Color = color
                objects.box.Visible = true
            end

            if esp.methods.Health then
                local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
                local x = minx - 6
                objects.healthbg.From = Vector2.new(x, maxy)
                objects.healthbg.To = Vector2.new(x, miny)
                objects.healthbg.Color = Color3.fromRGB(20, 20, 20)
                objects.healthbg.Thickness = 4
                objects.healthbg.Visible = true

                objects.health.From = Vector2.new(x, maxy)
                objects.health.To = Vector2.new(x, maxy - height * ratio)
                objects.health.Color = Color3.fromRGB(255, 65, 65):Lerp(Color3.fromRGB(65, 255, 120), ratio)
                objects.health.Thickness = 2
                objects.health.Visible = true
            end
        end
    end

    if esp.methods.Line then
        objects.line.From = Vector2.new(viewport.X * 0.5, viewport.Y)
        objects.line.To = Vector2.new(rootpoint.X, bottom)
        objects.line.Color = color
        objects.line.Visible = true
    end

    if esp.methods.Trace then
        local head = character:FindFirstChild("Head")
        local target = head and head.Position or root.Position
        local screen = camera:WorldToViewportPoint(target)
        if screen.Z > 0 then
            objects.trace.From = viewport * 0.5
            objects.trace.To = Vector2.new(screen.X, screen.Y)
            objects.trace.Color = color
            objects.trace.Visible = true
        end
    end

    if esp.methods.Skeleton then
        local bones = humanoid.RigType == Enum.HumanoidRigType.R6 and bones_r6 or bones_r15
        for i, pair in bones do
            local a = character:FindFirstChild(pair[1])
            local b = character:FindFirstChild(pair[2])
            local segment = objects.skeleton[i]
            if a and b then
                local p1 = camera:WorldToViewportPoint(a.Position)
                local p2 = camera:WorldToViewportPoint(b.Position)
                if p1.Z > 0 and p2.Z > 0 then
                    segment.From = Vector2.new(p1.X, p1.Y)
                    segment.To = Vector2.new(p2.X, p2.Y)
                    segment.Color = color
                    segment.Visible = true
                end
            end
        end
    end
end

function esp:set_enabled(value)
    self.enabled = value == true
end

function esp:set_teamcheck(value)
    self.teamcheck = value == true
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

function esp:destroy()
    if self.destroyed then return end
    self.destroyed = true

    for _, connection in self.connections do
        connection:Disconnect()
    end
    for player in self.cache do
        remove(player)
    end
    if marker.Parent then
        marker:Destroy()
    end
end

table.insert(esp.connections, marker.Destroying:Connect(function()
    esp:destroy()
end))
table.insert(esp.connections, players.PlayerAdded:Connect(create))
table.insert(esp.connections, players.PlayerRemoving:Connect(remove))

for _, player in players:GetPlayers() do
    create(player)
end

table.insert(esp.connections, runservice.RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera
    if not camera or esp.destroyed then return end
    for player, objects in esp.cache do
        local ok, err = pcall(update, player, objects, camera)
        if not ok then
            hide(objects)
            if not esp.errors[player] then
                esp.errors[player] = true
                warn("[sixly_esp] " .. player.Name .. ": " .. tostring(err))
            end
        end
    end
end))

return esp
