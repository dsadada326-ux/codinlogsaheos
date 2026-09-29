-- Loading screen: films the LoadingScene (the little island with the Red Button - it's kept in
-- ReplicatedFirst so it arrives before anything else, and this puts a copy of it in the world) from
-- Island.CameraPosition while the game loads. The two cursors take turns
-- clicking the button about 2 times a second, the button squashes and its counter counts up, and a
-- chunky green bar shows the percentage (it pops every 10%).
-- When it's done it fades to black and hands over to the game (or to JoinIntro for new players,
-- which waits for the LoadingDone attribute this sets).
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local MIN_TIME = 3 + math.random() * 2 -- the bar takes 3-5 seconds (longer only if the game really isn't ready)
local CLICKS_MIN, CLICKS_MAX = 1.5, 2.5  -- clicks per second on the button while loading
local MAX_TIME = 25          -- give up waiting on slow things after this
local SCENE_WAIT = 5         -- if the scene still isn't in after this, load without it
local INTRO_WAIT = 8         -- max seconds to wait for the join intro to take over

------------------------------------------------------------------------------------------
-- the screen
------------------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 2000
gui.Parent = player:WaitForChild("PlayerGui")

-- (build the black cover first, then take Roblox's loading screen down, so the real map never shows)
local black = Instance.new("Frame")
black.Name = "Black"
black.BackgroundColor3 = Color3.new(0, 0, 0)
black.BorderSizePixel = 0
black.Size = UDim2.fromScale(1, 1)
black.ZIndex = 10
black.Parent = gui

ReplicatedFirst:RemoveDefaultLoadingScreen()

-- (the black frame above covers the screen until the scene is in, and for the fade at the end)

-- the bar ------------------------------------------------------------------------------
local DARK_OUTLINE = Color3.fromRGB(10, 75, 15)
local TRACK = Color3.fromRGB(10, 120, 20)
local TRACK_CHECK = Color3.fromRGB(5, 100, 15)
local FILL_TOP = Color3.fromRGB(225, 255, 130)
local FILL_BOTTOM = Color3.fromRGB(145, 235, 70)

local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.fromScale(0.5, 0.93)
bar.Size = UDim2.fromScale(0.62, 1)
bar.BackgroundColor3 = TRACK
bar.BorderSizePixel = 0
bar.ZIndex = 2
bar.Parent = gui

local ratio = Instance.new("UIAspectRatioConstraint")
ratio.AspectRatio = 10.4
ratio.DominantAxis = Enum.DominantAxis.Width
ratio.Parent = bar

Instance.new("UICorner", bar).CornerRadius = UDim.new(0.22, 0)

local outline = Instance.new("UIStroke")
outline.Color = DARK_OUTLINE
outline.Thickness = 5
outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
outline.Parent = bar

-- thin light rim just inside the dark outline
local rim = Instance.new("Frame")
rim.Name = "Rim"
rim.BackgroundTransparency = 1
rim.Size = UDim2.fromScale(1, 1)
rim.ZIndex = 6
rim.Parent = bar
Instance.new("UICorner", rim).CornerRadius = UDim.new(0.22, 0)
local rimStroke = Instance.new("UIStroke")
rimStroke.Color = Color3.fromRGB(215, 255, 190)
rimStroke.Thickness = 2
rimStroke.Transparency = 0.2
rimStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
rimStroke.Parent = rim

-- a checker pattern (rows x cols squares) in a frame the size of the whole bar
local ROWS = 4
local COLS = 42

local function checker(parent, color, transparency, z)
	local holder = Instance.new("Frame")
	holder.Name = "Checker"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = z
	holder.Parent = parent

	for r = 0, ROWS - 1 do
		for c = 0, COLS - 1 do
			if (r + c) % 2 == 0 then
				local sq = Instance.new("Frame")
				sq.BorderSizePixel = 0
				sq.BackgroundColor3 = color
				sq.BackgroundTransparency = transparency
				sq.Position = UDim2.fromScale(c / COLS, r / ROWS)
				sq.Size = UDim2.fromScale(1 / COLS, 1 / ROWS)
				sq.ZIndex = z
				sq.Parent = holder
			end
		end
	end

	return holder
end

-- the dark track, clipped to the rounded bar
local track = Instance.new("CanvasGroup")
track.Name = "Track"
track.BackgroundTransparency = 1
track.Size = UDim2.fromScale(1, 1)
track.ZIndex = 3
track.Parent = bar
Instance.new("UICorner", track).CornerRadius = UDim.new(0.22, 0)
checker(track, TRACK_CHECK, 0, 3)

-- the bright fill, also rounded; its pattern stays the size of the whole bar
local fill = Instance.new("CanvasGroup")
fill.Name = "Fill"
fill.BackgroundColor3 = Color3.new(1, 1, 1)
fill.BorderSizePixel = 0
fill.Size = UDim2.fromScale(0, 1)
fill.ZIndex = 4
fill.Parent = bar
Instance.new("UICorner", fill).CornerRadius = UDim.new(0.22, 0)

local fillGradient = Instance.new("UIGradient")
fillGradient.Rotation = 90
fillGradient.Color = ColorSequence.new(FILL_TOP, FILL_BOTTOM)
fillGradient.Parent = fill

local fillPattern = Instance.new("Frame")
fillPattern.Name = "Pattern"
fillPattern.BackgroundTransparency = 1
fillPattern.Size = UDim2.fromScale(1, 1)
fillPattern.ZIndex = 4
fillPattern.Parent = fill
checker(fillPattern, Color3.new(1, 1, 1), 0.82, 4)

-- a glossy strip along the top of the fill
local gloss = Instance.new("Frame")
gloss.Name = "Gloss"
gloss.BackgroundColor3 = Color3.new(1, 1, 1)
gloss.BackgroundTransparency = 0.45
gloss.BorderSizePixel = 0
gloss.Position = UDim2.fromScale(0.012, 0.1)
gloss.Size = UDim2.fromScale(0.976, 0.12)
gloss.ZIndex = 5
gloss.Parent = fill
Instance.new("UICorner", gloss).CornerRadius = UDim.new(0.5, 0)

-- the big "91%"
local function percentLabel(name, z, offsetY, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, 0, 0.5, offsetY)
	label.Size = UDim2.fromScale(0.4, 1.05)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "0%"
	label.TextColor3 = color
	label.ZIndex = z
	label.Parent = bar

	local stroke = Instance.new("UIStroke")
	stroke.Color = DARK_OUTLINE
	stroke.Thickness = 4
	stroke.Parent = label

	return label, stroke
end

local shadow, shadowStroke = percentLabel("Shadow", 7, 4, DARK_OUTLINE)
local percent, percentStroke = percentLabel("Percent", 8, 0, Color3.new(1, 1, 1))

local textGradient = Instance.new("UIGradient")
textGradient.Rotation = 90
textGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 255, 200))
textGradient.Parent = percent

