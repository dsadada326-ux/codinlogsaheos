-- Equipment Trader UI. Walk up to the trader to open it.
--   Shop page:  your 3 items (rolled by the server each refresh), Buy / Owned buttons,
--               pity counters + refresh timer along the bottom.
--   Index page: every item. Found ones (shown up in your shop, or owned) show their card and
--               "1 in X" odds, the rest are a ??? silhouette.
-- When the shop refreshes, "The Trader Shop just refreshed!" pops up on screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer

local EquipmentConfig = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyRemote = remotes:WaitForChild("BuyEquipment")

local shopModel = workspace:WaitForChild("Islands"):WaitForChild("Island1"):WaitForChild("Zones")
	:WaitForChild("EquipmentTrader"):WaitForChild("EquipmentShop")
local trigger = shopModel:WaitForChild("Hitbox")
local refreshLabel = trigger:FindFirstChild("RefreshLabel", true)

local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("EquipmentShop")
local holder = gui:WaitForChild("Holder")
local top = holder:WaitForChild("Top")

local traderZone = ZoneConfig.find("EquipmentTrader")

local COIN_ICON = "rbxassetid://99928751746150"

local BOOSTS = {
	{ key = "money", icon = "rbxassetid://74760303647639", text = function(v) return "x" .. v end },
	{ key = "coins", icon = COIN_ICON, text = function(v) return "x" .. v end },
	{ key = "time", icon = "rbxassetid://104436607164470", text = function(v) return "x" .. v end },
	{ key = "runeLuck", icon = "rbxassetid://87821576554128", text = function(v) return "x" .. v .. " Luck" end },
	{ key = "runeBulk", icon = "rbxassetid://101935509296686", text = function(v) return "+" .. v .. " Bulk" end },
	{ key = "walkSpeed", icon = "rbxassetid://101881781579355", text = function(v) return "+" .. v .. " Speed" end },
}

-- card colors per rarity: { light (top), dark (bottom) }
local CARD = {
	Common = { Color3.fromRGB(250, 250, 250), Color3.fromRGB(185, 185, 195) },
	Rare = { Color3.fromRGB(160, 230, 255), Color3.fromRGB(35, 145, 245) },
	Epic = { Color3.fromRGB(220, 170, 255), Color3.fromRGB(135, 60, 230) },
	Legendary = { Color3.fromRGB(255, 230, 110), Color3.fromRGB(245, 145, 25) },
	Mythic = { Color3.fromRGB(255, 160, 215), Color3.fromRGB(220, 45, 140) },
}

local BUTTON = {
	green = { Color3.fromRGB(165, 255, 95), Color3.fromRGB(70, 195, 40), Color3.fromRGB(15, 70, 10) },
	red = { Color3.fromRGB(255, 130, 130), Color3.fromRGB(215, 45, 45), Color3.fromRGB(85, 10, 10) },
	grey = { Color3.fromRGB(215, 215, 222), Color3.fromRGB(135, 135, 148), Color3.fromRGB(45, 45, 55) },
	purple = { Color3.fromRGB(200, 150, 255), Color3.fromRGB(125, 60, 225), Color3.fromRGB(45, 15, 90) },
}

local PANEL = Color3.fromRGB(30, 30, 36)
local PANEL_DARK = Color3.fromRGB(20, 20, 25)

local titleLabel = top:FindFirstChild("Title")
local FONT = Font.new(
	titleLabel and titleLabel.FontFace.Family or "rbxasset://fonts/families/FredokaOne.json",
	Enum.FontWeight.Bold
)

------------------------------------------------------------------------------------------
-- little UI helpers
------------------------------------------------------------------------------------------
local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props or {}) do
		i[k] = v
	end
	i.Parent = parent
	return i
end

local function corner(parent, scale)
	return new("UICorner", { CornerRadius = UDim.new(scale or 0.1, 0) }, parent)
end

