-- The game's one and only ProcessReceipt. Looks the product up in ProductHandlers and gives it.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local ProductHandlers = require(script.Parent:WaitForChild("ProductHandlers"))

local granted = {} -- PurchaseIds already given this server (Roblox can retry a receipt)

MarketplaceService.ProcessReceipt = function(receipt)
	if granted[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local handler = ProductHandlers[receipt.ProductId]

	if not player or not handler then
		-- not here / unknown product: Roblox tries again later (e.g. when they rejoin)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, result = pcall(handler, player)

	if ok and result then
		granted[receipt.PurchaseId] = true
		-- the Profile's "Robux Spent" stat
		player:SetAttribute("RobuxSpent", (player:GetAttribute("RobuxSpent") or 0) + (tonumber(receipt.CurrencySpent) or 0))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	warn("[PurchaseService] couldn't give product " .. receipt.ProductId .. " to " .. player.Name .. ": " .. tostring(result))
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
