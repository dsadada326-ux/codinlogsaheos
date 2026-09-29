-- Prestige levels and the Upgrade Tree.
--
-- A prestige resets the player's NUMBERS (Cash, Buttons, Button Value, Rebirths, Time and
-- every upgrade level except Gem upgrades) but keeps the SETUP: unlocked areas, tutorial
-- unlocks, settings, Gems, Gem upgrades, and Upgrade Tree purchases.
local PrestigeConfig = {}

-- Levels[n] is what you get when you reach Prestige n
PrestigeConfig.Levels = {
	{
		cost = 5000, -- Rebirths needed for Prestige 0 -> 1
		money = 3, rebirths = 2, time = 2,
		perk = "AutoStarter",
		perkText = '<font color="#FFA333">AUTOMATES</font> Starter Upgrades',
	},
	{
		cost = 1000000, -- Rebirths needed for Prestige 1 -> 2
		money = 10, rebirths = 5, time = 5,
		perk = "UpgradeTree",
		perkText = '<font color="#FFA333">UNLOCKS</font> Upgrade Tree',
	},
	{
		cost = 500000000, -- Rebirths needed for Prestige 2 -> 3 (max on this island)
		money = 25, rebirths = 25, time = 25,
		perk = nil,
		perkText = '<font color="#FFA333">MAX</font> Prestige for this island',
	},
}

PrestigeConfig.MaxLevel = #PrestigeConfig.Levels

function PrestigeConfig.level(player)
	return player:GetAttribute("Prestige") or 0
end

-- the multipliers active at a prestige level (level 0 = all x1)
function PrestigeConfig.multipliersAt(level)
	local def = PrestigeConfig.Levels[level]

	if not def then
		return { money = 1, rebirths = 1, time = 1 }
	end

	return { money = def.money, rebirths = def.rebirths, time = def.time }
end

function PrestigeConfig.hasPerk(player, perk)
	local level = PrestigeConfig.level(player)

	for i = 1, level do
		local def = PrestigeConfig.Levels[i]

		if def and def.perk == perk then
			return true
		end
	end

	return false
end

------------------------------------------------------------------------------------------
-- Upgrade Tree (Workspace.Islands.Island1.UpgradeTree.UpgradeN). Unlocked at Prestige 2.
-- Step on a node to buy it (paid in Cash) once the node it grows from is owned.
------------------------------------------------------------------------------------------
PrestigeConfig.Tree = {
	Upgrade1 = { parent = nil, cost = 1e8, kind = "money", value = 2 },
	Upgrade2 = { parent = "Upgrade1", cost = 1e9, kind = "rebirths", value = 2 },
	Upgrade3 = { parent = "Upgrade2", cost = 1e10, kind = "money", value = 3 },
	Upgrade4 = { parent = "Upgrade2", cost = 1e10, kind = "time", value = 2 },
	Upgrade8 = { parent = "Upgrade2", cost = 1e10, kind = "time", value = 2 },
	Upgrade5 = { parent = "Upgrade3", cost = 1e11, kind = "rebirths", value = 2 },
	Upgrade6 = { parent = "Upgrade4", cost = 1e11, kind = "rebirths", value = 3 },
	Upgrade7 = { parent = "Upgrade4", cost = 1e11, kind = "money", value = 3 },
	Upgrade11 = { parent = "Upgrade8", cost = 1e11, kind = "money", value = 2 },
	Upgrade9 = { parent = "Upgrade5", cost = 1e12, kind = "money", value = 2 },
	Upgrade12 = { parent = "Upgrade6", cost = 1e12, kind = "time", value = 2 },
	Upgrade10 = { parent = "Upgrade9", cost = 1e13, kind = "rebirths", value = 2 },
	Upgrade13 = { parent = "Upgrade12", cost = 1e13, kind = "money", value = 3 },
	Upgrade14 = { parent = "Upgrade10", cost = 1e14, kind = "island" }, -- opens the Buttons rune island
}

