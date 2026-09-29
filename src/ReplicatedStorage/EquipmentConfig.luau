-- Equipment sold by the Equipment Trader. Every player gets their own `Slots` items, rolled
-- from `weight` every `RotationSeconds` (everyone refreshes at the same moment). Pity: if you
-- go `Pity.Legendary` refreshes without a Legendary-or-better, the next shop guarantees one
-- (same for Mythic). Buy with Coins, equip one at a time. Boosts: money / coins / time
-- multiply, walkSpeed / runeBulk add, runeLuck multiplies.
local EquipmentConfig = {}

EquipmentConfig.Slots = 3
EquipmentConfig.RotationSeconds = 300

EquipmentConfig.Pity = {
	Legendary = 10, -- a Legendary (or Mythic) is guaranteed at least every 10 refreshes
	Mythic = 30, -- a Mythic is guaranteed at least every 30 refreshes
}

EquipmentConfig.RarityRank = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 }

-- Robux restock: a Developer Product (not a gamepass, since it can be bought again and again).
-- Create it under Monetization > Developer Products and paste its ID here. 0 = not set up yet.
EquipmentConfig.RestockProductId = 3715007049

-- Second equipment slot: a Gamepass (bought once, kept forever). Create it under
-- Monetization > Passes (name it "Second Equipment Slot") and paste its ID here. 0 = not set up yet.
EquipmentConfig.SecondSlotPassId = 0

-- saved slot attributes (each holds a position in Order, 0 = empty)
EquipmentConfig.SlotAttributes = { "EquippedIndex", "EquippedIndex2" }

EquipmentConfig.Order = {
	"Pencil", "Balloon", "Dice", "Magnet", "Timer", "SpeedCoil", "GoldDice", "GrapplingHook",
	"DiamondDice", "Cloud", "Hoverboard", "RuneCoin", "MagicCarpet", "MONEY",
}

EquipmentConfig.Items = {
	Pencil = { name = "Pencil", rarity = "Common", weight = 50, cost = 1e3, image = "rbxassetid://98507525246268", boosts = { money = 1.5, coins = 1.25 } },
	Balloon = { name = "Balloon", rarity = "Common", weight = 40, cost = 3e3, image = "rbxassetid://108192771443998", boosts = { money = 2, walkSpeed = 4 } },
	Dice = { name = "Dice", rarity = "Common", weight = 30, cost = 5e3, image = "rbxassetid://120431925490241", boosts = { money = 5, runeLuck = 1.25 } },
	Magnet = { name = "Magnet", rarity = "Rare", weight = 20, cost = 2e4, image = "rbxassetid://106532023061860", boosts = { coins = 4 } },
	Timer = { name = "Timer", rarity = "Rare", weight = 20, cost = 1.2e5, image = "rbxassetid://116114871550285", boosts = { time = 5 } },
	SpeedCoil = { name = "Speed Coil", rarity = "Rare", weight = 40, cost = 3e5, image = "rbxassetid://131893959114650", boosts = { money = 4, coins = 2, walkSpeed = 6 } },
	GoldDice = { name = "Gold Dice", rarity = "Epic", weight = 10, cost = 5e7, image = "rbxassetid://120116438488949", boosts = { money = 8, coins = 4, runeLuck = 1.75 } },
	GrapplingHook = { name = "Grappling Hook", rarity = "Epic", weight = 10, cost = 1e8, image = "rbxassetid://134677649696183", boosts = { time = 4, walkSpeed = 10 } },
	DiamondDice = { name = "Diamond Dice", rarity = "Legendary", weight = 5, cost = 5e9, image = "rbxassetid://91029106791568", boosts = { money = 12, coins = 10, runeLuck = 2.5 } },
	Cloud = { name = "Cloud", rarity = "Legendary", weight = 5, cost = 1.5e10, image = "rbxassetid://83491286988487", boosts = { coins = 5, walkSpeed = 8 } },
	Hoverboard = { name = "Hoverboard", rarity = "Legendary", weight = 1, cost = 1e10, image = "rbxassetid://73775911758204", boosts = { money = 35, walkSpeed = 10 } },
	RuneCoin = { name = "Rune Coin", rarity = "Mythic", weight = 0.25, cost = 5e11, image = "rbxassetid://132545887256480", boosts = { runeBulk = 10 } },
	MagicCarpet = { name = "Magic Carpet", rarity = "Mythic", weight = 0.2, cost = 1e12, image = "rbxassetid://94726772449775", boosts = { money = 50, walkSpeed = 16 } },
	MONEY = { name = "MONEY", rarity = "Mythic", weight = 0.1, cost = 5e13, image = "rbxassetid://122743434972421", boosts = { money = 100 } },
}

