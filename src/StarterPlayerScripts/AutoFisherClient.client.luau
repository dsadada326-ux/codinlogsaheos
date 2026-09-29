-- Auto-fishers: a buy button by every bridge (step on it, pay Fish Meal) and, once owned,
-- an NPC on the end of that bridge who fishes for you. The catches are rolled on the server
-- (FishingService) and arrive here as FishingEvent("autofish", n, fishId, gain).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local FishingConfig = require(ReplicatedStorage:WaitForChild("FishingConfig"))
local FishingVisuals = require(ReplicatedStorage:WaitForChild("FishingVisuals"))
local abbreviate = require(ReplicatedStorage:WaitForChild("NumberFormat")).abbreviate
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyRemote = remotes:WaitForChild("BuyAutoFisher")
local eventRemote = remotes:WaitForChild("FishingEvent")
local assets = ReplicatedStorage:WaitForChild("FishingAssets")
local buttonTemplate = ReplicatedStorage:WaitForChild("FarmAssets"):WaitForChild("WheatButton")
local rigTemplate = assets:WaitForChild("NPCRig")

local island = workspace:WaitForChild("Islands"):WaitForChild(FishingConfig.IslandName)
local map = island:WaitForChild("Map")

local folder = Instance.new("Folder")
folder.Name = "AutoFishers"
folder.Parent = FishingVisuals.folder

local AFFORD = Color3.fromRGB(70, 220, 90)
local CANT = Color3.fromRGB(230, 60, 60)
local NPC_ARM_RAISE = 1.57 -- NPCs have no tool-hold animation, so raise the arm ourselves

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { map }

local function rootPart()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

------------------------------------------------------------------------------------------
-- bridge data
------------------------------------------------------------------------------------------
local bridges = {}
for n in ipairs(FishingConfig.AutoFishers) do
	local b = island:WaitForChild("Bridge" .. n, 30)
	if b then
		bridges[n] = {
			model = b,
			start = b:GetAttribute("Start"),
			tip = b:GetAttribute("Tip"),
			facing = b:GetAttribute("Facing"),
		}
	end
end

------------------------------------------------------------------------------------------
-- buy buttons
------------------------------------------------------------------------------------------
local buttons = {}

local function makeButton(n, info)
	local def = FishingConfig.AutoFishers[n]
	-- right on the flat end of the bridge where you fish, off to one side of the walkway
	local side = info.facing:Cross(Vector3.yAxis)
	local spot = info.tip - info.facing * 5.2 + side * 2.2
	local deckParams = RaycastParams.new()
	deckParams.FilterType = Enum.RaycastFilterType.Include
	deckParams.FilterDescendantsInstances = { info.model }
	local hit = workspace:Raycast(spot + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), deckParams)
		or workspace:Raycast(spot + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), groundParams)
	local y = hit and hit.Position.Y or info.start.Y

	local model = buttonTemplate:Clone()
	model.Name = "AutoFisherButton" .. n
	model:ScaleTo(0.75) -- fits between the bridge rails
	model:PivotTo(CFrame.new(spot.X, y, spot.Z) * CFrame.fromOrientation(0, math.atan2(-info.facing.X, -info.facing.Z), 0))
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
		end
	end
	local pad = model:FindFirstChild("Button")
	local tag = pad and pad:FindFirstChild("PriceTag")
	if tag then
		local name = tag:FindFirstChild("NameLabel", true)
		local price = tag:FindFirstChild("PriceLabel", true)
		local icon = tag:FindFirstChild("CurrencyImageIcon", true)
		if name then name.Text = "Auto-Fisher " .. n end
		if price then price.Text = abbreviate(def.price) end
		if icon then icon.Image = FishingVisuals.Icons.FishMeal end
	end
	model.Parent = folder
	buttons[n] = { model = model, pad = pad, position = Vector3.new(spot.X, y, spot.Z), padSize = pad and pad.Size }
end

