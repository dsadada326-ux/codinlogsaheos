-- THE LABORATORY: Staff Wing, Lab Shop and Marks menu (client).
--   * the Staff Wing: your workers and decor, each building itself in part by part when bought
--     and flying apart when an Advancement Mark resets them
--   * the Lab Shop (kiosk in the Staff Wing): hire staff and buy decor, currencies on the top bar
--   * the Marks menu (prompt at the Advancement Marks board): every mark, its bonuses and progress
-- LabService checks the real rules. Tuning: ReplicatedStorage.LabConfig (Staff, Decor, Marks).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LabConfig = require(ReplicatedStorage:WaitForChild("LabConfig"))
local Kit = require(ReplicatedStorage:WaitForChild("FishingUIKit"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local assets = ReplicatedStorage:WaitForChild("LabAssets")
local staffTemplates = assets:WaitForChild("Staff")
local decorTemplates = assets:WaitForChild("Decor")
local actionRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LabAction")

local FY = LabConfig.StaffWing.center.Y -- the Staff Wing floor
local CURRENCIES = { "Chemicals", "Oxygen", "CarbonDioxide", "Knowledge" }

local function abbreviate(n)
	return NumberFormat.abbreviate(math.floor(n + 0.5))
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
local function fmt(n)
	return (string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", ""))
end

local folder = Instance.new("Folder")
folder.Name = "LabStaffClient"
folder.Parent = workspace

------------------------------------------------------------------------------------------
-- LOOK: dark panels, Montserrat, purple accents
------------------------------------------------------------------------------------------
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
local FONT_HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Black)
local BG = Color3.fromRGB(14, 14, 16)
local LINE = Color3.fromRGB(70, 30, 150)
local ACCENT = Color3.fromRGB(120, 40, 255)
local ACCENT_2 = Color3.fromRGB(80, 20, 200)
local SOFT = Color3.fromRGB(225, 225, 232)
local DIM = Color3.fromRGB(140, 140, 155)

local function new(class, props, parent)
	return Kit.new(class, props, parent)
end
local function corner(obj, r)
	return new("UICorner", { CornerRadius = UDim.new(r or 0, r and 0 or 4) }, obj)
end
local function stroke(obj, color, thickness, transparency)
	return new("UIStroke", {
		Color = color, Thickness = thickness or 1.5, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, obj)
end
local function text(parent, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, FontFace = FONT, TextScaled = true, TextColor3 = SOFT, Text = "",
	})
	local max = props.Max
	local shadow = props.Shadow
	props.Max, props.Shadow = nil, nil
	for k, v in pairs(props) do l[k] = v end
	if max then new("UITextSizeConstraint", { MaxTextSize = max }, l) end
	if shadow then
		new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = shadow, Transparency = 0.35 }, l)
	end
	l.Parent = parent
	return l
end
-- a colour fade across text or a frame
local function fade(obj, a, b, rotation)
	return new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rotation or 0 }, obj)
end
local function hover(button)
	local s = new("UIScale", { Name = "Hover" }, button)
	button.MouseEnter:Connect(function() TweenService:Create(s, TweenInfo.new(0.12), { Scale = 1.04 }):Play() end)
	button.MouseLeave:Connect(function() TweenService:Create(s, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
	button.MouseButton1Down:Connect(function() TweenService:Create(s, TweenInfo.new(0.07), { Scale = 0.95 }):Play() end)
	button.MouseButton1Up:Connect(function() TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1.04 }):Play() end)
	button:SetAttribute("NoTween", true)
	return s
end
local function pop(obj, from)
	Kit.pop(obj, from)
end

-- currency icons, borrowed from the currency list on the right of the screen
local function currencyIcon(parent, cur, props)
	local info = LabConfig.Currencies[cur]
	local icon
	if info.icon ~= "" then
		icon = Kit.image(parent, { Image = info.icon })
	else
		local row = playerGui:WaitForChild("Currencies", 10)
		row = row and row:WaitForChild("MainCurrenciesFrame", 5)
		row = row and row:WaitForChild("CurrenciesFrame", 5)
		row = row and row:WaitForChild(cur, 5)
		local src = row and row:FindFirstChild("Icon")
		if src then
			icon = src:Clone()
			icon.Parent = parent
		else
			icon = text(parent, { Text = info.short or cur:sub(1, 2), TextColor3 = info.color })
		end
	end
	icon.Name = "CurrencyIcon"
	icon.AnchorPoint = Vector2.zero
	icon.Position = UDim2.new()
	for k, v in pairs(props or {}) do icon[k] = v end
	if not icon:FindFirstChildOfClass("UIAspectRatioConstraint") then
		new("UIAspectRatioConstraint", { AspectRatio = 1 }, icon)
	end
	return icon
end

