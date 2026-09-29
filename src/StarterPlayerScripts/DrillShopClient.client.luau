-- DRILLING MANIA: the Drill Shop stall (Workspace.DrillShop). Same frosted glass look as the
-- Rod Shop: every drill with its rarity, Oil per second, how many you own and a buy button.
-- Side panel: the next drill you can't afford yet, spinning on a sunburst.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local DrillConfig = require(ReplicatedStorage:WaitForChild("DrillConfig"))
local DrillVisuals = require(ReplicatedStorage:WaitForChild("DrillVisuals"))
local Multipliers = require(ReplicatedStorage:WaitForChild("Multipliers"))
local Kit = require(ReplicatedStorage:WaitForChild("FishingUIKit"))
local abbreviate = require(ReplicatedStorage:WaitForChild("NumberFormat")).abbreviate
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local actionRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DrillAction")

local ICON = DrillConfig.Icons.Iron
local INK = Color3.fromRGB(8, 10, 14)

local w = Kit.glass("DrillShop", "Drill Shop", { side = true, main = 0.75, aspect = 1.55, tint = Color3.fromRGB(225, 225, 235) })
w.panel:FindFirstChild("Title").TextColor3 = Color3.fromRGB(255, 215, 120)
if w.side then
	w.side.BackgroundColor3 = Color3.fromRGB(215, 215, 235)
end

local function fmtRate(n)
	return abbreviate(math.floor(n * 10 + 0.5) / 10)
end

local list = Kit.new("ScrollingFrame", {
	Name = "List", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 7, ScrollBarImageColor3 = Color3.fromRGB(250, 250, 250), ScrollBarImageTransparency = 0.3,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
}, w.body)
Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 16) }, list)
Kit.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local rows = {}

local function makeRow(i, drill)
	local color = DrillVisuals.rarityColor(drill.rarity)
	local row = Kit.new("Frame", {
		Name = drill.id, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.55),
		BackgroundTransparency = 0.4,
	}, list)
	Kit.corner(row, 0.16)
	Kit.stroke(row, 3, INK, true)

	local stage = Kit.new("Frame", {
		Position = UDim2.fromScale(0.015, 0.06), Size = UDim2.fromScale(0.19, 0.88), BackgroundColor3 = color, BackgroundTransparency = 0.35,
	}, row)
	Kit.corner(stage, 0.2)
	Kit.stroke(stage, 2.5, INK, true)
	Kit.gradient(stage, Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 130))
	DrillVisuals.viewport(stage, drill, { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, 25)

	Kit.text(row, {
		Text = drill.name, Position = UDim2.fromScale(0.23, 0.08), Size = UDim2.fromScale(0.45, 0.34),
		TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4, Max = 40,
	})
	local tag = Kit.new("Frame", {
		Position = UDim2.fromScale(0.23, 0.48), Size = UDim2.fromScale(0.15, 0.2), BackgroundColor3 = color,
	}, row)
	Kit.corner(tag, 0.5)
	Kit.stroke(tag, 2.5, INK, true)
	Kit.gradient(tag, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 160))
	Kit.text(tag, {
		Text = drill.rarity, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.8), Stroke = 2,
	})
	local rate = Kit.text(row, {
		Text = "", Position = UDim2.fromScale(0.4, 0.47), Size = UDim2.fromScale(0.3, 0.22),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(215, 190, 255), Stroke = 2.5, Max = 26,
	})
	local owned = Kit.text(row, {
		Text = "", Position = UDim2.fromScale(0.23, 0.74), Size = UDim2.fromScale(0.45, 0.18),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(235, 240, 250), Stroke = 2, Max = 22,
	})

	local stockLabel = Kit.text(row, {
		Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0.97, 0, 0.08, 0), Size = UDim2.fromScale(0.25, 0.2),
		Stroke = 2.5, Max = 24,
	})
	local button, paint, label = Kit.button(row, {
		Name = "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.97, 0, 0.6, 0), Size = UDim2.fromScale(0.25, 0.42),
	}, "NO STOCK")
	label.Visible = false
	local priceRow = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, button)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
	}, priceRow)
	local price = Kit.text(priceRow, { Text = abbreviate(drill.price), Size = UDim2.fromScale(0, 0.62), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Max = 30, Stroke = 2.5 })
	Kit.image(priceRow, { Image = ICON, Size = UDim2.fromScale(0.75, 0.75), SizeConstraint = Enum.SizeConstraint.RelativeYY, LayoutOrder = 2 })

	local busy = false
	button.Activated:Connect(function()
		if busy then return end
		busy = true
		local ok, result = pcall(function() return actionRemote:InvokeServer("buyDrill", drill.id) end)
		if ok and type(result) == "table" and result.ok then
			Kit.pop(row, 1.05)
			Kit.pop(button, 1.2)
			Kit.pop(stockLabel, 1.3)
		else
			Kit.pop(button, 0.85)
			MessageToPlayer.show("PurchaseUnavailable")
		end
		busy = false
	end)

	rows[i] = { row = row, drill = drill, paint = paint, price = price, rate = rate, owned = owned, stock = stockLabel, label = label, priceRow = priceRow, stage = stage }
