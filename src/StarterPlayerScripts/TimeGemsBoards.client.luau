local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local buyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuyUpgrade")

-- each board: which card is which upgrade (card names repeat across boards, ids don't),
-- and which currency the total at the top of the board shows
local BOARDS = {
	{
		name = "Time",
		currency = "Time",
		cards = {
			TimeSpeed = "TimeSpeed",
			TimeMultiplier = "TimeMultiplier",
			AutoTime = "AutoTime",
		},
	},
	{
		name = "TimeBoosts",
		currency = "Time",
		cards = {
			MoneyMultiplier = "TimeMoneyBoost",
			RebirthMultiplier = "TimeRebirthBoost",
			RuneBulk = "RuneBulk",
		},
	},
	{
		island = "Island2",
		name = "TreeUpgrades",
		currency = "Wood",
		cards = {
			WoodMultiplier = "WoodMultiplier",
			DamageDealt = "DamageDealt",
			ButtonCooldown = "ButtonCooldown",
		},
	},
	{
		island = "Island2",
		name = "Mine",
		currency = "Ores",
		cards = {
			OresMultiplier = "MineOresMultiplier",
			Damage = "MineDamage",
		},
	},
	{
		island = "Island2",
		name = "MineBoosts",
		currency = "Ores",
		cards = {
			SpawnSpeed = "MineSpawnSpeed",
			MaxOres = "MaxOres",
			OreSpawnLuck = "OreSpawnLuck",
		},
	},
	{
		island = "Island2",
		name = "Farm",
		currency = "Gold",
		cards = {
			Speed = "FarmSpeed",
			GoldMultiplier = "FarmGoldMultiplier",
		},
	},
	{
		name = "Coins",
		currency = "Coins",
		cards = {
			CoinMultiplier = "CoinMultiplier",
			CoinSpawnSpeed = "CoinSpawnSpeed",
			AutoPickupCoins = "AutoPickupCoins",
		},
	},
	{
		name = "Tycoon",
		currency = "Coins",
		cards = {
			Speed = "DropperSpeed",
		},
	},
	{
		name = "Gems",
		currency = "Gems",
		cards = {
			MoneyMultiplier = "GemMoneyMultiplier",
			RebirthsMultiplier = "GemRebirthMultiplier",
			TimeMultiplier = "GemTimeMultiplier",
			CoinsMultiplier = "GemButtonMultiplier",
		},
	},
}

local COUNT_TIME = 0.6

local function setText(label, text)
	if label.Text ~= text then
		label.Text = text
	end
end

local function setVisible(object, visible)
	if object and object.Visible ~= visible then
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

local function hideMaxed()
	local value = player:GetAttribute(SettingsConfig.attributeOf("HideMaxUpgrades"))

	if value == nil then
		return SettingsConfig.Settings.HideMaxUpgrades.Default
	end

	return value
end

local entries = {}

-- cards with a currency icon inside the cost: the number and the icon sit side by side,
-- centered together, based on how wide the text really is
local ICON_GAP = 4

local function layoutCostIcon(entry)
	local label, icon = entry.costLabel, entry.costIconObject

	if not icon then
		return
	end

	local pad = label:FindFirstChild("CostPadding") or Instance.new("UIPadding")
	pad.Name = "CostPadding"
	pad.Parent = label

	local iconWidth = icon.AbsoluteSize.X
	pad.PaddingRight = UDim.new(0, iconWidth + ICON_GAP) -- text centers in the space left of the icon
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0.5, label.TextBounds.X / 2 + ICON_GAP, 0.5, 0)
end

local function refreshCard(entry)
	local id, def = entry.id, entry.def
	local level = player:GetAttribute(UpgradeConfig.levelAttribute(id)) or 0
	local isMaxed = level >= def.MaxLevel
	local currency = UpgradeConfig.currencyOf(id, level)
	local balance = player:GetAttribute(currency) or 0

	local shown = not (isMaxed and hideMaxed())

	setVisible(entry.card, shown)

	if shown and entry.wasShown == false then
		bounce(entry.cardScale, 0.8)
	end

	entry.wasShown = shown

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
		-- cards with a currency icon in the cost show just the number next to it
		if entry.costIcon then
			setText(entry.costLabel, NumberFormat.abbreviate(cost))
		else
			setText(entry.costLabel, NumberFormat.abbreviate(cost) .. " " .. currency)
		end

		entry.cost = cost
	end

	if entry.costIconObject then
		entry.costIconObject.Visible = not isMaxed -- no icon next to "MAXED"
		layoutCostIcon(entry)
	end

	local canAfford = not isMaxed and balance >= (entry.cost or math.huge)

	setVisible(entry.maxed, isMaxed)
	setVisible(entry.canOne, canAfford)
	setVisible(entry.canMax, canAfford)
	setVisible(entry.cantOne, not isMaxed and not canAfford)
	setVisible(entry.cantMax, not isMaxed and not canAfford)
