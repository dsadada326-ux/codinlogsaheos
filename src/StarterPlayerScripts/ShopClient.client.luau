-- The Shop menu (built in code; the old StarterGui.Shop is switched off).
-- One scrolling page: Featured (Gamepass Bundle + Global Runes), Gamepasses, Gems.
-- The switch at the top right flips every price between Robux and Tickets: anything can be bought
-- with Tickets instead (you get Tickets for playing - ShopService). Prices live in ShopConfig.
-- Opened by the Shop button on the left and the + next to your Gems.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local Kit = require(ReplicatedStorage:WaitForChild("FishingUIKit"))
local abbreviate = require(ReplicatedStorage:WaitForChild("NumberFormat")).abbreviate
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyTicketsRemote = remotes:WaitForChild("BuyTicketItem")
local shopEvent = remotes:WaitForChild("ShopEvent")

local INK = Color3.fromRGB(14, 18, 30)
local ROBUX = "\u{E002}"
local TICKET_ICON = ShopConfig.Tickets.icon
local GEM_ICON = ShopConfig.GemIcon

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function lighten(c, k) return c:Lerp(Color3.new(1, 1, 1), k) end
local function darken(c, k) return c:Lerp(Color3.new(0, 0, 0), k) end

-- Robux prices in full with commas (1,099 not 1K)
local function commas(n)
	local s = tostring(math.floor(n))
	while true do
		local k
		s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return s
end

local function fmtTime(s)
	s = math.max(0, math.floor(s))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- keeps an image bobbing / wobbling while the shop is open
local wobblers = {}
local function wobble(obj, kind, seed)
	table.insert(wobblers, { obj = obj, kind = kind, seed = seed or math.random() * 6, base = obj.Position })
end

------------------------------------------------------------------------------------------
-- window
------------------------------------------------------------------------------------------
local gui = Kit.new("ScreenGui", {
	Name = "ShopMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 25, Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local dim = Kit.new("TextButton", {
	Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
	Text = "", AutoButtonColor = false,
}, gui)

local panel = Kit.new("Frame", {
	Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.62, 0.78), BackgroundColor3 = Color3.fromRGB(26, 34, 54),
}, gui)
Kit.corner(panel, 0.04)
Kit.stroke(panel, 5, INK, true)
Kit.new("UIAspectRatioConstraint", { AspectRatio = 1.45 }, panel)
Kit.new("UISizeConstraint", { MaxSize = Vector2.new(1080, 745), MinSize = Vector2.new(460, 318) }, panel)
Kit.new("ImageLabel", {
	Name = "Checker", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = "rbxassetid://6372755229",
	ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(64, 64), ImageTransparency = 0.92,
}, panel)
local openScale = Kit.new("UIScale", { Name = "OpenScale" }, panel)

-- header
local header = Kit.new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0.125, 0), BackgroundColor3 = Color3.new(1, 1, 1) }, panel)
Kit.corner(header, 0.28)
Kit.stroke(header, 4, INK, true)
local headerGrad = Kit.gradient(header, Color3.fromRGB(110, 205, 255), Color3.fromRGB(35, 105, 235))
Kit.new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, Size = UDim2.new(1, -16, 0.45, 0),
	Position = UDim2.fromOffset(8, 4), BorderSizePixel = 0,
}, header)
local headerIcon = Kit.new("ImageLabel", {
	Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.012, 0.42),
	Size = UDim2.fromScale(0.1, 1.4), Image = "rbxassetid://100728051235087", ScaleType = Enum.ScaleType.Fit,
}, header)
Kit.text(header, {
	Name = "Title", Text = "SHOP", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.115, 0.5),
	Size = UDim2.fromScale(0.2, 0.78), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4, Max = 54,
})

local close, paintClose = Kit.button(header, {
	Name = "Close", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromScale(0.07, 0.8),
}, "X")
paintClose("red")
Kit.new("UIAspectRatioConstraint", { AspectRatio = 1 }, close)

