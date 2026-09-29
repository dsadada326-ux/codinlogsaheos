-- The Wheat Farm on Island 2 (server side). Ported from the old game's FarmHandler.
--   BuyFarmSlot (RemoteFunction)  buy the next plot with Gold  -> { ok, reason }
--   ClaimWheat  (RemoteEvent)     harvest a fully grown plot   (plot index)
--   SellWheat   (RemoteFunction)  turn all Wheat into Gold     -> { ok, gold }
--   FarmReward  (RemoteEvent)     server -> client, for the "+X" orb VFX
-- Owned plots are saved in the FarmSlots attribute; each plot's growth stage lives in
-- FarmStage_<plot> (0-5) and restarts at 0 when you rejoin.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FarmConfig = require(ReplicatedStorage:WaitForChild("FarmConfig"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyRemote = remotes:WaitForChild("BuyFarmSlot")
local claimRemote = remotes:WaitForChild("ClaimWheat")
local sellRemote = remotes:WaitForChild("SellWheat")
local rewardRemote = remotes:WaitForChild("FarmReward")

local slotsFolder = workspace:WaitForChild("Islands"):WaitForChild("Island2")
	:WaitForChild("Zones"):WaitForChild("Farm"):WaitForChild("FarmLayer"):WaitForChild("Slots")

local HARVEST_RANGE = 14 -- studs: you have to actually be at the plot to harvest it

local nextStageAt = {} -- [player] = { [plotIndex] = os.clock() when it grows a stage }
local lastBuy = {}

local function farmOpen(player)
	return ZoneConfig.isRevealed(player, ZoneConfig.find("Farm"))
end

local function ownedCount(player)
	return math.clamp(math.floor(FarmConfig.owned(player)), 0, #FarmConfig.Slots)
end

local function stageOf(player, index)
	return player:GetAttribute(FarmConfig.stageAttribute(index)) or 0
end

local function plant(player, index)
	player:SetAttribute(FarmConfig.stageAttribute(index), 0)
	nextStageAt[player] = nextStageAt[player] or {}
	nextStageAt[player][index] = os.clock() + FarmConfig.stageTime(player)
end

local function setup(player)
	if not player:GetAttribute("DataLoaded") then
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end

	if not player.Parent then
		return
	end

	nextStageAt[player] = {}

	for index = 1, ownedCount(player) do
		plant(player, index)
	end
end

-- growth: one loop for everyone
local acc = 0

RunService.Heartbeat:Connect(function(dt)
	acc += dt

	if acc < 0.1 then
		return
	end

	acc = 0
	local now = os.clock()

	for player, timers in pairs(nextStageAt) do
		if player.Parent then
			for index, at in pairs(timers) do
				if now >= at then
					local stage = stageOf(player, index) + 1

					if stage >= FarmConfig.MaxStage then
						player:SetAttribute(FarmConfig.stageAttribute(index), FarmConfig.MaxStage)
						timers[index] = nil -- fully grown: waits to be harvested
					else
						player:SetAttribute(FarmConfig.stageAttribute(index), stage)
						timers[index] = now + FarmConfig.stageTime(player)
					end
				end
			end
		end
	end
end)

-- buy the next plot
buyRemote.OnServerInvoke = function(player)
	if not farmOpen(player) then
		return { ok = false, reason = "Locked" }
	end

	local now = os.clock()

	if lastBuy[player] and now - lastBuy[player] < 0.3 then
		return { ok = false, reason = "Slow down" }
	end

	lastBuy[player] = now

	local index = ownedCount(player) + 1
	local slot = FarmConfig.Slots[index]

	if not slot then
		return { ok = false, reason = "All Owned" }
	end

	local price = slot.Price or 0
	local gold = player:GetAttribute("Gold") or 0

	if price > 0 then
		if gold < price then
			return { ok = false, reason = "Not Enough Gold" }
		end

		player:SetAttribute("Gold", gold - price)
	end

	player:SetAttribute("FarmSlots", index)
	plant(player, index)

	return { ok = true, index = index }
end

-- harvest a fully grown plot
claimRemote.OnServerEvent:Connect(function(player, index)
	index = tonumber(index)

	if not index or index % 1 ~= 0 or index < 1 or index > ownedCount(player) then
		return
	end

	if not farmOpen(player) or stageOf(player, index) < FarmConfig.MaxStage then
		return
	end

	local slotPart = slotsFolder:FindFirstChild(tostring(index))
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

	if slotPart and root and (root.Position - slotPart.Position).Magnitude > HARVEST_RANGE then
		return
	end

	local reward = FarmConfig.Slots[index].WheatReward or 0
	player:SetAttribute("Wheat", (player:GetAttribute("Wheat") or 0) + reward)
	plant(player, index)

	rewardRemote:FireClient(player, "Wheat", reward, index)
end)

-- sell every Wheat for Gold
sellRemote.OnServerInvoke = function(player)
	if not farmOpen(player) then
		return { ok = false, reason = "Locked" }
	end

	local wheat = player:GetAttribute("Wheat") or 0

	if wheat <= 0 then
		return { ok = false, reason = "No Wheat" }
	end

	local gold = math.floor(wheat * FarmConfig.goldRate(player))

	player:SetAttribute("Wheat", 0)
	player:SetAttribute("Gold", (player:GetAttribute("Gold") or 0) + gold)

	rewardRemote:FireClient(player, "Gold", gold)

	return { ok = true, gold = gold }
end

Players.PlayerAdded:Connect(setup)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setup, player)
end

Players.PlayerRemoving:Connect(function(player)
	nextStageAt[player] = nil
	lastBuy[player] = nil
end)
