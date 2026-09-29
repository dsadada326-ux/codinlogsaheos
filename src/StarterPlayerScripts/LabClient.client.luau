-- THE LABORATORY (client). Draws your own lab tycoon on your screen:
--   * red buttons (from LabAssets.LabButton) for the next pieces, and each piece building itself in
--   * the Chemistry Station mixing minigame + the Oxygen pump (SurfaceGuis on their screens)
--   * the potion hotbar, the Potion Brewer menu, selling at the Potion Stand, the Knowledge Shop
-- LabService on the server checks all of the real rules. Tuning: ReplicatedStorage.LabConfig.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LabConfig = require(ReplicatedStorage:WaitForChild("LabConfig"))
local Kit = require(ReplicatedStorage:WaitForChild("FishingUIKit"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local assets = ReplicatedStorage:WaitForChild("LabAssets")
local itemTemplates = assets:WaitForChild("Items")
local buttonTemplate = assets:WaitForChild("LabButton")
local actionRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LabAction")

local INK = Color3.fromRGB(10, 12, 18)
local FY = 2.55 -- the lab floor
local CUR_ORDER = { "Chemicals", "Oxygen", "CarbonDioxide" }

local function now()
	return workspace:GetServerTimeNow()
end
local function abbreviate(n)
	return NumberFormat.abbreviate(math.floor(n + 0.5))
end
local function fmt1(n)
	if n >= 100 then return abbreviate(n) end
	return tostring(math.floor(n * 10 + 0.5) / 10)
end
local function have(cur)
	return player:GetAttribute(LabConfig.Currencies[cur].attr) or 0
end
local function invoke(...)
	local args = table.pack(...)
	local ok, r = pcall(function() return actionRemote:InvokeServer(table.unpack(args, 1, args.n)) end)
	if ok and type(r) == "table" then return r end
	return { ok = false, reason = "error" }
end

local folder = Instance.new("Folder")
folder.Name = "LabClient"
folder.Parent = workspace

------------------------------------------------------------------------------------------
-- little helpers: currency icons, flask icons, toasts
------------------------------------------------------------------------------------------
local function currencyIcon(parent, cur, props)
	local info = LabConfig.Currencies[cur]
	local icon
	if info.icon ~= "" then
		icon = Kit.image(parent, { Image = info.icon })
	else
		-- Oxygen / CO2 are drawn with frames: borrow the ones from the currency list
		local row = playerGui:WaitForChild("Currencies", 10)
		row = row and row:WaitForChild("MainCurrenciesFrame", 5)
		row = row and row:WaitForChild("CurrenciesFrame", 5)
		row = row and row:WaitForChild(cur, 5)
		local src = row and row:FindFirstChild("Icon")
		if src then
			icon = src:Clone()
			icon.Parent = parent
		else
			icon = Kit.text(parent, { Text = info.short or cur:sub(1, 2), TextColor3 = info.color })
		end
	end
	icon.Name = "CurrencyIcon"
	icon.AnchorPoint = Vector2.zero
	icon.Position = UDim2.new()
	for k, v in pairs(props or {}) do icon[k] = v end
	if not icon:FindFirstChildOfClass("UIAspectRatioConstraint") then
		Kit.new("UIAspectRatioConstraint", { AspectRatio = 1 }, icon)
	end
	return icon
end

-- a round potion flask drawn with frames
local function flaskIcon(parent, color, props)
	local holder = Kit.new("Frame", { Name = "Flask", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
	for k, v in pairs(props or {}) do holder[k] = v end
	Kit.new("UIAspectRatioConstraint", { AspectRatio = 1 }, holder)
	local z = holder.ZIndex
	local glass = Color3.fromRGB(225, 240, 250)
	local neck = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.1), Size = UDim2.fromScale(0.26, 0.34),
		BackgroundColor3 = glass, BackgroundTransparency = 0.15, ZIndex = z,
	}, holder)
	Kit.corner(neck, 0.2)
	Kit.stroke(neck, 2, INK, true)
	local cork = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.02), Size = UDim2.fromScale(0.3, 0.13),
		BackgroundColor3 = Color3.fromRGB(170, 110, 60), ZIndex = z + 2,
	}, holder)
	Kit.corner(cork, 0.3)
	Kit.stroke(cork, 2, INK, true)
	local body = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.98), Size = UDim2.fromScale(0.74, 0.66),
		BackgroundColor3 = glass, BackgroundTransparency = 0.15, ZIndex = z + 1,
	}, holder)
	Kit.corner(body, 1)
	Kit.stroke(body, 2.5, INK, true)
	local liquid = Kit.new("Frame", {
		Name = "Liquid", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromScale(0.8, 0.8),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = z + 2,
	}, body)
	Kit.corner(liquid, 1)
	local grad = Kit.gradient(liquid, color:Lerp(Color3.new(1, 1, 1), 0.35), color:Lerp(Color3.new(0, 0, 0), 0.25))
	local shine = Kit.new("Frame", {
		Position = UDim2.fromScale(0.2, 0.18), Size = UDim2.fromScale(0.22, 0.16), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.2, ZIndex = z + 3, Rotation = -30,
	}, body)
	Kit.corner(shine, 1)
	local function setColor(c)
		grad.Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.35), c:Lerp(Color3.new(0, 0, 0), 0.25))
	end
	return holder, setColor
end

local toastGui = Kit.new("ScreenGui", { Name = "LabToasts", ResetOnSpawn = false, DisplayOrder = 25, IgnoreGuiInset = true }, playerGui)
local function toast(text, color, icon, big)
	local holder = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, big and 0.3 or 0.36),
		Size = UDim2.fromScale(0.5, big and 0.085 or 0.06), BackgroundTransparency = 1,
	}, toastGui)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8),
	}, holder)
	local label = Kit.text(holder, {
		Text = text, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = color or Color3.new(1, 1, 1), Stroke = 3,
	})
	if icon then
		currencyIcon(holder, icon, { Size = UDim2.fromScale(1, 1), SizeConstraint = Enum.SizeConstraint.RelativeYY, LayoutOrder = 2 })
	end
	local sc = Kit.new("UIScale", { Scale = 0.3 }, holder)
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(holder, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { Position = holder.Position - UDim2.fromScale(0, 0.06) }):Play()
	task.delay(1.2, function()
		TweenService:Create(sc, TweenInfo.new(0.3), { Scale = 0 }):Play()
	end)
	task.delay(1.6, function() holder:Destroy() end)
	return label
end

-- "+12" floating over something in the world
local function worldPop(adornee, text, color, icon)
	local g = Kit.new("BillboardGui", {
		Size = UDim2.fromOffset(200, 42), AlwaysOnTop = true, LightInfluence = 0, Adornee = adornee,
		StudsOffsetWorldSpace = Vector3.new(0, 1, 0), ResetOnSpawn = false,
	}, playerGui)
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, g)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4),
	}, holder)
	Kit.text(holder, { Text = text, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = color, Stroke = 2.5 })
	if icon then
		currencyIcon(holder, icon, { Size = UDim2.fromScale(1, 1), SizeConstraint = Enum.SizeConstraint.RelativeYY, LayoutOrder = 2 })
	end
	local sc = Kit.new("UIScale", { Scale = 0.3 }, holder)
	TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(g, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { StudsOffsetWorldSpace = Vector3.new(0, 5, 0) }):Play()
	task.delay(0.8, function() TweenService:Create(sc, TweenInfo.new(0.3), { Scale = 0 }):Play() end)
	task.delay(1.15, function() g:Destroy() end)
end

local function customPrompt(parent, action, object, opens)
	local p = Instance.new("ProximityPrompt")
	p.Style = Enum.ProximityPromptStyle.Custom
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.RequiresLineOfSight = false
	p.MaxActivationDistance = 11
	p.HoldDuration = 0
	if opens then p:SetAttribute("Opens", opens) end
	p.Parent = parent
	return p
end

