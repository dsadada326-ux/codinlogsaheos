-- Skill Tree UI (ported from the old game's SkillTreeManager). Opened from the Skill Tree button.
--   Nodes sit on a hex grid growing out of the Root. You see what you own, what you can buy next,
--   and one more step as "?". Hover a node for its info card, click to buy a level (Stars).
--   Drag to move, scroll / pinch / triggers to zoom. The button gets a badge when you can afford
--   something. Stars pill = your Stars; timer pill = the next Stars payout.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SkillTreeConfig = require(ReplicatedStorage:WaitForChild("SkillTreeConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local buyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuySkillNode")

local gui = playerGui:WaitForChild("SkillTree")
local container = gui:WaitForChild("Container")
local background = container:WaitForChild("Background")
local lockedOverlay = container:WaitForChild("LockedOverlay")
local moving = container:WaitForChild("MovingContainer")
local info = container:WaitForChild("UpgradeInfo")
local template = moving:WaitForChild("UpgradeTemplate")
local closeButton = container:WaitForChild("CloseButton")
local starsPill = container:WaitForChild("StarsPill")
local timerPill = container:WaitForChild("TimerPill")
local hint = container:FindFirstChild("Hint")
local pattern = background:FindFirstChild("Pattern")
local particlesFrame = background:FindFirstChild("Particles")

local openButton = playerGui:WaitForChild("Buttons"):WaitForChild("Container"):WaitForChild("SkillTree")
local badge = openButton:FindFirstChild("Notification")
local uiBlur = Lighting:FindFirstChild("UiBlur")

local STARS = SkillTreeConfig.Currency
local STAR_ICON = SkillTreeConfig.CurrencyIcon
local abbreviate = NumberFormat.abbreviate

local function setPillText(pill, text)
	local label = pill:FindFirstChild("Label")
	if not label then return end
	label.Text = text
	local extra = label:FindFirstChild("Extra")
	if extra then extra.Text = text end
end

local function stars()
	return player:GetAttribute(STARS) or 0
end

------------------------------------------------------------------------------------------
-- levels (read live from the Skill_ attributes)
------------------------------------------------------------------------------------------
local levels = SkillTreeConfig.levels(player)

local function refreshLevels()
	levels = SkillTreeConfig.levels(player)
end

------------------------------------------------------------------------------------------
-- timer pill: "+1 in 04:59"
------------------------------------------------------------------------------------------
local function refreshTimer()
	local nextAt = player:GetAttribute("StarsNextAt")
	local left = nextAt and math.max(math.floor(nextAt - workspace:GetServerTimeNow() + 0.5), 0) or 0
	local amount = abbreviate(SkillTreeConfig.starAmount(player))
	setPillText(timerPill, string.format("+%s in %02d:%02d", amount, left // 60, left % 60))
end

task.spawn(function()
	while true do
		refreshTimer()
		task.wait(1)
	end
end)

------------------------------------------------------------------------------------------
-- stars pill
------------------------------------------------------------------------------------------
local starsIcon = starsPill:FindFirstChild("Icon")
if starsIcon then starsIcon.Image = STAR_ICON end

local starsScale = starsPill:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
starsScale.Parent = starsPill

local popInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function refreshStarsPill(bump)
	setPillText(starsPill, abbreviate(stars()))

	if bump then
		starsScale.Scale = 1.15
		TweenService:Create(starsScale, popInfo, { Scale = 1 }):Play()
	end
end

refreshStarsPill(false)

------------------------------------------------------------------------------------------
-- layout
------------------------------------------------------------------------------------------
template.Visible = false
info.Visible = false
moving.Active = false
lockedOverlay.Visible = false
moving.Visible = true

local positions = {} -- [id] = Vector2 (scale inside MovingContainer)

local function nodePosition(id)
	local cached = positions[id]
	if cached then return cached end

	local node = SkillTreeConfig.Nodes[id]
	local pos

	if node and node.Requires and node.Direction then
		local parent = nodePosition(node.Requires)
		local dir = SkillTreeConfig.DirectionOffsets[node.Direction] or Vector2.zero
		local size = moving.AbsoluteSize
		local step = dir * ((SkillTreeConfig.HexStepScale or 0.035) * size.Y)
		pos = parent + Vector2.new(size.X > 0 and step.X / size.X or 0, size.Y > 0 and step.Y / size.Y or 0)
	else
		pos = Vector2.new(0.5, 0.5)
	end

	positions[id] = pos
	return pos
end

-- steps from this node back to the nearest node you own (0 = owned, 1 = buyable next, 2 = "?")
local function distance(id)
	local steps = 0
	local guard = 0

	while id and guard < 64 do
		if (levels[id] or 0) > 0 then
			return steps
		end

		local node = SkillTreeConfig.Nodes[id]
		id = node and node.Requires
		steps += 1
		guard += 1
	end

	return math.huge
end

local function canBuy(id, node)
	local d = distance(id)
	local lvl = levels[id] or 0

	if d == 1 then
		return true
	elseif d == 0 then
		return lvl < (node.Levels or 1)
	end

	return false
end

local function canAffordAny()
	local balance = stars()

	for id, node in pairs(SkillTreeConfig.Nodes) do
		if canBuy(id, node) and SkillTreeConfig.priceForLevel(node, (levels[id] or 0) + 1) <= balance then
			return true
		end
	end

	return false
end

local function refreshBadge()
	if badge then
		badge.Visible = canAffordAny()
	end
end

------------------------------------------------------------------------------------------
-- node visuals
------------------------------------------------------------------------------------------
local FILL = {
	Maxed = { Color3.fromRGB(255, 230, 100), Color3.fromRGB(228, 140, 16) },
	Available = { Color3.fromRGB(110, 255, 150), Color3.fromRGB(46, 180, 10) },
	Expensive = { Color3.fromRGB(165, 175, 190), Color3.fromRGB(78, 88, 104) },
}
local GLOW = {
	Maxed = Color3.fromRGB(255, 205, 60),
	Available = Color3.fromRGB(120, 255, 120),
}
local TITLE = {
	Maxed = { Color3.fromRGB(255, 240, 150), Color3.fromRGB(245, 165, 30) },
	Available = { Color3.fromRGB(190, 255, 180), Color3.fromRGB(80, 215, 60) },
	Expensive = { Color3.fromRGB(240, 240, 250), Color3.fromRGB(165, 170, 185) },
	Locked = { Color3.fromRGB(185, 185, 200), Color3.fromRGB(115, 115, 135) },
}
local RED = Color3.fromRGB(255, 110, 110)
local GOLD = Color3.fromRGB(255, 215, 70)
local WHITE = Color3.new(1, 1, 1)
local PILL_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

local baseSize = template.Size
local nodes = {} -- [id] = the node's ImageButton
local glows = {} -- [id] = glow image behind it
local anim = {} -- [id] = { Hover, Pop, Phase }
local states = {} -- [id] = "Maxed" / "Available" / "Expensive" / "Locked"

local function stateOf(id, node, d)
	if d >= 2 then
		return "Locked"
	end

	local lvl = levels[id] or 0

	if d == 0 and lvl >= (node.Levels or 1) then
		return "Maxed"
	end

	return stars() >= SkillTreeConfig.priceForLevel(node, lvl + 1) and "Available" or "Expensive"
end

local function makeLevelPill(button)
	local frame = Instance.new("Frame")
	frame.Name = "LevelPill"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.17)
	frame.Size = UDim2.fromScale(0.5, 0.17)
	frame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
	frame.BackgroundTransparency = 0.15
	frame.ZIndex = 5

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.5)
	text.Size = UDim2.fromScale(0.86, 0.82)
	text.FontFace = PILL_FONT
	text.TextScaled = true
	text.TextColor3 = WHITE
	text.ZIndex = 6
	local textStroke = Instance.new("UIStroke")
	textStroke.Thickness = 1
	textStroke.Parent = text
	text.Parent = frame

	frame.Parent = button
end

local function makeGlow(id, button)
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow_" .. id
	glow.BackgroundTransparency = 1
	glow.Image = template.Image
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = button.Position
	glow.Size = baseSize
	glow.ZIndex = 1
	glow.Visible = false

	local aspect = template:FindFirstChildOfClass("UIAspectRatioConstraint")
	if aspect then aspect:Clone().Parent = glow end

	glow.Parent = moving
	glows[id] = glow
end

local function paintNode(id, node, button, d)
	local state = stateOf(id, node, d)
	states[id] = state

	local lvl = levels[id] or 0
	local maxLevel = node.Levels or 1

	local locked = button:FindFirstChild("Locked")
	if locked then
		locked.Visible = state == "Locked"
		local lockedText = locked:FindFirstChild("LockedText", true)
		if lockedText then lockedText.Text = "?" end
	end

	local unlocked = button:FindFirstChild("Unlocked")
	if unlocked then
		unlocked.Visible = state ~= "Locked"

		local fill = FILL[state]
		if fill then
			local seq = ColorSequence.new(fill[1], fill[2])
			local g = unlocked:FindFirstChildOfClass("UIGradient")
			if g then g.Color = seq end

			local inner = unlocked:FindFirstChild("Container")
			local ig = inner and inner:FindFirstChildOfClass("UIGradient")
			if ig then ig.Color = seq end
		end

		local icon = unlocked:FindFirstChild("UpgradeIconImage", true)
		if icon then icon.Image = node.Icon or "" end

		local price = unlocked:FindFirstChild("Price", true)
		if price then
			price.Visible = state == "Available" or state == "Expensive"

			local cur = price:FindFirstChild("CurrencyIconImage", true)
			if cur then cur.Image = STAR_ICON end

			local amount = price:FindFirstChild("AmountLabel", true)
			if amount then
				amount.Text = abbreviate(SkillTreeConfig.priceForLevel(node, lvl + 1))
				amount.TextColor3 = state == "Expensive" and RED or WHITE
			end
		end
	end

	local pill = button:FindFirstChild("LevelPill")
	if pill then
		pill.Visible = state ~= "Locked" and maxLevel > 1

		local text = pill:FindFirstChild("Text")
		if text then
			text.Text = state == "Maxed" and "MAX" or string.format("%d/%d", lvl, maxLevel)
			text.TextColor3 = state == "Maxed" and GOLD or WHITE
		end
	end
end

------------------------------------------------------------------------------------------
-- info card (hover)
------------------------------------------------------------------------------------------
local titleLabel = info:FindFirstChild("TitleLabel", true)
local descriptionLabel = info:FindFirstChild("DescriptionLabel", true)
local levelBar = info:FindFirstChild("LevelBar", true)
local levelFill = levelBar and levelBar:FindFirstChild("Fill")
local levelLabel = levelBar and levelBar:FindFirstChild("LevelLabel")
local costLabel = info:FindFirstChild("CostLabel", true)
local infoPop = info:FindFirstChild("PopScale")
local infoFor = nil
local hovered = nil

local function hex(c)
	return string.format("#%02X%02X%02X", c.R * 255, c.G * 255, c.B * 255)
end

local function positionInfo(id)
	local pos = nodePosition(id)
	local size = moving.AbsoluteSize
	local point = moving.AbsolutePosition + Vector2.new(pos.X * size.X, pos.Y * size.Y)
	local button = nodes[id]
	local half = button and button.AbsoluteSize.X / 2 or 0

	local cPos = container.AbsolutePosition
	local cSize = container.AbsoluteSize
	local iSize = info.AbsoluteSize

	local x = point.X + half + 14
	local anchorX = 0

	if x + iSize.X > cPos.X + cSize.X - 8 then
		x = point.X - half - 14
		anchorX = 1
	end

	local halfH = iSize.Y / 2
	local y = math.clamp(point.Y, cPos.Y + halfH + 8, math.max(cPos.Y + cSize.Y - halfH - 8, cPos.Y + halfH + 8))

	info.AnchorPoint = Vector2.new(anchorX, 0.5)
	info.Position = UDim2.fromOffset(x - cPos.X, y - cPos.Y)
end

local function showInfo(id, node)
	local state = states[id] or "Locked"
	local lvl = levels[id] or 0
	local maxLevel = node.Levels or 1

	if titleLabel then
		titleLabel.Text = node.Name or id
		local g = titleLabel:FindFirstChildOfClass("UIGradient")
		local c = TITLE[state]
		if g and c then g.Color = ColorSequence.new(c[1], c[2]) end
	end

	if descriptionLabel then
		descriptionLabel.Text = node.Description or ""
	end

	if levelFill then
		local frac = maxLevel > 0 and math.clamp(lvl / maxLevel, 0, 1) or 0
		TweenService:Create(levelFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(frac, 1) }):Play()
		local g = levelFill:FindFirstChildOfClass("UIGradient")
		if g then
			local c = state == "Maxed" and FILL.Maxed or FILL.Available
			g.Color = ColorSequence.new(c[1], c[2])
		end
	end

	if levelLabel then
		levelLabel.Text = state == "Maxed" and "MAX LEVEL" or string.format("Level %d / %d", lvl, maxLevel)
	end

	if costLabel then
		costLabel.RichText = true

		if state == "Maxed" then
			costLabel.Text = string.format('<font color="%s">Fully upgraded!</font>', hex(GOLD))
		elseif state == "Locked" then
			local req = node.Requires and SkillTreeConfig.Nodes[node.Requires]
			costLabel.Text = string.format('<font color="#A8A8BE">Unlock %s first</font>', req and req.Name or "the previous node")
		else
			local price = SkillTreeConfig.priceForLevel(node, lvl + 1)
			local color = state == "Available" and "#7CFF6B" or hex(RED)
			costLabel.Text = string.format('Cost: <font color="%s">%s Stars</font>', color, abbreviate(price))
		end
	end

	positionInfo(id)

	if infoFor ~= id and infoPop then
		infoPop.Scale = 0.85
		TweenService:Create(infoPop, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	infoFor = id
	info.Visible = true
end

local function hideInfo()
	info.Visible = false
	infoFor = nil
end

------------------------------------------------------------------------------------------
-- buying + celebration
------------------------------------------------------------------------------------------
local renderAll, updateHover

local function celebrate(id, node)
	local a = anim[id]
	if a then a.Pop = 1 end

	local size = moving.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return end

	local pos = nodePosition(id)
	local lvl = levels[id] or 0
	local maxed = lvl >= (node.Levels or 1)
	local nodePx = baseSize.Y.Scale * size.Y
	local count = maxed and 16 or 10

	for i = 1, count do
		local star = Instance.new("ImageLabel")
		star.BackgroundTransparency = 1
		star.Image = STAR_ICON
		star.ImageColor3 = maxed and GOLD or WHITE
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		local px = nodePx * (0.18 + math.random() * 0.12)
		star.Size = UDim2.fromScale(px / size.X, px / size.Y)
		star.Position = UDim2.fromScale(pos.X, pos.Y)
		star.Rotation = math.random(0, 360)
		star.ZIndex = 4
		star.Parent = moving

		local angle = i / count * math.pi * 2 + (math.random() - 0.5) * 0.5
		local dist = nodePx * (0.9 + math.random() * 0.6) * (maxed and 1.35 or 1)
		local tween = TweenService:Create(star, TweenInfo.new(0.55 + math.random() * 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			ImageTransparency = 1,
			Position = UDim2.fromScale(pos.X + math.cos(angle) * dist / size.X, pos.Y + math.sin(angle) * dist / size.Y),
			Rotation = star.Rotation + 200,
			Size = UDim2.fromScale(star.Size.X.Scale * 0.4, star.Size.Y.Scale * 0.4),
		})
		tween.Completed:Once(function() star:Destroy() end)
		tween:Play()
	end

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(0.5, 1)
	text.Size = UDim2.fromScale(nodePx * 1.8 / size.X, nodePx * 0.42 / size.Y)
	text.Position = UDim2.fromScale(pos.X, pos.Y - nodePx * 0.45 / size.Y)
	text.FontFace = PILL_FONT
	text.TextScaled = true
	text.Text = maxed and "MAXED!" or ("LVL " .. lvl .. "!")
	text.TextColor3 = maxed and GOLD or Color3.fromRGB(140, 255, 120)
	text.ZIndex = 6
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = text
	text.Parent = moving

	TweenService:Create(text, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(pos.X, pos.Y - nodePx * 1.25 / size.Y),
	}):Play()
	local fade = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5)
	TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	local t = TweenService:Create(text, fade, { TextTransparency = 1 })
	t.Completed:Once(function() text:Destroy() end)
	t:Play()
