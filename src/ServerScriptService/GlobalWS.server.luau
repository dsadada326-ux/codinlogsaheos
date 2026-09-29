local Players = game:GetService("Players")

local WALK_SPEED = 35


local function setupCharacter(character)

	local humanoid =
		character:WaitForChild("Humanoid")

	humanoid.WalkSpeed =
		WALK_SPEED

end


Players.PlayerAdded:Connect(function(player)

	player.CharacterAdded:Connect(setupCharacter)

end)


for _, player in ipairs(Players:GetPlayers()) do

	if player.Character then
		setupCharacter(player.Character)
	end

	player.CharacterAdded:Connect(setupCharacter)

end