------------------------------------------------------------------------------------------
-- a dark menu window: header with a gradient title, a sidebar list on the left, content on the right
------------------------------------------------------------------------------------------
local openCount = 0
local function blur(on)
	local b = Lighting:FindFirstChild("LabMenuBlur")
	if not b then
		b = new("BlurEffect", { Name = "LabMenuBlur", Size = 0 }, Lighting)
	end
	TweenService:Create(b, TweenInfo.new(0.25), { Size = on and 14 or 0 }):Play()
end

local windows = {}
local function darkWindow(name, title)
	local gui = new("ScreenGui", { Name = name, ResetOnSpawn = false, DisplayOrder = 22, Enabled = false, IgnoreGuiInset = true }, playerGui)
	local holder = new("Frame", {
		Name = "Holder", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.72, 0.74),
		BackgroundColor3 = BG, BorderSizePixel = 0,
	}, gui)
	new("UIAspectRatioConstraint", { AspectRatio = 1.95 }, holder)
	new("UISizeConstraint", { MaxSize = Vector2.new(1180, 605) }, holder)
	corner(holder, 0.018)
	local edge = stroke(holder, Color3.new(1, 1, 1), 2)
	fade(edge, Color3.fromRGB(150, 70, 255), Color3.fromRGB(40, 15, 90), 35)
	local scale = new("UIScale", { Name = "OpenScale" }, holder)

	-- header
	local header = new("Frame", { Name = "Header", Size = UDim2.fromScale(1, 0.15), BackgroundTransparency = 1 }, holder)
	local titleLabel = text(header, {
		Name = "Title", Text = title, FontFace = FONT_HEAVY, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.035, 0.52),
		Size = UDim2.fromScale(0.3, 0.62), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.new(1, 1, 1), Shadow = 2.5,
	})
	fade(titleLabel, Color3.fromRGB(150, 60, 255), Color3.fromRGB(80, 20, 210), 90)
	local divider = new("Frame", {
		Name = "Divider", Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = LINE, BorderSizePixel = 0,
	}, header)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) }) }, divider)

	-- close button (top right)
	local close = new("TextButton", {
		Name = "Close", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.985, 0.5), Size = UDim2.fromScale(0.05, 0.5),
		BackgroundColor3 = Color3.fromRGB(28, 28, 32), Text = "X", FontFace = FONT_HEAVY, TextScaled = true, TextColor3 = Color3.fromRGB(255, 110, 120),
		AutoButtonColor = false,
	}, header)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, close)
	corner(close, 0.2)
	stroke(close, Color3.fromRGB(255, 90, 110), 1.5, 0.3)
	new("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0) }, close)
	hover(close)

	-- sidebar
	local sidebar = new("Frame", {
		Name = "Sidebar", Position = UDim2.new(0, 0, 0.15, 3), Size = UDim2.new(0.235, 0, 0.85, -3), BackgroundTransparency = 1,
	}, holder)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.012, 0) }, sidebar)
	new("UIPadding", { PaddingTop = UDim.new(0.03, 0), PaddingBottom = UDim.new(0.03, 0) }, sidebar)
	local sideLine = new("Frame", {
		Name = "SideLine", Position = UDim2.new(0.235, 0, 0.15, 3), Size = UDim2.new(0, 3, 0.85, -3), BackgroundColor3 = LINE, BorderSizePixel = 0,
	}, holder)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 0.85) }, sideLine)

	local content = new("Frame", {
		Name = "Content", Position = UDim2.new(0.235, 3, 0.15, 3), Size = UDim2.new(0.765, -3, 0.85, -3), BackgroundTransparency = 1,
	}, holder)

	local w = { gui = gui, holder = holder, header = header, sidebar = sidebar, content = content, title = titleLabel }
	local isOpen = false
	function w.open()
		if isOpen then return end
		for _, other in ipairs(windows) do
			if other ~= w then other.hide() end
		end
		isOpen = true
		openCount += 1
		gui.Enabled = true
		blur(true)
		scale.Scale = 0.8
		TweenService:Create(scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if w.onOpen then w.onOpen() end
	end
	function w.hide()
		if not isOpen then return end
		isOpen = false
		openCount = math.max(0, openCount - 1)
		if openCount == 0 then blur(false) end
		local t = TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.8 })
		t:Play()
		t.Completed:Connect(function()
			if not isOpen then gui.Enabled = false end
		end)
	end
	function w.isOpen() return isOpen end
	close.Activated:Connect(w.hide)
	table.insert(windows, w)
	return w
end

-- "// Section" heading in a sidebar
local function sideHeading(sidebar, label, order)
	local h = new("Frame", { Name = "Heading", LayoutOrder = order, Size = UDim2.fromScale(0.94, 0.1), BackgroundTransparency = 1 }, sidebar)
	text(h, { Text = "// " .. label, Size = UDim2.fromScale(1, 0.8), Position = UDim2.fromScale(0, 0.2), FontFace = FONT, TextColor3 = SOFT, Max = 34 })
	return h
