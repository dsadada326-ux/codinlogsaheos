-- Every multiplier the player has, stacked, in one place. The server pays out with these
-- and the boards preview with the same functions, so what you see is what you get.
local UpgradeConfig = require(script.Parent:WaitForChild("UpgradeConfig"))
local PrestigeConfig = require(script.Parent:WaitForChild("PrestigeConfig"))
local RuneConfig = require(script.Parent:WaitForChild("RuneConfig"))
local EquipmentConfig = require(script.Parent:WaitForChild("EquipmentConfig"))
local SkillTreeConfig = require(script.Parent:WaitForChild("SkillTreeConfig"))
local ShopConfig = require(script.Parent:WaitForChild("ShopConfig")) -- gamepasses + Ticket boosts
local DrillConfig = require(script.Parent:WaitForChild("DrillConfig")) -- Drilling Mania Enhancer tiers

local function shop(player, passKey, boost)
	return ShopConfig.multiplier(player, passKey, boost)
end

local function skill(player, currency)
	return SkillTreeConfig.multiplier(player, currency)
end

local Multipliers = {}

local function up(player, id)
	return UpgradeConfig.valueAt(id, player:GetAttribute(UpgradeConfig.levelAttribute(id)) or 0)
end

local function prestige(player)
	return PrestigeConfig.multipliersAt(PrestigeConfig.level(player))
end

-- Cash from converting Buttons
function Multipliers.money(player)
	return up(player, "CashMultiplier")
		* up(player, "RebirthMoneyMultiplier")
		* up(player, "GemMoneyMultiplier")
		* up(player, "TimeMoneyBoost")
		* prestige(player).money
		* PrestigeConfig.treeMultiplier(player, "money")
		* RuneConfig.boost(player, "money")
		* EquipmentConfig.boost(player, "money")
		* skill(player, "Money")
		* shop(player, "x2Money", "Money")
end

-- Rebirths from rebirthing
function Multipliers.rebirths(player)
	return up(player, "GemRebirthMultiplier")
		* up(player, "TimeRebirthBoost")
		* prestige(player).rebirths
		* PrestigeConfig.treeMultiplier(player, "rebirths")
		* skill(player, "Rebirths")
end

-- Time per gain on the Time pad
function Multipliers.time(player)
	return up(player, "TimeMultiplier")
		* up(player, "GemTimeMultiplier")
		* prestige(player).time
		* PrestigeConfig.treeMultiplier(player, "time")
		* RuneConfig.boost(player, "time")
		* EquipmentConfig.boost(player, "time")
		* skill(player, "Time")
		* shop(player, "x2Time", "Time")
end

-- Buttons per click (player and Auto Clickers)
function Multipliers.buttons(player)
	return up(player, "ButtonMultiplier")
		* up(player, "RebirthButtonMultiplier")
		* up(player, "GemButtonMultiplier")
		* RuneConfig.boost(player, "buttons")
end

-- Coins (Coins island and the Tycoon)
function Multipliers.coins(player)
	return up(player, "CoinMultiplier")
		* EquipmentConfig.boost(player, "coins")
		* skill(player, "Coins")
		* shop(player, "x2Coins")
		* RuneConfig.boost(player, "coins")
end

-- DRILLING MANIA ------------------------------------------------------------------------
-- Scrap per piece picked up
function Multipliers.scrap(player)
	return up(player, "ScrapValue") * DrillConfig.enhanceBoost(player, "scrap") * RuneConfig.boost(player, "scrap")
end

-- Iron out of the Furnace
function Multipliers.iron(player)
	return up(player, "FurnaceYield") * DrillConfig.enhanceBoost(player, "iron") * RuneConfig.boost(player, "iron")
end

-- Oil every drill pumps
function Multipliers.oil(player)
	return up(player, "OilMultiplier") * DrillConfig.enhanceBoost(player, "oil") * RuneConfig.boost(player, "oil")
end

-- Chemicals (the Laboratory), on top of its upgraders + reactor
function Multipliers.chemicals(player)
	return RuneConfig.boost(player, "chemicals")
end

-- Coins from the Craft shop (on top of every normal Coins multiplier)
function Multipliers.craftCoins(player)
	return Multipliers.coins(player) * DrillConfig.enhanceBoost(player, "coins")
end

-- Gold per Wheat sold (Farm, Island 2)
function Multipliers.gold(player)
	return up(player, "FarmGoldMultiplier") * PrestigeConfig.treeMultiplier(player, "gold") * RuneConfig.boost(player, "gold") * skill(player, "Gold")
		* shop(player, "x2Gold")
end

-- Ores per ore broken (Mine, Island 2)
function Multipliers.ores(player)
	return up(player, "MineOresMultiplier") * PrestigeConfig.treeMultiplier(player, "ores") * RuneConfig.boost(player, "ores")
end

-- rune stand stats
function Multipliers.runeLuck(player)
	return RuneConfig.boost(player, "luck") * EquipmentConfig.boost(player, "runeLuck")
		* (1 + SkillTreeConfig.flat(player, "RuneLuck"))
		* shop(player, "x2RuneLuck", "RuneLuck")
end

-- how fast rune stands roll (x2 Rune Speed pass / Ticket boost)
function Multipliers.runeSpeed(player)
	return shop(player, "x2RuneSpeed", "RuneSpeed")
end

function Multipliers.runeBulk(player)
	return 1 + up(player, "RuneBulk") + RuneConfig.boost(player, "bulk") + EquipmentConfig.boost(player, "runeBulk")
		+ SkillTreeConfig.flat(player, "RuneBulk")
end

-- extra walk speed from equipment
function Multipliers.walkSpeedBonus(player)
	return EquipmentConfig.boost(player, "walkSpeed")
end

return Multipliers
