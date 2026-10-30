local players = cloneref(game:GetService("Players"))
local runservice = cloneref(game:GetService("RunService"))
local localplayer = players.LocalPlayer

local previous = workspace:FindFirstChild("sixly_esp")
if previous then previous:Destroy() end

local playergui = localplayer:WaitForChild("PlayerGui")
local old = playergui:FindFirstChild("sixly_esp")
if old then old:Destroy() end

local folder = Instance.new("Folder")
folder.Name = "sixly_esp"
folder.Parent = workspace

local esp = {}
local cache = {}
local connections = {}
local closed = false
local rendername = "sixly_esp_glow_render"
local enemycolor = Color3.fromRGB(255, 30, 30)
local teamcolor = Color3.fromRGB(65, 160, 255)
local tracecolor = Color3.fromRGB(60, 255, 95)

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

local newline = function()
    local line = Drawing.new("Line")
    line.Visible = false
    line.Transparency = 1
    line.Thickness = 1.5
    return line
end

local newgui = function()
    local gui = Instance.new("BillboardGui")
    gui.Name = "ESPLabel"
    gui.Enabled = false
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.Size = UDim2.fromOffset(150, 39)
    gui.StudsOffsetWorldSpace = Vector3.new(0, 1.15, 0)
    gui.Parent = playergui

    local label = Instance.new("TextLabel")
    label.Name = "PlayerName"
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 22)
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(255, 45, 45)
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.Text = ""
    label.Parent = gui

    local background = Instance.new("Frame")
    background.Name = "HealthBackground"
    background.AnchorPoint = Vector2.new(0.5, 0)
    background.Position = UDim2.new(0.5, 0, 0, 26)
    background.Size = UDim2.fromOffset(74, 5)
    background.BorderSizePixel = 0
    background.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    background.Parent = gui

    local health = Instance.new("Frame")
    health.Name = "HealthFill"
    health.Size = UDim2.fromScale(1, 1)
    health.BackgroundColor3 = Color3.fromRGB(255, 45, 45)
    health.BorderSizePixel = 0
    health.Parent = background

    return gui, label, background, health
end

local create = function(player)
    if closed or player == localplayer or cache[player] then return end

    local glow = Instance.new("Highlight")
    glow.Name = "Glow_" .. player.UserId
    glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    glow.FillTransparency = 1
    glow.OutlineTransparency = 1
    glow.Enabled = false
    glow.Parent = folder

    local gui, name, healthbg, healthfill = newgui()
    local trace = newline()
    trace.Color = tracecolor
    cache[player] = {
        glow = glow,
        gui = gui,
        name = name,
        healthbg = healthbg,
        healthfill = healthfill,
        trace = trace,
        skeleton = {},
        character = nil,
        humanoid = nil,
        head = nil,
        root = nil,
        healthconnection = nil,
        maxhealthconnection = nil,
        hidden = true,
        lastcolor = nil,
        healthratio = 1,
    }
end

local hide = function(objects)
    if objects.hidden then return end
    objects.hidden = true
    objects.glow.Enabled = false
    objects.gui.Enabled = false
    objects.trace.Visible = false
    for _, line in objects.skeleton do
        line.Visible = false
    end
end

local remove = function(player)
    local objects = cache[player]
    if not objects then return end
    if objects.healthconnection then objects.healthconnection:Disconnect() end
    if objects.maxhealthconnection then objects.maxhealthconnection:Disconnect() end
    objects.trace:Remove()
    for _, line in objects.skeleton do
        line:Remove()
    end
    objects.glow:Destroy()
    objects.gui:Destroy()
    cache[player] = nil
end

local updatehealth = function(objects)
    local humanoid = objects.humanoid
    if not humanoid then return end
    local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
    objects.healthratio = ratio
    objects.healthfill.Size = UDim2.fromScale(ratio, 1)
end

local attach = function(player, objects, character)
    if objects.healthconnection then objects.healthconnection:Disconnect() end
    if objects.maxhealthconnection then objects.maxhealthconnection:Disconnect() end
    objects.healthconnection = nil
    objects.maxhealthconnection = nil
    objects.character = character
    objects.root = character and character:FindFirstChild("HumanoidRootPart")
    objects.head = character and character:FindFirstChild("Head")
    objects.humanoid = character and character:FindFirstChildOfClass("Humanoid")
    objects.glow.Adornee = character
    objects.gui.Adornee = objects.head
    objects.name.Text = player.DisplayName

    if objects.humanoid then
        objects.healthconnection = objects.humanoid.HealthChanged:Connect(function()
            updatehealth(objects)
        end)
        objects.maxhealthconnection = objects.humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
            updatehealth(objects)
        end)
        updatehealth(objects)
    end