EquipmentConfig.RarityColors = {
	Common = Color3.fromRGB(215, 215, 215),
	Rare = Color3.fromRGB(80, 225, 255),
	Epic = Color3.fromRGB(185, 120, 255),
	Legendary = Color3.fromRGB(255, 205, 60),
	Mythic = Color3.fromRGB(255, 90, 170),
}

function EquipmentConfig.ownedAttribute(id)
	return "Equipment_" .. id
end

-- how many slots this player can use (2 with the Second Equipment Slot pass).
-- The server sets the SecondSlot attribute from gamepass ownership.
function EquipmentConfig.slotCount(player)
	return player:GetAttribute("SecondSlot") == true and 2 or 1
end

-- the item in a slot (default slot 1); a locked slot always counts as empty
function EquipmentConfig.equipped(player, slot)
	slot = slot or 1
	local attribute = EquipmentConfig.SlotAttributes[slot]

	if not attribute or slot > EquipmentConfig.slotCount(player) then
		return nil
	end

	return EquipmentConfig.Order[player:GetAttribute(attribute) or 0]
end

-- which slot an item is equipped in, or nil
function EquipmentConfig.slotOf(player, id)
	for slot = 1, EquipmentConfig.slotCount(player) do
		if EquipmentConfig.equipped(player, slot) == id then
			return slot
		end
	end

	return nil
end

-- combined boost from every equipped item: multipliers multiply, walkSpeed / runeBulk add
function EquipmentConfig.boost(player, kind)
	local additive = kind == "walkSpeed" or kind == "runeBulk"
	local total = additive and 0 or 1

	for slot = 1, EquipmentConfig.slotCount(player) do
		local id = EquipmentConfig.equipped(player, slot)
		local def = id and EquipmentConfig.Items[id]
		local value = def and def.boosts[kind]

		if value then
			if additive then
				total += value
			else
				total *= value
			end
		end
	end

	return total
end

------------------------------------------------------------------------------------------
-- the trader's stock (per player, saved as attributes)
--   TraderWindow          which refresh window the stock was rolled for
--   TraderSlot1..N        index into Order (0 = empty)
--   TraderPity_<Rarity>   refreshes in a row without that rarity (or better)
--   TraderSeen_<id>       has ever shown up in your shop (the Index)
------------------------------------------------------------------------------------------
function EquipmentConfig.slotAttribute(i)
	return "TraderSlot" .. i
end

function EquipmentConfig.pityAttribute(rarity)
	return "TraderPity_" .. rarity
end

function EquipmentConfig.seenAttribute(id)
	return "TraderSeen_" .. id
end

function EquipmentConfig.window(serverTime)
	return math.floor(serverTime / EquipmentConfig.RotationSeconds)
end

function EquipmentConfig.secondsLeft(serverTime)
	return (EquipmentConfig.window(serverTime) + 1) * EquipmentConfig.RotationSeconds - serverTime
end

function EquipmentConfig.rank(id)
	local def = EquipmentConfig.Items[id]
	return def and EquipmentConfig.RarityRank[def.rarity] or 0
end

