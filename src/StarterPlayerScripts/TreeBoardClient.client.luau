-- Drives the Tree board next to the Blue Button (Workspace.TreeUpgradeBoard.TreeUI).
-- The arrows pick which tree the Blue Button chops: any tree you've reached (Tier Up unlocks more).
-- Single-step arrows are green when you can move that way, gray when you can't.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local IslandTwoConfig = require(ReplicatedStorage:WaitForChild("IslandTwoConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local woodChop = remotes:WaitForChild("WoodChop")
local selectTree = remotes:WaitForChild("SelectTree")

local board = workspace:WaitForChild("TreeUpgradeBoard")
local stage = board:WaitForChild("TreeUI"):WaitForChild("Stage")

local title = stage:WaitForChild("TreeTitle")
local titleShadow = stage:WaitForChild("TreeTitleShadow")
local tierLabel = stage:WaitForChild("TierAmount")
local treesBeaten = stage:WaitForChild("TreesBeaten")
local bigIcon = stage:WaitForChild("BigIcon")
local shadowIcon = stage:WaitForChild("ShadowBigIcon")
local sunray = stage:WaitForChild("Sunray")
local bars = stage:WaitForChild("ProgressBar")
local fill = bars:WaitForChild("ProgressBarUnder"):WaitForChild("ProgressBar")
local hpText = bars.ProgressBarUnder:WaitForChild("HPCount")
local woodAmount = bars:WaitForChild("Gains"):WaitForChild("Wood"):WaitForChild("Amount")
local popTemplate = stage:WaitForChild("MoneyGained")
local starTemplate = stage:WaitForChild("Star")

local arrows = {
	left = stage:WaitForChild("GoDown1"),
	first = stage:WaitForChild("GoDownMax"),
	right = stage:WaitForChild("GoUp1"),
	last = stage:WaitForChild("GoUpMax"),
}

stage:WaitForChild("TextLabelWhite").Visible = false -- leftover "$1,700" label from the original UI

local FILL_WIDTH = fill.Size.X.Scale
local ICON_SIZE = bigIcon.Size
local DEFAULT_ICON = bigIcon.Image
local SHADOW_SIZE = shadowIcon.Size
local quick = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local numTrees = #IslandTwoConfig.Tiers

------------------------------------------------------------------------------------------
-- arrow colours
------------------------------------------------------------------------------------------
local function seq(top, mid, bottom)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(0.51, mid),
		ColorSequenceKeypoint.new(1, bottom),
	})
end

local GREEN = {
	gradient = seq(Color3.fromRGB(170, 255, 130), Color3.fromRGB(110, 235, 90), Color3.fromRGB(60, 200, 60)),
	back = Color3.fromRGB(35, 140, 45),
	stroke = Color3.fromRGB(18, 70, 24),
}
local GRAY = {
	gradient = seq(Color3.fromRGB(205, 205, 210), Color3.fromRGB(170, 170, 175), Color3.fromRGB(135, 135, 140)),
	back = Color3.fromRGB(95, 95, 100),
	stroke = Color3.fromRGB(45, 45, 50),
}

-- the double arrows keep their original look while usable
local function captureLook(button)
	return {
		gradient = button.MainFrame.UIGradient.Color,
		back = button.BackgroundColor3,
		stroke = button.UIStroke.Color,
	}
end
local ORIGINAL = { first = captureLook(arrows.first), last = captureLook(arrows.last) }

local function paint(button, look)
	button.BackgroundColor3 = look.back
	button.UIStroke.Color = look.stroke
	button.MainFrame.UIGradient.Color = look.gradient
	button.MainFrame.UIStroke.Color = look.stroke
	local g = button:FindFirstChildOfClass("UIGradient")
	if g then g.Color = look.gradient end
	local shadow = button:FindFirstChild("Shadow")
	local sg = shadow and shadow:FindFirstChildOfClass("UIGradient")
	if sg then sg.Color = look.gradient end
end

local function setArrow(key, enabled)
	local button = arrows[key]
	button.Active = enabled
	button.AutoButtonColor = false
	if key == "left" or key == "right" then
		paint(button, enabled and GREEN or GRAY)
	else
		paint(button, enabled and ORIGINAL[key] or GRAY)
	end
	for _, d in ipairs(button.MainFrame:GetChildren()) do
		if d:IsA("ImageLabel") and d.Name == "Image" then
			d.ImageTransparency = enabled and 0 or 0.45
		end
	end
end

------------------------------------------------------------------------------------------
-- state
------------------------------------------------------------------------------------------
local function highestTier()
	return math.clamp(player:GetAttribute("TreeTier") or 1, 1, numTrees)
end

local pending = nil -- a tree we asked for that the server hasn't confirmed yet
local pendingAt = 0

local function selectedTree()
	if pending and os.clock() - pendingAt < 1.5 then
		return pending
	end
	pending = nil
	local _, index = IslandTwoConfig.selected(player)
	return index
end

