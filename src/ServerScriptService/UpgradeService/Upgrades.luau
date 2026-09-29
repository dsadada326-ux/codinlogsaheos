local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))

local Upgrades = {}

local COOLDOWN = 0.1 -- seconds between purchases per player
local lastBuy = {}
local ISLAND2_CURRENCIES = { Wood = true, Gold = true, Ores = true, Wheat = true }

local function round2(number)
	return math.floor(number * 100 + 0.5) / 100
end

-- buys 1 level ("one") or as many as the player can afford ("max")
function Upgrades.buy(player, id, mode)
	if typeof(id) ~= "string" or Config.Upgrades[id] == nil then
		return { ok = false, reason = "unknown" }
	end

	if player:GetAttribute("DataLoaded") ~= true then
		return { ok = false, reason = "loading" }
	end

	local now = os.clock()

	if now - (lastBuy[player] or 0) < COOLDOWN then
		return { ok = false, reason = "cooldown" }
	end

	lastBuy[player] = now

	local def = Config.Upgrades[id]

	if not Config.isUnlocked(player, id) then
		return { ok = false, reason = "locked" }
	end

	-- Island 2 upgrades (paid in Wood, Gold or Ores) need Island 2 unlocked
	if ISLAND2_CURRENCIES[Config.currencyOf(id)] and player:GetAttribute("Island2Unlocked") ~= true then
		return { ok = false, reason = "locked" }
	end

	local level = player:GetAttribute(Config.levelAttribute(id)) or 0

	if level >= def.MaxLevel then
		return { ok = false, reason = "maxed" }
	end

	local currency = Config.currencyOf(id) -- "Cash" or "Buttons"
	local balance = player:GetAttribute(currency) or 0
	local count, total = Config.affordable(id, level, balance)

	if mode ~= "max" then
		count = math.min(count, 1)
		total = count > 0 and Config.costAt(id, level) or 0
	end

	if count < 1 then
		return { ok = false, reason = "cash" }
	end

	player:SetAttribute(currency, round2(balance - total))
	player:SetAttribute(Config.levelAttribute(id), level + count)

	return { ok = true, bought = count, level = level + count, spent = total }
end

-- hidden upgrades appear once their condition is met (UnlockCash / UnlockAfter), and stay unlocked
function Upgrades.checkUnlocks(player)
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end

	for _, id in ipairs(Config.Order) do
		if Config.needsUnlock(id)
			and player:GetAttribute(Config.unlockAttribute(id)) ~= 1
			and Config.meetsUnlock(player, id) then
			player:SetAttribute(Config.unlockAttribute(id), 1)
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	lastBuy[player] = nil
end)

return Upgrades
