-- Island 2 (the Blue Island): click the Blue Button to hit the tree, chop it down for Wood.
--
--   tree HP     = BaseHP x tier.hp
--   damage      = 1 + Damage Dealt upgrade + tier.damage
--   cooldown    = BaseCooldown x Button Cooldown upgrade x tier.cooldown   (seconds)
--   wood/tree   = BaseWood x Wood Multiplier upgrade x tier.wood
--
-- Tier Up costs Wood and resets Wood + the tree upgrades, then the next tier's bonuses apply.
local UpgradeConfig = require(script.Parent:WaitForChild("UpgradeConfig"))

local IslandTwoConfig = {}

IslandTwoConfig.BaseHP = 5
IslandTwoConfig.BaseWood = 10
IslandTwoConfig.BaseCooldown = 1
IslandTwoConfig.MinCooldown = 0.15
IslandTwoConfig.RespawnSeconds = 5

-- unlocking the island: the whole Upgrade Tree + max Prestige on Island 1
IslandTwoConfig.UnlockPrestige = 3

-- the areas of Island 2 appear as you go
IslandTwoConfig.UpgradesAtWood = 10   -- first chop: the Tree Upgrades area + board
IslandTwoConfig.TiersAtWood = 100     -- the Tier board

IslandTwoConfig.Tiers = {
	-- HP goes up x5 each tree, starting at 5: 5, 25, 125
	{ name = "Starter Tree", hp = 1, cooldown = 1, wood = 1, damage = 0, image = "rbxassetid://101143767629414" },
	{ name = "Silver Tree", hp = 5, cooldown = 0.75, wood = 1.5, damage = 1, cost = 100, image = "rbxassetid://72044791854674" },
	-- cooldown -50%, +100% Wood, keeps the permanent +1 damage from Silver
	{ name = "Master Tree", hp = 25, cooldown = 0.5, wood = 2, damage = 1, cost = 1000 },
}

function IslandTwoConfig.tier(player)
	local index = math.clamp(player:GetAttribute("TreeTier") or 1, 1, #IslandTwoConfig.Tiers)
	return IslandTwoConfig.Tiers[index], index
end

-- the tree you're chopping: any tree up to your highest tier (the Tree board's arrows pick it).
-- HP and Wood come from this tree; damage/cooldown bonuses come from your highest tier.
function IslandTwoConfig.selected(player)
	local _, highest = IslandTwoConfig.tier(player)
	local index = math.clamp(player:GetAttribute("SelectedTree") or highest, 1, highest)
	return IslandTwoConfig.Tiers[index], index
end

-- the Island 2 Upgrade Tree's Wood boost (and Wood runes)
local function treeWood(player)
	local PrestigeConfig = require(script.Parent:WaitForChild("PrestigeConfig"))

	local RuneConfig = require(script.Parent:WaitForChild("RuneConfig"))

	return PrestigeConfig.treeMultiplier(player, "wood") * RuneConfig.boost(player, "wood")
end

local function up(player, id)
	return UpgradeConfig.valueAt(id, player:GetAttribute(UpgradeConfig.levelAttribute(id)) or 0)
end

function IslandTwoConfig.maxHP(player)
	local tier = IslandTwoConfig.selected(player)
	return math.floor(IslandTwoConfig.BaseHP * tier.hp + 0.5)
end

function IslandTwoConfig.damage(player)
	local tier = IslandTwoConfig.tier(player)
	return 1 + up(player, "DamageDealt") + tier.damage
end

function IslandTwoConfig.cooldown(player)
	local tier = IslandTwoConfig.tier(player)
	return math.max(IslandTwoConfig.BaseCooldown * up(player, "ButtonCooldown") * tier.cooldown, IslandTwoConfig.MinCooldown)
end

function IslandTwoConfig.woodPerTree(player)
	local tier = IslandTwoConfig.selected(player)
	return IslandTwoConfig.BaseWood * up(player, "WoodMultiplier") * tier.wood * treeWood(player)
end

-- previews for any tree (the Tree board's arrows)
function IslandTwoConfig.maxHPForTier(index)
	local tier = IslandTwoConfig.Tiers[index]
	return tier and math.floor(IslandTwoConfig.BaseHP * tier.hp + 0.5) or 0
end

function IslandTwoConfig.woodForTier(player, index)
	local tier = IslandTwoConfig.Tiers[index]
	return tier and IslandTwoConfig.BaseWood * up(player, "WoodMultiplier") * tier.wood * treeWood(player) or 0
end

function IslandTwoConfig.canUnlock(player)
	if (player:GetAttribute("Prestige") or 0) < IslandTwoConfig.UnlockPrestige then
		return false
	end

	for i = 1, 14 do
		if player:GetAttribute("Tree_Upgrade" .. i) ~= true then
			return false
		end
	end

	return true
end

return IslandTwoConfig