end

-- an outlined sidebar button with coloured text; returns button, setSelected(on)
local function sideButton(sidebar, label, color, order)
	local b = new("TextButton", {
		Name = label, LayoutOrder = order, Size = UDim2.fromScale(0.86, 0.085), BackgroundColor3 = color, BackgroundTransparency = 1,
		Text = "", AutoButtonColor = false,
	}, sidebar)
	local s = stroke(b, color, 1.5, 0.15)
	local glow = new("Frame", {
		Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.5),
		BackgroundColor3 = color, BackgroundTransparency = 0.92, BorderSizePixel = 0, ZIndex = 0,
	}, b)
	corner(glow, 1)
	local l = text(b, {
		Text = label, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.88, 0.42),
		TextColor3 = Color3.new(1, 1, 1), Max = 22, Shadow = 1.5,
	})
	fade(l, color:Lerp(Color3.new(1, 1, 1), 0.25), color, 90)
	hover(b)
	local function setSelected(on)
		s.Color = on and Color3.new(1, 1, 1) or color
		s.Transparency = on and 0 or 0.15
		TweenService:Create(b, TweenInfo.new(0.15), { BackgroundTransparency = on and 0.85 or 1 }):Play()
	end
	return b, setSelected
end

-- a card with the gradient look from the reference (dark top, lighter bottom)
local function card(parent, props, tint)
	local c = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, parent)
	for k, v in pairs(props) do c[k] = v end
	tint = tint or Color3.fromRGB(95, 110, 150)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(22, 24, 32), tint) }, c)
	local s = stroke(c, tint:Lerp(Color3.new(1, 1, 1), 0.35), 2)
	return c, s
end

-- a big dim padlock drawn with frames (the locked card)
local function padlock(parent)
	local holder = new("Frame", {
		Name = "Padlock", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.62, 0.62),
		BackgroundTransparency = 1,
	}, parent)
	new("UIAspectRatioConstraint", { AspectRatio = 0.9 }, holder)
	local col = Color3.fromRGB(30, 30, 34)
	local shackle = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.02), Size = UDim2.fromScale(0.58, 0.55),
		BackgroundTransparency = 1,
	}, holder)
	corner(shackle, 0.5)
	new("UIStroke", { Color = col, Thickness = 14, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, shackle)
	local body = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.92, 0.6), BackgroundColor3 = col,
	}, holder)
	corner(body, 0.12)
	local hole = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromScale(0.2, 0.2),
		BackgroundColor3 = Color3.fromRGB(12, 12, 14), SizeConstraint = Enum.SizeConstraint.RelativeXX,
	}, body)
	corner(hole, 1)
	local slot = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.08, 0.35),
		BackgroundColor3 = Color3.fromRGB(12, 12, 14),
	}, body)
	corner(slot, 0.4)
	return holder
end

-- quick message at the top of the screen
local toastGui = new("ScreenGui", { Name = "LabStaffToasts", ResetOnSpawn = false, DisplayOrder = 30, IgnoreGuiInset = true }, playerGui)
local function toast(msg, color)
	local l = text(toastGui, {
		Text = msg, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromScale(0.5, 0.05),
		TextColor3 = color or Color3.new(1, 1, 1), FontFace = FONT_HEAVY, Shadow = 2.5,
	})
	local s = new("UIScale", { Scale = 0.4 }, l)
	TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(l, TweenInfo.new(1.6), { Position = UDim2.fromScale(0.5, 0.16) }):Play()
	task.delay(1.2, function() TweenService:Create(l, TweenInfo.new(0.35), { TextTransparency = 1 }):Play() end)
	task.delay(1.6, function() l:Destroy() end)
end

------------------------------------------------------------------------------------------
-- THE STAFF WING: workers and decor build themselves in (same drop-in as the lab pieces)
------------------------------------------------------------------------------------------
local function dust(position, color)
	local att = Instance.new("Attachment")
	att.WorldPosition = position
	att.Parent = workspace.Terrain
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color or Color3.fromRGB(190, 140, 255))
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

local function templateFor(e)
	return (e.kind == "Staff" and staffTemplates or decorTemplates):FindFirstChild(e.id)
end

-- put a model with the bottom of its box on the floor at spot = { X, Z, turn }
local function placeModel(model, spot)
	local cf, size = model:GetBoundingBox()
	local turn = CFrame.Angles(0, math.rad(spot[3] or 0), 0)
	local target = CFrame.new(spot[1], FY + size.Y / 2, spot[2]) * turn * cf.Rotation
	model:PivotTo(target * cf:ToObjectSpace(model:GetPivot()))
