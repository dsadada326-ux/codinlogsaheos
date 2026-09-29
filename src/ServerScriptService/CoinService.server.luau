local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local CoinConfig = require(ReplicatedStorage:WaitForChild("CoinConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local Multipliers = require(ReplicatedStorage:WaitForChild("Multipliers"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local coinSpawned = remotes:WaitForChild("CoinSpawned")
local coinRemoved = remotes:WaitForChild("CoinRemoved")
local collectCoin = remotes:WaitForChild("CollectCoin")

local island = workspace:WaitForChild("Islands"):WaitForChild("Island1"):WaitForChild("Zones"):WaitForChild("Coins")
local area = island:WaitForChild("Hitbox")       -- where coins can appear
local floor = island:FindFirstChild("Pickup")    -- the ground they sit on

local coinsZone = ZoneConfig.find("Coins")
local rng = Random.new()
local state = {} -- [player] = { timer, coins = { [id] = position }, count }

local function round2(n)
	return math.floor(n * 100 + 0.5) / 100
end

local function up(player, id)
	return UpgradeConfig.valueAt(id, player:GetAttribute(UpgradeConfig.levelAttribute(id)) or 0)
end

local function grant(player)
	local amount = CoinConfig.CoinValue * Multipliers.coins(player)
	player:SetAttribute("Coins", round2((player:GetAttribute("Coins") or 0) + amount))
end

local function spawnFor(player, s)
	local half = area.Size / 2
	local offset = Vector3.new(rng:NextNumber(-half.X, half.X) * 0.9, 0, rng:NextNumber(-half.Z, half.Z) * 0.9)
	local point = area.CFrame:PointToWorldSpace(offset)
	local groundY = floor and (floor.Position.Y + floor.Size.Y / 2) or area.Position.Y
	local position = Vector3.new(point.X, groundY + 1.2, point.Z)
	local id = HttpService:GenerateGUID(false)

	s.coins[id] = position
	s.count += 1
	coinSpawned:FireClient(player, id, position)
end

collectCoin.OnServerEvent:Connect(function(player, id)
	local s = state[player]

	if not s or typeof(id) ~= "string" or not s.coins[id] then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root or (root.Position - s.coins[id]).Magnitude > CoinConfig.PickupRange + 4 then
		return
	end

	s.coins[id] = nil
	s.count -= 1
	grant(player)
	coinRemoved:FireClient(player, id)
end)

RunService.Heartbeat:Connect(function(dt)
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("DataLoaded") == true and ZoneConfig.isRevealed(player, coinsZone) then
			local s = state[player]

			if not s then
				s = { timer = 0, coins = {}, count = 0 }
				state[player] = s
			end

			local auto = up(player, "AutoPickupCoins") >= 1

			-- Auto Pickup just bought: everything on the ground goes straight in
			if auto and s.count > 0 then
				for id in pairs(s.coins) do
					grant(player)
					coinRemoved:FireClient(player, id)
				end

				s.coins = {}
				s.count = 0
			end

			s.timer += dt

			local interval = math.max(up(player, "CoinSpawnSpeed"), 0.2)

			if s.timer >= interval then
				s.timer = 0

				if auto then
					grant(player)
				elseif s.count < CoinConfig.MaxOnGround then
					spawnFor(player, s)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
end)
