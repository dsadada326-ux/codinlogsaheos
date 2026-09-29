-- Rune stands (Workspace.Runes.<Pool>). Stand inside a stand's Hitbox to roll it once
-- every RollInterval seconds, as long as you can pay. Each roll gives `bulk` runes.
--
-- Every rune you own counts toward its boost levels: reach a level's `need` count and
-- that rune's boost becomes active. Boosts multiply the matching Multipliers:
--   money / time / buttons / wood / gold / ores / fishmeal / fishluck / shells / scrap / iron / oil / coins -> x value,  luck -> rarer runes more often,  bulk -> + runes per roll
--
-- chance = % chance per roll (luck multiplies the chance of every non-common rune).
local RuneConfig = {}

RuneConfig.RollInterval = 1 -- seconds between rolls while standing in a stand

-- level thresholds shared by every rune: owning 1, 10, 100, 1K, 10K of it
RuneConfig.LevelNeeds = { 1, 10, 100, 1000, 10000 }

RuneConfig.Pools = {
	Starter = {
		order = 1,
		currency = "Cash", cost = 1e7, -- per roll
		unlock = { prestige = 1, text = "Unlocks at 1 Prestige" },
		runes = {
			{ name = "Common", chance = 70, boosts = { money = { 1.1, 1.2, 1.35, 1.6, 2 } } },
			{ name = "Rare", chance = 22, boosts = { money = { 1.2, 1.4, 1.6, 1.9, 2.3 } } },
			{ name = "Epic", chance = 6, boosts = { money = { 1.4, 1.7, 2, 2.4, 3 }, bulk = { 1, 1, 1, 1, 1 } } },
			{ name = "Legendary", chance = 1.5, boosts = { money = { 1.6, 2, 2.4, 2.8, 3.4 }, luck = { 1.1, 1.2, 1.3, 1.4, 1.5 } } },
			{ name = "Mythic", chance = 0.4, boosts = { money = { 1.8, 2.2, 2.6, 3.1, 3.7 }, luck = { 1.1, 1.2, 1.3, 1.4, 1.5 } } },
			{ name = "Godly", chance = 0.08, boosts = { money = { 2, 2.5, 3, 3.5, 4 }, bulk = { 1, 2, 2, 3, 3 } } },
			{ name = "Underworld", chance = 0.015, boosts = { money = { 2.2, 2.7, 3.2, 3.8, 4.5 }, luck = { 1.25, 1.5, 1.75, 2, 2.5 } } },
			{ name = "Ascension", chance = 0.002, boosts = { money = { 2.5, 3, 3.5, 4.2, 5 }, bulk = { 2, 2, 3, 3, 4 } } },
		},
	},

	Time = {
		order = 2,
		currency = "Time", cost = 1000,
		unlock = { time = 50000, text = "Unlocks at 50K Time" },
		runes = {
			{ name = "Clock", chance = 65, boosts = { money = { 1.3, 1.5, 1.7, 2, 2.4 }, time = { 1.15, 1.25, 1.4, 1.6, 1.8 } } },
			{ name = "Slow", chance = 27, boosts = { money = { 1.4, 1.6, 1.8, 2.1, 2.5 }, time = { 1.2, 1.35, 1.5, 1.75, 2 }, luck = { 1.05, 1.1, 1.15, 1.2, 1.3 } } },
			{ name = "Fast", chance = 6, boosts = { money = { 1.6, 1.8, 2.1, 2.4, 2.8 }, time = { 1.3, 1.5, 1.7, 2, 2.3 } } },
			{ name = "Quick", chance = 1.5, boosts = { money = { 1.8, 2.1, 2.4, 2.8, 3.3 }, time = { 1.4, 1.6, 1.8, 2.1, 2.4 }, bulk = { 1, 1, 1, 1, 2 } } },
			{ name = "SuperSpeed", chance = 0.15, boosts = { money = { 2, 2.4, 2.8, 3.2, 3.8 }, time = { 1.5, 1.7, 2, 2.3, 2.6 }, bulk = { 1, 2, 2, 2, 3 } } },
			{ name = "OverClocked", chance = 0.01, boosts = { money = { 2.5, 3.2, 4, 5, 6 }, time = { 1.6, 1.9, 2.2, 2.5, 3 }, bulk = { 2, 2, 3, 3, 4 } } },
		},
	},

	Buttons = {
		order = 3,
		currency = "Buttons", cost = 100,
		unlock = { prestigeOrTree = { prestige = 3, tree = "Upgrade14" }, text = "Unlocks at 3 Prestiges" },
		runes = {
			{ name = "Tapper", chance = 60, boosts = { buttons = { 1.2, 1.35, 1.5, 1.8, 2.2 } } },
			{ name = "Presser", chance = 28, boosts = { buttons = { 1.3, 1.5, 1.75, 2.1, 2.6 }, money = { 1.1, 1.2, 1.3, 1.5, 1.7 } } },
			{ name = "Clicker", chance = 9, boosts = { buttons = { 1.5, 1.8, 2.1, 2.5, 3 }, luck = { 1.05, 1.1, 1.15, 1.2, 1.3 } } },
			{ name = "Buttoner", chance = 2.5, boosts = { buttons = { 1.8, 2.2, 2.6, 3.1, 3.7 }, bulk = { 1, 1, 1, 2, 2 } } },
			{ name = "Button Master", chance = 0.4, boosts = { buttons = { 2.2, 2.7, 3.2, 3.8, 4.5 }, money = { 1.5, 1.8, 2.1, 2.5, 3 } } },
			{ name = "Button Legend", chance = 0.03, boosts = { buttons = { 3, 3.6, 4.3, 5.2, 6.5 }, luck = { 1.3, 1.6, 1.9, 2.2, 2.6 }, bulk = { 2, 2, 3, 3, 4 } } },
		},
	},

	-- Island 2 stands. Chances are placeholders (copied from Time) - change them freely.
	Wood = {
		order = 4,
		currency = "Wood", cost = 100,
		unlock = { island2 = true, text = "Unlocks on Island 2" },
		runes = {
			{ name = "Oak", chance = 65, boosts = { wood = { 1.2, 1.35, 1.5, 1.8, 2.2 } } },
			{ name = "Birch", chance = 27, boosts = { wood = { 1.3, 1.5, 1.75, 2.1, 2.6 }, money = { 1.1, 1.2, 1.3, 1.5, 1.7 } } },
			{ name = "DarkOak", chance = 6, boosts = { wood = { 1.5, 1.8, 2.1, 2.5, 3 }, luck = { 1.05, 1.1, 1.15, 1.2, 1.3 } } },
			{ name = "Acacia", chance = 1.5, boosts = { wood = { 1.8, 2.2, 2.6, 3.1, 3.7 }, bulk = { 1, 1, 1, 2, 2 } } },
			{ name = "Cherry", chance = 0.15, boosts = { wood = { 2.2, 2.7, 3.2, 3.8, 4.5 }, money = { 1.5, 1.8, 2.1, 2.5, 3 } } },
			{ name = "FrostWood", chance = 0.01, boosts = { wood = { 3, 3.6, 4.3, 5.2, 6.5 }, luck = { 1.3, 1.6, 1.9, 2.2, 2.6 }, bulk = { 2, 2, 3, 3, 4 } } },
		},
	},

	Gold = {
		order = 6,
		currency = "Gold", cost = 100,
		unlock = { island2 = true, text = "Unlocks on Island 2" },
		runes = {
			{ name = "Flake", chance = 65, boosts = { gold = { 1.2, 1.35, 1.5, 1.8, 2.2 } } },
			{ name = "Pebble", chance = 27, boosts = { gold = { 1.3, 1.5, 1.75, 2.1, 2.6 }, money = { 1.1, 1.2, 1.3, 1.5, 1.7 } } },
			{ name = "Rock", chance = 6, boosts = { gold = { 1.5, 1.8, 2.1, 2.5, 3 }, luck = { 1.05, 1.1, 1.15, 1.2, 1.3 } } },
			{ name = "Bar", chance = 1.5, boosts = { gold = { 1.8, 2.2, 2.6, 3.1, 3.7 }, bulk = { 1, 1, 1, 2, 2 } } },
			{ name = "Liquid", chance = 0.15, boosts = { gold = { 2.2, 2.7, 3.2, 3.8, 4.5 }, money = { 1.5, 1.8, 2.1, 2.5, 3 } } },
			{ name = "Solid", chance = 0.01, boosts = { gold = { 3, 3.6, 4.3, 5.2, 6.5 }, luck = { 1.3, 1.6, 1.9, 2.2, 2.6 }, bulk = { 2, 2, 3, 3, 4 } } },
		},
	},

	Ore = {
		order = 5,
		currency = "Ores", cost = 100,
		unlock = { island2 = true, text = "Unlocks on Island 2" },
		runes = {
			{ name = "Copper", chance = 65, boosts = { ores = { 1.2, 1.35, 1.5, 1.8, 2.2 } } },
			{ name = "Coal", chance = 27, boosts = { ores = { 1.3, 1.5, 1.75, 2.1, 2.6 }, money = { 1.1, 1.2, 1.3, 1.5, 1.7 } } },
			{ name = "Iron", chance = 6, boosts = { ores = { 1.5, 1.8, 2.1, 2.5, 3 }, luck = { 1.05, 1.1, 1.15, 1.2, 1.3 } } },
			{ name = "Gold", chance = 1.5, boosts = { ores = { 1.8, 2.2, 2.6, 3.1, 3.7 }, bulk = { 1, 1, 1, 2, 2 } } },
			{ name = "Emerald", chance = 0.15, boosts = { ores = { 2.2, 2.7, 3.2, 3.8, 4.5 }, money = { 1.5, 1.8, 2.1, 2.5, 3 } } },
			{ name = "Diamond", chance = 0.01, boosts = { ores = { 3, 3.6, 4.3, 5.2, 6.5 }, luck = { 1.3, 1.6, 1.9, 2.2, 2.6 }, bulk = { 2, 2, 3, 3, 4 } } },
		},
	},

	-- Fishing Frenzy stand (Workspace.Runes.Beachy). Needs Fish Tier 1 (or any Fish Prestige).
	Beachy = {
		order = 7,
		currency = "FishMeal", cost = 250,
		unlock = { fishTier = 1, text = "Unlocks at Fish Tier 1" },
		runes = {
			{ name = "Seashell", chance = 65, boosts = { fishmeal = { 1.1, 1.2, 1.35, 1.55, 1.8 } } },
			{ name = "Starfish", chance = 27, boosts = { fishmeal = { 1.15, 1.3, 1.5, 1.75, 2.1 }, shells = { 1.1, 1.2, 1.3, 1.45, 1.6 } } },
			{ name = "Pearl", chance = 6, boosts = { shells = { 1.25, 1.45, 1.7, 2, 2.4 }, luck = { 1.05, 1.1, 1.15, 1.2, 1.3 } } },
			{ name = "Coral", chance = 1.5, boosts = { fishluck = { 1.1, 1.2, 1.3, 1.45, 1.6 }, fishmeal = { 1.2, 1.4, 1.6, 1.9, 2.3 } } },
			{ name = "Treasure", chance = 0.15, boosts = { fishmeal = { 1.5, 1.8, 2.1, 2.5, 3 }, bulk = { 1, 1, 1, 2, 2 } } },
			{ name = "Kraken", chance = 0.01, boosts = { fishmeal = { 2, 2.4, 2.8, 3.3, 4 }, fishluck = { 1.25, 1.5, 1.75, 2, 2.4 }, bulk = { 2, 2, 3, 3, 4 } } },
		},
	},

	-- Drilling Mania stand (Workspace.Runes.Coin), paid in Coins. Boosts the drilling currencies.
	Coin = {
		order = 8,
		currency = "Coins", cost = 500,
		unlock = { text = "Drilling Mania" },
		runes = {
			{ name = "Bolt", chance = 65, boosts = { scrap = { 1.15, 1.3, 1.5, 1.8, 2.2 } } },
			{ name = "Cog", chance = 27, boosts = { scrap = { 1.2, 1.4, 1.65, 2, 2.5 }, oil = { 1.1, 1.2, 1.3, 1.5, 1.7 } } },
			{ name = "Ingot", chance = 6, boosts = { iron = { 1.25, 1.5, 1.8, 2.2, 2.7 }, luck = { 1.05, 1.1, 1.15, 1.2, 1.3 } } },
			{ name = "Barrel", chance = 1.5, boosts = { oil = { 1.3, 1.6, 1.9, 2.3, 2.8 }, coins = { 1.1, 1.2, 1.35, 1.5, 1.7 } } },
			{ name = "Refinery", chance = 0.15, boosts = { oil = { 1.6, 2, 2.4, 2.9, 3.5 }, coins = { 1.3, 1.5, 1.8, 2.1, 2.5 }, bulk = { 1, 1, 1, 2, 2 } } },
			{ name = "Tycoon", chance = 0.01, boosts = { coins = { 2, 2.5, 3, 3.6, 4.5 }, oil = { 2, 2.4, 2.8, 3.3, 4 }, bulk = { 2, 2, 3, 3, 4 } } },
		},
	},

	-- Global Runes: no stand, only from the Shop (Global Runes open for everyone in the server).
	-- These runes have their own level steps (`needs`) instead of the shared LevelNeeds.
	Global = {
		order = 9,
		noStand = true,
		currency = "Cash", cost = 0,
		unlock = { shopOnly = true, text = "Get these in the Shop!" },
		runes = {
			{ name = "Orbit", chance = 60, needs = { 5, 50, 500, 5000, 15000 },
				boosts = { money = { 2, 2.5, 3, 4, 5 } } },
			{ name = "Comet", chance = 28, needs = { 5, 50, 500, 5000, 15000 },
				boosts = { money = { 3, 4, 5, 6, 7.5 } } },
			{ name = "Nova", chance = 9, needs = { 5, 50, 500, 5000, 15000 },
				boosts = { money = { 5, 6, 7.5, 9, 11 }, bulk = { 0, 0, 1, 1, 1 } } },
			{ name = "Nebula", chance = 2.5, needs = { 5, 50, 500, 5000, 15000 },
				boosts = { money = { 8, 10, 12, 14, 16 }, bulk = { 1, 1, 2, 2, 2 } } },
			{ name = "Galaxy", chance = 0.45, needs = { 3, 15, 50, 150, 500 },
				boosts = { money = { 12, 15, 18, 21, 25 }, bulk = { 2, 2, 3, 3, 4 } } },
			{ name = "Cosmos", chance = 0.05, needs = { 3, 10, 25, 50, 100 },
				boosts = { money = { 20, 24, 28, 34, 40 }, bulk = { 3, 3, 4, 4, 5 } } },
		},
	},
}

