local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))

local signsFolder = workspace
	:WaitForChild("Islands")
	:WaitForChild("Island1")
	:WaitForChild("TempZones")
	:WaitForChild("TempZones")

local FADE_TIME = 0.45
local RISE = 2

-- "37 / 50 Rebirths", "3.2K / 10K Time", "1 / 2 Prestiges"
-- (uses the sign's own `progress` when its area has no single stat)
local function progressFor(sign)
	return sign.def.progress or (sign.target.attribute and {
		attribute = sign.target.attribute,
		threshold = sign.target.threshold,
	}) or nil
end

local function progressText(p)
	local have = player:GetAttribute(p.attribute) or 0
	local unit = p.unit or p.attribute

	if p.threshold == 1 and unit:sub(-1) == "s" then
		unit = unit:sub(1, -2) -- "1 Rebirth"
	end

	return NumberFormat.abbreviate(math.min(have, p.threshold)) .. " / " .. NumberFormat.abbreviate(p.threshold) .. " " .. unit
end

------------------------------------------------------------------------------------------
-- track every piece of a sign so it can be shown / hidden on this screen only
------------------------------------------------------------------------------------------
local signs = {}

local function track(sign, inst)
	if sign.known[inst] then
		return
	end

	sign.known[inst] = true

	if inst:IsA("BasePart") then
		table.insert(sign.parts, {
			inst = inst,
			canCollide = inst.CanCollide,
			canQuery = inst.CanQuery,
			canTouch = inst.CanTouch,
			cframe = inst.CFrame,
		})
	elseif inst:IsA("Texture") or inst:IsA("Decal") then
		table.insert(sign.textures, { inst = inst, transparency = inst.Transparency })
	elseif inst:IsA("SurfaceGui") or inst:IsA("BillboardGui") then
		table.insert(sign.guis, { inst = inst, enabled = inst.Enabled })
	elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("Light") then
		table.insert(sign.effects, { inst = inst, enabled = inst.Enabled })
	end

	-- a piece that streams in late matches the sign's current state
	if sign.shown == false then
		sign.applyHidden(inst)
	end
end

local function setHiddenInstant(sign, hidden)
	for _, p in ipairs(sign.parts) do
		p.inst.LocalTransparencyModifier = hidden and 1 or 0
		p.inst.CanCollide = (not hidden) and p.canCollide
		p.inst.CanQuery = (not hidden) and p.canQuery
		p.inst.CanTouch = (not hidden) and p.canTouch
	end

	for _, t in ipairs(sign.textures) do
		t.inst.Transparency = hidden and 1 or t.transparency
	end

	for _, g in ipairs(sign.guis) do
		g.inst.Enabled = (not hidden) and g.enabled
	end

	for _, fx in ipairs(sign.effects) do
		fx.inst.Enabled = (not hidden) and fx.enabled
	end
end

-- rises up out of the ground and fades in
local function appear(sign)
	for _, p in ipairs(sign.parts) do
		local part = p.inst

		part.CanCollide = p.canCollide
		part.CanQuery = p.canQuery
		part.CanTouch = p.canTouch

		TweenService:Create(part, TweenInfo.new(FADE_TIME), { LocalTransparencyModifier = 0 }):Play()

		if part.Anchored and #part:GetJoints() == 0 then
			part.CFrame = p.cframe * CFrame.new(0, -RISE, 0)

			TweenService:Create(
				part,
				TweenInfo.new(FADE_TIME + 0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ CFrame = p.cframe }
			):Play()
		end
	end

	for _, t in ipairs(sign.textures) do
		TweenService:Create(t.inst, TweenInfo.new(FADE_TIME), { Transparency = t.transparency }):Play()
	end

	task.delay(FADE_TIME * 0.5, function()
		if sign.shown then
			for _, g in ipairs(sign.guis) do
				g.inst.Enabled = g.enabled
			end

			for _, fx in ipairs(sign.effects) do
				fx.inst.Enabled = fx.enabled
			end
		end
	end)
end

-- sinks back into the ground and fades out
local function disappear(sign)
	for _, g in ipairs(sign.guis) do
		g.inst.Enabled = false
	end

	for _, fx in ipairs(sign.effects) do
		fx.inst.Enabled = false
	end

	for _, p in ipairs(sign.parts) do
		local part = p.inst

		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false

		TweenService:Create(part, TweenInfo.new(FADE_TIME), { LocalTransparencyModifier = 1 }):Play()

		if part.Anchored and #part:GetJoints() == 0 then
			TweenService:Create(
				part,
				TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ CFrame = p.cframe * CFrame.new(0, -RISE, 0) }
			):Play()

			task.delay(FADE_TIME + 0.05, function()
				if not sign.shown then
					part.CFrame = p.cframe
				end
			end)
		end
	end

	for _, t in ipairs(sign.textures) do
		TweenService:Create(t.inst, TweenInfo.new(FADE_TIME), { Transparency = 1 }):Play()
	end