end

local buying = false

local function tryBuy(id, node)
	if buying or not canBuy(id, node) then
		return
	end

	buying = true

	local ok, result = pcall(function()
		return buyRemote:InvokeServer(id)
	end)

	refreshLevels()

	if ok and type(result) == "table" and result.ok then
		celebrate(id, node)
	else
		MessageToPlayer.show("PurchaseUnavailable")
	end

	renderAll()
	updateHover()
	refreshBadge()
	refreshTimer()
	buying = false
end

------------------------------------------------------------------------------------------
-- rendering the nodes
------------------------------------------------------------------------------------------
local function clearNode(id)
	if nodes[id] then nodes[id]:Destroy() nodes[id] = nil end
	if glows[id] then glows[id]:Destroy() glows[id] = nil end
	anim[id] = nil
	states[id] = nil
end

local function renderNode(id, node, hiddenForIntro)
	local d = distance(id)

	if d > 2 then
		clearNode(id)
		return
	end

	local button = nodes[id]

	if not button then
		button = template:Clone()
		button.Name = id
		button.AnchorPoint = Vector2.new(0.5, 0.5)

		local intro = Instance.new("UIScale")
		intro.Name = "IntroScale"
		intro.Parent = button

		local pos = nodePosition(id)
		button.Position = UDim2.new(pos.X, 0, pos.Y, 0)
		button.Parent = moving
		nodes[id] = button

		makeLevelPill(button)
		makeGlow(id, button)
		anim[id] = { Hover = 0, Pop = 0, Phase = math.random() * math.pi * 2 }

		if hiddenForIntro then
			button.Visible = false
			intro.Scale = 0
		else
			button.Visible = true
			intro.Scale = 1
		end

		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				tryBuy(id, node)
			end
		end)
	end

	paintNode(id, node, button, d)
