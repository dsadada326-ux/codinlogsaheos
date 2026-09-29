local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local PrestigeConfig = require(ReplicatedStorage:WaitForChild("PrestigeConfig"))
local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))
local Upgrades = require(ServerScriptService:WaitForChild("UpgradeService"):WaitForChild("Upgrades"))

-- the Starter board upgrades Prestige 1 automates
local STARTER = { "ButtonMultiplier", "CashMultiplier", "CritChance", "CritMultiplier" }
local INTERVAL = 0.25

local function autoOn(player)
	local value = player:GetAttribute(SettingsConfig.attributeOf("AutoUpgradeStarter"))

	if value == nil then
		return SettingsConfig.Settings.AutoUpgradeStarter.Default
	end

	return value
end

-- each tick: for every currency (Cash, Buttons), buy the cheapest affordable Starter level,
-- so a Buttons-paid upgrade never waits behind the Cash ones
local function step(player)
	local best = {} -- [currency] = { id, share }

	for _, id in ipairs(STARTER) do
		local def = UpgradeConfig.Upgrades[id]
		local level = player:GetAttribute(UpgradeConfig.levelAttribute(id)) or 0

		if level < def.MaxLevel and UpgradeConfig.isUnlocked(player, id) then
			local currency = UpgradeConfig.currencyOf(id, level)
			local balance = player:GetAttribute(currency) or 0
			local cost = UpgradeConfig.costAt(id, level)

			if cost <= balance then
				local share = cost / math.max(balance, 1)

				if not best[currency] or share < best[currency].share then
					best[currency] = { id = id, share = share }
				end
			end
		end
	end

	for _, pick in pairs(best) do
		Upgrades.buy(player, pick.id, "one")
		task.wait(0.11) -- the buy cooldown is 0.1s per player
	end
end

while true do
	task.wait(INTERVAL)

	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("DataLoaded") == true
			and PrestigeConfig.hasPerk(player, "AutoStarter")
			and autoOn(player) then
			local ok, err = pcall(step, player)

			if not ok then
				warn("[AutoUpgrade] " .. tostring(err))
			end
		end
	end
end