------------------------------------------------------------------------------------------
-- Island 2 Upgrade Tree (Workspace.UpgradeBoards.Island2.UpgradeTree.Island2UpgradeN).
-- Same layout and parents as the Island 1 tree. Opens with Island 2, paid in Gold.
-- kinds: "gold" (all Gold earned), "wood", "ores", "money" (same Money boost as Island 1)
------------------------------------------------------------------------------------------
PrestigeConfig.Island2TreeCurrency = "Gold"

PrestigeConfig.Island2Tree = {
	Island2Upgrade1 = { parent = nil, cost = 1e4, kind = "gold", value = 2 },
	Island2Upgrade2 = { parent = "Island2Upgrade1", cost = 1e5, kind = "wood", value = 2 },
	Island2Upgrade3 = { parent = "Island2Upgrade2", cost = 1e6, kind = "gold", value = 3 },
	Island2Upgrade4 = { parent = "Island2Upgrade2", cost = 1e6, kind = "ores", value = 2 },
	Island2Upgrade8 = { parent = "Island2Upgrade2", cost = 1e6, kind = "money", value = 5 },
	Island2Upgrade5 = { parent = "Island2Upgrade3", cost = 1e7, kind = "wood", value = 2 },
	Island2Upgrade6 = { parent = "Island2Upgrade4", cost = 1e7, kind = "ores", value = 3 },
	Island2Upgrade7 = { parent = "Island2Upgrade4", cost = 1e7, kind = "gold", value = 3 },
	Island2Upgrade11 = { parent = "Island2Upgrade8", cost = 1e7, kind = "money", value = 5 },
	Island2Upgrade9 = { parent = "Island2Upgrade5", cost = 1e8, kind = "gold", value = 2 },
	Island2Upgrade12 = { parent = "Island2Upgrade6", cost = 1e8, kind = "ores", value = 2 },
	Island2Upgrade10 = { parent = "Island2Upgrade9", cost = 1e9, kind = "wood", value = 3 },
	Island2Upgrade13 = { parent = "Island2Upgrade12", cost = 1e9, kind = "gold", value = 3 },
	-- "Unlock Island 3 - Requires Prestige 7": shows once Island2Upgrade10 is owned, can't be bought yet
	Island2Upgrade14 = { parent = "Island2Upgrade10", cost = 1e10, kind = "island", comingSoon = true },
}

------------------------------------------------------------------------------------------
-- Fishing Frenzy Upgrade Tree (Workspace.Islands["FishingFrenzySub-1"].UpgradeTree.FishUpgradeN).
-- Same layout as the Island 2 tree, paid in Crabs (from the Conversion board).
-- kinds: "fishmeal", "fishluck", "fishspeed" (bites faster), "shells", "crabs", "autofish"
------------------------------------------------------------------------------------------
PrestigeConfig.FishTreeCurrency = "Crabs"
-- the whole tree (its island + nodes) stays hidden until Fish Tier 3 (when the Conversion board
-- starts giving Crabs). Once you've fishing-prestiged, or own any node, it stays open.
PrestigeConfig.FishTreeTier = 3

function PrestigeConfig.fishTreeUnlocked(player)
	if (player:GetAttribute("FishTier") or 0) >= PrestigeConfig.FishTreeTier then return true end
	if (player:GetAttribute("FishPrestige") or 0) >= 1 then return true end
	for node in pairs(PrestigeConfig.FishTree) do
		if player:GetAttribute("Tree_" .. node) == true then return true end
	end
	return false
end

