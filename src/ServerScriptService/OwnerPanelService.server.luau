-- Owner Panel (server). Only owners get the panel, and every change is checked again here,
-- so nobody else can use it even if they fire the remote themselves.
--   Owners = the UserIds in OWNERS, plus the owner (rank 255) of the group that owns the game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local OWNERS = {
	[11283839999] = true, -- aheosturn
}

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("OwnerSetValue")
local panelTemplate = ServerStorage:WaitForChild("OwnerPanel")

-- attributes the panel must never touch (they'd break saving / loading)
local BLOCKED = { DataLoaded = true }

local ownerCache = {}

local function isOwner(player)
	if ownerCache[player] ~= nil then
		return ownerCache[player]
	end

	local ok = OWNERS[player.UserId] == true

	if not ok and game.CreatorType == Enum.CreatorType.Group then
		local success, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		ok = success and rank == 255
	elseif not ok and game.CreatorType == Enum.CreatorType.User then
		ok = player.UserId == game.CreatorId
	end

	ownerCache[player] = ok
	return ok
end

local function round2(n)
	return math.floor(n * 100 + 0.5) / 100
end

remote.OnServerInvoke = function(player, attribute, mode, value)
	if not isOwner(player) then
		warn("[OwnerPanel] " .. player.Name .. " tried to use the owner panel without permission")
		return { ok = false, message = "Not allowed" }
	end

	if typeof(attribute) ~= "string" or #attribute == 0 or #attribute > 100 or not attribute:match("^[%w_]+$") then
		return { ok = false, message = "Bad value name" }
	end

	if BLOCKED[attribute] or attribute:sub(1, 1) == "_" then
		return { ok = false, message = "That one is protected" }
	end

	local current = player:GetAttribute(attribute)

	if mode == "toggle" then
		if type(current) ~= "boolean" then
			return { ok = false, message = "Not a true/false value" }
		end
		player:SetAttribute(attribute, not current)
		return { ok = true, value = not current }
	end

	if typeof(value) == "boolean" then
		if current ~= nil and type(current) ~= "boolean" then
			return { ok = false, message = attribute .. " is a number" }
		end
		player:SetAttribute(attribute, value)
		return { ok = true, value = value }
	end

	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return { ok = false, message = "Bad number" }
	end

	if current ~= nil and type(current) ~= "number" then
		return { ok = false, message = attribute .. " is true/false" }
	end

	local new = mode == "add" and (current or 0) + value or value
	new = math.abs(new) < 1e15 and round2(new) or new
	player:SetAttribute(attribute, new)

	return { ok = true, value = new }
end

local function give(player)
	if not isOwner(player) then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")

	if not playerGui:FindFirstChild("OwnerPanel") then
		local panel = panelTemplate:Clone()
		panel.ResetOnSpawn = false
		panel.Parent = playerGui
	end
end

Players.PlayerAdded:Connect(give)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(give, player)
end

Players.PlayerRemoving:Connect(function(player)
	ownerCache[player] = nil
end)
