-- Shared by the server (ConversionService = the real payout and growth) and the
-- client (ConversionBoard = what the board shows).
--
-- Button Value = how much cash one button is worth. It is saved with the player,
-- grows on a timer, and is NOT reset by converting. (A future rebirth is what
-- should reset it: player:SetAttribute("ButtonValue", ConversionConfig.StartValue))
local ConversionConfig = {}

ConversionConfig.StartValue = 1   -- Button Value for a brand new player
ConversionConfig.TickSeconds = 3  -- how often Button Value grows

-- How fast it grows. Bigger = faster.
ConversionConfig.Growth = 0.05

-- Potential cash (the "+X Cash" on the board) at which growth gets going.
-- Growth follows the log of (1 + potential / this), so it speeds up as your
-- potential cash grows, but with diminishing returns.
ConversionConfig.PotentialScale = 10

local function round2(number)
	return math.floor(number * 100 + 0.5) / 100
end

-- Button Value after one tick. It only ever goes up:
--  * more potential cash held  -> bigger step
--  * higher Button Value       -> much smaller step (so it can't run away)
function ConversionConfig.nextValue(value, potentialCash)
	value = math.max(value, ConversionConfig.StartValue)
	potentialCash = math.max(potentialCash, 0)

	local step = ConversionConfig.Growth
		* math.log10(1 + potentialCash / ConversionConfig.PotentialScale)

	return value + step / (value * value)
end

-- total cash for that many buttons at a given Button Value.
-- `multiplier` is the Cash Multiplier upgrade (1 if the player has none).
function ConversionConfig.cashFor(buttons, value, multiplier)
	return round2(
		math.max(buttons, 0)
			* math.max(value, ConversionConfig.StartValue)
			* (multiplier or 1)
	)
end

return ConversionConfig