local function anchorPart(name, cf)
	local a = Instance.new("Part")
	a.Name = name
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.Transparency = 1
	a.Size = Vector3.new(1, 1, 1)
	a.CFrame = cf
	a.Parent = folder
	return a
end

-- a screen on a lab machine (buttons on SurfaceGuis only work from PlayerGui)
local function screenGui(screenPart, name)
	local sg = Kit.new("SurfaceGui", {
		Name = name, Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50,
		LightInfluence = 0, MaxDistance = 90, Adornee = screenPart, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	local bg = Kit.new("Frame", { Name = "Bg", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(16, 22, 34) }, sg)
	Kit.gradient(bg, Color3.fromRGB(34, 48, 70), Color3.fromRGB(12, 16, 26))
	Kit.new("ImageLabel", {
		Name = "Checker", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = "rbxassetid://6372755229",
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(50, 50), ImageTransparency = 0.93,
	}, bg)
	return sg, bg
end

------------------------------------------------------------------------------------------
-- THE TYCOON PIECES: each one builds itself in, part by part (lerped down into place)
------------------------------------------------------------------------------------------
local built = {} -- [id] = model
local spinners = {} -- { model, base, axis, speed }
local onBuilt = {} -- [id] = function(model) (screens, prompts...)
local onRemoved = {} -- [id] = function()

local SPIN = {
	Fan = { axis = "Z", speed = 9 },
	Ring = { axis = "Y", speed = 1.4 },
	Halo = { axis = "Y", speed = -0.9 },
	Stirrer = { axis = "Y", speed = 2.2 },
}

local function startSpinners(id, model)
	for _, d in ipairs(model:GetDescendants()) do
		local s = d:IsA("Model") and SPIN[d.Name]
		if s then
			table.insert(spinners, { owner = id, model = d, base = d:GetPivot(), axis = s.axis, speed = s.speed, bob = d.Name == "Halo" })
		end
	end
end

local function dust(position, color)
	local att = Instance.new("Attachment")
	att.WorldPosition = position
	att.Parent = workspace.Terrain
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color or Color3.fromRGB(140, 255, 160))
	pe.LightEmission = 0.7
	pe.Size = NumberSequence.new(0.8, 0)
	pe.Lifetime = NumberRange.new(0.6, 1.1)
	pe.Speed = NumberRange.new(6, 14)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Rate = 0
	pe.Parent = att
	pe:Emit(40)
	task.delay(2, function() att:Destroy() end)
end

local function buildIn(id, model)
	local parts = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			table.insert(parts, p)
		elseif p:IsA("ParticleEmitter") or p:IsA("Light") or p:IsA("SurfaceGui") or p:IsA("Beam") then
			if p.Enabled then
				p.Enabled = false
				p:SetAttribute("LabWasOn", true)
			end
		end
	end
	table.sort(parts, function(a, b) return a.Position.Y < b.Position.Y end)
	local total = math.clamp(#parts * 0.035, 0.5, 1.6)
	local rng = Random.new()
	for i, p in ipairs(parts) do
		local target, alpha = p.CFrame, p.Transparency
		p.Transparency = 1
		p.CFrame = target * CFrame.new(rng:NextNumber(-3, 3), rng:NextNumber(7, 12), rng:NextNumber(-3, 3))
			* CFrame.Angles(rng:NextNumber(-0.8, 0.8), rng:NextNumber(-1.2, 1.2), rng:NextNumber(-0.8, 0.8))
		task.delay((i - 1) / #parts * total, function()
			if not p.Parent then return end
			TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = target, Transparency = alpha }):Play()
		end)
	end
	task.delay(total + 0.55, function()
		if not model.Parent then return end
		for _, d in ipairs(model:GetDescendants()) do
			if d:GetAttribute("LabWasOn") then d.Enabled = true end
		end
		local cf, size = model:GetBoundingBox()
		dust(cf.Position - Vector3.new(0, size.Y / 2 - 1, 0))
		startSpinners(id, model)
	end)
end

local function renderItem(id, animate)
	if built[id] then return end
	local template = itemTemplates:FindFirstChild(id)
	if not template then return end
	local model = template:Clone()
	model.Parent = folder
	built[id] = model
	if animate then
		buildIn(id, model)
	else
		startSpinners(id, model)
	end
	if onBuilt[id] then task.spawn(onBuilt[id], model) end
end

local function removeItem(id, animate)
	local model = built[id]
	if not model then return end
	built[id] = nil
	for i = #spinners, 1, -1 do
		if spinners[i].owner == id then table.remove(spinners, i) end
	end
	if onRemoved[id] then onRemoved[id]() end
	if not animate then
		model:Destroy()
		return
	end
	-- a Lab Level reset: everything flies apart and fades out
	local rng = Random.new()
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			TweenService:Create(p, TweenInfo.new(rng:NextNumber(0.5, 0.9), Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = p.CFrame * CFrame.new(rng:NextNumber(-4, 4), rng:NextNumber(6, 14), rng:NextNumber(-4, 4))
					* CFrame.Angles(rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), rng:NextNumber(-2, 2)),
				Transparency = 1,
			}):Play()
		elseif p:IsA("ParticleEmitter") or p:IsA("Light") or p:IsA("SurfaceGui") or p:IsA("Beam") then
			p.Enabled = false
		end
	end
	local cf = model:GetBoundingBox()
	dust(cf.Position, Color3.fromRGB(200, 255, 220))
	task.delay(1, function() model:Destroy() end)
end

------------------------------------------------------------------------------------------
-- RED BUTTONS
------------------------------------------------------------------------------------------
local buttons = {} -- [id] = { model, part, base, rest, tag... }

local function paintButton(b)
	local def = LabConfig.Items[b.id]
	local affordable = have(def.currency) >= def.cost
	local design = b.tag and b.tag:FindFirstChild("Design", true)
	if design then
		for _, child in ipairs(design:GetChildren()) do
			if child.Name:sub(-2) == "On" then child.Enabled = affordable
			elseif child.Name:sub(-3) == "Off" then child.Enabled = not affordable end
		end
	end
end

local function paintButtons()
	for _, b in pairs(buttons) do paintButton(b) end
end

local function removeButton(id, animate)
	local b = buttons[id]
	if not b then return end
	buttons[id] = nil
	if animate then
		local target = b.model:GetPivot()
		local v = Instance.new("NumberValue")
		v:GetPropertyChangedSignal("Value"):Connect(function()
			if b.model.Parent then b.model:PivotTo(target * CFrame.new(0, -2.2 * v.Value, 0)) end
		end)
		local t = TweenService:Create(v, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Value = 1 })
		t.Completed:Connect(function() b.model:Destroy() v:Destroy() end)
		t:Play()
		if b.tag then b.tag.Enabled = false end
	else
		b.model:Destroy()
	end
end

