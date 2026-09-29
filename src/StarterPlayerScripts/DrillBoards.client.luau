-- DRILLING MANIA: the two upgrade boards by the scrap field (the "scrapups" models).
--   the one nearer the drills = Scrap Upgrades (paid in Scrap)
--   the other one             = Iron Upgrades (paid in Iron)
-- One card is cloned from the board's ScrapTemp card for every upgrade.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local DrillConfig = require(ReplicatedStorage:WaitForChild("DrillConfig"))
local buyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuyUpgrade")

local BOARDS = {
	{ currency = "Scrap", label = "Scrap", icon = DrillConfig.Icons.Scrap, upgrades = { "ScrapValue", "ScrapSpawnSpeed", "ScrapCapacity", "ScrapRange" } },
	{ currency = "Metal", label = "Iron", icon = DrillConfig.Icons.Iron, upgrades = { "ScrapBulk", "FurnaceSpeed", "FurnaceYield", "OilMultiplier" } },
}

local zone = workspace:WaitForChild("Islands"):WaitForChild("Island1"):WaitForChild("Zones"):WaitForChild("DrillZone")

-- wait for both boards to stream in
local models
for _ = 1, 60 do
	models = {}
	for _, c in ipairs(zone:GetChildren()) do
		if c.Name == "scrapups" and c:FindFirstChild("SurfaceGuiPart") then
			table.insert(models, c)
		end
	end
	if #models >= 2 then break end
	task.wait(0.5)
end
table.sort(models, function(a, b)
	return a:GetPivot().Position.Z > b:GetPivot().Position.Z -- nearer the drills first
end)

local function setText(label, text)
	if label and label.Text ~= text then label.Text = text end
end
local function setVisible(o, v)
	if o and o.Visible ~= v then o.Visible = v end
end

local function bounce(scale, from)
	scale.Scale = from
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function hideMaxed()
	local value = player:GetAttribute(SettingsConfig.attributeOf("HideMaxUpgrades"))
	if value == nil then
		return SettingsConfig.Settings.HideMaxUpgrades.Default
	end
	return value
end

local entries = {}

local function refreshCard(e)
	local def = e.def
	local level = player:GetAttribute(UpgradeConfig.levelAttribute(e.id)) or 0
	local maxed = level >= def.MaxLevel
	local balance = player:GetAttribute(e.board.currency) or 0
	local shown = not (maxed and hideMaxed())
	setVisible(e.card, shown)

	local current = UpgradeConfig.formatValue(e.id, UpgradeConfig.valueAt(e.id, level))
	if maxed then
		setText(e.level, "MAX")
		setText(e.value, current)
		setText(e.cost, "MAXED")
	else
		local nextValue = UpgradeConfig.formatValue(e.id, UpgradeConfig.valueAt(e.id, level + 1))
		e.price = UpgradeConfig.costAt(e.id, level)
		setText(e.level, level .. "/" .. def.MaxLevel)
		setText(e.value, current .. " -> " .. nextValue)
		setText(e.cost, NumberFormat.abbreviate(e.price) .. " " .. e.board.label)
	end
	local afford = not maxed and balance >= (e.price or math.huge)
	setVisible(e.maxed, maxed)
	setVisible(e.canOne, afford)
	setVisible(e.canMax, afford)
	setVisible(e.cantOne, not maxed and not afford)
	setVisible(e.cantMax, not maxed and not afford)
end

local function refreshAll()
	for _, e in ipairs(entries) do
		refreshCard(e)
	end
end

local function tryBuy(e, mode, button)
	if e.busy then return end
	e.busy = true
	local ok, result = pcall(function()
		return buyRemote:InvokeServer(e.id, mode)
	end)
	local pop = button:FindFirstChild("AffordPopScale")
	if ok and type(result) == "table" and result.ok then
		if pop then bounce(pop, 1.18) end
		bounce(e.scale, 1.06)
	else
		if pop then bounce(pop, 0.85) end
		MessageToPlayer.show("PurchaseUnavailable")
	end
	refreshAll()
	task.wait(0.1)
	e.busy = false
end

