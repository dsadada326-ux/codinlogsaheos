-- The Teleport menu (StarterGui.Teleport): opened from the Teleport button, one card per island.
--   Island 1 - green.  "You're Here" (blue) when you're on it, otherwise "Teleport".
--   Island 2 - orange. Locked until you unlock it: lock over the picture, "Unlock in the
--              Island 1 Tree", grey "Locked" button (or "Unlock" once you qualify).
--   Island 3 - blue.   Always locked for now: "Coming in Update 2".
--   Fishing Frenzy - ocean blue, Island 1's sub-island, always open. It lives INSIDE Island 1's
--              slot: scroll down on the Island 1 card (or hit the round arrow) to reach it.
--              Its picture is FishingFrenzyConfig.CardImage.
--   Laboratory - teal, Island 2's sub-island (the lab tycoon). Same idea: it lives INSIDE Island 2's
--              slot, scroll down on the Island 2 card to reach it. Needs Island 2 unlocked.
-- Teleporting goes through IslandTransition (black cut, eyes open, island name at the top);
-- IslandTwoService checks everything again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local IslandTwoConfig = require(ReplicatedStorage:WaitForChild("IslandTwoConfig"))
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local IslandTransition = require(ReplicatedStorage:WaitForChild("IslandTransition"))
local FishingFrenzyConfig = require(ReplicatedStorage:WaitForChild("FishingFrenzyConfig"))
local LabConfig = require(ReplicatedStorage:WaitForChild("LabConfig"))

local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("Teleport")
local holder = gui:WaitForChild("Holder")
local cardsFrame = holder:WaitForChild("TeleportScrollingFrame")
local closeButton = holder:WaitForChild("Top"):WaitForChild("Close")
local openButton = playerGui:WaitForChild("Buttons"):WaitForChild("Container"):WaitForChild("Teleport")

local DESCRIPTIONS = {
	Island1 = "Buttons, Rebirths & Prestige",
	Island2 = "Wood, Farming & Mining",
	FishingFrenzy = FishingFrenzyConfig.Subtitle,
	Laboratory = "Sub-Island of Island 2",
}
local NORMAL_TEXT = Color3.fromRGB(255, 255, 255)
local LOCKED_TEXT = Color3.fromRGB(255, 120, 120)

-- button looks: gradient (bottom -> top), light rim, dark outline, text gradient top colour
local STYLES = {
	teleport = { text = "Teleport", colors = { Color3.fromRGB(95, 236, 52), Color3.fromRGB(181, 255, 112), Color3.fromRGB(218, 255, 115) },
		rim = Color3.fromRGB(185, 255, 152), dark = Color3.fromRGB(0, 66, 0), textTop = Color3.fromRGB(0, 255, 0), textDark = Color3.fromRGB(0, 85, 0) },
	here = { text = "You're Here", colors = { Color3.fromRGB(35, 120, 255), Color3.fromRGB(85, 165, 255), Color3.fromRGB(140, 205, 255) },
		rim = Color3.fromRGB(170, 220, 255), dark = Color3.fromRGB(10, 40, 110), textTop = Color3.fromRGB(120, 200, 255), textDark = Color3.fromRGB(10, 45, 120) },
	locked = { text = "Locked", colors = { Color3.fromRGB(135, 135, 142), Color3.fromRGB(190, 190, 196), Color3.fromRGB(225, 225, 230) },
		rim = Color3.fromRGB(235, 235, 240), dark = Color3.fromRGB(45, 45, 52), textTop = Color3.fromRGB(190, 190, 196), textDark = Color3.fromRGB(45, 45, 52) },
	unlock = { text = "Unlock", colors = { Color3.fromRGB(245, 160, 20), Color3.fromRGB(255, 200, 70), Color3.fromRGB(255, 230, 120) },
		rim = Color3.fromRGB(255, 235, 170), dark = Color3.fromRGB(110, 55, 0), textTop = Color3.fromRGB(255, 215, 90), textDark = Color3.fromRGB(110, 55, 0) },
}

------------------------------------------------------------------------------------------
-- which island are you standing on? (same boxes IslandCurrencies uses)
------------------------------------------------------------------------------------------
local hitboxes = workspace:WaitForChild("IslandHitboxes")

local function currentIsland()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

	if not root then
		return nil
	end

	if FishingFrenzyConfig.isInside(root.Position) then
		return "FishingFrenzy"
	end

	if LabConfig.isInside(root.Position) then
		return "Laboratory"
	end

	for _, name in ipairs({ "Island2", "Island1" }) do
		local box = hitboxes:FindFirstChild(name)

		if box and box:IsA("BasePart") then
			local p = box.CFrame:PointToObjectSpace(root.Position)
			local half = box.Size / 2

			-- (tall enough to count anyone standing on the island, even under the box)
			if math.abs(p.X) <= half.X and math.abs(p.Z) <= half.Z and p.Y <= half.Y then
				return name
			end
		end
	end

	return nil