local function addButton(id, animate)
	if buttons[id] then return end
	local def = LabConfig.Items[id]
	local model = buttonTemplate:Clone()
	model.Name = "LabButton_" .. id
	local cf, size = model:GetBoundingBox()
	local target = model:GetPivot() + Vector3.new(def.button[1] - cf.X, FY + size.Y / 2 - cf.Y, def.button[2] - cf.Z)
	model:PivotTo(target)
	model.Parent = folder
	local part = model:WaitForChild("Button")
	local base = model:WaitForChild("Part")
	local tag = part:FindFirstChild("PriceTag")
	local b = { id = id, model = model, part = part, base = base, tag = tag, rest = base.CFrame:ToObjectSpace(part.CFrame) }
	buttons[id] = b
	if tag then
		tag.ResetOnSpawn = false
		local nameLabel = tag:FindFirstChild("NameLabel", true)
		local priceLabel = tag:FindFirstChild("PriceLabel", true)
		local icon = tag:FindFirstChild("CurrencyImageIcon", true)
		if nameLabel then nameLabel.Text = def.name end
		if priceLabel then
			local short = LabConfig.Currencies[def.currency].short
			priceLabel.Text = def.cost <= 0 and "FREE" or abbreviate(def.cost)
			if def.cost > 0 and def.currency == "Oxygen" then priceLabel.Text ..= " O2" end
			if def.cost > 0 and short and def.currency ~= "Oxygen" then priceLabel.Text ..= " " .. short end
		end
		if icon then
			local img = LabConfig.Currencies[def.currency].icon
			icon.Image = img
			icon.Visible = def.cost > 0 and img ~= ""
		end
	end
	-- what it does, under the price tag
	local info = Kit.new("BillboardGui", {
		Name = "LabButtonInfo", Size = UDim2.fromOffset(220, 26), StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0),
		MaxDistance = 40, LightInfluence = 0, Adornee = part, ResetOnSpawn = false,
	}, model)
	Kit.text(info, { Text = def.desc or "", Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(255, 235, 170), Stroke = 2 })
	if id == "ChemistryStation" then
		info.Size = UDim2.fromOffset(240, 60)
		info.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
		info:ClearAllChildren()
		local l = Kit.text(info, { Text = "START YOUR LAB!", Size = UDim2.new(1, 0, 0.55, 0), TextColor3 = Color3.fromRGB(140, 255, 150), Stroke = 3 })
		Kit.text(info, { Text = "step on the red button", Position = UDim2.fromScale(0, 0.55), Size = UDim2.new(1, 0, 0.4, 0), Stroke = 2 })
		task.spawn(function()
			while l.Parent and info.Parent do
				Kit.pop(l, 1.12)
				task.wait(0.9)
			end
		end)
	end
	paintButton(b)

	if animate then
		local v = Instance.new("NumberValue")
		model:PivotTo(target * CFrame.new(0, -2.2, 0))
		v:GetPropertyChangedSignal("Value"):Connect(function()
			if buttons[id] == b then model:PivotTo(target * CFrame.new(0, -2.2 * (1 - v.Value), 0)) end
		end)
		local t = TweenService:Create(v, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 })
		t.Completed:Connect(function() v:Destroy() end)
		t:Play()
	end

	local busy, blockedUntil = false, 0
	part.Touched:Connect(function(hit)
		local character = player.Character
		if buttons[id] ~= b or busy or os.clock() < blockedUntil or not (character and hit:IsDescendantOf(character)) then
			return
		end
		busy = true
		local rest = base.CFrame * b.rest
		TweenService:Create(part, TweenInfo.new(0.08), { CFrame = rest * CFrame.new(0, -0.3, 0) }):Play()
		local r = invoke("buy", id)
		if r.ok then
			blockedUntil = math.huge
		else
			TweenService:Create(part, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = base.CFrame * b.rest }):Play()
			if r.reason == "cost" then
				local short = LabConfig.Currencies[def.currency].short or def.currency
				toast("Not enough " .. short .. "! (" .. abbreviate(have(def.currency)) .. "/" .. abbreviate(def.cost) .. ")", Color3.fromRGB(255, 110, 110))
			end
			blockedUntil = os.clock() + 1.5
		end
		task.wait(0.3)
		busy = false
	end)
end

------------------------------------------------------------------------------------------
-- CHEMISTRY STATION: the mixing minigame on its screen
------------------------------------------------------------------------------------------
local MIX = LabConfig.Mix
local mix -- { gui, track, zone, perfect, marker, streak, button, paint, feedback, freezeUntil, freezePos, busy, anchor }

local function markerNow()
	local t0 = player:GetAttribute("LabMixT0") or 0
	local speed = player:GetAttribute("LabMixSpeed") or MIX.Speed[1]
	local u = ((now() - t0) * speed) % 2
	return u < 1 and u or 2 - u
end

local function mixGain(streak, perfect)
	return MIX.Base * (LabConfig.owns(player, "MixingBench") and 2 or 1) * (1 + streak * LabConfig.streakStep(player))
		* (perfect and MIX.PerfectBonus or 1) * LabConfig.chemMultiplier(player)
end

local function doMix()
	if not mix or mix.busy then return end
	mix.busy = true
	local t = now()
	local pos = markerNow()
	mix.freezeUntil, mix.freezePos = os.clock() + 0.35, pos
	Kit.pop(mix.button, 0.9)
	local r = invoke("mix", t)
	if r.ok then
		mix.freezePos = r.pos or pos
		if r.hit then
			local c = r.perfect and Color3.fromRGB(255, 225, 90) or Color3.fromRGB(120, 255, 130)
			mix.feedback.Text = (r.perfect and "PERFECT! " or "NICE! ") .. "+" .. fmt1(r.gain)
			mix.feedback.TextColor3 = c
			mix.zone.BackgroundColor3 = Color3.new(1, 1, 1)
			worldPop(mix.anchor, "+" .. fmt1(r.gain), c, "Chemicals")
			if r.perfect then dust(mix.anchor.Position + Vector3.new(0, 3, 0), Color3.fromRGB(255, 230, 100)) end
		else
			mix.feedback.Text = "MISSED! streak lost"
			mix.feedback.TextColor3 = Color3.fromRGB(255, 100, 100)
			mix.track.BackgroundColor3 = Color3.fromRGB(120, 20, 25)
		end
		Kit.pop(mix.feedback, 1.35)
		task.delay(0.25, function()
			if mix then
				mix.zone.BackgroundColor3 = Color3.fromRGB(70, 230, 100)
				mix.track.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
			end
		end)
	else
		mix.freezeUntil = 0
	end
	task.wait(0.08)
	if mix then mix.busy = false end
end

onBuilt.ChemistryStation = function(model)
	local screen = model:WaitForChild("Screen")
	local sg, bg = screenGui(screen, "LabMixScreen")
	local m = { gui = sg, freezeUntil = 0 }
	Kit.text(bg, {
		Text = "CHEMICAL MIXER", Position = UDim2.fromScale(0.04, 0.03), Size = UDim2.fromScale(0.6, 0.15),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(140, 255, 150), Stroke = 3,
	})
	m.streak = Kit.text(bg, {
		Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.96, 0.04), Size = UDim2.fromScale(0.34, 0.12),
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 210, 90), Stroke = 2.5,
	})
	m.per = Kit.text(bg, {
		Text = "", Position = UDim2.fromScale(0.04, 0.19), Size = UDim2.fromScale(0.92, 0.08),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 210, 235), Stroke = 2,
	})
	m.track = Kit.new("Frame", {
		Name = "Track", Position = UDim2.fromScale(0.05, 0.31), Size = UDim2.fromScale(0.9, 0.2), BackgroundColor3 = Color3.fromRGB(28, 32, 44),
	}, bg)
	Kit.corner(m.track, 0.25)
	Kit.stroke(m.track, 4, INK, true)
	m.zone = Kit.new("Frame", {
		Name = "Zone", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.2, 0.84),
		BackgroundColor3 = Color3.fromRGB(70, 230, 100),
	}, m.track)
	Kit.corner(m.zone, 0.2)
	Kit.gradient(m.zone, Color3.new(1, 1, 1), Color3.fromRGB(160, 200, 160))
	m.perfect = Kit.new("Frame", {
		Name = "Perfect", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.32, 1),
		BackgroundColor3 = Color3.fromRGB(255, 230, 90), BorderSizePixel = 0,
	}, m.zone)
	Kit.corner(m.perfect, 0.2)
	m.marker = Kit.new("Frame", {
		Name = "Marker", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 12, 1.35, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3,
	}, m.track)
	Kit.corner(m.marker, 0.5)
	Kit.stroke(m.marker, 3, INK, true)
	m.feedback = Kit.text(bg, {
		Text = "Hit MIX when the marker is in the green!", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.54),
		Size = UDim2.fromScale(0.9, 0.11), TextColor3 = Color3.fromRGB(220, 230, 245), Stroke = 2.5,
	})
	local b, paint = Kit.button(bg, {
		Name = "Mix", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.95), Size = UDim2.fromScale(0.46, 0.26),
	}, "MIX!")
	paint("green")
	m.button = b
	b.Activated:Connect(function() task.spawn(doMix) end)

	-- press E in front of the station too
	local front = screen.CFrame.LookVector
	local pos = screen.Position + front * 4.5
	m.anchor = anchorPart("MixAnchor", CFrame.new(pos.X, FY + 3, pos.Z))
	local prompt = customPrompt(m.anchor, "MIX", "🧪 Chemistry Station")
	prompt.MaxActivationDistance = 12
	prompt.Triggered:Connect(function() task.spawn(doMix) end)
	mix = m