local percentScale = Instance.new("UIScale")
percentScale.Parent = percent

-- outlines scale with the bar's size on screen
local function fitStrokes()
	local h = bar.AbsoluteSize.Y
	outline.Thickness = math.max(3, h * 0.07)
	percentStroke.Thickness = math.max(2, h * 0.06)
	shadowStroke.Thickness = math.max(2, h * 0.06)
end

bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitStrokes)
fitStrokes()

local function setBar(p) -- 0..1
	fill.Size = UDim2.fromScale(p, 1)
	fill.Visible = p > 0.001
	fillPattern.Size = UDim2.fromScale(1 / math.max(p, 0.001), 1)
	local text = math.floor(p * 100 + 0.5) .. "%"
	percent.Text = text
	shadow.Text = text
end

setBar(0)

------------------------------------------------------------------------------------------
-- hide everything else while loading
------------------------------------------------------------------------------------------
local coreTypes = { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Chat, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.EmotesMenu }
local coreWas = {}

for _, t in ipairs(coreTypes) do
	local ok, on = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, t)
	coreWas[t] = ok and on

	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, t, false)
end

local hiddenGuis = {}

local function hideGui(g)
	if g ~= gui and g:IsA("ScreenGui") and g.Enabled then
		g.Enabled = false
		table.insert(hiddenGuis, g)
	end
end

for _, g in ipairs(player.PlayerGui:GetChildren()) do
	hideGui(g)
end

local guiAdded = player.PlayerGui.ChildAdded:Connect(hideGui)

------------------------------------------------------------------------------------------
-- the scene
------------------------------------------------------------------------------------------
local scene = {}