local function treeIsDown()
	return (player:GetAttribute("TreeRespawnAt") or 0) > workspace:GetServerTimeNow()
end

local fillTween
local function setFill(ratio)
	if fillTween then fillTween:Cancel() end
	fillTween = TweenService:Create(fill, quick, {
		Size = UDim2.new(FILL_WIDTH * math.clamp(ratio, 0, 1), 0, fill.Size.Y.Scale, fill.Size.Y.Offset),
	})
	fillTween:Play()
end

local function refresh()
	local index = selectedTree()
	local tier = IslandTwoConfig.Tiers[index]
	local highest = highestTier()

	title.Text = tier.name
	titleShadow.Text = tier.name
	tierLabel.Text = "Tier " .. index
	bigIcon.Image = tier.image or DEFAULT_ICON
	shadowIcon.Image = bigIcon.Image
	treesBeaten.Text = NumberFormat.abbreviate(player:GetAttribute("TreesBeaten") or 0)
	woodAmount.Text = "+" .. NumberFormat.abbreviate(IslandTwoConfig.woodForTier(player, index))

	local maxHp = IslandTwoConfig.maxHPForTier(index)
	if treeIsDown() then
		local left = math.ceil((player:GetAttribute("TreeRespawnAt") or 0) - workspace:GetServerTimeNow())
		hpText.Text = "Growing back... " .. math.max(left, 0) .. "s"
		setFill(0)
	else
		local hp = pending and maxHp or math.min(player:GetAttribute("TreeHP") or maxHp, maxHp)
		hpText.Text = NumberFormat.abbreviate(hp) .. " / " .. NumberFormat.abbreviate(maxHp) .. " HP"
		setFill(maxHp > 0 and hp / maxHp or 0)
	end

	-- you can only move onto trees you've reached
	setArrow("left", index > 1)
	setArrow("first", index > 1)
	setArrow("right", index < highest)
	setArrow("last", index < highest)
end

------------------------------------------------------------------------------------------
-- tree icon animations (every tween cancels the last one, so spamming can't stack them)
------------------------------------------------------------------------------------------
local iconTween, shadowTween
local function tweenIcons(info, iconGoal, shadowGoal)
	if iconTween then iconTween:Cancel() end
	if shadowTween then shadowTween:Cancel() end
	iconTween = TweenService:Create(bigIcon, info, iconGoal)
	iconTween:Play()
	if shadowGoal then
		shadowTween = TweenService:Create(shadowIcon, info, shadowGoal)
		shadowTween:Play()
	end
end

local function scaled(size, k)
	return UDim2.new(size.X.Scale * k, 0, size.Y.Scale * k, 0)
end

local function popTree()
	bigIcon.Rotation, shadowIcon.Rotation = 0, 0
	bigIcon.Size = scaled(ICON_SIZE, 0.85)
	shadowIcon.Size = SHADOW_SIZE
	tweenIcons(TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = ICON_SIZE })
end

local function hitTree()
	bigIcon.Size = scaled(ICON_SIZE, 0.9)
	tweenIcons(TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = ICON_SIZE })
end

local function knockDown()
	tweenIcons(TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Size = UDim2.fromScale(0, 0), Rotation = 25 },
		{ Size = UDim2.fromScale(0, 0), Rotation = 25 })
end

local function growBack()
	bigIcon.Rotation, shadowIcon.Rotation = 0, 0
	tweenIcons(TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = ICON_SIZE, Rotation = 0 },
		{ Size = SHADOW_SIZE, Rotation = 0 })
end

------------------------------------------------------------------------------------------
-- arrows
------------------------------------------------------------------------------------------
local lastArrowClick = 0

local function goTo(index)
	index = math.clamp(index, 1, highestTier())
	if index == selectedTree() then
		return
	end
	pending, pendingAt = index, os.clock()
	selectTree:FireServer(index)
	if not treeIsDown() then
		popTree()
	end
	refresh()
end

