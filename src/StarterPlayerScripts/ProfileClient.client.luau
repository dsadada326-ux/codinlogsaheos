-- The Profile menu (built in code; the old StarterGui.Profile is switched off).
--   Search bar at the top: look up anyone (players here first, then anyone who has played).
--   Left: name, title, prestige and the stats list. Right: their character (idle, turning to
--   follow your cursor). Bottom: Titles (left) and Achievements (right).
-- Stats / achievements / titles are set up in ReplicatedStorage.ProfileConfig.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Kit = require(ReplicatedStorage:WaitForChild("FishingUIKit"))
local ProfileConfig = require(ReplicatedStorage:WaitForChild("ProfileConfig"))
local abbreviate = require(ReplicatedStorage:WaitForChild("NumberFormat")).abbreviate
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getProfile = remotes:WaitForChild("GetProfile")
local equipTitle = remotes:WaitForChild("EquipTitle")

local INK = Color3.fromRGB(14, 18, 30)
local ROBUX = "\u{E002}"
local PROFILE_ICON = "rbxassetid://77466480151300"

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function formatStat(value, format)
	value = tonumber(value) or 0
	if format == "time" then
		local s = math.floor(value)
		local d, h, m = s // 86400, (s % 86400) // 3600, (s % 3600) // 60
		if d > 0 then return d .. "d " .. h .. "h" end
		if h > 0 then return h .. "h " .. m .. "m" end
		return m .. "m " .. (s % 60) .. "s"
	elseif format == "robux" then
		return ROBUX .. abbreviate(value)
	elseif format == "mult" then
		return "x" .. (value >= 100 and abbreviate(value) or string.format("%.2f", value):gsub("%.?0+$", ""))
	end
	return abbreviate(math.floor(value))
end

------------------------------------------------------------------------------------------
-- window
------------------------------------------------------------------------------------------
local gui = Kit.new("ScreenGui", {
	Name = "ProfileMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 25, Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local dim = Kit.new("TextButton", {
	Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
}, gui)

local panel = Kit.new("Frame", {
	Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.6, 0.76), BackgroundColor3 = Color3.fromRGB(24, 30, 50),
}, gui)
Kit.corner(panel, 0.04)
Kit.stroke(panel, 5, INK, true)
Kit.new("UIAspectRatioConstraint", { AspectRatio = 1.5 }, panel)
Kit.new("UISizeConstraint", { MaxSize = Vector2.new(1060, 706), MinSize = Vector2.new(450, 300) }, panel)
Kit.new("ImageLabel", {
	Name = "Checker", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = "rbxassetid://6372755229",
	ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(64, 64), ImageTransparency = 0.92,
}, panel)
local openScale = Kit.new("UIScale", { Name = "OpenScale" }, panel)

-- header: icon, title, search bar, close
local header = Kit.new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0.125, 0), BackgroundColor3 = Color3.new(1, 1, 1) }, panel)
Kit.corner(header, 0.28)
Kit.stroke(header, 4, INK, true)
Kit.gradient(header, Color3.fromRGB(255, 220, 90), Color3.fromRGB(245, 150, 30))
Kit.new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, Size = UDim2.new(1, -16, 0.45, 0), Position = UDim2.fromOffset(8, 4), BorderSizePixel = 0,
}, header)
local headerIcon = Kit.new("ImageLabel", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.012, 0.45), Size = UDim2.fromScale(0.09, 1.3),
	Image = PROFILE_ICON, ScaleType = Enum.ScaleType.Fit,
}, header)
Kit.text(header, {
	Text = "PROFILE", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.105, 0.5), Size = UDim2.fromScale(0.24, 0.72),
	TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4, Max = 50,
})

local close, paintClose = Kit.button(header, {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromScale(0.075, 0.8),
}, "X")
paintClose("red")
Kit.new("UIAspectRatioConstraint", { AspectRatio = 1 }, close)

