-- The Runes menu (StarterGui.Runes), opened from the Runes button.
--   Tabs along the top (TABS below): click one and it pops forward while the others dim.
--   One card per rune in the selected pool, coloured by rarity. Runes you haven't found yet
--   use the "???" template (LockedOverlay): only the silhouette and the chance show.
--   Everything reads from ReplicatedStorage.RuneConfig, so change names/chances there.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local RuneConfig = require(ReplicatedStorage:WaitForChild("RuneConfig"))
local Multipliers = require(ReplicatedStorage:WaitForChild("Multipliers"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))

-- the tabs, left to right (must be pool names in RuneConfig.Pools)
local TABS = { "Starter", "Time", "Buttons", "Wood", "Ore", "Gold", "Beachy", "Coin", "Global" }

-- tab colours: bottom -> top of the gradient, and the light inner rim
local TAB_COLORS = {
	Starter = { Color3.fromRGB(95, 236, 52), Color3.fromRGB(218, 255, 115), Color3.fromRGB(185, 255, 152) },
	Time = { Color3.fromRGB(135, 12, 22), Color3.fromRGB(235, 72, 72), Color3.fromRGB(255, 145, 145) },
	Wood = { Color3.fromRGB(95, 55, 20), Color3.fromRGB(190, 128, 62), Color3.fromRGB(232, 184, 125) },
	Gold = { Color3.fromRGB(150, 112, 8), Color3.fromRGB(255, 214, 70), Color3.fromRGB(255, 236, 150) },
	Global = { Color3.fromRGB(95, 40, 190), Color3.fromRGB(188, 132, 255), Color3.fromRGB(218, 192, 255) },
	Buttons = { Color3.fromRGB(170, 20, 35), Color3.fromRGB(255, 95, 105), Color3.fromRGB(255, 160, 165) },
	Ore = { Color3.fromRGB(80, 82, 92), Color3.fromRGB(175, 178, 190), Color3.fromRGB(215, 218, 228) },
	Beachy = { Color3.fromRGB(20, 150, 190), Color3.fromRGB(255, 225, 150), Color3.fromRGB(255, 240, 200) },
	Coin = { Color3.fromRGB(190, 120, 10), Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 240, 150) },
}

-- card colours by rarity (1 = most common): bottom, top, inner rim
local RARITY = {
	{ Color3.fromRGB(0, 170, 0), Color3.fromRGB(170, 255, 127), Color3.fromRGB(170, 255, 127) }, -- green
	{ Color3.fromRGB(0, 120, 195), Color3.fromRGB(140, 235, 255), Color3.fromRGB(0, 255, 255) }, -- cyan
	{ Color3.fromRGB(110, 50, 200), Color3.fromRGB(200, 160, 255), Color3.fromRGB(215, 185, 255) }, -- purple
	{ Color3.fromRGB(230, 118, 0), Color3.fromRGB(255, 205, 80), Color3.fromRGB(255, 222, 125) }, -- orange
	{ Color3.fromRGB(225, 212, 110), Color3.fromRGB(255, 255, 215), Color3.fromRGB(255, 255, 232) }, -- pale yellow
	{ Color3.fromRGB(180, 180, 192), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255) }, -- white
	{ Color3.fromRGB(135, 0, 20), Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 135, 135) }, -- red
	{ Color3.fromRGB(255, 85, 175), Color3.fromRGB(255, 235, 120), Color3.fromRGB(255, 240, 175) }, -- pink/gold
}
local LOCKED_COLORS = { Color3.fromRGB(22, 22, 28), Color3.fromRGB(48, 48, 56), Color3.fromRGB(70, 70, 80) }

local BOOST_ORDER = { "money", "buttons", "time", "wood", "gold", "ores", "fishmeal", "shells", "fishluck", "scrap", "iron", "oil", "coins", "luck", "bulk" }
local BOOST_NAMES = { money = "Money", buttons = "Buttons", time = "Time", wood = "Wood", gold = "Gold", ores = "Ores", fishmeal = "Fish Meal", shells = "Shells", fishluck = "Fishing Luck", scrap = "Scrap", iron = "Iron", oil = "Oil", coins = "Coins" }