end

for i, drill in ipairs(DrillConfig.Drills) do
	makeRow(i, drill)
end

local function resizeRows()
	local h = math.max(80, math.floor(list.AbsoluteSize.Y * 0.34))
	for _, r in ipairs(rows) do r.row.Size = UDim2.new(1, 0, 0, h) end
end
list:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeRows)

------------------------------------------------------------------------------------------
-- side panel: next drill
------------------------------------------------------------------------------------------
local side = w.side
local sideTitle = Kit.text(side, {
	Text = "Save up for:", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.04), Size = UDim2.fromScale(0.9, 0.08),
	TextColor3 = Color3.fromRGB(255, 225, 90), Max = 24, Stroke = 2.5,
})
local sideName = Kit.text(side, {
	Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.13), Size = UDim2.fromScale(0.92, 0.09), Max = 26, Stroke = 2.5,
})
local stage = Kit.new("Frame", {
	Name = "Stage", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.24), Size = UDim2.fromScale(0.96, 0.46), BackgroundTransparency = 1,
}, side)
Kit.sunburst(stage, Color3.fromRGB(255, 255, 240))
local sideStats = Kit.text(side, {
	Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromScale(0.92, 0.08),
	TextColor3 = Color3.fromRGB(215, 190, 255), Max = 22, Stroke = 2.5,
})
local sidePriceRow = Kit.new("Frame", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.83), Size = UDim2.fromScale(0.9, 0.1),
}, side)
Kit.new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
}, sidePriceRow)
local sidePrice = Kit.text(sidePriceRow, { Text = "", Size = UDim2.fromScale(0, 0.9), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Max = 26, Stroke = 2.5 })
local sidePriceIcon = Kit.image(sidePriceRow, { Image = ICON, Size = UDim2.fromScale(0.9, 0.9), SizeConstraint = Enum.SizeConstraint.RelativeYY, LayoutOrder = 2 })

local sideView, sideModel, sideCenter, shown
local function showSide(drill)
	if not drill then
		sideTitle.Text = "You can afford"
		sideName.Text = "every drill!"
		sideStats.Text = ""
		sidePrice.Text = ""
		sidePriceIcon.Visible = false
		if sideView then sideView:Destroy() sideView = nil end
		shown = nil
		return
	end
	sideTitle.Text = "Save up for:"
	sideName.Text = drill.name
	sideName.TextColor3 = DrillVisuals.rarityColor(drill.rarity)
	sideStats.Text = "🛢 " .. fmtRate(drill.rate * Multipliers.oil(player)) .. " Oil/s"
	sidePrice.Text = abbreviate(drill.price)
	sidePrice.TextColor3 = Color3.fromRGB(255, 120, 120)
	sidePriceIcon.Visible = true
	if shown ~= drill then
		shown = drill
		if sideView then sideView:Destroy() end
		sideView, sideModel, sideCenter = DrillVisuals.viewport(stage, drill, { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, 0)
	end
end

RunService.RenderStepped:Connect(function(dt)
	if w.isOpen() and sideModel and sideModel.Parent and sideCenter then
		sideModel:PivotTo(CFrame.new(sideCenter) * CFrame.Angles(0, dt * 0.9, 0) * CFrame.new(-sideCenter) * sideModel:GetPivot())
	end
end)

------------------------------------------------------------------------------------------
local function refresh()
	local metal = player:GetAttribute("Metal") or 0
	local inv = DrillConfig.inventory(player)
	local placedCount = {}
	for _, id in pairs(DrillConfig.placed(player)) do
		placedCount[id] = (placedCount[id] or 0) + 1
	end
	local oilMult = Multipliers.oil(player)
	local stock = DrillConfig.stock(player)
	local nextDrill
	for _, r in ipairs(rows) do
		local afford = metal >= r.drill.price
		local left = stock[r.drill.id] or 0
		r.stock.Text = left > 0 and ("x" .. left .. " Stock") or "NO STOCK"
		r.stock.TextColor3 = left > 0 and Color3.fromRGB(150, 255, 140) or Color3.fromRGB(255, 120, 120)
		r.label.Visible = left <= 0
		r.priceRow.Visible = left > 0
		r.row.BackgroundTransparency = left > 0 and 0.4 or 0.7
		r.stage.BackgroundTransparency = left > 0 and 0.35 or 0.75
		r.paint(left <= 0 and "grey" or (afford and "green" or "red"))
		r.rate.Text = "🛢 " .. fmtRate(r.drill.rate * oilMult) .. " Oil/s"
		local have = (inv[r.drill.id] or 0) + (placedCount[r.drill.id] or 0)
		r.owned.Text = have > 0 and ("Owned: " .. have .. ((placedCount[r.drill.id] or 0) > 0 and ("  (" .. placedCount[r.drill.id] .. " placed)") or "")) or "Not owned yet"
		if not afford and not nextDrill then nextDrill = r.drill end
	end
	showSide(nextDrill)
end

player.AttributeChanged:Connect(function(attr)
	if w.isOpen() and (attr == "Metal" or attr == "DrillInv" or attr == "DrillPlaced" or attr == "DrillStock" or attr:find("Upgrade_OilMultiplier")) then
		refresh()
	end
end)

w.onOpen = function()
	resizeRows()
	refresh()
end

------------------------------------------------------------------------------------------
-- restock timer + Robux restock button (top of the window, like the Trader Shop)
------------------------------------------------------------------------------------------
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local S = DrillConfig.Stock

local titleLabel = w.panel:FindFirstChild("Title")
if titleLabel then titleLabel.Size = UDim2.fromScale(0.42, 0.12) end

local timerBox = Kit.new("Frame", {
	Name = "RestockTimer", Position = UDim2.fromScale(0.025, 0.035), Size = UDim2.fromScale(0.25, 0.08),
	BackgroundColor3 = Color3.fromRGB(30, 32, 42), BackgroundTransparency = 0.15,
}, w.panel)
Kit.corner(timerBox, 0.35)
Kit.stroke(timerBox, 3, INK, true)
Kit.text(timerBox, {
	Text = "New stock in", Position = UDim2.fromScale(0.06, 0.06), Size = UDim2.fromScale(0.88, 0.4), Stroke = 1.5, Max = 18,
	TextColor3 = Color3.fromRGB(210, 215, 230),
})
local timerText = Kit.text(timerBox, {
	Text = "5:00", Position = UDim2.fromScale(0.06, 0.44), Size = UDim2.fromScale(0.88, 0.52), Stroke = 2.5, Max = 30,
	TextColor3 = Color3.fromRGB(255, 225, 90),
})

local restock, paintRestock, restockLabel = Kit.button(w.panel, {
	Name = "Restock", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.975, 0.03), Size = UDim2.fromScale(0.25, 0.09),
}, "Restock  \u{E002}" .. S.RestockPrice)
paintRestock("green")
restockLabel.Size = UDim2.fromScale(0.9, 0.7)
local shine = Kit.new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(-0.2, 0.5), Size = UDim2.new(0.12, 0, 2, 0), Rotation = 20, ZIndex = 3,
}, restock)
restock.ClipsDescendants = true

