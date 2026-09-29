local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))

-- Rows in the currency list and when they appear. (Buttons is always shown; Cash and Time
-- are handled by UpgradeBoard.lua and TimeButtonFX.lua.) Rows not in the game stay hidden.
local RULES = {
	Rebirths = function()
		return ZoneConfig.isRevealed(player, ZoneConfig.find("Rebirths")) or (player:GetAttribute("Rebirths") or 0) > 0
	end,
	Coins = function()
		return ZoneConfig.isRevealed(player, ZoneConfig.find("Coins")) or (player:GetAttribute("Coins") or 0) > 0
	end,
	Wheat = function()
		return ZoneConfig.isRevealed(player, ZoneConfig.find("Farm")) or (player:GetAttribute("Wheat") or 0) > 0
	end,
	Iron = function() return false end,
	Ores = function()
		return ZoneConfig.isRevealed(player, ZoneConfig.find("Mine")) or (player:GetAttribute("Ores") or 0) > 0
	end,
	Gold = function()
		return ZoneConfig.isRevealed(player, ZoneConfig.find("Farm")) or ZoneConfig.isRevealed(player, ZoneConfig.find("Mine")) or (player:GetAttribute("Gold") or 0) > 0
	end,
}

local function apply()
	local currencies = player.PlayerGui:FindFirstChild("Currencies")
	local list = currencies
		and currencies:FindFirstChild("MainCurrenciesFrame")
		and currencies.MainCurrenciesFrame:FindFirstChild("CurrenciesFrame")

	if not list then
		return
	end

	for name, rule in pairs(RULES) do
		local row = list:FindFirstChild(name)

		if row then
			row.Visible = rule()
		end
	end
end

for _, attribute in ipairs({ "Rebirths", ZoneConfig.flagAttribute(ZoneConfig.find("Rebirths")), "Coins", ZoneConfig.flagAttribute(ZoneConfig.find("Coins")), "Wheat", "Gold", ZoneConfig.flagAttribute(ZoneConfig.find("Farm")), "Ores", ZoneConfig.flagAttribute(ZoneConfig.find("Mine")) }) do
	player:GetAttributeChangedSignal(attribute):Connect(apply)
end

player.PlayerGui.ChildAdded:Connect(function(child)
	if child.Name == "Currencies" then
		task.defer(apply)
	end
end)

apply()
