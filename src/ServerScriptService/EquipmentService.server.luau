local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentConfig = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local Multipliers = require(ReplicatedStorage:WaitForChild("Multipliers"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyRemote = remotes:WaitForChild("BuyEquipment")
local equipRemote = remotes:WaitForChild("EquipEquipment")

local traderZone = ZoneConfig.find("EquipmentTrader")
local BASE_WALK_SPEED = 40 -- everyone's base speed; equipment adds on top

local function round2(n)
	return math.floor(n * 100 + 0.5) / 100
end

local function indexOf(id)
	for i, v in ipairs(EquipmentConfig.Order) do
		if v == id then
			return i
		end
	end

	return nil
end

local function applyWalkSpeed(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.WalkSpeed = BASE_WALK_SPEED + Multipliers.walkSpeedBonus(player)
	end
end

buyRemote.OnServerInvoke = function(player, id)
	if player:GetAttribute("DataLoaded") ~= true or not ZoneConfig.isRevealed(player, traderZone) then
		return { ok = false, reason = "locked" }
	end

	local def = typeof(id) == "string" and EquipmentConfig.Items[id]

	if not def then
		return { ok = false, reason = "unknown" }
	end

	local stock = EquipmentConfig.stockOf(player)

	if not table.find(stock, id) then
		return { ok = false, reason = "not in stock" }
	end

	if player:GetAttribute(EquipmentConfig.ownedAttribute(id)) == true then
		return { ok = false, reason = "owned" }
	end

	local coins = player:GetAttribute("Coins") or 0

	if coins < def.cost then
		return { ok = false, reason = "coins" }
	end

	player:SetAttribute("Coins", round2(coins - def.cost))
	player:SetAttribute(EquipmentConfig.ownedAttribute(id), true)

	return { ok = true }
end

-- id = "" unequips
equipRemote.OnServerInvoke = function(player, id)
	if player:GetAttribute("DataLoaded") ~= true then
		return { ok = false }
	end

	if id == "" then
		player:SetAttribute("EquippedIndex", 0)
		return { ok = true }
	end

	local index = typeof(id) == "string" and indexOf(id)

	if not index or player:GetAttribute(EquipmentConfig.ownedAttribute(id)) ~= true then
		return { ok = false, reason = "not owned" }
	end

	player:SetAttribute("EquippedIndex", index)

	return { ok = true }
end

local function watch(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 5)
		applyWalkSpeed(player)
	end)

	player:GetAttributeChangedSignal("EquippedIndex"):Connect(function()
		applyWalkSpeed(player)
	end)

	applyWalkSpeed(player)
end

Players.PlayerAdded:Connect(watch)

for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end

------------------------------------------------------------------------------------------
-- the trader's stock: each player rolls their own shop every refresh window (with pity)
------------------------------------------------------------------------------------------
local rng = Random.new()

-- forced = a paid Robux restock: rerolls right now (the normal timer keeps going)
local function restock(player, forced)
	if player:GetAttribute("DataLoaded") ~= true or not ZoneConfig.isRevealed(player, traderZone) then
		return false
	end

	local window = EquipmentConfig.window(workspace:GetServerTimeNow())

	if not forced and player:GetAttribute("TraderWindow") == window then
		return false
	end

	local legendary = player:GetAttribute(EquipmentConfig.pityAttribute("Legendary")) or 0
	local mythic = player:GetAttribute(EquipmentConfig.pityAttribute("Mythic")) or 0
	local stock, newLegendary, newMythic = EquipmentConfig.roll(rng, legendary, mythic)

	for i = 1, EquipmentConfig.Slots do
		player:SetAttribute(EquipmentConfig.slotAttribute(i), stock[i] and indexOf(stock[i]) or 0)
	end

	for _, id in ipairs(stock) do
		player:SetAttribute(EquipmentConfig.seenAttribute(id), true)
	end

	player:SetAttribute(EquipmentConfig.pityAttribute("Legendary"), newLegendary)
	player:SetAttribute(EquipmentConfig.pityAttribute("Mythic"), newMythic)

	-- set last: the client treats a TraderWindow change as "the shop just refreshed"
	player:SetAttribute("TraderWindow", window)

	if forced then
		-- not saved, just tells the client to show "restocked!"
		player:SetAttribute("TraderRestocks", (player:GetAttribute("TraderRestocks") or 0) + 1)
	end

	return true
end

-- Robux restock (Developer Product, id in EquipmentConfig.RestockProductId)
if EquipmentConfig.RestockProductId ~= 0 then
	local ProductHandlers = require(script.Parent:WaitForChild("ProductHandlers"))

	ProductHandlers[EquipmentConfig.RestockProductId] = function(player)
		return restock(player, true)
	end
end

task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(restock, player)
		end

		task.wait(1)
	end
end)