end

for _, def in ipairs(ZoneConfig.TempZones) do
	local model = signsFolder:WaitForChild(def.model, 15)
	local target = ZoneConfig.find(def.target)
	local after = def.after and ZoneConfig.find(def.after)

	if model and target then
		local sign = {
			def = def,
			target = target,
			after = after,
			model = model,
			parts = {}, textures = {}, guis = {}, effects = {},
			known = {},
			shown = nil,
		}

		sign.applyHidden = function(inst)
			if inst:IsA("BasePart") then
				inst.LocalTransparencyModifier = 1
				inst.CanCollide = false
				inst.CanQuery = false
				inst.CanTouch = false
			elseif inst:IsA("Texture") or inst:IsA("Decal") then
				inst.Transparency = 1
			elseif inst:IsA("SurfaceGui") or inst:IsA("BillboardGui") or inst:IsA("ParticleEmitter")
				or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("Light") then
				inst.Enabled = false
			end
		end

		track(sign, model)

		for _, d in ipairs(model:GetDescendants()) do
			track(sign, d)
		end

		model.DescendantAdded:Connect(function(inst)
			track(sign, inst)
		end)

		-- the "Unlocks At / 37 / 50 Rebirths" text
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("TextLabel") and d.Name == "PriceLabel" then
				sign.priceLabel = d
			end
		end

		table.insert(signs, sign)
	end
end

------------------------------------------------------------------------------------------
-- which signs should be up right now
------------------------------------------------------------------------------------------
local function shouldShow(sign)
	if ZoneConfig.isRevealed(player, sign.target) then
		return false -- its area is open: the sign's job is done
	end

	if sign.after and not ZoneConfig.isRevealed(player, sign.after) then
		return false -- the step before it isn't done yet
	end

	return true
end

local function refresh(animate)
	for _, sign in ipairs(signs) do
		local show = shouldShow(sign)

		local progress = progressFor(sign)

		if sign.priceLabel and progress then
			local text = progressText(progress)

			if sign.priceLabel.Text ~= text then
				sign.priceLabel.Text = text
			end
		end

		if sign.shown ~= show then
			if sign.shown == nil or not animate then
				setHiddenInstant(sign, not show)
			elseif show then
				appear(sign)
			else
				disappear(sign)
			end

			sign.shown = show
		end
	end
end

refresh(false)

local function settled()
	return player:GetAttribute("_ZonesSettled") == true
end

-- signs change when an area unlocks, and their numbers change with the stats
for _, zone in ipairs(ZoneConfig.Zones) do
	if not ZoneConfig.alwaysOpen(zone) then
		player:GetAttributeChangedSignal(ZoneConfig.flagAttribute(zone)):Connect(function()
			refresh(settled())
		end)
	end
end

local statWatched = {}

for _, sign in ipairs(signs) do
	local progress = progressFor(sign)
	local attribute = progress and progress.attribute

	if attribute and not statWatched[attribute] then
		statWatched[attribute] = true

		player:GetAttributeChangedSignal(attribute):Connect(function()
			refresh(settled())
		end)
	end
end

-- once saved data has arrived, snap to the right state (no animation for the initial load)
local function onLoaded()
	task.delay(2, function()
		refresh(false)
	end)
end

if player:GetAttribute("DataLoaded") then
	onLoaded()
else
	local connection

	connection = player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		if player:GetAttribute("DataLoaded") then
			connection:Disconnect()
			onLoaded()
		end
	end)
end