local function hookArrow(button, step)
	local base = button.Size
	local sizeTween
	local function sizeTo(goal, info)
		if sizeTween then sizeTween:Cancel() end
		sizeTween = TweenService:Create(button, info or quick, { Size = goal })
		sizeTween:Play()
	end

	button.MouseButton1Click:Connect(function()
		if not button.Active then
			return
		end
		local now = os.clock()
		if now - lastArrowClick < 0.2 then
			return -- no spamming the arrows
		end
		lastArrowClick = now
		goTo(step(selectedTree()))
		button.Size = scaled(base, 0.85)
		sizeTo(base, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
	end)
	button.MouseEnter:Connect(function()
		if button.Active then
			sizeTo(scaled(base, 1.08))
		end
	end)
	button.MouseLeave:Connect(function()
		sizeTo(base)
	end)
end

hookArrow(arrows.left, function(i) return i - 1 end)
hookArrow(arrows.right, function(i) return i + 1 end)
hookArrow(arrows.first, function() return 1 end)
hookArrow(arrows.last, function() return highestTier() end)

------------------------------------------------------------------------------------------
-- hit popups (capped so spamming can't pile them up)
------------------------------------------------------------------------------------------
local MAX_POPUPS = 6
local livePopups = 0

local function popup(damage)
	if livePopups >= MAX_POPUPS then
		return
	end
	livePopups += 1

	local label = popTemplate:Clone()
	label.Text = "-" .. NumberFormat.abbreviate(damage) .. "HP"
	label.Position = UDim2.fromScale(0.5 + math.random(-60, 60) / 1000, 0.5 + math.random(-40, 40) / 1000)
	label.Rotation = math.random(-12, 12)
	label.Visible = true
	label.Parent = stage
	local stroke = label:FindFirstChildOfClass("UIStroke")
	local rise = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(label, rise, { Position = label.Position - UDim2.fromScale(0, 0.15), TextTransparency = 1 }):Play()
	if stroke then
		TweenService:Create(stroke, rise, { Transparency = 1 }):Play()
	end

	local star = starTemplate:Clone()
	local starSize = star.Size
	star.Size = UDim2.fromScale(0, 0)
	star.Position = label.Position
	star.Visible = true
	star.Parent = stage
	TweenService:Create(star, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = starSize }):Play()
	task.delay(0.3, function()
		TweenService:Create(star, TweenInfo.new(0.12), { Size = UDim2.fromScale(0, 0) }):Play()
	end)

	task.delay(0.65, function()
		label:Destroy()
		star:Destroy()
		livePopups -= 1
	end)
end

------------------------------------------------------------------------------------------
-- "+X [wood]" floating up from the tree when it's chopped down
------------------------------------------------------------------------------------------
local woodIcon = bars.Gains.Wood:WaitForChild("Icon")

local function woodPopup(wood)
	local holder = Instance.new("Frame")
	holder.Name = "WoodGain"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.3, 0.12)
	holder.ZIndex = 20

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = holder

	local label = popTemplate:Clone()
	label.Name = "Amount"
	label.Visible = true
	label.AnchorPoint = Vector2.new(0, 0)
	label.Position = UDim2.new()
	label.Rotation = 0
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.TextScaled = true
	label.Text = "+" .. NumberFormat.abbreviate(wood)
	label.TextColor3 = Color3.fromRGB(255, 205, 120)
	label.LayoutOrder = 1
	label.ZIndex = 21
	local ratio = label:FindFirstChildOfClass("UIAspectRatioConstraint")
	if ratio then ratio:Destroy() end
	local gradient = label:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(Color3.fromRGB(255, 235, 170), Color3.fromRGB(235, 150, 60))
		gradient.Rotation = 90
	end
	label.Parent = holder

	local icon = woodIcon:Clone()
	icon.AnchorPoint = Vector2.new(0, 0)
	icon.Position = UDim2.new()
	icon.Size = UDim2.fromScale(1, 1)
	icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	icon.LayoutOrder = 2
	icon.ZIndex = 21
	icon.Parent = holder

	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = holder
	holder.Parent = stage

	local stroke = label:FindFirstChildOfClass("UIStroke")

	-- pop in, float up with a little sway, then fade away
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.15 }):Play()
	task.delay(0.35, function()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	end)
	TweenService:Create(holder, TweenInfo.new(1.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.3),
	}):Play()
	holder.Rotation = -6
	TweenService:Create(holder, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true), { Rotation = 6 }):Play()

	task.delay(0.9, function()
		local fade = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(icon, fade, { ImageTransparency = 1 }):Play()
		if stroke then
			TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		end
		TweenService:Create(scale, fade, { Scale = 0.8 }):Play()
	end)
	task.delay(1.5, function()
		holder:Destroy()
	end)
end

woodChop.OnClientEvent:Connect(function(damage, hp, _, wood)
	pending = nil
	refresh()
	popup(damage)
	if wood then
		task.delay(0.2, woodPopup, wood)
	end
	if hp and hp <= 0 then
		knockDown()
	else
		hitTree()
	end
end)

player:GetAttributeChangedSignal("SelectedTree"):Connect(function()
	pending = nil
	refresh()
end)
for _, attribute in ipairs({ "TreeTier", "TreeHP", "TreeMaxHP", "TreeRespawnAt", "TreesBeaten", "Wood" }) do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end

-- sunray spin + the respawn countdown
local wasDown = treeIsDown()
local lastSecond = -1
RunService.RenderStepped:Connect(function(dt)
	sunray.Rotation = (sunray.Rotation + dt * 75) % 360
	local down = treeIsDown()
	if wasDown and not down then
		growBack()
		refresh()
	elseif down then
		local sec = math.floor(workspace:GetServerTimeNow())
		if sec ~= lastSecond then
			lastSecond = sec
			refresh()
		end
	end
	wasDown = down
end)

if treeIsDown() then
	bigIcon.Size, shadowIcon.Size = UDim2.fromScale(0, 0), UDim2.fromScale(0, 0)
end
refresh()
