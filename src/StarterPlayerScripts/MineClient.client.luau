-- The Mine on Island 2 (client side). Ported from the old game's MineManager.
-- Draws your ores (from the MineOre_<slot> attributes MineService sets), the mining circle
-- around you while you're in the mine, and plays the grow / hit-shake / break animations,
-- the HP billboard and sounds. The actual hits come from MineService every TickSeconds.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local OreConfig = require(ReplicatedStorage:WaitForChild("OreConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local eventRemote = remotes:WaitForChild("MineEvent")

local templates = ReplicatedStorage:WaitForChild("MineAssets"):WaitForChild("Ores")
local slotsFolder = workspace:WaitForChild("Islands"):WaitForChild("Island2")
	:WaitForChild("Zones"):WaitForChild("Mine"):WaitForChild("Main"):WaitForChild("Slots")

-- our ores live in their own folder so the zone reveal effects never touch them
local oresFolder = workspace:FindFirstChild("MineOres") or Instance.new("Folder")
oresFolder.Name = "MineOres"
oresFolder.Parent = workspace

local HIT_SOUNDS = { "rbxassetid://9125869797", "rbxassetid://9125869504" }

local drawn = {} -- [slot] = { name, model, pivot, parts, token, billboard, hideToken, breaking }

local function sfxOn()
	return player:GetAttribute("Setting_SFX") ~= false
end

local lastSound = 0

local function playHitSound()
	if not sfxOn() or os.clock() - lastSound < 0.1 then
		return
	end

	lastSound = os.clock()

	local sound = Instance.new("Sound")
	sound.SoundId = HIT_SOUNDS[math.random(1, #HIT_SOUNDS)]
	sound.Volume = 1
	sound.PlayOnRemove = true
	sound.Parent = SoundService
	sound:Destroy()
end

-- ANIMATIONS (same timings as the old game) --------------------------------------
local function setFade(d, visible) -- visible 0..1
	for _, p in ipairs(d.parts) do
		p.part.Transparency = 1 - (1 - p.base) * visible
	end
end

local function playGrow(d)
	d.token += 1
	local token = d.token

	task.spawn(function()
		setFade(d, 0)
		d.model:PivotTo(d.pivot * CFrame.new(0, -3, 0))

		local t = 0

		while t < 0.6 do
			t += RunService.Heartbeat:Wait()

			if d.token ~= token or not d.model.Parent then
				return
			end

			local a = 1 - (1 - math.clamp(t / 0.6, 0, 1)) ^ 3
			d.model:PivotTo(d.pivot * CFrame.new(0, (1 - a) * -3, 0))
			setFade(d, a)
		end

		d.model:PivotTo(d.pivot)
		setFade(d, 1)
	end)
end

local function playShake(d)
	d.token += 1
	local token = d.token

	task.spawn(function()
		local t = 0

		while t < 0.3 do
			t += RunService.Heartbeat:Wait()

			if d.token ~= token or not d.model.Parent then
				return
			end

			local a = t / 0.3
			local fall = 1 - a
			local angle = math.sin(a * math.pi * 3) * 6 * fall
			local dip = math.sin(a * math.pi) * 0.25 * fall
			d.model:PivotTo(d.pivot * CFrame.new(0, -dip, 0) * CFrame.Angles(math.rad(angle), 0, math.rad(angle)))
		end

		if d.token == token then
			d.model:PivotTo(d.pivot)
		end
	end)
end

local function playBreak(d)
	d.token += 1
	d.breaking = true
	local token = d.token

	if d.billboard then
		d.billboard.Enabled = false
	end

	task.spawn(function()
		local t = 0

		while t < 0.5 do
			t += RunService.Heartbeat:Wait()

			if d.token ~= token or not d.model.Parent then
				return
			end

			local spin, rise, fade

			if t < 0.08 then
				spin, rise, fade = 0, 0, 0
			elseif t < 0.2 then
				local a = 1 - (1 - (t - 0.08) / 0.12) ^ 2
				rise, spin, fade = a * 0.75, a * 0.3, 0
			else
				local a = math.clamp((t - 0.2) / 0.3, 0, 1)
				fade = a ^ 2
				rise = (a * 0.5 + 0.5) * 1.5
				spin = fade * 0.7 + 0.3
			end

			d.model:PivotTo(d.pivot * CFrame.new(0, rise, 0) * CFrame.Angles(0, math.rad(spin * 2.5 * 360), 0))

			for _, p in ipairs(d.parts) do
				p.part.Transparency = p.base + (1 - p.base) * fade
			end
		end
	end)
end

-- HP BILLBOARD ---------------------------------------------------------------------
local function makeBillboard(d)
	local hitbox = d.model:FindFirstChild("Hitbox")

	local gui = Instance.new("BillboardGui")
	gui.Name = "OreInfo"
	gui.Adornee = hitbox
	gui.Size = UDim2.fromScale(5, 1.9)
	gui.StudsOffset = Vector3.new(0, 3.3, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 60
	gui.Enabled = false
	gui.Parent = d.model

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.38)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = d.name
	title.TextColor3 = OreConfig.Ores[d.name].Color
	title.Parent = gui
	local ts = Instance.new("UIStroke")
	ts.Thickness = 2
	ts.Parent = title

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromScale(0.08, 0.42)
	bar.Size = UDim2.fromScale(0.84, 0.24)
	bar.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	bar.Parent = gui
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0.5, 0)
	local bs = Instance.new("UIStroke")
	bs.Thickness = 2
	bs.Parent = bar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HP"
	hpText.BackgroundTransparency = 1
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.Font = Enum.Font.FredokaOne
	hpText.TextScaled = true
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.ZIndex = 2
	hpText.Parent = bar
	local hs = Instance.new("UIStroke")
	hs.Thickness = 1.5
	hs.Parent = hpText

	local rewardRow = Instance.new("Frame")
	rewardRow.Name = "Reward"
	rewardRow.BackgroundTransparency = 1
	rewardRow.Position = UDim2.fromScale(0, 0.7)
	rewardRow.Size = UDim2.fromScale(1, 0.3)
	rewardRow.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rewardRow

	local rewardText = Instance.new("TextLabel")
	rewardText.Name = "Amount"
	rewardText.BackgroundTransparency = 1
	rewardText.AutomaticSize = Enum.AutomaticSize.X
	rewardText.Size = UDim2.fromScale(0, 1)
	rewardText.Font = Enum.Font.FredokaOne
	rewardText.TextScaled = true
	rewardText.TextColor3 = Color3.fromRGB(255, 255, 255)
	rewardText.LayoutOrder = 1
	rewardText.Parent = rewardRow
	local rs = Instance.new("UIStroke")
	rs.Thickness = 1.5
	rs.Parent = rewardText

	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Image = OreConfig.Icon
	icon.Size = UDim2.fromScale(1, 1)
	icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	icon.LayoutOrder = 2
	icon.Parent = rewardRow

	d.billboard = gui
	d.fill = fill
	d.hpText = hpText
	d.rewardText = rewardText
end

local function showBillboard(d, hp, maxHp, reward)
	if not d.billboard then
		makeBillboard(d)
	end

	local ratio = math.clamp(hp / math.max(maxHp, 1), 0, 1)

	TweenService:Create(d.fill, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(ratio, 1) }):Play()
	d.fill.BackgroundColor3 = Color3.fromRGB(230, 70, 60):Lerp(Color3.fromRGB(90, 220, 90), ratio)
	d.hpText.Text = NumberFormat.abbreviate(math.max(hp, 0)) .. " / " .. NumberFormat.abbreviate(maxHp)
	d.rewardText.Text = "+" .. NumberFormat.abbreviate(reward)
	d.billboard.Enabled = true

	d.hideToken = (d.hideToken or 0) + 1
	local token = d.hideToken

	task.delay(10, function()
		if d.hideToken == token and d.billboard then
			d.billboard.Enabled = false
		end
	end)
end

-- "+X Ores" orb when an ore breaks
local function orb(position, amount)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position + Vector3.new(math.random(-8, 8) / 10, 0, math.random(-8, 8) / 10)
	anchor.Parent = oresFolder

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(4, 1.3)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Adornee = anchor
	gui.Parent = anchor

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(200, 205, 215)
	label.Text = "+" .. NumberFormat.abbreviate(amount)
	label.LayoutOrder = 1
	label.Parent = holder

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(25, 25, 30)
	stroke.Parent = label

	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = OreConfig.Icon
	image.Size = UDim2.fromScale(1, 1)
	image.SizeConstraint = Enum.SizeConstraint.RelativeYY
	image.LayoutOrder = 2
	image.Parent = holder

	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = holder

	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 6, 0) }):Play()

	task.delay(0.8, function()
		local fade = TweenInfo.new(0.4)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		TweenService:Create(image, fade, { ImageTransparency = 1 }):Play()
	end)

	task.delay(1.3, function()
		anchor:Destroy()
	end)