local function border(parent, thickness, color)
	return new("UIStroke", {
		Thickness = thickness or 3,
		Color = color or Color3.new(0, 0, 0),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function gradient(parent, c1, c2)
	return new("UIGradient", { Rotation = 90, Color = ColorSequence.new(c1, c2) }, parent)
end

local function text(parent, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
	}, parent)
	local maxSize = props.MaxSize or 40
	local strokeSize = props.StrokeSize or 2.5
	local strokeColor = props.StrokeColor or Color3.fromRGB(10, 10, 15)
	props.MaxSize, props.StrokeSize, props.StrokeColor = nil, nil, nil
	for k, v in pairs(props) do
		l[k] = v
	end
	new("UITextSizeConstraint", { MaxTextSize = maxSize }, l)
	new("UIStroke", { Thickness = strokeSize, Color = strokeColor }, l)
	return l
end

local function square(parent, props)
	local img = new("ImageLabel", {
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
	}, parent)
	for k, v in pairs(props) do
		img[k] = v
	end
	new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }, img)
	return img
end

-- a chunky gradient button; returns the button and a paint(styleName) function
local function chunkyButton(parent, props, label)
	local b = new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
	}, parent)
	for k, v in pairs(props) do
		b[k] = v
	end
	corner(b, 0.25)
	local stroke = border(b, 3)
	local grad = gradient(b, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	local title = text(b, {
		Name = "Label",
		Text = label or "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.72),
		MaxSize = 34,
	})

	local function paint(style)
		local c = BUTTON[style]
		grad.Color = ColorSequence.new(c[1], c[2])
		stroke.Color = c[3]
		title:FindFirstChildOfClass("UIStroke").Color = c[3]
	end

	return b, paint, title
end

------------------------------------------------------------------------------------------
-- frame + header
------------------------------------------------------------------------------------------
local oldList = holder:FindFirstChild("ScrollingFrame")
if oldList then
	oldList:Destroy()
end

local oldClose = holder:FindFirstChild("Close")
if oldClose then
	oldClose:Destroy()
end

holder.AnchorPoint = Vector2.new(0.5, 0.5)
holder.Position = UDim2.fromScale(0.5, 0.52)
holder.Size = UDim2.fromScale(0.62, 0.66)
holder.BackgroundColor3 = Color3.fromRGB(44, 44, 52)
new("UIAspectRatioConstraint", { AspectRatio = 1.62 }, holder)

if titleLabel then
	titleLabel.AnchorPoint = Vector2.new(0, 0.5)
	titleLabel.Position = UDim2.fromScale(0.115, 0.5)
	titleLabel.Size = UDim2.fromScale(0.42, 0.78)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "Trader Shop"

	for _, d in ipairs(titleLabel:GetDescendants()) do
		if d:IsA("TextLabel") then
			d.Text = "Trader Shop"
			d.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
end

local closeButton, paintClose = chunkyButton(top, {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(0.985, 0, 0.5, 0),
	Size = UDim2.fromScale(0.1, 0.8),
	ZIndex = 5,
}, "X")
paintClose("red")
new("UIAspectRatioConstraint", { AspectRatio = 1.15 }, closeButton)

local indexButton, paintIndex = chunkyButton(top, {
	Name = "IndexButton",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(0.87, 0, 0.5, 0),
	Size = UDim2.fromScale(0.16, 0.66),
	ZIndex = 5,
}, "Index")
paintIndex("purple")

-- Robux restock (Developer Product; the id lives in EquipmentConfig.RestockProductId)
local restockButton, paintRestock, restockLabel = chunkyButton(top, {
	Name = "RestockButton",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(0.69, 0, 0.5, 0),
	Size = UDim2.fromScale(0.155, 0.66),
	ZIndex = 5,
}, "Restock")
paintRestock("green")
restockLabel.AnchorPoint = Vector2.new(0, 0.5)
restockLabel.Position = UDim2.fromScale(0.3, 0.5)
restockLabel.Size = UDim2.fromScale(0.64, 0.72)

square(restockButton, {
	Name = "Robux",
	Image = "rbxasset://textures/ui/common/robux.png",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0.07, 0.5),
	Size = UDim2.fromScale(0.3, 0.6),
	ZIndex = 6,
})

