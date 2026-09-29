-- Shared by the server (UpgradeService = the real purchases and effects) and the
-- client (the Starter board = what you see).
--
-- To add an upgrade: add it to Order and Upgrades below. Its level (and unlock flag)
-- are saved automatically. Costs are in Cash unless Currency says otherwise.
--
-- ResetOnRebirth = true: the level goes back to 0 when the player rebirths.
--
-- Unlocking (the card is hidden until then):
--   UnlockCash  = appears once the player has had that much Cash
--   UnlockAfter = appears once another upgrade reaches a level
--
--   value at a level = (Base + PerLevel * level)
--   and, if MilestoneEvery is set, that is multiplied by MilestoneFactor
--   once for every MilestoneEvery levels reached (e.g. doubles at 15, 30, 45)
--   cost of the next level = floor(BaseCost * CostGrowth ^ currentLevel)
--
-- Pacing (beta = easy, tested with simulated players): new players unlock Cash
-- Multiplier in ~6-17 s and finish Button Multiplier in ~20-60 s. An active player
-- maxes everything in ~1.2 hours, a casual player in ~3 hours.
local UpgradeConfig = {}

UpgradeConfig.Order = {
	"ButtonMultiplier", "CashMultiplier", "CritChance", "CritMultiplier", "Autoclicker",
	"RebirthButtonMultiplier", "RebirthMoneyMultiplier", "RebirthCritMultiplier",
	"TimeSpeed", "TimeMultiplier", "AutoTime",
	"GemMoneyMultiplier", "GemRebirthMultiplier", "GemTimeMultiplier", "GemButtonMultiplier",
	"TimeMoneyBoost", "TimeRebirthBoost", "RuneBulk",
	"CoinMultiplier", "CoinSpawnSpeed", "AutoPickupCoins", "DropperSpeed",
	"WoodMultiplier", "DamageDealt", "ButtonCooldown",
	"FarmSpeed", "FarmGoldMultiplier",
	"MineOresMultiplier", "MineDamage", "MineSpawnSpeed", "MaxOres", "OreSpawnLuck",
	"ScrapValue", "ScrapSpawnSpeed", "ScrapCapacity", "ScrapRange",
	"ScrapBulk", "FurnaceSpeed", "FurnaceYield", "OilMultiplier",
}