end
onRemoved.ChemistryStation = function()
	if mix then
		mix.gui:Destroy()
		mix.anchor:Destroy()
		mix = nil
	end
end

------------------------------------------------------------------------------------------
-- OXYGEN GENERATOR: the pump on its screen
------------------------------------------------------------------------------------------
local PUMP = LabConfig.Pump
local pump

local function pressureNow()
	local p = player:GetAttribute("LabPressure") or 0
	local at = player:GetAttribute("LabPressureAt") or now()
	return math.clamp(p - PUMP.Decay * (now() - at), 0, 1)
end

local function doPump()
	if not pump or pump.busy then return end
	pump.busy = true
	Kit.pop(pump.button, 0.88)
	Kit.pop(pump.gauge, 1.04)
	local r = invoke("pump")
	if r.ok and (r.burst or 0) > 0 then
		worldPop(pump.anchor, "BURST! +" .. fmt1(r.burst), Color3.fromRGB(130, 215, 255), "Oxygen")
		dust(pump.anchor.Position + Vector3.new(0, 3, 0), Color3.fromRGB(140, 220, 255))
		pump.fill.BackgroundColor3 = Color3.new(1, 1, 1)
		task.delay(0.2, function() if pump then pump.fill.BackgroundColor3 = Color3.fromRGB(90, 190, 255) end end)
	end
	task.wait(0.05)
	if pump then pump.busy = false end
end

onBuilt.OxygenGenerator = function(model)
	local screen = model:WaitForChild("Screen")
	local sg, bg = screenGui(screen, "LabPumpScreen")
	local m = { gui = sg }
	Kit.text(bg, {
		Text = "OXYGEN PUMP", Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.6, 0.17),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(130, 215, 255), Stroke = 3,
	})
	m.rate = Kit.text(bg, {
		Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.95, 0.06), Size = UDim2.fromScale(0.36, 0.12),
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(200, 230, 255), Stroke = 2,
	})
	m.gauge = Kit.new("Frame", {
		Name = "Gauge", Position = UDim2.fromScale(0.05, 0.27), Size = UDim2.fromScale(0.9, 0.22), BackgroundColor3 = Color3.fromRGB(28, 32, 44),
		ClipsDescendants = true,
	}, bg)
	Kit.corner(m.gauge, 0.3)
	Kit.stroke(m.gauge, 4, INK, true)
	m.fill = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(90, 190, 255), BorderSizePixel = 0 }, m.gauge)
	Kit.corner(m.fill, 0.3)
	Kit.gradient(m.fill, Color3.new(1, 1, 1), Color3.fromRGB(150, 170, 200))
	m.pct = Kit.text(m.gauge, {
		Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.75), ZIndex = 2, Stroke = 2.5,
	})
	Kit.text(bg, {
		Text = "Fill the gauge for an Oxygen burst!", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.9, 0.11), TextColor3 = Color3.fromRGB(220, 230, 245), Stroke = 2,
	})
	local b, paint = Kit.button(bg, {
		Name = "Pump", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.95), Size = UDim2.fromScale(0.5, 0.28),
	}, "PUMP!")
	paint("blue")
	m.button = b
	b.Activated:Connect(function() task.spawn(doPump) end)
	local front = screen.CFrame.LookVector
	local pos = screen.Position + front * 4.5
	m.anchor = anchorPart("PumpAnchor", CFrame.new(pos.X, FY + 3, pos.Z))
	local prompt = customPrompt(m.anchor, "PUMP", "💨 Oxygen Generator")
	prompt.Triggered:Connect(function() task.spawn(doPump) end)
	pump = m
end
onRemoved.OxygenGenerator = function()
	if pump then
		pump.gui:Destroy()
		pump.anchor:Destroy()
		pump = nil
	end
end

------------------------------------------------------------------------------------------
-- floating "+1/s" labels over the machines that make things on their own
------------------------------------------------------------------------------------------
local rateBoards = {} -- [id] = { label, fn }
local RATE_INFO = {
	ChemTanks = { cur = "Chemicals", rate = function() return LabConfig.Passive.Chemicals * LabConfig.chemMultiplier(player) end },
	OxygenGenerator = { cur = "Oxygen", rate = function() return LabConfig.Passive.Oxygen * LabConfig.oxygenMultiplier(player) end },
	CO2Extractor = { cur = "CarbonDioxide", rate = function() return LabConfig.Passive.CarbonDioxide * LabConfig.co2Multiplier(player) end },
}
for id, info in pairs(RATE_INFO) do
	local prev = onBuilt[id]
	onBuilt[id] = function(model)
		if prev then task.spawn(prev, model) end
		local cf, size = model:GetBoundingBox()
		local a = anchorPart("Rate_" .. id, CFrame.new(cf.Position + Vector3.new(0, size.Y / 2 + 1.2, 0)))
		local g = Kit.new("BillboardGui", {
			Size = UDim2.fromOffset(170, 34), MaxDistance = 70, LightInfluence = 0, Adornee = a, ResetOnSpawn = false,
		}, playerGui)
		local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, g)
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4),
		}, holder)
		local label = Kit.text(holder, {
			Text = "", Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = LabConfig.Currencies[info.cur].color, Stroke = 2.5,
		})
		currencyIcon(holder, info.cur, { Size = UDim2.fromScale(1, 1), SizeConstraint = Enum.SizeConstraint.RelativeYY, LayoutOrder = 2 })
		rateBoards[id] = { gui = g, anchor = a, label = label, rate = info.rate }
	end
	local prevR = onRemoved[id]
	onRemoved[id] = function()
		if prevR then prevR() end
		local r = rateBoards[id]
		if r then r.gui:Destroy() r.anchor:Destroy() rateBoards[id] = nil end
	end
end

------------------------------------------------------------------------------------------
-- POTION HOTBAR (like the drill hotbar): the potions you brewed. Pick one to hold it.
------------------------------------------------------------------------------------------
local SLOTS, SLOT, GAP = #LabConfig.Potions, 74, 7
local KEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine, Enum.KeyCode.Zero,
}
local hotGui = Kit.new("ScreenGui", { Name = "LabHotbar", ResetOnSpawn = false, DisplayOrder = 6, Enabled = false }, playerGui)
local bar = Kit.new("Frame", {
	Name = "Bar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.fromOffset(SLOTS * SLOT + (SLOTS - 1) * GAP, SLOT), BackgroundTransparency = 1,
}, hotGui)
Kit.new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder,
}, bar)
local barScale = Kit.new("UIScale", {}, bar)
local hint = Kit.text(hotGui, {
	Name = "Hint", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -SLOT - 18), Size = UDim2.fromOffset(560, 28),
	Text = "", Stroke = 2.5, TextColor3 = Color3.fromRGB(255, 240, 200),
})

local menuBar
task.spawn(function()
	local b = playerGui:WaitForChild("Buttons", 30)
	menuBar = b and b:WaitForChild("Container", 30)
end)
local function fit()
	local cam = workspace.CurrentCamera
	local width = cam and cam.ViewportSize.X or 1200
	local left = 16
	if menuBar and menuBar.Visible then
		left = math.max(left, menuBar.AbsolutePosition.X + menuBar.AbsoluteSize.X + 16)
	end
	if left > width * 0.6 then left = 16 end
	local room = width - left - 16
	local scale = math.clamp(room / bar.Size.X.Offset, 0.45, 1)
	barScale.Scale = scale
	local half = bar.Size.X.Offset * scale / 2
	local center = math.max(width / 2, left + half)
	bar.Position = UDim2.new(0, center, 1, -8)
	hint.Position = UDim2.new(0, center, 1, -SLOT * scale - 18)
end