end

local function prepare(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch = false
			if d.Name == "Anchor" or d.Name == "HumanoidRootPart" then
				d.CanCollide = false
				d.Transparency = 1
			end
		end
	end
end

local placed = {} -- [id] = model

local function buildIn(model)
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
	end)
end

local function flyApart(model)
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
	dust(cf.Position, Color3.fromRGB(220, 200, 255))
	task.delay(1, function() model:Destroy() end)
end

local function render(id, animate)
	if placed[id] then return end
	local e = LabConfig.ExtraById[id]
	local template = e and templateFor(e)
	if not template then return end
	local model = template:Clone()
	prepare(model)
	placeModel(model, e.spot)
	model.Parent = folder
	placed[id] = model
	if animate then buildIn(model) end
end

local function unrender(id, animate)
	local model = placed[id]
	if not model then return end
	placed[id] = nil
	if animate then flyApart(model) else model:Destroy() end
end

-- the Lab Shop kiosk: a little terminal with a glowing screen
local kioskPart
do
	local k = LabConfig.StaffWing.kiosk
	local model = new("Model", { Name = "LabShopKiosk" }, folder)
	local function box(name, size, cf, color, material)
		return new("Part", {
			Name = name, Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, Anchored = true,
			TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
		}, model)
	end
	local base = CFrame.new(k[1], FY, k[2])
	box("Base", Vector3.new(5, 0.6, 4), base * CFrame.new(0, 0.3, 0), Color3.fromRGB(40, 38, 52))
	-- the screen faces +Z, back towards the rest of the lab where players walk in from
	box("Stand", Vector3.new(1.6, 3.4, 1.2), base * CFrame.new(0, 2.3, -0.4), Color3.fromRGB(55, 52, 70))
	local screen = box("Screen", Vector3.new(4.4, 2.8, 0.4), base * CFrame.new(0, 4.6, 0.2) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(30, 24, 50))
	box("Glow", Vector3.new(4.6, 0.25, 3.6), base * CFrame.new(0, 0.66, 0), ACCENT, Enum.Material.Neon)
	kioskPart = screen
	local sg = new("SurfaceGui", {
		Face = Enum.NormalId.Back, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 60, LightInfluence = 0,
		Adornee = screen, ResetOnSpawn = false,
	}, playerGui)
	local bg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BG }, sg)
	fade(bg, Color3.fromRGB(60, 25, 120), Color3.fromRGB(14, 12, 22), 90)
	local t = text(bg, { Text = "LAB SHOP", FontFace = FONT_HEAVY, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.9, 0.42), TextColor3 = Color3.new(1, 1, 1) })
	fade(t, Color3.fromRGB(200, 150, 255), Color3.fromRGB(130, 60, 255), 90)
	text(bg, { Text = "Staff & Decor", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.75), Size = UDim2.fromScale(0.8, 0.2), TextColor3 = DIM })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Open"
	prompt.ObjectText = "Lab Shop"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 11
	prompt.HoldDuration = 0
	prompt:SetAttribute("Opens", "LabStaffShop")
	prompt.Parent = screen
end

------------------------------------------------------------------------------------------
-- LAB SHOP
------------------------------------------------------------------------------------------
local shop = darkWindow("LabStaffShop", "LAB SHOP")

-- currencies on the top bar
local bar = new("Frame", {
	Name = "Currencies", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.925, 0.52), Size = UDim2.fromScale(0.6, 0.5),
	BackgroundTransparency = 1,
}, shop.header)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.015, 0), SortOrder = Enum.SortOrder.LayoutOrder,
}, bar)
local barAmounts = {}
for i, cur in ipairs(CURRENCIES) do
	local info = LabConfig.Currencies[cur]
	local pill = new("Frame", { Name = cur, LayoutOrder = i, Size = UDim2.fromScale(0.235, 0.8), BackgroundColor3 = Color3.fromRGB(24, 24, 30) }, bar)
	corner(pill, 0.3)
	stroke(pill, info.color, 1.5, 0.25)
	currencyIcon(pill, cur, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.04, 0.5), Size = UDim2.fromScale(0.85, 0.85), SizeConstraint = Enum.SizeConstraint.RelativeYY })
	barAmounts[cur] = text(pill, {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.94, 0.5), Size = UDim2.fromScale(0.6, 0.55),
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = info.color, Max = 22, Shadow = 1.5,
	})
end