-- bought: the button squashes down, pops in a burst of sparkles and is gone
local function poof(b)
	local model = b.model
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(parts, d) end
		if d:IsA("BillboardGui") then d.Enabled = false end
	end
	local center = b.position + Vector3.new(0, 0.5, 0)
	local burst = Instance.new("Part")
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.Transparency = 1
	burst.Size = Vector3.one
	burst.Position = center
	burst.Parent = FishingVisuals.folder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 140), Color3.fromRGB(120, 255, 160))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	emitter.Speed = NumberRange.new(10, 18)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.LightEmission = 1
	emitter.Enabled = false
	emitter.Parent = burst
	emitter:Emit(45)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Volume = 0.8
	sound.Parent = burst
	sound:Play()
	FishingVisuals.splash(center, 1.4)
	FishingVisuals.popup(center + Vector3.new(0, 3, 0), "PURCHASED!", Color3.fromRGB(120, 255, 150), nil, true)
	for _, p in ipairs(parts) do
		TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Size = p.Size * Vector3.new(0.05, 0.05, 0.05),
			Transparency = 1,
		}):Play()
	end
	task.delay(0.4, function()
		model.Parent = nil
	end)
	Debris:AddItem(burst, 2)
end

local loaded = false
local function paintButtons()
	local fishMeal = player:GetAttribute("FishMeal") or 0
	for n, b in pairs(buttons) do
		local owned = player:GetAttribute(FishingConfig.autoFisherAttribute(n)) == true
		if owned and not b.owned then
			b.owned = true
			if loaded and b.model.Parent then
				poof(b)
			else
				b.model.Parent = nil
			end
		elseif not owned and b.owned then
			-- reset (tier up / prestige): bring a fresh button back
			b.owned = false
			b.model:Destroy()
			makeButton(n, bridges[n])
			b = buttons[n]
		elseif not owned then
			b.model.Parent = folder
		end
		if b.pad and not b.owned then
			b.pad.Color = fishMeal >= FishingConfig.AutoFishers[n].price and AFFORD or CANT
		end
	end
end

for n, info in pairs(bridges) do
	makeButton(n, info)
end

-- step on a button to buy
local standingOn = nil
local busy = false
task.spawn(function()
	while true do
		task.wait(0.12)
		local root = rootPart()
		local current = nil
		if root then
			for n, b in pairs(buttons) do
				if b.model.Parent and not b.owned then
					local d = root.Position - b.position
					if Vector3.new(d.X, 0, d.Z).Magnitude < 1.6 and d.Y > -1 and d.Y < 6 then
						current = n
						break
					end
				end
			end
		end
		if current and current ~= standingOn and not busy then
			busy = true
			local b = buttons[current]
			if b.pad then
				local original = b.pad.Size
				TweenService:Create(b.pad, TweenInfo.new(0.1), { Size = original * Vector3.new(1, 0.5, 1) }):Play()
				task.delay(0.15, function()
					TweenService:Create(b.pad, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = original }):Play()
				end)
			end
			local ok, result = pcall(function() return buyRemote:InvokeServer(current) end)
			if ok and result and not result.ok and result.reason == "money" then
				MessageToPlayer.show("NoFishMeal")
			end
			busy = false
		end
		standingOn = current
	end
end)

------------------------------------------------------------------------------------------
-- NPC fishers
------------------------------------------------------------------------------------------
local npcs = {}

local function attachRod(rig, rod)
	local hand = rig:FindFirstChild("RightHand")
	local gripAttachment = hand and hand:FindFirstChild("RightGripAttachment")
	local source = assets.Rods:FindFirstChild(rod.model)
	if not hand or not gripAttachment or not source then return nil end

	local copy = source:Clone()
	local main
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") and (not main or d.Size.Magnitude > main.Size.Magnitude) then
			main = d
		end
	end
	if not main then copy:Destroy() return nil end
	local gripWorld = copy:FindFirstChild("Handle") and copy.Handle:IsA("Attachment") and copy.Handle.WorldPosition
	local gripLocal = gripWorld and main.CFrame:PointToObjectSpace(gripWorld) or Vector3.new(0, -main.Size.Y * 0.35, 0)
	local grip = CFrame.new(gripLocal) * CFrame.Angles(math.rad(60), 0, 0)

	-- move the whole rod so its grip sits in the hand, then weld it on
	local target = hand.CFrame * gripAttachment.CFrame * grip:Inverse()
	local delta = target * main.CFrame:Inverse()
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then
			local w = Instance.new("WeldConstraint")
			w.Part0 = hand
			w.Part1 = d
			w.Parent = d
		end
	end
	local tip = Instance.new("Attachment")
	FishingVisuals.leftGrip(main, gripLocal)
	tip.Name = "Tip"
	tip.Position = Vector3.new(0, main.Size.Y / 2 - 0.1, 0)
	tip.Parent = main
	copy.Name = "Rod"
	copy.Parent = rig
	return tip
