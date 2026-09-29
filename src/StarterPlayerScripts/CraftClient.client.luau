-- DRILLING MANIA: the Craft stall (Workspace.Craft). Oil + Iron -> Coins.
-- Every recipe is a card: [Oil] + [Iron]  ===>  [Coins], with Craft x1 / x10 / MAX.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local DrillConfig = require(ReplicatedStorage:WaitForChild("DrillConfig"))
local DrillVisuals = require(ReplicatedStorage:WaitForChild("DrillVisuals"))
local Multipliers = require(ReplicatedStorage:WaitForChild("Multipliers"))
local Kit = require(ReplicatedStorage:WaitForChild("FishingUIKit"))
local abbreviate = require(ReplicatedStorage:WaitForChild("NumberFormat")).abbreviate
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local actionRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DrillAction")

local INK = Color3.fromRGB(8, 10, 14)
local Icons = DrillConfig.Icons

local w = Kit.glass("CraftShop", "Crafting", { aspect = 1.45, tint = Color3.fromRGB(255, 238, 205) })
w.panel:FindFirstChild("Title").TextColor3 = Color3.fromRGB(255, 220, 90)

-- your Oil / Iron / Coins along the top
local wallet = Kit.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.125), Size = UDim2.fromScale(0.8, 0.055), BackgroundTransparency = 1,
}, w.panel)
Kit.new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder,
}, wallet)
local walletLabels = {}
for i, key in ipairs({ "Oil", "Metal", "Coins" }) do
	local chip = Kit.new("Frame", { LayoutOrder = i, Size = UDim2.fromScale(0.26, 1), BackgroundColor3 = Color3.fromRGB(30, 30, 40), BackgroundTransparency = 0.25 }, wallet)
	Kit.corner(chip, 0.5)
	Kit.stroke(chip, 2.5, INK, true)
	Kit.image(chip, {
		Image = key == "Metal" and Icons.Iron or Icons[key], AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromScale(1.25, 1.25), SizeConstraint = Enum.SizeConstraint.RelativeYY,
	})
	walletLabels[key] = Kit.text(chip, {
		Text = "0", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromScale(0.62, 0.8),
		TextXAlignment = Enum.TextXAlignment.Right, Stroke = 2,
	})
end

local list = Kit.new("ScrollingFrame", {
	Position = UDim2.fromScale(0, 0.06), Size = UDim2.fromScale(1, 0.94), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 7, ScrollBarImageColor3 = Color3.new(1, 1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, w.body)
Kit.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 14) }, list)
Kit.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, list)

-- an icon in a rounded tile with an amount under it
local function tile(parent, x, image, color, amountText)
	local t = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5), Size = UDim2.fromScale(0.8, 0.8),
		SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundColor3 = color,
	}, parent)
	Kit.corner(t, 0.22)
	Kit.stroke(t, 3, INK, true)
	Kit.gradient(t, Color3.new(1, 1, 1), Color3.fromRGB(130, 130, 140))
	local img = Kit.image(t, { Image = image, AnchorPoint = Vector2.new(0.5, 0.45), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.72, 0.72), ZIndex = 2 })
	local amt = Kit.text(t, {
		Text = amountText, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1.02), Size = UDim2.fromScale(1.1, 0.34), ZIndex = 3, Stroke = 2.5,
	})
	return t, img, amt
end

local cards = {}