-- search bar
local search = Kit.new("Frame", {
	Name = "Search", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.36, 0.5), Size = UDim2.fromScale(0.44, 0.7),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
}, header)
Kit.corner(search, 0.45)
local searchStroke = Kit.stroke(search, 3, INK, true)
Kit.gradient(search, Color3.fromRGB(255, 255, 255), Color3.fromRGB(225, 232, 245))
Kit.text(search, {
	Text = "\u{1F50D}", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.03, 0.5), Size = UDim2.fromScale(0.1, 0.7), Stroke = 0,
})
local box = Kit.new("TextBox", {
	Name = "Box", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.14, 0.5), Size = UDim2.fromScale(0.62, 0.62),
	FontFace = Kit.Font, TextScaled = true, Text = "", PlaceholderText = "Search any player...", PlaceholderColor3 = Color3.fromRGB(140, 150, 170),
	TextColor3 = Color3.fromRGB(30, 40, 60), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
}, search)
local goButton, paintGo = Kit.button(search, {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0), Size = UDim2.new(0.2, 0, 1, -8),
}, "Go")
paintGo("green")
box.Focused:Connect(function() tween(searchStroke, 0.15, { Thickness = 4.5 }) searchStroke.Color = Color3.fromRGB(255, 255, 255) end)
box.FocusLost:Connect(function() tween(searchStroke, 0.15, { Thickness = 3 }) searchStroke.Color = INK end)

-- "back to me"
local meButton, paintMe = Kit.button(header, {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.81, 0.5), Size = UDim2.fromScale(0.09, 0.66),
}, "Me")
paintMe("blue")

------------------------------------------------------------------------------------------
-- left: name card + stats
------------------------------------------------------------------------------------------
local left = Kit.new("Frame", { Name = "Left", BackgroundTransparency = 1, Position = UDim2.fromScale(0.02, 0.155), Size = UDim2.fromScale(0.47, 0.83) }, panel)

local nameCard = Kit.new("Frame", { Name = "NameCard", Size = UDim2.fromScale(1, 0.22), BackgroundColor3 = Color3.new(1, 1, 1) }, left)
Kit.corner(nameCard, 0.18)
Kit.stroke(nameCard, 3.5, INK, true)
Kit.gradient(nameCard, Color3.fromRGB(70, 90, 140), Color3.fromRGB(30, 40, 70))
local headshot = Kit.new("ImageLabel", {
	BackgroundColor3 = Color3.fromRGB(40, 50, 80), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.new(0.8, 0, 0.8, 0),
	Image = "", ScaleType = Enum.ScaleType.Crop,
}, nameCard)
Kit.new("UIAspectRatioConstraint", { AspectRatio = 1 }, headshot)
Kit.corner(headshot, 1)
Kit.stroke(headshot, 3, Color3.fromRGB(255, 255, 255), true)
local displayName = Kit.text(nameCard, {
	Text = "", Position = UDim2.fromScale(0.25, 0.08), Size = UDim2.fromScale(0.72, 0.42), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3.5,
})
local userName = Kit.text(nameCard, {
	Text = "", Position = UDim2.fromScale(0.25, 0.5), Size = UDim2.fromScale(0.4, 0.22), TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(190, 205, 235), Stroke = 2,
})
local statusLabel = Kit.text(nameCard, {
	Text = "", Position = UDim2.fromScale(0.25, 0.74), Size = UDim2.fromScale(0.4, 0.18), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2,
})
local titleBadge = Kit.new("Frame", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -8), Size = UDim2.fromScale(0.34, 0.34), BackgroundColor3 = Color3.new(1, 1, 1),
}, nameCard)
Kit.corner(titleBadge, 0.45)
Kit.stroke(titleBadge, 2.5, INK, true)
local titleGrad = Kit.gradient(titleBadge, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
local titleText = Kit.text(titleBadge, { Text = "", Size = UDim2.fromScale(0.9, 0.72), Position = UDim2.fromScale(0.05, 0.14), Stroke = 2 })

-- the stats list
local statsFrame = Kit.new("ScrollingFrame", {
	Name = "Stats", Position = UDim2.fromScale(0, 0.25), Size = UDim2.fromScale(1, 0.58), BackgroundColor3 = Color3.fromRGB(12, 16, 28),
	BackgroundTransparency = 0.3, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = Color3.fromRGB(200, 215, 240),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, left)
Kit.corner(statsFrame, 0.06)
Kit.stroke(statsFrame, 3, INK, true)
Kit.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 14) }, statsFrame)
Kit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, statsFrame)

