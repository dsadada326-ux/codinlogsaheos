local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RuneConfig = require(ReplicatedStorage:WaitForChild("RuneConfig"))
local Multipliers = require(ReplicatedStorage:WaitForChild("Multipliers"))

local runeRolled = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RuneRolled")
local runesRolledRemote = runeRolled
local standsFolder = workspace:WaitForChild("Runes")

local rng = Random.new()

local function runesRolledFire(player, poolName, results, best)
	runesRolledRemote:FireClient(player, poolName, results, best)
end

local stands = {} -- [poolName] = hitbox
for poolName, pool in pairs(RuneConfig.Pools) do
	if not pool.noStand then
		task.spawn(function()
			local stand = standsFolder:WaitForChild(poolName, 15)

			if stand then
				stands[poolName] = stand:WaitForChild("Hitbox")
			end
		end)
	end
end

local state = {} -- [player] = { pool, accum }

-- the stand pad is a flat disc: its thin axis is the Hitbox's X
local function standingIn(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root then
		return nil
	end

	for poolName, hitbox in pairs(stands) do
		local l = hitbox.CFrame:PointToObjectSpace(root.Position)
		local radius = math.max(hitbox.Size.Y, hitbox.Size.Z) / 2

		if math.abs(l.X) <= hitbox.Size.X / 2 + 5 and math.sqrt(l.Y * l.Y + l.Z * l.Z) <= radius then
			return poolName
		end
	end

	return nil
end

-- one weighted pick: luck multiplies every rune's weight except the most common one
local function rollOne(pool, luck)
	local total = 0
	local weights = {}

	for i, rune in ipairs(pool.runes) do
		local w = rune.chance * (i == 1 and 1 or luck)
		weights[i] = w
		total += w
	end

	local r = rng:NextNumber() * total

	for i, rune in ipairs(pool.runes) do
		r -= weights[i]

		if r <= 0 then
			return rune, i
		end
	end

	return pool.runes[1], 1
end

local function roll(player, poolName)
	local pool = RuneConfig.Pools[poolName]
	local balance = player:GetAttribute(pool.currency) or 0

	if balance < pool.cost then
		return false
	end

	player:SetAttribute(pool.currency, math.floor((balance - pool.cost) * 100 + 0.5) / 100)

	local bulk = math.max(1, math.floor(Multipliers.runeBulk(player)))
	local luck = Multipliers.runeLuck(player)

	local results = {}
	local bestIndex = 0

	for _ = 1, bulk do
		local rune, index = rollOne(pool, luck)
		local attribute = RuneConfig.countAttribute(poolName, rune.name)

		player:SetAttribute(attribute, (player:GetAttribute(attribute) or 0) + 1)
		results[rune.name] = (results[rune.name] or 0) + 1
		bestIndex = math.max(bestIndex, index)
	end

	local openedAttribute = RuneConfig.openedAttribute(poolName)
	player:SetAttribute(openedAttribute, (player:GetAttribute(openedAttribute) or 0) + bulk)

	runeRolled:FireClient(player, poolName, results, pool.runes[bestIndex].name)

	return true
end

RunService.Heartbeat:Connect(function(deltaTime)
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("DataLoaded") == true then
			-- the Time stand's 50K Time requirement is checked once and saved (Time resets on prestige)
			if player:GetAttribute("Unlocked_Rune_Time") ~= true and (player:GetAttribute("Time") or 0) >= RuneConfig.Pools.Time.unlock.time then
				player:SetAttribute("Unlocked_Rune_Time", true)
			end

			local s = state[player]

			if not s then
				s = { pool = nil, accum = 0 }
				state[player] = s
			end

			local poolName = standingIn(player)

			if poolName and RuneConfig.isUnlocked(player, poolName) then
				if s.pool ~= poolName then
					s.pool = poolName
					s.accum = RuneConfig.RollInterval -- first roll right away
				end

				s.accum += deltaTime

				-- x2 Rune Speed (pass / Ticket boost) rolls more often
				local interval = RuneConfig.RollInterval / math.max(Multipliers.runeSpeed(player), 0.01)
				if s.accum >= interval then
					s.accum -= interval
					roll(player, poolName)
				end
			else
				s.pool = nil
				s.accum = 0
			end

			if player:GetAttribute("RuneStand") ~= s.pool then
				player:SetAttribute("RuneStand", s.pool) -- lets the client light up the stand
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
end)

-- free runes (the Global Runes Robux product): ServerStorage.GrantRunes:Fire(player, poolName, count)
-- Rune Luck applies, Rune Bulk doesn't, and it costs nothing.
local grantEvent = game:GetService("ServerStorage"):FindFirstChild("GrantRunes")
if not grantEvent then
	grantEvent = Instance.new("BindableEvent")
	grantEvent.Name = "GrantRunes"
	grantEvent.Parent = game:GetService("ServerStorage")
end
grantEvent.Event:Connect(function(player, poolName, count)
	local pool = RuneConfig.Pools[poolName]
	if not pool or not player.Parent then return end
	count = math.clamp(math.floor(tonumber(count) or 0), 0, 100000)
	if count == 0 then return end
	local luck = Multipliers.runeLuck(player)
	local results, bestIndex = {}, 1
	for _ = 1, count do
		local rune, index = rollOne(pool, luck)
		results[rune.name] = (results[rune.name] or 0) + 1
		bestIndex = math.max(bestIndex, index)
	end
	for name, n in pairs(results) do
		local attribute = RuneConfig.countAttribute(poolName, name)
		player:SetAttribute(attribute, (player:GetAttribute(attribute) or 0) + n)
	end
	local openedAttribute = RuneConfig.openedAttribute(poolName)
	player:SetAttribute(openedAttribute, (player:GetAttribute(openedAttribute) or 0) + count)
	runesRolledFire(player, poolName, results, pool.runes[bestIndex].name)
end)