-- what this player's trader is offering right now
function EquipmentConfig.stockOf(player)
	local stock = {}

	for i = 1, EquipmentConfig.Slots do
		local id = EquipmentConfig.Order[player:GetAttribute(EquipmentConfig.slotAttribute(i)) or 0]

		if id then
			table.insert(stock, id)
		end
	end

	return stock
end

-- refreshes left until that rarity is guaranteed (1 = the next refresh)
function EquipmentConfig.pityLeft(player, rarity)
	local count = player:GetAttribute(EquipmentConfig.pityAttribute(rarity)) or 0
	return math.max(1, EquipmentConfig.Pity[rarity] - count)
end

function EquipmentConfig.discovered(player, id)
	return player:GetAttribute(EquipmentConfig.seenAttribute(id)) == true
		or player:GetAttribute(EquipmentConfig.ownedAttribute(id)) == true
end

local function pickFrom(rng, pool, minRank)
	local total = 0

	for _, id in ipairs(pool) do
		if EquipmentConfig.rank(id) >= minRank then
			total += EquipmentConfig.Items[id].weight
		end
	end

	if total <= 0 then
		return nil
	end

	local r = rng:NextNumber() * total
	local last

	for i, id in ipairs(pool) do
		if EquipmentConfig.rank(id) >= minRank then
			last = i
			r -= EquipmentConfig.Items[id].weight

			if r <= 0 then
				return i
			end
		end
	end

	return last
end

-- rolls a new shop. legendaryCount / mythicCount = refreshes in a row without one.
-- returns the stock and the new counts.
function EquipmentConfig.roll(rng, legendaryCount, mythicCount)
	local pool = table.clone(EquipmentConfig.Order)
	local picked = {}

	local forceRank = nil
	if mythicCount >= EquipmentConfig.Pity.Mythic - 1 then
		forceRank = EquipmentConfig.RarityRank.Mythic
	elseif legendaryCount >= EquipmentConfig.Pity.Legendary - 1 then
		forceRank = EquipmentConfig.RarityRank.Legendary
	end

	if forceRank then
		local i = pickFrom(rng, pool, forceRank)
		if i then
			table.insert(picked, table.remove(pool, i))
		end
	end

	while #picked < EquipmentConfig.Slots and #pool > 0 do
		local i = pickFrom(rng, pool, 0)
		if not i then break end
		table.insert(picked, table.remove(pool, i))
	end

	-- shuffle so a pity item isn't always in the first slot
	for i = #picked, 2, -1 do
		local j = rng:NextInteger(1, i)
		picked[i], picked[j] = picked[j], picked[i]
	end

	local best = 0
	for _, id in ipairs(picked) do
		best = math.max(best, EquipmentConfig.rank(id))
	end

	local newLegendary = best >= EquipmentConfig.RarityRank.Legendary and 0 or legendaryCount + 1
	local newMythic = best >= EquipmentConfig.RarityRank.Mythic and 0 or mythicCount + 1

	return picked, newLegendary, newMythic
end

-- chance an item shows up in any one shop (ignores pity), for the Index's "1 in X"
local chanceCache = nil

function EquipmentConfig.appearChance(id)
	if not chanceCache then
		chanceCache = {}
		local total = 0

		for _, k in ipairs(EquipmentConfig.Order) do
			chanceCache[k] = 0
			total += EquipmentConfig.Items[k].weight
		end

		local used = {}

		local function walk(depth, prob, remaining)
			if remaining <= 0 then return end

			for _, k in ipairs(EquipmentConfig.Order) do
				if not used[k] then
					local w = EquipmentConfig.Items[k].weight
					local p = prob * w / remaining
					chanceCache[k] += p

					if depth < EquipmentConfig.Slots then
						used[k] = true
						walk(depth + 1, p, remaining - w)
						used[k] = nil
					end
				end
			end
		end

		walk(1, 1, total)
	end

	return chanceCache[id] or 0
end

return EquipmentConfig