local statRows = {}
for i, stat in ipairs(ProfileConfig.Stats) do
	local holder = Kit.new("Frame", { Name = stat.key, LayoutOrder = i, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42) }, statsFrame)
	local row = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, holder)
	Kit.corner(row, 0.3)
	Kit.stroke(row, 2.5, INK, true)
	Kit.gradient(row, Color3.fromRGB(95, 105, 130), Color3.fromRGB(35, 40, 55))
	Kit.text(row, { Text = stat.icon, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.new(0, 30, 0.7, 0), Stroke = 0 })
	Kit.text(row, {
		Text = stat.label, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 44, 0.5, 0), Size = UDim2.new(0.55, -44, 0.6, 0),
		TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2.5,
	})
	local value = Kit.text(row, {
		Text = "-", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.42, 0, 0.6, 0),
		TextXAlignment = Enum.TextXAlignment.Right, Stroke = 2.5,
	})
	statRows[i] = { stat = stat, row = row, value = value }
end

-- bottom-left: Titles
local titlesButton, paintTitles, titlesLabel = Kit.button(left, {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(0.62, 0.13),
}, "Titles")
paintTitles("blue")

------------------------------------------------------------------------------------------
-- right: the character stage
------------------------------------------------------------------------------------------
local right = Kit.new("Frame", { Name = "Right", BackgroundTransparency = 1, Position = UDim2.fromScale(0.51, 0.155), Size = UDim2.fromScale(0.47, 0.83) }, panel)
local stage = Kit.new("Frame", { Name = "Stage", Size = UDim2.fromScale(1, 0.84), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true }, right)
Kit.corner(stage, 0.06)
Kit.stroke(stage, 3.5, INK, true)
Kit.gradient(stage, Color3.fromRGB(120, 200, 255), Color3.fromRGB(40, 70, 150))
Kit.new("ImageLabel", {
	BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = "rbxassetid://6372755229", ScaleType = Enum.ScaleType.Tile,
	TileSize = UDim2.fromOffset(48, 48), ImageTransparency = 0.85,
}, stage)
-- soft spotlight + floor glow
local glow = Kit.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.9, 0.9), BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.75,
}, stage)
Kit.corner(glow, 1)
Kit.new("UIAspectRatioConstraint", { AspectRatio = 1 }, glow)
local glowGrad = Kit.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }) }, glow)
local floor = Kit.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.9), Size = UDim2.fromScale(0.6, 0.08), BackgroundColor3 = Color3.fromRGB(10, 20, 50),
	BackgroundTransparency = 0.5,
}, stage)
Kit.corner(floor, 1)

local viewport = Kit.new("ViewportFrame", {
	Name = "Viewport", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(190, 190, 200),
	LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-0.4, -0.8, -0.6),
}, stage)
local world = Kit.new("WorldModel", {}, viewport)
local cam = Kit.new("Camera", { FieldOfView = 32 }, viewport)
viewport.CurrentCamera = cam
local thumbFallback = Kit.new("ImageLabel", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.95, 0.95),
	ScaleType = Enum.ScaleType.Fit, Visible = false,
}, stage)
local loading = Kit.text(stage, { Text = "Loading...", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.1), Stroke = 3, Visible = false })

