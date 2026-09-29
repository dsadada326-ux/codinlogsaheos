local Players = game:GetService("Players")

-- one second of Playtime per second in game (saved by PlayerData)
while true do
	task.wait(1)

	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("DataLoaded") == true then
			player:SetAttribute("Playtime", (player:GetAttribute("Playtime") or 0) + 1)
		end
	end
end