task.spawn(function()
	local ok = pcall(function()
		local template = ReplicatedFirst:WaitForChild("LoadingScene", 15)
		local folder = workspace:FindFirstChild("LoadingScene") or template:Clone()
		folder.Parent = workspace -- only on this screen (it's a local copy)

		-- give its meshes/textures a moment to load so the first frame isn't grey
		local preloaded = false
		task.spawn(function()
			pcall(ContentProvider.PreloadAsync, ContentProvider, { folder })
			preloaded = true
		end)
		local waitStart = os.clock()
		while not preloaded and os.clock() - waitStart < 1.5 do
			task.wait()
		end

		local island = folder:WaitForChild("Island", 15)
		scene.camPart = island:WaitForChild("CameraPosition", 15)
		local buttonModel = folder:WaitForChild("RedButton", 15):WaitForChild("Button", 15)
		scene.cap = buttonModel:WaitForChild("Button", 15)
		scene.base = buttonModel:FindFirstChild("Base")
		scene.counter = buttonModel:FindFirstChild("Counter")
		scene.cursors = {}

		local cursorsModel = buttonModel:WaitForChild("ClickCursors", 15)

		for _, cursor in ipairs(cursorsModel:GetChildren()) do
			if cursor:IsA("Model") then
				table.insert(scene.cursors, { model = cursor, base = cursor:GetPivot(), click = 0, phase = math.random() * math.pi * 2 })
			end
		end

		scene.capCFrame = scene.cap.CFrame
		scene.capSize = scene.cap.Size
	end)

	if ok and scene.camPart and scene.cap then
		scene.ready = true
		TweenService:Create(black, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	end
end)

-- the camera: CameraPosition, with a slow gentle sway
local startClock = os.clock()

RunService:BindToRenderStep("LoadingScreenCamera", Enum.RenderPriority.Camera.Value + 10, function()
	if not scene.ready then
		return
	end

	local t = os.clock() - startClock
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 70
	-- exactly where Island.CameraPosition points (move that part to change the shot), with a tiny sway
	camera.CFrame = scene.camPart.CFrame
		* CFrame.Angles(math.rad(math.sin(t * 0.4) * 0.6), math.rad(math.sin(t * 0.25) * 0.8), 0)

	-- cursors: bob gently, and poke down at the button when they click
	local target = scene.capCFrame.Position + Vector3.new(0, scene.capSize.Y / 2, 0)

	for _, c in ipairs(scene.cursors) do
		local tip = c.base.Position
		local dir = (target - tip).Unit
		local bob = math.sin(t * 2.2 + c.phase) * 0.25
		c.model:PivotTo(c.base + dir * (c.click * 2.2) + Vector3.new(0, bob, 0))
	end
end)

-- one click: a cursor pokes the button, the button squashes, the counter counts
local presses = 0
local capToken = 0

local function press(which)
	if not scene.ready then
		return
	end

	presses += 1

	-- this cursor pokes down and pops back up
	local c = scene.cursors[which]

	if c then
		if c.tween then
			c.tween:Cancel()
		end

		local v = Instance.new("NumberValue")
		v.Value = c.click
		v.Changed:Connect(function(x)
			c.click = x
		end)

		task.spawn(function()
			c.tween = TweenService:Create(v, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 1 })
			c.tween:Play()
			c.tween.Completed:Wait()
			c.tween = TweenService:Create(v, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 0 })
			c.tween:Play()
			c.tween.Completed:Wait()
			v:Destroy()
		end)
	end

	-- the button squashes down and springs back (a new click restarts it)
	capToken += 1
	local token = capToken

	task.delay(0.08, function()
		if token ~= capToken then
			return
		end

		local cap, size, cf = scene.cap, scene.capSize, scene.capCFrame
		local squashed = Vector3.new(size.X * 1.06, size.Y * 0.62, size.Z * 1.06)
		local drop = (size.Y - squashed.Y) / 2

		TweenService:Create(cap, TweenInfo.new(0.07, Enum.EasingStyle.Quad), {
			Size = squashed,
			CFrame = cf * CFrame.new(0, -drop, 0),
		}):Play()

		task.wait(0.09)

		if token ~= capToken then
			return
		end

		TweenService:Create(cap, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = size,
			CFrame = cf,
		}):Play()
	end)

	-- the counter on the button counts the clicks
	local counterGui = scene.counter and scene.counter:FindFirstChildOfClass("SurfaceGui")

	if counterGui then
		for _, d in ipairs(counterGui:GetDescendants()) do
			if d:IsA("TextLabel") and (d.Name == "TextLabel" or d.Name == "DropShadow") then
				d.Text = "x" .. presses
			elseif d:IsA("TextLabel") and d.Name == "ComboMultiplier" then
				d.Text = string.format("%.2fx", 1 + presses * 0.05)
			elseif d:IsA("Frame") and d.Name == "Fill" then
				TweenService:Create(d, TweenInfo.new(0.15), { Size = UDim2.new(math.clamp(presses / 20, 0, 1), 0, d.Size.Y.Scale, d.Size.Y.Offset) }):Play()
			end
		end

		local frame = counterGui:FindFirstChild("Frame")
		local scale = frame and frame:FindFirstChildOfClass("UIScale")

		if scale then
			scale.Scale = 1.15
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end

