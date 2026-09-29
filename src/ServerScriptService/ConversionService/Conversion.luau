local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("ConversionConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local Multipliers = require(ReplicatedStorage:WaitForChild("Multipliers"))

local Conversion = {}

local COOLDOWN = 0.25 -- seconds between conversions per player
local lastConvert = {}

local function round2(number)
	return math.floor(number * 100 + 0.5) / 100
end

local function round4(number)
	return math.floor(number * 10000 + 0.5) / 10000
end

-- every Cash multiplier the player has (Cash Multiplier, Rebirth Money, Gems, Time Money
-- Boost, prestige, Upgrade Tree), from ReplicatedStorage.Multipliers
local function cashMultiplier(player)
	return Multipliers.money(player)
end

local function getValue(player)
	return player:GetAttribute("ButtonValue") or Config.StartValue
end

-- sells all of a player's buttons for cash at their current Button Value.
-- Button Value is NOT changed by converting.
function Conversion.convert(player)
	if player:GetAttribute("DataLoaded") ~= true then
		return { ok = false, reason = "loading" }
	end

	-- the Conversion board unlocks at Button Multiplier 3/5 (same as Cash Multiplier)
	if not UpgradeConfig.isUnlocked(player, "CashMultiplier") then
		return { ok = false, reason = "locked" }
	end

	local now = os.clock()

	if now - (lastConvert[player] or 0) < COOLDOWN then
		return { ok = false, reason = "cooldown" }
	end

	lastConvert[player] = now

	local buttons = player:GetAttribute("Buttons") or 0

	if buttons < 0.01 then
		return { ok = false, reason = "nothing" }
	end

	local value = getValue(player)

	-- the Cash Multiplier upgrade boosts what you get for converting
	local multiplier = cashMultiplier(player)

	local cash = Config.cashFor(buttons, value, multiplier)

	player:SetAttribute("Buttons", 0)
	player:SetAttribute(
		"Cash",
		round2((player:GetAttribute("Cash") or 0) + cash)
	)

	return {
		ok = true,
		sold = buttons,
		cash = cash,
		value = value,
		multiplier = multiplier,
	}
end

-- grows every player's Button Value one step, based on the cash they could get right now
function Conversion.tick()
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("DataLoaded") == true then
			local value = getValue(player)
			local buttons = player:GetAttribute("Buttons") or 0

			-- the same "+X Cash" the board shows, so the Cash Multiplier speeds up growth too
			local potentialCash = Config.cashFor(buttons, value, cashMultiplier(player))

			local newValue = round4(Config.nextValue(value, potentialCash))

			if newValue > value then
				player:SetAttribute("ButtonValue", newValue)
			end
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	lastConvert[player] = nil
end)

return Conversion
