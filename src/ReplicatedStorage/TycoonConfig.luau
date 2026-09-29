-- The Tycoon (Workspace.Islands.Island1.Zones.Tycoon.TycoonMain.TycoonDroppers).
-- Everything costs and pays Coins. Step on a buy button to buy the next piece.
--   Droppers: pay DropValue every DropInterval seconds (minus Dropper Speed), the Click
--             Dropper pays when you click its button.
--   Upgraders: every drop passes through them on the conveyor, so each owned upgrader
--              multiplies every dropper's value.
-- Payouts happen on the server; each player sees their own machines and drops.
local TycoonConfig = {}

-- the buy order (a button appears once the one before it is bought)
TycoonConfig.Order = {
	"ClickDropper", "Dropper1", "Upgrader1", "Dropper2", "Upgrader2", "Dropper3",
	"Dropper4", "Upgrader3", "Dropper5", "Upgrader4", "Dropper6", "Upgrader5", "Dropper7",
}

TycoonConfig.MinInterval = 0.75

TycoonConfig.Items = {
	ClickDropper = { kind = "dropper", name = "Click Dropper", cost = 0, manual = true, value = 6500 },
	Dropper1 = { kind = "dropper", name = "Dropper I", cost = 1e5, value = 30000, interval = 3 },
	Dropper2 = { kind = "dropper", name = "Dropper II", cost = 1e6, value = 40000, interval = 3.5 },
	Dropper3 = { kind = "dropper", name = "Dropper III", cost = 5e6, value = 80000, interval = 4 },
	Dropper4 = { kind = "dropper", name = "Dropper IV", cost = 2e7, value = 120000, interval = 4.5 },
	Dropper5 = { kind = "dropper", name = "Dropper V", cost = 2.5e8, value = 175000, interval = 5 },
	Dropper6 = { kind = "dropper", name = "Dropper VI", cost = 3.5e9, value = 200000, interval = 5.5 },
	Dropper7 = { kind = "dropper", name = "Dropper VII", cost = 8e10, value = 550000, interval = 6 },

	Upgrader1 = { kind = "upgrader", name = "Upgrader I", cost = 2.5e5, multiplier = 1.5 },
	Upgrader2 = { kind = "upgrader", name = "Upgrader II", cost = 2.5e6, multiplier = 2 },
	Upgrader3 = { kind = "upgrader", name = "Upgrader III", cost = 5e7, multiplier = 2 },
	Upgrader4 = { kind = "upgrader", name = "Upgrader IV", cost = 1e9, multiplier = 2.5 },
	Upgrader5 = { kind = "upgrader", name = "Upgrader V", cost = 2.5e10, multiplier = 3 },
}

function TycoonConfig.ownedAttribute(item)
	return "Tycoon_" .. item
end

function TycoonConfig.owns(player, item)
	local def = TycoonConfig.Items[item]

	if def and def.cost == 0 then
		return true -- the Click Dropper comes free
	end

	return player:GetAttribute(TycoonConfig.ownedAttribute(item)) == true
end

-- the next thing to buy (nil when everything is owned)
function TycoonConfig.nextItem(player)
	for _, item in ipairs(TycoonConfig.Order) do
		if not TycoonConfig.owns(player, item) then
			return item
		end
	end

	return nil
end

-- product of every owned upgrader
function TycoonConfig.upgraderMultiplier(player)
	local total = 1

	for item, def in pairs(TycoonConfig.Items) do
		if def.kind == "upgrader" and TycoonConfig.owns(player, item) then
			total *= def.multiplier
		end
	end

	return total
end

return TycoonConfig
