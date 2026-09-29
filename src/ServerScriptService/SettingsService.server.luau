local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))

local setSetting = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("SetSetting")

-- the client asks to flip a setting; validate and store it as an attribute
-- (the same attribute PlayerData already saves)
setSetting.OnServerEvent:Connect(function(player, key, value)
	if typeof(key) ~= "string" or SettingsConfig.Settings[key] == nil then
		return
	end

	if typeof(value) ~= "boolean" then
		return
	end

	if player:GetAttribute("DataLoaded") ~= true then
		return
	end

	player:SetAttribute(SettingsConfig.attributeOf(key), value)
end)

-- Save Last Position: remember where the player was, and put them back when they rejoin
local PLACE_DELAY = 0.5 -- seconds after spawning before teleporting (lets the character settle)

local function trySavePosition(player)
	if player:GetAttribute(SettingsConfig.attributeOf("SaveLastPos")) == false then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if root then
		player:SetAttribute("LastPosition", root.Position)
	end
end

-- First spawn of the session: put the player on their saved spot (or leave them on the
-- spawn), then tell their client where they landed so JoinIntro can drop them in from the sky.
local function tryRestorePosition(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 5)

	if not root then
		return
	end

	-- the saved spot comes with the player's data
	if player:GetAttribute("DataLoaded") ~= true then
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end

	task.wait(PLACE_DELAY)

	if not character.Parent then
		return
	end

	local saved = player:GetAttribute("LastPosition")
	local useSaved = saved and player:GetAttribute(SettingsConfig.attributeOf("SaveLastPos")) ~= false
	local landing = useSaved and (saved + Vector3.new(0, 3, 0)) or root.Position

	-- load the area around the landing spot for them first (the place streams parts in)
	pcall(function()
		player:RequestStreamAroundAsync(landing, 5)
	end)

	if not character.Parent then
		return
	end

	if useSaved then
		root.CFrame = CFrame.new(landing) * root.CFrame.Rotation
	end

	-- JoinIntro (client) plays the sky drop, only for brand-new players.
	-- To preview it in Studio: select Workspace and tick the PreviewJoinIntro attribute.
	local preview = RunService:IsStudio() and workspace:GetAttribute("PreviewJoinIntro") == true

	if player:GetAttribute("IntroPlayed") ~= true or preview then
		player:SetAttribute("IntroPlayed", true)
		player:SetAttribute("_IntroLanding", landing)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- only the very first spawn restores the saved spot; later respawns
		-- (dying, rejoining a rebirth, etc.) use the normal spawn point
		if player:GetAttribute("_Restored") then
			return
		end

		player:SetAttribute("_Restored", true)

		task.spawn(tryRestorePosition, player, character)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	trySavePosition(player)
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		trySavePosition(player)
	end
end)
