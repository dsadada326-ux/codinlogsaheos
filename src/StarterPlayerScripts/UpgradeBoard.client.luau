local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local buyRemote = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("BuyUpgrade")

local starter = workspace
	:WaitForChild("UpgradeBoards")
	:WaitForChild("Island1")
	:WaitForChild("Starter")

local cardList = starter
	:WaitForChild("SurfaceGuiPart")
	:WaitForChild("UpgradeBoardTemplate")
	:WaitForChild("ScrollingFrame")
	:WaitForChild("Frame")

-- the cash amount at the top of the board
local amountLabel = starter
	:WaitForChild("CurrencySurfaceGuiPart")
	:WaitForChild("CurrencySurfaceTemplate")
	:WaitForChild("CurrencyTemplate")
	:WaitForChild("AmountLabel")

local COUNT_TIME = 0.6 -- seconds a big change in cash takes to count up / down

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.2K" (used for costs)
local function abbreviate(value)
	value = math.floor(value)

	if value < 1000 then
		return tostring(value)
	end

	local index = 0

	while value >= 1000 and index < #SUFFIXES - 1 do
		value /= 1000
		index += 1
	end

	local text = string.format("%.1f", math.floor(value * 10) / 10)
	text = text:gsub("%.0$", "")

	return text .. SUFFIXES[index + 1]
end

-- 15868 -> "15,868", and abbreviated once it gets huge
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))

-- 122095 -> "122K", 300000000 -> "300M" (same as the currency list)
local function formatTotal(value)
	return NumberFormat.abbreviate(value)
end

local function setText(label, text)
	if label.Text ~= text then
		label.Text = text
	end
end

local function setVisible(object, visible)
	if object.Visible ~= visible then
		object.Visible = visible
	end
end

local function bounce(scale, from)
	scale.Scale = from

	TweenService:Create(
		scale,
		TweenInfo.new(
			0.3,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),
		{ Scale = 1 }
	):Play()
end

local placeCostIcon -- defined below

-- upgrade cards ----------------------------------------------------------------
local cards = {}

-- only the Cash-tier cards live on this board; RebirthMoneyMultiplier / RebirthCritMultiplier
-- are on the Rebirth Boosts board (RebirthBoostsBoard.lua), even though they share
-- ReplicatedStorage.UpgradeConfig for their level/cost math
local STARTER_BOARD_IDS = { "ButtonMultiplier", "CashMultiplier", "CritChance", "CritMultiplier" }

for _, id in ipairs(STARTER_BOARD_IDS) do
	local card = cardList:WaitForChild(id, 5)

	if not card then
		warn("UpgradeBoard: missing card '" .. id .. "' on the Starter board, skipping it")
		continue
	end
	local buttons = card:WaitForChild("Buttons")

	local cardScale = Instance.new("UIScale")
	cardScale.Name = "CardScale"
	cardScale.Parent = card

	cards[id] = {
		id = id,
		def = UpgradeConfig.Upgrades[id],
		card = card,
		cardScale = cardScale,
		levelLabel = card:WaitForChild("Level"),
		valueLabel = card:WaitForChild("Multiplier"),
		costLabel = card:WaitForChild("Cost"),
		costIcon = card:WaitForChild("Cost"):FindFirstChild("CostIcon"), -- button image after the number
		canOne = buttons:WaitForChild("CanBuyOne"),   -- green
		canMax = buttons:WaitForChild("CanBuyMax"),   -- green
		cantOne = buttons:WaitForChild("CantBuyOne"), -- red
		cantMax = buttons:WaitForChild("CantBuyMax"), -- red
		maxed = buttons:WaitForChild("Maxed"),        -- gray
		badge = card:FindFirstChild("Milestone"),       -- "LV 15 = x2!" sticker (Cash Multiplier)
		badgePulse = nil,
		lastMilestone = nil,
		wasShown = nil,
		busy = false,
	}
end