-- your Tickets + time to the next one
local pill = Kit.new("Frame", {
	Name = "Tickets", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.33, 0.5), Size = UDim2.fromScale(0.25, 0.72),
	BackgroundColor3 = Color3.new(1, 1, 1),
}, header)
Kit.corner(pill, 0.4)
Kit.stroke(pill, 3, INK, true)
Kit.gradient(pill, Color3.fromRGB(255, 236, 120), Color3.fromRGB(245, 165, 30))
local pillIcon = Kit.new("ImageLabel", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(-0.07, 0.5),
	Size = UDim2.fromScale(0.3, 1.5), Image = TICKET_ICON, ScaleType = Enum.ScaleType.Fit, Rotation = -12,
}, pill)
local pillCount = Kit.text(pill, {
	Text = "0", Position = UDim2.fromScale(0.25, 0.05), Size = UDim2.fromScale(0.72, 0.55), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3,
})
local pillCountScale = Kit.new("UIScale", {}, pillCount)
local pillBarBack = Kit.new("Frame", {
	Position = UDim2.fromScale(0.26, 0.64), Size = UDim2.fromScale(0.68, 0.22), BackgroundColor3 = Color3.fromRGB(110, 60, 10),
}, pill)
Kit.corner(pillBarBack, 1)
local pillBar = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, pillBarBack)
Kit.corner(pillBar, 1)
Kit.gradient(pillBar, Color3.fromRGB(180, 255, 140), Color3.fromRGB(60, 200, 70), 0)
local pillTimer = Kit.text(pillBarBack, {
	Text = "+1 in 5:00", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1.7), Stroke = 2,
})

------------------------------------------------------------------------------------------
-- the Robux / Tickets switch
------------------------------------------------------------------------------------------
local mode = "robux"
local switch = Kit.new("TextButton", {
	Name = "Switch", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.915, -12, 0.5, 0), Size = UDim2.fromScale(0.23, 0.72),
	BackgroundColor3 = Color3.fromRGB(20, 26, 42), Text = "", AutoButtonColor = false,
}, header)
Kit.corner(switch, 1)
Kit.stroke(switch, 3, INK, true)
local switchScale = Kit.new("UIScale", {}, switch)
switch.MouseEnter:Connect(function() tween(switchScale, 0.12, { Scale = 1.05 }) end)
switch.MouseLeave:Connect(function() tween(switchScale, 0.12, { Scale = 1 }) end)

local function sideLabel(text, x, img)
	local f = Kit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(x, 0), Size = UDim2.fromScale(0.5, 1), ZIndex = 2 }, switch)
	if img then
		Kit.new("ImageLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.8), Image = img, ScaleType = Enum.ScaleType.Fit, ImageTransparency = 0.45, ZIndex = 2,
		}, f)
	else
		Kit.text(f, { Text = text, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.6), TextTransparency = 0.45, Stroke = 0, ZIndex = 2 })
	end
	return f
end
sideLabel(ROBUX .. " Robux", 0)
sideLabel(nil, 0.5, TICKET_ICON)

local knob = Kit.new("Frame", {
	Name = "Knob", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.new(0.5, -4, 1, -8),
	BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3,
}, switch)
Kit.corner(knob, 1)
Kit.stroke(knob, 2.5, INK, true)
local knobGrad = Kit.gradient(knob, Color3.fromRGB(150, 255, 110), Color3.fromRGB(40, 185, 60))
local knobText = Kit.text(knob, {
	Text = ROBUX .. " Robux", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.7), Stroke = 2.5, ZIndex = 4,
})
Kit.text(switch, {
	Text = "tap to switch", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 1), Size = UDim2.fromScale(0.8, 0.32),
	TextColor3 = Color3.fromRGB(230, 240, 255), Stroke = 1.5,
})