end

-- DRAWING --------------------------------------------------------------------------
local function remove(slot)
	local d = drawn[slot]

	if d then
		d.token += 1
		d.model:Destroy()
		drawn[slot] = nil
	end
end

local function draw(slot, oreName)
	local slotPart = slotsFolder:FindFirstChild(slot)
	local template = templates:FindFirstChild(oreName)

	if not (slotPart and template) then
		return
	end

	remove(slot)

	local model = template:Clone()
	local pivot = slotPart.CFrame * template:GetPivot()
	model:PivotTo(pivot)
	model:SetAttribute("Slot", slot)

	local parts = {}

	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			table.insert(parts, { part = p, base = p.Transparency })
		end
	end

	model.Parent = oresFolder

	local d = { name = oreName, model = model, pivot = pivot, parts = parts, token = 0 }
	drawn[slot] = d
	playGrow(d)
end

local function refresh(slot)
	local oreName = player:GetAttribute(OreConfig.slotAttribute(slot))
	local d = drawn[slot]

	if oreName then
		if not d or d.name ~= oreName or d.breaking then
			draw(slot, oreName)
		end
	elseif d then
		-- give a break animation time to finish before the model goes
		if d.breaking then
			task.delay(0.1, function()
				if drawn[slot] == d then
					remove(slot)
				end
			end)
		else
			remove(slot)
		end
	end