UpgradeConfig.Upgrades = {
	-- more buttons from every click. Paid in Buttons: spend them here, or convert them?
	ButtonMultiplier = {
		ResetOnRebirth = true, -- back to level 0 when you rebirth
		Name = "Button Multiplier",
		Currency = "Buttons",
		MaxLevel = 4, -- 4 buys...
		DisplayLevelOffset = 1, -- ...shown as 1/5 -> 5/5 (you start on 1/5 at x1)
		BaseCost = 15, -- 15, 37, 93, 234 Buttons
		CostGrowth = 2.5,
		UnlockCash = 0, -- the first upgrade, always available
		Base = 1,
		PerLevel = 1, -- x1, x2, x3, x4, x5 buttons per click
		Kind = "multiplier",
	},

	-- multiplies the cash you get when you convert
	CashMultiplier = {
		ResetOnRebirth = true, -- back to level 0 when you rebirth
		Name = "Cash Multiplier",
		MaxLevel = 50,
		BaseCost = 25,
		CostGrowth = 1.4,
		UnlockCash = 0,
		UnlockAfter = { Upgrade = "ButtonMultiplier", Level = 2 }, -- appears at Button Multiplier 3/5 (2 buys)
		Base = 1,
		PerLevel = 2, -- x1, x3, x5, ...
		MilestoneEvery = 15, -- every 15 levels...
		MilestoneFactor = 2, -- ...the whole multiplier doubles (x29 -> x62 at level 15). Level 50 = x808
		Kind = "multiplier",
	},

	-- chance that a click is a critical click
	CritChance = {
		ResetOnRebirth = true, -- back to level 0 when you rebirth
		Name = "Critical Chance",
		MaxLevel = 10,
		BaseCost = 60,
		CostGrowth = 3.5,
		UnlockCash = 50, -- appears once you have had 50 Cash
		Base = 0,
		PerLevel = 0.03, -- 0% -> 30%
		Kind = "percent",
	},

	-- how many times more buttons a critical click gives
	CritMultiplier = {
		ResetOnRebirth = true, -- back to level 0 when you rebirth
		Name = "Critical Multiplier",
		MaxLevel = 15,
		BaseCost = 75,
		CostGrowth = 2.6,
		UnlockCash = 50, -- appears once you have had 50 Cash
		Base = 2,
		PerLevel = 0.25, -- x2 -> x5.75
		Kind = "multiplier",
	},
	-- every level adds one cursor that taps the red button for you (Button Multiplier and
	-- criticals apply, but no combo: only the player's own clicks build the combo).
	-- A Rebirth Boosts upgrade: paid in Rebirths, and kept when you rebirth.
	Autoclicker = {
		Name = "Auto Clicker",
		Currency = "Rebirths",
		MaxLevel = 8,
		BaseCost = 5, -- 5, 60, 720, 8.6K, 103K, 1.2M, 14.9M, 179M Rebirths
		CostGrowth = 12,
		UnlockCash = 0,
		Base = 0,
		PerLevel = 1, -- clicks per second (one click per AutoClickInterval for each level)
		Kind = "rate",
	},

	-- multiplies your Button Multiplier upgrade: more buttons from every click (stacks on top)
	RebirthButtonMultiplier = {
		Name = "Rebirth Buttons",
		Currency = "Rebirths",
		MaxLevel = 4,
		DisplayLevelOffset = 1, -- shown 1/5 -> 5/5, like the Button Multiplier on the Starter board
		BaseCost = 10, -- 10, 1.5K, 225K, 33.7M Rebirths
		CostGrowth = 150,
		UnlockCash = 0,
		Base = 1,
		PerLevel = 1, -- x1 -> x5
		Kind = "multiplier",
	},

	-- multiplies your Cash Multiplier upgrade (stacks on top of it)
	RebirthMoneyMultiplier = {
		Name = "Rebirth Money",
		Currency = "Rebirths",
		MaxLevel = 25,
		BaseCost = 3,
		CostGrowth = 2.4, -- 3, 7, 17, 41, 99, ... ~4B Rebirths for the last level
		UnlockCash = 0,
		Base = 1,
		PerLevel = 1, -- x1 -> x26
		Kind = "multiplier",
	},

	-- multiplies your Critical Multiplier upgrade (stacks on top of it)
	RebirthCritMultiplier = {
		Name = "Rebirth Critical",
		Currency = "Rebirths",
		MaxLevel = 10,
		BaseCost = 25,
		CostGrowth = 7, -- 25, 175, 1.2K, 8.5K, ... ~1B Rebirths for the last level
		UnlockCash = 0,
		Base = 1,
		PerLevel = 1, -- x1 -> x11
		Kind = "multiplier",
	},
	-- TIME (Time board, on the Time island) --------------------------------------------
	-- Time is earned by standing on the Time button (or anywhere, with Auto Time).
	-- Pacing: Auto Time around 13 min, everything maxed ~27 min, 10K Time held ~20 min.

	-- seconds between Time gains
	TimeSpeed = {
		Name = "Time Speed",
		Currency = "Time",
		MaxLevel = 9,
		BaseCost = 50, -- 50, 105, 220, 463, 972, ... ~18.9K Time
		CostGrowth = 2.1,
		UnlockCash = 0,
		Base = 1,
		PerLevel = -0.1, -- 1.0s -> 0.1s
		Kind = "seconds",
	},

	-- Time gained per tick
	TimeMultiplier = {
		Name = "Time Multiplier",
		Currency = "Time",
		MaxLevel = 50,
		BaseCost = 20, -- 20, 23, 26, ... ~28K Time
		CostGrowth = 1.16,
		UnlockCash = 0,
		Base = 1,
		PerLevel = 1, -- x1 -> x51
		Kind = "multiplier",
	},

	-- earn Time anywhere, without standing on the button
	AutoTime = {
		Name = "Auto Time",
		Currency = "Time",
		MaxLevel = 1,
		BaseCost = 5000,
		CostGrowth = 1,
		UnlockCash = 0,
		Base = 0,
		PerLevel = 1,
		Kind = "toggle",
	},

	-- GEMS (Gems board, on the Time island) --------------------------------------------
	-- Gems are a limited currency: the game doesn't hand any out on its own.

	GemMoneyMultiplier = {
		Name = "Money Multiplier",
		Currency = "Gems",
		MaxLevel = 20,
		BaseCost = 1,
		CostGrowth = 1.4,
		UnlockCash = 0,
		Base = 1,
		PerLevel = 0.5, -- x1 -> x11 on all Cash earned
		Kind = "multiplier",
	},

	GemRebirthMultiplier = {
		Name = "Rebirths Multiplier",
		Currency = "Gems",
		MaxLevel = 20,
		BaseCost = 5,
		CostGrowth = 1.4,
		UnlockCash = 0,
		Base = 1,
		PerLevel = 0.5, -- x1 -> x11 on all Rebirths earned
		Kind = "multiplier",
	},

	GemTimeMultiplier = {
		Name = "Time Multiplier",
		Currency = "Gems",
		MaxLevel = 20,
		BaseCost = 20,
		CostGrowth = 1.4,
		UnlockCash = 0,
		Base = 1,
		PerLevel = 0.5, -- x1 -> x11 on all Time earned
		Kind = "multiplier",
	},

	GemButtonMultiplier = {
		Name = "Buttons Multiplier",
		Currency = "Gems",
		MaxLevel = 20,
		BaseCost = 25,
		CostGrowth = 1.4,
		UnlockCash = 0,
		Base = 1,
		PerLevel = 0.5, -- x1 -> x11 on all Buttons earned
		Kind = "multiplier",
	},
	-- TIME BOOSTS (TimeBoosts board, unlocks at 100 Time) --------------------------------
	TimeMoneyBoost = {
		Name = "Time Money Boost",
		Currency = "Time",
		MaxLevel = 25,
		BaseCost = 50, -- 50, 67, 91, ... ~67K Time
		CostGrowth = 1.35,
		UnlockCash = 0,
		Base = 1,
		PerLevel = 1, -- x1 -> x26 on all Cash
		Kind = "multiplier",
	},

	TimeRebirthBoost = {
		Name = "Time Rebirth Boost",
		Currency = "Time",
		MaxLevel = 25,
		BaseCost = 100, -- 100, 135, 182, ... ~134K Time
		CostGrowth = 1.35,
		UnlockCash = 0,
		Base = 1,
		PerLevel = 1, -- x1 -> x26 on all Rebirths
		Kind = "multiplier",
	},

	-- +1 rune per roll per level (TimeBoosts board)
	RuneBulk = {
		Name = "Time Rune Bulk",
		Currency = "Time",
		MaxLevel = 5,
		BaseCost = 10000, -- 10K, 25K, 62K, 156K, 390K Time
		CostGrowth = 2.5,
		UnlockCash = 0,
		Base = 0,
		PerLevel = 1,
		Kind = "plus",
	},

	-- COINS (Coins board, Coins island - Prestige 2) ----------------------------------------
	CoinMultiplier = {
		Name = "Coin Multiplier",
		Currency = "Coins",
		MaxLevel = 20,
		BaseCost = 10, -- 10, 16, 25, 40, 65, ... ~74K Coins
		CostGrowth = 1.6,
		UnlockCash = 0,
		Base = 1,
		PerLevel = 0.5, -- x1 -> x11 on all Coins
		Kind = "multiplier",
	},

	CoinSpawnSpeed = {
		Name = "Coin Spawn Speed",
		Currency = "Coins",
		MaxLevel = 10,
		BaseCost = 15, -- 15, 25, 43, ... ~1.8K Coins
		CostGrowth = 1.7,
		UnlockCash = 0,
		Base = 3,
		PerLevel = -0.2, -- 3.0s -> 1.0s between coin spawns
		Kind = "seconds",
	},

	AutoPickupCoins = {
		Name = "Auto Pickup Coins",
		Currency = "Coins",
		MaxLevel = 1,
		BaseCost = 500,
		CostGrowth = 1,
		UnlockCash = 0,
		Base = 0,
		PerLevel = 1,
		Kind = "toggle",
	},

	-- TYCOON (Tycoon board - Prestige 3) ----------------------------------------------------
	DropperSpeed = {
		Name = "Dropper Speed",
		Currency = "Coins",
		MaxLevel = 20,
		BaseCost = 1000, -- 1K, 1.6K, 2.6K, ... ~7.5M Coins
		CostGrowth = 1.6,
		UnlockCash = 0,
		Base = 0,
		PerLevel = -0.15, -- 0s -> -3s off every automatic dropper (never below 0.75s)
		Kind = "secondsDelta",
	},

	-- WOOD (Tree Upgrades board, Island 2) - reset when you Tier Up ----------------------
	WoodMultiplier = {
		Name = "Wood Multiplier",
		Currency = "Wood",
		MaxLevel = 20,
		BaseCost = 15, -- 15, 20, 27, ... ~4.5K Wood
		CostGrowth = 1.35,
		UnlockCash = 0,
		Base = 1,
		PerLevel = 1, -- x1 -> x21 Wood per tree
		Kind = "multiplier",
		ResetOnTier = true,
	},

	DamageDealt = {
		Name = "Damage Dealt",
		Currency = "Wood",
		MaxLevel = 20,
		BaseCost = 20, -- 20, 28, 39, ... ~11K Wood
		CostGrowth = 1.4,
		UnlockCash = 0,
		Base = 0,
		PerLevel = 1, -- +0 -> +20 damage per click
		Kind = "plus",
		ResetOnTier = true,
	},

	ButtonCooldown = {
		Name = "Button Cooldown",
		Currency = "Wood",
		MaxLevel = 20,
		BaseCost = 25, -- 25, 35, 49, ... ~15K Wood
		CostGrowth = 1.4,
		UnlockCash = 0,
		Base = 1,
		PerLevel = -0.03, -- x1 -> x0.4 of the Blue Button's cooldown
		Kind = "multiplier",
		ResetOnTier = true,
	},
	-- MINE (Mine + MineBoosts boards, Island 2) - paid in Ores ----------------------------
	MineOresMultiplier = {
		Name = "Ores Multiplier",
		Currency = "Ores",
		MaxLevel = 20,
		BaseCost = 10, -- 10, 16, 25, ... ~76K Ores
		CostGrowth = 1.6,
		UnlockCash = 0,
		Base = 1,
		PerLevel = 1, -- x1 -> x21 Ores per ore broken
		Kind = "multiplier",
	},

	MineDamage = {
		Name = "Damage",
		Currency = "Ores",
		MaxLevel = 25,
		BaseCost = 12, -- 12, 20, 34, ... ~4.7M Ores
		CostGrowth = 1.7,
		UnlockCash = 0,
		Base = 0,
		PerLevel = 1, -- +0 -> +25 damage per click (on top of 1)
		Kind = "plus",
	},

	MineSpawnSpeed = {
		Name = "Spawn Speed",
		Currency = "Ores",
		MaxLevel = 15,
		BaseCost = 15, -- 15, 24, 38, ... ~11K Ores
		CostGrowth = 1.6,
		UnlockCash = 0,
		Base = 0,
		PerLevel = -0.15, -- 3s -> 0.75s between ores
		Kind = "secondsDelta",
	},

	MaxOres = {
		Name = "Max Ores",
		Currency = "Ores",
		MaxLevel = 23,
		BaseCost = 10, -- 10, 30, 90, ... ~314B Ores (the big late-game sink)
		CostGrowth = 3,
		UnlockCash = 0,
		Base = 0,
		PerLevel = 1, -- 1 -> 24 ores out at once
		Kind = "plus",
	},

	OreSpawnLuck = {
		Name = "Ore Spawn Luck",
		Currency = "Ores",
		MaxLevel = 20,
		BaseCost = 50, -- 50, 90, 162, ... ~3.4M Ores
		CostGrowth = 1.8,
		UnlockCash = 0,
		Base = 1,
		PerLevel = 0.1, -- x1 -> x3 luck for rarer ores
		Kind = "multiplier",
	},

	-- FARM (Farm board, Island 2) - paid in Gold ------------------------------------------
	FarmSpeed = {
		Name = "Grow Speed",
		Currency = "Gold",
		MaxLevel = 20,
		BaseCost = 50, -- 50, 80, 128, ... ~379K Gold
		CostGrowth = 1.6,
		UnlockCash = 0,
		Base = 0,
		PerLevel = -0.1, -- 3s -> 1s per wheat growth stage
		Kind = "secondsDelta",
	},

	FarmGoldMultiplier = {
		Name = "Gold Multiplier",
		Currency = "Gold",
		MaxLevel = 20,
		BaseCost = 50, -- 50, 90, 162, ... ~3.4M Gold
		CostGrowth = 1.8,
		UnlockCash = 0,
		Base = 1,
		PerLevel = 0.5, -- x1 -> x11 Gold when selling Wheat
		Kind = "multiplier",
	},

	-- DRILLING MANIA (the two scrap boards by the scrap field). Drill = true: kept on
	-- Prestige, reset by the Enhancer instead. -------------------------------------------
	ScrapValue = {
		Name = "Scrap Value", Desc = "More Scrap from every piece you pick up!",
		Currency = "Scrap", Drill = true,
		MaxLevel = 25, BaseCost = 15, CostGrowth = 1.45, -- 15, 21, 31, ... ~110K Scrap
		UnlockCash = 0, Base = 1, PerLevel = 0.5, -- x1 -> x13.5
		Kind = "multiplier",
	},

	ScrapSpawnSpeed = {
		Name = "Spawn Speed", Desc = "Scrap shows up faster on the field!",
		Currency = "Scrap", Drill = true,
		MaxLevel = 10, BaseCost = 25, CostGrowth = 1.9, -- 25 ... ~8K Scrap
		UnlockCash = 0, Base = 1.5, PerLevel = -0.1, -- 1.5s -> 0.5s
		Kind = "seconds",
	},

	ScrapCapacity = {
		Name = "Scrap Capacity", Desc = "More Scrap can lie on the field at once!",
		Currency = "Scrap", Drill = true,
		MaxLevel = 16, BaseCost = 20, CostGrowth = 1.6, -- 20 ... ~23K Scrap
		UnlockCash = 0, Base = 20, PerLevel = 5, -- 20 -> 100 pieces
		Kind = "number",
	},

	ScrapRange = {
		Name = "Pickup Range", Desc = "Grab Scrap from further away!",
		Currency = "Scrap", Drill = true,
		MaxLevel = 14, BaseCost = 30, CostGrowth = 1.7, -- 30 ... ~30K Scrap
		UnlockCash = 0, Base = 6, PerLevel = 1, -- 6 -> 20 studs
		Kind = "studs",
	},

	ScrapBulk = {
		Name = "Bulk Respawn", Desc = "More Scrap spawns every time!",
		Currency = "Metal", Drill = true,
		MaxLevel = 9, BaseCost = 5, CostGrowth = 2.2, -- 5 ... ~2.8K Iron
		UnlockCash = 0, Base = 1, PerLevel = 1, -- 1 -> 10 per spawn
		Kind = "number",
	},

	FurnaceSpeed = {
		Name = "Furnace Speed", Desc = "The Furnace cooks Scrap faster!",
		Currency = "Metal", Drill = true,
		MaxLevel = 12, BaseCost = 10, CostGrowth = 1.9, -- 10 ... ~11K Iron
		UnlockCash = 0, Base = 1, PerLevel = 0.25, -- x1 -> x4 speed
		Kind = "multiplier",
	},

	FurnaceYield = {
		Name = "Iron Yield", Desc = "More Iron out of every Scrap you cook!",
		Currency = "Metal", Drill = true,
		MaxLevel = 20, BaseCost = 8, CostGrowth = 1.65, -- 8 ... ~110K Iron
		UnlockCash = 0, Base = 1, PerLevel = 0.25, -- x1 -> x6
		Kind = "multiplier",
	},

	OilMultiplier = {
		Name = "Oil Multiplier", Desc = "Every drill pumps more Oil!",
		Currency = "Metal", Drill = true,
		MaxLevel = 20, BaseCost = 20, CostGrowth = 1.7, -- 20 ... ~480K Iron
		UnlockCash = 0, Base = 1, PerLevel = 0.5, -- x1 -> x11
		Kind = "multiplier",
	},
}

-- a prestige resets every upgrade level except the ones paid in Gems (Gems are limited)
function UpgradeConfig.resetsOnPrestige(id)
	-- Island 2 (Wood) has its own reset: Tiers
	local currency = UpgradeConfig.Upgrades[id].Currency
	return currency ~= "Gems" and currency ~= "Wood" and currency ~= "Gold" and currency ~= "Ores"
		and not UpgradeConfig.Upgrades[id].Drill
end

function UpgradeConfig.levelAttribute(id)
	return "Upgrade_" .. id
end

function UpgradeConfig.unlockAttribute(id)
	return "Unlocked_" .. id
end

-- the level number shown on the card ("1/5" when the saved level is 0 for Button Multiplier)
function UpgradeConfig.displayLevel(id, level)
	local def = UpgradeConfig.Upgrades[id]
	local offset = def.DisplayLevelOffset or 0

	return level + offset, def.MaxLevel + offset
end

-- which currency an upgrade is paid in ("Cash", "Buttons", or "Rebirths").
-- `level` matters for upgrades with a CurrencySplit (Autoclicker switches to Rebirths at level 8+)
function UpgradeConfig.currencyOf(id, level)
	local def = UpgradeConfig.Upgrades[id]
	local split = def.CurrencySplit

	if split and (level or 0) >= split.AtLevel then
		return split.Currency
	end

	return def.Currency or "Cash"
end

-- does this upgrade start hidden?
function UpgradeConfig.needsUnlock(id)
	local def = UpgradeConfig.Upgrades[id]

	return (def.UnlockCash or 0) > 0 or def.UnlockAfter ~= nil
end

-- is the upgrade available to this player? (works on the server and the client)
function UpgradeConfig.isUnlocked(player, id)
	if not UpgradeConfig.needsUnlock(id) then
		return true
	end

	-- anyone who already owns levels keeps it
	if (player:GetAttribute(UpgradeConfig.levelAttribute(id)) or 0) > 0 then
		return true
	end

	return player:GetAttribute(UpgradeConfig.unlockAttribute(id)) == 1
end

-- has the player met the unlock condition right now?
function UpgradeConfig.meetsUnlock(player, id)
	local def = UpgradeConfig.Upgrades[id]

	if (def.UnlockCash or 0) > 0 and (player:GetAttribute("Cash") or 0) < def.UnlockCash then
		return false
	end

	if def.UnlockAfter then
		local level = player:GetAttribute(UpgradeConfig.levelAttribute(def.UnlockAfter.Upgrade)) or 0

		if level < def.UnlockAfter.Level then
			return false
		end
	end

	return true
end

-- the upgrade's effect at a level
function UpgradeConfig.valueAt(id, level)
	local def = UpgradeConfig.Upgrades[id]

	level = math.clamp(level, 0, def.MaxLevel)

	local value = def.Base + def.PerLevel * level

	if def.MilestoneEvery then
		value *= (def.MilestoneFactor or 2) ^ math.floor(level / def.MilestoneEvery)
	end

	return value
end

-- cost of the next level when you are at `level` (in whatever currency applies at that level)
function UpgradeConfig.costAt(id, level)
	local def = UpgradeConfig.Upgrades[id]
	local split = def.CurrencySplit

	if split and level >= split.AtLevel then
		return math.floor(split.BaseCost * split.CostGrowth ^ (level - split.AtLevel))
	end

	return math.floor(def.BaseCost * def.CostGrowth ^ level)
end

-- how many levels an amount of ONE currency can buy from `level`, and what they cost.
-- If the upgrade's currency changes partway (Autoclicker's CurrencySplit), this stops
-- right before the switch, so a single purchase never mixes two currencies.
function UpgradeConfig.affordable(id, level, cash)
	local def = UpgradeConfig.Upgrades[id]
	local split = def.CurrencySplit
	local startCurrency = UpgradeConfig.currencyOf(id, level)
	local count, total = 0, 0

	while level + count < def.MaxLevel do
		if split and level + count == split.AtLevel and startCurrency ~= split.Currency then
			break
		end

		local cost = UpgradeConfig.costAt(id, level + count)

		if total + cost > cash then
			break
		end

		total += cost
		count += 1
	end

	return count, total
