-- Shell Upgrades stall (prompt Opens = "ShellUpgrades"): frosted glass window with big
-- spaced-out cards side by side (like the Equipment Trader). 3 show at once, scroll for more.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local FishingConfig = require(ReplicatedStorage:WaitForChild("FishingConfig"))
local FishingVisuals = require(ReplicatedStorage:WaitForChild("FishingVisuals"))
local Kit = require(ReplicatedStorage:WaitForChild("FishingUIKit"))
local abbreviate = require(ReplicatedStorage:WaitForChild("NumberFormat")).abbreviate
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local buyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuyShellUpgrade")

local SHELL_ICON = FishingVisuals.Icons.Shells
local LOOK = {
	FishValue = { emoji = "💰", top = Color3.fromRGB(255, 235, 120), bottom = Color3.fromRGB(240, 160, 30) },
	Luck = { emoji = "🍀", top = Color3.fromRGB(170, 255, 140), bottom = Color3.fromRGB(50, 185, 70) },
	BiteSpeed = { emoji = "⚡", top = Color3.fromRGB(150, 225, 255), bottom = Color3.fromRGB(35, 130, 235) },
	Backpack = { emoji = "🪣", top = Color3.fromRGB(215, 190, 255), bottom = Color3.fromRGB(125, 70, 220) },
	ShellMagnet = { emoji = "🧲", top = Color3.fromRGB(255, 160, 160), bottom = Color3.fromRGB(215, 50, 60) },
	ShellValue = { emoji = "🐚", top = Color3.fromRGB(255, 200, 225), bottom = Color3.fromRGB(230, 95, 155) },
}

local w = Kit.glass("ShellUpgradesMenu", "Shell Upgrades", { aspect = 1.6, tint = Color3.fromRGB(245, 225, 235) })

-- shell balance chip (top-left of the panel)
local balance = Kit.new("Frame", {
	Position = UDim2.fromScale(0.03, 0.035), Size = UDim2.fromScale(0.2, 0.085),
	BackgroundColor3 = Color3.fromRGB(15, 20, 30), BackgroundTransparency = 0.35,
}, w.panel)
Kit.corner(balance, 0.45)
Kit.new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
}, balance)
Kit.image(balance, { Image = SHELL_ICON, Size = UDim2.fromScale(0.85, 0.85), SizeConstraint = Enum.SizeConstraint.RelativeYY, LayoutOrder = 1 })
local balanceText = Kit.text(balance, { Text = "0", Size = UDim2.fromScale(0, 0.7), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Max = 30 })

local strip = Kit.new("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 7, ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255), ScrollBarImageTransparency = 0.3,
	ScrollingDirection = Enum.ScrollingDirection.X, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X,
	VerticalScrollBarInset = Enum.ScrollBarInset.None, HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
}, w.body)
Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 14) }, strip)
local layout = Kit.new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center,
}, strip)

local function effectText(u, level)
	local v = u.per * level
	if u.id == "Backpack" then return "+" .. v .. " fish" end
	if u.id == "ShellMagnet" then return "+" .. v .. " studs" end
	return "+" .. math.floor(v * 100 + 0.5) .. "%"
end

local iconFolder = ReplicatedStorage:WaitForChild("FishingAssets"):WaitForChild("Icons")
local spinners = {}
game:GetService("RunService").RenderStepped:Connect(function()
	if not w.isOpen() then return end
	local t = os.clock()
	for _, sp in ipairs(spinners) do
		local base = sp.base
		sp.model:PivotTo(base * CFrame.Angles(0, math.sin(t * 1.2 + sp.phase) * 0.35, 0) + Vector3.new(0, math.sin(t * 2 + sp.phase) * 0.06, 0))
	end
end)

