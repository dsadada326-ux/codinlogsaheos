-- Inventory menu (StarterGui.Inventory). MenuPopups opens/closes it; this fills it in.
--   Tabs on the left: Items / Consumables (the selected tab uses the green "open" look and pops).
--   Items       - the Equipment you own. Click one to see it on the right with its boosts and
--                 Equip / Unequip (uses the EquipEquipment remote, same as the Trader).
--   Consumables - your consumables + Active Effects (no consumables exist in the game yet).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local EquipmentConfig = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))
local equipRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EquipEquipment")

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Inventory")
local holder = gui:WaitForChild("Holder")
local tabsFrame = holder:WaitForChild("InventoryButtonsFrame")
local openTemplate = tabsFrame:WaitForChild("OpenButtonTemplate")
local closedTemplate = tabsFrame:WaitForChild("ClosedButtonTemplate")
local itemsList = holder:WaitForChild("InventoryScrollingFrame")
local itemTemplate = itemsList:WaitForChild("InventoryItemTemplate")
local viewFrame = holder:WaitForChild("ViewFrame")
local viewTemplate = gui:WaitForChild("ViewItemTemplate")
local consumablesList = holder:WaitForChild("ConsumablesScrollingFrame")
local activeEffects = holder:WaitForChild("ActiveEffects")
local confirmOverlay = gui:FindFirstChild("ConfirmOverlay")

itemTemplate.Visible = false
viewTemplate.Visible = false
if confirmOverlay then confirmOverlay.Visible = false end

itemsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
itemsList.CanvasSize = UDim2.new()
consumablesList.AutomaticCanvasSize = Enum.AutomaticSize.Y
consumablesList.CanvasSize = UDim2.new()

local EQUIPPED_COLOR = Color3.fromRGB(110, 255, 120)
local SELECTED_COLOR = Color3.fromRGB(255, 255, 255)

-- boost text + icon
local BOOSTS = {
	{ key = "money", text = function(v) return "x" .. v .. " Money" end, icon = "rbxassetid://74760303647639" },
	{ key = "coins", text = function(v) return "x" .. v .. " Coins" end, icon = "rbxassetid://99928751746150" },
	{ key = "time", text = function(v) return "x" .. v .. " Time" end, icon = "rbxassetid://104436607164470" },
	{ key = "runeLuck", text = function(v) return "x" .. v .. " Rune Luck" end, icon = "rbxassetid://101935509296686" },
	{ key = "runeBulk", text = function(v) return "+" .. v .. " Rune Bulk" end, icon = "rbxassetid://101935509296686" },
	{ key = "walkSpeed", text = function(v) return "+" .. v .. " Speed" end, icon = "rbxassetid://101881781579355" },
}

local function setText(label, text)
	if not label then return end
	label.Text = text
	local extra = label:FindFirstChild("Extra")
	if extra then extra.Text = text end
end

local function darker(c, k)
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

local function emptyLabel(parent, text)
	local source = activeEffects:FindFirstChild("EmptyLabel")
	local label = source and source:Clone() or Instance.new("TextLabel")
	label.Name = "EmptyLabel"
	label.AnchorPoint = Vector2.new(0, 0)
	label.Position = UDim2.new()
	label.Size = UDim2.new(1, 0, 0.2, 0)
	label.Text = text
	label.Visible = false
	label.Parent = parent
	return label
end

local itemsEmpty = emptyLabel(itemsList, "No items yet!\nBuy Equipment from the Trader.")
local consumablesEmpty = emptyLabel(consumablesList, "No consumables yet!")

------------------------------------------------------------------------------------------
-- tabs
------------------------------------------------------------------------------------------
-- remember the two looks, so any tab can wear either
local function snapshot(button)
	local strokes = {}
	for _, c in ipairs(button:GetChildren()) do
		if c:IsA("UIStroke") then table.insert(strokes, c.Color) end
	end

	local title = button:FindFirstChild("Title")
	local extra = title and title:FindFirstChild("Extra")

	return {
		gradient = button:FindFirstChildOfClass("UIGradient") and button:FindFirstChildOfClass("UIGradient").Color,
		strokes = strokes,
		titleStroke = title and title:FindFirstChildOfClass("UIStroke") and title:FindFirstChildOfClass("UIStroke").Color,
		extraStroke = extra and extra:FindFirstChildOfClass("UIStroke") and extra:FindFirstChildOfClass("UIStroke").Color,
		extraGradient = extra and extra:FindFirstChildOfClass("UIGradient") and extra:FindFirstChildOfClass("UIGradient").Color,
	}
end

local LOOK_OPEN = snapshot(openTemplate)
local LOOK_CLOSED = snapshot(closedTemplate)

