local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))

-- the player list shows only Cash and Playtime
local function formatPlaytime(seconds)
	seconds = math.floor(seconds or 0)

	local days = math.floor(seconds / 86400)
	local hours = math.floor(seconds % 86400 / 3600)
	local minutes = math.floor(seconds % 3600 / 60)

	if days > 0 then
		return days .. "d " .. hours .. "h"
	elseif hours > 0 then
		return hours .. "h " .. minutes .. "m"
	end

	return minutes .. "m"
end

local STATS = {
	{ name = "Cash", attribute = "Cash", format = NumberFormat.abbreviate },
	{ name = "Playtime", attribute = "Playtime", format = formatPlaytime },
}

local function setup(player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	for _, stat in ipairs(STATS) do
		local value = Instance.new("StringValue")
		value.Name = stat.name
		value.Value = stat.format(player:GetAttribute(stat.attribute) or 0)
		value.Parent = folder

		player:GetAttributeChangedSignal(stat.attribute):Connect(function()
			value.Value = stat.format(player:GetAttribute(stat.attribute) or 0)
		end)
	end

	folder.Parent = player
end

Players.PlayerAdded:Connect(setup)

for _, player in ipairs(Players:GetPlayers()) do
	setup(player)
end