end

-- 0.25 -> "x0.25", 1.5 -> "x1.5", 3 -> "x3", 0.12 (percent) -> "12%"
function UpgradeConfig.formatValue(id, value)
	local def = UpgradeConfig.Upgrades[id]

	if def.Kind == "percent" then
		return string.format("%d%%", math.floor(value * 100 + 0.5))
	end

	if def.Kind == "rate" then
		return string.format("%d/s", math.floor(value + 0.5))
	end

	if def.Kind == "seconds" then
		return string.format("%.1fs", value)
	end

	if def.Kind == "secondsDelta" then
		if math.abs(value) < 0.001 then
			return "0s"
		end

		return string.format("%.2fs", value):gsub("0+s$", "s"):gsub("%.s$", "s")
	end

	if def.Kind == "number" then
		return tostring(math.floor(value + 0.5))
	end

	if def.Kind == "studs" then
		return math.floor(value + 0.5) .. " studs"
	end

	if def.Kind == "plus" then
		return "+" .. math.floor(value + 0.5)
	end

	if def.Kind == "toggle" then
		return value >= 1 and "On" or "Off"
	end

	local text = string.format("%.2f", value)
	text = text:gsub("0+$", "")
	text = text:gsub("%.$", "")

	return "x" .. text
end

return UpgradeConfig