end

-- (the place streams parts in, so a slot's part may arrive after its ore does)
local PREFIX = "MineOre_"

player.AttributeChanged:Connect(function(name)
	if name:sub(1, #PREFIX) == PREFIX then
		refresh(name:sub(#PREFIX + 1))
	end
end)

slotsFolder.ChildAdded:Connect(function(child)
	task.defer(refresh, child.Name)
end)

for name in pairs(player:GetAttributes()) do
	if name:sub(1, #PREFIX) == PREFIX then
		refresh(name:sub(#PREFIX + 1))
	end
end

-- MINING CIRCLE ------------------------------------------------------------------
local RADIUS = OreConfig.MineRadius
local FILL = Color3.fromRGB(120, 205, 170)
local OUTLINE = Color3.fromRGB(20, 45, 35)
local IN_RANGE = Color3.fromRGB(90, 255, 140)
local OUT_OF_RANGE = Color3.fromRGB(255, 255, 255)

local circle = Instance.new("Part")
circle.Name = "MiningRadius"
circle.Anchored = true
circle.CanCollide = false
circle.CanQuery = false
circle.CanTouch = false
circle.CastShadow = false
circle.Transparency = 1
circle.Size = Vector3.new(RADIUS * 2, 0.05, RADIUS * 2)
circle.Parent = oresFolder

local surface = Instance.new("SurfaceGui")
surface.Face = Enum.NormalId.Top
surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surface.PixelsPerStud = 40
surface.LightInfluence = 0
surface.Adornee = circle
surface.Parent = circle

local disc = Instance.new("Frame")
disc.AnchorPoint = Vector2.new(0.5, 0.5)
disc.Position = UDim2.fromScale(0.5, 0.5)
disc.Size = UDim2.new(1, -8, 1, -8)
disc.BackgroundColor3 = FILL
disc.BackgroundTransparency = 1
disc.Parent = surface
Instance.new("UICorner", disc).CornerRadius = UDim.new(0.5, 0)

local ring = Instance.new("UIStroke")
ring.Color = OUTLINE
ring.Thickness = 6
ring.Transparency = 1
ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ring.Parent = disc

-- fills up from the middle as the next hit comes (a guess on our side; reset on every real tick)
local progress = Instance.new("Frame")
progress.AnchorPoint = Vector2.new(0.5, 0.5)
progress.Position = UDim2.fromScale(0.5, 0.5)
progress.Size = UDim2.fromScale(0, 0)
progress.BackgroundColor3 = FILL
progress.BackgroundTransparency = 1
progress.Parent = disc
Instance.new("UICorner", progress).CornerRadius = UDim.new(0.5, 0)

local discScale = Instance.new("UIScale")
discScale.Parent = disc

local shown = 0 -- 0 hidden .. 1 fully visible
local tickProgress = 0

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function paintCircle()
	disc.BackgroundTransparency = 1 - 0.5 * shown
	ring.Transparency = 1 - shown
	progress.BackgroundTransparency = 1 - 0.35 * shown
	surface.Enabled = shown > 0.01
end

paintCircle()

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local inMine = root ~= nil and OreConfig.inArea(slotsFolder, root.Position)

	-- fade the circle in/out as you enter/leave the mine
	local target = inMine and 1 or 0
	shown += (target - shown) * math.clamp(dt * 10, 0, 1)

	if math.abs(target - shown) < 0.01 then
		shown = target
	end

	paintCircle()

	local anyInRange = false

	for _, d in pairs(drawn) do
		local inside = inMine and not d.breaking and OreConfig.inRange(root.Position, d.pivot.Position)
		local highlight = d.model:FindFirstChildOfClass("Highlight")

		if highlight then
			highlight.OutlineColor = inside and IN_RANGE or OUT_OF_RANGE
		end

		anyInRange = anyInRange or inside
	end

	if not root or shown <= 0 then
		return
	end

	-- sit flat on the ground under you
	groundParams.FilterDescendantsInstances = { character, oresFolder }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), groundParams)
	local y = hit and hit.Position.Y or (root.Position.Y - 3)
	circle.CFrame = CFrame.new(root.Position.X, y + 0.06, root.Position.Z)

	-- the next-hit fill
	if anyInRange then
		tickProgress = math.min(tickProgress + dt / OreConfig.TickSeconds, 1)
	else
		tickProgress = 0
	end

	progress.Size = UDim2.fromScale(tickProgress, tickProgress)
end)

local function pulse()
	tickProgress = 0
	discScale.Scale = 1.06
	ring.Color = IN_RANGE
	TweenService:Create(discScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(ring, TweenInfo.new(0.35), { Color = OUTLINE }):Play()
end

-- SERVER RESULTS -------------------------------------------------------------------
eventRemote.OnClientEvent:Connect(function(kind, slot, a, b, c)
	if kind == "tick" then
		pulse()
		return
	end

	local d = drawn[slot]

	if kind == "hit" then
		if d then
			playShake(d)
			showBillboard(d, a, b, c)
		end

		playHitSound()
	elseif kind == "break" then
		if d then
			playBreak(d)
			orb(d.pivot.Position, a)
		end

		playHitSound()
	end
end)