------------------------------------------------------------------------------------------
-- the scrolling page
------------------------------------------------------------------------------------------
local scroll = Kit.new("ScrollingFrame", {
	Name = "Scroll", Position = UDim2.fromScale(0.015, 0.155), Size = UDim2.fromScale(0.97, 0.825),
	BackgroundColor3 = Color3.fromRGB(16, 22, 38), BackgroundTransparency = 0.35, BorderSizePixel = 0,
	ScrollBarThickness = 9, ScrollBarImageColor3 = Color3.fromRGB(200, 215, 240), CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
}, panel)
Kit.corner(scroll, 0.035)
Kit.stroke(scroll, 3, INK, true)
Kit.new("UIPadding", {
	PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 20), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 22),
}, scroll)
Kit.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, scroll)

local order = 0
local function nextOrder() order += 1 return order end

local function section(text, icon)
	local f = Kit.new("Frame", { Name = text, LayoutOrder = nextOrder(), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44) }, scroll)
	if icon then
		Kit.new("ImageLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(44, 44),
			Image = icon, ScaleType = Enum.ScaleType.Fit,
		}, f)
	end
	Kit.text(f, {
		Text = text, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, icon and 52 or 0, 0.5, 0), Size = UDim2.new(0.6, 0, 0.8, 0),
		TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3.5,
	})
	local line = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 2), Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, BorderSizePixel = 0,
	}, f)
	Kit.gradient(line, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 0).Transparency = NumberSequence.new(0, 1)
	return f
end

local function grid(cellHeight, columns)
	local f = Kit.new("Frame", {
		LayoutOrder = nextOrder(), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	}, scroll)
	local gap = 0.018
	Kit.new("UIGridLayout", {
		CellSize = UDim2.new((1 - gap * (columns - 1)) / columns, 0, 0, cellHeight), CellPadding = UDim2.new(gap, 0, 0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, f)
	return f
end

-- a card: coloured gradient, gloss, checker, dark outline
local function card(parent, color, props)
	local f = Kit.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1) }, parent)
	for k, v in pairs(props or {}) do f[k] = v end
	Kit.corner(f, 0.09)
	Kit.stroke(f, 3.5, INK, true)
	Kit.gradient(f, lighten(color, 0.35), darken(color, 0.25))
	local gloss = Kit.new("Frame", {
		Name = "Gloss", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.86, BorderSizePixel = 0,
		Position = UDim2.new(0, 6, 0, 5), Size = UDim2.new(1, -12, 0.42, 0),
	}, f)
	Kit.corner(gloss, 0.2)
	Kit.new("ImageLabel", {
		Name = "Checker", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = "rbxassetid://6372755229",
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(40, 40), ImageTransparency = 0.88,
	}, f)
	-- grows a little under the mouse
	local s = Kit.new("UIScale", { Name = "Hover" }, f)
	f.MouseEnter:Connect(function() tween(s, 0.14, { Scale = 1.025 }) end)
	f.MouseLeave:Connect(function() tween(s, 0.14, { Scale = 1 }) end)
	return f
end