end

------------------------------------------------------------------------------------------
-- cards
------------------------------------------------------------------------------------------
local cards = {}

-- Island 1's slot scrolls between Island 1 and Fishing Frenzy, Island 2's between Island 2 and
-- the Laboratory
local SLOTS = {
	{ slot = "Island1", main = "Island1", sub = "FishingFrenzy" },
	{ slot = "Island2", main = "Island2", sub = "Laboratory" },
}
local slotOf = {}
for _, s in ipairs(SLOTS) do
	local frame = cardsFrame:WaitForChild(s.slot)
	s.scroller = frame:WaitForChild("Scroller")
	s.hint = frame:WaitForChild("ScrollHint")
	slotOf[s.main], slotOf[s.sub] = s, s
end

local function cardFrame(name)
	local s = slotOf[name]
	if s then
		return s.scroller:WaitForChild(name):WaitForChild("Card")
	end

	return cardsFrame:WaitForChild(name):WaitForChild("Card")
end

for _, name in ipairs({ "Island1", "FishingFrenzy", "Island2", "Laboratory", "Island3" }) do
	local card = cardFrame(name)
	local button = card:WaitForChild("TeleportButton")
	local strokes = {}

	for _, st in ipairs(button:GetChildren()) do
		if st:IsA("UIStroke") then table.insert(strokes, st) end
	end

	cards[name] = {
		card = card,
		button = button,
		strokes = strokes, -- [1] light rim, [2] dark outline (as built)
		gradient = button:FindFirstChildOfClass("UIGradient"),
		title = button:WaitForChild("Title"),
		picture = card:WaitForChild("Picture"),
		description = card:WaitForChild("Description"),
		state = nil,
	}
end

-- Fishing Frenzy's picture (until one is set it keeps Island 1's)
if FishingFrenzyConfig.CardImage ~= "" then
	cards.FishingFrenzy.picture:WaitForChild("Image").Image = FishingFrenzyConfig.CardImage
end

local function styleButton(c, styleName)
	local st = STYLES[styleName]
	local title, extra = c.title, c.title:FindFirstChild("Extra")

	title.Text = st.text
	if extra then extra.Text = st.text end

	if c.gradient then
		c.gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, st.colors[1]),
			ColorSequenceKeypoint.new(0.56, st.colors[2]),
			ColorSequenceKeypoint.new(1, st.colors[3]),
		})
	end

	-- light rim first, dark outline second
	local lightStroke, darkStroke

	for _, stroke in ipairs(c.strokes) do
		local col = stroke.Color
		if (col.R + col.G + col.B) > 1.2 then lightStroke = stroke else darkStroke = stroke end
	end

	if lightStroke then lightStroke.Color = st.rim end
	if darkStroke then darkStroke.Color = st.dark end

	for _, label in ipairs({ title, extra }) do
		if label then
			local stroke = label:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Color = st.textDark end
		end
	end

	local textGradient = extra and extra:FindFirstChildOfClass("UIGradient")

	if textGradient then
		textGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, st.textTop),
			ColorSequenceKeypoint.new(0.48, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
		})
	end
end

local function setCard(name, state)
	local c = cards[name]

	if c.state == state then
		return
	end

	c.state = state

	local locked = state == "locked" or state == "unlock"
	local picture = c.picture
	picture:WaitForChild("LockedOverlay").Visible = locked
	picture:WaitForChild("HereBadge").Visible = state == "here"

	local subBadge = picture:FindFirstChild("SubBadge")
	if subBadge then
		subBadge.Visible = state ~= "here" -- same corner space as "YOU ARE HERE"
	end
	picture:WaitForChild("Image").ImageColor3 = locked and Color3.fromRGB(90, 95, 115) or Color3.new(1, 1, 1)

	if name == "Island3" then
		c.description.Text = "Coming in Update 2"
	elseif name == "Island2" and locked then
		c.description.Text = "Unlock in the Island 1 Tree"
	elseif name == "Laboratory" and locked then
		c.description.Text = "Unlock Island 2 first"
	else
		c.description.Text = DESCRIPTIONS[name]
	end

	c.description.TextColor3 = locked and LOCKED_TEXT or NORMAL_TEXT
	styleButton(c, state == "here" and "here" or state)
end