-- the "Every 15 LVLs = x2!" sticker: pulses when the next doubling is one level away
local function refreshBadge(entry, level)
	local badge, def = entry.badge, entry.def

	if not badge or not def.MilestoneEvery then
		return
	end

	local every = def.MilestoneEvery
	local reached = math.floor(level / every)
	local nextLevel = (reached + 1) * every
	local show = nextLevel <= def.MaxLevel

	setVisible(badge, show)

	local scale = badge:FindFirstChild("BadgeScale")

	-- just hit a doubling: big pop
	if entry.lastMilestone ~= nil and reached > entry.lastMilestone and scale then
		scale.Scale = 1.6

		TweenService:Create(
			scale,
			TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end

	entry.lastMilestone = reached

	if not show then
		return
	end

	setText(badge.Text, "Every " .. every .. " LVLs = x" .. (def.MilestoneFactor or 2) .. "!")

	-- pulse while the doubling is the very next level
	local close = level == nextLevel - 1

	if close and not entry.badgePulse and scale then
		entry.badgePulse = TweenService:Create(
			scale,
			TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.15 }
		)

		entry.badgePulse:Play()
	elseif not close and entry.badgePulse then
		entry.badgePulse:Cancel()
		entry.badgePulse = nil
	end
end

-- puts the cost icon just to the right of the cost number
placeCostIcon = function(entry)
	local label, icon = entry.costLabel, entry.costIcon
	local width = label.AbsoluteSize.X

	if width <= 0 then
		return
	end

	local textRight = 0.5 + (label.TextBounds.X / 2) / width

	icon.Position = UDim2.new(textRight, 4, 0.5, 0)
end

local function refreshCard(entry)
	local id, def = entry.id, entry.def

	local currency = UpgradeConfig.currencyOf(id) -- "Cash" or "Buttons"
	local balance = player:GetAttribute(currency) or 0
	local level = player:GetAttribute(UpgradeConfig.levelAttribute(id)) or 0

	local unlocked = UpgradeConfig.isUnlocked(player, id)

	local isMaxed = level >= def.MaxLevel

	local hideMaxed = player:GetAttribute(SettingsConfig.attributeOf("HideMaxUpgrades"))
	if hideMaxed == nil then
		hideMaxed = SettingsConfig.Settings.HideMaxUpgrades.Default
	end

	-- the card shows once it's unlocked, and (depending on the setting) goes away when it's maxed
	local shown = unlocked and not (isMaxed and hideMaxed)

	setVisible(entry.card, shown)

	if shown and entry.wasShown == false then
		bounce(entry.cardScale, 0.8) -- pops in when it unlocks
	end

	entry.wasShown = shown

	-- level, effect and cost
	local current = UpgradeConfig.formatValue(id, UpgradeConfig.valueAt(id, level))

	if isMaxed then
		setText(entry.levelLabel, "MAX")
		setText(entry.valueLabel, current)
		setText(entry.costLabel, "MAXED")
	else
		local nextValue = UpgradeConfig.formatValue(id, UpgradeConfig.valueAt(id, level + 1))
		local cost = UpgradeConfig.costAt(id, level)

		local shownLevel, shownMax = UpgradeConfig.displayLevel(id, level)

		setText(entry.levelLabel, shownLevel .. "/" .. shownMax)
		setText(entry.valueLabel, current .. " -> " .. nextValue)

		if entry.costIcon then
			-- "93" + button image
			setText(entry.costLabel, abbreviate(cost))
			placeCostIcon(entry)
		else
			setText(entry.costLabel, abbreviate(cost) .. " " .. currency)
		end

		entry.cost = cost
	end

	refreshBadge(entry, level)

	-- buttons: green = can buy, red = can't afford it yet, gray = maxed
	local canAfford = not isMaxed and balance >= (entry.cost or math.huge)

	setVisible(entry.maxed, isMaxed)
	setVisible(entry.canOne, canAfford)
	setVisible(entry.canMax, canAfford)
	setVisible(entry.cantOne, not isMaxed and not canAfford)
	setVisible(entry.cantMax, not isMaxed and not canAfford)
end

local function refreshAll()
	for _, id in ipairs(STARTER_BOARD_IDS) do
		if cards[id] then
			refreshCard(cards[id])
		end
	end
end

local function tryBuy(entry, mode, button)
	if entry.busy then
		return
	end

	entry.busy = true

	local ok, result = pcall(function()
		return buyRemote:InvokeServer(entry.id, mode)
	end)

	local pop = button:FindFirstChild("AffordPopScale")

	if ok and type(result) == "table" and result.ok then
		if pop then
			bounce(pop, 1.18)
		end

		bounce(entry.cardScale, 1.06)
	elseif pop then
		bounce(pop, 0.85) -- couldn't buy
		MessageToPlayer.show("PurchaseUnavailable")
	end

	refreshAll()

	task.wait(0.1)
	entry.busy = false