end

renderAll = function()
	for id, node in pairs(SkillTreeConfig.Nodes) do
		renderNode(id, node)
	end
end

------------------------------------------------------------------------------------------
-- intro: nodes pop in branch by branch when the tree opens
------------------------------------------------------------------------------------------
local depthCache = {}

local function depthOf(id)
	if depthCache[id] then return depthCache[id] end

	local start, d, guard = id, 0, 0
	while id and id ~= SkillTreeConfig.Root and guard < 64 do
		local node = SkillTreeConfig.Nodes[id]
		id = node and node.Requires
		d += 1
		guard += 1
	end

	depthCache[start] = d
	return d
end

local branchCache = {}

local function branchOf(id)
	if id == SkillTreeConfig.Root then return nil end
	if branchCache[id] then return branchCache[id] end

	local start, guard = id, 0
	while guard < 64 do
		local node = SkillTreeConfig.Nodes[id]
		if not (node and node.Requires) then return nil end

		if node.Requires == SkillTreeConfig.Root then
			branchCache[start] = id
			return id
		end

		id = node.Requires
		guard += 1
	end

	return nil
end

local introToken = 0

local function reveal(id)
	local button = nodes[id]
	if not button then return end

	button.Visible = true
	local intro = button:FindFirstChild("IntroScale")
	if intro then
		intro.Scale = 0
		TweenService:Create(intro, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

local function playIntro()
	introToken += 1
	local token = introToken

	local order = {}
	for id in pairs(SkillTreeConfig.Nodes) do
		if distance(id) <= 2 then table.insert(order, id) end
	end

	table.sort(order, function(a, b)
		local da, db = depthOf(a), depthOf(b)
		if da == db then return a < b end
		return da < db
	end)

	local branches, branchOrder = {}, {}

	for _, id in ipairs(order) do
		if not nodes[id] then
			renderNode(id, SkillTreeConfig.Nodes[id], true)
		end

		local button = nodes[id]
		if button then
			button.Visible = false
			local intro = button:FindFirstChild("IntroScale")
			if intro then intro.Scale = 0 end
		end

		local branch = branchOf(id)
		if branch then
			if not branches[branch] then
				branches[branch] = {}
				table.insert(branchOrder, branch)
			end
			table.insert(branches[branch], id)
		end
	end

	task.spawn(function()
		if token ~= introToken then return end

		if nodes[SkillTreeConfig.Root] then
			reveal(SkillTreeConfig.Root)
		end

		task.wait(0.045)

		for _, branch in ipairs(branchOrder) do
			task.spawn(function()
				for _, id in ipairs(branches[branch]) do
					if token ~= introToken then return end
					reveal(id)
					task.wait(0.045)
				end
			end)
		end
	end)
end

------------------------------------------------------------------------------------------
-- hover: the node nearest the pointer (within reach) shows its info card
------------------------------------------------------------------------------------------
updateHover = function()
	if not gui.Enabled then
		if hovered then
			hovered = nil
			hideInfo()
		end
		return
	end

	local origin = moving.AbsolutePosition
	local size = moving.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return end

	local inset = gui.IgnoreGuiInset and Vector2.zero or GuiService:GetGuiInset()
	local mouse = UserInputService:GetMouseLocation() - inset - origin
	local reach = (SkillTreeConfig.HexStepScale or 0.035) * size.Y * 0.9 -- (AbsoluteSize already includes the zoom)

	local best, bestDist = nil, math.huge

	for id in pairs(nodes) do
		local pos = positions[id]
		if pos then
			local dist = (Vector2.new(pos.X * size.X, pos.Y * size.Y) - mouse).Magnitude
			if dist < bestDist then
				best, bestDist = id, dist
			end
		end
	end

	if not best or bestDist > reach then
		if hovered then
			hovered = nil
			hideInfo()
		end
		return
	end

	hovered = best
	showInfo(best, SkillTreeConfig.Nodes[best])
end

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		updateHover()
	end
end)

