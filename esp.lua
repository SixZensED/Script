-- v3
local players = game:GetService("Players")
local runservice = game:GetService("RunService")
local localplayer = players.LocalPlayer
local env = (getgenv and getgenv()) or _G
assert(Drawing and type(Drawing.new) == "function", "sixly esp: Drawing.new required")
if env.sixly_esp_drawing and type(env.sixly_esp_drawing.destroy) == "function" then
    pcall(function() env.sixly_esp_drawing:destroy() end)
end
local pink, purple = Color3.fromRGB(255,38,220), Color3.fromRGB(172,59,255)
local cyan, white = Color3.fromRGB(65,210,255), Color3.fromRGB(250,247,255)
local dark, red, green = Color3.fromRGB(18,9,26), Color3.fromRGB(255,65,100), Color3.fromRGB(65,255,145)
local r6parts = {"Head","Torso","Left Arm","Right Arm","Left Leg","Right Leg"}
local r15parts = {"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"}
local r6bones = {{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}
local r15bones = {{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}}

local esp = {
    enabled = true, teamcheck = false, maxdistance = 1200,
    tracerorigin = "Top", tracertarget = "Root",
    offset = Vector2.zero, projectionmode = "Viewport", autoscale = true,
    scale = Vector2.new(1,1),
    drawing = {scale=Vector2.new(1,1),offset=Vector2.zero,autoscale=true,multiplier=Vector2.new(1,1)},
    methods = {Glow=true,Box=true,Skeleton=true,Trace=true,Name=true,Health=true,Distance=true},
    custom = {}
}
local cache, connections, watched = {}, {}, {}
local closed = false
local gui = Instance.new("ScreenGui")
gui.Name = "sixly_projection_monitor"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = -100
gui.Parent = localplayer:WaitForChild("PlayerGui")
local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1,1)
frame.BackgroundTransparency = 1
frame.Parent = gui
local highlights = Instance.new("Folder")
highlights.Name = "sixly_drawing_highlights"
highlights.Parent = workspace
local rendername = "sixly_custom_esp_render"
local lastcamera, lastviewport
local drawingSize = Vector2.zero
local currentRatio = Vector2.new(1,1)
local projectionScale = Vector2.new(1,1)

local function call(name, ...)
    local fn = esp.custom[name]
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a,b end
    warn("[Sixly ESP] " .. name .. ": " .. tostring(a))
end
local function characterof(target, isplayer)
    if not isplayer then return target end
    local value = call("get_character", target)
    if typeof(value) == "Instance" then return value end
    return target.Character
end
local function healthof(target, model, humanoid)
    local health, maximum = call("get_health", target, model, humanoid)
    if type(health) == "number" then return health, type(maximum) == "number" and maximum or 100 end
    if humanoid then return humanoid.Health, humanoid.MaxHealth end
    return 100, 100
end
local function aliveof(target, model, humanoid, health)
    local value = call("is_alive", target, model, humanoid)
    if type(value) == "boolean" then return value end
    return humanoid == nil or health > 0
end
local function teammateof(target, model, isplayer)
    local value = call("is_teammate", target, model)
    if type(value) == "boolean" then return value end
    return isplayer and target.Team ~= nil and target.Team == localplayer.Team and not target.Neutral and not localplayer.Neutral or false
end
local function rootof(target, model)
    local part = call("get_root", target, model)
    if typeof(part) == "Instance" and part:IsA("BasePart") then return part end
    return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart
end
function esp:set_custom(data)
    self.custom = type(data) == "table" and data or {}
    self:refresh()
end