end

local footposition = function(character, root, humanoid)
    local left = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg")
    local right = character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg")
    if left and right then
        local average = (left.Position + right.Position) * 0.5
        return Vector3.new(average.X, math.min(left.Position.Y - left.Size.Y * 0.5, right.Position.Y - right.Size.Y * 0.5), average.Z)
    end
    return root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y * 0.5, 0)
end

local drawskeleton = function(objects, character, humanoid, camera, color)
    local bones = humanoid.RigType == Enum.HumanoidRigType.R6 and bones_r6 or bones_r15
    for i, pair in bones do
        local a = character:FindFirstChild(pair[1])
        local b = character:FindFirstChild(pair[2])
        local line = objects.skeleton[i]
        if not line then
            line = newline()
            objects.skeleton[i] = line
        end
        if a and b then
            local p1 = camera:WorldToViewportPoint(a.Position)
            local p2 = camera:WorldToViewportPoint(b.Position)
            if p1.Z > 0 and p2.Z > 0 then
                line.From = Vector2.new(p1.X, p1.Y)
                line.To = Vector2.new(p2.X, p2.Y)
                line.Color = color
                line.Visible = true
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
    end
end

local update = function(player, objects, camera)
    local methods = esp.methods
    if not esp.enabled or not methods then
        hide(objects)
        return
    end

    local character = player.Character
    if objects.character ~= character or (character and (not objects.root or not objects.head or not objects.humanoid)) then
        attach(player, objects, character)
    end

    local humanoid, root, head = objects.humanoid, objects.root, objects.head
    if not character or not humanoid or not root or not head or humanoid.Health <= 0 then
        hide(objects)
        return
    end

    local teammate = player.Team ~= nil and player.Team == localplayer.Team
        and not player.Neutral and not localplayer.Neutral
    if esp.teamcheck and teammate then
        hide(objects)
        return
    end

    objects.hidden = false
    local color = teammate and teamcolor or enemycolor
    local visibleglow = (methods.Glow or methods.Health) == true
    if objects.glow.Enabled ~= visibleglow then
        objects.glow.Enabled = visibleglow
    end
    if objects.lastcolor ~= color then
        objects.lastcolor = color
        objects.glow.OutlineColor = color
        objects.glow.FillColor = color
        objects.name.TextColor3 = color
    end
    if visibleglow then
        local outline = methods.Glow and 0 or 1
        local fill = methods.Health and (0.8 - objects.healthratio * 0.25) or 1
        if objects.glow.OutlineTransparency ~= outline then
            objects.glow.OutlineTransparency = outline
        end
        if objects.glow.FillTransparency ~= fill then
            objects.glow.FillTransparency = fill
        end
    end

    local showgui = methods.Name == true or methods.Health == true
    if objects.gui.Enabled ~= showgui then objects.gui.Enabled = showgui end
    if objects.name.Visible ~= (methods.Name == true) then
        objects.name.Visible = methods.Name == true
    end
    if objects.healthbg.Visible ~= (methods.Health == true) then
        objects.healthbg.Visible = methods.Health == true
    end

    if methods.Trace then
        local point, onscreen = camera:WorldToViewportPoint(root.Position)
        if onscreen and point.Z > 0 then
            local foot = camera:WorldToViewportPoint(footposition(character, root, humanoid))
            if foot.Z > 0 then
                local viewport = camera.ViewportSize
                objects.trace.From = Vector2.new(viewport.X * 0.5, viewport.Y - 1)
                objects.trace.To = Vector2.new(foot.X, foot.Y)
                objects.trace.Visible = true
            else
                objects.trace.Visible = false
            end
        else
            objects.trace.Visible = false
        end
    else
        objects.trace.Visible = false
    end

    if methods.Skeleton then
        drawskeleton(objects, character, humanoid, camera, color)
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

local cleanup = function()
    if closed then return end
    closed = true
    runservice:UnbindFromRenderStep(rendername)
    for _, connection in connections do
        connection:Disconnect()
    end
    for player in cache do
        remove(player)
    end
end

function esp:destroy()
    cleanup()
    folder:Destroy()
end

connections[#connections + 1] = folder.Destroying:Connect(cleanup)
connections[#connections + 1] = players.PlayerAdded:Connect(create)
connections[#connections + 1] = players.PlayerRemoving:Connect(remove)

for _, player in players:GetPlayers() do
    create(player)
end

runservice:BindToRenderStep(rendername, Enum.RenderPriority.Camera.Value + 1, function()
    if closed or not esp.enabled or not esp.methods then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    for player, objects in cache do
        local ok = pcall(update, player, objects, camera)
        if not ok then hide(objects) end
    end
end)

return esp
