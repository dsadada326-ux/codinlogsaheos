-- The catch reveal: the fish pops up in the middle of the screen under a spotlight beam in
-- its rarity colour, with rays behind it, "NEW!" if it's your first one, "1 in N" and
-- "Name (kg)". Plays for every catch.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local FishingConfig = require(ReplicatedStorage:WaitForChild("FishingConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local assets = ReplicatedStorage:WaitForChild("FishingAssets")

local Reveal = {}

local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local INK = Color3.fromRGB(10, 10, 14)
local BEAM_STRIPS = 28

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "CatchReveal"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 15
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local root = Instance.new("Frame")
root.BackgroundTransparency = 1
root.AnchorPoint = Vector2.new(0.5, 0)
root.Position = UDim2.fromScale(0.5, 0)
root.Size = UDim2.fromScale(0.5, 0.78)
root.Parent = gui
local rootAspect = Instance.new("UIAspectRatioConstraint")
rootAspect.AspectRatio = 0.95
rootAspect.Parent = root
local rootScale = Instance.new("UIScale")
rootScale.Parent = root

-- spotlight beam: strips that get wider towards the bottom (a soft trapezoid)
local beam = Instance.new("Frame")
beam.Name = "Beam"
beam.BackgroundTransparency = 1
beam.Size = UDim2.fromScale(1, 1)
beam.Parent = root
local strips = {}
for i = 1, BEAM_STRIPS do
	local k = (i - 1) / (BEAM_STRIPS - 1)
	local strip = Instance.new("Frame")
	strip.BorderSizePixel = 0
	strip.AnchorPoint = Vector2.new(0.5, 0)
	strip.Position = UDim2.fromScale(0.5, (i - 1) / BEAM_STRIPS)
	strip.Size = UDim2.new(0.34 + 0.62 * k, 0, 1 / BEAM_STRIPS, 1)
	strip.BackgroundColor3 = Color3.new(1, 1, 1)
	strip.Parent = beam
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(0.88, 0.55), NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = strip
	strips[i] = { frame = strip, base = 0.08 + 0.42 * k ^ 1.3 }
end

-- rays behind the fish
local rays = Instance.new("Frame")
rays.BackgroundTransparency = 1
rays.AnchorPoint = Vector2.new(0.5, 0.5)
rays.Position = UDim2.fromScale(0.5, 0.4)
rays.Size = UDim2.fromScale(0.95, 0.95)
rays.Parent = root
local raysAspect = Instance.new("UIAspectRatioConstraint")
raysAspect.Parent = rays
for i = 0, 7 do
	local ray = Instance.new("Frame")
	ray.AnchorPoint = Vector2.new(0.5, 0.5)
	ray.Position = UDim2.fromScale(0.5, 0.5)
	ray.Size = UDim2.fromScale(0.09, 1)
	ray.Rotation = i * 22.5
	ray.BorderSizePixel = 0
	ray.BackgroundColor3 = Color3.new(1, 1, 1)
	ray.Parent = rays
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.75),
		NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(0.65, 0.75), NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = ray
end

-- the fish
local view = Instance.new("ViewportFrame")
view.BackgroundTransparency = 1
view.AnchorPoint = Vector2.new(0.5, 0.5)
view.Position = UDim2.fromScale(0.5, 0.4)
view.Size = UDim2.fromScale(0.78, 0.62)
view.Ambient = Color3.fromRGB(200, 200, 200)
view.LightColor = Color3.new(1, 1, 1)
view.LightDirection = Vector3.new(-0.5, -1, -0.6)
view.Parent = root
local cam = Instance.new("Camera")
cam.FieldOfView = 30
cam.Parent = view
view.CurrentCamera = cam
local viewScale = Instance.new("UIScale")
viewScale.Parent = view

local function label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	local strokeSize = props.StrokeSize or 4
	props.StrokeSize = nil
	for k, v in pairs(props) do l[k] = v end
	local s = Instance.new("UIStroke")
	s.Thickness = strokeSize
	s.Color = INK
	s.Parent = l
	l.Parent = root
	return l
end

local newBadge = label({
	Name = "New", Text = "NEW", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.24, 0.17),
	Size = UDim2.fromScale(0.3, 0.1), Rotation = -14, TextColor3 = Color3.fromRGB(255, 205, 40), ZIndex = 5,
})
local newGrad = Instance.new("UIGradient")
newGrad.Color = ColorSequence.new(Color3.fromRGB(255, 235, 90), Color3.fromRGB(255, 150, 20))
newGrad.Rotation = 90
newGrad.Parent = newBadge
local newScale = Instance.new("UIScale")
newScale.Parent = newBadge

