-- Fishing Frenzy shop jumps: the Rods / Sell / Magnets buttons at the top of the screen move
-- you to the matching stall (Magnets -> Shell Upgrades). Spots come from FishingFrenzyConfig.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishingFrenzyConfig = require(ReplicatedStorage:WaitForChild("FishingFrenzyConfig"))
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FishingShopTeleport")

local COOLDOWN = 1
local lastUse = {}

remote.OnServerInvoke = function(player, shopName)
	if player:GetAttribute("DataLoaded") ~= true then
		return { ok = false, reason = "loading" }
	end

	if typeof(shopName) ~= "string" or not FishingFrenzyConfig.Shops[shopName] then
		return { ok = false, reason = "unknown" }
	end

	local now = os.clock()
	if now - (lastUse[player] or 0) < COOLDOWN then
		return { ok = false, reason = "cooldown" }
	end
	lastUse[player] = now

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not humanoid or humanoid.Health <= 0 then
		return { ok = false, reason = "dead" }
	end

	local target = FishingFrenzyConfig.shopSpot(shopName)

	if not target then
		return { ok = false, reason = "missing" }
	end

	pcall(function()
		player:RequestStreamAroundAsync(target.Position, 5)
	end)

	character:PivotTo(target)

	return { ok = true }
end

Players.PlayerRemoving:Connect(function(player)
	lastUse[player] = nil
end)
