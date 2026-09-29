-- The areas that appear as the player progresses, in unlock order.
-- The server (ZoneService) sets a saved flag (Zone_<Name> = true) the first time the
-- condition is met, and it never turns off again -- so everything stays open after a
-- rebirth resets Cash and Buttons. Unlocking an area also unlocks every area before it.
-- The client (ZoneReveal) shows/hides the island, its textures, and its boards, on that
-- player's screen only, with a "being built" animation when it first appears.
local ZoneConfig = {}

ZoneConfig.Zones = {
	{ name = "Starter" }, -- always visible from the moment you join

	{
		name = "StarterUpgrades",
		label = "Upgrades",
		attribute = "Buttons", threshold = 25,
		boards = {
			{ "UpgradeBoards", "Island1", "Starter" },
		},
	},

	{
		-- no island of its own: just the Conversion board, when converting unlocks
		-- (Button Multiplier 3/5, the same moment Cash Multiplier appears)
		name = "Conversion",
		label = "Conversion",
		noIsland = true,
		condition = function(player)
			return player:GetAttribute("Unlocked_CashMultiplier") == 1
				or (player:GetAttribute("Upgrade_CashMultiplier") or 0) > 0
		end,
		boards = {
			{ "OtherBoards", "Conversion" },
		},
	},

	{
		name = "Rebirths",
		label = "Rebirths",
		attribute = "Cash", threshold = 1000,
		boards = {
			{ "OtherBoards", "Rebirth" },
		},
	},

	{
		name = "RebirthBoosts",
		label = "Rebirth Boosts",
		attribute = "Rebirths", threshold = 1,
		boards = {
			{ "UpgradeBoards", "Island1", "RebirthBoosts" },
		},
	},

	{
		name = "Time",
		label = "Time",
		attribute = "Rebirths", threshold = 50,
		boards = {
			{ "UpgradeBoards", "Island1", "Time" },
			{ "UpgradeBoards", "Island1", "Gems" },
		},
	},

	{
		name = "TimeBoosts",
		label = "Time Boosts",
		attribute = "Time", threshold = 100,
		boards = {
			{ "UpgradeBoards", "Island1", "TimeBoosts" },
		},
	},

	{
		name = "Prestige",
		label = "Prestige",
		attribute = "Time", threshold = 10000,
		boards = {
			{ "OtherBoards", "Prestige" },
			{ "Runes", "Starter" }, -- the Starter rune stand sits on the Prestige island
		},
	},

	-- the areas below are NOT part of the step-by-step chain: each opens on its own condition
	{
		name = "TimeRune",
		label = "Time Runes",
		independent = true,
		attribute = "Time", threshold = 50000,
		boards = {
			{ "Runes", "Time" },
		},
	},

	{
		name = "UpgradeTree",
		label = "Upgrade Tree",
		independent = true,
		noIsland = true, -- the tree + its ground are handled by UpgradeTree.lua
		condition = function(player)
			return (player:GetAttribute("Prestige") or 0) >= 2
		end,
	},

	{
		name = "Leaderboards",
		label = "Leaderboards",
		independent = true,
		condition = function(player)
			return (player:GetAttribute("Prestige") or 0) >= 1
		end,
	},

	-- ISLAND 2 ----------------------------------------------------------------------------
	{
		-- unlocking Island 2: the Blue Button, the floor and the tree
		name = "Island2Start",
		island2 = true, -- part of Island 2: hidden until Island 2 is unlocked
		label = "Blue Island",
		island = "Island2", model = "Island2Starter",
		independent = true,
		condition = function(player)
			return player:GetAttribute("Island2Unlocked") == true
		end,
		boards = {
			{ "Islands", "Island2", "BlueButton", "Button" },
		},
	},

	{
		-- the first chop: the Tree Upgrades area and board
		name = "Island2Upgrades",
		island2 = true, -- part of Island 2: hidden until Island 2 is unlocked
		label = "Tree Upgrades",
		noIsland = true, -- its floor model was removed; just the board shows up
		independent = true,
		condition = function(player)
			return player:GetAttribute("Island2Unlocked") == true and (player:GetAttribute("Wood") or 0) >= 10
		end,
		boards = {
			{ "UpgradeBoards", "Island2", "TreeUpgrades" },
		},
	},

	{
		-- 100 Wood: the Tier board
		name = "Island2Tiers",
		island2 = true, -- part of Island 2: hidden until Island 2 is unlocked
		label = "Tree Tiers",
		noIsland = true,
		independent = true,
		condition = function(player)
			return player:GetAttribute("Island2Unlocked") == true and (player:GetAttribute("Wood") or 0) >= 100
		end,
		boards = {
			{ "Islands", "Island2", "Tiers" },
		},
	},

	{
		-- the Mine, its two upgrade boards and the Sell Ores board
		name = "Mine",
		island2 = true, -- part of Island 2: hidden until Island 2 is unlocked
		label = "Mine",
		island = "Island2", model = "Mine",
		independent = true,
		condition = function(player)
			return player:GetAttribute("Island2Unlocked") == true
		end,
		boards = {
			{ "UpgradeBoards", "Island2", "Mine" },
			{ "UpgradeBoards", "Island2", "MineBoosts" },
			{ "OtherBoards", "SellOres" },
		},
	},

	{
		-- the Wheat Farm, its upgrade board and the Sell Wheat board
		name = "Farm",
		island2 = true, -- part of Island 2: hidden until Island 2 is unlocked
		label = "Wheat Farm",
		island = "Island2", model = "Farm",
		independent = true,
		condition = function(player)
			return player:GetAttribute("Island2Unlocked") == true
		end,
		boards = {
			{ "UpgradeBoards", "Island2", "Farm" },
			{ "OtherBoards", "SellWheat" },
		},
	},

	{
		-- the "Red Island -> Blue Island" board appears once the whole Upgrade Tree is owned
		name = "Island2",
		label = "Island 2",
		independent = true,
		noIsland = true,
		condition = function(player)
			for i = 1, 14 do
				if player:GetAttribute("Tree_Upgrade" .. i) ~= true then
					return false
				end
			end

			return true
		end,
		boards = {
			{ "OtherBoards", "Island2LevelUp" },
		},
	},

	{
		-- Prestige 1: the island with the Equipment Trader (and the path to it)
		name = "EquipmentTrader",
		label = "Equipment Trader",
		independent = true,
		condition = function(player)
			return (player:GetAttribute("Prestige") or 0) >= 1
		end,
	},

	{
		-- Prestige 2: the Coins island and its board
		name = "Coins",
		label = "Coins",
		independent = true,
		condition = function(player)
			return (player:GetAttribute("Prestige") or 0) >= 2
		end,
		boards = {
			{ "UpgradeBoards", "Island1", "Coins" },
		},
	},

	{
		-- Prestige 3 (or buying "Unlock Island 2" on the tree first): the Tycoon
		name = "Tycoon",
		label = "Tycoon",
		independent = true,
		condition = function(player)
			return (player:GetAttribute("Prestige") or 0) >= 3 or player:GetAttribute("Tree_Upgrade14") == true
		end,
		boards = {
			{ "UpgradeBoards", "Island1", "Tycoon" },
		},
	},

	{
		-- same moment as the Tycoon: the Portal island with the Buttons rune stand
		name = "Portal",
		label = "Buttons Runes",
		independent = true,
		condition = function(player)
			return (player:GetAttribute("Prestige") or 0) >= 3 or player:GetAttribute("Tree_Upgrade14") == true
		end,
		boards = {
			{ "Runes", "Buttons" },
		},
	},
}