local function shine(f)
	f.ClipsDescendants = true
	local bar = Kit.new("Frame", {
		Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.3, 0.5), Size = UDim2.new(0, 36, 2.4, 0), Rotation = 22, ZIndex = 8,
	}, f)
	task.spawn(function()
		task.wait(math.random() * 2)
		while bar.Parent do
			if gui.Enabled then
				bar.Position = UDim2.fromScale(-0.3, 0.5)
				tween(bar, 0.9, { Position = UDim2.fromScale(1.3, 0.5) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			end
			task.wait(3.2)
		end
	end)
end

local function icon(parent, image, props)
	local img = Kit.new("ImageLabel", { BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Fit, ZIndex = 3 }, parent)
	for k, v in pairs(props) do img[k] = v end
	return img
end

------------------------------------------------------------------------------------------
-- price buttons: every one shows Robux or Tickets depending on the switch
------------------------------------------------------------------------------------------
local toast
local priceButtons = {}

local function say(text, color) toast(text, color) end

local function owned(entry)
	return entry.kind == "pass" and ShopConfig.hasPass(player, entry.def.key)
end

local function paintPrice(pb, animate)
	local def = pb.def
	local function apply()
		if owned(pb) then
			pb.paint("grey")
			pb.ticketIcon.Visible = false
			pb.label.Text = "Owned \u{2713}"
			pb.label.Position = UDim2.fromScale(0.5, 0.5)
		elseif pb.confirm then
			pb.paint("red")
			pb.ticketIcon.Visible = false
			pb.label.Text = "Sure?"
			pb.label.Position = UDim2.fromScale(0.5, 0.5)
		elseif mode == "robux" then
			pb.paint("green")
			pb.ticketIcon.Visible = false
			pb.label.Text = ROBUX .. commas(pb.robux or def.price)
			pb.label.Position = UDim2.fromScale(0.5, 0.5)
		else
			local can = (player:GetAttribute("Tickets") or 0) >= def.tickets
			pb.paint(can and "gold" or "grey")
			pb.ticketIcon.Visible = true
			pb.label.Text = abbreviate(def.tickets)
			pb.label.Position = UDim2.fromScale(0.6, 0.5)
		end
	end
	if animate then
		-- flip: squash shut, swap, pop open
		tween(pb.flip, 0.1, { Scale = 0.2 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
			apply()
			tween(pb.flip, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	else
		apply()
	end
end

local function prompt(pb)
	local def = pb.def
	if owned(pb) then
		say("You already own this!", Color3.fromRGB(150, 255, 150))
		return
	end
	if mode == "robux" then
		if not def.id or def.id == 0 then
			say("Coming soon! (try Tickets)", Color3.fromRGB(255, 220, 120))
			return
		end
		if pb.kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, def.id)
		else
			MarketplaceService:PromptProductPurchase(player, def.id)
		end
		return
	end

	-- Tickets: tap once to arm, again to buy
	if (player:GetAttribute("Tickets") or 0) < def.tickets then
		say("Not enough Tickets! You get 1 every " .. fmtTime(ShopConfig.Tickets.GrantInterval), Color3.fromRGB(255, 130, 130))
		Kit.pop(pb.button, 0.85)
		return
	end
	if not pb.confirm then
		pb.confirm = true
		paintPrice(pb, true)
		task.delay(2.5, function()
			if pb.confirm then
				pb.confirm = false
				paintPrice(pb, true)
			end
		end)
		return
	end
	pb.confirm = false
	local ok, result = pcall(function() return buyTicketsRemote:InvokeServer(def.key) end)
	if ok and type(result) == "table" and result.ok then
		say("Bought with Tickets!", Color3.fromRGB(150, 255, 150))
		Kit.pop(pb.card or pb.button, 1.12)
	else
		local reason = ok and type(result) == "table" and result.reason
		say(reason == "tickets" and "Not enough Tickets!" or reason == "owned" and "You already own this!" or "Couldn't buy that", Color3.fromRGB(255, 130, 130))
	end
	paintPrice(pb, true)
end

-- kind: "pass" / "gems" / "global"
local function priceButton(parent, props, kind, def, cardFrame)
	local b, paint, label = Kit.button(parent, props, "")
	label.Size = UDim2.fromScale(0.72, 0.72)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	local ticketIcon = Kit.new("ImageLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.06, 0.5), Size = UDim2.fromScale(0.3, 1.1),
		Image = TICKET_ICON, ScaleType = Enum.ScaleType.Fit, Rotation = -10, Visible = false,
	}, b)
	local flip = Kit.new("UIScale", { Name = "Flip" }, label)
	local pb = { button = b, paint = paint, label = label, ticketIcon = ticketIcon, flip = flip, kind = kind, def = def, card = cardFrame }
	table.insert(priceButtons, pb)
	b.Activated:Connect(function() prompt(pb) end)
	-- the real Robux price, once Roblox tells us
	if def.id and def.id ~= 0 then
		task.spawn(function()
			local infoType = kind == "pass" and Enum.InfoType.GamePass or Enum.InfoType.Product
			local ok, info = pcall(function() return MarketplaceService:GetProductInfo(def.id, infoType) end)
			if ok and info and info.PriceInRobux then
				pb.robux = info.PriceInRobux
				paintPrice(pb)
			end
		end)
	end
	paintPrice(pb)
	return pb
end

local function repaintAll(animate)
	for i, pb in ipairs(priceButtons) do
		if animate then
			task.delay((i % 12) * 0.02, function() paintPrice(pb, true) end)
		else
			paintPrice(pb)
		end
	end
end

------------------------------------------------------------------------------------------
-- FEATURED
------------------------------------------------------------------------------------------
section("Featured", "rbxassetid://99928751746150")

do -- Gamepass Bundle
	local b = ShopConfig.Bundle
	local f = card(scroll, Color3.fromRGB(255, 185, 40), { Name = "Bundle", LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 170) })
	shine(f)
	Kit.text(f, {
		Text = b.name, Position = UDim2.fromScale(0.03, 0.08), Size = UDim2.fromScale(0.5, 0.26), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3.5, ZIndex = 3,
	})
	Kit.text(f, {
		Text = b.description, Position = UDim2.fromScale(0.03, 0.35), Size = UDim2.fromScale(0.5, 0.14), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 250, 225), Stroke = 2.5, ZIndex = 3,
	})
	local row = Kit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.03, 0.52), Size = UDim2.fromScale(0.5, 0.42), ZIndex = 3 }, f)
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.03, 0), VerticalAlignment = Enum.VerticalAlignment.Center }, row)
	for i, img in ipairs(b.icons) do
		local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.2, 1) }, row)
		Kit.new("UIAspectRatioConstraint", { AspectRatio = 1 }, holder)
		wobble(icon(holder, img, { Size = UDim2.fromScale(1, 1) }), "tilt", i)
	end
	local ribbon = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.8, 0.22), Size = UDim2.fromScale(0.2, 0.24),
		BackgroundColor3 = Color3.fromRGB(235, 50, 60), Rotation = 6, ZIndex = 4,
	}, f)
	Kit.corner(ribbon, 0.35)
	Kit.stroke(ribbon, 3, INK, true)
	Kit.text(ribbon, { Text = b.discount, Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), Stroke = 2.5, ZIndex = 5 })
	wobble(ribbon, "tilt", 0)
	priceButton(f, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.8, 0.66), Size = UDim2.fromScale(0.28, 0.34), ZIndex = 5,
	}, "pass", b, f)