local function relayout()
	table.clear(positions)

	for id, button in pairs(nodes) do
		local pos = nodePosition(id)
		button.Position = UDim2.new(pos.X, 0, pos.Y, 0)
		if glows[id] then glows[id].Position = button.Position end
	end

	updateHover()
end

moving:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)

------------------------------------------------------------------------------------------
-- zoom (wheel / pinch / triggers) and drag
------------------------------------------------------------------------------------------
local zoom = moving:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
zoom.Parent = moving
zoom.Scale = 1

local MIN_ZOOM, MAX_ZOOM = 0.6, 2.2

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel and gui.Enabled then
		zoom.Scale = math.clamp(zoom.Scale + input.Position.Z * 0.1, MIN_ZOOM, MAX_ZOOM)
	end
end)

local pinchStart = nil
UserInputService.TouchPinch:Connect(function(_, scale, _, state)
	if not gui.Enabled then return end

	if state == Enum.UserInputState.Begin then
		pinchStart = zoom.Scale
	elseif state == Enum.UserInputState.Change then
		if pinchStart then
			zoom.Scale = math.clamp(pinchStart * scale, MIN_ZOOM, MAX_ZOOM)
		end
	else
		pinchStart = nil
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if not gui.Enabled then return end

	local r2 = UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
	local l2 = UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL2)

	if r2 and not l2 then
		zoom.Scale = math.clamp(zoom.Scale + 0.8 * dt, MIN_ZOOM, MAX_ZOOM)
	elseif l2 and not r2 then
		zoom.Scale = math.clamp(zoom.Scale - 0.8 * dt, MIN_ZOOM, MAX_ZOOM)
	end