-- the grid of things to buy
local grid = new("ScrollingFrame", {
	Name = "Grid", Position = UDim2.fromScale(0.03, 0.05), Size = UDim2.fromScale(0.95, 0.92), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(160, 160, 170), AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
}, shop.content)
local gridLayout = new("UIGridLayout", {
	CellSize = UDim2.fromScale(0.31, 0), CellPadding = UDim2.fromScale(0.025, 0), SortOrder = Enum.SortOrder.LayoutOrder,
}, grid)
new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, grid)
-- cells keep a card shape whatever the window size
local function sizeCells()
	local w = grid.AbsoluteSize.X
	gridLayout.CellSize = UDim2.fromOffset(math.floor(w * 0.31), math.floor(w * 0.31 * 1.18))
	gridLayout.CellPadding = UDim2.fromOffset(math.floor(w * 0.02), math.floor(w * 0.025))
end
grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeCells)

local previews = {} -- { camera, center, dist }
local cards = {} -- [id] = { ... }

local function preview(parent, template)
	local vp = new("ViewportFrame", {
		Name = "Preview", Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.9, 0.46), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 165, 190), LightColor = Color3.fromRGB(255, 250, 255), LightDirection = Vector3.new(-0.5, -1, -0.7),
	}, parent)
	local m = template:Clone()
	prepare(m)
	m.Parent = vp
	local cf, size = m:GetBoundingBox()
	local cam = new("Camera", { FieldOfView = 35 }, vp)
	vp.CurrentCamera = cam
	table.insert(previews, { camera = cam, center = cf.Position, dist = size.Magnitude * 1.35 + 1 })
	return vp
end

local function refreshShop() end -- filled in below

local function shopCard(e, order)
	local info = LabConfig.Currencies[e.currency]
	local c, cs = card(grid, { Name = e.id, LayoutOrder = order, Visible = false }, Color3.fromRGB(70, 60, 110))
	corner(c, 0.04)
	local template = templateFor(e)
	if template then preview(c, template) end
	text(c, {
		Text = e.name, FontFace = FONT_HEAVY, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.1),
		TextColor3 = Color3.new(1, 1, 1), Max = 26, Shadow = 1.5,
	})
	text(c, {
		Text = LabConfig.extraEffect(e), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.61), Size = UDim2.fromScale(0.9, 0.08),
		TextColor3 = Color3.fromRGB(120, 235, 140), Max = 20, Shadow = 1.5,
	})
	text(c, {
		Text = e.desc, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromScale(0.9, 0.065),
		TextColor3 = DIM, Max = 16,
	})
	local buy = new("TextButton", {
		Name = "Buy", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.955), Size = UDim2.fromScale(0.86, 0.15),
		BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = false,
	}, c)
	corner(buy, 0.25)
	local buyGrad = new("UIGradient", { Rotation = 90 }, buy)
	local buyStroke = stroke(buy, Color3.new(1, 1, 1), 1.5, 0.2)
	local icon = currencyIcon(buy, e.currency, {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.07, 0.5), Size = UDim2.fromScale(0.72, 0.72), SizeConstraint = Enum.SizeConstraint.RelativeYY,
	})
	local label = text(buy, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.56, 0.5), Size = UDim2.fromScale(0.66, 0.6),
		FontFace = FONT_HEAVY, TextColor3 = Color3.new(1, 1, 1), Max = 24, Shadow = 1.5,
	})
	hover(buy)
	cards[e.id] = { card = c, cardStroke = cs, buy = buy, grad = buyGrad, buyStroke = buyStroke, icon = icon, label = label, kind = e.kind, info = info }
	buy.Activated:Connect(function()
		if LabConfig.ownsExtra(player, e.id) then return end
		local r = invoke("buyExtra", e.id)
		if r.ok then
			pop(c, 1.08)
			toast(e.name .. (e.kind == "Staff" and " hired!" or " built!"), Color3.fromRGB(200, 160, 255))
			-- close so you can watch it build itself in the Staff Wing
			task.delay(0.35, shop.hide)
		elseif r.reason == "cost" then
			toast("Not enough " .. (info.short or e.currency) .. "!", Color3.fromRGB(255, 120, 130))
			pop(buy, 1.12)
		end
	end)
end

local order = 0
for _, list in ipairs({ LabConfig.Staff, LabConfig.Decor }) do
	for _, e in ipairs(list) do
		order += 1
		shopCard(e, order)
	end
end

local tab = "Staff"
local setTabs = {}
sideHeading(shop.sidebar, "Lab Shop", 1)
local staffTab, staffSel = sideButton(shop.sidebar, "Workers", Color3.fromRGB(170, 110, 255), 2)
local decorTab, decorSel = sideButton(shop.sidebar, "Decor", Color3.fromRGB(90, 170, 255), 3)
sideHeading(shop.sidebar, "Info", 4)
text(shop.sidebar, {
	Name = "Info", LayoutOrder = 5, Size = UDim2.fromScale(0.86, 0.34), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = DIM, Max = 16,
	Text = "Staff and decor show up in the Staff Wing and boost your lab. They stay through Lab Levels and reset with an Advancement Mark.",
})
setTabs.Staff, setTabs.Decor = staffSel, decorSel