for i, board in ipairs(BOARDS) do
	local model = models[i]
	if model then
		-- no auto-upgrade stand for these boards
		for _, name in ipairs({ "AutoUpgradeSurfacePart", "AutoUpgradeBackGround" }) do
			local p = model:FindFirstChild(name)
			if p then
				p.Transparency = 1
				p.CanCollide = false
				for _, d in ipairs(p:GetDescendants()) do
					if d:IsA("SurfaceGui") then d.Enabled = false end
					if d:IsA("ParticleEmitter") then d.Enabled = false end
				end
			end
		end

		local gui = model:WaitForChild("SurfaceGuiPart"):WaitForChild("UpgradeBoardTemplate")
		local locked = gui:FindFirstChild("Locked")
		if locked then locked.Visible = false end
		local list = gui:WaitForChild("ScrollingFrame"):WaitForChild("Frame")
		local template = list:WaitForChild("ScrapTemp")
		template.Visible = false

		for order, id in ipairs(board.upgrades) do
			local def = UpgradeConfig.Upgrades[id]
			local card = template:Clone()
			card.Name = id
			card.LayoutOrder = order
			card.Visible = true
			card.Parent = list
			local cl = card:FindFirstChild("Locked")
			if cl then cl.Visible = false end
			setText(card:FindFirstChild("Title"), def.Name)
			setText(card:FindFirstChild("Desc"), def.Desc or "")
			for _, n in ipairs({ "Icon", "BackIcon" }) do
				local img = card:FindFirstChild(n)
				if img then img.Image = board.icon end
			end
			local buttons = card:WaitForChild("Buttons")
			local scale = Instance.new("UIScale")
			scale.Name = "CardScale"
			scale.Parent = card
			local e = {
				id = id, def = def, board = board, card = card, scale = scale,
				level = card:FindFirstChild("Level"), value = card:FindFirstChild("Multiplier"), cost = card:FindFirstChild("Cost"),
				canOne = buttons:FindFirstChild("CanBuyOne"), canMax = buttons:FindFirstChild("CanBuyMax"),
				cantOne = buttons:FindFirstChild("CantBuyOne"), cantMax = buttons:FindFirstChild("CantBuyMax"),
				maxed = buttons:FindFirstChild("Maxed"),
			}
			table.insert(entries, e)
			e.canOne.Activated:Connect(function() tryBuy(e, "one", e.canOne) end)
			e.canMax.Activated:Connect(function() tryBuy(e, "max", e.canMax) end)
			for _, b in ipairs({ e.cantOne, e.cantMax, e.maxed }) do
				if b then
					b.Activated:Connect(function()
						local pop = b:FindFirstChild("AffordPopScale")
						if pop then bounce(pop, 0.85) end
						MessageToPlayer.show("PurchaseUnavailable")
					end)
				end
			end
			player:GetAttributeChangedSignal(UpgradeConfig.levelAttribute(id)):Connect(refreshAll)
		end

		-- the currency total on top, counting smoothly
		local cur = model:FindFirstChild("CurrencySurfaceGuiPart")
		local tpl = cur and cur:FindFirstChild("CurrencyTemplate", true)
		if tpl then
			local amount = tpl:FindFirstChild("AmountLabel")
			local icon = tpl:FindFirstChild("CurrencyIconImage")
			if icon then
				icon.Image = board.icon
				local nameLabel = icon:FindFirstChild("CurrencyNameLabel")
				if nameLabel then nameLabel.Text = board.label end
			end
			if amount then
				local shown = Instance.new("NumberValue")
				shown.Value = player:GetAttribute(board.currency) or 0
				amount.Text = NumberFormat.abbreviate(shown.Value)
				shown:GetPropertyChangedSignal("Value"):Connect(function()
					setText(amount, NumberFormat.abbreviate(shown.Value))
				end)
				local tween
				player:GetAttributeChangedSignal(board.currency):Connect(function()
					local target = player:GetAttribute(board.currency) or 0
					if tween then tween:Cancel() end
					tween = TweenService:Create(shown, TweenInfo.new(0.5, Enum.EasingStyle.Quart), { Value = target })
					tween:Play()
				end)
			end
		end

		player:GetAttributeChangedSignal(board.currency):Connect(refreshAll)
	else
		warn("DrillBoards: scrapups board " .. i .. " not found")
	end
end

player:GetAttributeChangedSignal(SettingsConfig.attributeOf("HideMaxUpgrades")):Connect(refreshAll)
refreshAll()