for i, r in ipairs(DrillConfig.Recipes) do
	local card = Kit.new("Frame", {
		Name = r.id, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = r.color:Lerp(Color3.new(1, 1, 1), 0.35), BackgroundTransparency = 0.3,
	}, list)
	Kit.corner(card, 0.14)
	Kit.stroke(card, 3, INK, true)
	Kit.gradient(card, Color3.new(1, 1, 1), Color3.fromRGB(200, 190, 175))

	local title = Kit.text(card, {
		Text = r.name, Position = UDim2.fromScale(0.02, 0.04), Size = UDim2.fromScale(0.35, 0.2), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = r.color, Stroke = 3,
	})

	-- the recipe strip
	local strip = Kit.new("Frame", { Position = UDim2.fromScale(0.01, 0.24), Size = UDim2.fromScale(0.6, 0.74), BackgroundTransparency = 1 }, card)
	local oilTile, _, oilAmt = tile(strip, 0.1, Icons.Oil, Color3.fromRGB(150, 120, 220), abbreviate(r.oil))
	Kit.text(strip, { Text = "+", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.215, 0.5), Size = UDim2.fromScale(0.07, 0.5), Stroke = 3 })
	local ironTile, _, ironAmt = tile(strip, 0.33, Icons.Iron, Color3.fromRGB(150, 180, 215), abbreviate(r.iron))

	-- the arrow (a shaft + a head) with a light running through it
	local arrow = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.56, 0.5), Size = UDim2.fromScale(0.2, 0.34), BackgroundTransparency = 1,
	}, strip)
	local shaft = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(0.72, 0.45), BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
	}, arrow)
	Kit.corner(shaft, 0.5)
	Kit.stroke(shaft, 3, INK, true)
	Kit.gradient(shaft, Color3.fromRGB(255, 240, 150), Color3.fromRGB(245, 160, 20))
	local light = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.3, 0.5), Size = UDim2.fromScale(0.25, 1.4),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, BorderSizePixel = 0, Rotation = 15,
	}, shaft)
	local head = Kit.text(arrow, {
		Text = "▶", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1.02, 0.5), Size = UDim2.fromScale(0.42, 1.25),
		TextColor3 = Color3.fromRGB(255, 185, 40), Stroke = 3, FontFace = Font.fromEnum(Enum.Font.GothamBlack),
	})

	local coinTile, coinImg, coinAmt = tile(strip, 0.84, Icons.Coins, Color3.fromRGB(255, 215, 80), "")
	Kit.sunburst(coinTile, Color3.fromRGB(255, 250, 200))
	local coinScale = Kit.new("UIScale", {}, coinTile)

	-- buttons
	local can = Kit.text(card, {
		Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.98, 0.06), Size = UDim2.fromScale(0.34, 0.18),
		TextXAlignment = Enum.TextXAlignment.Right, Stroke = 2, TextColor3 = Color3.fromRGB(240, 240, 250),
	})
	local btns = {}
	for j, spec in ipairs({ { "x1", 1 }, { "x10", 10 }, { "MAX", "max" } }) do
		local b, paint = Kit.button(card, {
			Name = spec[1], AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.635 + (j - 1) * 0.118, 0.6), Size = UDim2.fromScale(0.105, 0.44),
		}, spec[1])
		btns[j] = { button = b, paint = paint, count = spec[2] }
		local busy = false
		b.Activated:Connect(function()
			if busy then return end
			busy = true
			local ok, res = pcall(function() return actionRemote:InvokeServer("craft", r.id, spec[2]) end)
			if ok and type(res) == "table" and res.ok then
				Kit.pop(b, 1.2)
				-- the ingredients jump into the arrow, the coin bursts
				Kit.pop(oilTile, 0.8)
				Kit.pop(ironTile, 0.8)
				light.Position = UDim2.fromScale(-0.3, 0.5)
				TweenService:Create(light, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(1.3, 0.5) }):Play()
				task.delay(0.2, function()
					coinScale.Scale = 1.35
					TweenService:Create(coinScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				end)
				local toast = Kit.text(card, {
					Text = "+" .. abbreviate(res.coins) .. " Coins!", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.52, 0.3),
					Size = UDim2.fromScale(0.3, 0.3), TextColor3 = Color3.fromRGB(255, 225, 80), Stroke = 3, ZIndex = 10,
				})
				TweenService:Create(toast, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.52, -0.1), TextTransparency = 1 }):Play()
				local ts = toast:FindFirstChildOfClass("UIStroke")
				if ts then TweenService:Create(ts, TweenInfo.new(0.9), { Transparency = 1 }):Play() end
				task.delay(0.95, function() toast:Destroy() end)
			else
				Kit.pop(b, 0.85)
				MessageToPlayer.show("PurchaseUnavailable")
			end
			busy = false
		end)
	end

	cards[i] = { recipe = r, card = card, coinAmt = coinAmt, can = can, btns = btns, oilAmt = oilAmt, ironAmt = ironAmt, light = light }
end

local function resize()
	local h = math.max(84, math.floor(list.AbsoluteSize.Y * 0.3))
	for _, c in ipairs(cards) do c.card.Size = UDim2.new(1, 0, 0, h) end
end
list:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)

local function refresh()
	local oil = player:GetAttribute("Oil") or 0
	local metal = player:GetAttribute("Metal") or 0
	walletLabels.Oil.Text = abbreviate(math.floor(oil))
	walletLabels.Metal.Text = abbreviate(math.floor(metal))
	walletLabels.Coins.Text = abbreviate(math.floor(player:GetAttribute("Coins") or 0))
	local mult = Multipliers.craftCoins(player)
	for _, c in ipairs(cards) do
		local r = c.recipe
		local most = math.min(math.floor(oil / r.oil), math.floor(metal / r.iron))
		c.coinAmt.Text = abbreviate(math.floor(r.coins * mult))
		c.can.Text = most > 0 and ("Can craft " .. abbreviate(most)) or "Not enough"
		c.can.TextColor3 = most > 0 and Color3.fromRGB(160, 255, 150) or Color3.fromRGB(255, 140, 140)
		c.oilAmt.TextColor3 = oil >= r.oil and Color3.new(1, 1, 1) or Color3.fromRGB(255, 120, 120)
		c.ironAmt.TextColor3 = metal >= r.iron and Color3.new(1, 1, 1) or Color3.fromRGB(255, 120, 120)
		for _, b in ipairs(c.btns) do
			local need = b.count == "max" and 1 or b.count
			b.paint(most >= need and (b.count == "max" and "gold" or "green") or "grey")
		end
	end
end

-- a light runs through each arrow every couple of seconds
task.spawn(function()
	while true do
		if w.isOpen() then
			for k, c in ipairs(cards) do
				task.delay(k * 0.12, function()
					c.light.Position = UDim2.fromScale(-0.3, 0.5)
					TweenService:Create(c.light, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(1.3, 0.5) }):Play()
				end)
			end
		end
		task.wait(2)
	end
end)

player.AttributeChanged:Connect(function(attr)
	if w.isOpen() and (attr == "Oil" or attr == "Metal" or attr == "Coins") then
		refresh()
	end
end)

w.onOpen = function()
	resize()
	refresh()
end

local stall = workspace:WaitForChild("DrillingMania"):WaitForChild("Craft")
local prompt, anchor = DrillVisuals.stallPrompt(stall, "Craft", "Craft", "Crafting")
if prompt then
	prompt.Triggered:Connect(function()
		if w.isOpen() then w.hide() else w.open() end
	end)
	Kit.closeWhenFar(w, function() return anchor.Position end, 24)
end