------------------------------------------------------------------------------------------
-- shop page: 3 cards
------------------------------------------------------------------------------------------
local shopPage = new("Frame", {
	Name = "ShopPage",
	Position = UDim2.fromScale(0.025, 0.19),
	Size = UDim2.fromScale(0.95, 0.66),
	BackgroundColor3 = PANEL,
}, holder)
corner(shopPage, 0.04)
border(shopPage, 3)
new("UIPadding", {
	PaddingLeft = UDim.new(0.025, 0), PaddingRight = UDim.new(0.025, 0),
	PaddingTop = UDim.new(0.045, 0), PaddingBottom = UDim.new(0.045, 0),
}, shopPage)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0.025, 0),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, shopPage)

local emptyLabel = text(shopPage, {
	Text = "Restocking...",
	Size = UDim2.fromScale(0.6, 0.15),
	TextColor3 = Color3.fromRGB(200, 200, 210),
	Visible = false,
})

local cards = {}

local function makeCard(slot)
	local frame = new("Frame", {
		Name = "Card" .. slot,
		LayoutOrder = slot,
		Size = UDim2.fromScale(0.31, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, shopPage)
	corner(frame, 0.07)
	border(frame, 3.5)
	local grad = gradient(frame, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	local scale = new("UIScale", {}, frame)

	local name = text(frame, {
		Name = "ItemName",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.035),
		Size = UDim2.fromScale(0.92, 0.14),
		MaxSize = 36,
		StrokeSize = 3,
	})

	local image = square(frame, {
		Name = "Image",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.185),
		Size = UDim2.fromScale(0.9, 0.33),
	})

	local box = new("Frame", {
		Name = "Boosts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.54),
		Size = UDim2.fromScale(0.86, 0.25),
		BackgroundColor3 = Color3.fromRGB(28, 38, 48),
		BackgroundTransparency = 0.15,
	}, frame)
	corner(box, 0.14)
	new("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, box)

	local buy, paintBuy, buyLabel = chunkyButton(frame, {
		Name = "Buy",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.965),
		Size = UDim2.fromScale(0.86, 0.14),
	})
	buyLabel.AnchorPoint = Vector2.new(0, 0.5)
	buyLabel.Position = UDim2.fromScale(0.26, 0.5)
	buyLabel.Size = UDim2.fromScale(0.68, 0.72)

	local coin = square(buy, {
		Name = "Coin",
		Image = COIN_ICON,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.05, 0.5),
		Size = UDim2.fromScale(0.3, 0.85),
	})

	local card = {
		frame = frame, grad = grad, scale = scale, name = name, image = image, box = box,
		buy = buy, paintBuy = paintBuy, buyLabel = buyLabel, coin = coin, id = nil,
	}
	cards[slot] = card
	return card
end

local function boostRows(card, def)
	for _, c in ipairs(card.box:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end

	local order = 0
	for _, b in ipairs(BOOSTS) do
		local v = def.boosts[b.key]
		if v then
			order += 1
			local row = new("Frame", {
				LayoutOrder = order,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0.3),
			}, card.box)

			if b.icon then
				square(row, {
					Image = b.icon,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(0.4, 0.5),
					Size = UDim2.fromScale(0.3, 0.95),
				})
				text(row, {
					Text = b.text(v),
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0.44, 0.5),
					Size = UDim2.fromScale(0.54, 0.9),
					TextXAlignment = Enum.TextXAlignment.Left,
					MaxSize = 24,
					StrokeSize = 2,
				})
			else
				text(row, {
					Text = b.text(v),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.9, 0.9),
					MaxSize = 24,
					StrokeSize = 2,
				})
			end
		end
	end