end)

local dragging = false
local dragStart, startPos

background.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	dragging = true
	dragStart = input.Position
	startPos = moving.Position

	local conn
	conn = input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End then
			dragging = false
			conn:Disconnect()
		end
	end)
end)

background.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end

	local delta = input.Position - dragStart
	local size = background.AbsoluteSize
	moving.Position = UDim2.new(
		startPos.X.Scale + (size.X > 0 and delta.X / size.X or 0), startPos.X.Offset,
		startPos.Y.Scale + (size.Y > 0 and delta.Y / size.Y or 0), startPos.Y.Offset
	)
end)

------------------------------------------------------------------------------------------
-- open / close
------------------------------------------------------------------------------------------
local closePos = closeButton.Position
local starsPos = starsPill.Position
local timerPos = timerPill.Position
local hintTransparency = hint and hint.TextTransparency or 0
local homePosition = moving.Position

local function playOpenAnimation()
	closeButton.Position = closePos - UDim2.fromScale(0, 0.15)
	TweenService:Create(closeButton, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = closePos }):Play()

	local slide = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.1)
	starsPill.Position = starsPos - UDim2.fromScale(0.2, 0)
	TweenService:Create(starsPill, slide, { Position = starsPos }):Play()
	timerPill.Position = timerPos + UDim2.fromScale(0.2, 0)
	TweenService:Create(timerPill, slide, { Position = timerPos }):Play()

	if hint then
		local fadeIn = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.45)
		hint.TextTransparency = 1
		TweenService:Create(hint, fadeIn, { TextTransparency = hintTransparency }):Play()

		local stroke = hint:FindFirstChildOfClass("UIStroke")
		if stroke then
			local target = stroke.Transparency < 1 and stroke.Transparency or 0.3
			stroke.Transparency = 1
			TweenService:Create(stroke, fadeIn, { Transparency = target }):Play()
		end
	end