local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("Runes")
local holder = gui:WaitForChild("Holder")
local tabsFrame = holder:WaitForChild("RunesButtons")
local tabTemplate = tabsFrame:WaitForChild("RuneButtonTemplate")
local cardsFrame = holder:WaitForChild("RunesContainer")
local cardTemplate = cardsFrame:WaitForChild("RuneTemplate")
local collection = holder:WaitForChild("Collection"):WaitForChild("Label")
local closeButton = holder:WaitForChild("Top"):WaitForChild("Close")

local openButton = playerGui:WaitForChild("Buttons"):WaitForChild("Container"):WaitForChild("Runes")
if not openButton:IsA("GuiButton") then
	openButton = openButton:FindFirstChildWhichIsA("GuiButton", true) or openButton
end

tabTemplate.Visible = false

-- the tab row fits every tab, so it doesn't need to scroll
tabsFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
tabsFrame.CanvasSize = UDim2.new()
tabsFrame.ScrollingEnabled = false
local tabLayout = tabsFrame:FindFirstChildOfClass("UIListLayout")
if tabLayout then
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
end
cardTemplate.Visible = false

------------------------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------------------------
local function gradient(g, bottom, top)
	if g then
		g.Color = ColorSequence.new(bottom, top)
	end
end

local function setText(label, text)
	if label and label.Text ~= text then
		label.Text = text
	end

	local extra = label and label:FindFirstChild("Extra")

	if extra and extra.Text ~= text then
		extra.Text = text
	end
end