end

do -- Global Runes
	local g = ShopConfig.GlobalRunes
	local f = card(scroll, Color3.fromRGB(150, 90, 255), { Name = "GlobalRunes", LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 185) })
	shine(f)
	wobble(icon(f, g.icon, { Position = UDim2.fromScale(0.015, 0.05), Size = UDim2.fromScale(0.13, 0.5) }), "tilt", 2)
	Kit.text(f, {
		Text = "Global Runes", Position = UDim2.fromScale(0.15, 0.07), Size = UDim2.fromScale(0.45, 0.22), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3.5, ZIndex = 3,
	})
	Kit.text(f, {
		Text = "Opens runes for EVERYONE in the server (you too!)", Position = UDim2.fromScale(0.15, 0.31), Size = UDim2.fromScale(0.8, 0.13),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(235, 225, 255), Stroke = 2.5, ZIndex = 3,
	})
	Kit.text(f, {
		Text = "Rune Bulk doesn't apply", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.98, 0.08), Size = UDim2.fromScale(0.3, 0.1),
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(215, 200, 255), Stroke = 2, ZIndex = 3,
	})
	local row = Kit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.02, 0.58), Size = UDim2.fromScale(0.96, 0.34), ZIndex = 3 }, f)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.015, 0), HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, row)
	for _, option in ipairs(g.options) do
		local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.185, 1) }, row)
		Kit.text(holder, {
			Text = "x" .. abbreviate(option.amount), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.02),
			Size = UDim2.fromScale(0.8, 0.5), Stroke = 2.5, ZIndex = 4,
		})
		priceButton(holder, { Size = UDim2.fromScale(1, 0.95), ZIndex = 4 }, "global", option, f)
	end
end