local slots = {}
for i = 1, SLOTS do
	local b = Kit.new("TextButton", {
		Name = "Slot" .. i, LayoutOrder = i, Size = UDim2.fromOffset(SLOT, SLOT), Text = "", AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(38, 40, 44), BackgroundTransparency = 0.25, Visible = false,
	}, bar)
	b:SetAttribute("NoTween", true) -- has its own hover
	Kit.corner(b, 0.16)
	local stroke = Kit.stroke(b, 3, INK, true)
	Kit.text(b, { Text = i == 10 and "0" or tostring(i), Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(14, 15), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
	local count = Kit.text(b, {
		Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 3), Size = UDim2.fromOffset(36, 16),
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5, TextColor3 = Color3.fromRGB(255, 230, 120),
	})
	local flask, setColor = flaskIcon(b, Color3.new(1, 1, 1), {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.1), Size = UDim2.fromScale(0.62, 0.62), ZIndex = 2,
	})
	local rarity = Kit.text(b, {
		Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(0.94, 0, 0, 16), ZIndex = 5,
	})
	local sc = Kit.new("UIScale", {}, b)
	b.MouseEnter:Connect(function() TweenService:Create(sc, TweenInfo.new(0.1), { Scale = 1.06 }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(sc, TweenInfo.new(0.1), { Scale = 1 }):Play() end)
	slots[i] = { button = b, stroke = stroke, count = count, rarity = rarity, flask = flask, setColor = setColor }
end

local selectedPotion
local held -- the flask in your hand
local function dropHeld()
	if held then held:Destroy() held = nil end
end
local function holdPotion(potion)
	dropHeld()
	local character = player.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if not (potion and hand) then return end
	local m = Instance.new("Model")
	m.Name = "HeldPotion"
	local function p(name, shape, size, color, mat, alpha, offset)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = shape
		part.Size = size
		part.Color = color
		part.Material = mat
		part.Transparency = alpha
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		part.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.35, -0.1) * offset
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = hand, part
		w.Parent = part
		part.Parent = m
		return part
	end
	p("Glass", Enum.PartType.Ball, Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(220, 240, 255), Enum.Material.Glass, 0.55, CFrame.new())
	local liquid = p("Liquid", Enum.PartType.Ball, Vector3.new(0.72, 0.72, 0.72), potion.color, Enum.Material.Neon, 0.1, CFrame.new(0, -0.04, 0))
	p("Neck", Enum.PartType.Cylinder, Vector3.new(0.5, 0.3, 0.3), Color3.fromRGB(220, 240, 255), Enum.Material.Glass, 0.45, CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)))
	p("Cork", Enum.PartType.Cylinder, Vector3.new(0.2, 0.26, 0.26), Color3.fromRGB(170, 110, 60), Enum.Material.Wood, 0, CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local light = Instance.new("PointLight")
	light.Color = potion.color
	light.Range = 6
	light.Brightness = 1.2
	light.Parent = liquid
	m.Parent = character
	held = m
end

local inLab = false
local refreshHotbar
local function select(potionId)
	selectedPotion = selectedPotion ~= potionId and potionId or nil
	holdPotion(selectedPotion and LabConfig.PotionById[selectedPotion])
	refreshHotbar()
end

refreshHotbar = function()
	local bag = LabConfig.potions(player)
	local list = {}
	for id, n in pairs(bag) do
		if n > 0 and LabConfig.PotionById[id] then table.insert(list, LabConfig.PotionById[id]) end
	end
	table.sort(list, function(a, b) return a.index > b.index end) -- rarest first
	if selectedPotion and not (bag[selectedPotion] and bag[selectedPotion] > 0) then
		selectedPotion = nil
		dropHeld()
	end
	local totalValue, totalCount = 0, 0
	for i, s in ipairs(slots) do
		local potion = list[i]
		s.potion = potion
		s.button.Visible = potion ~= nil
		if potion then
			local rc = LabConfig.Rarities[potion.rarity]
			s.setColor(potion.color)
			s.count.Text = "x" .. bag[potion.id]
			s.rarity.Text = potion.rarity
			s.rarity.TextColor3 = rc
			local on = selectedPotion == potion.id
			s.button.BackgroundTransparency = on and 0.05 or 0.25
			s.button.BackgroundColor3 = on and rc:Lerp(Color3.fromRGB(40, 40, 50), 0.55) or Color3.fromRGB(38, 40, 44)
			s.stroke.Color = on and Color3.new(1, 1, 1) or rc:Lerp(INK, 0.35)
			s.stroke.Thickness = on and 3.5 or 3
		end
	end
	for id, n in pairs(bag) do
		local p = LabConfig.PotionById[id]
		if p then
			totalValue += p.value * n
			totalCount += n
		end
	end
	if selectedPotion then
		local p = LabConfig.PotionById[selectedPotion]
		hint.Text = p.name .. "  -  " .. p.rarity .. "  -  worth " .. abbreviate(p.value * LabConfig.sellMultiplier(player)) .. " Knowledge each"
	elseif totalCount > 0 then
		hint.Text = totalCount .. " potions (" .. abbreviate(totalValue * LabConfig.sellMultiplier(player)) .. " Knowledge) - sell them at the Potion Stand!"
	elseif LabConfig.owns(player, "PotionBrewer") then
		hint.Text = "Brew potions at the Potion Brewer!"
	elseif not LabConfig.owns(player, "ChemistryStation") then
		hint.Text = "Step on the red button to start your lab!"
	else
		hint.Text = "Make Chemicals and build the lab with the red buttons!"
	end
end

for _, s in ipairs(slots) do
	s.button.Activated:Connect(function()
		if s.potion then
			Kit.pop(s.button, 0.88)
			select(s.potion.id)
		end
	end)
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inLab then return end
	for i, key in ipairs(KEYS) do
		if input.KeyCode == key then
			local s = slots[i]
			if s and s.potion then
				Kit.pop(s.button, 0.88)
				select(s.potion.id)
			end
			return
		end
	end
end)
player.CharacterAdded:Connect(function()
	held = nil
	selectedPotion = nil
	if refreshHotbar then refreshHotbar() end
end)

local function setCoreBackpack(on)
	for _ = 1, 5 do
		local ok = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, on) end)
		if ok then return end
		task.wait(0.5)
	end
end

------------------------------------------------------------------------------------------
-- POTION BREWER menu
------------------------------------------------------------------------------------------
local brewer = Kit.glass("LabBrewer", "POTION BREWER", { aspect = 1.7, tint = Color3.fromRGB(210, 220, 245) })
local brewBody = brewer.body
local brewCards = {}
local oddsFor = "Basic"
local revealing = false

