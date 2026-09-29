-- Profile lookups: GetProfile(nil) = you, GetProfile("name") = anyone (online players first,
-- then anyone who has ever played, read from their save). EquipTitle(id) sets your title.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local RuneConfig = require(ReplicatedStorage:WaitForChild("RuneConfig"))
local Multipliers = require(ReplicatedStorage:WaitForChild("Multipliers"))
local ProfileConfig = require(ReplicatedStorage:WaitForChild("ProfileConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getRemote = remotes:WaitForChild("GetProfile")
local equipRemote = remotes:WaitForChild("EquipTitle")

-- something that answers :GetAttribute like a Player (for saves of people who aren't here)
local function fromSave(data, userId)
	local proxy = { UserId = userId }
	function proxy:GetAttribute(name)
		return data[name]
	end
	function proxy:FindFirstChild() return nil end
	return proxy
end

local function safe(f, who, default)
	local ok, v = pcall(f, who)
	return ok and tonumber(v) or default
end

local function statsFor(who)
	local runes = 0
	for poolName in pairs(RuneConfig.Pools) do
		runes += tonumber(who:GetAttribute(RuneConfig.openedAttribute(poolName))) or 0
	end
	return {
		TimePlayed = tonumber(who:GetAttribute("Playtime")) or 0,
		RunesRolled = runes,
		RobuxSpent = tonumber(who:GetAttribute("RobuxSpent")) or 0,
		TotalButtons = tonumber(who:GetAttribute("TotalButtons")) or 0,
		RuneBulk = math.max(1, math.floor(safe(Multipliers.runeBulk, who, 1))),
		RuneSpeed = safe(Multipliers.runeSpeed, who, 1),
		RuneLuck = safe(Multipliers.runeLuck, who, 1),
		Prestige = tonumber(who:GetAttribute("Prestige")) or 0,
		Rebirths = tonumber(who:GetAttribute("Rebirths")) or 0,
		FishCaught = tonumber(who:GetAttribute("FishCaught")) or 0,
		Title = who:GetAttribute("EquippedTitle") or "",
	}
end

local function packet(userId, name, displayName, stats, online)
	return { ok = true, userId = userId, name = name, displayName = displayName, stats = stats, online = online }
end

local function findOnline(query)
	query = query:lower()
	-- exact name first, then a name / display name that starts with it
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == query or p.DisplayName:lower() == query then return p end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():sub(1, #query) == query or p.DisplayName:lower():sub(1, #query) == query then return p end
	end
	return nil
end

local lastLookup = {}
getRemote.OnServerInvoke = function(player, query)
	if query == nil or query == "" then
		return packet(player.UserId, player.Name, player.DisplayName, statsFor(player), true)
	end
	if type(query) ~= "string" or #query > 20 then
		return { ok = false, reason = "bad" }
	end
	query = query:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^@", "")

	local online = findOnline(query)
	if online then
		return packet(online.UserId, online.Name, online.DisplayName, statsFor(online), true)
	end

	-- offline lookups hit Roblox + the DataStore: slow them down a little
	local now = os.clock()
	if now - (lastLookup[player] or 0) < 1.5 then
		return { ok = false, reason = "slow" }
	end
	lastLookup[player] = now

	local okId, userId = pcall(function() return Players:GetUserIdFromNameAsync(query) end)
	if not okId or not userId then
		return { ok = false, reason = "nobody" }
	end
	local okName, realName = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	realName = okName and realName or query

	local reader = ServerStorage:FindFirstChild("ReadSavedData")
	local data = reader and reader:Invoke(userId)
	if not data then
		return { ok = false, reason = "never", userId = userId, name = realName }
	end
	return packet(userId, realName, realName, statsFor(fromSave(data, userId)), false)
end

equipRemote.OnServerInvoke = function(player, titleId)
	if titleId == "" or titleId == nil then
		player:SetAttribute("EquippedTitle", "")
		return { ok = true }
	end
	if type(titleId) ~= "string" or not ProfileConfig.titleUnlocked(statsFor(player), titleId) then
		return { ok = false }
	end
	player:SetAttribute("EquippedTitle", titleId)
	return { ok = true }
end

Players.PlayerRemoving:Connect(function(player)
	lastLookup[player] = nil
end)
