local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PrestigeConfig = require(ReplicatedStorage:WaitForChild("PrestigeConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local ConversionConfig = require(ReplicatedStorage:WaitForChild("ConversionConfig"))

local doPrestige = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DoPrestige")
local prestigedRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Prestiged")
local TycoonConfig = require(ReplicatedStorage:WaitForChild("TycoonConfig"))

local COOLDOWN = 1
local last = {}

-- Resets the NUMBERS (Cash, Buttons, Button Value, Rebirths, Time, upgrade levels except Gems)
-- and keeps the SETUP (unlocked areas + tutorial unlocks, settings, Gems, Gem upgrades,
-- Upgrade Tree, runes, playtime).
local function prestige(player)
	if player:GetAttribute("DataLoaded") ~= true then
		return { ok = false, reason = "loading" }
	end

	local now = os.clock()

	if now - (last[player] or 0) < COOLDOWN then
		return { ok = false, reason = "cooldown" }
	end

	last[player] = now

	local level = PrestigeConfig.level(player)
	local nextDef = PrestigeConfig.Levels[level + 1]

	if not nextDef then
		return { ok = false, reason = "max" }
	end

	if (player:GetAttribute("Rebirths") or 0) < nextDef.cost then
		return { ok = false, reason = "rebirths" }
	end

	player:SetAttribute("Cash", 0)
	player:SetAttribute("Buttons", 0)
	player:SetAttribute("ButtonValue", ConversionConfig.StartValue)
	player:SetAttribute("Rebirths", 0)
	player:SetAttribute("Time", 0)
	player:SetAttribute("Coins", 0)
	player:SetAttribute("Wood", 0)
	player:SetAttribute("TreeTier", 1)

	-- every upgrade level except the Gem ones (Gems are limited)
	for _, id in ipairs(UpgradeConfig.Order) do
		-- (Drilling Mania upgrades are reset by the Enhancer instead)
		if UpgradeConfig.Upgrades[id].Currency ~= "Gems" and not UpgradeConfig.Upgrades[id].Drill then
			player:SetAttribute(UpgradeConfig.levelAttribute(id), 0)
		end
	end

	-- tycoon purchases
	for item in pairs(TycoonConfig.Items) do
		player:SetAttribute(TycoonConfig.ownedAttribute(item), false)
	end

	player:SetAttribute("Prestige", level + 1)

	-- the client covers the screen, moves you back to the red button, and shows "PRESTIGED!"
	prestigedRemote:FireClient(player, level + 1)

	return { ok = true, level = level + 1 }
end

doPrestige.OnServerInvoke = prestige

Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
end)