end

local busy = false

local function shake(guiObject)
	local home = guiObject.Position
	for _, dx in ipairs({ -0.03, 0.03, -0.02, 0.02, 0 }) do
		guiObject.Position = home + UDim2.fromScale(dx, 0)
		task.wait(0.03)
	end
	guiObject.Position = home
end

local function pop(card)
	card.scale.Scale = 1.08
	TweenService:Create(card.scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

for slot = 1, EquipmentConfig.Slots do
	local card = makeCard(slot)

	card.buy.Activated:Connect(function()
		local id = card.id
		if busy or not id or player:GetAttribute(EquipmentConfig.ownedAttribute(id)) == true then
			return
		end

		busy = true
		local ok, result = pcall(function()
			return buyRemote:InvokeServer(id)
		end)
		busy = false

		if ok and type(result) == "table" and result.ok then
			pop(card)
		else
			task.spawn(shake, card.buy)
		end
	end)
end

local function paintCard(card, id)
	local def = EquipmentConfig.Items[id]
	local changed = card.id ~= id
	card.id = id

	if changed then
		local colors = CARD[def.rarity] or CARD.Common
		card.grad.Color = ColorSequence.new(colors[1], colors[2])
		card.name.Text = def.name
		card.image.Image = def.image
		boostRows(card, def)
	end

	local owned = player:GetAttribute(EquipmentConfig.ownedAttribute(id)) == true

	if owned then
		card.paintBuy("grey")
		card.coin.Visible = false
		card.buyLabel.Text = "Owned"
		card.buyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		card.buyLabel.Position = UDim2.fromScale(0.5, 0.5)
	else
		local coins = player:GetAttribute("Coins") or 0
		card.paintBuy(coins >= def.cost and "green" or "red")
		card.coin.Visible = true
		card.buyLabel.Text = NumberFormat.abbreviate(def.cost)
		card.buyLabel.AnchorPoint = Vector2.new(0, 0.5)
		card.buyLabel.Position = UDim2.fromScale(0.26, 0.5)
	end
end

------------------------------------------------------------------------------------------
-- footer: pity + refresh timer
------------------------------------------------------------------------------------------
local footer = new("Frame", {
	Name = "Footer",
	Position = UDim2.fromScale(0.025, 0.875),
	Size = UDim2.fromScale(0.95, 0.1),
	BackgroundColor3 = PANEL,
}, holder)
corner(footer, 0.35)
border(footer, 3)

local legendaryLabel = text(footer, {
	RichText = true,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0.025, 0.5),
	Size = UDim2.fromScale(0.3, 0.5),
	TextXAlignment = Enum.TextXAlignment.Left,
	MaxSize = 22,
	StrokeSize = 2,
})

local timerLabel = text(footer, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.34, 0.78),
	TextColor3 = Color3.fromRGB(255, 215, 225),
	MaxSize = 32,
	StrokeSize = 2.5,
	Text = "Refresh in: 5m 00s",
})

local mythicLabel = text(footer, {
	RichText = true,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(0.975, 0.5),
	Size = UDim2.fromScale(0.3, 0.5),
	TextXAlignment = Enum.TextXAlignment.Right,
	MaxSize = 22,
	StrokeSize = 2,
})

local function pityText(rarity, color)
	local left = EquipmentConfig.pityLeft(player, rarity)
	return string.format(
		'<font color="%s">%s</font> Pity: %d Refresh%s',
		color, rarity, left, left == 1 and "" or "es"
	)
end

local function paintFooter()
	legendaryLabel.Text = pityText("Legendary", "#FFD23C")
	mythicLabel.Text = pityText("Mythic", "#FF6EBE")
end