local function showTab(which)
	tab = which
	for k, set in pairs(setTabs) do set(k == which) end
	for _, c in pairs(cards) do c.card.Visible = c.kind == which end
	grid.CanvasPosition = Vector2.zero
end
staffTab.Activated:Connect(function() showTab("Staff") end)
decorTab.Activated:Connect(function() showTab("Decor") end)

refreshShop = function()
	for _, cur in ipairs(CURRENCIES) do
		barAmounts[cur].Text = abbreviate(have(cur))
	end
	for id, c in pairs(cards) do
		local e = LabConfig.ExtraById[id]
		if LabConfig.ownsExtra(player, id) then
			c.label.Text = e.kind == "Staff" and "HIRED ✔" or "OWNED ✔"
			c.label.Position = UDim2.fromScale(0.5, 0.5)
			c.label.Size = UDim2.fromScale(0.86, 0.6)
			c.icon.Visible = false
			c.grad.Color = ColorSequence.new(Color3.fromRGB(40, 150, 90), Color3.fromRGB(20, 90, 55))
			c.buyStroke.Color = Color3.fromRGB(120, 255, 170)
			c.cardStroke.Color = Color3.fromRGB(120, 255, 170)
		else
			local afford = have(e.currency) >= e.cost
			c.label.Text = abbreviate(e.cost)
			c.label.Position = UDim2.fromScale(0.56, 0.5)
			c.label.Size = UDim2.fromScale(0.66, 0.6)
			c.icon.Visible = true
			c.grad.Color = afford and ColorSequence.new(Color3.fromRGB(150, 80, 255), ACCENT_2)
				or ColorSequence.new(Color3.fromRGB(70, 70, 80), Color3.fromRGB(40, 40, 48))
			c.buyStroke.Color = afford and Color3.fromRGB(200, 160, 255) or Color3.fromRGB(110, 110, 120)
			c.cardStroke.Color = afford and c.info.color or Color3.fromRGB(95, 95, 110)
		end
	end
end
shop.onOpen = function()
	sizeCells()
	showTab(tab)
	refreshShop()
end
Kit.closeWhenFar(shop, function() return kioskPart and kioskPart.Position end, 18)

------------------------------------------------------------------------------------------
-- MARKS MENU (from the Advancement Marks board)
------------------------------------------------------------------------------------------
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII" }
local MARK_LOOK = {
	{ title = "Mark of Discovery", color = Color3.fromRGB(255, 120, 40) },
	{ title = "Mark of Synthesis", color = Color3.fromRGB(110, 160, 255) },
	{ title = "Mark of Catalysis", color = Color3.fromRGB(200, 150, 255) },
	{ title = "Mark of Insight", color = Color3.fromRGB(150, 60, 255) },
	{ title = "Mark of Essence", color = Color3.fromRGB(240, 80, 100) },
}

local marks = darkWindow("LabMarks", "MARKS")
sideHeading(marks.sidebar, "Lab Marks", 1)
local markButtons = {}
for i = 1, LabConfig.MaxMark do
	local look = MARK_LOOK[i] or { title = "Mark " .. (ROMAN[i] or i), color = ACCENT }
	local b, set = sideButton(marks.sidebar, look.title, look.color, i + 1)
	markButtons[i] = { button = b, set = set }
end

-- left card: the selected mark
local info, infoStroke = card(marks.content, {
	Name = "MarkCard", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.08, 0.46), Size = UDim2.fromScale(0.39, 0.78),
})
local mName = text(info, { FontFace = FONT_HEAVY, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.05), Size = UDim2.fromScale(0.92, 0.11), TextColor3 = Color3.new(1, 1, 1), Shadow = 2 })
local mNameGrad = fade(mName, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 90)
local mRoman = text(info, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.17), Size = UDim2.fromScale(0.5, 0.075), TextColor3 = SOFT, Shadow = 1.5 })
local mState = text(info, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromScale(0.6, 0.075), TextColor3 = SOFT, Shadow = 1.5 })
local sep = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.35), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Color3.fromRGB(130, 130, 140), BorderSizePixel = 0 }, info)
new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }, sep)
local bonusList = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.39), Size = UDim2.fromScale(0.9, 0.36), BackgroundTransparency = 1 }, info)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.02, 0) }, bonusList)
local mReq = text(info, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.fromScale(0.88, 0.07), TextColor3 = Color3.new(1, 1, 1), Shadow = 1.5 })