local function wear(button, look)
	local g = button:FindFirstChildOfClass("UIGradient")
	if g and look.gradient then g.Color = look.gradient end

	local i = 0
	for _, c in ipairs(button:GetChildren()) do
		if c:IsA("UIStroke") then
			i += 1
			if look.strokes[i] then c.Color = look.strokes[i] end
		end
	end

	local title = button:FindFirstChild("Title")
	local extra = title and title:FindFirstChild("Extra")

	if title and title:FindFirstChildOfClass("UIStroke") and look.titleStroke then
		title:FindFirstChildOfClass("UIStroke").Color = look.titleStroke
	end
	if extra and extra:FindFirstChildOfClass("UIStroke") and look.extraStroke then
		extra:FindFirstChildOfClass("UIStroke").Color = look.extraStroke
	end
	if extra and extra:FindFirstChildOfClass("UIGradient") and look.extraGradient then
		extra:FindFirstChildOfClass("UIGradient").Color = look.extraGradient
	end
end

local tabs = {
	Items = { button = openTemplate },
	Consumables = { button = closedTemplate },
}

openTemplate.Name = "Items"
closedTemplate.Name = "Consumables"
openTemplate.LayoutOrder = 1
closedTemplate.LayoutOrder = 2
setText(openTemplate:FindFirstChild("Title"), "Items")
setText(closedTemplate:FindFirstChild("Title"), "Consumables")

local tabInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PAGE_POSITIONS = { [itemsList] = itemsList.Position, [consumablesList] = consumablesList.Position }

for name, t in pairs(tabs) do
	local scale = Instance.new("UIScale")
	scale.Name = "TabScale"
	scale.Parent = t.button
	t.scale = scale
end

local selectedTab = nil
local refreshItems, showItem

local function selectTab(name)
	selectedTab = name

	for tabName, t in pairs(tabs) do
		local on = tabName == name
		wear(t.button, on and LOOK_OPEN or LOOK_CLOSED)

		if on then
			t.scale.Scale = 1.15
			TweenService:Create(t.scale, tabInfo, { Scale = 1.06 }):Play()
		else
			TweenService:Create(t.scale, tabInfo, { Scale = 0.95 }):Play()
		end
	end

	local items = name == "Items"
	itemsList.Visible = items
	viewFrame.Visible = items
	consumablesList.Visible = not items
	activeEffects.Visible = not items

	-- slide the new page in
	local page = items and itemsList or consumablesList
	local base = PAGE_POSITIONS[page]
	page.Position = base + UDim2.fromScale(0, 0.04)
	TweenService:Create(page, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = base }):Play()

	if items then
		refreshItems()
	end
end

for name, t in pairs(tabs) do
	t.button.Activated:Connect(function()
		if selectedTab ~= name then
			selectTab(name)
		end
	end)

	t.button.MouseEnter:Connect(function()
		if selectedTab ~= name then
			TweenService:Create(t.scale, tabInfo, { Scale = 1 }):Play()
		end
	end)

	t.button.MouseLeave:Connect(function()
		if selectedTab ~= name then
			TweenService:Create(t.scale, tabInfo, { Scale = 0.95 }):Play()
		end
	end)
end

------------------------------------------------------------------------------------------
-- Items: owned Equipment
------------------------------------------------------------------------------------------
local cards = {} -- [id] = { card, stroke, badge, hover }
local selectedItem = nil
local view = nil

local function owned(id)
	return player:GetAttribute(EquipmentConfig.ownedAttribute(id)) == true
end

local function buildCard(id, order)
	local def = EquipmentConfig.Items[id]
	local rarity = EquipmentConfig.RarityColors[def.rarity] or Color3.new(1, 1, 1)

	local card = itemTemplate:Clone()
	card.Name = id
	card.LayoutOrder = order
	card.Visible = true

	card:WaitForChild("Image").Image = def.image

	local rg = card:FindFirstChild("RarityGradient")
	local rgGradient = rg and rg:FindFirstChildOfClass("UIGradient")
	if rgGradient then
		rgGradient.Color = ColorSequence.new(darker(rarity, 0.45), rarity)
	end

	-- "Equipped" tag along the bottom
	local badge = Instance.new("TextLabel")
	badge.Name = "EquippedBadge"
	badge.BackgroundTransparency = 1
	badge.AnchorPoint = Vector2.new(0.5, 1)
	badge.Position = UDim2.fromScale(0.5, 0.97)
	badge.Size = UDim2.fromScale(0.9, 0.22)
	badge.ZIndex = 5
	badge.TextScaled = true
	badge.Text = "Equipped"
	badge.TextColor3 = EQUIPPED_COLOR
	badge.Visible = false
	local titleLabel = openTemplate:FindFirstChild("Title")
	if titleLabel then badge.FontFace = titleLabel.FontFace end
	local bs = Instance.new("UIStroke")
	bs.Thickness = 2
	bs.Parent = badge
	badge.Parent = card

	-- click area (the card itself is a CanvasGroup)
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 10
	hit:SetAttribute("NoTween", true)
	hit.Parent = card

	local hover = Instance.new("UIScale")
	hover.Name = "Hover"
	hover.Parent = card

	hit.MouseEnter:Connect(function()
		TweenService:Create(hover, tabInfo, { Scale = 1.06 }):Play()
	end)
	hit.MouseLeave:Connect(function()
		TweenService:Create(hover, tabInfo, { Scale = 1 }):Play()
	end)
	hit.Activated:Connect(function()
		hover.Scale = 0.92
		TweenService:Create(hover, tabInfo, { Scale = 1.06 }):Play()
		showItem(id)
	end)

	card.Parent = itemsList

	cards[id] = { card = card, stroke = card:FindFirstChild("InnerUIStroke"), badge = badge, rarity = rarity }
