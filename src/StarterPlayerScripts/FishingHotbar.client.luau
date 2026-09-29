-- Fishing Frenzy hotbar + backpack (replaces Roblox's default backpack while you're on the island).
--   Hotbar: your rod + your best fish, 9 slots, keys 1-9 or click. Fish names use rarity colours.
--   Backpack: the last slot ("+N") or the ` key opens every fish you're carrying.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local FishingConfig = require(ReplicatedStorage:WaitForChild("FishingConfig"))
local FishingFrenzyConfig = require(ReplicatedStorage:WaitForChild("FishingFrenzyConfig"))
local FishingVisuals = require(ReplicatedStorage:WaitForChild("FishingVisuals"))
local Kit = require(ReplicatedStorage:WaitForChild("FishingUIKit"))
local abbreviate = require(ReplicatedStorage:WaitForChild("NumberFormat")).abbreviate

local SLOTS = 9
local SLOT_SIZE = 74
local GAP = 8
local INK = Color3.fromRGB(10, 10, 14)
local KEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
}

local gui = Kit.new("ScreenGui", { Name = "FishingHotbar", ResetOnSpawn = false, DisplayOrder = 6, Enabled = false }, player:WaitForChild("PlayerGui"))
local bar = Kit.new("Frame", {
	Name = "Bar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.fromOffset((SLOTS + 1) * SLOT_SIZE + SLOTS * GAP + 10, SLOT_SIZE), BackgroundTransparency = 1,
}, gui)
Kit.new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder,
}, bar)
local barScale = Kit.new("UIScale", {}, bar)
-- sit in the space to the right of the menu bar (which slides to the bottom-left on the island)
local menuBar
task.spawn(function()
	local buttons = player.PlayerGui:WaitForChild("Buttons", 30)
	menuBar = buttons and buttons:WaitForChild("Container", 30)
end)
local function fit()
	local cam = workspace.CurrentCamera
	local width = cam and cam.ViewportSize.X or 1200
	local left = 16
	if menuBar and menuBar.Visible then
		left = math.max(left, menuBar.AbsolutePosition.X + menuBar.AbsoluteSize.X + 16)
	end
	if left > width * 0.6 then left = 16 end -- menu isn't in the corner (yet)
	local room = width - left - 16
	local scale = math.clamp(room / bar.Size.X.Offset, 0.5, 1)
	barScale.Scale = scale
	local half = bar.Size.X.Offset * scale / 2
	local center = math.max(width / 2, left + half) -- centred, unless that would cover the menu
	bar.Position = UDim2.new(0, center, 1, -8)
end
fit()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(fit)
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end

------------------------------------------------------------------------------------------
-- slots
------------------------------------------------------------------------------------------
local function makeSlot(parent, i)
	local b = Kit.new("TextButton", {
		Name = "Slot" .. i, LayoutOrder = i, Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE), Text = "", AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(38, 40, 44), BackgroundTransparency = 0.25,
	}, parent)
	Kit.corner(b, 0.16)
	local stroke = Kit.stroke(b, 3, INK, true)
	local number = Kit.new("TextLabel", {
		Name = "Number", BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(18, 18),
		FontFace = Kit.Font, TextScaled = true, Text = i <= SLOTS and tostring(i) or "", TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, b)
	Kit.stroke(number, 2, INK)
	local name = Kit.new("TextLabel", {
		Name = "ItemName", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.88, 0.62), FontFace = Kit.Font, TextScaled = true, TextWrapped = true, Text = "",
		TextColor3 = Color3.new(1, 1, 1),
	}, b)
	Kit.stroke(name, 2.5, INK)
	Kit.new("UITextSizeConstraint", { MaxTextSize = 20 }, name)
	local star = Kit.new("TextLabel", {
		Name = "Star", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 2),
		Size = UDim2.fromOffset(18, 18), FontFace = Kit.Font, TextScaled = true, Text = "☆", TextColor3 = Color3.fromRGB(255, 215, 70),
		Visible = false,
	}, b)
	Kit.stroke(star, 1.5, INK)
	local scale = Kit.new("UIScale", {}, b)
	b.MouseEnter:Connect(function() TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.06 }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play() end)
	return { button = b, stroke = stroke, name = name, star = star, number = number, scale = scale, tool = nil }
end

local slots = {}
for i = 1, SLOTS do
	slots[i] = makeSlot(bar, i)
end

-- the Inventory slot on the far right (E, or tap it)
local invSlot = makeSlot(bar, SLOTS + 2)
invSlot.number.Text = "E"
invSlot.name.Text = "🎒\nInventory"
invSlot.button.BackgroundColor3 = Color3.fromRGB(55, 95, 150)
invSlot.button.BackgroundTransparency = 0.1
Kit.gradient(invSlot.button, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 190, 225))
Kit.new("Frame", { Name = "Spacer", LayoutOrder = SLOTS + 1, Size = UDim2.fromOffset(2, SLOT_SIZE), BackgroundTransparency = 1 }, bar)

------------------------------------------------------------------------------------------
-- backpack window (every fish)
------------------------------------------------------------------------------------------
local bag = Kit.glass("FishingBackpack", "Inventory", { aspect = 1.6, tint = Color3.fromRGB(220, 230, 245) })
local bagInfo = Kit.text(bag.panel, {
	Text = "", Position = UDim2.fromScale(0.03, 0.04), Size = UDim2.fromScale(0.3, 0.07), TextXAlignment = Enum.TextXAlignment.Left, Max = 26,
})
local grid = Kit.new("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 7,
	ScrollBarImageColor3 = Color3.new(1, 1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, bag.body)
Kit.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8) }, grid)
Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(SLOT_SIZE + 10, SLOT_SIZE + 10), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
local bagSlots = {}

------------------------------------------------------------------------------------------
-- Auto Sell (gamepass) button at the top of the Inventory
------------------------------------------------------------------------------------------
local MarketplaceService = game:GetService("MarketplaceService")
local autoSellRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ToggleAutoSell")

local auto = Kit.new("TextButton", {
	Name = "AutoSell", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.97, 0.025),
	Size = UDim2.fromScale(0.36, 0.1), Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1),
	ClipsDescendants = true, ZIndex = 5,
}, bag.panel)
Kit.corner(auto, 0.35)
local autoStroke = Kit.stroke(auto, 3.5, INK, true)
local autoGrad = Kit.gradient(auto, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
-- shine that sweeps across
local shineBar = Kit.new("Frame", {
	Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, BorderSizePixel = 0,
	Size = UDim2.new(0.12, 0, 2, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.2, 0.5), Rotation = 20, ZIndex = 6,
}, auto)
Kit.text(auto, {
	Text = "⚡", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.new(0.16, 0, 0.8, 0), ZIndex = 7,
})
local autoLabel = Kit.text(auto, {
	Text = "AUTO SELL", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.2, 0, 0.36, 0), Size = UDim2.new(0.5, 0, 0.5, 0),
	TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2.5, ZIndex = 7,
})
local autoSub = Kit.text(auto, {
	Text = "", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.2, 0, 0.76, 0), Size = UDim2.new(0.5, 0, 0.32, 0),
	TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2, ZIndex = 7,
})
-- the switch on the right (owners) / price tag (everyone else)
local switch = Kit.new("Frame", {
	Name = "Switch", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.24, 0, 0.56, 0),
	BackgroundColor3 = Color3.fromRGB(30, 34, 44), ZIndex = 7,
}, auto)
Kit.corner(switch, 1)
Kit.stroke(switch, 2.5, INK, true)
local knob = Kit.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.28, 0.5), Size = UDim2.fromScale(0.44, 0.8),
	BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 8,
}, switch)
Kit.corner(knob, 1)
Kit.stroke(knob, 2, INK, true)
local switchText = Kit.text(switch, {
	Text = "OFF", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.72, 0.5), Size = UDim2.fromScale(0.5, 0.7), ZIndex = 8, Stroke = 1.5,
})
local priceTag = Kit.text(auto, {
	Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.26, 0, 0.56, 0),
	TextColor3 = Color3.fromRGB(120, 255, 130), ZIndex = 7, Stroke = 2.5,
})
local autoScale = Kit.new("UIScale", {}, auto)
auto.MouseEnter:Connect(function() TweenService:Create(autoScale, TweenInfo.new(0.12), { Scale = 1.05 }):Play() end)
auto.MouseLeave:Connect(function() TweenService:Create(autoScale, TweenInfo.new(0.12), { Scale = 1 }):Play() end)

local function paintAuto()
	local owns = player:GetAttribute("AutoSellPass") == true
	local on = owns and player:GetAttribute("AutoSell") == true
	switch.Visible = owns
	priceTag.Visible = not owns
	if not owns then
		-- gold "buy me"
		autoGrad.Color = ColorSequence.new(Color3.fromRGB(255, 236, 110), Color3.fromRGB(245, 160, 20))
		autoStroke.Color = Color3.fromRGB(110, 55, 0)
		autoSub.Text = "Sells fish for you!"
		autoSub.TextColor3 = Color3.fromRGB(255, 250, 220)
		priceTag.Text = FishingConfig.AutoSellPassId ~= 0 and ("R$" .. (FishingConfig.AutoSellPrice or "")) or "SOON"
	elseif on then
		autoGrad.Color = ColorSequence.new(Color3.fromRGB(150, 255, 110), Color3.fromRGB(40, 185, 60))
		autoStroke.Color = Color3.fromRGB(10, 70, 15)
		autoSub.Text = "Selling as you catch"
		autoSub.TextColor3 = Color3.fromRGB(230, 255, 230)
		switch.BackgroundColor3 = Color3.fromRGB(40, 150, 55)
		switchText.Text = "ON"
		switchText.Position = UDim2.fromScale(0.3, 0.5)
		TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.72, 0.5) }):Play()
	else
		autoGrad.Color = ColorSequence.new(Color3.fromRGB(215, 218, 228), Color3.fromRGB(125, 130, 148))
		autoStroke.Color = INK
		autoSub.Text = "Tap to turn on"
		autoSub.TextColor3 = Color3.fromRGB(240, 242, 250)
		switch.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
		switchText.Text = "OFF"
		switchText.Position = UDim2.fromScale(0.72, 0.5)
		TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.28, 0.5) }):Play()
	end
end

local autoBusy = false
auto.Activated:Connect(function()
	if autoBusy then return end
	Kit.pop(auto, 0.9)
	if player:GetAttribute("AutoSellPass") ~= true then
		if FishingConfig.AutoSellPassId ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, FishingConfig.AutoSellPassId)
		else
			autoSub.Text = "Coming soon!"
		end
		return
	end
	autoBusy = true
	pcall(function() autoSellRemote:InvokeServer(player:GetAttribute("AutoSell") ~= true) end)
	autoBusy = false
end)
player:GetAttributeChangedSignal("AutoSellPass"):Connect(paintAuto)
player:GetAttributeChangedSignal("AutoSell"):Connect(paintAuto)
paintAuto()

-- a shine sweeps across it every couple of seconds
task.spawn(function()
	while true do
		if bag.isOpen() then
			shineBar.Position = UDim2.fromScale(-0.2, 0.5)
			TweenService:Create(shineBar, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(1.2, 0.5) }):Play()
		end
		task.wait(2.2)
	end
end)

-- "Auto-sold" toast above the hotbar
local toast = Kit.text(gui, {
	Name = "AutoSoldToast", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.fromOffset(420, 30),
	Text = "", TextColor3 = Color3.fromRGB(150, 255, 150), Visible = false, Stroke = 2.5,
})
local toastScale = Kit.new("UIScale", {}, toast)
local toastToken = 0
ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FishingEvent").OnClientEvent:Connect(function(kind, total, count)
	if kind ~= "autosold" then return end
	toastToken += 1
	local my = toastToken
	toast.Text = "⚡ Auto-sold " .. count .. " fish  +" .. abbreviate(total) .. " Fish Meal"
	toast.Position = UDim2.new(0, bar.Position.X.Offset, 1, -(SLOT_SIZE * barScale.Scale) - 20)
	toast.Visible = true
	toast.TextTransparency = 0
	toastScale.Scale = 0.7
	TweenService:Create(toastScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(1.6, function()
		if my ~= toastToken then return end
		TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.4)
		if my == toastToken then toast.Visible = false end
	end)
end)

------------------------------------------------------------------------------------------
-- tools
------------------------------------------------------------------------------------------
local function rarityIndex(tool)
	local fish = FishingConfig.FishById[tool:GetAttribute("Fish") or ""]
	return fish and (FishingConfig.RarityIndex[fish.rarity] or 0) or 0
end

local function fishValue(tool)
	local fish = FishingConfig.FishById[tool:GetAttribute("Fish") or ""]
	return fish and FishingConfig.baseValue(fish, tool:GetAttribute("Kg") or fish.kg[1]) or 0
end

local function allTools()
	local list = {}
	local character = player.Character
	for _, container in ipairs({ player:FindFirstChild("Backpack"), character }) do
		if container then
			for _, t in ipairs(container:GetChildren()) do
				if t:IsA("Tool") then table.insert(list, t) end
			end
		end
	end
	table.sort(list, function(a, b)
		local ra = a:GetAttribute("FishingTool") == "Rod"
		local rb = b:GetAttribute("FishingTool") == "Rod"
		if ra ~= rb then return ra end
		local xa, xb = rarityIndex(a), rarityIndex(b)
		if xa ~= xb then return xa > xb end
		local va, vb = fishValue(a), fishValue(b)
		if va ~= vb then return va > vb end
		return a.Name < b.Name
	end)
	return list
end

local function equipped()
	return player.Character and player.Character:FindFirstChildOfClass("Tool")
end

local function toggle(tool)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not tool or not tool.Parent then return end
	if tool.Parent == player.Character then
		humanoid:UnequipTools()
	else
		humanoid:EquipTool(tool)
	end
end

local function paintSlot(s, tool, index)
	s.tool = tool
	if not tool then
		s.name.Text = ""
		s.star.Visible = false
		s.button.BackgroundTransparency = 0.55
		s.stroke.Color = INK
		s.stroke.Thickness = 3
		return
	end
	local fishId = tool:GetAttribute("Fish")
	local fish = fishId and FishingConfig.FishById[fishId]
	s.name.Text = tool.Name
	s.name.TextColor3 = fish and FishingVisuals.rarityColor(fish.rarity):Lerp(Color3.new(1, 1, 1), 0.15) or Color3.new(1, 1, 1)
	s.star.Visible = fish ~= nil and (FishingConfig.RarityIndex[fish.rarity] or 0) >= 4
	s.star.Text = "★"
	local on = tool.Parent == player.Character
	s.button.BackgroundTransparency = on and 0.05 or 0.25
	s.button.BackgroundColor3 = on and Color3.fromRGB(70, 74, 82) or Color3.fromRGB(38, 40, 44)
	s.stroke.Color = on and Color3.new(1, 1, 1) or INK
	s.stroke.Thickness = on and 3.5 or 3
end

local shown = {}
local function refresh()
	local list = allTools()
	for i = 1, SLOTS do
		paintSlot(slots[i], list[i], i)
	end
	invSlot.stroke.Color = bag.isOpen() and Color3.new(1, 1, 1) or INK
	invSlot.stroke.Thickness = bag.isOpen() and 3.5 or 3
	shown = list

	-- the backpack grid
	if bag.isOpen() then
		local fishCount = 0
		for i, tool in ipairs(list) do
			local s = bagSlots[i]
			if not s then
				s = makeSlot(grid, i)
				s.number.Text = ""
				s.button.Size = UDim2.fromOffset(SLOT_SIZE + 10, SLOT_SIZE + 10)
				s.button.Activated:Connect(function() toggle(s.tool) end)
				bagSlots[i] = s
			end
			s.button.Visible = true
			paintSlot(s, tool, i)
			if tool:GetAttribute("FishingTool") == "Fish" then fishCount += 1 end
		end
		for i = #list + 1, #bagSlots do
			bagSlots[i].button.Visible = false
		end
		bagInfo.Text = "🐟 " .. fishCount .. " / " .. FishingConfig.backpackSize(player)
	end
end

local function toggleBag()
	if bag.isOpen() then bag.hide() else bag.open() end
	Kit.pop(invSlot.button, 0.9)
end

for _, s in ipairs(slots) do
	s.button.Activated:Connect(function()
		if s.tool then toggle(s.tool) end
	end)
end
invSlot.button.Activated:Connect(toggleBag)
bag.onOpen = refresh
bag.onClose = refresh

------------------------------------------------------------------------------------------
-- keys
------------------------------------------------------------------------------------------
local onIsland = false
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not onIsland then return end
	for i, key in ipairs(KEYS) do
		if input.KeyCode == key then
			local s = slots[i]
			if s.tool then toggle(s.tool) end
			Kit.pop(s.button, 0.9)
			return
		end
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Backquote then
		-- E also talks to the stalls: only open the inventory when no prompt is showing
		local prompts = player.PlayerGui:FindFirstChild("CustomPrompts")
		if input.KeyCode == Enum.KeyCode.E and prompts and #prompts:GetChildren() > 0 and not bag.isOpen() then
			return
		end
		toggleBag()
	end
end)

------------------------------------------------------------------------------------------
-- keep it in sync
------------------------------------------------------------------------------------------
local pending = false
local function queue()
	if pending then return end
	pending = true
	task.defer(function()
		pending = false
		refresh()
	end)
end

local function watch(container)
	if not container then return end
	container.ChildAdded:Connect(queue)
	container.ChildRemoved:Connect(queue)
end
watch(player:WaitForChild("Backpack"))
player.ChildAdded:Connect(function(c) if c:IsA("Backpack") then watch(c) queue() end end)
if player.Character then watch(player.Character) end
player.CharacterAdded:Connect(function(c) watch(c) queue() end)

local function setCoreBackpack(on)
	for _ = 1, 5 do
		local ok = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, on) end)
		if ok then return end
		task.wait(0.5)
	end
end

task.spawn(function()
	while true do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local now = root ~= nil and FishingFrenzyConfig.isInside(root.Position)
		if now ~= onIsland then
			onIsland = now
			gui.Enabled = now
			setCoreBackpack(not now)
			if not now and bag.isOpen() then bag.hide() end
			refresh()
		end
		if onIsland then fit() end
		task.wait(0.3)
	end
end)