-- right card: the next mark, locked until you get there
local nextCard, nextStroke = card(marks.content, {
	Name = "NextCard", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.92, 0.46), Size = UDim2.fromScale(0.39, 0.78),
}, Color3.fromRGB(8, 8, 10))
local lock = padlock(nextCard)
local nextLabel = text(nextCard, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.95), Size = UDim2.fromScale(0.9, 0.08), TextColor3 = DIM, Shadow = 1.5 })
local check = text(nextCard, { Text = "✔", FontFace = FONT_HEAVY, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.5, 0.4), TextColor3 = Color3.fromRGB(120, 255, 170), Visible = false })

-- advance button under the cards
local advance = new("TextButton", {
	Name = "Advance", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.975), Size = UDim2.fromScale(0.34, 0.1),
	BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = false,
}, marks.content)
corner(advance, 0.25)
local advGrad = new("UIGradient", { Rotation = 90 }, advance)
local advStroke = stroke(advance, Color3.new(1, 1, 1), 1.5, 0.2)
local advLabel = text(advance, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.85, 0.55), FontFace = FONT_HEAVY, TextColor3 = Color3.new(1, 1, 1), Shadow = 1.5 })
hover(advance)

local selected = 1
local armedUntil = 0

local function bonusLine(label, color, orderN)
	local l = text(bonusList, { LayoutOrder = orderN, Text = label, Size = UDim2.fromScale(1, 0.2), TextColor3 = Color3.new(1, 1, 1), Shadow = 1.5, Max = 26 })
	fade(l, color:Lerp(Color3.new(1, 1, 1), 0.3), color, 90)
end

local function refreshMarks()
	local m = LabConfig.labMark(player)
	local lv = LabConfig.labLevel(player)
	local def = LabConfig.Marks[selected]
	local look = MARK_LOOK[selected] or { title = def.name, color = ACCENT }
	for i, mb in ipairs(markButtons) do mb.set(i == selected) end

	mName.Text = look.title:gsub("^Mark of ", "")
	mNameGrad.Color = ColorSequence.new(look.color:Lerp(Color3.new(1, 1, 1), 0.35), look.color)
	mRoman.Text = "Mark " .. (ROMAN[selected] or selected)
	infoStroke.Color = look.color:Lerp(Color3.new(1, 1, 1), 0.3)
	info:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(Color3.fromRGB(22, 24, 32), look.color:Lerp(Color3.fromRGB(60, 70, 100), 0.6))

	if selected <= m then
		mState.Text = "OWNED"
		mState.TextColor3 = Color3.fromRGB(120, 255, 170)
	elseif selected == m + 1 then
		mState.Text = math.floor(math.clamp(lv / LabConfig.MaxLevel, 0, 1) * 100) .. "%"
		mState.TextColor3 = SOFT
	else
		mState.Text = "LOCKED"
		mState.TextColor3 = DIM
	end

	for _, ch in ipairs(bonusList:GetChildren()) do
		if ch:IsA("TextLabel") then ch:Destroy() end
	end
	bonusLine("x" .. fmt(def.prod) .. " Production", Color3.fromRGB(90, 235, 130), 1)
	bonusLine("x" .. fmt(def.knowledge) .. " Knowledge", LabConfig.Currencies.Knowledge.color, 2)
	bonusLine("x" .. fmt(def.luck) .. " Luck", Color3.fromRGB(100, 200, 255), 3)
	if (def.bulk or 0) > 0 then
		bonusLine("+" .. def.bulk .. " Potion" .. (def.bulk > 1 and "s" or "") .. " per brew", Color3.fromRGB(255, 210, 90), 4)
	end
	mReq.Text = selected <= m and "[Achieved]" or ("[Needs Lab Level " .. LabConfig.MaxLevel .. "]")

	-- next mark card
	local nextIndex = math.min(m + 1, LabConfig.MaxMark)
	if m >= LabConfig.MaxMark then
		lock.Visible = false
		check.Visible = true
		nextLabel.Text = "Every mark earned!"
		nextStroke.Color = Color3.fromRGB(120, 255, 170)
	else
		lock.Visible = true
		check.Visible = false
		local nlook = MARK_LOOK[nextIndex] or { title = "Mark " .. nextIndex, color = ACCENT }
		nextLabel.Text = "Next: " .. nlook.title
		nextStroke.Color = nlook.color:Lerp(Color3.new(1, 1, 1), 0.45)
	end

	-- advance button
	if os.clock() < armedUntil then return end
	if m >= LabConfig.MaxMark then
		advLabel.Text = "ALL MARKS"
		advGrad.Color = ColorSequence.new(Color3.fromRGB(40, 150, 90), Color3.fromRGB(20, 90, 55))
		advStroke.Color = Color3.fromRGB(120, 255, 170)
	elseif lv >= LabConfig.MaxLevel then
		advLabel.Text = "ADVANCE"
		advGrad.Color = ColorSequence.new(Color3.fromRGB(150, 80, 255), ACCENT_2)
		advStroke.Color = Color3.fromRGB(200, 160, 255)
	else
		advLabel.Text = "Lab Level " .. lv .. " / " .. LabConfig.MaxLevel
		advGrad.Color = ColorSequence.new(Color3.fromRGB(70, 70, 80), Color3.fromRGB(40, 40, 48))
		advStroke.Color = Color3.fromRGB(110, 110, 120)
	end