local left = Kit.new("Frame", { Name = "Brews", Size = UDim2.fromScale(0.56, 1), BackgroundTransparency = 1 }, brewBody)
Kit.new("UIListLayout", { Padding = UDim.new(0.04, 0), SortOrder = Enum.SortOrder.LayoutOrder }, left)
local right = Kit.new("Frame", {
	Name = "Odds", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.41, 1),
	BackgroundColor3 = Color3.fromRGB(20, 26, 40), BackgroundTransparency = 0.15,
}, brewBody)
Kit.corner(right, 0.06)
Kit.stroke(right, 4, INK, true)
local oddsTitle = Kit.text(right, {
	Text = "CHANCES", Position = UDim2.fromScale(0.05, 0.02), Size = UDim2.fromScale(0.9, 0.09), Stroke = 3, TextColor3 = Color3.fromRGB(255, 225, 120),
})
local luckText = Kit.text(right, {
	Text = "", Position = UDim2.fromScale(0.05, 0.11), Size = UDim2.fromScale(0.9, 0.06), Stroke = 2, TextColor3 = Color3.fromRGB(140, 255, 150),
})
local oddsList = Kit.new("ScrollingFrame", {
	Position = UDim2.fromScale(0.04, 0.19), Size = UDim2.fromScale(0.92, 0.79), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, right)
Kit.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, oddsList)
local oddsRows = {}
for i, p in ipairs(LabConfig.Potions) do
	local row = Kit.new("Frame", {
		LayoutOrder = -i, Size = UDim2.new(1, -8, 0, 34), BackgroundColor3 = LabConfig.Rarities[p.rarity], BackgroundTransparency = 0.8,
	}, oddsList)
	Kit.corner(row, 0.25)
	flaskIcon(row, p.color, { Position = UDim2.fromOffset(4, 1), Size = UDim2.new(0, 32, 0, 32) })
	Kit.text(row, {
		Text = p.name, Position = UDim2.new(0, 40, 0, 2), Size = UDim2.new(0.6, -40, 0, 18), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = LabConfig.Rarities[p.rarity], Stroke = 2,
	})
	Kit.text(row, {
		Text = p.rarity .. " - " .. abbreviate(p.value) .. " Knowledge", Position = UDim2.new(0, 40, 0, 19), Size = UDim2.new(0.6, -40, 0, 13),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(215, 220, 230), Stroke = 1.5,
	})
	local pct = Kit.text(row, {
		Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.new(0.36, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Right, Stroke = 2,
	})
	oddsRows[p.id] = { row = row, pct = pct }
end

local function pctText(x)
	if x <= 0 then return "-" end
	local v = x * 100
	if v >= 10 then return string.format("%.1f%%", v) end
	if v >= 1 then return string.format("%.2f%%", v) end
	if v >= 0.01 then return string.format("%.3f%%", v) end
	return "1 in " .. abbreviate(1 / x)
end

local function refreshOdds()
	local brew = LabConfig.BrewById[oddsFor]
	local odds = LabConfig.odds(player, brew)
	oddsTitle.Text = brew.name:upper() .. " CHANCES"
	luckText.Text = "Luck x" .. fmt1(LabConfig.luck(player, brew))
	for id, r in pairs(oddsRows) do
		local x = odds[id] or 0
		r.pct.Text = pctText(x)
		r.row.Visible = x > 0
		r.pct.TextColor3 = x > 0 and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 160)
	end
	for id, c in pairs(brewCards) do
		c.stroke.Color = id == oddsFor and Color3.fromRGB(255, 230, 110) or INK
		c.stroke.Thickness = id == oddsFor and 5 or 4
	end
end

local doBrew
for i, brew in ipairs(LabConfig.Brews) do
	local card = Kit.new("TextButton", {
		Name = brew.id, LayoutOrder = i, Size = UDim2.fromScale(1, 0.48), Text = "", AutoButtonColor = false,
		BackgroundColor3 = i == 1 and Color3.fromRGB(40, 110, 70) or Color3.fromRGB(70, 55, 120),
	}, left)
	card:SetAttribute("NoTween", true)
	Kit.corner(card, 0.1)
	local stroke = Kit.stroke(card, 4, INK, true)
	Kit.gradient(card, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 165))
	flaskIcon(card, i == 1 and Color3.fromRGB(120, 235, 120) or Color3.fromRGB(190, 110, 255), {
		Position = UDim2.fromScale(0.03, 0.1), Size = UDim2.fromScale(0.26, 0.8),
	})
	Kit.text(card, {
		Text = brew.name, Position = UDim2.fromScale(0.3, 0.07), Size = UDim2.fromScale(0.45, 0.24), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3,
	})
	local sub = Kit.text(card, {
		Text = brew.noCommon and "No Commons! x" .. brew.luck .. " luck" or "x" .. brew.luck .. " luck", Position = UDim2.fromScale(0.3, 0.31),
		Size = UDim2.fromScale(0.45, 0.14), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 230, 120), Stroke = 2,
	})
	local costs = Kit.new("Frame", { Position = UDim2.fromScale(0.3, 0.52), Size = UDim2.fromScale(0.44, 0.36), BackgroundTransparency = 1 }, card)
	Kit.new("UIListLayout", { Padding = UDim.new(0.06, 0), SortOrder = Enum.SortOrder.LayoutOrder }, costs)
	local costLabels = {}
	for j, cur in ipairs(CUR_ORDER) do
		local amount = brew.cost[cur]
		if amount then
			local line = Kit.new("Frame", { LayoutOrder = j, Size = UDim2.fromScale(1, 0.3), BackgroundTransparency = 1 }, costs)
			currencyIcon(line, cur, { Size = UDim2.fromScale(1, 1), SizeConstraint = Enum.SizeConstraint.RelativeYY })
			costLabels[cur] = Kit.text(line, {
				Text = "", Position = UDim2.new(0.16, 0, 0, 0), Size = UDim2.fromScale(0.84, 1), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2,
			})
		end
	end
	local b, paint, label = Kit.button(card, {
		Name = "Brew", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.97, 0.62), Size = UDim2.fromScale(0.22, 0.4),
	}, "BREW")
	local lock = Kit.text(card, {
		Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.97, 0.08), Size = UDim2.fromScale(0.3, 0.2),
		TextColor3 = Color3.fromRGB(255, 140, 140), Stroke = 2,
	})
	brewCards[brew.id] = { card = card, stroke = stroke, button = b, paint = paint, label = label, costLabels = costLabels, lock = lock, sub = sub }
	card.Activated:Connect(function()
		oddsFor = brew.id
		refreshOdds()
	end)
	card.MouseEnter:Connect(function()
		oddsFor = brew.id
		refreshOdds()
	end)
	b.Activated:Connect(function()
		oddsFor = brew.id
		refreshOdds()
		doBrew(brew.id)
	end)
end

local function refreshBrewer()
	if not brewer.isOpen() then return end
	for id, c in pairs(brewCards) do
		local brew = LabConfig.BrewById[id]
		local unlocked = LabConfig.owns(player, brew.needs)
		local affordable = true
		for cur, amount in pairs(brew.cost) do
			local ok = have(cur) >= amount
			affordable = affordable and ok
			c.costLabels[cur].Text = abbreviate(amount) .. "  (" .. abbreviate(have(cur)) .. ")"
			c.costLabels[cur].TextColor3 = ok and Color3.new(1, 1, 1) or Color3.fromRGB(255, 120, 120)
		end
		c.lock.Text = unlocked and "" or "Build the " .. LabConfig.Items[brew.needs].name .. "!"
		c.label.Text = unlocked and (revealing and "..." or "BREW") or "LOCKED"
		c.paint(unlocked and affordable and not revealing and "green" or "grey")
	end
	refreshOdds()
end

-- the reveal: flasks flicker through potions and land on what you got
local overlay = Kit.new("TextButton", {
	Name = "Reveal", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 10, 18), BackgroundTransparency = 0.15,
	Text = "", AutoButtonColor = false, Visible = false, ZIndex = 20,
}, brewer.panel)
overlay:SetAttribute("NoTween", true)
Kit.corner(overlay, 0.045)
local burstHolder = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20 }, overlay)
Kit.corner(burstHolder, 0.045)
local burst = Kit.sunburst(burstHolder, Color3.new(1, 1, 1))
for _, d in ipairs(burst:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex = 20 end end
burst.ZIndex = 20
local revealFlask, revealColor = flaskIcon(overlay, Color3.new(1, 1, 1), {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.36, 0.36), ZIndex = 22,
})
for _, d in ipairs(revealFlask:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex += 21 end end
local revealName = Kit.text(overlay, {
	Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.63), Size = UDim2.fromScale(0.8, 0.11), ZIndex = 30, Stroke = 3.5,
})
local revealRarity = Kit.text(overlay, {
	Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.74), Size = UDim2.fromScale(0.6, 0.07), ZIndex = 30, Stroke = 2.5,
})
local revealRow = Kit.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.97), Size = UDim2.fromScale(0.9, 0.12), BackgroundTransparency = 1, ZIndex = 30,
}, overlay)
Kit.new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6),
}, revealRow)
local revealTitle = Kit.text(overlay, {
	Text = "BREWING...", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.05), Size = UDim2.fromScale(0.6, 0.1), ZIndex = 30, Stroke = 3.5,
})
local skip = false
overlay.Activated:Connect(function() skip = true end)