local function refresh()
	local here = currentIsland()
	local island2Open = player:GetAttribute("Island2Unlocked") == true

	setCard("Island1", here == "Island1" and "here" or "teleport")
	setCard("FishingFrenzy", here == "FishingFrenzy" and "here" or "teleport")

	if not island2Open then
		setCard("Island2", IslandTwoConfig.canUnlock(player) and "unlock" or "locked")
	else
		setCard("Island2", here == "Island2" and "here" or "teleport")
	end

	setCard("Laboratory", not island2Open and "locked" or (here == "Laboratory" and "here" or "teleport"))

	setCard("Island3", "locked")
end

------------------------------------------------------------------------------------------
-- island <-> sub-island scrolling (Island 1 / Fishing Frenzy, Island 2 / Laboratory)
------------------------------------------------------------------------------------------
local function atSub(s)
	local maxY = s.scroller.AbsoluteCanvasSize.Y - s.scroller.AbsoluteWindowSize.Y
	return maxY > 0 and s.scroller.CanvasPosition.Y >= maxY * 0.5
end

local function paintHint(s)
	s.hint.Text = atSub(s) and "▲" or "▼"
end

local function scrollTo(s, sub, instant)
	local maxY = math.max(0, s.scroller.AbsoluteCanvasSize.Y - s.scroller.AbsoluteWindowSize.Y)
	local target = Vector2.new(0, sub and maxY or 0)

	if instant then
		s.scroller.CanvasPosition = target
	else
		TweenService:Create(s.scroller, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CanvasPosition = target }):Play()
	end
end

for _, s in ipairs(SLOTS) do
	s.scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		paintHint(s)
	end)

	s.hint.Activated:Connect(function()
		scrollTo(s, not atSub(s))
	end)

	-- a little bob so people notice there's more below
	task.spawn(function()
		local base = s.hint.Position
		while true do
			if holder.Visible and not atSub(s) then
				TweenService:Create(s.hint, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Position = base + UDim2.fromOffset(0, 4) }):Play()
				task.wait(0.35)
				TweenService:Create(s.hint, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Position = base }):Play()
				task.wait(0.9)
			else
				task.wait(0.3)
			end
		end
	end)
end

------------------------------------------------------------------------------------------
-- open / close
------------------------------------------------------------------------------------------
local scale = holder:FindFirstChild("OpenScale") or Instance.new("UIScale")
scale.Name = "OpenScale"
scale.Parent = holder

local isOpen = false

local function setOpen(open)
	isOpen = open

	if open then
		refresh()
		holder.Visible = true

		-- start on whichever of the two you're standing on
		task.defer(function()
			local here = currentIsland()
			for _, s in ipairs(SLOTS) do
				scrollTo(s, here == s.sub, true)
				paintHint(s)
			end
		end)
		scale.Scale = 0.6
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	else
		local t = TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 })
		t:Play()
		t.Completed:Connect(function()
			if not isOpen then
				holder.Visible = false
			end
		end)
	end
end

holder.Visible = false
gui.Enabled = true

openButton.Activated:Connect(function()
	setOpen(not isOpen)
end)

closeButton.Activated:Connect(function()
	setOpen(false)
end)

------------------------------------------------------------------------------------------
-- buttons
------------------------------------------------------------------------------------------
local busy = false

local function shake(card)
	local cardScale = card:FindFirstChild("CardScale")

	if cardScale then
		cardScale.Scale = 0.94
		TweenService:Create(cardScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

for name, c in pairs(cards) do
	local hover = c.button:FindFirstChild("HoverScale")

	if hover then
		c.button.MouseEnter:Connect(function()
			TweenService:Create(hover, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
		end)
		c.button.MouseLeave:Connect(function()
			TweenService:Create(hover, TweenInfo.new(0.12), { Scale = 1 }):Play()
		end)
	end

	c.button.Activated:Connect(function()
		if busy then
			return
		end

		if c.state == "here" then
			shake(c.card)
			return
		end

		if c.state == "locked" then
			shake(c.card)
			MessageToPlayer.show("PurchaseUnavailable")
			return
		end

		busy = true

		-- close the menu first so it isn't there when your eyes open
		setOpen(false)

		local result = IslandTransition.travel(name)

		if not (type(result) == "table" and result.ok) and result.reason ~= "busy" then
			setOpen(true)
			shake(c.card)
		end

		task.wait(0.4)
		refresh()
		busy = false
	end)
end

player:GetAttributeChangedSignal("Island2Unlocked"):Connect(refresh)
player:GetAttributeChangedSignal("Prestige"):Connect(refresh)

-- keep "You're Here" right while it's open (you might walk off an island)
task.spawn(function()
	while true do
		if isOpen then
			refresh()
		end

		task.wait(0.5)
	end
end)
