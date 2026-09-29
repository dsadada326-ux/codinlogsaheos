-- The Mine on Island 2 (server side). Ported from the old game's MineHandler.
-- Every player gets their own ores: which ore sits on which slot is the player attribute
-- MineOre_<slot> (the ore's name, or nil when empty), and each client draws only its own.
-- Mining: while you stand in the mine, every OreConfig.TickSeconds each of your ores inside
-- the circle around you (OreConfig.MineRadius) takes one hit.
--   MineEvent (RemoteEvent)    server -> client: ("hit", slot, hp, maxHp, reward) / ("break", slot, reward) / ("tick")
--   SellOres  (RemoteFunction) turn all Ores into Gold -> { ok, gold }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OreConfig = require(ReplicatedStorage:WaitForChild("OreConfig"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local eventRemote = remotes:WaitForChild("MineEvent")
local sellRemote = remotes:WaitForChild("SellOres")

local mineModel = workspace:WaitForChild("Islands"):WaitForChild("Island2"):WaitForChild("Zones"):WaitForChild("Mine")
local slotsFolder = mineModel:WaitForChild("Main"):WaitForChild("Slots")

local BREAK_CLEAR_DELAY = 0.6 -- the slot frees up after the break animation

-- the mine area = the mine floor (CaveGround), shared with clients through attributes
local floor = mineModel:FindFirstChild("CaveGround", true)

if floor and floor:IsA("BasePart") then
	slotsFolder:SetAttribute("AreaCFrame", floor.CFrame)
	slotsFolder:SetAttribute("AreaSize", floor.Size)
else
	-- no floor found: use the slots' footprint plus a margin
	local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, slot in ipairs(slotsFolder:GetChildren()) do
		if slot:IsA("BasePart") then
			minV = minV:Min(slot.Position)
			maxV = maxV:Max(slot.Position)
		end
	end

	slotsFolder:SetAttribute("AreaCFrame", CFrame.new((minV + maxV) / 2 - Vector3.new(0, 1.5, 0)))
	slotsFolder:SetAttribute("AreaSize", (maxV - minV) + Vector3.new(12, 1, 12))
	warn("[MineService] No CaveGround floor under the Mine model - using the slots' footprint as the mine area.")
end

local slotNames = {}

for _, slot in ipairs(slotsFolder:GetChildren()) do
	if slot:IsA("BasePart") then
		table.insert(slotNames, slot.Name)
	end
end

local state = {} -- [player] = { ores = { [slot] = { name, hp, broken } }, spawnTimer, tickTimer }

local function mineOpen(player)
	return ZoneConfig.isRevealed(player, ZoneConfig.find("Mine"))
end

local function stateOf(player)
	local s = state[player]

	if not s then
		s = { ores = {}, spawnTimer = 0, tickTimer = 0 }
		state[player] = s
	end

	return s
end

local function countOres(s)
	local n = 0

	for _ in pairs(s.ores) do
		n += 1
	end

	return n
end

local function spawnOre(player, s)
	local free = {}

	for _, name in ipairs(slotNames) do
		if not s.ores[name] then
			table.insert(free, name)
		end
	end

	if #free == 0 then
		return
	end

	local slot = free[math.random(1, #free)]
	local oreName = OreConfig.roll(OreConfig.luck(player))
	local def = OreConfig.Ores[oreName]

	s.ores[slot] = { name = oreName, hp = def.Health, broken = false }
	player:SetAttribute(OreConfig.slotAttribute(slot), oreName)
end

-- one hit on one ore
local function hitOre(player, s, slot, ore)
	local maxHp = OreConfig.Ores[ore.name].Health
	local reward = OreConfig.reward(player, ore.name)

	ore.hp -= OreConfig.damage(player)

	if ore.hp > 0 then
		eventRemote:FireClient(player, "hit", slot, ore.hp, maxHp, reward)
		return
	end

	ore.broken = true
	player:SetAttribute("Ores", (player:GetAttribute("Ores") or 0) + reward)
	eventRemote:FireClient(player, "break", slot, reward)

	task.delay(BREAK_CLEAR_DELAY, function()
		if state[player] == s and s.ores[slot] == ore then
			s.ores[slot] = nil

			if player.Parent then
				player:SetAttribute(OreConfig.slotAttribute(slot), nil)
			end
		end
	end)
end

-- your ores inside the circle right now
local function oresInRange(s, rootPosition)
	local list = {}

	for slot, ore in pairs(s.ores) do
		local slotPart = not ore.broken and slotsFolder:FindFirstChild(slot)

		if slotPart and OreConfig.inRange(rootPosition, slotPart.Position) then
			table.insert(list, { slot = slot, ore = ore })
		end
	end

	return list
end

RunService.Heartbeat:Connect(function(dt)
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("DataLoaded") and mineOpen(player) then
			local s = stateOf(player)

			-- spawning
			s.spawnTimer += dt

			if s.spawnTimer >= OreConfig.spawnInterval(player) and countOres(s) < OreConfig.maxOres(player, #slotNames) then
				s.spawnTimer = 0
				spawnOre(player, s)
			end

			-- mining: the tick only counts while an ore is inside your circle
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local targets = nil

			if root and humanoid and humanoid.Health > 0 and OreConfig.inArea(slotsFolder, root.Position) then
				targets = oresInRange(s, root.Position)
			end

			if targets and #targets > 0 then
				s.tickTimer += dt

				if s.tickTimer >= OreConfig.TickSeconds then
					s.tickTimer = 0
					eventRemote:FireClient(player, "tick")

					for _, t in ipairs(targets) do
						hitOre(player, s, t.slot, t.ore)
					end
				end
			else
				s.tickTimer = 0
			end
		end
	end
end)

-- sell every Ore for Gold
sellRemote.OnServerInvoke = function(player)
	if not mineOpen(player) then
		return { ok = false, reason = "Locked" }
	end

	local ores = player:GetAttribute("Ores") or 0

	if ores <= 0 then
		return { ok = false, reason = "No Ores" }
	end

	local gold = math.floor(ores * OreConfig.goldRate(player))

	player:SetAttribute("Ores", 0)
	player:SetAttribute("Gold", (player:GetAttribute("Gold") or 0) + gold)

	return { ok = true, gold = gold }
end

Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
end)
