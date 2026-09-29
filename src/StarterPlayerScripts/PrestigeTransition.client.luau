local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local prestigedRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Prestiged")

local redButton = workspace:WaitForChild("Islands"):WaitForChild("Island1"):WaitForChild("RedButton"):WaitForChild("Button")

local GREEN = Color3.fromRGB(90, 255, 120)
local GREEN_DARK = Color3.fromRGB(10, 70, 25)

local function uiFont()
	local ok, font = pcall(function()
		return player.PlayerGui.Currencies.MainCurrenciesFrame.CurrenciesFrame.Money.Value.FontFace
	end)

	return ok and font or Font.fromEnum(Enum.Font.FredokaOne)
end

local function label(parent, text, size, position, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size = size
	l.Position = position
	l.TextScaled = true
	l.FontFace = uiFont()
	l.Text = text
	l.TextColor3 = color
	l.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(10, 10, 18)
	stroke.Parent = l

	return l, stroke
end

-- a spot on the ground just in front of the red button
local function spotByRedButton()
	local pivot = redButton:GetPivot()
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local toward = spawn and (spawn.Position - pivot.Position) or Vector3.new(0, 0, 1)
	toward = Vector3.new(toward.X, 0, toward.Z)
	toward = toward.Magnitude > 0.1 and toward.Unit or Vector3.new(0, 0, 1)

	local point = pivot.Position + toward * 12
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local hit = workspace:Raycast(point + Vector3.new(0, 40, 0), Vector3.new(0, -100, 0), params)
	local y = hit and hit.Position.Y or pivot.Position.Y

	return CFrame.lookAt(Vector3.new(point.X, y + 4, point.Z), Vector3.new(pivot.Position.X, y + 4, pivot.Position.Z))
end

local playing = false

local function play(level)
	if playing then
		return
	end

	playing = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "PrestigeTransition"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.Parent = player:WaitForChild("PlayerGui")

	-- the loading screen: dark backdrop with a green glow, spinning ring, title, progress bar
	local cover = Instance.new("CanvasGroup")
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = Color3.fromRGB(8, 14, 12)
	cover.GroupTransparency = 1
	cover.Parent = gui

	local glow = Instance.new("UIGradient")
	glow.Color = ColorSequence.new(Color3.fromRGB(12, 45, 22), Color3.fromRGB(4, 8, 10))
	glow.Rotation = 90
	glow.Parent = cover

	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.42)
	ring.Size = UDim2.fromScale(0.09, 0.09)
	ring.BackgroundTransparency = 1
	ring.Parent = cover
	Instance.new("UIAspectRatioConstraint", ring).AspectRatio = 1
	Instance.new("UICorner", ring).CornerRadius = UDim.new(0.5, 0)

	local ringStroke = Instance.new("UIStroke")
	ringStroke.Thickness = 8
	ringStroke.Color = GREEN
	ringStroke.Parent = ring

	local ringGradient = Instance.new("UIGradient")
	ringGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(0.75, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	ringGradient.Parent = ringStroke

	local title = label(cover, "PRESTIGING", UDim2.fromScale(0.5, 0.08), UDim2.fromScale(0.5, 0.58), GREEN)
	local sub = label(cover, "Prestige " .. level, UDim2.fromScale(0.3, 0.045), UDim2.fromScale(0.5, 0.65), Color3.fromRGB(200, 255, 210))

	local barBack = Instance.new("Frame")
	barBack.AnchorPoint = Vector2.new(0.5, 0.5)
	barBack.Position = UDim2.fromScale(0.5, 0.72)
	barBack.Size = UDim2.fromScale(0.32, 0.018)
	barBack.BackgroundColor3 = GREEN_DARK
	barBack.Parent = cover
	Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = GREEN
	barFill.Parent = barBack
	Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

	-- spin + "PRESTIGING..." dots while it's up
	local started = os.clock()
	local spin = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		ringGradient.Rotation = (t * 360) % 360
		title.Text = "PRESTIGING" .. string.rep(".", math.floor(t * 3) % 4)
	end)

	-- 1) cover the screen
	TweenService:Create(cover, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
	TweenService:Create(barFill, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Size = UDim2.fromScale(1, 1) }):Play()
	task.wait(0.45)

	-- 2) back to the red button while nobody can see
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if root then
		character:PivotTo(spotByRedButton())
		root.AssemblyLinearVelocity = Vector3.zero
	end

	local camera = workspace.CurrentCamera

	if camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Custom
	end

	task.wait(1.25)
	spin:Disconnect()
	title.Text = "PRESTIGED!"

	-- 3) reveal
	TweenService:Create(cover, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { GroupTransparency = 1 }):Play()
	task.wait(0.3)

	-- 4) "PRESTIGED!" in green at the top
	local banner = Instance.new("CanvasGroup")
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.12)
	banner.Size = UDim2.fromScale(0.5, 0.12)
	banner.BackgroundTransparency = 1
	banner.GroupTransparency = 1
	banner.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Scale = 0.5
	scale.Parent = banner

	local big, bigStroke = label(banner, "PRESTIGED!", UDim2.fromScale(1, 0.7), UDim2.fromScale(0.5, 0.35), Color3.new(1, 1, 1))
	bigStroke.Thickness = 4
	bigStroke.Color = GREEN_DARK

	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GREEN),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(210, 255, 220)),
		ColorSequenceKeypoint.new(1, GREEN),
	})
	shine.Offset = Vector2.new(-1, 0)
	shine.Parent = big

	label(banner, "Prestige " .. level, UDim2.fromScale(0.45, 0.3), UDim2.fromScale(0.5, 0.85), Color3.fromRGB(200, 255, 210))

	TweenService:Create(banner, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
	TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(shine, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Offset = Vector2.new(1, 0) }):Play()

	task.wait(2.6)

	TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		GroupTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.06),
	}):Play()

	task.wait(0.45)
	gui:Destroy()
	playing = false
end

prestigedRemote.OnClientEvent:Connect(play)