end

local function popPercent()
	percentScale.Scale = 1.18
	TweenService:Create(percentScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- the cursors take turns clicking, 3-5 times a second, for as long as it's loading
local clicking = true

task.spawn(function()
	local which = 1

	while clicking do
		if scene.ready and #scene.cursors > 0 then
			press(which)
			which = which % #scene.cursors + 1
		end

		task.wait(1 / (CLICKS_MIN + math.random() * (CLICKS_MAX - CLICKS_MIN)))
	end
end)

------------------------------------------------------------------------------------------
-- progress
------------------------------------------------------------------------------------------
local shown = 0
local lastTen = 0

-- the map around your character: loaded, plus a beat for the scripts that hide locked areas
local areaReady = false

task.spawn(function()
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10)

	if root then
		pcall(function()
			player:RequestStreamAroundAsync(root.Position, 8)
		end)
	end

	task.wait(0.8)
	areaReady = true
end)

-- the clock for the bar starts once the scene is showing, so every 10% click is on camera
local barClock = nil

local function targetProgress()
	if not barClock then
		if scene.ready or os.clock() - startClock > SCENE_WAIT then
			barClock = os.clock()
		else
			return 0
		end
	end

	local elapsed = os.clock() - barClock
	local p = math.clamp(elapsed / MIN_TIME, 0, 1)

	if elapsed < MAX_TIME then
		-- don't run ahead of what's actually loaded
		if not game:IsLoaded() then
			p = math.min(p, 0.6)
		end

		if ContentProvider.RequestQueueSize > 0 then
			p = math.min(p, 0.8)
		end

		if player:GetAttribute("DataLoaded") ~= true then
			p = math.min(p, 0.9)
		end

		if not player.Character or not areaReady then
			p = math.min(p, 0.95)
		end
	end

	return p
end

while shown < 1 do
	local dt = RunService.RenderStepped:Wait()
	local target = targetProgress()

	-- ease toward the target, but always creep forward a little so it never looks stuck
	shown = math.min(target, shown + math.max((target - shown) * dt * 4, dt * 0.02))
	setBar(shown)

	local tens = math.floor(shown * 10 + 1e-6)

	if tens > lastTen then
		lastTen = tens
		popPercent()
	end
end

clicking = false

task.wait(0.5)

------------------------------------------------------------------------------------------
-- hand over to the game
------------------------------------------------------------------------------------------
TweenService:Create(black, TweenInfo.new(0.4), { BackgroundTransparency = 0 }):Play()
task.wait(0.45)

RunService:UnbindFromRenderStep("LoadingScreenCamera")
bar.Visible = false
camera.CameraType = Enum.CameraType.Custom
camera.FieldOfView = 70

guiAdded:Disconnect()

for _, g in ipairs(hiddenGuis) do
	if g.Parent then
		g.Enabled = true
	end
end

for t, was in pairs(coreWas) do
	if was then
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, t, true)
	end
end

-- put the scene's button back the way it was (it's in the world, other people may see it)
if scene.ready then
	scene.cap.Size = scene.capSize
	scene.cap.CFrame = scene.capCFrame

	for _, c in ipairs(scene.cursors) do
		c.model:PivotTo(c.base)
	end
end

player:SetAttribute("LoadingDone", true)

-- a brand-new player gets the join intro: stay black until it takes over (its eyes start shut)
local previewing = RunService:IsStudio() and workspace:GetAttribute("PreviewJoinIntro") == true
-- (the server sets _IntroLanding when it starts one; IntroPlayed still false = not decided yet)
local introComing = previewing
	or player:GetAttribute("_IntroLanding") ~= nil
	or player:GetAttribute("IntroPlayed") ~= true

if introComing then
	local waited = 0

	while not player.PlayerGui:FindFirstChild("JoinIntroEyes") and waited < INTRO_WAIT do
		waited += task.wait(0.1)
	end
end

TweenService:Create(black, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
task.wait(0.55)
gui:Destroy()