local cards = {}
for i, u in ipairs(FishingConfig.ShellUpgrades) do
	local look = LOOK[u.id] or LOOK.ShellValue
	local card = Kit.new("Frame", { Name = u.id, LayoutOrder = i, Size = UDim2.new(0, 220, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1) }, strip)
	Kit.corner(card, 0.08)
	Kit.stroke(card, 4, Color3.fromRGB(8, 10, 14), true)
	Kit.gradient(card, look.top, look.bottom)
	card.BackgroundTransparency = 0.12

	Kit.text(card, {
		Text = u.name, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.04), Size = UDim2.fromScale(0.9, 0.11), Stroke = 3.5, Max = 36,
	})

	-- big icon
	local iconBox = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.17), Size = UDim2.fromScale(0.52, 0.3),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35,
	}, card)
	Kit.new("UIAspectRatioConstraint", { AspectRatio = 1 }, iconBox)
	Kit.corner(iconBox, 0.25)
	Kit.stroke(iconBox, 3, Color3.fromRGB(8, 10, 14), true)
	Kit.sunburst(iconBox, Color3.new(1, 1, 1))
	-- the 3D icon (ReplicatedStorage.FishingAssets.Icons.<id>), gently swaying
	local iconModel = iconFolder:FindFirstChild(u.id)
	if iconModel then
		local vpf = Kit.new("ViewportFrame", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.96, 0.96), ZIndex = 3, Ambient = Color3.fromRGB(190, 190, 190),
			LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.4, -1, -0.8),
		}, iconBox)
		local model = iconModel:Clone()
		model.Parent = vpf
		local cf, size = model:GetBoundingBox()
		local cam = Kit.new("Camera", { FieldOfView = 30 }, vpf)
		vpf.CurrentCamera = cam
		local radius = math.max(size.X, size.Y) * 0.5
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, 0, radius / math.tan(math.rad(15)) * 1.12 + size.Z), cf.Position)
		table.insert(spinners, { model = model, base = model:GetPivot(), phase = i })
	else
		Kit.text(iconBox, {
			Text = look.emoji, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.78), Stroke = 0, ZIndex = 3,
		})
	end

	Kit.text(card, {
		Text = u.desc, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.88, 0.08), Max = 20, Stroke = 2,
	})
	local effect = Kit.text(card, {
		Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.59), Size = UDim2.fromScale(0.88, 0.08),
		TextColor3 = Color3.fromRGB(235, 255, 225), Max = 22, Stroke = 2.5,
	})

	-- level bar
	local bar = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.69), Size = UDim2.fromScale(0.84, 0.075),
		BackgroundColor3 = Color3.fromRGB(20, 25, 35),
	}, card)
	Kit.corner(bar, 0.5)
	Kit.stroke(bar, 2.5, Color3.fromRGB(8, 10, 14), true)
	local fill = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, bar)
	Kit.corner(fill, 0.5)
	Kit.gradient(fill, Color3.fromRGB(255, 255, 255), look.top)
	local levelText = Kit.text(bar, { Text = "", Size = UDim2.fromScale(1, 1), Max = 18, Stroke = 2, ZIndex = 3 })

	local buy, paint, buyLabel = Kit.button(card, {
		Name = "Buy", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.955), Size = UDim2.fromScale(0.84, 0.14),
	}, "")
	buyLabel.Visible = false
	local priceRow = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, buy)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
	}, priceRow)
	local price = Kit.text(priceRow, { Text = "", Size = UDim2.fromScale(0, 0.6), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Max = 30, Stroke = 2.5 })
	local priceIcon = Kit.image(priceRow, { Image = SHELL_ICON, Size = UDim2.fromScale(0.68, 0.68), SizeConstraint = Enum.SizeConstraint.RelativeYY, LayoutOrder = 2 })

	cards[u.id] = { u = u, card = card, effect = effect, fill = fill, levelText = levelText, buy = buy, paint = paint, price = price, priceIcon = priceIcon }

	local busy = false
	buy.Activated:Connect(function()
		if busy then return end
		busy = true
		local ok, result = pcall(function() return buyRemote:InvokeServer(u.id) end)
		busy = false
		if ok and result and result.ok then
			Kit.pop(card, 1.05)
		elseif ok and result and result.reason == "money" then
			MessageToPlayer.show("NoShells")
			Kit.pop(buy, 0.85)
		end
	end)
end

-- 3 cards fill the window; the rest scroll sideways
local function resize()
	local width = strip.AbsoluteSize.X - 12
	local cardW = math.floor((width - 18 * 2) / 3)
	for _, c in pairs(cards) do
		c.card.Size = UDim2.new(0, math.max(150, cardW), 1, 0)
	end
end
strip:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)

local function refresh()
	local shells = player:GetAttribute("Shells") or 0
	balanceText.Text = abbreviate(shells)
	for id, c in pairs(cards) do
		local level = FishingConfig.shellUpLevel(player, id)
		local maxed = level >= c.u.max
		c.fill.Size = UDim2.fromScale(math.max(level / c.u.max, 0.001), 1)
		c.levelText.Text = "Lv " .. level .. " / " .. c.u.max
		if maxed then
			c.effect.Text = effectText(c.u, level) .. " (MAX)"
			c.price.Text = "MAXED"
			c.priceIcon.Visible = false
			c.paint("gold")
		else
			c.effect.Text = effectText(c.u, level) .. "  >  " .. effectText(c.u, level + 1)
			local cost = FishingConfig.shellUpCost(id, level)
			c.price.Text = abbreviate(cost)
			c.priceIcon.Visible = true
			c.paint(shells >= cost and "green" or "red")
		end
	end
end

player.AttributeChanged:Connect(function(attr)
	if w.isOpen() and (attr == "Shells" or attr:sub(1, 8) == "ShellUp_") then refresh() end
end)

local standPosition
w.onOpen = function()
	resize()
	refresh()
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt:GetAttribute("Opens") ~= "ShellUpgrades" then return end
	standPosition = prompt.Parent and prompt.Parent:IsA("BasePart") and prompt.Parent.Position or nil
	if w.isOpen() then w.hide() else w.open() end
end)

Kit.closeWhenFar(w, function() return standPosition end, 22)