-- The little "Unlocks At" signs (Workspace.Islands.Island1.TempZones.TempZones.<model>).
-- A sign shows once the area before it is unlocked, and disappears when its own area unlocks.
-- It shows live progress toward the goal, e.g. "37 / 50 Rebirths".
ZoneConfig.TempZones = {
	{ model = "RebirthBoosts", after = nil, target = "RebirthBoosts" }, -- the first sign, from the start
	{ model = "Time", after = "RebirthBoosts", target = "Time" },
	{ model = "Prestige", after = "Time", target = "Prestige" },
	{
		model = "UpgradeTree", after = "Prestige", target = "UpgradeTree",
		progress = { attribute = "Prestige", threshold = 2, unit = "Prestiges" },
	},
}

function ZoneConfig.find(name)
	for _, zone in ipairs(ZoneConfig.Zones) do
		if zone.name == name then
			return zone
		end
	end

	return nil
end

function ZoneConfig.flagAttribute(zone)
	return "Zone_" .. zone.name
end

function ZoneConfig.alwaysOpen(zone)
	return zone.attribute == nil and zone.condition == nil
end

-- is the condition met right now? (server uses this to set the saved flag)
function ZoneConfig.conditionMet(player, zone)
	if zone.condition then
		return zone.condition(player) == true
	end

	if zone.attribute then
		return (player:GetAttribute(zone.attribute) or 0) >= zone.threshold
	end

	return true
end

-- has the player unlocked this area? (works on the server and the client)
function ZoneConfig.isRevealed(player, zone)
	-- Island 2 areas stay hidden while Island 2 is locked, whatever their saved flag says
	if zone.island2 and player:GetAttribute("Island2Unlocked") ~= true then
		return false
	end

	if ZoneConfig.alwaysOpen(zone) then
		return true
	end

	return player:GetAttribute(ZoneConfig.flagAttribute(zone)) == true
end

-- every player attribute that can unlock an area (so both sides know what to watch)
function ZoneConfig.watchedAttributes()
	return {
		"Buttons", "Cash", "Rebirths", "Time", "Prestige", "Wood", "Island2Unlocked",
		"Tree_Upgrade1", "Tree_Upgrade2", "Tree_Upgrade3", "Tree_Upgrade4", "Tree_Upgrade5",
		"Tree_Upgrade6", "Tree_Upgrade7", "Tree_Upgrade8", "Tree_Upgrade9", "Tree_Upgrade10",
		"Tree_Upgrade11", "Tree_Upgrade12", "Tree_Upgrade13", "Tree_Upgrade14",
		"Unlocked_CashMultiplier", "Upgrade_CashMultiplier",
	}
end

return ZoneConfig