local function trim(n)
	return (string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", ""))
end

-- "77%", "2.1%", "1 in 195", "1 in 13K"
local function chanceText(percent)
	if percent <= 0 then
		return "-"
	elseif percent >= 10 then
		return math.floor(percent + 0.5) .. "%"
	elseif percent >= 1 then
		return (string.format("%.1f", percent):gsub("%.0$", "")) .. "%"
	end

	local n = 100 / percent

	return "1 in " .. (n < 1000 and tostring(math.floor(n + 0.5)) or NumberFormat.abbreviate(n))
end

-- effective % per roll, same math as the server (luck boosts every rune but the first)
local function effectiveChances(pool, luck)
	local total = 0

	for i, rune in ipairs(pool.runes) do
		total += rune.chance * (i == 1 and 1 or luck)
	end

	local out = {}

	for i, rune in ipairs(pool.runes) do
		out[i] = total > 0 and rune.chance * (i == 1 and 1 or luck) / total * 100 or 0
	end

	return out
end

local function boostLines(rune, level)
	local lines = {}

	for _, kind in ipairs(BOOST_ORDER) do
		local values = rune.boosts[kind]
		local v = values and values[math.clamp(level, 1, #values)]

		if v and not (kind == "bulk" and v == 0) then -- (no "+0 Rune Bulk" lines)
			if kind == "luck" then
				table.insert(lines, "x" .. trim(v) .. " Rune Luck")
			elseif kind == "bulk" then
				table.insert(lines, "+" .. trim(v) .. " Rune Bulk")
			else
				table.insert(lines, trim(v) .. "x " .. BOOST_NAMES[kind])
			end
		end
	end

	return lines
end

------------------------------------------------------------------------------------------
-- cards (built once per pool, then just updated)
------------------------------------------------------------------------------------------
local cardsByPool = {} -- [pool] = { { rune, index, card, parts... } }

local function buildCard(poolName, rune, index)
	local card = cardTemplate:Clone()
	card.Name = poolName .. "_" .. rune.name
	card.LayoutOrder = index
	card.Visible = false
	card.Parent = cardsFrame

	local boosts = card:WaitForChild("Boosts")
	local boostTemplate = boosts:WaitForChild("BoostTemplate")
	boostTemplate.Visible = false

	local c = {
		rune = rune,
		index = index,
		card = card,
		name = card:WaitForChild("PassName"),
		chance = card:WaitForChild("Chance"),
		frameGradient = card:WaitForChild("Frame"):FindFirstChildOfClass("UIGradient"),
		innerStroke = card:FindFirstChild("InnerUIStroke"),
		locked = card:WaitForChild("LockedOverlay"),
		level = card:WaitForChild("Level"),
		levelLabel = card.Level:WaitForChild("CurrentLevelLabel"),
		fill = card.Level:WaitForChild("Progressbar"):WaitForChild("Fill"),
		progress = card.Level:WaitForChild("ProgressLabel"),
		boosts = boosts,
		boostTemplate = boostTemplate,
		boostRows = {},
		scale = card:FindFirstChildOfClass("UIScale"),
		found = nil,
	}

	setText(c.name, rune.name)

	return c
end

for _, poolName in ipairs(TABS) do
	local pool = RuneConfig.Pools[poolName]

	if pool then
		cardsByPool[poolName] = {}

		for i, rune in ipairs(pool.runes) do
			cardsByPool[poolName][i] = buildCard(poolName, rune, i)
		end
	end
end

local function setBoostRows(c, lines)
	for i, text in ipairs(lines) do
		local row = c.boostRows[i]

		if not row then
			row = c.boostTemplate:Clone()
			row.Name = "Boost" .. i
			row.LayoutOrder = i
			row.Parent = c.boosts
			c.boostRows[i] = row
		end

		row.Visible = true
		setText(row, text)
	end

	for i = #lines + 1, #c.boostRows do
		c.boostRows[i].Visible = false
	end
end

local function updateCard(poolName, pool, c, percent)
	local count = player:GetAttribute(RuneConfig.countAttribute(poolName, c.rune.name)) or 0
	local found = count > 0

	c.chance.Text = chanceText(percent)

	-- discovered <-> undiscovered look
	if c.found ~= found then
		c.found = found

		local colors = found and (RARITY[c.index] or RARITY[#RARITY]) or LOCKED_COLORS
		gradient(c.frameGradient, colors[1], colors[2])

		if c.innerStroke then
			c.innerStroke.Color = colors[3]
		end

		c.locked.Visible = not found
		c.name.Visible = found
		c.level.Visible = found
		c.boosts.Visible = found
	end

	if not found then
		local hint = c.locked:FindFirstChild("Hint")

		if hint then
			hint.Text = RuneConfig.isUnlocked(player, poolName) and "Undiscovered" or pool.unlock.text
		end

		return
	end

	local level = math.max(RuneConfig.levelFor(count, c.rune.needs), 1)
	local nextNeed = RuneConfig.needsFor(c.rune)[level + 1]

	c.levelLabel.Text = "LVL " .. level

	if nextNeed then
		c.progress.Text = NumberFormat.abbreviate(count) .. " / " .. NumberFormat.abbreviate(nextNeed)
		c.fill.Size = UDim2.new(math.clamp(count / nextNeed, 0.04, 1), 0, 1, 0)
	else
		c.progress.Text = "MAX"
		c.fill.Size = UDim2.new(1, 0, 1, 0)
	end

	setBoostRows(c, boostLines(c.rune, level))
end

local selected = nil

local function refreshCards()
	if not selected then
		return
	end

	local pool = RuneConfig.Pools[selected]
	local chances = effectiveChances(pool, Multipliers.runeLuck(player))
	local foundCount = 0

	for i, c in ipairs(cardsByPool[selected]) do
		updateCard(selected, pool, c, chances[i])

		if c.found then
			foundCount += 1
		end
	end

	setText(collection, foundCount .. " / " .. #pool.runes .. " Found")
end

------------------------------------------------------------------------------------------
-- tabs
------------------------------------------------------------------------------------------
local tabs = {} -- [pool] = { button, scale, dim }

local SELECTED_SCALE = 1.08
local IDLE_SCALE = 0.94
local tabInfo = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local fadeInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

for order, poolName in ipairs(TABS) do
	if RuneConfig.Pools[poolName] then
		local button = tabTemplate:Clone()
		button.Name = poolName
		button.LayoutOrder = order
		local count = #TABS
		button.Size = UDim2.new(1 / count, -math.ceil(8 * (count - 1) / count) - 2, button.Size.Y.Scale, button.Size.Y.Offset)
		button.Visible = true

		local colors = TAB_COLORS[poolName] or TAB_COLORS.Starter
		gradient(button:FindFirstChildOfClass("UIGradient"), colors[1], colors[2])

		local inner = button:FindFirstChild("InnerUIStroke")
		if inner then
			inner.Color = colors[3]
		end

		setText(button:WaitForChild("NameLabel"), poolName)

		local dim = button:WaitForChild("Dim")
		dim.Visible = true
		dim.BackgroundTransparency = 1

		button.Parent = tabsFrame

		tabs[poolName] = {
			button = button,
			scale = button:FindFirstChildOfClass("UIScale"),
			dim = dim,
		}
	end
end

-- cards pop in one after another
local function popCards(poolName)
	for i, c in ipairs(cardsByPool[poolName]) do
		if c.scale then
			c.scale.Scale = 0.75
			TweenService:Create(c.scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, (i - 1) * 0.03), { Scale = 1 }):Play()
		end
	end
end

local function select(poolName, instant)
	if not cardsByPool[poolName] then
		return
	end

	local changed = selected ~= poolName
	selected = poolName

	for name, t in pairs(tabs) do
		local isSelected = name == poolName

		if t.scale then
			if instant then
				t.scale.Scale = isSelected and SELECTED_SCALE or IDLE_SCALE
			elseif isSelected then
				t.scale.Scale = SELECTED_SCALE + 0.1 -- quick pop, then settle
				TweenService:Create(t.scale, tabInfo, { Scale = SELECTED_SCALE }):Play()
			else
				TweenService:Create(t.scale, fadeInfo, { Scale = IDLE_SCALE }):Play()
			end
		end

		t.button.ZIndex = isSelected and 4 or 3
		TweenService:Create(t.dim, fadeInfo, { BackgroundTransparency = isSelected and 1 or 0.45 }):Play()
	end

	for name, list in pairs(cardsByPool) do
		for _, c in ipairs(list) do
			c.card.Visible = name == poolName
		end
	end

	refreshCards()

	if changed then
		cardsFrame.CanvasPosition = Vector2.zero

		if not instant then
			popCards(poolName)
		end
	end
end

for name, t in pairs(tabs) do
	t.button.Activated:Connect(function()
		select(name)
	end)

	t.button.MouseEnter:Connect(function()
		if selected ~= name and t.scale then
			TweenService:Create(t.scale, fadeInfo, { Scale = 1 }):Play()
		end
	end)

	t.button.MouseLeave:Connect(function()
		if selected ~= name and t.scale then
			TweenService:Create(t.scale, fadeInfo, { Scale = IDLE_SCALE }):Play()
		end
	end)
end

select(TABS[1], true)

------------------------------------------------------------------------------------------
-- open / close
------------------------------------------------------------------------------------------
local openScale = holder:FindFirstChild("OpenScale") or Instance.new("UIScale")
openScale.Name = "OpenScale"
openScale.Parent = holder

local isOpen = false

local function setOpen(open)
	isOpen = open

	if open then
		refreshCards()
		holder.Visible = true
		openScale.Scale = 0.6
		TweenService:Create(openScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		popCards(selected)
	else
		local t = TweenService:Create(openScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 })
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

if openButton:IsA("GuiButton") then
	openButton.Activated:Connect(function()
		setOpen(not isOpen)
	end)
end

closeButton.Activated:Connect(function()
	setOpen(false)
end)

-- live numbers while it's open
player.AttributeChanged:Connect(function(attribute)
	if isOpen and attribute:sub(1, 5) == "Rune_" then
		refreshCards()
	end
end)

task.spawn(function()
	while true do
		task.wait(0.5)

		if isOpen then
			refreshCards()
		end
	end
end)
