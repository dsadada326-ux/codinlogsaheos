-- The Mine on Island 2 (ported from the old game).
-- Ores spawn on the slots under Island2.Zones.Mine.Main.Slots, one at a time, only for you.
-- Stand in the mine: a circle shows around you, and every TickSeconds each ore inside it takes
-- a hit. When an ore's Health runs out you get its Reward (x Ores Multiplier).
-- Sell Ores for Gold at the SellOres board.
local OreConfig = {}

OreConfig.OreToGoldRate = 1000 -- Gold per Ore when selling
OreConfig.BaseSpawnInterval = 3 -- seconds between spawns (before Spawn Speed)
OreConfig.MinSpawnInterval = 0.5
OreConfig.MineRadius = 6    -- studs: the circle around you
OreConfig.OreReach = 2      -- an ore counts as inside if its centre is within MineRadius + this
OreConfig.TickSeconds = 2   -- one hit on every ore in the circle this often
OreConfig.AreaHeight = 14   -- how far above the mine floor still counts as "in the mine"

OreConfig.Icon = "rbxassetid://93137720782314" -- the Ores currency icon

-- spawn order doesn't matter; Chance is a weight (rarer = lower), Ore Spawn Luck boosts rare ones
OreConfig.Order = { "Stone", "Iron", "Gold", "Diamond" }

OreConfig.Ores = {
	Stone = { Health = 6, Reward = 1, Chance = 30, Color = Color3.fromRGB(170, 170, 180) },
	Iron = { Health = 12, Reward = 3, Chance = 20, Color = Color3.fromRGB(215, 175, 145) },
	Gold = { Health = 20, Reward = 8, Chance = 9, Color = Color3.fromRGB(255, 205, 60) },
	Diamond = { Health = 40, Reward = 25, Chance = 1, Color = Color3.fromRGB(110, 230, 255) },
}

-- is this ore (slot position) inside the circle around this root position? (flat distance)
function OreConfig.inRange(rootPosition, orePosition)
	local flat = Vector3.new(orePosition.X - rootPosition.X, 0, orePosition.Z - rootPosition.Z)

	return flat.Magnitude <= OreConfig.MineRadius + OreConfig.OreReach
end

-- is this position standing in the mine? MineService writes the mine floor's CFrame/Size
-- as attributes on the Slots folder (folders always replicate, even with streaming on)
function OreConfig.inArea(slotsFolder, position)
	local cf = slotsFolder:GetAttribute("AreaCFrame")
	local size = slotsFolder:GetAttribute("AreaSize")

	if typeof(cf) ~= "CFrame" or typeof(size) ~= "Vector3" then
		return false
	end

	local p = cf:PointToObjectSpace(position)

	return math.abs(p.X) <= size.X / 2
		and math.abs(p.Z) <= size.Z / 2
		and p.Y >= -2
		and p.Y <= OreConfig.AreaHeight
end

function OreConfig.slotAttribute(slotName)
	return "MineOre_" .. slotName
end

local function up(player, id)
	local UpgradeConfig = require(script.Parent:WaitForChild("UpgradeConfig"))

	return UpgradeConfig.valueAt(id, player:GetAttribute(UpgradeConfig.levelAttribute(id)) or 0)
end

-- damage each click does
function OreConfig.damage(player)
	return 1 + up(player, "MineDamage")
end

-- seconds between new ores
function OreConfig.spawnInterval(player)
	return math.max(OreConfig.BaseSpawnInterval + up(player, "MineSpawnSpeed"), OreConfig.MinSpawnInterval)
end

-- how many ores can be out at once
function OreConfig.maxOres(player, slotCount)
	return math.clamp(1 + up(player, "MaxOres"), 1, math.max(slotCount or 1, 1))
end

-- luck (1 = normal odds)
function OreConfig.luck(player)
	return math.max(up(player, "OreSpawnLuck"), 0.01)
end

-- Ores you get for breaking one
function OreConfig.reward(player, oreName)
	local Multipliers = require(script.Parent:WaitForChild("Multipliers"))
	local def = OreConfig.Ores[oreName]

	return math.floor((def and def.Reward or 0) * Multipliers.ores(player))
end

function OreConfig.goldRate(player)
	local PrestigeConfig = require(script.Parent:WaitForChild("PrestigeConfig"))

	return OreConfig.OreToGoldRate * PrestigeConfig.treeMultiplier(player, "gold")
end

-- Ore Spawn Luck: rarer ores get their weight multiplied by up to `luck` (the rarest gets
-- the full boost, the most common gets none) -- same curve as the old game
function OreConfig.roll(luck)
	local maxChance, minChance = 0, math.huge

	for _, name in ipairs(OreConfig.Order) do
		local c = OreConfig.Ores[name].Chance or 0

		if c > 0 then
			maxChance = math.max(maxChance, c)
			minChance = math.min(minChance, c)
		end
	end

	local span = minChance < maxChance and math.log(maxChance / minChance) or 0
	local pool, total = {}, 0

	for _, name in ipairs(OreConfig.Order) do
		local c = OreConfig.Ores[name].Chance or 0
		local rarity = 0

		if c > 0 and span > 0 then
			rarity = math.clamp(math.log(maxChance / c) / span, 0, 1)
		end

		local weight = c * luck ^ rarity
		total += weight
		table.insert(pool, { name = name, weight = weight })
	end

	local pick = math.random() * total
	local acc = 0

	for _, entry in ipairs(pool) do
		acc += entry.weight

		if pick <= acc then
			return entry.name
		end
	end

	return pool[#pool].name
end

return OreConfig