end

local function nameTag(rig, n)
	local head = rig:FindFirstChild("Head")
	if not head then return end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 34)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 70
	gui.Adornee = head
	gui.Parent = rig
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = "🎣 Auto-Fisher " .. n
	l.TextColor3 = Color3.fromRGB(150, 230, 255)
	l.Parent = gui
	local s = Instance.new("UIStroke")
	s.Thickness = 2.5
	s.Parent = l
end

local function spawnNpc(n)
	if npcs[n] then return end
	local info = bridges[n]
	if not info then return end

	local rig = rigTemplate:Clone()
	rig.Name = "AutoFisher" .. n
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.RequiresNeck = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	for _, p in ipairs(rig:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Anchored = p == root
		end
	end

	-- stand at the end of the bridge, facing the water
	-- off to one side so you can still fish from the same bridge
	local standAt = info.tip - info.facing * 1.8 + info.facing:Cross(Vector3.yAxis) * 2.1
	local cf, size = rig:GetBoundingBox()
	local pivot = rig:GetPivot()
	local feetToPivot = pivot.Position.Y - (cf.Position.Y - size.Y / 2)
	rig:PivotTo(CFrame.lookAt(Vector3.new(standAt.X, info.tip.Y + feetToPivot, standAt.Z), Vector3.new(standAt.X, info.tip.Y + feetToPivot, standAt.Z) + info.facing))
	rig.Parent = folder

	-- they fish with whatever rod YOU have equipped (and swap when you change it)
	local rod = FishingConfig.equippedRod(player)
	local tip = attachRod(rig, rod)
	nameTag(rig, n)

	local npc = { rig = rig, tip = tip, alive = true, n = n, rodId = rod.id }
	npcs[n] = npc

	function npc.setRod()
		if not npc.alive then return end
		local want = FishingConfig.equippedRod(player)
		if want.id == npc.rodId then return false end
		if npc.busy or npc.casting or npc.recasting then
			npc.pendingRod = true -- after this catch / cast
			return false
		end
		local old = rig:FindFirstChild("Rod")
		if old then old:Destroy() end
		npc.tip = attachRod(rig, want)
		npc.rodId = want.id
		if npc.bobber then
			npc.bobber:destroy()
			npc.bobber = nil
		end
		local head = rig:FindFirstChild("Head")
		if head then FishingVisuals.splash(head.Position - Vector3.new(0, 1, 0), 0.6) end
		npc.recasting = true
		task.spawn(function()
			task.wait(0.3)
			npc.recasting = false
			if npc.alive and not npc.bobber and not npc.busy then npc.recast() end
		end)
		return true
	end

	-- little "poof" when he shows up
	FishingVisuals.splash(standAt + info.facing * 3, 1.2)

	task.spawn(function()
		task.wait(0.2)
		npc.arm = FishingVisuals.arm(rig, nil, function()
			local t = npc.tip
			return t and t.Parent and t.Parent:FindFirstChild("LeftGrip")
		end)
		npc.recast()
	end)

	function npc.recast()
		if not npc.alive or not npc.arm then return end
		if npc.bobber then npc.bobber:destroy() npc.bobber = nil end
		npc.casting = true
		npc.arm:cast(0.45 + math.random() * 0.4)
		if not npc.alive then return end
		local bobber = FishingVisuals.bobber()
		npc.bobber = bobber
		if npc.tip then bobber:attachLine(npc.tip) end
		local from = npc.tip and npc.tip.WorldPosition or (standAt + Vector3.new(0, 3, 0))
		local to = Vector3.new(standAt.X, FishingVisuals.waterY, standAt.Z) + info.facing * (9 + math.random() * 3)
			+ info.facing:Cross(Vector3.yAxis) * (math.random() * 4 - 2)
		bobber:fly(from, to, 0.45)
		if not npc.alive then return end
		FishingVisuals.splash(to, 0.8)
		bobber:float(to)
		npc.arm:waiting()
		npc.casting = false
		if npc.pendingRod and not npc.busy then
			npc.pendingRod = false
			npc.setRod()
		end
	end

	function npc.catch(fishId, kg)
		if not npc.alive or not npc.bobber or npc.busy then return end
		npc.busy = true
		local bobber = npc.bobber
		npc.arm:bite()
		bobber:dip()
		task.wait(0.6)
		if not npc.alive then return end
		npc.arm:reel()
		local bobberPos = bobber.model:GetPivot().Position
		FishingVisuals.splash(bobberPos, 1)
		bobber:reelTo(function()
			return npc.tip and npc.tip.WorldPosition or standAt
		end, 0.45)
		if not npc.alive then return end
		bobber:destroy()
		npc.bobber = nil

		-- the fish jumps out and into his hands
		local source = assets.Fish:FindFirstChild(fishId)
		local head = rig:FindFirstChild("Head")
		if source and head then
			local model = source:Clone()
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") then p.Anchored = true p.CanCollide = false p.CanQuery = false end
			end
			model.Parent = FishingVisuals.folder
			local start = os.clock()
			while npc.alive do
				local k = math.clamp((os.clock() - start) / 0.6, 0, 1)
				local p = bobberPos:Lerp(head.Position + Vector3.new(0, 1.5, 0), k) + Vector3.new(0, math.sin(k * math.pi) * 5, 0)
				model:PivotTo(CFrame.new(p) * CFrame.Angles(0, k * 8, math.sin(k * 18) * 0.4))
				if k >= 1 then break end
				RunService.RenderStepped:Wait()
			end
			task.delay(0.3, function() model:Destroy() end)
		end

		local fish = FishingConfig.FishById[fishId]
		local color = fish and FishingVisuals.rarityColor and FishingVisuals.rarityColor(fish.rarity) or Color3.fromRGB(255, 225, 120)
		if head then
			-- it went into your inventory
			if fish then
				local big = FishingConfig.RarityIndex[fish.rarity] and FishingConfig.RarityIndex[fish.rarity] >= 4
				FishingVisuals.popup(head.Position + Vector3.new(0, 3, 0), "+1 " .. fish.name .. (kg and (" (" .. FishingConfig.formatKg(kg) .. ")") or ""), color, nil, big)
			end
		end
		npc.arm:idle()
		task.wait(0.8)
		npc.busy = false
		if npc.pendingRod then
			npc.pendingRod = false
			if npc.setRod() then return end -- it recasts with the new rod
		end
		if not npc.bobber and not npc.recasting then npc.recast() end
	end

	function npc.destroy()
		npc.alive = false
		if npc.arm then npc.arm:destroy() end
		if npc.bobber then npc.bobber:destroy() end
		rig:Destroy()
	end
end

local function despawnNpc(n)
	local npc = npcs[n]
	if npc then
		npcs[n] = nil
		npc.destroy()
	end
end

local function sync()
	for n in pairs(bridges) do
		if player:GetAttribute(FishingConfig.autoFisherAttribute(n)) == true then
			spawnNpc(n)
		else
			despawnNpc(n)
		end
	end
	paintButtons()
end

eventRemote.OnClientEvent:Connect(function(kind, n, fishId, gain)
	if kind == "autofull" then
		MessageToPlayer.show("BucketFull")
		return
	end
	if kind ~= "autofish" then return end
	local npc = npcs[n]
	if not npc then return end
	-- only bother animating when you're around
	local root = rootPart()
	if root and (root.Position - npc.rig:GetPivot().Position).Magnitude < 250 then
		task.spawn(npc.catch, fishId, gain)
	end
end)

local function syncRods()
	for _, npc in pairs(npcs) do
		if npc.setRod then npc.setRod() end
	end
end

-- keep checking: rods can change from the shop, a tier reset, etc.
task.spawn(function()
	while true do
		task.wait(2)
		syncRods()
	end
end)

player.AttributeChanged:Connect(function(attr)
	if attr == "EquippedRod" then
		task.defer(syncRods)
	elseif attr == "FishMeal" then
		paintButtons()
	elseif attr:sub(1, 11) == "AutoFisher_" then
		sync()
	end
end)

if player:GetAttribute("DataLoaded") ~= true then
	player:GetAttributeChangedSignal("DataLoaded"):Wait()
end
sync()
loaded = true