local rarityLabel = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.fromScale(0.7, 0.055), StrokeSize = 3,
})
local oneInLabel = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.695), Size = UDim2.fromScale(0.8, 0.1),
})
local nameLabel = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.79), Size = UDim2.fromScale(1.15, 0.1),
})
local valueLabel = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.895), Size = UDim2.fromScale(0.7, 0.065), StrokeSize = 3,
	TextColor3 = Color3.fromRGB(255, 225, 110),
})

local texts = { newBadge, rarityLabel, oneInLabel, nameLabel, valueLabel }

local model, spin, token = nil, 0, 0
local modelOffset = CFrame.new()

RunService.RenderStepped:Connect(function(dt)
	if not gui.Enabled then return end
	rays.Rotation = (rays.Rotation + dt * 18) % 360
	if model and model.Parent then
		spin += dt
		model:PivotTo(CFrame.new(0, math.sin(spin * 2.4) * 0.06, 0) * CFrame.Angles(0, math.sin(spin * 1.3) * 0.45, math.sin(spin * 2.1) * 0.1) * modelOffset)
	end
	newScale.Scale = 1 + math.sin(os.clock() * 7) * 0.06
end)

local function oneInText(n)
	if n == math.huge then return "???" end
	if n < 1000 then return "1 in " .. tostring(n) end
	return "1 in " .. NumberFormat.abbreviate(n)
end

function Reveal.show(result, colorOf)
	token += 1
	local mine = token
	local color = colorOf and colorOf(result.rarity) or Color3.fromRGB(80, 255, 80)

	for _, s in ipairs(strips) do
		s.frame.BackgroundColor3 = color
	end
	rarityLabel.Text = string.upper(result.rarity)
	rarityLabel.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.25)
	oneInLabel.Text = oneInText(FishingConfig.oneIn(result.fish))
	nameLabel.Text = result.name .. " (" .. FishingConfig.formatKg(result.kg) .. ")"
	valueLabel.Text = "+" .. NumberFormat.abbreviate(math.floor(result.value + 0.5)) .. " Fish Meal"
	newBadge.Visible = result.isNew == true

	if model then model:Destroy() model = nil end
	local source = assets.Fish:FindFirstChild(result.fish)
	if source then
		model = source:Clone()
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("ParticleEmitter") or d:IsA("Sparkles") then d:Destroy() end
		end
		model:PivotTo(CFrame.new())
		model.Parent = view
		local boxCF, size = model:GetBoundingBox()
		modelOffset = CFrame.new(-boxCF.Position)
		local radius = math.max(size.X, size.Y, size.Z) * 0.5
		cam.CFrame = CFrame.lookAt(Vector3.new(0, radius * 0.15, radius / math.tan(math.rad(15)) * 1.05), Vector3.zero)
		spin = 0
	end

	-- in
	gui.Enabled = true
	for i, s in ipairs(strips) do
		s.frame.BackgroundTransparency = 1
		TweenService:Create(s.frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, i * 0.006), { BackgroundTransparency = s.base }):Play()
	end
	for _, l in ipairs(texts) do
		l.TextTransparency = 0
		l:FindFirstChildOfClass("UIStroke").Transparency = 0
	end
	for _, ray in ipairs(rays:GetChildren()) do
		if ray:IsA("Frame") then ray.BackgroundTransparency = 0 end
	end
	rootScale.Scale = 1
	viewScale.Scale = 0.2
	TweenService:Create(viewScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local textScale = oneInLabel:FindFirstChild("Pop") or Instance.new("UIScale")
	textScale.Name = "Pop"
	for _, l in ipairs({ oneInLabel, nameLabel }) do
		local s = l:FindFirstChild("Pop") or Instance.new("UIScale")
		s.Name = "Pop"
		s.Parent = l
		s.Scale = 0.3
		TweenService:Create(s, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.12), { Scale = 1 }):Play()
	end

	-- rarer = stays a bit longer
	local hold = 2.1 + (FishingConfig.RarityIndex[result.rarity] or 1) * 0.25
	task.delay(hold, function()
		if token ~= mine then return end
		local fade = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, s in ipairs(strips) do
			TweenService:Create(s.frame, fade, { BackgroundTransparency = 1 }):Play()
		end
		for _, l in ipairs(texts) do
			TweenService:Create(l, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(l:FindFirstChildOfClass("UIStroke"), fade, { Transparency = 1 }):Play()
		end
		for _, ray in ipairs(rays:GetChildren()) do
			if ray:IsA("Frame") then TweenService:Create(ray, fade, { BackgroundTransparency = 1 }):Play() end
		end
		TweenService:Create(viewScale, fade, { Scale = 0 }):Play()
		task.wait(0.4)
		if token == mine then
			gui.Enabled = false
			if model then model:Destroy() model = nil end
		end
	end)
end

return Reveal
