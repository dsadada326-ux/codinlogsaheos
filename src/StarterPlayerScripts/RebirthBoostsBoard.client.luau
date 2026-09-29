local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local buyRemote = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("BuyUpgrade")

local IDS = { "RebirthButtonMultiplier", "RebirthMoneyMultiplier", "RebirthCritMultiplier", "Autoclicker" }

local board = workspace
	:WaitForChild("UpgradeBoards")
	:WaitForChild("Island1")
	:WaitForChild("RebirthBoosts")

local cardList = board
	:WaitForChild("SurfaceGuiPart")
	:WaitForChild("UpgradeBoardTemplate")
	:WaitForChild("ScrollingFrame")
	:WaitForChild("Frame")

-- the Rebirths amount at the top of the board
local amountLabel = board
	:WaitForChild("CurrencySurfaceGuiPart")
	:WaitForChild("CurrencySurfaceTemplate")
	:WaitForChild("CurrencyTemplate")
	:WaitForChild("AmountLabel")

local COUNT_TIME = 0.6

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

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
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

-- cards ----------------------------------------------------------------------------
local cards = {}

for _, id in ipairs(IDS) do
	local card = cardList:WaitForChild(id)
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
		canOne = buttons:WaitForChild("CanBuyOne"),
		canMax = buttons:WaitForChild("CanBuyMax"),
		cantOne = buttons:WaitForChild("CantBuyOne"),
		cantMax = buttons:WaitForChild("CantBuyMax"),
		maxed = buttons:FindFirstChild("Maxed"),
		wasShown = nil,
		busy = false,
	}
end

local function refreshCard(entry)
	local id, def = entry.id, entry.def
	local level = player:GetAttribute(UpgradeConfig.levelAttribute(id)) or 0
	local isMaxed = level >= def.MaxLevel

	local unlocked = UpgradeConfig.isUnlocked(player, id)

	local currency = UpgradeConfig.currencyOf(id, level)
	local balance = player:GetAttribute(currency) or 0

	local shown = unlocked and not isMaxed

	setVisible(entry.card, shown)

	if shown and entry.wasShown == false then
		bounce(entry.cardScale, 0.8)
	end

	entry.wasShown = shown

	if not shown then
		return
	end

	local current = UpgradeConfig.formatValue(id, UpgradeConfig.valueAt(id, level))
	local nextValue = UpgradeConfig.formatValue(id, UpgradeConfig.valueAt(id, level + 1))
	local cost = UpgradeConfig.costAt(id, level)

	local shownLevel, shownMax = UpgradeConfig.displayLevel(id, level)

	setText(entry.levelLabel, shownLevel .. "/" .. shownMax)
	setText(entry.valueLabel, current .. " -> " .. nextValue)
	setText(entry.costLabel, abbreviate(cost) .. " " .. currency)

	entry.cost = cost

	local canAfford = balance >= cost

	if entry.maxed then
		setVisible(entry.maxed, false)
	end

	setVisible(entry.canOne, canAfford)
	setVisible(entry.canMax, canAfford)
	setVisible(entry.cantOne, not canAfford)
	setVisible(entry.cantMax, not canAfford)
end

local function refreshAll()
	for _, id in ipairs(IDS) do
		refreshCard(cards[id])
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
		bounce(pop, 0.85)
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

	for _, button in ipairs({ entry.cantOne, entry.cantMax, entry.maxed }) do
		if button then
			button.Activated:Connect(function()
				local pop = button:FindFirstChild("AffordPopScale")

				if pop then
					bounce(pop, 0.85)
				end
			end)
		end
	end
end

player:GetAttributeChangedSignal("Cash"):Connect(refreshAll)
player:GetAttributeChangedSignal("Rebirths"):Connect(refreshAll)

for _, id in ipairs(IDS) do
	player:GetAttributeChangedSignal(UpgradeConfig.levelAttribute(id)):Connect(refreshAll)
end

refreshAll()

-- Rebirths amount at the top of the board ------------------------------------------
local shownAmount = Instance.new("NumberValue")
shownAmount.Value = player:GetAttribute("Rebirths") or 0
setText(amountLabel, formatTotal(shownAmount.Value))

shownAmount:GetPropertyChangedSignal("Value"):Connect(function()
	setText(amountLabel, formatTotal(shownAmount.Value))
end)

local countTween = nil

player:GetAttributeChangedSignal("Rebirths"):Connect(function()
	local target = player:GetAttribute("Rebirths") or 0
	local change = math.abs(target - shownAmount.Value)

	if countTween then
		countTween:Cancel()
		countTween = nil
	end

	if change < math.max(2, math.abs(target) * 0.02) then
		shownAmount.Value = target
	else
		countTween = TweenService:Create(
			shownAmount,
			TweenInfo.new(COUNT_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ Value = target }
		)

		countTween:Play()
	end
end)
