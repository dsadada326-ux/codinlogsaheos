local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Upgrades = require(script:WaitForChild("Upgrades"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))

local buyRemote = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("BuyUpgrade")

-- the Buy 1 / Buy Max buttons on the Starter board call this
buyRemote.OnServerInvoke = function(player, id, mode)
	return Upgrades.buy(player, id, mode)
end

-- unlock upgrades as soon as the player has had enough Cash
local function watch(player)
	local function check()
		Upgrades.checkUnlocks(player)
	end

	player:GetAttributeChangedSignal("Cash"):Connect(check)
	player:GetAttributeChangedSignal("DataLoaded"):Connect(check)

	for _, id in ipairs(UpgradeConfig.Order) do
		player:GetAttributeChangedSignal(UpgradeConfig.levelAttribute(id)):Connect(check)
	end

	check()
end

Players.PlayerAdded:Connect(watch)

for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end