------------------------------------------------------------------------------------------
-- index page
------------------------------------------------------------------------------------------
local indexPage = new("Frame", {
	Name = "IndexPage",
	Position = UDim2.fromScale(0.025, 0.19),
	Size = UDim2.fromScale(0.95, 0.785),
	BackgroundColor3 = PANEL,
	Visible = false,
}, holder)
corner(indexPage, 0.035)
border(indexPage, 3)

text(indexPage, {
	Text = "Item Index",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.fromScale(0.025, 0.025),
	Size = UDim2.fromScale(0.3, 0.11),
	TextXAlignment = Enum.TextXAlignment.Left,
	MaxSize = 36,
	StrokeSize = 3,
})

local foundPill = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.03),
	Size = UDim2.fromScale(0.28, 0.1),
	BackgroundColor3 = PANEL_DARK,
}, indexPage)
corner(foundPill, 0.5)
border(foundPill, 2, Color3.fromRGB(55, 55, 65))

local foundLabel = text(foundPill, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.85, 0.7),
	MaxSize = 26,
	StrokeSize = 2,
})

local backButton, paintBack = chunkyButton(indexPage, {
	Name = "Back",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(0.975, 0.025),
	Size = UDim2.fromScale(0.17, 0.11),
}, "Back")
paintBack("red")

local grid = new("ScrollingFrame", {
	Name = "Grid",
	Position = UDim2.fromScale(0.02, 0.16),
	Size = UDim2.fromScale(0.96, 0.81),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Color3.fromRGB(150, 150, 165),
	ScrollingDirection = Enum.ScrollingDirection.Y,
}, indexPage)
new("UIPadding", {
	PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
	PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12),
}, grid)

local COLUMNS = 6
local GAP = 8
local gridLayout = new("UIGridLayout", {
	CellPadding = UDim2.fromOffset(GAP, GAP),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Left,
}, grid)

local function sizeGrid()
	local width = grid.AbsoluteSize.X - 16
	local cell = math.max(40, math.floor((width - GAP * (COLUMNS - 1)) / COLUMNS))
	gridLayout.CellSize = UDim2.fromOffset(cell, math.floor(cell * 1.05))
end
grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeGrid)
sizeGrid()

local function oddsText(id)
	local p = EquipmentConfig.appearChance(id)
	if p <= 0 then
		return "???"
	end

	local n = 1 / p
	if n < 100 then
		return "1 in " .. string.format("%.1f", n):gsub("%.0$", "")
	end
	if n < 1000 then
		return "1 in " .. math.floor(n + 0.5)
	end
	return "1 in " .. NumberFormat.abbreviate(math.floor(n + 0.5))
end

local indexCells = {}

local function darker(c, amount)
	return c:Lerp(Color3.new(0, 0, 0), amount)
end

for i, id in ipairs(EquipmentConfig.Order) do
	local def = EquipmentConfig.Items[id]
	local colors = CARD[def.rarity] or CARD.Common

	local cell = new("Frame", {
		Name = id,
		LayoutOrder = i,
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, grid)
	corner(cell, 0.1)
	local stroke = border(cell, 2, Color3.fromRGB(10, 10, 14))
	local grad = gradient(cell, colors[1], colors[2])

	local name = text(cell, {
		Text = def.name,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.04),
		Size = UDim2.fromScale(0.92, 0.17),
		MaxSize = 22,
		StrokeSize = 2,
	})

	local image = square(cell, {
		Image = def.image,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromScale(0.9, 0.42),
	})

	local rarity = text(cell, {
		Text = def.rarity,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.fromScale(0.8, 0.12),
		MaxSize = 16,
		StrokeSize = 1.5,
	})

	local oddsPill = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromScale(0.8, 0.14),
		BackgroundColor3 = Color3.fromRGB(30, 40, 50),
		BackgroundTransparency = 0.15,
	}, cell)
	corner(oddsPill, 0.5)
	text(oddsPill, {
		Text = oddsText(id),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.8),
		MaxSize = 16,
		StrokeSize = 1.5,
	})

	local unknown = text(cell, {
		Text = "???",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.34),
		TextColor3 = Color3.fromRGB(215, 215, 225),
		MaxSize = 40,
		StrokeSize = 3,
		ZIndex = 3,
	})

	indexCells[id] = {
		cell = cell, grad = grad, stroke = stroke, name = name, image = image,
		rarity = rarity, odds = oddsPill, unknown = unknown, colors = colors,
	}
