-- DRILLING MANIA: the Enhancer board (Workspace["Enhancer-tiererset"]). Three tiers: each one
-- resets your Drilling Mania progress (Scrap, Iron, Oil, drills, plots, drill upgrades)
-- for boosts that stay forever. Tiers + boosts live in DrillConfig.Enhancer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local DrillConfig = require(ReplicatedStorage:WaitForChild("DrillConfig"))
local Kit = require(ReplicatedStorage:WaitForChild("FishingUIKit"))
local abbreviate = require(ReplicatedStorage:WaitForChild("NumberFormat")).abbreviate
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local actionRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DrillAction")
local eventRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DrillEvent")

local INK = Color3.fromRGB(10, 10, 16)
local BOOST_NAMES = { scrap = "Scrap", iron = "Iron", oil = "Oil", coins = "Craft Coins" }
local BOOST_ORDER = { "scrap", "iron", "oil", "coins" }
local NUMERALS = { "I", "II", "III", "IV", "V" }

local part = workspace:WaitForChild("DrillingMania"):WaitForChild("Enhancer-tiererset")

local gui = Kit.new("SurfaceGui", {
	Name = "EnhancerBoard", Face = Enum.NormalId.Front, Adornee = part, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
	PixelsPerStud = 45, LightInfluence = 0, ResetOnSpawn = false, MaxDistance = 150,
}, player:WaitForChild("PlayerGui"))

local bg = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, gui)
Kit.gradient(bg, Color3.fromRGB(55, 45, 80), Color3.fromRGB(18, 16, 30))
Kit.stroke(bg, 10, INK, true)
Kit.new("ImageLabel", {
	BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = "rbxassetid://6372755229", ScaleType = Enum.ScaleType.Tile,
	TileSize = UDim2.fromOffset(80, 80), ImageTransparency = 0.9,
}, bg)

local title = Kit.text(bg, {
	Text = "ENHANCER", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.025), Size = UDim2.fromScale(0.6, 0.14), Stroke = 6,
})
Kit.gradient(title, Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 150, 40))
Kit.text(bg, {
	Text = "Reset Drilling Mania for boosts that last forever!", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.165),
	Size = UDim2.fromScale(0.8, 0.06), Stroke = 3, TextColor3 = Color3.fromRGB(220, 215, 240),
})

local row = Kit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromScale(0.94, 0.58), BackgroundTransparency = 1 }, bg)
Kit.new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0.025, 0), SortOrder = Enum.SortOrder.LayoutOrder,
}, row)

local cards = {}
for i, tier in ipairs(DrillConfig.Enhancer) do
	local card = Kit.new("Frame", { LayoutOrder = i, Size = UDim2.fromScale(0.31, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, row)
	Kit.corner(card, 0.08)
	local stroke = Kit.stroke(card, 7, INK, true)
	local grad = Kit.gradient(card, tier.color:Lerp(Color3.new(1, 1, 1), 0.25), tier.color:Lerp(INK, 0.55))

	local numeral = Kit.text(card, {
		Text = NUMERALS[i], AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.02), Size = UDim2.fromScale(0.5, 0.25), Stroke = 5,
	})
	Kit.text(card, {
		Text = tier.name, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.26), Size = UDim2.fromScale(0.9, 0.1), Stroke = 3.5,
	})
	-- boosts
	local lines = {}
	for _, k in ipairs(BOOST_ORDER) do
		local v = tier.boosts[k]
		if v then table.insert(lines, "x" .. v .. " " .. BOOST_NAMES[k]) end
	end
	Kit.text(card, {
		Text = table.concat(lines, "\n"), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromScale(0.86, 0.26),
		Stroke = 3, TextColor3 = Color3.fromRGB(170, 255, 150),
	})
	-- requirement
	local need = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromScale(0.86, 0.11), BackgroundTransparency = 1,
	}, card)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
	}, need)
	local needText = Kit.text(need, { Text = abbreviate(tier.oil), Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Stroke = 3 })
	Kit.image(need, { Image = DrillConfig.Icons.Oil, Size = UDim2.fromScale(1.1, 1.1), SizeConstraint = Enum.SizeConstraint.RelativeYY, LayoutOrder = 2 })

	local button, paint, label = Kit.button(card, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.96), Size = UDim2.fromScale(0.84, 0.16),
	}, "ENHANCE")
	label.Size = UDim2.fromScale(0.9, 0.75)
	local bar = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.79), Size = UDim2.fromScale(0.84, 0.035), BackgroundColor3 = Color3.fromRGB(20, 18, 30),
		ClipsDescendants = true,
	}, card)
	Kit.corner(bar, 0.5)
	local barFill = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(180, 150, 255), BorderSizePixel = 0 }, bar)
	Kit.corner(barFill, 0.5)
	local scale = Kit.new("UIScale", {}, card)

	cards[i] = { card = card, stroke = stroke, grad = grad, button = button, paint = paint, label = label, needText = needText, barFill = barFill, scale = scale, tier = tier, numeral = numeral }
