local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))

-- the first time a player meets an area's condition, it unlocks for good (saved).
-- Reaching a later area also unlocks every area before it (e.g. you can't have
-- rebirthed without having had 1,000 Cash, even though Cash resets on rebirth).
local function check(player)
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end

	local zones = ZoneConfig.Zones
	local furthest = 0

	for index, zone in ipairs(zones) do
		if not zone.independent and (ZoneConfig.isRevealed(player, zone) or ZoneConfig.conditionMet(player, zone)) then
			furthest = index
		end
	end

	-- independent areas: only their own condition counts
	for _, zone in ipairs(zones) do
		if zone.independent and player:GetAttribute(ZoneConfig.flagAttribute(zone)) ~= true and ZoneConfig.conditionMet(player, zone) then
			player:SetAttribute(ZoneConfig.flagAttribute(zone), true)
		end
	end

	for index = 1, furthest do
		local zone = zones[index]

		if not ZoneConfig.alwaysOpen(zone) and not zone.independent then
			local flag = ZoneConfig.flagAttribute(zone)

			if player:GetAttribute(flag) ~= true then
				player:SetAttribute(flag, true)
			end
		end
	end
end

local function watch(player)
	player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		check(player)
	end)

	for _, attribute in ipairs(ZoneConfig.watchedAttributes()) do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			check(player)
		end)
	end

	check(player)
end

Players.PlayerAdded:Connect(watch)

for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end
