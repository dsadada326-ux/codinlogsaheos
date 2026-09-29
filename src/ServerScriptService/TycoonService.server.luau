local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TycoonConfig = require(ReplicatedStorage:WaitForChild("TycoonConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local Multipliers = require(ReplicatedStorage:WaitForChild("Multipliers"))

local tycoonDrop = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TycoonDrop")
local tycoonSold = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TycoonSold")
local HttpService = game:GetService("HttpService")

local root = workspace:WaitForChild("Islands"):WaitForChild("Island1"):WaitForChild("Zones")
	:WaitForChild("Tycoon"):WaitForChild("TycoonMain"):WaitForChild("TycoonDroppers")

local tycoonZone = ZoneConfig.find("Tycoon")

local CONVEYOR_SPEED = 14

local function round2(n)
	return math.floor(n * 100 + 0.5) / 100
end

local function unlocked(player)
	return player:GetAttribute("DataLoaded") == true and ZoneConfig.isRevealed(player, tycoonZone)
end

-- the conveyor belt pushes drops from its Start to its End attachment
do
	local belt = root:WaitForChild("Conveyor"):WaitForChild("Conveyor")
	local startAtt, endAtt = belt:FindFirstChild("Start"), belt:FindFirstChild("End")

	if startAtt and endAtt then
		local direction = (endAtt.WorldPosition - startAtt.WorldPosition)
		direction = Vector3.new(direction.X, 0, direction.Z).Unit
		belt.AssemblyLinearVelocity = direction * CONVEYOR_SPEED
	end
end

-- A drop is only worth Coins once it reaches the Seller at the end of the belt.
-- The server hands each drop a ticket; the player's game sends it back when the drop
-- arrives. A ticket is only accepted after the drop could really have ridden the belt
-- (and before it expires), so drops that fall off, or fake claims, pay nothing.
local sellerPart = root:WaitForChild("Seller"):FindFirstChildWhichIsA("BasePart", true)
local MAX_TICKETS = 200
local TICKET_LIFETIME = 40
local pending = {} -- [player] = { [id] = { amount, created, minTime } }

local minTravel = {} -- [item] = seconds the belt needs, at least

for _, model in ipairs(root:WaitForChild("Droppers"):GetChildren()) do
	local spot = model:FindFirstChild("DropPosition")

	if spot and sellerPart then
		local flat = Vector3.new(spot.Position.X - sellerPart.Position.X, 0, spot.Position.Z - sellerPart.Position.Z)
		minTravel[model.Name] = flat.Magnitude / CONVEYOR_SPEED * 0.6 -- slack for timing
	end
end

local function drop(player, item)
	local def = TycoonConfig.Items[item]
	local amount = def.value * TycoonConfig.upgraderMultiplier(player) * Multipliers.coins(player)

	pending[player] = pending[player] or {}

	local tickets = pending[player]
	local count = 0

	for _ in pairs(tickets) do
		count += 1
	end

	if count >= MAX_TICKETS then
		return -- too many drops still on the belt
	end

	local id = HttpService:GenerateGUID(false)
	tickets[id] = { amount = amount, created = os.clock(), minTime = minTravel[item] or 2 }

	tycoonDrop:FireClient(player, item, id, amount)
end

tycoonSold.OnServerEvent:Connect(function(player, id)
	local tickets = pending[player]
	local ticket = tickets and typeof(id) == "string" and tickets[id]

	if not ticket then
		return
	end

	local age = os.clock() - ticket.created

	if age < ticket.minTime then
		return -- arrived faster than the belt allows: not a real arrival
	end

	tickets[id] = nil

	if age <= TICKET_LIFETIME then
		player:SetAttribute("Coins", round2((player:GetAttribute("Coins") or 0) + ticket.amount))
	end
end)

-- forget drops that never arrived
task.spawn(function()
	while true do
		task.wait(5)

		local now = os.clock()

		for _, tickets in pairs(pending) do
			for id, ticket in pairs(tickets) do
				if now - ticket.created > TICKET_LIFETIME then
					tickets[id] = nil
				end
			end
		end
	end
end)

-- buying: step on the next piece's button
local lastTry = {}

local function tryBuy(player, item)
	if not unlocked(player) then
		return
	end

	lastTry[player] = lastTry[player] or {}
	local now = os.clock()

	if now - (lastTry[player][item] or 0) < 0.5 then
		return
	end

	lastTry[player][item] = now

	if TycoonConfig.owns(player, item) then
		return -- already bought (buttons can be bought in any order)
	end

	local def = TycoonConfig.Items[item]
	local coins = player:GetAttribute("Coins") or 0

	if coins < def.cost then
		return
	end

	player:SetAttribute("Coins", round2(coins - def.cost))
	player:SetAttribute(TycoonConfig.ownedAttribute(item), true)
end

for _, button in ipairs(root:WaitForChild("BuyButtons"):GetChildren()) do
	local item = button.Name
	local hitbox = button:FindFirstChild("ButtonHitbox")

	if hitbox and TycoonConfig.Items[item] then
		hitbox.CanTouch = true

		hitbox.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)

			if player then
				tryBuy(player, item)
			end
		end)
	end
end

-- the Click Dropper: click its button
do
	local clickDropper = root:WaitForChild("Droppers"):WaitForChild("ClickDropper")
	local button = clickDropper:WaitForChild("ActivateButton")
	local detector = button:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
	detector.MaxActivationDistance = 40
	detector.Parent = button

	local lastClick = {}

	detector.MouseClick:Connect(function(player)
		if not unlocked(player) then
			return
		end

		local now = os.clock()

		if now - (lastClick[player] or 0) < 0.25 then
			return
		end

		lastClick[player] = now
		drop(player, "ClickDropper")
	end)
end

-- automatic droppers pay on their own timers
local timers = {} -- [player][item] = seconds

RunService.Heartbeat:Connect(function(dt)
	for _, player in ipairs(Players:GetPlayers()) do
		if unlocked(player) then
			timers[player] = timers[player] or {}

			local speed = UpgradeConfig.valueAt("DropperSpeed", player:GetAttribute(UpgradeConfig.levelAttribute("DropperSpeed")) or 0)

			for item, def in pairs(TycoonConfig.Items) do
				if def.kind == "dropper" and not def.manual and TycoonConfig.owns(player, item) then
					local interval = math.max(def.interval + speed, TycoonConfig.MinInterval)
					local t = (timers[player][item] or 0) + dt

					if t >= interval then
						t -= interval
						drop(player, item)
					end

					timers[player][item] = t
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	timers[player] = nil
	lastTry[player] = nil
	pending[player] = nil
end)
