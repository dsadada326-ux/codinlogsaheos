-- Shared look for the Fishing Frenzy menus (Rod Shop, Shell Upgrades, Sell dialog).
-- Client only. Everything is built in code so the menus stay consistent.
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Kit = {}

Kit.Font = Font.fromEnum(Enum.Font.FredokaOne)
Kit.Ink = Color3.fromRGB(12, 24, 40)

Kit.Buttons = {
	green = { Color3.fromRGB(150, 255, 90), Color3.fromRGB(55, 190, 40), Color3.fromRGB(15, 70, 10) },
	red = { Color3.fromRGB(255, 120, 120), Color3.fromRGB(210, 45, 50), Color3.fromRGB(85, 10, 15) },
	blue = { Color3.fromRGB(120, 215, 255), Color3.fromRGB(30, 130, 225), Color3.fromRGB(8, 45, 95) },
	grey = { Color3.fromRGB(215, 215, 222), Color3.fromRGB(130, 132, 145), Color3.fromRGB(45, 45, 55) },
	gold = { Color3.fromRGB(255, 240, 120), Color3.fromRGB(245, 170, 25), Color3.fromRGB(110, 55, 0) },
}

function Kit.new(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props or {}) do
		i[k] = v
	end
	if parent then i.Parent = parent end
	return i
end

function Kit.corner(parent, r)
	return Kit.new("UICorner", { CornerRadius = UDim.new(r or 0.15, 0) }, parent)
end

function Kit.stroke(parent, thickness, color, border)
	return Kit.new("UIStroke", {
		Thickness = thickness or 2,
		Color = color or Kit.Ink,
		ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual,
	}, parent)
end

function Kit.gradient(parent, top, bottom, rotation)
	return Kit.new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 }, parent)
end

function Kit.text(parent, props)
	local l = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Kit.Font,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
	})
	local strokeSize = props.Stroke or 2
	local max = props.Max
	props.Stroke, props.Max = nil, nil
	for k, v in pairs(props) do l[k] = v end
	if strokeSize > 0 then Kit.stroke(l, strokeSize) end
	if max then Kit.new("UITextSizeConstraint", { MaxTextSize = max }, l) end
	l.Parent = parent
	return l
end

function Kit.image(parent, props)
	local img = Kit.new("ImageLabel", { BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit })
	for k, v in pairs(props) do img[k] = v end
	img.Parent = parent
	return img
end

-- chunky button: returns button, paint(style), label
function Kit.button(parent, props, labelText)
	local b = Kit.new("TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), Text = "" })
	for k, v in pairs(props) do b[k] = v end
	Kit.corner(b, 0.28)
	local s = Kit.stroke(b, 3, Kit.Ink, true)
	local g = Kit.gradient(b, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	local label = Kit.text(b, {
		Name = "Label", Text = labelText or "", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.7), Max = 30, Stroke = 2.5,
	})
	b.Parent = parent

	local scale = Kit.new("UIScale", { Name = "Press" }, b)
	b.MouseEnter:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.05 }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
	b.MouseButton1Down:Connect(function() TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.92 }):Play() end)
	b.MouseButton1Up:Connect(function() TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1.05 }):Play() end)
	b:SetAttribute("NoTween", true) -- has its own

	local function paint(style)
		local c = Kit.Buttons[style] or Kit.Buttons.grey
		g.Color = ColorSequence.new(c[1], c[2])
		s.Color = c[3]
		local ls = label:FindFirstChildOfClass("UIStroke")
		if ls then ls.Color = c[3] end
	end
	paint("green")
	return b, paint, label
end