end

local function setOpen(open)
	if gui.Enabled == open then return end
	gui.Enabled = open
end

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if uiBlur then uiBlur.Enabled = gui.Enabled end

	if gui.Enabled then
		refreshLevels()
		refreshStarsPill(false)
		refreshTimer()
		moving.Position = homePosition -- start centred on the Root
		zoom.Scale = 1
		playOpenAnimation()
		renderAll()
		playIntro()
	else
		hideInfo()
		hovered = nil
	end
end)

gui.Enabled = false
if uiBlur then uiBlur.Enabled = false end

openButton.Activated:Connect(function()
	setOpen(not gui.Enabled)
end)

closeButton.Activated:Connect(function()
	setOpen(false)
end)

------------------------------------------------------------------------------------------
-- keep everything live
------------------------------------------------------------------------------------------
player.AttributeChanged:Connect(function(attribute)
	if attribute == STARS then
		refreshStarsPill(gui.Enabled)
		refreshBadge()
		if gui.Enabled then renderAll() updateHover() end
	elseif attribute:sub(1, 6) == "Skill_" then
		refreshLevels()
		refreshBadge()
		if gui.Enabled then renderAll() updateHover() end
	end
end)

-- floating stars in the background
local particles = {}
local clock = 0

local function resetParticle(p, anywhere)
	p.X = math.random()
	p.Y = anywhere and math.random() or 1.05
	p.Speed = 0.012 + math.random() * 0.025
	p.Drift = (math.random() - 0.5) * 0.012
	p.Size = 0.006 + math.random() * 0.01
	p.Phase = math.random() * math.pi * 2
	p.Image.Size = UDim2.fromScale(p.Size, p.Size)
