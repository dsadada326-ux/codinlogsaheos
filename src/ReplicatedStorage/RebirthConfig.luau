-- Shared by the server (RebirthService = the real reset) and the client
-- (the Rebirth board = the "X (+Y)" preview).
--
-- Rebirths gained = floor((Cash / CashPerRebirth) ^ GainExponent)
--   GainExponent = 1: straight 1K Cash = 1 Rebirth (100M Cash = 100K Rebirths)
--   (lower it, e.g. 0.5, to make each extra Rebirth cost more Cash)
-- Rebirth shop prices are scaled for this: tested with simulated players, the whole
-- Rebirth shop maxes in ~4h active, ~5.5h casual.
local RebirthConfig = {}

RebirthConfig.CashPerRebirth = 1000 -- your first Rebirth costs this much Cash
RebirthConfig.GainExponent = 1      -- 1 = linear; lower = each extra Rebirth costs more

-- how many rebirths a Cash amount is worth right now
function RebirthConfig.potential(cash)
	local ratio = math.max(cash, 0) / RebirthConfig.CashPerRebirth

	if ratio < 1 then
		return 0
	end

	return math.floor(ratio ^ RebirthConfig.GainExponent + 1e-9)
end

-- what THIS player would get right now: potential(Cash) x every Rebirths multiplier they have
-- (Gems, Time Rebirth Boost, prestige, Upgrade Tree)
function RebirthConfig.potentialFor(player)
	local Multipliers = require(script.Parent:WaitForChild("Multipliers"))

	local base = RebirthConfig.potential(player:GetAttribute("Cash") or 0)

	if base < 1 then
		return 0
	end

	return math.floor(base * Multipliers.rebirths(player))
end

return RebirthConfig