local function showPotion(p)
	revealColor(p.color)
	revealName.Text = p.name
	revealName.TextColor3 = LabConfig.Rarities[p.rarity]
	revealRarity.Text = p.rarity .. "  -  " .. abbreviate(p.value) .. " Knowledge"
	revealRarity.TextColor3 = LabConfig.Rarities[p.rarity]
end

local RARE_RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Godly = 7 }

local function reveal(brew, ids)
	revealing = true
	skip = false
	overlay.Visible = true
	burst.Visible = false
	revealRow:ClearAllChildren()
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6),
	}, revealRow)
	local odds = LabConfig.odds(player, brew)
	local pool = {}
	for _, p in ipairs(LabConfig.Potions) do
		if odds[p.id] > 0 then table.insert(pool, p) end
	end
	for n, id in ipairs(ids) do
		local final = LabConfig.PotionById[id]
		revealTitle.Text = #ids > 1 and ("BREWING... (" .. n .. "/" .. #ids .. ")") or "BREWING..."
		burst.Visible = false
		local steps = n == 1 and 16 or 9
		for s = 1, steps do
			if skip then break end
			showPotion(pool[math.random(1, #pool)])
			Kit.pop(revealFlask, 1.08)
			task.wait(0.03 + (s / steps) ^ 2 * 0.16)
		end
		showPotion(final)
		revealTitle.Text = "YOU GOT..."
		Kit.pop(revealFlask, 1.5)
		Kit.pop(revealName, 1.4)
		local rank = RARE_RANK[final.rarity] or 1
		if rank >= 3 then
			burst.Visible = true
			for _, d in ipairs(burst:GetChildren()) do
				if d:IsA("Frame") then d.BackgroundColor3 = LabConfig.Rarities[final.rarity] end
			end
		end
		if rank >= 5 then
			toast(final.rarity:upper() .. " POTION!", LabConfig.Rarities[final.rarity], nil, true)
		end
		local mini = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundTransparency = 1, ZIndex = 30 }, revealRow)
		local f = flaskIcon(mini, final.color, { ZIndex = 31 })
		for _, d in ipairs(f:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex += 30 end end
		Kit.pop(mini, 1.4)
		local waitFor = skip and 0.25 or (rank >= 4 and 1.1 or 0.7)
		skip = false
		task.wait(waitFor)
	end
	revealTitle.Text = "Click to continue"
	local t = os.clock()
	while not skip and os.clock() - t < 1.6 and brewer.isOpen() do task.wait(0.05) end
	overlay.Visible = false
	revealing = false
	refreshBrewer()
end

doBrew = function(brewId)
	if revealing then return end
	local brew = LabConfig.BrewById[brewId]
	if not LabConfig.owns(player, brew.needs) then
		toast("Build the " .. LabConfig.Items[brew.needs].name .. " first!", Color3.fromRGB(255, 120, 120))
		return
	end
	for _, cur in ipairs(CUR_ORDER) do
		local amount = brew.cost[cur]
		if amount and have(cur) < amount then
			toast("Not enough " .. (LabConfig.Currencies[cur].short or cur) .. "!", Color3.fromRGB(255, 120, 120))
			return
		end
	end
	revealing = true
	refreshBrewer()
	local r = invoke("brew", brewId)
	if r.ok and r.potions then
		if built.PotionBrewer then
			local brewPart = built.PotionBrewer:FindFirstChild("Brew")
			if brewPart then dust(brewPart.Position + Vector3.new(0, 2, 0), LabConfig.PotionById[r.potions[1]].color) end
		end
		reveal(brew, r.potions)
	else
		revealing = false
		refreshBrewer()
		if r.reason == "cost" then toast("Not enough " .. tostring(r.missing) .. "!", Color3.fromRGB(255, 120, 120)) end
	end
end

brewer.onOpen = function()
	oddsFor = LabConfig.owns(player, "AdvancedBrewer") and "Advanced" or "Basic"
	refreshBrewer()
end

local brewAnchor
onBuilt.PotionBrewer = function(model)
	local a = model:WaitForChild("PromptAnchor")
	brewAnchor = a
	local prompt = customPrompt(a, "BREW", "⚗️ Potion Brewer")
	prompt.Triggered:Connect(function() brewer.open() end)
end
onRemoved.PotionBrewer = function()
	brewAnchor = nil
	brewer.hide()
end
Kit.closeWhenFar(brewer, function() return brewAnchor and brewAnchor.Position end, 16)

------------------------------------------------------------------------------------------
-- KNOWLEDGE SHOP
------------------------------------------------------------------------------------------
local shop = Kit.glass("LabKnowledgeShop", "KNOWLEDGE SHOP", { aspect = 1.7, tint = Color3.fromRGB(240, 215, 240) })
-- your Knowledge, on a tab above the window's top-left corner
local balance = Kit.new("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.02, 0, 0, -6), Size = UDim2.fromScale(0.22, 0.085),
	BackgroundColor3 = Color3.fromRGB(30, 20, 40), BackgroundTransparency = 0.1,
}, shop.holder)
Kit.corner(balance, 0.4)
Kit.stroke(balance, 3, INK, true)
currencyIcon(balance, "Knowledge", { Position = UDim2.fromScale(0.03, 0.05), Size = UDim2.fromScale(0.9, 0.9), SizeConstraint = Enum.SizeConstraint.RelativeYY })
local balanceText = Kit.text(balance, {
	Text = "", Position = UDim2.fromScale(0.3, 0.1), Size = UDim2.fromScale(0.66, 0.8), TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = LabConfig.Currencies.Knowledge.color, Stroke = 2.5,
})
local grid = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, shop.body)
Kit.new("UIGridLayout", {
	CellSize = UDim2.fromScale(0.315, 0.47), CellPadding = UDim2.fromScale(0.027, 0.05), SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, grid)

local function effectText(u, lvl)
	if u.id == "LuckyBrew" then return "x" .. string.format("%.2f", 1.25 ^ lvl) .. " luck" end
	if u.id == "BulkBrew" then return (1 + lvl) .. (lvl == 0 and " potion" or " potions") .. " per brew" end
	return "+" .. math.floor(lvl * u.per * 100 + 0.5) .. "%"
end

local shopCards = {}
for i, u in ipairs(LabConfig.Upgrades) do
	local card = Kit.new("Frame", { LayoutOrder = i, BackgroundColor3 = Color3.fromRGB(45, 30, 70) }, grid)
	Kit.corner(card, 0.1)
	Kit.stroke(card, 4, INK, true)
	Kit.gradient(card, Color3.new(1, 1, 1), Color3.fromRGB(160, 150, 175))
	Kit.text(card, { Text = u.icon, Position = UDim2.fromScale(0.04, 0.05), Size = UDim2.fromScale(0.22, 0.3), Stroke = 0 })
	Kit.text(card, {
		Text = u.name, Position = UDim2.fromScale(0.28, 0.05), Size = UDim2.fromScale(0.68, 0.17), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2.5,
	})
	Kit.text(card, {
		Text = u.desc, Position = UDim2.fromScale(0.28, 0.22), Size = UDim2.fromScale(0.68, 0.12), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(215, 205, 235), Stroke = 2,
	})
	local levelBar = Kit.new("Frame", {
		Position = UDim2.fromScale(0.06, 0.41), Size = UDim2.fromScale(0.88, 0.1), BackgroundColor3 = Color3.fromRGB(25, 20, 35), ClipsDescendants = true,
	}, card)
	Kit.corner(levelBar, 0.5)
	Kit.stroke(levelBar, 2.5, INK, true)
	local levelFill = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = LabConfig.Currencies.Knowledge.color, BorderSizePixel = 0 }, levelBar)
	Kit.corner(levelFill, 0.5)
	local levelText = Kit.text(levelBar, {
		Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.9), ZIndex = 2, Stroke = 2,
	})
	local effect = Kit.text(card, {
		Text = "", Position = UDim2.fromScale(0.06, 0.54), Size = UDim2.fromScale(0.88, 0.12), TextColor3 = Color3.fromRGB(150, 255, 160), Stroke = 2,
	})
	local b, paint, label = Kit.button(card, {
		Name = "Buy", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.95), Size = UDim2.fromScale(0.8, 0.24),
	}, "")
	label.Size = UDim2.fromScale(0.62, 0.7)
	label.Position = UDim2.fromScale(0.58, 0.5)
	local icon = currencyIcon(b, "Knowledge", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.08, 0.5), Size = UDim2.fromScale(0.8, 0.8), SizeConstraint = Enum.SizeConstraint.RelativeYY,
	})
	shopCards[u.id] = { card = card, levelFill = levelFill, levelText = levelText, effect = effect, button = b, paint = paint, label = label, icon = icon }
	b.Activated:Connect(function()
		local r = invoke("upgrade", u.id)
		if r.ok then
			Kit.pop(card, 1.08)
			toast(u.name .. " Lv " .. r.level .. "!", Color3.fromRGB(150, 255, 160))
		elseif r.reason == "cost" then
			toast("Not enough Knowledge!", Color3.fromRGB(255, 120, 120))
		end
	end)