end

for _, entry in pairs(cards) do
	entry.canOne.Activated:Connect(function()
		tryBuy(entry, "one", entry.canOne)
	end)

	entry.canMax.Activated:Connect(function()
		tryBuy(entry, "max", entry.canMax)
	end)

	-- red / gray buttons: just a little shake, nothing is bought
	for _, button in ipairs({ entry.cantOne, entry.cantMax, entry.maxed }) do
		button.Activated:Connect(function()
			local pop = button:FindFirstChild("AffordPopScale")

			if pop then
				bounce(pop, 0.85)
			end

			MessageToPlayer.show("PurchaseUnavailable")
		end)
	end
end

-- refresh whenever something the cards depend on changes
player:GetAttributeChangedSignal("Cash"):Connect(refreshAll)
player:GetAttributeChangedSignal("Buttons"):Connect(refreshAll)

for _, id in ipairs(STARTER_BOARD_IDS) do
	player:GetAttributeChangedSignal(UpgradeConfig.levelAttribute(id)):Connect(refreshAll)
	player:GetAttributeChangedSignal(UpgradeConfig.unlockAttribute(id)):Connect(refreshAll)
end

player:GetAttributeChangedSignal(SettingsConfig.attributeOf("HideMaxUpgrades")):Connect(refreshAll)

refreshAll()

-- cash amount at the top of the board -----------------------------------------------
local shownCash = Instance.new("NumberValue")
shownCash.Value = player:GetAttribute("Cash") or 0
setText(amountLabel, formatTotal(shownCash.Value))

shownCash:GetPropertyChangedSignal("Value"):Connect(function()
	setText(amountLabel, formatTotal(shownCash.Value))
end)

local countTween = nil

player:GetAttributeChangedSignal("Cash"):Connect(function()
	local target = player:GetAttribute("Cash") or 0
	local change = math.abs(target - shownCash.Value)

	if countTween then
		countTween:Cancel()
		countTween = nil
	end

	if change < math.max(5, math.abs(target) * 0.02) then
		shownCash.Value = target
	else
		countTween = TweenService:Create(
			shownCash,
			TweenInfo.new(
				COUNT_TIME,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.Out
			),
			{ Value = target }
		)

		countTween:Play()
	end
end)

-- new players: Cash stays hidden until Cash Multiplier unlocks -----------------------
-- (Button Multiplier 3/5), or they already have Cash
local topParts = {
	starter:WaitForChild("CurrencySurfaceGuiPart"),
}

for _, part in ipairs(starter:GetChildren()) do
	-- the small background behind the top panel (same height as the panel)
	if part.Name == "BackGround" and math.abs(part.Position.Y - topParts[1].Position.Y) < 1 then
		table.insert(topParts, part)
	end
end

local function cashRevealed()
	return UpgradeConfig.isUnlocked(player, "CashMultiplier")
		or (player:GetAttribute("Cash") or 0) > 0
end

local function applyCashReveal()
	local show = cashRevealed()

	-- top of the Starter board (only changed on this player's screen)
	for _, part in ipairs(topParts) do
		part.LocalTransparencyModifier = show and 0 or 1

		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("SurfaceGui") or child:IsA("ParticleEmitter") then
				child.Enabled = show
			end
		end
	end

	-- the Cash row in the currency list
	local currencies = player.PlayerGui:FindFirstChild("Currencies")
	local row = currencies
		and currencies:FindFirstChild("MainCurrenciesFrame")
		and currencies.MainCurrenciesFrame:FindFirstChild("CurrenciesFrame")
		and currencies.MainCurrenciesFrame.CurrenciesFrame:FindFirstChild("Money")

	if row then
		row.Visible = show
	end
end

player:GetAttributeChangedSignal("Cash"):Connect(applyCashReveal)
player:GetAttributeChangedSignal(UpgradeConfig.unlockAttribute("CashMultiplier")):Connect(applyCashReveal)
player:GetAttributeChangedSignal(UpgradeConfig.levelAttribute("CashMultiplier")):Connect(applyCashReveal)

-- the currency list is recreated when the character respawns
player.PlayerGui.ChildAdded:Connect(function(child)
	if child.Name == "Currencies" then
		task.defer(applyCashReveal)
	end
end)

applyCashReveal()