-- a menu window: returns { gui, panel, body, close, open(), hide(), isOpen() }
function Kit.window(name, title, colors, size)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Kit.new("ScreenGui", { Name = name, ResetOnSpawn = false, DisplayOrder = 20, Enabled = false, IgnoreGuiInset = true }, playerGui)

	local panel = Kit.new("Frame", {
		Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
		Size = size or UDim2.fromScale(0.62, 0.7), BackgroundColor3 = Color3.fromRGB(30, 40, 58),
	}, gui)
	Kit.corner(panel, 0.035)
	Kit.stroke(panel, 4, Kit.Ink, true)
	Kit.new("UIAspectRatioConstraint", { AspectRatio = 1.65 }, panel)
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(1100, 700) }, panel)
	Kit.new("ImageLabel", {
		Name = "Checker", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = "rbxassetid://6372755229",
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(60, 60), ImageTransparency = 0.9,
	}, panel)
	local scale = Kit.new("UIScale", { Name = "OpenScale" }, panel)

	local header = Kit.new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0.14, 0), BackgroundColor3 = Color3.new(1, 1, 1) }, panel)
	Kit.corner(header, 0.3)
	Kit.stroke(header, 3, Kit.Ink, true)
	Kit.gradient(header, colors[1], colors[2])
	Kit.text(header, {
		Name = "Title", Text = title, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.03, 0.5),
		Size = UDim2.fromScale(0.7, 0.75), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3.5, Max = 48,
	})

	local close, paintClose = Kit.button(header, {
		Name = "Close", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromScale(0.08, 0.78),
	}, "X")
	paintClose("red")
	Kit.new("UIAspectRatioConstraint", { AspectRatio = 1.1 }, close)

	local body = Kit.new("Frame", {
		Name = "Body", Position = UDim2.new(0.02, 0, 0.17, 0), Size = UDim2.new(0.96, 0, 0.8, 0), BackgroundTransparency = 1,
	}, panel)

	local w = { gui = gui, panel = panel, body = body, header = header, close = close }
	local isOpen = false

	function w.open()
		if isOpen then return end
		isOpen = true
		gui.Enabled = true
		scale.Scale = 0.7
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if w.onOpen then w.onOpen() end
	end

	function w.hide()
		if not isOpen then return end
		isOpen = false
		local t = TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.7 })
		t:Play()
		t.Completed:Connect(function()
			if not isOpen then gui.Enabled = false end
		end)
		if w.onClose then w.onClose() end
	end

	function w.isOpen() return isOpen end

	close.Activated:Connect(w.hide)
	return w
end

-- closes a window when you walk more than `range` studs from `getPosition()`
function Kit.closeWhenFar(window, getPosition, range)
	task.spawn(function()
		while true do
			task.wait(0.3)
			if window.isOpen() then
				local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				local pos = getPosition()
				if not root or not pos or (root.Position - pos).Magnitude > range then
					window.hide()
				end
			end
		end
	end)
end

function Kit.pop(guiObject, from)
	local s = guiObject:FindFirstChild("Pop") or Kit.new("UIScale", { Name = "Pop" }, guiObject)
	s.Scale = from or 1.15
	TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

------------------------------------------------------------------------------------------
-- frosted glass window (Rod Shop / Shell Upgrades): see-through panel, background blurred,
-- title on top, red X just outside the top-right corner, optional side panel on the right.
--   opts = { aspect = 1.6, main = 0.76 (width share of the main panel), side = true, tint = Color3 }
------------------------------------------------------------------------------------------
local Lighting = game:GetService("Lighting")
local openGlass = 0

local function blur(on)
	local b = Lighting:FindFirstChild("FishingMenuBlur")
	if not b then
		b = Instance.new("BlurEffect")
		b.Name = "FishingMenuBlur"
		b.Size = 0
		b.Parent = Lighting
	end
	TweenService:Create(b, TweenInfo.new(0.25), { Size = on and 14 or 0 }):Play()
end