end

local footer = Kit.text(bg, {
	Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.975), Size = UDim2.fromScale(0.9, 0.055), Stroke = 3,
	TextColor3 = Color3.fromRGB(255, 175, 160),
})
local current = Kit.text(bg, {
	Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.915), Size = UDim2.fromScale(0.9, 0.06), Stroke = 3,
	TextColor3 = Color3.fromRGB(170, 255, 150),
})

local confirmUntil = 0
local function refresh()
	local tier = player:GetAttribute("DrillEnhance") or 0
	local oil = player:GetAttribute("Oil") or 0
	for i, c in ipairs(cards) do
		if i <= tier then
			c.paint("green")
			c.label.Text = "✔ DONE"
			c.barFill.Size = UDim2.fromScale(1, 1)
			c.stroke.Color = Color3.fromRGB(40, 150, 50)
			c.card.BackgroundTransparency = 0
			c.needText.TextColor3 = Color3.new(1, 1, 1)
		elseif i == tier + 1 then
			local ready = oil >= c.tier.oil
			c.paint(ready and "gold" or "grey")
			c.label.Text = ready and (os.clock() < confirmUntil and "SURE? TAP!" or "ENHANCE") or (math.floor(oil / c.tier.oil * 100) .. "%")
			c.barFill.Size = UDim2.fromScale(math.clamp(oil / c.tier.oil, 0, 1), 1)
			c.stroke.Color = ready and Color3.fromRGB(255, 220, 80) or INK
			c.card.BackgroundTransparency = 0
			c.needText.TextColor3 = ready and Color3.fromRGB(170, 255, 150) or Color3.fromRGB(255, 140, 140)
		else
			c.paint("grey")
			c.label.Text = "🔒 LOCKED"
			c.barFill.Size = UDim2.fromScale(0, 1)
			c.stroke.Color = INK
			c.card.BackgroundTransparency = 0.45
			c.needText.TextColor3 = Color3.fromRGB(200, 200, 210)
		end
	end
	local parts = {}
	for _, k in ipairs(BOOST_ORDER) do
		local m = DrillConfig.enhanceBoost(player, k)
		if m > 1 then table.insert(parts, "x" .. (math.floor(m * 100 + 0.5) / 100) .. " " .. BOOST_NAMES[k]) end
	end
	current.Text = #parts > 0 and ("Your boosts: " .. table.concat(parts, "   ")) or "No Enhancer boosts yet"
	footer.Text = "Enhancing resets: Scrap, Iron, Oil, drills, plots and drill upgrades"
end

for i, c in ipairs(cards) do
	local busy = false
	c.button.Activated:Connect(function()
		if busy then return end
		local tier = player:GetAttribute("DrillEnhance") or 0
		if i ~= tier + 1 or (player:GetAttribute("Oil") or 0) < c.tier.oil then
			Kit.pop(c.button, 0.85)
			if i == tier + 1 then MessageToPlayer.show("PurchaseUnavailable") end
			return
		end
		if os.clock() > confirmUntil then
			confirmUntil = os.clock() + 3
			Kit.pop(c.button, 1.15)
			refresh()
			task.delay(3.05, refresh)
			return
		end
		confirmUntil = 0
		busy = true
		local ok, r = pcall(function() return actionRemote:InvokeServer("enhance") end)
		if not (ok and type(r) == "table" and r.ok) then
			MessageToPlayer.show("PurchaseUnavailable")
		end
		busy = false
		refresh()
	end)
end

-- big celebration when you enhance
local flash = Kit.new("ScreenGui", { Name = "EnhanceFlash", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30, Enabled = false }, player.PlayerGui)
local flashBg = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 230, 150), BackgroundTransparency = 1 }, flash)
local flashText = Kit.text(flash, {
	Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.7, 0.14), Stroke = 5,
})
Kit.gradient(flashText, Color3.fromRGB(255, 245, 170), Color3.fromRGB(255, 150, 40))
local flashScale = Kit.new("UIScale", {}, flashText)

eventRemote.OnClientEvent:Connect(function(kind, tier)
	if kind ~= "enhanced" then return end
	local def = DrillConfig.Enhancer[tier]
	flash.Enabled = true
	flashText.Text = (def and def.name or "ENHANCED") .. "!"
	flashText.TextTransparency = 0
	flashBg.BackgroundTransparency = 0.2
	flashScale.Scale = 0.4
	TweenService:Create(flashBg, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(flashScale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if cards[tier] then
		cards[tier].scale.Scale = 1.15
		TweenService:Create(cards[tier].scale, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { Scale = 1 }):Play()
	end
	task.delay(1.8, function()
		TweenService:Create(flashText, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.45)
		flash.Enabled = false
	end)
end)

player:GetAttributeChangedSignal("DrillEnhance"):Connect(refresh)
player:GetAttributeChangedSignal("Oil"):Connect(refresh)
refresh()