------------------------------------------------------------------------------------------
-- GAMEPASSES
------------------------------------------------------------------------------------------
section("Gamepasses", "rbxassetid://74619804770161")
local passGrid = grid(220, 4)
for i, pass in ipairs(ShopConfig.Passes) do
	local f = card(passGrid, pass.color, { Name = pass.key, LayoutOrder = i })
	local img = icon(f, pass.icon, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.05), Size = UDim2.fromScale(0.52, 0.38) })
	wobble(img, "bob", i)
	Kit.text(f, { Text = pass.name, Position = UDim2.fromScale(0.05, 0.44), Size = UDim2.fromScale(0.9, 0.15), Stroke = 3, ZIndex = 3 })
	Kit.text(f, {
		Text = pass.description, Position = UDim2.fromScale(0.06, 0.6), Size = UDim2.fromScale(0.88, 0.1),
		TextColor3 = Color3.fromRGB(240, 245, 255), Stroke = 2, ZIndex = 3,
	})
	priceButton(f, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.95), Size = UDim2.fromScale(0.82, 0.19), ZIndex = 4,
	}, "pass", pass, f)
end

------------------------------------------------------------------------------------------
-- GEMS
------------------------------------------------------------------------------------------
section("Gems", GEM_ICON)
local gemGrid = grid(200, 5)
for i, g in ipairs(ShopConfig.Gems) do
	local f = card(gemGrid, Color3.fromRGB(70, 175, 255), { Name = g.key, LayoutOrder = i })
	if g.tag then shine(f) end
	local img = icon(f, g.icon or GEM_ICON, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromScale(0.7, 0.48),
	})
	wobble(img, "tilt", i)
	Kit.text(f, { Text = abbreviate(g.amount) .. " Gems", Position = UDim2.fromScale(0.05, 0.56), Size = UDim2.fromScale(0.9, 0.16), Stroke = 3, ZIndex = 3 })
	priceButton(f, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.95), Size = UDim2.fromScale(0.86, 0.2), ZIndex = 4,
	}, "gems", g, f)
	if g.tag then
		local tag = Kit.new("Frame", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromScale(0.7, 0.13),
			BackgroundColor3 = Color3.fromRGB(255, 70, 90), Rotation = 4, ZIndex = 6,
		}, f)
		Kit.corner(tag, 0.4)
		Kit.stroke(tag, 2.5, INK, true)
		Kit.text(tag, { Text = g.tag, Size = UDim2.fromScale(0.92, 0.78), Position = UDim2.fromScale(0.04, 0.11), Stroke = 2, ZIndex = 7 })
	end
end

------------------------------------------------------------------------------------------
-- toast (bottom of the window)
------------------------------------------------------------------------------------------
local toastLabel = Kit.text(panel, {
	Name = "Toast", Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 8), Size = UDim2.fromScale(0.8, 0.06),
	Stroke = 3, TextTransparency = 1, ZIndex = 20,
})
local toastStroke = toastLabel:FindFirstChildOfClass("UIStroke")
toastStroke.Transparency = 1
local toastToken = 0
toast = function(text, color)
	toastToken += 1
	local my = toastToken
	toastLabel.Text = text
	toastLabel.TextColor3 = color or Color3.new(1, 1, 1)
	toastLabel.TextTransparency = 0
	toastStroke.Transparency = 0
	Kit.pop(toastLabel, 1.25)
	task.delay(2.2, function()
		if my ~= toastToken then return end
		tween(toastLabel, 0.35, { TextTransparency = 1 })
		tween(toastStroke, 0.35, { Transparency = 1 })
	end)
end