-- "restocked!" banner
local banner = Kit.text(w.panel, {
	Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromScale(0.7, 0.12),
	TextColor3 = Color3.fromRGB(150, 255, 140), Stroke = 4, ZIndex = 20, Visible = false,
})
local bannerScale = Kit.new("UIScale", {}, banner)
local bannerToken = 0
local function showBanner(text)
	bannerToken += 1
	local my = bannerToken
	banner.Text = text
	banner.Visible = true
	banner.TextTransparency = 0
	bannerScale.Scale = 0.4
	TweenService:Create(bannerScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(1.4, function()
		if my ~= bannerToken then return end
		TweenService:Create(banner, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.4)
		if my == bannerToken then banner.Visible = false end
	end)
end

local restockBusy = false
restock.Activated:Connect(function()
	if restockBusy then return end
	Kit.pop(restock, 0.9)
	if S.RestockProductId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, S.RestockProductId)
		return
	end
	-- no product id yet: free in Studio so it can be tested
	restockBusy = true
	local ok, r = pcall(function() return actionRemote:InvokeServer("restockTest") end)
	if not (ok and type(r) == "table" and r.ok) then
		showBanner("Restock isn't set up yet")
	end
	restockBusy = false
end)

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DrillEvent").OnClientEvent:Connect(function(kind, forced)
	if kind ~= "restocked" then return end
	if w.isOpen() then
		showBanner(forced and "Restocked!" or "The Drill Shop restocked!")
		for k, r in ipairs(rows) do
			task.delay(k * 0.03, function() Kit.pop(r.row, 1.04) end)
		end
	end
end)

task.spawn(function()
	local tick = 0
	while true do
		local t = workspace:GetServerTimeNow()
		local left = math.max(0, math.ceil(S.RestockSeconds - (t % S.RestockSeconds)))
		timerText.Text = string.format("%d:%02d", left // 60, left % 60)
		timerText.TextColor3 = left <= 10 and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(255, 225, 90)
		tick += 1
		if w.isOpen() and tick % 3 == 0 then
			shine.Position = UDim2.fromScale(-0.2, 0.5)
			TweenService:Create(shine, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(1.2, 0.5) }):Play()
		end
		task.wait(1)
	end
end)

local stall = workspace:WaitForChild("DrillingMania"):WaitForChild("DrillShop")
local prompt, anchor = DrillVisuals.stallPrompt(stall, "DrillShop", "Shop", "Drill Shop")
if prompt then
	prompt.Triggered:Connect(function()
		if w.isOpen() then w.hide() else w.open() end
	end)
	Kit.closeWhenFar(w, function() return anchor.Position end, 24)
end
