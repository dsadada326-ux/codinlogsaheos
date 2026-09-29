-- The Wheat Farm on Island 2 (ported from the old game).
-- Plots are bought in order (1, 2, 3, ...) with Gold. Each owned plot grows through
-- 6 stages (Wheat0 -> Wheat5); walk into a fully grown plot (stage 5) to harvest its Wheat.
-- Sell Wheat for Gold at the SellWheat board.
--
-- Saved: FarmSlots (how many plots you own). Growth stages restart at 0 when you rejoin.
-- Live:  FarmStage_<plot> attributes (0-5) on the Player, set by FarmService.
local FarmConfig = {}

FarmConfig.GrowthStageTime = 3      -- seconds per growth stage (before Grow Speed)
FarmConfig.MinGrowthStageTime = 0.5 -- Grow Speed can never go below this
FarmConfig.WheatToGoldRate = 1      -- Gold per Wheat (before Gold Multiplier)
FarmConfig.MaxStage = 5

FarmConfig.StageModelNames = { "Wheat0", "Wheat1", "Wheat2", "Wheat3", "Wheat4", "Wheat5" }

-- in buying order; the index is the plot's name under FarmLayer.Slots
FarmConfig.Slots = {
	{ Name = "Farm Plot 1", Price = 0, WheatReward = 5 },
	{ Name = "Farm Plot 2", Price = 10, WheatReward = 8 },
	{ Name = "Farm Plot 3", Price = 50, WheatReward = 12 },
	{ Name = "Farm Plot 4", Price = 650, WheatReward = 18 },
	{ Name = "Farm Plot 5", Price = 3000, WheatReward = 27 },
	{ Name = "Farm Plot 6", Price = 12000, WheatReward = 40 },
	{ Name = "Farm Plot 7", Price = 50000, WheatReward = 60 },
	{ Name = "Farm Plot 8", Price = 100000, WheatReward = 90 },
	{ Name = "Farm Plot 9", Price = 200000, WheatReward = 120 },
	{ Name = "Farm Plot 10", Price = 500000, WheatReward = 150 },
	{ Name = "Farm Plot 11", Price = 1000000, WheatReward = 200 },
	{ Name = "Farm Plot 12", Price = 2000000, WheatReward = 250 },
	{ Name = "Farm Plot 13", Price = 5000000, WheatReward = 320 },
	{ Name = "Farm Plot 14", Price = 10000000, WheatReward = 400 },
	{ Name = "Farm Plot 15", Price = 20000000, WheatReward = 500 },
	{ Name = "Farm Plot 16", Price = 50000000, WheatReward = 650 },
	{ Name = "Farm Plot 17", Price = 100000000, WheatReward = 800 },
	{ Name = "Farm Plot 18", Price = 200000000, WheatReward = 1000 },
	{ Name = "Farm Plot 19", Price = 500000000, WheatReward = 1250 },
	{ Name = "Farm Plot 20", Price = 1000000000, WheatReward = 1600 },
	{ Name = "Farm Plot 21", Price = 2000000000, WheatReward = 2000 },
	{ Name = "Farm Plot 22", Price = 40000000000, WheatReward = 2500 },
	{ Name = "Farm Plot 23", Price = 80000000000, WheatReward = 3200 },
	{ Name = "Farm Plot 24", Price = 500000000000, WheatReward = 4000 },
}

FarmConfig.WheatIcon = "rbxassetid://113575907853996" -- the Wheat currency orb

function FarmConfig.stageAttribute(index)
	return "FarmStage_" .. index
end

function FarmConfig.owned(player)
	return player:GetAttribute("FarmSlots") or 0
end

-- seconds each growth stage takes for this player (Grow Speed upgrade applied)
function FarmConfig.stageTime(player)
	local UpgradeConfig = require(script.Parent:WaitForChild("UpgradeConfig"))
	local level = player:GetAttribute(UpgradeConfig.levelAttribute("FarmSpeed")) or 0

	return math.max(
		FarmConfig.GrowthStageTime + UpgradeConfig.valueAt("FarmSpeed", level),
		FarmConfig.MinGrowthStageTime
	)
end

-- Gold per Wheat for this player (Gold Multiplier upgrade applied)
function FarmConfig.goldRate(player)
	local Multipliers = require(script.Parent:WaitForChild("Multipliers"))

	return FarmConfig.WheatToGoldRate * Multipliers.gold(player)
end

return FarmConfig