------------------------------------------------------------------------------------------
-- switching Robux <-> Tickets
------------------------------------------------------------------------------------------
local function setMode(newMode, instant)
	mode = newMode
	local tickets = mode == "tickets"
	local t = instant and 0 or 0.28
	tween(knob, t, { Position = tickets and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(0, 4, 0.5, 0) }, Enum.EasingStyle.Back)
	knobGrad.Color = tickets and ColorSequence.new(Color3.fromRGB(255, 236, 120), Color3.fromRGB(245, 165, 30))
		or ColorSequence.new(Color3.fromRGB(150, 255, 110), Color3.fromRGB(40, 185, 60))
	knobText.Text = tickets and "Tickets" or (ROBUX .. " Robux")
	-- the header tints to match
	headerGrad.Color = tickets and ColorSequence.new(Color3.fromRGB(255, 215, 110), Color3.fromRGB(235, 140, 30))
		or ColorSequence.new(Color3.fromRGB(110, 205, 255), Color3.fromRGB(35, 105, 235))
	for _, pb in ipairs(priceButtons) do pb.confirm = false end
	repaintAll(not instant)
	if not instant then
		Kit.pop(knob, 0.8)
		if tickets then Kit.pop(pill, 1.1) end
	end
end

switch.Activated:Connect(function()
	setMode(mode == "robux" and "tickets" or "robux")
end)

------------------------------------------------------------------------------------------
-- open / close
------------------------------------------------------------------------------------------
local isOpen = false

local function paintTickets()
	pillCount.Text = abbreviate(player:GetAttribute("Tickets") or 0)
end

local function open(tickets)
	if tickets ~= nil then setMode(tickets and "tickets" or "robux", true) end
	if isOpen then return end
	isOpen = true
	paintTickets()
	repaintAll(false)
	scroll.CanvasPosition = Vector2.zero
	gui.Enabled = true
	openScale.Scale = 0.6
	tween(openScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(dim, 0.25, { BackgroundTransparency = 0.45 })
	Kit.pop(headerIcon, 1.4)
end

local function hide()
	if not isOpen then return end
	isOpen = false
	tween(dim, 0.15, { BackgroundTransparency = 1 })
	tween(openScale, 0.16, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
		if not isOpen then gui.Enabled = false end
	end)
end

local function scrollTo(frameName)
	local target = scroll:FindFirstChild(frameName)
	if not target then return end
	task.defer(function()
		local y = target.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y - 12
		tween(scroll, 0.45, { CanvasPosition = Vector2.new(0, math.max(0, y)) }, Enum.EasingStyle.Quart)
	end)
end

setMode("robux", true)
close.Activated:Connect(hide)
dim.Activated:Connect(hide)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and isOpen and input.KeyCode == Enum.KeyCode.Escape then hide() end
end)

-- the old Shop gui is replaced by this one
task.spawn(function()
	local old = playerGui:WaitForChild("Shop", 10)
	if old then old.Enabled = false end
end)

-- the Shop button (left side) and the + next to your Gems
task.spawn(function()
	local buttons = playerGui:WaitForChild("Buttons")
	local side = buttons:WaitForChild("SideContainer")
	local function hook(b)
		if b and b:IsA("GuiButton") and not b:GetAttribute("ShopHooked") then
			b:SetAttribute("ShopHooked", true)
			b.Activated:Connect(function()
				if isOpen then hide() else open() end
			end)
		end
	end
	hook(side:FindFirstChild("Shop", true))
	side.DescendantAdded:Connect(function(d) if d.Name == "Shop" then hook(d) end end)

	-- the currency counter at the top left (named Gems, or Bubbles in older versions of the HUD)
	local bubbles = buttons:FindFirstChild("Gems") or buttons:FindFirstChild("Bubbles")
	local plus = bubbles and bubbles:FindFirstChildWhichIsA("TextButton", true)
	if plus then
		plus.Activated:Connect(function()
			open()
			scrollTo("Gems")
		end)
	end
	local amount = bubbles and bubbles:FindFirstChild("Amount", true)
	if amount and amount:IsA("TextLabel") then
		local function paintGems() amount.Text = abbreviate(player:GetAttribute("Gems") or 0) end
		player:GetAttributeChangedSignal("Gems"):Connect(paintGems)
		paintGems()
	end
end)

-- anything else can open it: ReplicatedStorage.HudActions:Fire("Shop", useTickets?)
local hudActions = ReplicatedStorage:FindFirstChild("HudActions")
if hudActions then
	hudActions.Event:Connect(function(action, useTickets)
		if action == "Shop" then open(useTickets) end
	end)
