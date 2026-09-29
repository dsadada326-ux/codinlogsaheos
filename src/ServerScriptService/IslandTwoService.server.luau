local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IslandTwoConfig = require(ReplicatedStorage:WaitForChild("IslandTwoConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local FishingFrenzyConfig = require(ReplicatedStorage:WaitForChild("FishingFrenzyConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local woodChop = remotes:WaitForChild("WoodChop")        -- server -> client: (damage, hp, maxHp, woodGained or nil)
local tierUpRemote = remotes:WaitForChild("TierUp")
local travelRemote = remotes:WaitForChild("TravelIsland")
local selectTreeRemote = remotes:WaitForChild("SelectTree") -- client -> server: (tree index)

local island2 = workspace:WaitForChild("Islands"):WaitForChild("Island2")
local button = island2:WaitForChild("BlueButton"):WaitForChild("Button")
local clickPart = button:WaitForChild("ClickPart")

local function round2(n)
	return math.floor(n * 100 + 0.5) / 100
end

------------------------------------------------------------------------------------------
-- each player has their own tree: HP, and a respawn timer while it's down.
-- Attributes the client shows: TreeHP, TreeMaxHP, TreeRespawnAt, BlueReadyAt (server time)
------------------------------------------------------------------------------------------
local lastClick = {}

local function resetTree(player)
	local maxHp = IslandTwoConfig.maxHP(player)
	player:SetAttribute("TreeMaxHP", maxHp)
	player:SetAttribute("TreeHP", maxHp)
	player:SetAttribute("TreeRespawnAt", 0)
end

local function chop(player)
	if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("Island2Unlocked") ~= true then
		return
	end

	-- no tree, no click: the button only works while the tree is actually standing
	if (player:GetAttribute("TreeRespawnAt") or 0) > workspace:GetServerTimeNow() then
		return
	end

	-- the button's cooldown
	local now = os.clock()
	local cooldown = IslandTwoConfig.cooldown(player)

	if now - (lastClick[player] or 0) < cooldown * 0.9 then
		return
	end

	lastClick[player] = now
	player:SetAttribute("BlueReadyAt", workspace:GetServerTimeNow() + cooldown)

	local maxHp = IslandTwoConfig.maxHP(player)
	local hp = math.min(player:GetAttribute("TreeHP") or maxHp, maxHp)
	local damage = IslandTwoConfig.damage(player)

	hp = math.max(hp - damage, 0)
	player:SetAttribute("TreeMaxHP", maxHp)
	player:SetAttribute("TreeHP", hp)

	if hp <= 0 then
		local wood = IslandTwoConfig.woodPerTree(player)
		player:SetAttribute("Wood", round2((player:GetAttribute("Wood") or 0) + wood))
		player:SetAttribute("TreesBeaten", (player:GetAttribute("TreesBeaten") or 0) + 1)
		player:SetAttribute("TreeRespawnAt", workspace:GetServerTimeNow() + IslandTwoConfig.RespawnSeconds)
		woodChop:FireClient(player, damage, 0, maxHp, wood)
	else
		woodChop:FireClient(player, damage, hp, maxHp, nil)
	end
end

local detector = clickPart:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
detector.MaxActivationDistance = 100000
detector.Parent = clickPart
detector.MouseClick:Connect(chop)

-- trees grow back after RespawnSeconds
RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()

	for _, player in ipairs(Players:GetPlayers()) do
		local at = player:GetAttribute("TreeRespawnAt") or 0

		if at > 0 and now >= at then
			resetTree(player)
		end
	end
end)

------------------------------------------------------------------------------------------
-- Tier Up: costs Wood, resets Wood + the tree upgrades, next tier's bonuses apply
------------------------------------------------------------------------------------------
tierUpRemote.OnServerInvoke = function(player)
	if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("Island2Unlocked") ~= true then
		return { ok = false, reason = "locked" }
	end

	local _, index = IslandTwoConfig.tier(player)
	local nextTier = IslandTwoConfig.Tiers[index + 1]

	if not nextTier then
		return { ok = false, reason = "max" }
	end

	if (player:GetAttribute("Wood") or 0) < nextTier.cost then
		return { ok = false, reason = "wood" }
	end

	player:SetAttribute("Wood", 0)

	for _, id in ipairs(UpgradeConfig.Order) do
		if UpgradeConfig.Upgrades[id].ResetOnTier then
			player:SetAttribute(UpgradeConfig.levelAttribute(id), 0)
		end
	end

	player:SetAttribute("SelectedTree", index + 1)
	player:SetAttribute("TreeTier", index + 1)
	resetTree(player)

	return { ok = true, tier = index + 1 }
end

------------------------------------------------------------------------------------------
-- picking which tree to chop (the Tree board's arrows): any tree you've reached
------------------------------------------------------------------------------------------
local lastSelect = {}

selectTreeRemote.OnServerEvent:Connect(function(player, index)
	if typeof(index) ~= "number" or index ~= index then
		return
	end

	if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("Island2Unlocked") ~= true then
		return
	end

	local now = os.clock()
	if now - (lastSelect[player] or 0) < 0.15 then
		return
	end
	lastSelect[player] = now

	local _, highest = IslandTwoConfig.tier(player)
	index = math.clamp(math.floor(index), 1, highest)

	if index == select(2, IslandTwoConfig.selected(player)) then
		return
	end

	player:SetAttribute("SelectedTree", index)

	-- a new tree starts at full HP; if the current one is down, the new one grows back on the same timer
	local maxHp = IslandTwoConfig.maxHP(player)
	player:SetAttribute("TreeMaxHP", maxHp)
	if (player:GetAttribute("TreeRespawnAt") or 0) <= workspace:GetServerTimeNow() then
		player:SetAttribute("TreeHP", maxHp)
	end
end)

------------------------------------------------------------------------------------------
-- travelling: the Island 2 board (first time unlocks it) and the side-menu Travel button
------------------------------------------------------------------------------------------
local function standingSpot(islandName)
	if islandName == "Island2" then
		local b = button:WaitForChild("Button")
		return b.Position + Vector3.new(14, 4, 0)
	end

	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	return (spawn and spawn.Position or Vector3.new(0, 5, 0)) + Vector3.new(0, 4, 0)
end

-- come out of a portal (Islands.Island1.Portals.<name>): stand on its TeleportToPart, facing away
-- from the door. FishingFrenzy = back on Island 1, Labratory = back on Island 2,
-- labratoryback = inside the Laboratory
local function portalSpot(name)
	local islands = workspace:FindFirstChild("Islands")
	local island1 = islands and islands:FindFirstChild("Island1")
	local portals = island1 and island1:FindFirstChild("Portals")
	local portal = portals and portals:FindFirstChild(name)
	local arrive = portal and portal:FindFirstChild("TeleportToPart")
	local door = portal and portal:FindFirstChild("TeleportPart")
	if not arrive then
		return nil
	end
	local pos = arrive.Position + Vector3.new(0, 1, 0)
	local away = door and (pos - door.Position) * Vector3.new(1, 0, 1)
	if not away or away.Magnitude < 0.01 then
		return CFrame.new(pos)
	end
	return CFrame.lookAt(pos, pos + away.Unit)
end

travelRemote.OnServerInvoke = function(player, islandName, via)
	if player:GetAttribute("DataLoaded") ~= true then
		return { ok = false, reason = "loading" }
	end

	if islandName == "Island2" and player:GetAttribute("Island2Unlocked") ~= true then
		if not IslandTwoConfig.canUnlock(player) then
			return { ok = false, reason = "locked" }
		end

		player:SetAttribute("Island2Unlocked", true)
		resetTree(player)
	end

	if islandName ~= "Island1" and islandName ~= "Island2" and islandName ~= "FishingFrenzy" and islandName ~= "Laboratory" then
		return { ok = false, reason = "unknown" }
	end

	-- the Laboratory is Island 2's sub-island
	if islandName == "Laboratory" and player:GetAttribute("Island2Unlocked") ~= true then
		return { ok = false, reason = "locked" }
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if root then
		-- Fishing Frenzy (Island 1's sub-island): in front of its portal
		local target
		if islandName == "FishingFrenzy" then
			target = FishingFrenzyConfig.arrival()
		elseif islandName == "Laboratory" then
			-- in front of the lab's way-out portal
			target = portalSpot("labratoryback")
		elseif islandName == "Island1" and via == "portal" then
			target = portalSpot("FishingFrenzy")
		elseif islandName == "Island2" and via == "portal" then
			target = portalSpot("Labratory")
		end
		target = target or (islandName ~= "Laboratory" and CFrame.new(standingSpot(islandName)))

		if not target then
			return { ok = false, reason = "missing" }
		end

		pcall(function()
			player:RequestStreamAroundAsync(target.Position, 5)
		end)

		character:PivotTo(target)
	end

	return { ok = true }
end

------------------------------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		if player:GetAttribute("DataLoaded") then
			resetTree(player)
		end
	end)

	-- tier changes the tree's size
	player:GetAttributeChangedSignal("TreeTier"):Connect(function()
		resetTree(player)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player:GetAttribute("DataLoaded") then
		resetTree(player)
	end
end

Players.PlayerRemoving:Connect(function(player)
	lastClick[player] = nil
	lastSelect[player] = nil
end)