end

local function refreshShop()
	balanceText.Text = abbreviate(have("Knowledge"))
	for _, u in ipairs(LabConfig.Upgrades) do
		local c = shopCards[u.id]
		local lvl = LabConfig.level(player, u.id)
		c.levelFill.Size = UDim2.fromScale(lvl / u.max, 1)
		c.levelText.Text = "Lv " .. lvl .. " / " .. u.max
		c.effect.Text = "Now: " .. effectText(u, lvl)
		if lvl >= u.max then
			c.label.Text = "MAXED"
			c.label.Position = UDim2.fromScale(0.5, 0.5)
			c.icon.Visible = false
			c.paint("gold")
		else
			local cost = LabConfig.upgradeCost(u.id, lvl)
			c.label.Text = abbreviate(cost)
			c.label.Position = UDim2.fromScale(0.58, 0.5)
			c.icon.Visible = true
			c.paint(have("Knowledge") >= cost and "green" or "grey")
		end
	end
end
shop.onOpen = refreshShop

------------------------------------------------------------------------------------------
-- the Potion Stand (sell) and the Knowledge Shop stall (in Workspace.Labratory)
------------------------------------------------------------------------------------------
local selling = false
local function sell(prompt)
	if selling then return end
	selling = true
	local r = invoke("sell")
	if r.ok then
		toast("+" .. abbreviate(r.knowledge), LabConfig.Currencies.Knowledge.color, "Knowledge", true)
		if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then
			dust(prompt.Parent.Position + Vector3.new(0, 2, 0), LabConfig.Currencies.Knowledge.color)
			worldPop(prompt.Parent, "Sold " .. r.count .. " potions!", Color3.fromRGB(255, 240, 160))
		end
	elseif r.reason == "empty" then
		toast(LabConfig.owns(player, "PotionBrewer") and "No potions! Brew some at the Potion Brewer." or "No potions yet! Build the Potion Brewer first.", Color3.fromRGB(255, 190, 120))
	end
	task.wait(0.4)
	selling = false
end

local shopPromptPart
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local opens = prompt:GetAttribute("Opens")
	if opens == "PotionStand" then
		task.spawn(sell, prompt)
	elseif opens == "KnowledgeShop" then
		shopPromptPart = prompt.Parent
		shop.open()
	end
end)
Kit.closeWhenFar(shop, function() return shopPromptPart and shopPromptPart:IsA("BasePart") and shopPromptPart.Position end, 18)

------------------------------------------------------------------------------------------
-- SYNC with your saved data
------------------------------------------------------------------------------------------
local firstSync = true
local function sync()
	for _, id in ipairs(LabConfig.Order) do
		if LabConfig.owns(player, id) then
			if buttons[id] then removeButton(id, not firstSync) end
			renderItem(id, not firstSync)
		else
			removeItem(id, not firstSync)
			if LabConfig.available(player, id) then
				addButton(id, not firstSync)
			else
				removeButton(id, false)
			end
		end
	end
	firstSync = false
	refreshHotbar()
	refreshBrewer()
end

local function onCurrency()
	paintButtons()
	refreshBrewer()
	if shop.isOpen() then refreshShop() end
end

for _, id in ipairs(LabConfig.Order) do
	player:GetAttributeChangedSignal(LabConfig.ownedAttribute(id)):Connect(sync)
end
for _, info in pairs(LabConfig.Currencies) do
	player:GetAttributeChangedSignal(info.attr):Connect(onCurrency)
end
for _, u in ipairs(LabConfig.Upgrades) do
	player:GetAttributeChangedSignal(LabConfig.upgradeAttribute(u.id)):Connect(function()
		if shop.isOpen() then refreshShop() end
		refreshBrewer()
		refreshHotbar()
	end)
end
player:GetAttributeChangedSignal("LabPotions"):Connect(function() refreshHotbar() end)
for _, attr in ipairs({ "LabLevel", "LabMark" }) do
	player:GetAttributeChangedSignal(attr):Connect(function()
		refreshHotbar()
		refreshBrewer()
		if shop.isOpen() then refreshShop() end
	end)
end

------------------------------------------------------------------------------------------
-- every frame
------------------------------------------------------------------------------------------
local accum = 0
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local near = (camPos - LabConfig.Bounds.center).Magnitude < 260

	if near then
		for _, s in ipairs(spinners) do
			if s.model.Parent then
				local a = t * s.speed
				local rot = s.axis == "Z" and CFrame.Angles(0, 0, a) or CFrame.Angles(0, a, 0)
				local bob = s.bob and CFrame.new(0, math.sin(t * 1.6) * 0.6, 0) or CFrame.identity
				s.model:PivotTo(s.base * bob * rot)
			end
		end

		-- the mixing screen
		if mix then
			local zone = player:GetAttribute("LabMixZone") or 0.5
			local width = player:GetAttribute("LabMixWidth") or MIX.Zone[1]
			mix.zone.Position = UDim2.fromScale(zone, 0.5)
			mix.zone.Size = UDim2.fromScale(width, 0.84)
			local pos = t < mix.freezeUntil and mix.freezePos or markerNow()
			mix.marker.Position = UDim2.fromScale(pos, 0.5)
		end
		if pump then
			local p = pressureNow()
			pump.fill.Size = UDim2.fromScale(p, 1)
			pump.pct.Text = "PRESSURE " .. math.floor(p * 100) .. "%"
		end
	end

	accum += dt
	if accum < 0.25 then return end
	accum = 0

	if mix then
		local streak = player:GetAttribute("LabStreak") or 0
		mix.streak.Text = streak > 0 and ("STREAK " .. streak .. "  x" .. fmt1(1 + streak * LabConfig.streakStep(player))) or ""
		mix.per.Text = "+" .. fmt1(mixGain(streak + (streak < MIX.StreakMax and 1 or 0), false)) .. " per mix   |   PERFECT (yellow) = x" .. MIX.PerfectBonus
	end
	if pump then
		pump.rate.Text = "+" .. fmt1(LabConfig.Passive.Oxygen * LabConfig.oxygenMultiplier(player)) .. " O2/s"
	end
	for _, r in pairs(rateBoards) do
		r.label.Text = "+" .. fmt1(r.rate()) .. "/s"
	end

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local nowIn = root ~= nil and LabConfig.isInside(root.Position)
	if nowIn ~= inLab then
		inLab = nowIn
		hotGui.Enabled = nowIn
		task.spawn(setCoreBackpack, not nowIn)
		if not nowIn then
			selectedPotion = nil
			dropHeld()
			brewer.hide()
			shop.hide()
		end
		refreshHotbar()
	end
	if hotGui.Enabled ~= inLab then hotGui.Enabled = inLab end
	if inLab then fit() end
end)

if player:GetAttribute("DataLoaded") ~= true then
	player:GetAttributeChangedSignal("DataLoaded"):Wait()
end
sync()