end

for i, mb in ipairs(markButtons) do
	mb.button.Activated:Connect(function()
		selected = i
		pop(info, 1.04)
		refreshMarks()
	end)
end

advance.Activated:Connect(function()
	local m = LabConfig.labMark(player)
	if m >= LabConfig.MaxMark then return end
	if LabConfig.labLevel(player) < LabConfig.MaxLevel then
		toast("Reach Lab Level " .. LabConfig.MaxLevel .. " first!", Color3.fromRGB(255, 120, 130))
		pop(advance, 1.12)
		return
	end
	-- two taps: this is a big reset
	if os.clock() > armedUntil then
		armedUntil = os.clock() + 3
		advLabel.Text = "Sure? Big reset!"
		advGrad.Color = ColorSequence.new(Color3.fromRGB(255, 120, 120), Color3.fromRGB(200, 40, 50))
		pop(advance, 1.1)
		task.delay(3.05, refreshMarks)
		return
	end
	armedUntil = 0
	local r = invoke("advance")
	if r.ok then
		selected = r.mark
		toast((MARK_LOOK[r.mark] and MARK_LOOK[r.mark].title or "Mark " .. r.mark) .. "!", Color3.fromRGB(220, 170, 255))
		pop(info, 1.1)
	end
	refreshMarks()
end)

marks.onOpen = function()
	selected = math.clamp(LabConfig.labMark(player) + 1, 1, LabConfig.MaxMark)
	refreshMarks()
end

-- a prompt on the Advancement Marks board opens the menu
local markBoardPart
task.spawn(function()
	local board = playerGui:WaitForChild("LabMarkBoard", 30)
	local adornee = board and board.Adornee
	while board and not adornee do
		board:GetPropertyChangedSignal("Adornee"):Wait()
		adornee = board.Adornee
	end
	if not adornee or not adornee:IsA("BasePart") then return end
	markBoardPart = new("Part", {
		Name = "MarksPrompt", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(adornee.Position.X, FY + 3, adornee.Position.Z),
	}, folder)
	local p = Instance.new("ProximityPrompt")
	p.Style = Enum.ProximityPromptStyle.Custom
	p.ActionText = "View Marks"
	p.ObjectText = "Advancement Marks"
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.RequiresLineOfSight = false
	p.MaxActivationDistance = 14
	p.HoldDuration = 0
	p:SetAttribute("Opens", "LabMarks")
	p.Parent = markBoardPart
end)
Kit.closeWhenFar(marks, function() return markBoardPart and markBoardPart.Position end, 22)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local opens = prompt:GetAttribute("Opens")
	if opens == "LabStaffShop" then
		shop.open()
	elseif opens == "LabMarks" then
		marks.open()
	end
end)

------------------------------------------------------------------------------------------
-- SYNC
------------------------------------------------------------------------------------------
local ready = false
local function syncAll(animate)
	for id in pairs(LabConfig.ExtraById) do
		if LabConfig.ownsExtra(player, id) then
			render(id, animate)
		else
			unrender(id, animate)
		end
	end
end

task.spawn(function()
	while player:GetAttribute("DataLoaded") ~= true do
		task.wait(0.5)
	end
	syncAll(false)
	ready = true
end)

local watched = {}
for id in pairs(LabConfig.ExtraById) do watched[LabConfig.extraAttribute(id)] = id end
local currencyAttrs = {}
for _, cur in ipairs(CURRENCIES) do currencyAttrs[LabConfig.Currencies[cur].attr] = true end

player.AttributeChanged:Connect(function(attr)
	local id = watched[attr]
	if id and ready then
		if LabConfig.ownsExtra(player, id) then render(id, true) else unrender(id, true) end
	end
	if shop.isOpen() and (id or currencyAttrs[attr]) then
		refreshShop()
	end
	if marks.isOpen() and (attr == "LabLevel" or attr == "LabMark") then
		refreshMarks()
	end
end)

-- slowly turn the model previews while the shop is open
RunService.RenderStepped:Connect(function()
	if not shop.isOpen() then return end
	local a = os.clock() * 0.6
	for _, p in ipairs(previews) do
		local dir = Vector3.new(math.sin(a), 0.45, math.cos(a)).Unit
		p.camera.CFrame = CFrame.lookAt(p.center + dir * p.dist, p.center)
	end
end)