end

local function paintIndex()
	local found = 0

	for _, id in ipairs(EquipmentConfig.Order) do
		local c = indexCells[id]
		local isFound = EquipmentConfig.discovered(player, id)

		if isFound then
			found += 1
			c.grad.Color = ColorSequence.new(c.colors[1], c.colors[2])
			c.image.ImageColor3 = Color3.new(1, 1, 1)
			c.image.ImageTransparency = 0
			c.stroke.Color = Color3.fromRGB(10, 10, 14)
		else
			-- dark, rarity-tinted card with a black silhouette
			c.grad.Color = ColorSequence.new(darker(c.colors[1], 0.78), darker(c.colors[2], 0.82))
			c.image.ImageColor3 = Color3.new(0, 0, 0)
			c.image.ImageTransparency = 0.15
			c.stroke.Color = Color3.fromRGB(55, 55, 62)
		end

		c.name.Visible = isFound
		c.rarity.Visible = isFound
		c.odds.Visible = isFound
		c.unknown.Visible = not isFound
	end

	foundLabel.Text = found .. " / " .. #EquipmentConfig.Order .. " Found"
end

------------------------------------------------------------------------------------------
-- pages
------------------------------------------------------------------------------------------
local onIndex = false

local function showPage(index)
	onIndex = index
	shopPage.Visible = not index
	footer.Visible = not index
	indexPage.Visible = index
	indexButton.Visible = not index

	if index then
		paintIndex()
	end
end

indexButton.Activated:Connect(function()
	showPage(true)
end)

backButton.Activated:Connect(function()
	showPage(false)
end)

------------------------------------------------------------------------------------------
-- render the shop
------------------------------------------------------------------------------------------
local lastStockKey = ""

local function render(animate)
	local stock = EquipmentConfig.stockOf(player)
	local key = table.concat(stock, ",")
	local newStock = key ~= lastStockKey
	lastStockKey = key

	emptyLabel.Visible = #stock == 0

	for slot, card in ipairs(cards) do
		local id = stock[slot]
		card.frame.Visible = id ~= nil

		if id then
			paintCard(card, id)

			if animate and newStock then
				card.scale.Scale = 0
				task.delay((slot - 1) * 0.07, function()
					TweenService:Create(card.scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				end)
			end
		end
	end

	paintFooter()

	if onIndex then
		paintIndex()
	end
end

------------------------------------------------------------------------------------------
-- "The Trader Shop just refreshed!" pop-up
------------------------------------------------------------------------------------------
local toastGui = new("ScreenGui", {
	Name = "TraderRefreshToast",
	ResetOnSpawn = false,
	DisplayOrder = 20,
	IgnoreGuiInset = false,
}, playerGui)

local toast = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.1),
	Size = UDim2.fromScale(0.55, 0.075),
	BackgroundTransparency = 1,
	FontFace = FONT,
	Text = "The Trader Shop just refreshed!",
	TextColor3 = Color3.new(1, 1, 1),
	TextScaled = true,
	Visible = false,
}, toastGui)
new("UITextSizeConstraint", { MaxTextSize = 52 }, toast)
local toastStroke = new("UIStroke", { Thickness = 3.5, Color = Color3.fromRGB(20, 35, 5) }, toast)
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(235, 255, 90), Color3.fromRGB(140, 225, 30)),
}, toast)
local toastScale = new("UIScale", { Scale = 0 }, toast)

local toastId = 0

