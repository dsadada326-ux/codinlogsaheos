local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))

local zonesFolder = workspace
	:WaitForChild("Islands")
	:WaitForChild("Island1")
	:WaitForChild("Zones")

-- how long the "being built" wave takes to sweep up a zone, and how long each
-- piece takes to fade in once its turn comes
local SWEEP_TIME = 1.1
local PART_FADE_TIME = 0.35
local RISE = 1.5 -- studs each piece rises from as it builds in (visual only, local)

local Debris = game:GetService("Debris")
local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))

local function settingOn(key)
	local value = player:GetAttribute(SettingsConfig.attributeOf(key))

	if value == nil then
		return SettingsConfig.Settings[key].Default
	end

	return value
end

-- the same rounded, outlined font as the currency list
local function uiFont()
	local ok, font = pcall(function()
		return player.PlayerGui.Currencies.MainCurrenciesFrame.CurrenciesFrame.Money.Value.FontFace
	end)

	return ok and font or Font.fromEnum(Enum.Font.FredokaOne)
end

local bannerGui = Instance.new("ScreenGui")
bannerGui.Name = "AreaUnlockBanner"
bannerGui.ResetOnSpawn = false
bannerGui.IgnoreGuiInset = true
bannerGui.DisplayOrder = 20
bannerGui.Parent = player:WaitForChild("PlayerGui")

local bannerQueue = {}
local bannerBusy = false

local function makeLabel(parent, text, size, position, color, strokeThickness)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextScaled = true
	label.FontFace = uiFont()
	label.TextColor3 = color
	label.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = strokeThickness
	stroke.Color = Color3.fromRGB(25, 20, 40)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label

	return label, stroke
end

local function playBanner(areaName)
	bannerBusy = true

	-- one small white line near the top of the screen: "Rebirths Unlocked!"
	local holder = Instance.new("CanvasGroup")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.13)
	holder.Size = UDim2.fromScale(0.34, 0.06)
	holder.GroupTransparency = 1
	holder.Parent = bannerGui

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 7
	ratio.Parent = holder

	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = holder

	makeLabel(holder, areaName .. " Unlocked!", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1), 2.5)

	-- pop in, hold, float up and fade
	TweenService:Create(holder, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	task.wait(2)

	TweenService:Create(holder, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		GroupTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.09),
	}):Play()

	task.wait(0.4)
	holder:Destroy()

	bannerBusy = false

	local nextArea = table.remove(bannerQueue, 1)

	if nextArea then
		task.spawn(playBanner, nextArea)
	end
end

local function announce(areaName)
	if bannerBusy then
		table.insert(bannerQueue, areaName)
	else
		task.spawn(playBanner, areaName)
	end
end

-- a burst of gold sparkles over the new area
local function sparkleBurst(position, radius)
	if not settingOn("VFX") then
		return
	end

	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(radius * 2, 1, radius * 2)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 255, 255))
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Speed = NumberRange.new(6, 14)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -8, 0)
	emitter.Rate = 0
	emitter.Parent = anchor

	emitter:Emit(90)

	task.delay(0.5, function()
		emitter:Emit(40)
	end)

	Debris:AddItem(anchor, 3)
end

local function niceName(zoneName)
	return (zoneName:gsub("(%l)(%u)", "%1 %2")) -- "StarterUpgrades" -> "Starter Upgrades"
end

-- pieces the new-player Cash reveal controls (UpgradeBoard.lua) are left to it
local function managedElsewhere(inst)
	local node = inst

	while node and node ~= workspace do
		if node:GetAttribute("ManagedByCashReveal") or node:GetAttribute("ManagedByScript") then
			return true
		end

		node = node.Parent
	end

	return false
end

local function findPath(path)
	local node = workspace

	for _, name in ipairs(path) do
		node = node:WaitForChild(name, 15)

		if not node then
			return nil
		end
	end

	return node
end

------------------------------------------------------------------------------------------
-- one entry per zone: every part / texture / gui / effect of the zone AND its boards
------------------------------------------------------------------------------------------
local entries = {}

local function newEntry(zoneDef)
	return {
		def = zoneDef,
		parts = {},     -- { inst, canCollide, canQuery, canTouch }
		textures = {},  -- { inst, transparency }  (Texture / Decal)
		guis = {},      -- { inst, enabled }       (SurfaceGui / BillboardGui)
		effects = {},   -- { inst, enabled }       (ParticleEmitter / Beam / Trail / lights)
		known = {},
		revealed = nil, -- nil until the first pass
	}
end