-- bottom-right: Achievements
local achButton, paintAch, achLabel = Kit.button(right, {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromScale(0.72, 0.13),
}, "Achievements")
paintAch("green")

------------------------------------------------------------------------------------------
-- Titles / Achievements pop-over
------------------------------------------------------------------------------------------
local over = Kit.new("Frame", {
	Name = "Over", Position = UDim2.fromScale(0.02, 1.2), Size = UDim2.fromScale(0.96, 0.83), BackgroundColor3 = Color3.fromRGB(20, 26, 44),
	Visible = false, ZIndex = 10,
}, panel)
Kit.corner(over, 0.04)
Kit.stroke(over, 4, INK, true)
local overTitle = Kit.text(over, {
	Text = "", Position = UDim2.fromScale(0.03, 0.02), Size = UDim2.fromScale(0.6, 0.1), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3.5, ZIndex = 11,
})
local back, paintBack = Kit.button(over, {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0.02, 0), Size = UDim2.fromScale(0.14, 0.1), ZIndex = 11,
}, "Back")
paintBack("red")
local overList = Kit.new("ScrollingFrame", {
	Position = UDim2.fromScale(0.02, 0.14), Size = UDim2.fromScale(0.96, 0.83), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 7, ScrollBarImageColor3 = Color3.fromRGB(200, 215, 240), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 11,
}, over)
Kit.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12) }, overList)
Kit.new("UIGridLayout", { CellSize = UDim2.new(0.485, 0, 0, 74), CellPadding = UDim2.new(0.03, 0, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, overList)

local function showOver(on)
	if on then
		over.Visible = true
		over.Position = UDim2.fromScale(0.02, 1.2)
		tween(over, 0.35, { Position = UDim2.fromScale(0.02, 0.155) }, Enum.EasingStyle.Back)
	else
		tween(over, 0.22, { Position = UDim2.fromScale(0.02, 1.2) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
			if over.Position.Y.Scale > 1 then over.Visible = false end
		end)
	end
end
back.Activated:Connect(function() showOver(false) end)

------------------------------------------------------------------------------------------
-- showing a profile
------------------------------------------------------------------------------------------
local current = nil -- the packet being shown
local model = nil
local modelBase = nil
local yaw, yawTarget = 0, 0
local loadToken = 0

local IDLE_R15 = "rbxassetid://507766666"
local IDLE_R6 = "rbxassetid://180435571"

local function clearModel()
	if model then model:Destroy() end
	model = nil
	thumbFallback.Visible = false
end

local function prepare(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ForceField") or d:IsA("Tool") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = d.Name == "HumanoidRootPart"
			d.CanCollide = false
		end
	end
	local humanoid = m:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.PlatformStand = false
	end
	return humanoid
end

local function showModel(m)
	clearModel()
	model = m
	local humanoid = prepare(m)
	m:PivotTo(CFrame.new(0, 0, 0))
	m.Parent = world
	local cf, size = m:GetBoundingBox()
	-- stand them in the middle, facing the camera
	modelBase = CFrame.new(-cf.Position) -- (characters face -Z, the camera sits at -Z looking back at them)
	m:PivotTo(modelBase)
	local height = math.max(size.Y, 4)
	local dist = height / 2 / math.tan(math.rad(cam.FieldOfView / 2)) * 1.15
	cam.CFrame = CFrame.lookAt(Vector3.new(0, height * 0.02, -dist), Vector3.new(0, 0, 0))
	-- idle animation
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		local anim = Instance.new("Animation")
		anim.AnimationId = humanoid.RigType == Enum.HumanoidRigType.R15 and IDLE_R15 or IDLE_R6
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if ok and track then
			track.Looped = true
			track:Play(0)
		end
	end
	-- pop in
	yaw = 0
end

local function loadCharacter(packet, token)
	clearModel()
	loading.Visible = true
	-- someone in this server: copy their character as they look right now
	local target = Players:GetPlayerByUserId(packet.userId)
	local character = target and target.Character
	if character then
		local was = character.Archivable
		character.Archivable = true
		local copy = character:Clone()
		character.Archivable = was
		if copy and token == loadToken then
			loading.Visible = false
			showModel(copy)
			return
		end
	end
	-- anyone else: build them from their avatar
	local ok, built = pcall(function() return Players:CreateHumanoidModelFromUserId(packet.userId) end)
	if token ~= loadToken then
		if ok and built then built:Destroy() end
		return
	end
	loading.Visible = false
	if ok and built then
		showModel(built)
	else
		-- last resort: their avatar picture
		local okT, img = pcall(function()
			return Players:GetUserThumbnailAsync(packet.userId, Enum.ThumbnailType.AvatarThumbnail, Enum.ThumbnailSize.Size420x420)
		end)
		thumbFallback.Image = okT and img or ""
		thumbFallback.Visible = true
	end
end

local function achievementsDone(stats)
	local n = 0
	for _, a in ipairs(ProfileConfig.Achievements) do
		if ProfileConfig.done(stats, a.id) then n += 1 end
	end
	return n
end

local function paintTitleBadge(stats)
	local t = ProfileConfig.TitleById[stats.Title or ""] or ProfileConfig.Titles[1]
	titleText.Text = t.text
	titleGrad.Color = ColorSequence.new(t.color:Lerp(Color3.new(1, 1, 1), 0.3), t.color:Lerp(Color3.new(0, 0, 0), 0.25))
end

local function show(packet)
	current = packet
	loadToken += 1
	local token = loadToken
	local stats = packet.stats
	displayName.Text = packet.displayName
	userName.Text = "@" .. packet.name
	statusLabel.Text = packet.online and "\u{25CF} In this server" or "\u{25CF} Offline"
	statusLabel.TextColor3 = packet.online and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(190, 190, 200)
	paintTitleBadge(stats)
	headshot.Image = ""
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(packet.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and token == loadToken then headshot.Image = img end
	end)
	-- stats slide in one after another
	for i, r in ipairs(statRows) do
		r.value.Text = formatStat(stats[r.stat.key], r.stat.format)
		r.row.Position = UDim2.fromScale(-0.15, 0)
		r.row.BackgroundTransparency = 1
		task.delay(0.04 * i, function()
			tween(r.row, 0.3, { Position = UDim2.fromScale(0, 0), BackgroundTransparency = 0 }, Enum.EasingStyle.Back)
		end)
	end
	achLabel.Text = "Achievements " .. achievementsDone(stats) .. "/" .. #ProfileConfig.Achievements
	meButton.Visible = packet.userId ~= player.UserId
	showOver(false)
	task.spawn(loadCharacter, packet, token)
end

local busy = false
local function lookup(query)
	if busy then return end
	busy = true
	loading.Visible = true
	local ok, packet = pcall(function() return getProfile:InvokeServer(query) end)
	busy = false
	loading.Visible = false
	if ok and type(packet) == "table" and packet.ok then
		show(packet)
		Kit.pop(nameCard, 1.06)
	elseif ok and type(packet) == "table" and packet.reason == "never" and packet.userId then
		-- a real Roblox player who hasn't played yet: show them with empty stats
		local empty = { Title = "" }
		for _, s in ipairs(ProfileConfig.Stats) do empty[s.key] = 0 end
		empty.RuneBulk, empty.RuneSpeed, empty.RuneLuck = 1, 1, 1
		show({ ok = true, userId = packet.userId, name = packet.name, displayName = packet.name, stats = empty, online = false })
		statusLabel.Text = "\u{25CF} Hasn't played yet"
		Kit.pop(nameCard, 1.06)
	else
		local reason = ok and type(packet) == "table" and packet.reason
		box.Text = ""
		box.PlaceholderText = reason == "never" and "They haven't played yet!" or reason == "slow" and "Slow down a sec..." or "Player not found"
		Kit.pop(search, 0.9)
		task.delay(2, function() box.PlaceholderText = "Search any player..." end)
	end
end

goButton.Activated:Connect(function() lookup(box.Text) end)
box.FocusLost:Connect(function(enter) if enter then lookup(box.Text) end end)
meButton.Activated:Connect(function() box.Text = "" lookup(nil) end)

------------------------------------------------------------------------------------------
-- Titles + Achievements lists
------------------------------------------------------------------------------------------
local function clearList()
	for _, c in ipairs(overList:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

local function listCard(i, color)
	local f = Kit.new("Frame", { LayoutOrder = i, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, overList)
	Kit.corner(f, 0.2)
	Kit.stroke(f, 3, INK, true)
	Kit.gradient(f, color:Lerp(Color3.new(1, 1, 1), 0.2), color:Lerp(Color3.new(0, 0, 0), 0.35))
	f.Position = UDim2.fromOffset(0, 20)
	return f
end

local function openTitles()
	if not current then return end
	clearList()
	local stats = current.stats
	local mine = current.userId == player.UserId
	overTitle.Text = mine and "Your Titles" or (current.displayName .. "'s Titles")
	for i, t in ipairs(ProfileConfig.Titles) do
		local unlocked = ProfileConfig.titleUnlocked(stats, t.id)
		local f = listCard(i, unlocked and t.color or Color3.fromRGB(80, 85, 100))
		Kit.text(f, {
			Text = t.text, Position = UDim2.fromScale(0.05, 0.1), Size = UDim2.fromScale(0.6, 0.45), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3, ZIndex = 13,
		})
		local from = t.from and ProfileConfig.AchievementById[t.from]
		Kit.text(f, {
			Text = unlocked and "Unlocked!" or ("\u{1F512} " .. (from and from.text or "")), Position = UDim2.fromScale(0.05, 0.58),
			Size = UDim2.fromScale(0.6, 0.3), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(235, 240, 250), Stroke = 2, ZIndex = 13,
		})
		if mine and unlocked then
			local equipped = (stats.Title or "") == t.id or ((stats.Title or "") == "" and i == 1)
			local b, paint = Kit.button(f, {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromScale(0.3, 0.55), ZIndex = 13,
			}, equipped and "Equipped" or "Equip")
			paint(equipped and "grey" or "green")
			b.Activated:Connect(function()
				local ok, r = pcall(function() return equipTitle:InvokeServer(i == 1 and "" or t.id) end)
				if ok and r and r.ok then
					stats.Title = i == 1 and "" or t.id
					paintTitleBadge(stats)
					openTitles()
				end
			end)
		end
		task.delay(0.03 * i, function() tween(f, 0.3, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back) end)
	end
	showOver(true)
end

local function openAchievements()
	if not current then return end
	clearList()
	local stats = current.stats
	overTitle.Text = "Achievements " .. achievementsDone(stats) .. "/" .. #ProfileConfig.Achievements
	for i, a in ipairs(ProfileConfig.Achievements) do
		local have = tonumber(stats[a.stat]) or 0
		local done = have >= a.goal
		local f = listCard(i, done and Color3.fromRGB(70, 190, 90) or Color3.fromRGB(70, 80, 110))
		Kit.text(f, {
			Text = (done and "\u{2713} " or "") .. a.name, Position = UDim2.fromScale(0.04, 0.06), Size = UDim2.fromScale(0.92, 0.36), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3, ZIndex = 13,
		})
		Kit.text(f, {
			Text = a.text, Position = UDim2.fromScale(0.04, 0.42), Size = UDim2.fromScale(0.55, 0.22), TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(225, 232, 245), Stroke = 2, ZIndex = 13,
		})
		local barBack = Kit.new("Frame", {
			Position = UDim2.fromScale(0.04, 0.7), Size = UDim2.fromScale(0.92, 0.2), BackgroundColor3 = Color3.fromRGB(15, 20, 35), ZIndex = 13,
		}, f)
		Kit.corner(barBack, 1)
		local fill = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 14 }, barBack)
		Kit.corner(fill, 1)
		Kit.gradient(fill, Color3.fromRGB(170, 255, 140), Color3.fromRGB(50, 190, 70), 0)
		local fmt = a.stat == "TimePlayed" and "time" or (a.stat == "RobuxSpent" and "robux" or "number")
		Kit.text(barBack, {
			Text = formatStat(math.min(have, a.goal), fmt) .. " / " .. formatStat(a.goal, fmt), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.95, 1.3), Stroke = 2, ZIndex = 15,
		})
		task.delay(0.03 * i, function()
			tween(f, 0.3, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
			tween(fill, 0.6, { Size = UDim2.fromScale(math.clamp(have / a.goal, 0, 1), 1) }, Enum.EasingStyle.Quart)
		end)
	end
	showOver(true)
end

titlesButton.Activated:Connect(openTitles)
achButton.Activated:Connect(openAchievements)

------------------------------------------------------------------------------------------
-- the character turns to follow your cursor, and breathes a little
------------------------------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	if not gui.Enabled or not model or not modelBase then return end
	local mouse = UserInputService:GetMouseLocation()
	local a, s = stage.AbsolutePosition, stage.AbsoluteSize
	if s.X > 0 then
		-- -1 (far left) .. 1 (far right) of the stage, clamped so they never turn their back
		local k = math.clamp((mouse.X - (a.X + s.X / 2)) / (s.X * 0.9), -1, 1)
		yawTarget = k * math.rad(55)
	end
	yaw += (yawTarget - yaw) * math.min(1, dt * 7)
	model:PivotTo(modelBase * CFrame.Angles(0, -yaw, 0))
	glow.Rotation += dt * 10
end)

------------------------------------------------------------------------------------------
-- open / close
------------------------------------------------------------------------------------------
local isOpen = false

local function open(query)
	if not isOpen then
		isOpen = true
		gui.Enabled = true
		openScale.Scale = 0.6
		tween(openScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(dim, 0.25, { BackgroundTransparency = 0.45 })
		Kit.pop(headerIcon, 1.4)
	end
	lookup(query)
end

local function hide()
	if not isOpen then return end
	isOpen = false
	tween(dim, 0.15, { BackgroundTransparency = 1 })
	tween(openScale, 0.16, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
		if not isOpen then
			gui.Enabled = false
			clearModel()
		end
	end)
end

close.Activated:Connect(hide)
dim.Activated:Connect(hide)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and isOpen and input.KeyCode == Enum.KeyCode.Escape then hide() end
end)

-- the old Profile gui is replaced by this one
task.spawn(function()
	local old = playerGui:WaitForChild("Profile", 10)
	if old and old:IsA("ScreenGui") then old.Enabled = false end
end)

-- the Profile button on the left
task.spawn(function()
	local side = playerGui:WaitForChild("Buttons"):WaitForChild("SideContainer")
	local function hook(b)
		if b and b:IsA("GuiButton") and not b:GetAttribute("ProfileHooked") then
			b:SetAttribute("ProfileHooked", true)
			b.Activated:Connect(function()
				if isOpen then hide() else open(nil) end
			end)
		end
	end
	hook(side:FindFirstChild("Profile", true))
	side.DescendantAdded:Connect(function(d) if d.Name == "Profile" then hook(d) end end)
end)

-- anything else can open it: HudActions:Fire("Profile", "name")
local hudActions = ReplicatedStorage:FindFirstChild("HudActions")
if hudActions then
	hudActions.Event:Connect(function(action, query)
		if action == "Profile" then open(query) end
	end)
end
