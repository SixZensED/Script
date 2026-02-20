local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Collect Angpao & Gold

local collect_items = function()
	local character = LocalPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	for _, v in ipairs(workspace:GetChildren()) do
		if v:IsA("Model") and v.Name == "Envelope" or v.Name == "Gold" then
			local hitbox = v:FindFirstChild("Hitbox")
			if hitbox then
				firetouchinterest(hitbox, rootPart, 0)
				task.wait(0.05)
				firetouchinterest(hitbox, rootPart, 1)
			end
		end
	end
end

-- Room Handle

local handle_room = function()
	ReplicatedStorage["Lobby Relatives"]:WaitForChild("LunarMap"):FireServer("Host")
	task.wait(0.15)
	ReplicatedStorage["Lobby Relatives"].Doors:FireServer("Play","Custom")
end

-- Result Handle

local result = function()
	if LocalPlayer.PlayerGui.Upboard:FindFirstChild("Result").Visible then
		ReplicatedStorage.Remotes.Upboard:FireServer("PlayAgain")
		task.wait(0.5)
	end
end

task.spawn(function()
	while task.wait() do
		if PlaceId == 16695366828 then  
			local success ,err = pcall(handle_room)
			if not success then
				warn("Room Error: " .. tostring(err))
			end
			return
		end
		
		task.spawn(result)
		local success, err = pcall(collect_items)
		if not success then
			warn("Collection Error: " .. tostring(err))
		end
		task.wait(1)
	end
end)