function Kit.glass(name, title, opts)
	opts = opts or {}
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Kit.new("ScreenGui", { Name = name, ResetOnSpawn = false, DisplayOrder = 20, Enabled = false, IgnoreGuiInset = true }, playerGui)
	local mainShare = opts.side and (opts.main or 0.76) or 0.93

	local holder = Kit.new("Frame", {
		Name = "Holder", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromScale(0.64, 0.72), BackgroundTransparency = 1,
	}, gui)
	Kit.new("UIAspectRatioConstraint", { AspectRatio = opts.aspect or 1.6 }, holder)
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(1150, 720) }, holder)
	local scale = Kit.new("UIScale", { Name = "OpenScale" }, holder)

	local tint = opts.tint or Color3.fromRGB(215, 235, 215)
	local panel = Kit.new("Frame", {
		Name = "Panel", Size = UDim2.fromScale(mainShare, 1), BackgroundColor3 = tint, BackgroundTransparency = 0.3,
	}, holder)
	Kit.corner(panel, 0.045)
	Kit.stroke(panel, 5, Color3.fromRGB(8, 10, 14), true)
	Kit.gradient(panel, Color3.new(1, 1, 1), Color3.fromRGB(200, 205, 200))

	Kit.text(panel, {
		Name = "Title", Text = title, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.7, 0.12), Stroke = 4, Max = 60,
	})

	local close, paintClose, closeLabel = Kit.button(holder, {
		Name = "Close", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(mainShare, 12, 0, 6),
		Size = UDim2.fromScale(0.062, 0.1),
	}, "X")
	paintClose("red")
	closeLabel.Size = UDim2.fromScale(0.8, 0.8)
	Kit.new("UIAspectRatioConstraint", { AspectRatio = 1 }, close)

	local body = Kit.new("Frame", {
		Name = "Body", Position = UDim2.fromScale(0.03, 0.15), Size = UDim2.fromScale(0.94, 0.82), BackgroundTransparency = 1,
	}, panel)

	local side
	if opts.side then
		side = Kit.new("Frame", {
			Name = "Side", Position = UDim2.new(mainShare, 12, 0.13, 12), Size = UDim2.new(1 - mainShare, -12, 0.72, 0),
			BackgroundColor3 = Color3.fromRGB(190, 240, 190), BackgroundTransparency = 0.25,
		}, holder)
		Kit.corner(side, 0.07)
		Kit.stroke(side, 4, Color3.fromRGB(8, 10, 14), true)
		Kit.gradient(side, Color3.new(1, 1, 1), Color3.fromRGB(190, 200, 190))
	end

	local w = { gui = gui, holder = holder, panel = panel, body = body, side = side, close = close }
	local isOpen = false

	function w.open()
		if isOpen then return end
		isOpen = true
		openGlass += 1
		gui.Enabled = true
		blur(true)
		scale.Scale = 0.75
		TweenService:Create(scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if w.onOpen then w.onOpen() end
	end

	function w.hide()
		if not isOpen then return end
		isOpen = false
		openGlass = math.max(0, openGlass - 1)
		if openGlass == 0 then blur(false) end
		local t = TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.75 })
		t:Play()
		t.Completed:Connect(function()
			if not isOpen then gui.Enabled = false end
		end)
		if w.onClose then w.onClose() end
	end

	function w.isOpen() return isOpen end
	close.Activated:Connect(w.hide)
	return w
end

-- a sunburst behind something (slowly turning rays), clipped to `parent`
function Kit.sunburst(parent, color)
	parent.ClipsDescendants = true
	local spin = Kit.new("Frame", {
		Name = "Sunburst", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(2.2, 2.2), BackgroundTransparency = 1, ZIndex = 0,
	}, parent)
	Kit.new("UIAspectRatioConstraint", { AspectRatio = 1 }, spin)
	for i = 0, 8 do
		local ray = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.12, 1),
			Rotation = i * 20, BackgroundColor3 = color or Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, ZIndex = 0,
		}, spin)
		Kit.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55),
				NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 1),
			}),
		}, ray)
	end
	task.spawn(function()
		while spin.Parent do
			spin.Rotation = (spin.Rotation + 0.25) % 360
			task.wait(1 / 30)
		end
	end)
	return spin
end

return Kit