function RuneConfig.countAttribute(pool, rune)
	return "Rune_" .. pool .. "_" .. rune:gsub("%s", "")
end

function RuneConfig.openedAttribute(pool)
	return "RunesOpened_" .. pool
end

-- a rune's level steps (its own `needs`, or the shared LevelNeeds)
function RuneConfig.needsFor(rune)
	return rune and rune.needs or RuneConfig.LevelNeeds
end

-- which boost level (0 = none) a count reaches (`needs` = a rune's own steps, optional)
function RuneConfig.levelFor(count, needs)
	local level = 0

	for i, need in ipairs(needs or RuneConfig.LevelNeeds) do
		if count >= need then
			level = i
		end
	end

	return level
end

-- is this pool open for the player? (needs PrestigeConfig for tree/prestige checks)
function RuneConfig.isUnlocked(player, poolName)
	local pool = RuneConfig.Pools[poolName]
	local unlock = pool.unlock

	if unlock.comingSoon or unlock.shopOnly then
		return false -- (shop-only runes come from the Shop, never a stand)
	end

	if unlock.island2 and player:GetAttribute("Island2Unlocked") ~= true then
		return false
	end

	if unlock.prestige and (player:GetAttribute("Prestige") or 0) < unlock.prestige then
		return false
	end

	-- Fishing Frenzy: Fish Tier (resets on Fish Prestige, so any Fish Prestige keeps it open)
	if unlock.fishTier and (player:GetAttribute("FishTier") or 0) < unlock.fishTier and (player:GetAttribute("FishPrestige") or 0) < 1 then
		return false
	end

	if unlock.time and player:GetAttribute("Unlocked_Rune_" .. poolName) ~= true then
		return false -- the Time requirement is checked once and saved (Time resets on prestige)
	end

	if unlock.tree and player:GetAttribute("Tree_" .. unlock.tree) ~= true then
		return false
	end

	-- either one opens it (Prestige 3, or buying that Upgrade Tree node first)
	if unlock.prestigeOrTree then
		local rule = unlock.prestigeOrTree
		local byPrestige = (player:GetAttribute("Prestige") or 0) >= rule.prestige
		local byTree = player:GetAttribute("Tree_" .. rule.tree) == true

		if not byPrestige and not byTree then
			return false
		end
	end

	return true
end

-- product of one boost across every rune the player owns (money / time / buttons / luck),
-- or the sum for bulk
function RuneConfig.boost(player, kind)
	local total = kind == "bulk" and 0 or 1

	for poolName, pool in pairs(RuneConfig.Pools) do
		for _, rune in ipairs(pool.runes) do
			local values = rune.boosts[kind]

			if values then
				local level = RuneConfig.levelFor(player:GetAttribute(RuneConfig.countAttribute(poolName, rune.name)) or 0, rune.needs)

				if level > 0 then
					if kind == "bulk" then
						total += values[level]
					else
						total *= values[level]
					end
				end
			end
		end
	end

	return total
end

return RuneConfig