end

local function paintCard(id)
	local c = cards[id]
	if not c then return end

	local equipped = EquipmentConfig.equipped(player) == id
	c.badge.Visible = equipped

	if c.stroke then
		c.stroke.Color = (selectedItem == id and SELECTED_COLOR) or (equipped and EQUIPPED_COLOR) or c.rarity
	end
end

local function clearView()
	if view then
		view:Destroy()
		view = nil
	end
end

local viewHint = emptyLabel(viewFrame, "Click an item to see it here!")
viewHint.AnchorPoint = Vector2.new(0.5, 0.5)
viewHint.Position = UDim2.fromScale(0.5, 0.5)
viewHint.Size = UDim2.fromScale(0.9, 0.2)
viewHint.ZIndex = 5

local function renderView()
	clearView()

	local id = selectedItem
	local def = id and EquipmentConfig.Items[id]
	viewHint.Visible = def == nil

	if not def then
		return
	end

	view = viewTemplate:Clone()
	view.Name = "View"
	view.AnchorPoint = Vector2.new(0, 0)
	view.Position = UDim2.new()
	view.Size = UDim2.fromScale(1, 1)
	view.Visible = true
	view.ZIndex = 5

	setText(view:FindFirstChild("ItemName"), def.name)
	view:FindFirstChild("Image").Image = def.image

	local rarity = EquipmentConfig.RarityColors[def.rarity]
	local inner = view:FindFirstChild("InnerUIStroke")
	if inner and rarity then inner.Color = rarity end

	local boosts = view:FindFirstChild("Boosts")
	local template = boosts and boosts:FindFirstChild("BoostTemplate")

	if template then
		template.Visible = false

		for i, b in ipairs(BOOSTS) do
			local value = def.boosts[b.key]

			if value then
				local row = template:Clone()
				row.Name = "Boost_" .. b.key
				row.LayoutOrder = i
				row.Visible = true
				setText(row:FindFirstChild("BoostLabel"), b.text(value))

				local img = row:FindFirstChild("BoostImage")
				if img then
					img.Visible = b.icon ~= nil
					img.Image = b.icon or ""
				end

				row.Parent = boosts
			end
		end
	end

	local buttonsFrame = view:FindFirstChild("Buttons")
	local equipButton = buttonsFrame and buttonsFrame:FindFirstChild("Equip")
	local unequipButton = buttonsFrame and buttonsFrame:FindFirstChild("Unequip")
	local equipped = EquipmentConfig.equipped(player) == id

	if equipButton then
		equipButton.Visible = not equipped
		equipButton.Activated:Connect(function()
			pcall(function() equipRemote:InvokeServer(id) end)
		end)
	end

	if unequipButton then
		unequipButton.Visible = equipped
		unequipButton.Activated:Connect(function()
			pcall(function() equipRemote:InvokeServer("") end)
		end)
	end

	view.Parent = viewFrame

	-- pop in
	local pop = Instance.new("UIScale")
	pop.Scale = 0.85
	pop.Parent = view
	TweenService:Create(pop, tabInfo, { Scale = 1 }):Play()
end

showItem = function(id)
	local previous = selectedItem
	selectedItem = id

	if previous then paintCard(previous) end
	paintCard(id)
	renderView()
end

refreshItems = function()
	local any = false

	for order, id in ipairs(EquipmentConfig.Order) do
		if owned(id) then
			any = true

			if not cards[id] then
				buildCard(id, order)
			end

			paintCard(id)
		elseif cards[id] then
			cards[id].card:Destroy()
			cards[id] = nil
		end
	end

	itemsEmpty.Visible = not any

	if selectedItem and not owned(selectedItem) then
		selectedItem = nil
	end

	-- default to the equipped item
	if not selectedItem then
		local equipped = EquipmentConfig.equipped(player)
		selectedItem = equipped and owned(equipped) and equipped or nil
		if selectedItem then paintCard(selectedItem) end
	end

	renderView()
end

------------------------------------------------------------------------------------------
-- Consumables (none in the game yet: empty list + "No active effects")
------------------------------------------------------------------------------------------
consumablesEmpty.Visible = true

local effectsList = activeEffects:FindFirstChild("List")
local effectTemplate = effectsList and effectsList:FindFirstChild("EffectTemplate")
if effectTemplate then effectTemplate.Visible = false end

------------------------------------------------------------------------------------------
-- keep it up to date
------------------------------------------------------------------------------------------
player.AttributeChanged:Connect(function(attribute)
	if attribute == "EquippedIndex" or attribute:sub(1, 10) == "Equipment_" then
		if gui.Enabled and selectedTab == "Items" then
			refreshItems()
		end
	end
end)

-- every time the menu opens, start on Items
gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled then
		selectTab("Items")
	end
end)

selectTab("Items")
