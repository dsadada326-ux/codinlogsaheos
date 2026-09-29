local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local Multipliers = require(ReplicatedStorage:WaitForChild("Multipliers"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))

local timeReward = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("TimeReward")

-- the pad you stand on to earn Time
local timeButton = workspace
	:WaitForChild("Islands")
	:WaitForChild("Island1")
	:WaitForChild("Zones")
	:WaitForChild("Time")
	:WaitForChild("TimeButton")
	:WaitForChild("Button")

local STAND_HEIGHT = 8   -- studs above the pad that still count as standing on it
local POPUP_EVERY = 0.35 -- seconds between +Time popups (gains are added up in between)
local MIN_INTERVAL = 0.1 -- fastest possible gain, whatever the upgrades say

local timeZone = ZoneConfig.find("Time")

local state = {} -- [player] = { accum, pending, lastPopup }

local function round2(number)
	return math.floor(number * 100 + 0.5) / 100
end

local function upgradeValue(player, id)
	return UpgradeConfig.valueAt(id, player:GetAttribute(UpgradeConfig.levelAttribute(id)) or 0)
end

-- is this player's character standing on the Time button?
local function isOnButton(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local offset = timeButton.CFrame:PointToObjectSpace(root.Position)
	local half = timeButton.Size / 2

	return math.abs(offset.X) <= half.X
		and math.abs(offset.Z) <= half.Z
		and offset.Y >= 0
		and offset.Y <= half.Y + STAND_HEIGHT
end

RunService.Heartbeat:Connect(function(deltaTime)
	local now = os.clock()

	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("DataLoaded") == true and ZoneConfig.isRevealed(player, timeZone) then
			local s = state[player]

			if not s then
				s = { accum = 0, pending = 0, lastPopup = 0 }
				state[player] = s
			end

			local onButton = isOnButton(player)
			local auto = upgradeValue(player, "AutoTime") >= 1

			-- tells the client to light up the pad
			if player:GetAttribute("OnTimeButton") ~= onButton then
				player:SetAttribute("OnTimeButton", onButton)
			end

			if onButton or auto then
				local interval = math.max(upgradeValue(player, "TimeSpeed"), MIN_INTERVAL)
				local perTick = Multipliers.time(player) -- Time Multiplier x Gems x prestige x Upgrade Tree

				s.accum += deltaTime

				local gained = 0

				while s.accum >= interval do
					s.accum -= interval
					gained += perTick
				end

				if gained > 0 then
					player:SetAttribute("Time", round2((player:GetAttribute("Time") or 0) + gained))
					s.pending += gained
				end

				if s.pending > 0 and now - s.lastPopup >= POPUP_EVERY then
					timeReward:FireClient(player, round2(s.pending), onButton)
					s.pending = 0
					s.lastPopup = now
				end
			else
				s.accum = 0
				s.pending = 0
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
end)
