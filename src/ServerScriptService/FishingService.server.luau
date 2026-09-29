-- Fishing Frenzy (server). The real rules for everything on the fishing island:
--   casting + reeling (only from a bridge, into the pond), the fish you carry (tools, saved in
--   FishInventory), selling, rods, Shell Upgrades, Fish Tiers, Fishing Prestige, Conversion,
--   auto-fishers, and the shells that spawn on the sand.
-- Numbers/costs are all in ReplicatedStorage.FishingConfig.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local FishingConfig = require(ReplicatedStorage:WaitForChild("FishingConfig"))
local FishingFrenzyConfig = require(ReplicatedStorage:WaitForChild("FishingFrenzyConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local castRemote = remotes:WaitForChild("FishingCast")
local reelRemote = remotes:WaitForChild("FishingReel")
local eventRemote = remotes:WaitForChild("FishingEvent")
local buyRodRemote = remotes:WaitForChild("BuyRod")
local equipRodRemote = remotes:WaitForChild("EquipRod")
local sellRemote = remotes:WaitForChild("SellFish")
local shellUpRemote = remotes:WaitForChild("BuyShellUpgrade")
local tierRemote = remotes:WaitForChild("FishTierUp")
local prestigeRemote = remotes:WaitForChild("FishPrestige")
local autoFisherRemote = remotes:WaitForChild("BuyAutoFisher")
local convertRemote = remotes:WaitForChild("ConvertCrabs")

local assets = ReplicatedStorage:WaitForChild("FishingAssets")
local island = workspace:WaitForChild("Islands"):WaitForChild(FishingConfig.IslandName)
local map = island:WaitForChild("Map")
local water = map:WaitForChild("WaterArea")
local stands = island:WaitForChild("FishingStands")

local rng = Random.new()

local function round(n)
	return math.floor(n + 0.5)
end

local function add(player, attribute, amount)
	player:SetAttribute(attribute, (player:GetAttribute(attribute) or 0) + amount)
end

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and humanoid and humanoid.Health > 0 then
		return root, character
	end
	return nil
end

local function onIsland(player)
	local root = rootOf(player)
	return root ~= nil and FishingFrenzyConfig.isInside(root.Position)
end

local function nearStand(player, standName, range)
	local root = rootOf(player)
	local stand = stands:FindFirstChild(standName)
	return root ~= nil and stand ~= nil and (root.Position - stand:GetBoundingBox().Position).Magnitude <= (range or 25)
end

------------------------------------------------------------------------------------------
-- bridges (numbered 1-8; Start / Tip / Facing attributes set in Studio)
------------------------------------------------------------------------------------------
local bridges = {}
for _, b in ipairs(island:GetChildren()) do
	local n = b:GetAttribute("BridgeIndex")
	if n then
		bridges[n] = b
	end
end

local bridgeParams = RaycastParams.new()
bridgeParams.FilterType = Enum.RaycastFilterType.Include
do
	local list = {}
	for _, b in pairs(bridges) do table.insert(list, b) end
	bridgeParams.FilterDescendantsInstances = list
end

local function bridgeUnder(position)
	local hit = workspace:Raycast(position, Vector3.new(0, -9, 0), bridgeParams)
	if not hit then
		return nil
	end
	local model = hit.Instance
	while model and model.Parent ~= island do
		model = model.Parent
	end
	return model
end

local function inPond(position)
	local d = position - water.Position
	return math.abs(d.X) <= water.Size.X / 2 - 1 and math.abs(d.Z) <= water.Size.Z / 2 - 1
end

------------------------------------------------------------------------------------------
-- the fish you carry: inventory table (saved as JSON) + one Tool per fish while on the island
------------------------------------------------------------------------------------------
local inventories = {} -- [player] = { { f = id, w = kg, u = uid } }
local uidCounter = 0

local function save(player)
	local inv = inventories[player]
	if not inv then return end
	local plain = {}
	for i, e in ipairs(inv) do
		plain[i] = { f = e.f, w = e.w }
	end
	player:SetAttribute("FishInventory", HttpService:JSONEncode(plain))
	player:SetAttribute("FishCarried", #inv)
end

local function load(player)
	local inv = {}
	local ok, data = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("FishInventory") or "[]")
	end)
	if ok and type(data) == "table" then
		for _, e in ipairs(data) do
			if type(e) == "table" and FishingConfig.FishById[e.f] and tonumber(e.w) then
				uidCounter += 1
				table.insert(inv, { f = e.f, w = tonumber(e.w), u = uidCounter })
			end
		end
	end
	inventories[player] = inv
	player:SetAttribute("FishCarried", #inv)
end

local function sellValue(player, entry)
	local fish = FishingConfig.FishById[entry.f]
	return round(FishingConfig.baseValue(fish, entry.w) * FishingConfig.fishMealMultiplier(player))
end

-- tools --------------------------------------------------------------------------------
local rodTemplates = {}

local function buildRodTool(rod)
	if rodTemplates[rod.id] then
		return rodTemplates[rod.id]:Clone()
	end

	local source = assets.Rods:FindFirstChild(rod.model)
	local tool = Instance.new("Tool")
	tool.Name = rod.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("FishingTool", "Rod")
	tool:SetAttribute("RodId", rod.id)

	if source then
		local copy = source:Clone()
		local main
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("BasePart") and (not main or d.Size.Magnitude > main.Size.Magnitude) then
				main = d
			end
		end
		local gripWorld = copy:FindFirstChild("Handle") and copy.Handle:IsA("Attachment") and copy.Handle.WorldPosition

		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.Massless = true
				d.CanQuery = false
				d.CanTouch = d == main
				if d ~= main then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = main
					weld.Part1 = d
					weld.Parent = d
				end
			end
		end

		for _, d in ipairs(copy:GetChildren()) do
			if d:IsA("BasePart") or d:IsA("Model") then
				d.Parent = tool
			end
		end
		main.Name = "Handle"

		-- where your hand goes (the model's grip point) and the tip the line hangs from
		local gripLocal = gripWorld and main.CFrame:PointToObjectSpace(gripWorld) or Vector3.new(0, -main.Size.Y * 0.35, 0)
		local tip = Instance.new("Attachment")
		tip.Name = "Tip"
		tip.Position = Vector3.new(0, main.Size.Y / 2 - 0.1, 0)
		tip.Parent = main
		-- rod held forward and angled up, like it's ready to cast
		tool.Grip = CFrame.new(gripLocal) * CFrame.Angles(math.rad(60), 0, 0)
		copy:Destroy()
	else
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.2, 6, 0.2)
		handle.Color = Color3.fromRGB(140, 95, 55)
		handle.CanCollide = false
		handle.Parent = tool
		local tip = Instance.new("Attachment")
		tip.Name = "Tip"
		tip.Position = Vector3.new(0, 3, 0)
		tip.Parent = handle
		tool.Grip = CFrame.new(0, -2, 0) * CFrame.Angles(math.rad(60), 0, 0)
	end

	rodTemplates[rod.id] = tool
	return tool:Clone()
end

local function fishModel(id)
	local source = assets.Fish:FindFirstChild(id)
	return source and source:Clone()
end

local function buildFishTool(entry)
	local fish = FishingConfig.FishById[entry.f]
	local tool = Instance.new("Tool")
	tool.Name = fish.name .. " (" .. FishingConfig.formatKg(entry.w) .. ")"
	tool.ToolTip = fish.rarity .. " " .. fish.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("FishingTool", "Fish")
	tool:SetAttribute("Fish", fish.id)
	tool:SetAttribute("Kg", entry.w)
	tool:SetAttribute("Uid", entry.u)

	local model = fishModel(fish.id)
	if model then
		local handle = model.PrimaryPart or model:FindFirstChild("Handle")
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.Massless = true
			end
		end
		for _, d in ipairs(model:GetChildren()) do
			d.Parent = tool
		end
		handle.Name = "Handle"
		model:Destroy()
		-- held out in front, side-on, belly down
		tool.Grip = CFrame.new(0, 0, -fish.length * 0.15) * CFrame.Angles(0, math.rad(90), 0)
	end
	return tool
end

local function fishingTools(player)
	local list = {}
	for _, container in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		if container then
			for _, t in ipairs(container:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("FishingTool") then
					table.insert(list, t)
				end
			end
		end
	end
	return list
end

local function syncTools(player)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack or player:GetAttribute("DataLoaded") ~= true or not inventories[player] then
		return
	end

	local want = onIsland(player)
	local tools = fishingTools(player)

	if not want then
		for _, t in ipairs(tools) do t:Destroy() end
		return
	end

	-- the rod you have equipped
	local rod = FishingConfig.equippedRod(player)
	local haveRod = false
	local haveFish = {}
	for _, t in ipairs(tools) do
		if t:GetAttribute("FishingTool") == "Rod" then
			if t:GetAttribute("RodId") == rod.id and not haveRod then
				haveRod = true
			else
				t:Destroy()
			end
		else
			local uid = t:GetAttribute("Uid")
			local keep = false
			for _, e in ipairs(inventories[player]) do
				if e.u == uid then keep = true break end
			end
			if keep and not haveFish[uid] then
				haveFish[uid] = true
			else
				t:Destroy()
			end
		end
	end

	if not haveRod then
		local tool = buildRodTool(rod)
		tool.Parent = backpack
	end

	for _, e in ipairs(inventories[player]) do
		if not haveFish[e.u] then
			buildFishTool(e).Parent = backpack
		end
	end
end

local function removeFish(player, uid)
	local inv = inventories[player]
	for i, e in ipairs(inv) do
		if e.u == uid then
			table.remove(inv, i)
			for _, t in ipairs(fishingTools(player)) do
				if t:GetAttribute("Uid") == uid then t:Destroy() end
			end
			return e
		end
	end
	return nil
end

local function clearFish(player)
	inventories[player] = {}
	for _, t in ipairs(fishingTools(player)) do
		if t:GetAttribute("FishingTool") == "Fish" then t:Destroy() end
	end
	save(player)
end

------------------------------------------------------------------------------------------
-- casting + reeling
------------------------------------------------------------------------------------------
local casts = {} -- [player] = { id, biteAt, fish, kg, pos }

castRemote.OnServerInvoke = function(player, target, power)
	if player:GetAttribute("DataLoaded") ~= true then return { ok = false, reason = "loading" } end
	local root, character = rootOf(player)
	if not root or not FishingFrenzyConfig.isInside(root.Position) then
		return { ok = false, reason = "island" }
	end

	local rodTool = character:FindFirstChildOfClass("Tool")
	if not rodTool or rodTool:GetAttribute("FishingTool") ~= "Rod" then
		return { ok = false, reason = "rod" }
	end

	if not bridgeUnder(root.Position) then
		return { ok = false, reason = "bridge" }
	end

	if typeof(target) ~= "Vector3" or (target - root.Position).Magnitude > 40 or not inPond(target) then
		return { ok = false, reason = "water" }
	end

	local inv = inventories[player]
	if not inv or #inv >= FishingConfig.backpackSize(player) then
		return { ok = false, reason = "full" }
	end

	-- cast power bar: x1.0 (weak) .. x1.5 (perfect) on this cast's luck and fish weight
	power = math.clamp(tonumber(power) or 0, 0, 1)
	local castMult = FishingConfig.castMultiplier(power)
	local fish, kg = FishingConfig.rollFish(rng, FishingConfig.luck(player) * castMult)
	kg = math.floor(kg * castMult * 100 + 0.5) / 100
	local wait = rng:NextNumber(FishingConfig.BiteTime[1], FishingConfig.BiteTime[2]) / FishingConfig.speed(player)
	wait = math.max(wait, FishingConfig.MinBiteTime)

	local id = HttpService:GenerateGUID(false)
	casts[player] = { id = id, biteAt = os.clock() + wait, fish = fish, kg = kg, pos = target }

	return { ok = true, id = id, biteIn = wait, rarity = fish.rarity }
end

-- reeling is a mash minigame:
--   "hook"   clicked while the fish bites -> starts the fight (returns how hard the fish pulls)
--   "land"   won the fight -> the fish is yours
--   "escape" lost the fight / gave up
reelRemote.OnServerInvoke = function(player, id, stage)
	local cast = casts[player]
	if not cast or cast.id ~= id then
		return { ok = false, reason = "none" }
	end

	local now = os.clock()
	if stage == "hook" then
		if cast.hooked then
			return { ok = false, reason = "none" }
		end
		if now < cast.biteAt - 0.35 then
			casts[player] = nil
			return { ok = false, reason = "early" }
		end
		if now > cast.biteAt + FishingConfig.ReelWindow + 0.75 then
			casts[player] = nil
			return { ok = false, reason = "late" }
		end
		cast.hooked = now
		return { ok = true, stage = "hooked", rarity = cast.fish.rarity, fight = FishingConfig.fightFor(player, cast.fish) }
	elseif stage == "escape" then
		casts[player] = nil
		return { ok = false, reason = "escaped" }
	end

	-- "land" (older clients without a stage land straight away like before)
	if stage == "land" then
		if not cast.hooked then
			return { ok = false, reason = "none" }
		end
		local fought = now - cast.hooked
		local fight = FishingConfig.fightFor(player, cast.fish)
		-- can't win faster than a very fast masher could, and not after the fish is long gone
		if fought < fight.minTime * 0.8 or fought > 40 then
			casts[player] = nil
			return { ok = false, reason = "escaped" }
		end
	else
		if now < cast.biteAt - 0.35 then
			casts[player] = nil
			return { ok = false, reason = "early" }
		end
		if now > cast.biteAt + FishingConfig.ReelWindow + 0.75 then
			casts[player] = nil
			return { ok = false, reason = "late" }
		end
	end
	casts[player] = nil

	local inv = inventories[player]
	if not inv or #inv >= FishingConfig.backpackSize(player) then
		return { ok = false, reason = "full" }
	end

	uidCounter += 1
	local entry = { f = cast.fish.id, w = cast.kg, u = uidCounter }
	table.insert(inv, entry)
	save(player)
	add(player, "FishCaught", 1)
	local foundAttr = "FishFound_" .. cast.fish.id
	local isNew = player:GetAttribute(foundAttr) ~= true
	if isNew then player:SetAttribute(foundAttr, true) end

	local backpack = player:FindFirstChild("Backpack")
	if backpack and onIsland(player) then
		buildFishTool(entry).Parent = backpack
	end

	return {
		ok = true,
		fish = cast.fish.id,
		name = cast.fish.name,
		rarity = cast.fish.rarity,
		kg = cast.kg,
		value = sellValue(player, entry),
		carried = #inv,
		capacity = FishingConfig.backpackSize(player),
		isNew = isNew,
	}
end

------------------------------------------------------------------------------------------
-- selling (the Sell NPC)
------------------------------------------------------------------------------------------
local function heldFish(player)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("FishingTool") == "Fish" then
		return tool
	end
	return nil
end

local function sellAll(player, multiplier)
	local total, count = 0, 0
	for _, e in ipairs(inventories[player] or {}) do
		total += sellValue(player, e)
		count += 1
	end
	if count == 0 then
		return 0, 0
	end
	total = round(total * (multiplier or 1))
	clearFish(player)
	add(player, "FishMeal", total)
	return total, count
end

sellRemote.OnServerInvoke = function(player, mode)
	if player:GetAttribute("DataLoaded") ~= true or not inventories[player] then
		return { ok = false }
	end

	if mode == "quote" then
		local total = 0
		for _, e in ipairs(inventories[player]) do
			total += sellValue(player, e)
		end
		local held = heldFish(player)
		local heldValue = 0
		if held then
			for _, e in ipairs(inventories[player]) do
				if e.u == held:GetAttribute("Uid") then heldValue = sellValue(player, e) end
			end
		end
		return { ok = true, all = total, count = #inventories[player], held = heldValue, heldName = held and held.Name or nil }
	end

	if not nearStand(player, "SellStand", 30) then
		return { ok = false, reason = "far" }
	end

	if mode == "hand" then
		local held = heldFish(player)
		if not held then
			return { ok = false, reason = "nothing" }
		end
		local entry = removeFish(player, held:GetAttribute("Uid"))
		if not entry then
			return { ok = false, reason = "nothing" }
		end
		local value = sellValue(player, entry)
		save(player)
		add(player, "FishMeal", value)
		return { ok = true, amount = value, count = 1 }
	elseif mode == "all" then
		local total, count = sellAll(player, 1)
		if count == 0 then
			return { ok = false, reason = "nothing" }
		end
		return { ok = true, amount = total, count = count }
	end

	return { ok = false }
end

-- Robux "Sell all 2x"
if FishingConfig.SellDoubleProductId ~= 0 then
	local ProductHandlers = require(script.Parent:WaitForChild("ProductHandlers"))
	ProductHandlers[FishingConfig.SellDoubleProductId] = function(player)
		local total, count = sellAll(player, 2)
		eventRemote:FireClient(player, "sold", total, count, true)
		return true -- paid either way (an empty bucket still gets the purchase)
	end
end

------------------------------------------------------------------------------------------
-- Auto Sell gamepass: while it's switched on, everything in your inventory sells itself
-- (same price as the Sell NPC). AutoSellPass = owns it, AutoSell = the switch (saved).
------------------------------------------------------------------------------------------
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local autoSellRemote = remotes:WaitForChild("ToggleAutoSell")

local function checkAutoSellPass(player)
	local id = FishingConfig.AutoSellPassId
	local owns = false
	if id and id ~= 0 then
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end)
		owns = ok and result == true
	elseif RunService:IsStudio() then
		owns = true -- no pass made yet: free in Studio so it can be tested
	end
	player:SetAttribute("AutoSellPass", owns)
end

Players.PlayerAdded:Connect(checkAutoSellPass)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(checkAutoSellPass, p) end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == FishingConfig.AutoSellPassId and passId ~= 0 then
		player:SetAttribute("AutoSellPass", true)
		player:SetAttribute("AutoSell", true) -- switch it on straight away
	end
end)

autoSellRemote.OnServerInvoke = function(player, on)
	if player:GetAttribute("AutoSellPass") ~= true then
		return { ok = false, reason = "pass" }
	end
	if type(on) ~= "boolean" then on = player:GetAttribute("AutoSell") ~= true end
	player:SetAttribute("AutoSell", on)
	return { ok = true, on = on }
end

task.spawn(function()
	while true do
		task.wait(FishingConfig.AutoSellInterval or 1.5)
		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("AutoSellPass") == true and player:GetAttribute("AutoSell") == true
				and player:GetAttribute("DataLoaded") == true and inventories[player] and #inventories[player] > 0 then
				local total, count = sellAll(player, 1)
				if count > 0 then
					eventRemote:FireClient(player, "autosold", total, count)
				end
			end
		end
	end
end)

------------------------------------------------------------------------------------------
-- rods
------------------------------------------------------------------------------------------
buyRodRemote.OnServerInvoke = function(player, id)
	local index = FishingConfig.RodIndex[id]
	local rod = index and FishingConfig.Rods[index]
	if not rod or player:GetAttribute("DataLoaded") ~= true then
		return { ok = false, reason = "unknown" }
	end
	if FishingConfig.ownsRod(player, id) then
		return { ok = false, reason = "owned" }
	end
	if not nearStand(player, "RodStand", 30) then
		return { ok = false, reason = "far" }
	end
	local fishMeal = player:GetAttribute("FishMeal") or 0
	if fishMeal < rod.price then
		return { ok = false, reason = "money" }
	end
	player:SetAttribute("FishMeal", fishMeal - rod.price)
	player:SetAttribute(FishingConfig.rodAttribute(id), true)
	player:SetAttribute("EquippedRod", index)
	syncTools(player)
	return { ok = true }
end

equipRodRemote.OnServerInvoke = function(player, id)
	local index = FishingConfig.RodIndex[id]
	if not index or not FishingConfig.ownsRod(player, id) then
		return { ok = false }
	end
	player:SetAttribute("EquippedRod", index)
	syncTools(player)
	return { ok = true }
end

------------------------------------------------------------------------------------------
-- Shell Upgrades
------------------------------------------------------------------------------------------
shellUpRemote.OnServerInvoke = function(player, id)
	local u = FishingConfig.ShellUpgradeById[id]
	if not u or player:GetAttribute("DataLoaded") ~= true then
		return { ok = false }
	end
	local level = FishingConfig.shellUpLevel(player, id)
	if level >= u.max then
		return { ok = false, reason = "max" }
	end
	local cost = FishingConfig.shellUpCost(id, level)
	local shells = player:GetAttribute("Shells") or 0
	if shells < cost then
		return { ok = false, reason = "money" }
	end
	player:SetAttribute("Shells", shells - cost)
	player:SetAttribute(FishingConfig.shellUpAttribute(id), level + 1)
	return { ok = true, level = level + 1 }
end

------------------------------------------------------------------------------------------
-- Fish Tier + Prestige
------------------------------------------------------------------------------------------
local function resetTierStuff(player)
	player:SetAttribute("FishMeal", 0)
	for _, rod in ipairs(FishingConfig.Rods) do
		if rod.id ~= "Wooden" then
			player:SetAttribute(FishingConfig.rodAttribute(rod.id), false)
		end
	end
	player:SetAttribute("EquippedRod", 1)
	for n in ipairs(FishingConfig.AutoFishers) do
		player:SetAttribute(FishingConfig.autoFisherAttribute(n), false)
	end
	clearFish(player)
	casts[player] = nil
end

tierRemote.OnServerInvoke = function(player)
	if player:GetAttribute("DataLoaded") ~= true then return { ok = false } end
	local tier = FishingConfig.tier(player)
	local nextTier = FishingConfig.Tiers[tier + 1]
	if not nextTier then
		return { ok = false, reason = "max" }
	end
	if (player:GetAttribute("FishMeal") or 0) < nextTier.cost then
		return { ok = false, reason = "money" }
	end
	resetTierStuff(player)
	player:SetAttribute("FishTier", tier + 1)
	syncTools(player)
	eventRemote:FireClient(player, "tier", tier + 1)
	return { ok = true, tier = tier + 1 }
end

prestigeRemote.OnServerInvoke = function(player)
	if player:GetAttribute("DataLoaded") ~= true then return { ok = false } end
	local prestige = FishingConfig.prestige(player)
	if prestige >= FishingConfig.MaxPrestige then
		return { ok = false, reason = "max" }
	end
	if FishingConfig.tier(player) < FishingConfig.MaxTier then
		return { ok = false, reason = "tier" }
	end
	resetTierStuff(player)
	player:SetAttribute("FishTier", 0)
	player:SetAttribute("Shells", 0)
	player:SetAttribute("Crabs", 0)
	for _, u in ipairs(FishingConfig.ShellUpgrades) do
		player:SetAttribute(FishingConfig.shellUpAttribute(u.id), 0)
	end
	player:SetAttribute("FishPrestige", prestige + 1)
	syncTools(player)
	eventRemote:FireClient(player, "prestige", prestige + 1)
	return { ok = true, prestige = prestige + 1 }
end

------------------------------------------------------------------------------------------
-- Conversion: Fish Meal -> Crabs (Tier 3+)
------------------------------------------------------------------------------------------
convertRemote.OnServerInvoke = function(player)
	if player:GetAttribute("DataLoaded") ~= true then return { ok = false } end
	if FishingConfig.tier(player) < FishingConfig.ConversionTier then
		return { ok = false, reason = "locked" }
	end
	local fishMeal = player:GetAttribute("FishMeal") or 0
	local batches = math.floor(fishMeal / FishingConfig.FishMealPerCrab)
	if batches < 1 then
		return { ok = false, reason = "money" }
	end
	local crabs = math.floor(batches * FishingConfig.crabMultiplier(player))
	player:SetAttribute("FishMeal", fishMeal - batches * FishingConfig.FishMealPerCrab)
	add(player, "Crabs", crabs)
	return { ok = true, crabs = crabs }
end

------------------------------------------------------------------------------------------
-- auto-fishers (one per bridge)
------------------------------------------------------------------------------------------
autoFisherRemote.OnServerInvoke = function(player, n)
	n = tonumber(n)
	local def = n and FishingConfig.AutoFishers[n]
	if not def or player:GetAttribute("DataLoaded") ~= true then
		return { ok = false }
	end
	local attr = FishingConfig.autoFisherAttribute(n)
	if player:GetAttribute(attr) == true then
		return { ok = false, reason = "owned" }
	end
	local root = rootOf(player)
	local bridge = bridges[n]
	if not root or not bridge or (root.Position - bridge:GetAttribute("Start")).Magnitude > 25 then
		return { ok = false, reason = "far" }
	end
	local fishMeal = player:GetAttribute("FishMeal") or 0
	if fishMeal < def.price then
		return { ok = false, reason = "money" }
	end
	player:SetAttribute("FishMeal", fishMeal - def.price)
	player:SetAttribute(attr, true)
	return { ok = true }
end

local autoNext = {} -- [player][n] = os.clock() of its next catch
local autoFullWarned = {} -- [player] = os.clock() we last told them their storage is full

-- an auto-fisher's catch goes into your inventory (sell it at the Sell NPC like any other fish)
local function giveAutoFish(player, n)
	local inv = inventories[player]
	if not inv then return end
	if #inv >= FishingConfig.backpackSize(player) then
		local now = os.clock()
		if not autoFullWarned[player] or now - autoFullWarned[player] > 20 then
			autoFullWarned[player] = now
			eventRemote:FireClient(player, "autofull", n)
		end
		return
	end
	local fish, kg = FishingConfig.rollFish(rng, FishingConfig.luck(player) * FishingConfig.AutoFisherLuck)
	kg = math.floor(kg * 100 + 0.5) / 100
	uidCounter += 1
	local entry = { f = fish.id, w = kg, u = uidCounter }
	table.insert(inv, entry)
	save(player)
	add(player, "FishCaught", 1)
	local foundAttr = "FishFound_" .. fish.id
	if player:GetAttribute(foundAttr) ~= true then player:SetAttribute(foundAttr, true) end
	local backpack = player:FindFirstChild("Backpack")
	if backpack and onIsland(player) then
		buildFishTool(entry).Parent = backpack
	end
	eventRemote:FireClient(player, "autofish", n, fish.id, kg, #inv, FishingConfig.backpackSize(player))
end

task.spawn(function()
	while true do
		task.wait(0.5)
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("DataLoaded") == true then
				autoNext[player] = autoNext[player] or {}
				for n in ipairs(FishingConfig.AutoFishers) do
					if player:GetAttribute(FishingConfig.autoFisherAttribute(n)) == true then
						local at = autoNext[player][n]
						if not at then
							autoNext[player][n] = now + FishingConfig.AutoFisherInterval * (0.5 + n * 0.1)
						elseif now >= at then
							-- Crew Training (upgrade tree) makes them fish faster
							autoNext[player][n] = now + FishingConfig.AutoFisherInterval / math.max(FishingConfig.autoFisherMultiplier(player), 0.1)
							giveAutoFish(player, n)
						end
					else
						autoNext[player][n] = nil
					end
				end
			end
		end
	end
end)

------------------------------------------------------------------------------------------
-- shells on the sand (shared: first one to walk over a shell gets it)
------------------------------------------------------------------------------------------
local shellFolder = island:FindFirstChild("SpawnedShells") or Instance.new("Folder")
shellFolder.Name = "SpawnedShells"
shellFolder.Parent = island

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { map }

local noGo = {} -- things shells shouldn't spawn inside
for _, name in ipairs({ "FishingStands", "FishingFrenzy", "UpgradeTree", "Achievemnets", "FishingTierBoard", "FishingPrestigeBoard", "FishingConversionBoard" }) do
	local m = island:FindFirstChild(name)
	if m and m:IsA("Model") then
		table.insert(noGo, m)
	elseif m then -- a folder of models
		for _, c in ipairs(m:GetChildren()) do
			if c:IsA("Model") then table.insert(noGo, c) end
		end
	end
end

local function shellSpot()
	local center = water.Position
	for _ = 1, 12 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(46, 150)
		local p = Vector3.new(center.X + math.cos(angle) * dist, 60, center.Z + math.sin(angle) * dist)
		local hit = workspace:Raycast(p, Vector3.new(0, -100, 0), groundParams)
		if hit and hit.Normal.Y > 0.8 and hit.Position.Y > -5 and hit.Position.Y < 3
			and not hit.Instance:IsDescendantOf(water) and hit.Instance.Name ~= "Leaves" then
			local blocked = false
			for _, m in ipairs(noGo) do
				local cf, size = m:GetBoundingBox()
				local local_ = cf:PointToObjectSpace(hit.Position)
				if math.abs(local_.X) < size.X / 2 + 3 and math.abs(local_.Z) < size.Z / 2 + 3 then
					blocked = true
					break
				end
			end
			if not blocked then
				return hit.Position
			end
		end
	end
	return nil
end

local function pickSize()
	local total = 0
	for _, s in ipairs(FishingConfig.ShellSizes) do total += s.chance end
	local r = rng:NextNumber() * total
	for _, s in ipairs(FishingConfig.ShellSizes) do
		r -= s.chance
		if r <= 0 then return s end
	end
	return FishingConfig.ShellSizes[1]
end

local function spawnShell()
	local pos = shellSpot()
	if not pos then return end
	local size = pickSize()
	local template = assets.Shells:FindFirstChild(size.id)
	if not template then return end
	local shell = template:Clone()
	shell:PivotTo(CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	shell:SetAttribute("Size", size.id)
	shell:SetAttribute("Amount", size.amount)
	shell.Parent = shellFolder
end

task.spawn(function()
	while true do
		if #shellFolder:GetChildren() < FishingConfig.MaxShells then
			spawnShell()
		end
		task.wait(FishingConfig.ShellSpawnEvery)
	end
end)

-- pickups
task.spawn(function()
	while true do
		task.wait(0.15)
		local shells = shellFolder:GetChildren()
		if #shells > 0 then
			for _, player in ipairs(Players:GetPlayers()) do
				local root = rootOf(player)
				if root and player:GetAttribute("DataLoaded") == true and FishingFrenzyConfig.isInside(root.Position) then
					local range = FishingConfig.pickupRange(player)
					for _, shell in ipairs(shells) do
						if shell.Parent and (shell:GetPivot().Position - root.Position).Magnitude <= range then
							local amount = math.max(1, round((shell:GetAttribute("Amount") or 1) * FishingConfig.shellMultiplier(player)))
							local pos = shell:GetPivot().Position
							local sizeName = shell:GetAttribute("Size")
							shell:Destroy()
							add(player, "Shells", amount)
							eventRemote:FireClient(player, "shell", pos, amount, sizeName)
						end
					end
				end
			end
		end
	end
end)

------------------------------------------------------------------------------------------
-- players
------------------------------------------------------------------------------------------
local function setup(player)
	if player:GetAttribute("DataLoaded") ~= true then
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
	if not player.Parent then return end
	load(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		syncTools(player)
	end)
	player:GetAttributeChangedSignal("EquippedRod"):Connect(function()
		syncTools(player)
	end)
	syncTools(player)
end

Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(setup, p)
end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	inventories[player] = nil
	casts[player] = nil
	autoNext[player] = nil
	autoFullWarned[player] = nil
end)

-- give / take the fishing tools as people walk on and off the island
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local cast = casts[player]
			if cast and not onIsland(player) then
				casts[player] = nil
			end
			syncTools(player)
		end
	end
end)