local function setPartHidden(record, hidden)
	local part = record.inst

	part.LocalTransparencyModifier = hidden and 1 or 0
	-- local only: the player walks through / clicks through a hidden piece
	part.CanCollide = (not hidden) and record.canCollide
	part.CanQuery = (not hidden) and record.canQuery
	part.CanTouch = (not hidden) and record.canTouch
end

local function setOtherHidden(entry, hidden)
	for _, t in ipairs(entry.textures) do
		t.inst.Transparency = hidden and 1 or t.transparency
	end

	for _, g in ipairs(entry.guis) do
		g.inst.Enabled = (not hidden) and g.enabled
	end

	for _, fx in ipairs(entry.effects) do
		fx.inst.Enabled = (not hidden) and fx.enabled
	end
end

-- adds one instance to an entry (and brings it straight into the zone's current state)
local function track(entry, inst)
	if entry.known[inst] or managedElsewhere(inst) then
		return
	end

	entry.known[inst] = true

	local hidden = entry.revealed == false

	if inst:IsA("BasePart") then
		local record = {
			inst = inst,
			canCollide = inst.CanCollide,
			canQuery = inst.CanQuery,
			canTouch = inst.CanTouch,
		}

		table.insert(entry.parts, record)

		if hidden then
			setPartHidden(record, true)
		end
	elseif inst:IsA("Texture") or inst:IsA("Decal") then
		table.insert(entry.textures, { inst = inst, transparency = inst.Transparency })

		if hidden then
			inst.Transparency = 1
		end
	elseif inst:IsA("SurfaceGui") or inst:IsA("BillboardGui") then
		table.insert(entry.guis, { inst = inst, enabled = inst.Enabled })

		if hidden then
			inst.Enabled = false
		end
	elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail")
		or inst:IsA("Light") or inst:IsA("Fire") or inst:IsA("Sparkles") or inst:IsA("Smoke") then
		table.insert(entry.effects, { inst = inst, enabled = inst.Enabled })

		if hidden then
			inst.Enabled = false
		end
	end
end

local function trackTree(entry, root)
	track(entry, root)

	for _, d in ipairs(root:GetDescendants()) do
		track(entry, d)
	end

	-- streaming can bring more in later
	root.DescendantAdded:Connect(function(inst)
		track(entry, inst)
	end)
end

-- Every area is registered straight away (hidden until its unlock is known), and each piece
-- is hidden the moment it streams in. (This used to wait up to 15s per area, one after another,
-- before hiding anything - so the whole map showed while the waits ran.)

-- calls fn(child) for the child of `parent` called `name` now and every time one (re)appears,
-- e.g. when streaming brings a model back in
local function watchChild(parent, name, fn)
	local current = parent:FindFirstChild(name)

	if current then
		task.spawn(fn, current)
	end

	parent.ChildAdded:Connect(function(child)
		if child.Name == name then
			fn(child)
		end
	end)
end

-- same, down a path of names from `root`
local function watchPath(root, path, fn, i)
	i = i or 1

	if i > #path then
		fn(root)
		return
	end

	watchChild(root, path[i], function(child)
		watchPath(child, path, fn, i + 1)
	end)
end

for _, zoneDef in ipairs(ZoneConfig.Zones) do
	local entry = newEntry(zoneDef)
	table.insert(entries, entry)

	if not zoneDef.noIsland then
		-- island = which island's Zones folder, model = the model's name (defaults: Island1, the area name)
		local path = zoneDef.island and { "Islands", zoneDef.island, "Zones" } or { "Islands", "Island1", "Zones" }
		table.insert(path, zoneDef.model or zoneDef.name)

		watchPath(workspace, path, function(model)
			trackTree(entry, model)
		end)
	end

	for _, boardPath in ipairs(zoneDef.boards or {}) do
		watchPath(workspace, boardPath, function(board)
			trackTree(entry, board)
		end)
	end
end

------------------------------------------------------------------------------------------
-- showing / hiding
------------------------------------------------------------------------------------------
local function hideInstant(entry)
	for _, record in ipairs(entry.parts) do
		setPartHidden(record, true)
	end

	setOtherHidden(entry, true)
end

local function showInstant(entry)
	for _, record in ipairs(entry.parts) do
		setPartHidden(record, false)
	end

	setOtherHidden(entry, false)
end

-- the "being built" reveal: pieces rise and fade in from the ground up, in a wave
local function revealWithBuildEffect(entry)
	local minY, maxY = math.huge, -math.huge

	for _, record in ipairs(entry.parts) do
		local y = record.inst.Position.Y
		minY = math.min(minY, y)
		maxY = math.max(maxY, y)
	end

	local span = math.max(maxY - minY, 0.001)

	-- textures follow the part they sit on
	local texturesByPart = {}

	for _, t in ipairs(entry.textures) do
		local parent = t.inst.Parent

		texturesByPart[parent] = texturesByPart[parent] or {}
		table.insert(texturesByPart[parent], t)
	end

	for _, record in ipairs(entry.parts) do
		local part = record.inst
		local fraction = (part.Position.Y - minY) / span
		local delay = fraction * SWEEP_TIME * 0.8 + math.random() * SWEEP_TIME * 0.2

		task.delay(delay, function()
			-- solid again the moment it starts building in
			part.CanCollide = record.canCollide
			part.CanQuery = record.canQuery
			part.CanTouch = record.canTouch

			local fadeInfo = TweenInfo.new(PART_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

			TweenService:Create(part, fadeInfo, { LocalTransparencyModifier = 0 }):Play()

			for _, t in ipairs(texturesByPart[part] or {}) do
				TweenService:Create(t.inst, fadeInfo, { Transparency = t.transparency }):Play()
			end

			-- a small local "pop up into place" on anchored scenery (never moves unanchored parts)
			if part.Anchored and #part:GetJoints() == 0 then
				local home = part.CFrame
				part.CFrame = home * CFrame.new(0, -RISE, 0)

				TweenService:Create(
					part,
					TweenInfo.new(PART_FADE_TIME + 0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ CFrame = home }
				):Play()
			end
		end)
	end

	-- any texture not sitting directly on one of the parts above
	for _, t in ipairs(entry.textures) do
		if not entry.known[t.inst.Parent] then
			TweenService:Create(
				t.inst,
				TweenInfo.new(PART_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Transparency = t.transparency }
			):Play()
		end
	end

	-- boards' UI and effects switch on once the build is mostly done
	task.delay(SWEEP_TIME * 0.6, function()
		for _, g in ipairs(entry.guis) do
			g.inst.Enabled = g.enabled
		end

		for _, fx in ipairs(entry.effects) do
			fx.inst.Enabled = fx.enabled
		end
	end)
end

local function applyZone(entry, animate)
	local unlocked = ZoneConfig.isRevealed(player, entry.def)

	if entry.revealed == unlocked then
		return
	end

	if entry.revealed == nil or not animate then
		if unlocked then
			showInstant(entry)
		else
			hideInstant(entry)
		end
	elseif unlocked and entry.def.silent then
		revealWithBuildEffect(entry)
	elseif unlocked then
		revealWithBuildEffect(entry)
		announce(entry.def.label or niceName(entry.def.name))

		-- sparkles over the middle of the new area
		local minP, maxP

		for _, record in ipairs(entry.parts) do
			local p = record.inst.Position
			minP = minP and minP:Min(p) or p
			maxP = maxP and maxP:Max(p) or p
		end

		if minP then
			local center = (minP + maxP) / 2
			local radius = math.clamp((maxP - minP).Magnitude / 4, 4, 20)

			task.delay(0.3, sparkleBurst, Vector3.new(center.X, maxP.Y + 2, center.Z), radius)
		end
	else
		hideInstant(entry)
	end

	entry.revealed = unlocked
end

local function refreshAll(animate)
	for _, entry in ipairs(entries) do
		applyZone(entry, animate)
	end
end

-- until data loads, everything but Starter stays hidden
refreshAll(false)

for _, zoneDef in ipairs(ZoneConfig.Zones) do
	if not ZoneConfig.alwaysOpen(zoneDef) then
		player:GetAttributeChangedSignal(ZoneConfig.flagAttribute(zoneDef)):Connect(function()
			-- flags that arrive with the saved data snap in; ones earned while playing animate
			refreshAll(player:GetAttribute("_ZonesSettled") == true)
		end)
	end
end

-- Island 2's areas also depend on Island 2 being unlocked
player:GetAttributeChangedSignal("Island2Unlocked"):Connect(function()
	refreshAll(player:GetAttribute("_ZonesSettled") == true)
end)

-- once the saved flags have had a moment to arrive, later unlocks play the build effect
local function settle()
	task.delay(2, function()
		refreshAll(false)
		player:SetAttribute("_ZonesSettled", true)
	end)
end

if player:GetAttribute("DataLoaded") then
	settle()
else
	local connection

	connection = player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		if player:GetAttribute("DataLoaded") then
			connection:Disconnect()
			settle()
		end
	end)
end
