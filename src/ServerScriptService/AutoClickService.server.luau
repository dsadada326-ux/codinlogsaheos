local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ComboConfig = require(ReplicatedStorage:WaitForChild("ComboConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))

local ClickHandler = require(
	script.Parent:WaitForChild("ButtonClickService"):WaitForChild("ClickHandler")
)

local INTERVAL = ComboConfig.AutoClickInterval

-- every interval, each player's Auto Clickers click the button
while true do
	task.wait(INTERVAL)

	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("DataLoaded") == true then
			local level = player:GetAttribute(UpgradeConfig.levelAttribute("Autoclicker")) or 0
			-- the Auto Button gamepass works like a few extra Auto Clickers
			if ShopConfig.hasPass(player, "AutoButton") then
				level += ShopConfig.AutoButtonClicks
			end

			if level > 0 then
				-- one click per Auto Clicker (per level) each interval
				ClickHandler.autoClicks(player, level)
			end
		end
	end
end