end

local function refreshAll()
	for _, entry in ipairs(entries) do
		refreshCard(entry)
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
		MessageToPlayer.show("PurchaseUnavailable")
	end

	refreshAll()

	task.wait(0.1)
	entry.busy = false
end

local watchedCurrencies = {}

for _, boardDef in ipairs(BOARDS) do
	local board = workspace:WaitForChild("UpgradeBoards"):WaitForChild(boardDef.island or "Island1"):WaitForChild(boardDef.name)
	local cardList = board
		:WaitForChild("SurfaceGuiPart")
		:WaitForChild("UpgradeBoardTemplate")
		:WaitForChild("ScrollingFrame")
		:WaitForChild("Frame")

	for cardName, id in pairs(boardDef.cards) do
		local card = cardList:WaitForChild(cardName, 10)

		if card and UpgradeConfig.Upgrades[id] then
			local buttons = card:WaitForChild("Buttons")

			local cardScale = Instance.new("UIScale")
			cardScale.Name = "CardScale"
			cardScale.Parent = card

			local entry = {
				id = id,
				def = UpgradeConfig.Upgrades[id],
				card = card,
				cardScale = cardScale,
				levelLabel = card:WaitForChild("Level"),
				valueLabel = card:WaitForChild("Multiplier"),
				costLabel = card:WaitForChild("Cost"),
				costIcon = card:WaitForChild("Cost"):FindFirstChildWhichIsA("ImageLabel", true) ~= nil,
				costIconObject = card:WaitForChild("Cost"):FindFirstChildWhichIsA("ImageLabel", true),
				canOne = buttons:WaitForChild("CanBuyOne"),
				canMax = buttons:WaitForChild("CanBuyMax"),
				cantOne = buttons:WaitForChild("CantBuyOne"),
				cantMax = buttons:WaitForChild("CantBuyMax"),
				maxed = buttons:FindFirstChild("Maxed"),
				wasShown = nil,
				busy = false,
			}

			table.insert(entries, entry)

			if entry.costIconObject then
				entry.costLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
					layoutCostIcon(entry)
				end)
			end

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

						MessageToPlayer.show("PurchaseUnavailable")
					end)
				end
			end

			player:GetAttributeChangedSignal(UpgradeConfig.levelAttribute(id)):Connect(refreshAll)
			watchedCurrencies[UpgradeConfig.currencyOf(id)] = true
		else
			warn("TimeGemsBoards: card '" .. cardName .. "' not found on the " .. boardDef.name .. " board")
		end
	end

	-- the currency total at the top of the board, counting up/down smoothly
	local amountLabel = board
		:WaitForChild("CurrencySurfaceGuiPart")
		:WaitForChild("CurrencySurfaceTemplate")
		:WaitForChild("CurrencyTemplate")
		:WaitForChild("AmountLabel")

	local shown = Instance.new("NumberValue")
	shown.Value = player:GetAttribute(boardDef.currency) or 0
	setText(amountLabel, NumberFormat.abbreviate(shown.Value))

	shown:GetPropertyChangedSignal("Value"):Connect(function()
		setText(amountLabel, NumberFormat.abbreviate(shown.Value))
	end)

	local countTween

	player:GetAttributeChangedSignal(boardDef.currency):Connect(function()
		local target = player:GetAttribute(boardDef.currency) or 0

		if countTween then
			countTween:Cancel()
			countTween = nil
		end

		if math.abs(target - shown.Value) < math.max(5, math.abs(target) * 0.02) then
			shown.Value = target
		else
			countTween = TweenService:Create(
				shown,
				TweenInfo.new(COUNT_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{ Value = target }
			)

			countTween:Play()
		end
	end)
end

for currency in pairs(watchedCurrencies) do
	player:GetAttributeChangedSignal(currency):Connect(refreshAll)
end

player:GetAttributeChangedSignal(SettingsConfig.attributeOf("HideMaxUpgrades")):Connect(refreshAll)

refreshAll()
