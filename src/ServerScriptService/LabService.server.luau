-- THE LABORATORY (server). The real rules for the lab tycoon: red buttons, the mixing
-- minigame, the oxygen pump, passive production, brewing, selling potions and the Knowledge
-- shop. Tuning lives in ReplicatedStorage.LabConfig.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LabConfig = require(ReplicatedStorage:WaitForChild("LabConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local actionRemote = remotes:FindFirstChild("LabAction") or Instance.new("RemoteFunction")
actionRemote.Name = "LabAction"
actionRemote.Parent = remotes

local rng = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

local function round2(n)
	return math.floor(n * 100 + 0.5) / 100
end

local function add(player, attr, amount)
	player:SetAttribute(attr, round2((player:GetAttribute(attr) or 0) + amount))
end

local function loaded(player)
	return player:GetAttribute("DataLoaded") == true
end

------------------------------------------------------------------------------------------
-- the mixing minigame: a marker sweeps left-right; hit MIX while it's in the green zone.
-- The round lives on the player as attributes so their screen draws the same thing.
------------------------------------------------------------------------------------------
local M = LabConfig.Mix

local function markerAt(player, t)
	local t0 = player:GetAttribute("LabMixT0") or 0
	local speed = player:GetAttribute("LabMixSpeed") or M.Speed[1]
	local u = ((t - t0) * speed) % 2
	return u < 1 and u or 2 - u
end

local function newRound(player)
	local streak = player:GetAttribute("LabStreak") or 0
	local k = math.clamp(streak / M.StreakMax, 0, 1)
	local width = M.Zone[1] + (M.Zone[2] - M.Zone[1]) * k
	local speed = M.Speed[1] + (M.Speed[2] - M.Speed[1]) * k
	player:SetAttribute("LabMixWidth", width)
	player:SetAttribute("LabMixZone", rng:NextNumber(width / 2 + 0.06, 1 - width / 2 - 0.06))
	player:SetAttribute("LabMixSpeed", speed)
	player:SetAttribute("LabMixT0", now())
end

------------------------------------------------------------------------------------------
local Actions = {}

function Actions.buy(player, id)
	if type(id) ~= "string" or not LabConfig.available(player, id) then
		return { ok = false, reason = "unavailable" }
	end
	local def = LabConfig.Items[id]
	local attr = LabConfig.Currencies[def.currency].attr
	local have = player:GetAttribute(attr) or 0
	if have < def.cost then
		return { ok = false, reason = "cost" }
	end
	player:SetAttribute(attr, round2(have - def.cost))
	player:SetAttribute(LabConfig.ownedAttribute(id), true)
	if id == "ChemistryStation" then
		player:SetAttribute("LabStreak", 0)
		newRound(player)
	end
	return { ok = true }
end

function Actions.mix(player, clientTime)
	if not LabConfig.owns(player, "ChemistryStation") then
		return { ok = false, reason = "locked" }
	end
	local t = now()
	-- judge the click at the moment the player clicked (their clock is synced to ours),
	-- as long as it's recent
	local at = t
	if type(clientTime) == "number" and clientTime <= t + 0.1 and clientTime >= t - 0.6 then
		at = clientTime
	end
	if at < (player:GetAttribute("LabMixT0") or 0) then
		return { ok = false, reason = "early" }
	end
	local pos = markerAt(player, at)
	local zone = player:GetAttribute("LabMixZone") or 0.5
	local width = player:GetAttribute("LabMixWidth") or M.Zone[1]
	local dist = math.abs(pos - zone)
	local hit = dist <= width / 2 + 0.015
	local perfect = dist <= width * 0.16
	local streak = player:GetAttribute("LabStreak") or 0
	local gain = 0
	if hit then
		streak = math.min(streak + 1, M.StreakMax)
		gain = M.Base
			* (LabConfig.owns(player, "MixingBench") and 2 or 1)
			* (1 + streak * LabConfig.streakStep(player))
			* (perfect and M.PerfectBonus or 1)
			* LabConfig.chemMultiplier(player)
		gain = round2(gain)
		add(player, "Chemicals", gain)
	else
		streak = 0
	end
	player:SetAttribute("LabStreak", streak)
	newRound(player)
	return { ok = true, hit = hit, perfect = perfect, gain = gain, streak = streak, pos = pos }
end

local P = LabConfig.Pump
function Actions.pump(player)
	if not LabConfig.owns(player, "OxygenGenerator") then
		return { ok = false, reason = "locked" }
	end
	local t = now()
	local p = player:GetAttribute("LabPressure") or 0
	local at = player:GetAttribute("LabPressureAt") or t
	p = math.max(0, p - P.Decay * (t - at)) + P.PerClick
	local burst = 0
	if p >= 1 then
		burst = round2(P.Burst * LabConfig.oxygenMultiplier(player))
		add(player, "Oxygen", burst)
		p = 0
	end
	player:SetAttribute("LabPressure", p)
	player:SetAttribute("LabPressureAt", t)
	return { ok = true, pressure = p, burst = burst }
end

function Actions.brew(player, brewId)
	local brew = LabConfig.BrewById[brewId]
	if not brew or not LabConfig.owns(player, brew.needs) then
		return { ok = false, reason = "locked" }
	end
	for cur, amount in pairs(brew.cost) do
		if (player:GetAttribute(LabConfig.Currencies[cur].attr) or 0) < amount then
			return { ok = false, reason = "cost", missing = cur }
		end
	end
	for cur, amount in pairs(brew.cost) do
		add(player, LabConfig.Currencies[cur].attr, -amount)
	end
	local bag = LabConfig.potions(player)
	local got = {}
	for _ = 1, 1 + LabConfig.level(player, "BulkBrew") + LabConfig.extraPotions(player) do
		local p = LabConfig.roll(player, brew, rng)
		bag[p.id] = (bag[p.id] or 0) + 1
		table.insert(got, p.id)
	end
	player:SetAttribute("LabPotions", LabConfig.encode(bag))
	return { ok = true, potions = got }
end

function Actions.sell(player)
	local bag = LabConfig.potions(player)
	local total, count = 0, 0
	for id, n in pairs(bag) do
		local p = LabConfig.PotionById[id]
		if p and n > 0 then
			total += p.value * n
			count += n
		end
	end
	if count == 0 then
		return { ok = false, reason = "empty" }
	end
	total = math.floor(total * LabConfig.sellMultiplier(player))
	add(player, "Knowledge", total)
	player:SetAttribute("LabPotions", "{}")
	return { ok = true, knowledge = total, count = count }
end

-- staff + decor from the Lab Shop
function Actions.buyExtra(player, id)
	local e = type(id) == "string" and LabConfig.ExtraById[id]
	if not e then
		return { ok = false, reason = "unknown" }
	end
	if LabConfig.ownsExtra(player, id) then
		return { ok = false, reason = "owned" }
	end
	local attr = LabConfig.Currencies[e.currency].attr
	local have = player:GetAttribute(attr) or 0
	if have < e.cost then
		return { ok = false, reason = "cost" }
	end
	player:SetAttribute(attr, round2(have - e.cost))
	player:SetAttribute(LabConfig.extraAttribute(id), true)
	return { ok = true }
end

function Actions.upgrade(player, id)
	local u = LabConfig.UpgradeById[id]
	if not u then
		return { ok = false, reason = "unknown" }
	end
	local level = LabConfig.level(player, id)
	if level >= u.max then
		return { ok = false, reason = "max" }
	end
	local cost = LabConfig.upgradeCost(id, level)
	local have = player:GetAttribute("Knowledge") or 0
	if have < cost then
		return { ok = false, reason = "cost" }
	end
	player:SetAttribute("Knowledge", round2(have - cost))
	player:SetAttribute(LabConfig.upgradeAttribute(id), level + 1)
	return { ok = true, level = level + 1 }
end

------------------------------------------------------------------------------------------
-- Lab Level (resets the tycoon) and Advancement Marks (resets levels + Knowledge too)
------------------------------------------------------------------------------------------
local function resetTycoon(player)
	for _, cur in ipairs({ "Chemicals", "Oxygen", "CarbonDioxide" }) do
		player:SetAttribute(cur, 0)
	end
	for _, id in ipairs(LabConfig.Order) do
		player:SetAttribute(LabConfig.ownedAttribute(id), false)
	end
	player:SetAttribute("LabPressure", 0)
	player:SetAttribute("LabStreak", 0)
	newRound(player)
end

function Actions.levelUp(player)
	local level = LabConfig.labLevel(player)
	local nextLevel = LabConfig.Levels[level + 1]
	if not nextLevel then
		return { ok = false, reason = "max" }
	end
	if (player:GetAttribute("Chemicals") or 0) < nextLevel.cost then
		return { ok = false, reason = "cost" }
	end
	resetTycoon(player)
	player:SetAttribute("LabLevel", level + 1)
	return { ok = true, level = level + 1 }
end

function Actions.advance(player)
	local mark = LabConfig.labMark(player)
	if mark >= LabConfig.MaxMark then
		return { ok = false, reason = "max" }
	end
	if LabConfig.labLevel(player) < LabConfig.MaxLevel then
		return { ok = false, reason = "level" }
	end
	resetTycoon(player)
	player:SetAttribute("LabLevel", 0)
	player:SetAttribute("Knowledge", 0)
	for _, u in ipairs(LabConfig.Upgrades) do
		player:SetAttribute(LabConfig.upgradeAttribute(u.id), 0)
	end
	for id in pairs(LabConfig.ExtraById) do
		player:SetAttribute(LabConfig.extraAttribute(id), false)
	end
	player:SetAttribute("LabMark", mark + 1)
	return { ok = true, mark = mark + 1 }
end

local COOLDOWNS = { mix = M.Cooldown, pump = P.Cooldown, levelUp = 1, advance = 1 }
local last = {}
actionRemote.OnServerInvoke = function(player, action, ...)
	if type(action) ~= "string" or not Actions[action] then
		return { ok = false, reason = "unknown" }
	end
	if not loaded(player) then
		return { ok = false, reason = "loading" }
	end
	last[player] = last[player] or {}
	local t = os.clock()
	if t - (last[player][action] or 0) < (COOLDOWNS[action] or 0.15) then
		return { ok = false, reason = "cooldown" }
	end
	last[player][action] = t
	local ok, result = pcall(Actions[action], player, ...)
	if not ok then
		warn("[LabService] " .. action .. ": " .. tostring(result))
		return { ok = false, reason = "error" }
	end
	return result
end

------------------------------------------------------------------------------------------
-- passive production (Chem Tanks + mixing staff, Oxygen Generator, CO2 Extractor)
------------------------------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			if loaded(player) then
				local perSecond = (LabConfig.owns(player, "ChemTanks") and LabConfig.Passive.Chemicals or 0) + LabConfig.autoMix(player)
				if perSecond > 0 then
					add(player, "Chemicals", perSecond * LabConfig.chemMultiplier(player))
				end
				if LabConfig.owns(player, "OxygenGenerator") then
					add(player, "Oxygen", LabConfig.Passive.Oxygen * LabConfig.oxygenMultiplier(player))
				end
				if LabConfig.owns(player, "CO2Extractor") then
					add(player, "CarbonDioxide", LabConfig.Passive.CarbonDioxide * LabConfig.co2Multiplier(player))
				end
			end
		end
	end
end)

-- a fresh round for anyone who already owns the station
local function onPlayer(player)
	task.spawn(function()
		while player.Parent and not loaded(player) do
			task.wait(0.5)
		end
		if player.Parent then
			player:SetAttribute("LabStreak", 0)
			newRound(player)
		end
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end
Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
end)