end

local function updateParticles(dt)
	if not particlesFrame then return end

	if #particles == 0 then
		for _ = 1, 22 do
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = STAR_ICON
			img.ImageColor3 = Color3.fromRGB(255, 240, 200)
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.ZIndex = 2
			Instance.new("UIAspectRatioConstraint").Parent = img
			img.Parent = particlesFrame

			local p = { Image = img }
			resetParticle(p, true)
			table.insert(particles, p)
		end
	end

	for _, p in ipairs(particles) do
		p.Y -= p.Speed * dt
		p.X += p.Drift * dt
		if p.Y < -0.05 then resetParticle(p, false) end

		p.Image.Position = UDim2.fromScale(p.X, p.Y)
		p.Image.Rotation += dt * 25
		p.Image.ImageTransparency = (math.sin(clock * 2.5 + p.Phase) * 0.5 + 0.5) * 0.45 + 0.45
	end
end

-- node breathing / hover growth / purchase pop, glows, background scroll
RunService.Heartbeat:Connect(function(dt)
	if not gui.Enabled then return end

	clock += dt

	for id, button in pairs(nodes) do
		local a = anim[id]

		if a then
			local state = states[id]
			a.Hover += ((hovered == id and state ~= "Locked" and 1 or 0) - a.Hover) * math.min(1, dt * 14)
			a.Pop = math.max(0, a.Pop - dt * 2.5)

			local breathe = state == "Available" and (math.sin(clock * 4 + a.Phase) * 0.5 + 0.5) or 0
			local popAmount = math.sin(a.Pop * math.pi) * 0.35
			local s = 1 + 0.12 * a.Hover + 0.035 * breathe + popAmount
			button.Size = UDim2.fromScale(baseSize.X.Scale * s, baseSize.Y.Scale * s)

			local glow = glows[id]
			if glow then
				local color = GLOW[state]
				glow.Visible = button.Visible and color ~= nil

				if glow.Visible then
					local intro = button:FindFirstChild("IntroScale")
					local g = s * (intro and intro.Scale or 1) * (1.28 + 0.08 * breathe + 0.3 * a.Pop)
					glow.Size = UDim2.fromScale(baseSize.X.Scale * g, baseSize.Y.Scale * g)
					glow.ImageColor3 = color
					glow.ImageTransparency = math.max((state == "Available" and (0.62 - 0.3 * breathe) or 0.72) - 0.5 * a.Pop, 0.1)
				end
			end
		end
	end

	if pattern then
		pattern.Position = UDim2.fromOffset(clock * 14 % 48 - 48, clock * 9 % 48 - 48)
	end

	updateParticles(dt)
end)

refreshBadge()