end

------------------------------------------------------------------------------------------
-- live bits
------------------------------------------------------------------------------------------
local lastTickets = player:GetAttribute("Tickets") or 0
player.AttributeChanged:Connect(function(attr)
	if attr == "Tickets" then
		local now = player:GetAttribute("Tickets") or 0
		if now > lastTickets then
			pillCountScale.Scale = 1.5
			tween(pillCountScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		lastTickets = now
		paintTickets()
		if mode == "tickets" then repaintAll(false) end
	elseif attr:sub(1, 5) == "Pass_" then
		repaintAll(false)
	end
end)

local accum = 0
RunService.RenderStepped:Connect(function(dt)
	if not isOpen then return end
	local t = os.clock()
	for _, w in ipairs(wobblers) do
		if w.kind == "tilt" then
			w.obj.Rotation = math.sin(t * 2 + w.seed) * 7
		else
			w.obj.Position = w.base + UDim2.fromOffset(0, math.sin(t * 2.2 + w.seed) * 3)
		end
	end
	pillIcon.Rotation = -12 + math.sin(t * 2.5) * 6
	accum += dt
	if accum < 0.2 then return end
	accum = 0
	local interval = ShopConfig.Tickets.GrantInterval
	local s = player:GetAttribute("TicketSeconds") or 0
	pillTimer.Text = "+" .. ShopConfig.Tickets.GrantAmount .. " in " .. fmtTime(interval - s)
	tween(pillBar, 0.2, { Size = UDim2.fromScale(math.clamp(s / interval, 0, 1), 1) }, Enum.EasingStyle.Linear)
end)

-- server news: tickets earned, passes bought, Global Runes from someone
local notice = Kit.new("ScreenGui", { Name = "ShopNotices", ResetOnSpawn = false, DisplayOrder = 30, IgnoreGuiInset = true }, playerGui)
local function notify(text, color, img)
	local f = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -80), Size = UDim2.fromOffset(440, 58),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, notice)
	Kit.corner(f, 0.4)
	Kit.stroke(f, 3.5, INK, true)
	Kit.gradient(f, lighten(color, 0.3), darken(color, 0.2))
	if img then
		Kit.new("ImageLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(64, 64),
			Image = img, ScaleType = Enum.ScaleType.Fit, Rotation = -10,
		}, f)
	end
	Kit.text(f, { Text = text, Position = UDim2.new(0, img and 72 or 14, 0.12, 0), Size = UDim2.new(1, img and -86 or -28, 0.76, 0), Stroke = 3 })
	tween(f, 0.45, { Position = UDim2.new(0.5, 0, 0, 72) }, Enum.EasingStyle.Back)
	task.delay(3, function()
		tween(f, 0.3, { Position = UDim2.new(0.5, 0, 0, -80) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
			f:Destroy()
		end)
	end)
end

shopEvent.OnClientEvent:Connect(function(kind, a, b)
	if kind == "tickets" then
		notify("+" .. a .. " Ticket" .. (a == 1 and "" or "s") .. "! Spend them in the Shop", Color3.fromRGB(255, 190, 50), TICKET_ICON)
	elseif kind == "pass" then
		local pass = ShopConfig.PassByKey[a] or (a == "Bundle" and ShopConfig.Bundle)
		notify("You got " .. (pass and pass.name or a) .. "!", Color3.fromRGB(90, 220, 110), pass and (pass.icon or (pass.icons and pass.icons[1])))
		repaintAll(false)
	elseif kind == "gems" then
		notify("+" .. abbreviate(a) .. " Gems!", Color3.fromRGB(70, 170, 255), GEM_ICON)
	elseif kind == "global" then
		notify(a .. " opened " .. abbreviate(b) .. " Global Runes for everyone!", Color3.fromRGB(150, 90, 255), ShopConfig.GlobalRunes.icon)
	end
end)

paintTickets()