local function showToast(message)
	toastId += 1
	local mine = toastId

	toast.Text = message or "The Trader Shop just refreshed!"
	toast.Visible = true
	toast.Position = UDim2.fromScale(0.5, 0.1)
	toast.Rotation = -6
	toast.TextTransparency = 0
	toastStroke.Transparency = 0
	toastScale.Scale = 0

	local popIn = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(toastScale, popIn, { Scale = 1 }):Play()
	TweenService:Create(toast, popIn, { Rotation = 0 }):Play()

	task.delay(1.6, function()
		if toastId ~= mine then return end

		local fade = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(toast, fade, { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.06) }):Play()
		TweenService:Create(toastStroke, fade, { Transparency = 1 }):Play()

		task.delay(0.5, function()
			if toastId == mine then
				toast.Visible = false
			end
		end)
	end)
end

-- a TraderWindow change after you've loaded in = the shop refreshed
local readyAt = nil

task.spawn(function()
	while player:GetAttribute("DataLoaded") ~= true do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
	readyAt = os.clock() + 4 -- ignore the roll that happens right as you join
end)

-- bought a Robux restock
player:GetAttributeChangedSignal("TraderRestocks"):Connect(function()
	showToast("The Trader Shop was restocked!")

	if gui.Enabled then
		render(true)
	end
end)

restockButton.Activated:Connect(function()
	local id = EquipmentConfig.RestockProductId

	if not id or id == 0 then
		showToast("Restock isn't set up yet (no product ID)")
		return
	end

	MarketplaceService:PromptProductPurchase(player, id)
end)

player:GetAttributeChangedSignal("TraderWindow"):Connect(function()
	if readyAt and os.clock() >= readyAt and ZoneConfig.isRevealed(player, traderZone) then
		showToast()
	end

	if gui.Enabled then
		render(true)
	end
end)

------------------------------------------------------------------------------------------
-- open near the trader, close when you walk away (X keeps it closed until you step off)
------------------------------------------------------------------------------------------
local dismissed = false
local inside = false

closeButton.Activated:Connect(function()
	gui.Enabled = false
	dismissed = true
end)

local function near()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root then
		return false
	end

	local l = trigger.CFrame:PointToObjectSpace(root.Position)
	local half = trigger.Size / 2 + Vector3.new(2, 4, 2)

	return math.abs(l.X) <= half.X and math.abs(l.Y) <= half.Y and math.abs(l.Z) <= half.Z
end

gui.Enabled = false
local accum = 0

RunService.Heartbeat:Connect(function(dt)
	accum += dt
	if accum < 0.25 then
		return
	end
	accum = 0

	local s = math.max(0, math.floor(EquipmentConfig.secondsLeft(workspace:GetServerTimeNow())))
	local timer = string.format("Refresh in: %dm %02ds", math.floor(s / 60), s % 60)
	timerLabel.Text = timer
	if refreshLabel then
		refreshLabel.Text = timer
	end

	local isNear = ZoneConfig.isRevealed(player, traderZone) and near()

	if isNear and not inside then
		inside = true

		if not dismissed then
			showPage(false)
			lastStockKey = ""
			render(true)
			gui.Enabled = true

			local scale = holder:FindFirstChild("OpenScale") or new("UIScale", { Name = "OpenScale" }, holder)
			scale.Scale = 0.8
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	elseif not isNear and inside then
		inside = false
		dismissed = false
		gui.Enabled = false
	end
end)

------------------------------------------------------------------------------------------
-- live updates while open (coins, purchases, pity, discoveries)
------------------------------------------------------------------------------------------
local dirty = false

player.AttributeChanged:Connect(function(name)
	if name == "Coins" or name:sub(1, 6) == "Trader" or name:sub(1, 10) == "Equipment_" then
		dirty = true
	end
end)

RunService.Heartbeat:Connect(function()
	if dirty and gui.Enabled then
		dirty = false
		render(false)
	end
end)