PrestigeConfig.FishTree = {
	FishUpgrade1 = { parent = nil, cost = 5, kind = "fishmeal", value = 2, title = "More Fish Meal" },
	FishUpgrade2 = { parent = "FishUpgrade1", cost = 25, kind = "fishluck", value = 1.5, title = "Lucky Lure" },
	FishUpgrade3 = { parent = "FishUpgrade2", cost = 100, kind = "fishmeal", value = 2, title = "More Fish Meal" },
	FishUpgrade4 = { parent = "FishUpgrade2", cost = 100, kind = "shells", value = 2, title = "Shell Seeker" },
	FishUpgrade8 = { parent = "FishUpgrade2", cost = 100, kind = "fishspeed", value = 1.25, title = "Quick Bites" },
	FishUpgrade5 = { parent = "FishUpgrade3", cost = 500, kind = "fishluck", value = 1.5, title = "Lucky Lure" },
	FishUpgrade6 = { parent = "FishUpgrade4", cost = 500, kind = "crabs", value = 2, title = "Crab Trapper" },
	FishUpgrade7 = { parent = "FishUpgrade4", cost = 500, kind = "autofish", value = 2, title = "Crew Training" },
	FishUpgrade11 = { parent = "FishUpgrade8", cost = 500, kind = "fishspeed", value = 1.25, title = "Quick Bites" },
	FishUpgrade9 = { parent = "FishUpgrade5", cost = 2500, kind = "fishmeal", value = 3, title = "Fish Feast" },
	FishUpgrade12 = { parent = "FishUpgrade6", cost = 2500, kind = "crabs", value = 2, title = "Crab Trapper" },
	FishUpgrade10 = { parent = "FishUpgrade9", cost = 12000, kind = "fishluck", value = 2, title = "Golden Hook" },
	FishUpgrade13 = { parent = "FishUpgrade12", cost = 12000, kind = "autofish", value = 2, title = "Crew Training" },
	FishUpgrade14 = { parent = "FishUpgrade10", cost = 60000, kind = "fishmeal", value = 5, title = "Ocean's Blessing" },
}

-- a node from any tree
function PrestigeConfig.treeDef(node)
	return PrestigeConfig.Tree[node] or PrestigeConfig.Island2Tree[node] or PrestigeConfig.FishTree[node]
end

function PrestigeConfig.isIsland2Node(node)
	return PrestigeConfig.Island2Tree[node] ~= nil
end

function PrestigeConfig.isFishNode(node)
	return PrestigeConfig.FishTree[node] ~= nil
end

-- what a node is paid in
function PrestigeConfig.treeCurrency(node)
	if PrestigeConfig.isFishNode(node) then
		return PrestigeConfig.FishTreeCurrency
	end
	return PrestigeConfig.isIsland2Node(node) and PrestigeConfig.Island2TreeCurrency or "Cash"
end

function PrestigeConfig.island2TreeUnlocked(player)
	return player:GetAttribute("Island2Unlocked") == true
end

function PrestigeConfig.treeAttribute(node)
	return "Tree_" .. node
end

function PrestigeConfig.treeUnlocked(player)
	return PrestigeConfig.hasPerk(player, "UpgradeTree")
end

function PrestigeConfig.owns(player, node)
	return player:GetAttribute(PrestigeConfig.treeAttribute(node)) == true
end

-- can this node be bought right now (ignoring Cash)?
function PrestigeConfig.available(player, node)
	local def = PrestigeConfig.treeDef(node)
	local open

	if PrestigeConfig.isFishNode(node) then
		open = PrestigeConfig.fishTreeUnlocked(player)
	elseif PrestigeConfig.isIsland2Node(node) then
		open = PrestigeConfig.island2TreeUnlocked(player)
	else
		open = PrestigeConfig.treeUnlocked(player)
	end

	if not def or def.comingSoon or not open or PrestigeConfig.owns(player, node) then
		return false
	end

	return def.parent == nil or PrestigeConfig.owns(player, def.parent)
end

-- is this node showing but not buyable yet (a "coming soon" node whose parent you own)?
function PrestigeConfig.comingSoon(player, node)
	local def = PrestigeConfig.treeDef(node)

	return def ~= nil and def.comingSoon == true and (def.parent == nil or PrestigeConfig.owns(player, def.parent))
end

-- product of every owned node of one kind, across both trees
-- ("money" / "rebirths" / "time" on Island 1; "gold" / "wood" / "ores" / "money" on Island 2)
function PrestigeConfig.treeMultiplier(player, kind)
	local total = 1

	for _, tree in ipairs({ PrestigeConfig.Tree, PrestigeConfig.Island2Tree, PrestigeConfig.FishTree }) do
		for node, def in pairs(tree) do
			if def.kind == kind and def.value and PrestigeConfig.owns(player, node) then
				total *= def.value
			end
		end
	end

	return total
end

return PrestigeConfig
