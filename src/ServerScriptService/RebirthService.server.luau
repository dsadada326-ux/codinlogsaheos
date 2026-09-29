local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))
local ConversionConfig = require(ReplicatedStorage:WaitForChild("ConversionConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))

local doRebirth = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("DoRebirth")

local COOLDOWN = 1 -- seconds between rebirths per player
local lastRebirth = {}

local function round2(number)
	return math.floor(number * 100 + 0.5) / 100
end

-- cashes in ALL of a player's current Cash for Rebirths (at least 1,000 Cash needed).
-- Resets Cash, Buttons, Button Value and the Cash-board upgrades; Rebirth Boosts are kept.
local function rebirth(player)
	if player:GetAttribute("DataLoaded") ~= true then
		return { ok = false, reason = "loading" }
	end

	local now = os.clock()

	if now - (lastRebirth[player] or 0) < COOLDOWN then
		return { ok = false, reason = "cooldown" }
	end

	lastRebirth[player] = now

	local gained = RebirthConfig.potentialFor(player) -- includes the Gems Rebirths Multiplier

	if gained < 1 then
		return { ok = false, reason = "cash" }
	end

	local totalRebirths = (player:GetAttribute("Rebirths") or 0) + gained

	player:SetAttribute("Rebirths", totalRebirths)
	player:SetAttribute("Cash", 0)
	player:SetAttribute("Buttons", 0)
	player:SetAttribute("ButtonValue", ConversionConfig.StartValue)

	-- the Cash-board upgrades start over; Rebirth Boosts upgrades are kept
	-- (unlock flags are kept too, so the tutorial isn't repeated)
	for _, id in ipairs(UpgradeConfig.Order) do
		if UpgradeConfig.Upgrades[id].ResetOnRebirth then
			player:SetAttribute(UpgradeConfig.levelAttribute(id), 0)
		end
	end

	return {
		ok = true,
		gained = gained,
		totalRebirths = totalRebirths,
	}
end

doRebirth.OnServerInvoke = function(player)
	return rebirth(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastRebirth[player] = nil
end)