local function newdrawing(objects, kind, properties)
    local object = Drawing.new(kind)
    object.Visible = false
    for key, value in properties do object[key] = value end
    objects.drawings[#objects.drawings+1] = object
    return object
end
local function newline(objects, color, thickness, transparency)
    return newdrawing(objects,"Line",{Color=color,Thickness=thickness,Transparency=transparency or 1})
end
local function newbox(objects, color, filled, thickness, transparency)
    return newdrawing(objects,"Square",{Color=color,Filled=filled,Thickness=thickness or 1,Transparency=transparency or 1})
end
local function newtext(objects, size)
    return newdrawing(objects,"Text",{Text="",Size=size,Color=white,Center=true,Outline=true,OutlineColor=dark,Font=2,Transparency=1})
end
local function create(target, isplayer)
    if closed or cache[target] or target == localplayer then return end
    local o = {target=target,isplayer=isplayer,drawings={},bones={},model=nil}
    o.boxglow = newbox(o,purple,false,3,0.33)
    o.box = newbox(o,pink,false,1.5,1)
    o.traceglow = newline(o,purple,3,0.3)
    o.trace = newline(o,white,1,0.85)
    o.name = newtext(o,13)
    o.info = newtext(o,12)
    o.healthback = newbox(o,dark,true,1,0.92)
    o.healthfill = newbox(o,green,true,1,1)
    o.healthborder = newbox(o,purple,false,1,0.85)
    for i=1,#r15bones do o.bones[i]={glow=newline(o,purple,3.4,0.4),core=newline(o,pink,1.5,1)} end
    local highlight = Instance.new("Highlight")
    highlight.Name="SixlyGlow_"..target.Name
    highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor=pink
    highlight.OutlineColor=purple
    highlight.FillTransparency=0.7
    highlight.OutlineTransparency=0
    highlight.Enabled=false
    highlight.Parent=highlights
    o.highlight=highlight
    cache[target]=o
    return o
end
local function hide(o)
    o.highlight.Enabled=false
    for _, d in o.drawings do d.Visible=false end
end
local function remove(target)
    local o=cache[target]
    if not o then return end
    cache[target]=nil
    o.highlight:Destroy()
    for _, d in o.drawings do pcall(function() d:Remove() end) end
end
local function projection(camera)
    drawingSize=camera.ViewportSize
    local size=frame.AbsoluteSize
    currentRatio=Vector2.new(1,1)
    if size.X>0 and size.Y>0 and drawingSize.X>0 and drawingSize.Y>0 then
        currentRatio=Vector2.new(size.X/drawingSize.X,size.Y/drawingSize.Y)
    end
    local cfg=esp.drawing
    local ratio=cfg.autoscale and currentRatio or Vector2.new(1,1)
    projectionScale=Vector2.new(ratio.X*cfg.multiplier.X,ratio.Y*cfg.multiplier.Y)
    cfg.scale=projectionScale
    cfg.offset=esp.offset
    esp.scale=projectionScale
    esp.autoscale=cfg.autoscale
end
local function project(camera, world)
    local point, visible=camera:WorldToViewportPoint(world)
    if point.Z<=0 then return nil,false end
    return Vector2.new(point.X*projectionScale.X,point.Y*projectionScale.Y)+esp.offset,visible
end
local function extendpart(camera, part, bounds)
    local cf,half=part.CFrame,part.Size*0.5
    local corners={}
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
        local pos=project(camera,cf:PointToWorldSpace(Vector3.new(half.X*x,half.Y*y,half.Z*z)))
        if not pos then return false end
        corners[#corners+1]=pos
    end end end
    for _,p in corners do
        bounds.minx=math.min(bounds.minx,p.X)
        bounds.miny=math.min(bounds.miny,p.Y)
        bounds.maxx=math.max(bounds.maxx,p.X)
        bounds.maxy=math.max(bounds.maxy,p.Y)
    end
    return true
end
local function getbodybox(camera,model,humanoid)
    local isr15=model:FindFirstChild("UpperTorso")~=nil
    local names=(humanoid and humanoid.RigType==Enum.HumanoidRigType.R6) and r6parts or (isr15 and r15parts or r6parts)
    local b={minx=math.huge,miny=math.huge,maxx=-math.huge,maxy=-math.huge}
    local count=0
    for _,name in names do
        local part=model:FindFirstChild(name)
        if part and part:IsA("BasePart") and extendpart(camera,part,b) then count+=1 end
    end
    if count<2 then
        b={minx=math.huge,miny=math.huge,maxx=-math.huge,maxy=-math.huge}
        count=0
        local root=model:FindFirstChild("HumanoidRootPart")
        for _,part in model:GetChildren() do
            if part:IsA("BasePart") and part~=root and part.Name~="Hitbox" and part.Name~="Collision" and part.Size.Magnitude<=15 then
                if extendpart(camera,part,b) then count+=1 end
            end
        end
    end
    if count==0 then return nil end
    local width,height=b.maxx-b.minx,b.maxy-b.miny
    if width<1 or height<2 then return nil end
    if width>height*1.8 then
        local mid=(b.minx+b.maxx)*0.5
        width=height*1.8
        b.minx=mid-width*0.5
    end
    return Vector2.new(b.minx-2,b.miny-2),Vector2.new(width+4,height+4)
end
local function getcustombox(camera, target, model, root, head)
    local custompos, customsize=call("get_box",target,model,camera)
    if typeof(custompos)=="Vector2" and typeof(customsize)=="Vector2" then
        return custompos,customsize
    end
    if esp.custom.box_mode~="Root" then return nil end
    local origin=root.Position
    local top=head and head:IsA("BasePart") and head.Position+Vector3.new(0,head.Size.Y*0.65,0) or origin+Vector3.new(0,2.6,0)
    local bottom=origin-Vector3.new(0,3,0)
    local top2d=project(camera,top)
    local bottom2d=project(camera,bottom)
    if not top2d or not bottom2d then return nil end
    local height=math.abs(bottom2d.Y-top2d.Y)
    if height<2 then return nil end
    local width=height*0.48
    local middle=(top2d.X+bottom2d.X)*0.5
    return Vector2.new(middle-width*0.5,math.min(top2d.Y,bottom2d.Y)),Vector2.new(width,height)
end
local function drawbone(bone,a,b,color,glow)
    if not a or not b then bone.glow.Visible=false bone.core.Visible=false return end
    bone.glow.From=a bone.glow.To=b bone.core.From=a bone.core.To=b
    bone.glow.Color=glow bone.core.Color=color
    bone.glow.Visible=true bone.core.Visible=true
end
local function update(target,o,camera,localroot)
    local model=characterof(target,o.isplayer)
    if not model or not model:IsA("Model") or not model.Parent then
        hide(o) o.model=nil o.highlight.Adornee=nil return
    end
    local humanoid=model:FindFirstChildOfClass("Humanoid")
    local health,maxhealth=healthof(target,model,humanoid)
    local root=rootof(target,model)
    if not aliveof(target,model,humanoid,health) or not root or not root:IsA("BasePart") then hide(o) return end
    local teammate=teammateof(target,model,o.isplayer)
    if esp.teamcheck and teammate then hide(o) return end
    local distance=localroot and (root.Position-localroot.Position).Magnitude or 0
    if esp.maxdistance>0 and localroot and distance>esp.maxdistance then hide(o) return end
    local root2d,visible=project(camera,root.Position)
    if not root2d or not visible then hide(o) return end
    local head=model:FindFirstChild("Head")
    local head2d
    if head and head:IsA("BasePart") then head2d=project(camera,head.Position+Vector3.new(0,head.Size.Y*0.7+0.12,0)) end
    local pos,size=getcustombox(camera,target,model,root,head)
    if not pos then pos,size=getbodybox(camera,model,humanoid) end
    if not pos then hide(o) return end
    if o.model~=model then o.model=model o.highlight.Adornee=model end
    local methods=esp.methods
    local color=teammate and cyan or pink
    local glow=teammate and cyan or purple
    o.highlight.Enabled=methods.Glow==true
    o.highlight.FillColor=color o.highlight.OutlineColor=glow
    local middle=pos.X+size.X*0.5
    local bottom=pos.Y+size.Y
    local anchor=head2d and head2d.X or root2d.X
    local showbox=methods.Box==true
    o.box.Visible=showbox o.boxglow.Visible=showbox
    if showbox then
        o.box.Position=pos o.box.Size=size o.boxglow.Position=pos o.boxglow.Size=size
        o.box.Color=color o.boxglow.Color=glow
    end
    local showtrace=methods.Trace==true or methods.Line==true
    o.trace.Visible=showtrace o.traceglow.Visible=showtrace
    if showtrace then
        local from=Vector2.new(drawingSize.X*0.5*projectionScale.X+esp.offset.X,esp.tracerorigin=="Bottom" and drawingSize.Y*projectionScale.Y+esp.offset.Y or esp.offset.Y)
        local to=root2d
        if esp.tracertarget=="Head" then to=head2d or root2d elseif esp.tracertarget=="Feet" then to=Vector2.new(middle,bottom) end
        o.trace.From=from o.trace.To=to o.traceglow.From=from o.traceglow.To=to
    end
    o.name.Visible=methods.Name==true
    if methods.Name then
        local label=call("get_name",target,model)
        o.name.Text=type(label)=="string" and label or target.Name
        o.name.Position=Vector2.new(anchor,(head2d and head2d.Y or pos.Y)-17)
        o.name.Color=white
    end
    local showhealth=methods.Health==true
    o.healthback.Visible=showhealth o.healthfill.Visible=showhealth o.healthborder.Visible=showhealth
    if showhealth then
        local ratio=math.clamp(health/math.max(maxhealth,1),0,1)
        local width=math.max(20,math.min(size.X,85))
        local barpos=Vector2.new(middle-width*0.5,bottom+5)
        local barsize=Vector2.new(width,4)
        o.healthback.Position=barpos o.healthback.Size=barsize
        o.healthfill.Position=barpos o.healthfill.Size=Vector2.new(width*ratio,4)
        o.healthfill.Color=red:Lerp(green,ratio)
        o.healthborder.Position=barpos o.healthborder.Size=barsize
    end
    local showinfo=methods.Health==true or methods.Distance==true
    o.info.Visible=showinfo
    if showinfo then
        local info={}
        if methods.Health then info[#info+1]=string.format("%d HP",math.ceil(health)) end
        if methods.Distance and localroot then info[#info+1]=string.format("%d studs",math.floor(distance+0.5)) end
        o.info.Text=table.concat(info," | ")
        o.info.Position=Vector2.new(middle,bottom+(showhealth and 13 or 5))
    end
    local isr15=model:FindFirstChild("UpperTorso")~=nil
    local bones=(humanoid and humanoid.RigType==Enum.HumanoidRigType.R6) and r6bones or (isr15 and r15bones or r6bones)
    for i,bone in o.bones do
        local pair=bones[i]
        if not methods.Skeleton or not pair then bone.glow.Visible=false bone.core.Visible=false continue end
        local a=model:FindFirstChild(pair[1])
        local b=model:FindFirstChild(pair[2])
        if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
            drawbone(bone,project(camera,a.Position),project(camera,b.Position),color,glow)
        else drawbone(bone,nil,nil,color,glow) end
    end
end
function esp:set_enabled(value)
    self.enabled=value==true
    if not self.enabled then for _,o in cache do hide(o) end end
end
function esp:set_methods(value)
    local selected={}
    if type(value)=="string" then selected[value]=true
    elseif type(value)=="table" then
        for key,item in value do
            if type(item)=="string" then selected[item]=true
            elseif type(key)=="string" and item==true then selected[key]=true end
        end
    end
    self.methods=selected
end
function esp:set_teamcheck(value) self.teamcheck=value==true end
function esp:set_trace_origin(value) self.tracerorigin=value=="Bottom" and "Bottom" or "Top" end
function esp:set_trace_target(value) self.tracertarget=(value=="Head" or value=="Feet") and value or "Root" end
function esp:set_maxdistance(value) self.maxdistance=math.max(0,tonumber(value) or 0) end
function esp:set_offset(value)
    if typeof(value)=="Vector2" then self.offset=value self.drawing.offset=value end
end
function esp:set_projection_mode(value) self.projectionmode="Viewport" end
function esp:set_auto_scale(value) self.drawing.autoscale=value==true self.autoscale=self.drawing.autoscale end
function esp:set_projection_scale(value)
    if typeof(value)=="Vector2" and value.X>0 and value.Y>0 then self.drawing.multiplier=value end
end
function esp:get_projection_info()
    local camera=workspace.CurrentCamera
    return {cameraViewport=camera and camera.ViewportSize,mode="Viewport (dynamic GUI ratio)",scale=self.drawing.multiplier,effectiveScale=projectionScale,guiSize=frame.AbsoluteSize,guiToViewportRatio=currentRatio,autoscale=self.autoscale,offset=self.offset}
end
function esp:clear_calibration()
    self.drawing.multiplier=Vector2.new(1,1)
    self.drawing.autoscale=true
    self.drawing.scale=Vector2.new(1,1)
    self.drawing.offset=Vector2.zero
    self.offset=Vector2.zero
    self.autoscale=true
    self.scale=Vector2.new(1,1)
end
function esp:calibrate() self:clear_calibration() end
function esp:add_model(model)
    if typeof(model)=="Instance" and model:IsA("Model") then create(model,false) end
end
function esp:remove_model(model) remove(model) end
function esp:watch_npcs(folder)
    if typeof(folder)~="Instance" or watched[folder] then return end
    watched[folder]=true
    for _,item in folder:GetDescendants() do
        if item:IsA("Humanoid") and item.Parent:IsA("Model") then self:add_model(item.Parent) end
    end
    connections[#connections+1]=folder.DescendantAdded:Connect(function(item)
        if item:IsA("Humanoid") and item.Parent:IsA("Model") then self:add_model(item.Parent) end
    end)
end
function esp:refresh()
    if closed then return end
    for _,o in cache do o.model=nil o.highlight.Adornee=nil hide(o) end
end
function esp:destroy()
    if closed then return end
    closed=true
    runservice:UnbindFromRenderStep(rendername)
    for _,connection in connections do connection:Disconnect() end
    for target in cache do remove(target) end
    highlights:Destroy()
    gui:Destroy()
    if env.sixly_esp_drawing==self then env.sixly_esp_drawing=nil end
end
connections[#connections+1]=players.PlayerAdded:Connect(function(player) create(player,true) end)
connections[#connections+1]=players.PlayerRemoving:Connect(remove)
for _,player in players:GetPlayers() do
    if player~=localplayer then create(player,true) end
end
runservice:BindToRenderStep(rendername,Enum.RenderPriority.Camera.Value+1,function()
    if closed or not esp.enabled then return end
    local camera=workspace.CurrentCamera
    if not camera then return end
    if lastcamera~=camera or lastviewport~=camera.ViewportSize then esp:refresh() end
    lastcamera=camera lastviewport=camera.ViewportSize
    projection(camera)
    local localcharacter=characterof(localplayer,true)
    local localroot=localcharacter and rootof(localplayer,localcharacter)
    for target,o in cache do
        if not o.isplayer and not target.Parent then remove(target)
        else update(target,o,camera,localroot) end
    end
end)
env.sixly_esp_drawing=esp
return esp
