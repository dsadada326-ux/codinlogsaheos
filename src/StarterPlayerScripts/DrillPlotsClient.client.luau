-- DRILLING MANIA: the drill plots (Workspace.DrillArea, covered by the grass in Workspace.Full).
--   * Step on the red button to buy the next plot: its grass drops away and the dirt shows.
--     The button then moves to the next plot (like the Wheat Farm on Island 2).
--   * Pick a drill in the hotbar (1-9 or click), walk to an empty plot, press E to place it.
--   * Drills pump Oil into their tank; walk up to a drill to collect it. Hold E to remove one.
-- Everything here is only drawn on your screen; DrillService checks the real rules.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DrillConfig = require(ReplicatedStorage:WaitForChild("DrillConfig"))
local DrillVisuals = require(ReplicatedStorage:WaitForChild("DrillVisuals"))
local Multipliers = require(ReplicatedStorage:WaitForChild("Multipliers"))
local Kit = require(ReplicatedStorage:WaitForChild("FishingUIKit"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local actionRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DrillAction")

local INK = Color3.fromRGB(10, 10, 14)
local FONT = Font.fromEnum(Enum.Font.FredokaOne)

local area = workspace:WaitForChild("DrillingMania")
local full = area:WaitForChild("Full")
local dirt = area:WaitForChild("DrillArea")
local buttonModel = full:WaitForChild("DrillSpot")
local buttonPart = buttonModel:WaitForChild("Button")
local buttonBase = buttonModel:WaitForChild("Part")

local function abbreviate(n)
	return NumberFormat.abbreviate(math.floor(n + 0.5))
end
local function fmtRate(n)
	return NumberFormat.abbreviate(math.floor(n * 10 + 0.5) / 10)
end

local folder = Instance.new("Folder")
folder.Name = "DrillPlotsClient"
folder.Parent = workspace

------------------------------------------------------------------------------------------
-- the grid
------------------------------------------------------------------------------------------
local fullCF, fullSize = full.CFrame, full.Size
local dirtTop = dirt.Position.Y + dirt.Size.Y / 2
local cells = {} -- [i] = { center (on the dirt), tileCF, cw, ch }
for i = 1, DrillConfig.MaxPlots do
	local offset, cw, ch = DrillConfig.cellOffset(i, fullSize)
	local world = fullCF * CFrame.new(offset.X, 0, offset.Z)
	cells[i] = {
		tileCF = world,
		floor = CFrame.new(world.Position.X, dirtTop, world.Position.Z) * fullCF.Rotation,
		cw = cw, ch = ch,
	}
end

-- the one big grass part becomes one tile per plot (so each plot can drop away on its own)
full.Transparency = 1
full.CanCollide = false
full.CanQuery = false
for _, t in ipairs(full:GetChildren()) do
	if t:IsA("Texture") then t.Transparency = 1 end
end

local tiles = {}
for i, c in ipairs(cells) do
	local tile = Instance.new("Part")
	tile.Name = "PlotCover" .. i
	tile.Anchored = true
	tile.Size = Vector3.new(c.cw, fullSize.Y, c.ch)
	tile.CFrame = c.tileCF
	tile.Color = full.Color
	tile.Material = full.Material
	tile.TopSurface = Enum.SurfaceType.Smooth
	for _, t in ipairs(full:GetChildren()) do
		if t:IsA("Texture") and t.Face == Enum.NormalId.Top then
			local copy = t:Clone()
			copy.Transparency = 0.8
			copy.OffsetStudsU = -(c.tileCF.Position.X)
			copy.Parent = tile
		end
	end
	tile.Parent = folder
	tiles[i] = { part = tile, open = false }
end

-- thin outline on every owned plot so you can see the grid
local function outline(i)
	local c = cells[i]
	local box = Instance.new("SelectionBox")
	box.Adornee = nil
	local edge = Instance.new("Part")
	edge.Name = "PlotEdge" .. i
	edge.Anchored = true
	edge.CanCollide = false
	edge.CanQuery = false
	edge.CanTouch = false
	edge.Transparency = 1
	edge.Size = Vector3.new(c.cw - 0.3, 0.05, c.ch - 0.3)
	edge.CFrame = c.floor * CFrame.new(0, 0.03, 0)
	edge.Parent = folder
	box.Adornee = edge
	box.LineThickness = 0.06
	box.Color3 = Color3.fromRGB(60, 35, 10)
	box.SurfaceTransparency = 1
	box.Transparency = 0.35
	box.Parent = edge
	return edge
end

local function openTile(i, animate)
	local t = tiles[i]
	if t.open then return end
	t.open = true
	t.part.CanCollide = false
	t.edge = outline(i)
	if animate then
		local tween = TweenService:Create(t.part, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			CFrame = cells[i].tileCF * CFrame.new(0, -1.2, 0), Size = t.part.Size * Vector3.new(0.6, 1, 0.6), Transparency = 1,
		})
		tween:Play()
		for _, tex in ipairs(t.part:GetChildren()) do
			if tex:IsA("Texture") then TweenService:Create(tex, TweenInfo.new(0.5), { Transparency = 1 }):Play() end
		end
		-- dust puff
		local att = Instance.new("Attachment")
		att.WorldCFrame = cells[i].floor * CFrame.new(0, 0.5, 0)
		att.Parent = workspace.Terrain
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(150, 110, 70))
		pe.Size = NumberSequence.new(1.5, 3.5)
		pe.Transparency = NumberSequence.new(0.3, 1)
		pe.Lifetime = NumberRange.new(0.6, 1)
		pe.Speed = NumberRange.new(4, 9)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Rate = 0
		pe.Parent = att
		pe:Emit(28)
		task.delay(2, function() att:Destroy() end)
	else
		t.part.Transparency = 1
		t.part.CFrame = cells[i].tileCF * CFrame.new(0, -1.2, 0)
		for _, tex in ipairs(t.part:GetChildren()) do
			if tex:IsA("Texture") then tex.Transparency = 1 end
		end
	end
end

local function closeTile(i)
	local t = tiles[i]
	if not t.open then return end
	t.open = false
	t.part.CanCollide = true
	t.part.Size = Vector3.new(cells[i].cw, fullSize.Y, cells[i].ch)
	t.part.CFrame = cells[i].tileCF
	t.part.Transparency = 0
	for _, tex in ipairs(t.part:GetChildren()) do
		if tex:IsA("Texture") then tex.Transparency = 0.8 end
	end
	if t.edge then t.edge:Destroy() t.edge = nil end
end

------------------------------------------------------------------------------------------
-- the red buy button
------------------------------------------------------------------------------------------
local buttonHome = buttonModel:GetPivot()
local baseToPivot = buttonBase.CFrame:ToObjectSpace(buttonHome)
local baseY = buttonBase.Position.Y
local buttonRest = buttonBase.CFrame:ToObjectSpace(buttonPart.CFrame) -- the red top, relative to its base
local priceTag = buttonPart:FindFirstChild("PriceTag")
local nameLabel = priceTag and priceTag:FindFirstChild("NameLabel", true)
local priceLabel = priceTag and priceTag:FindFirstChild("PriceLabel", true)
local priceIcon = priceTag and priceTag:FindFirstChild("CurrencyImageIcon", true)
if priceIcon then priceIcon.Image = DrillConfig.Icons.Iron end
local buttonAt -- which plot the button sits on

local function paintTag()
	local owned = player:GetAttribute("DrillPlots") or 0
	local price = DrillConfig.PlotPrices[owned + 1]
	if not (priceTag and price) then return end
	local affordable = price <= (player:GetAttribute("Metal") or 0)
	local design = priceTag:FindFirstChild("Design", true)
	if design then
		for _, child in ipairs(design:GetChildren()) do
			if child.Name:sub(-2) == "On" then child.Enabled = affordable
			elseif child.Name:sub(-3) == "Off" then child.Enabled = not affordable end
		end
	end
end

local moveToken = 0
local pressTweens = {}
local function stopPress()
	for _, t in ipairs(pressTweens) do t:Cancel() end
	pressTweens = {}
end

local function moveButton(index, animate)
	moveToken += 1
	stopPress()
	local c = index and cells[index]
	if not c then
		buttonModel.Parent = nil
		buttonAt = nil
		return
	end
	buttonModel.Parent = full
	buttonAt = index
	-- put the button part back on its base first (a press may have pushed it down)
	buttonPart.CFrame = buttonBase.CFrame * buttonRest
	local baseCF = CFrame.new(c.tileCF.Position.X, baseY, c.tileCF.Position.Z) * buttonBase.CFrame.Rotation
	local target = baseCF * baseToPivot
	if animate then
		-- pops up out of the ground at the new plot (no scaling: that would squash the price tag)
		local v = Instance.new("NumberValue")
		v.Value = 0
		buttonModel:PivotTo(target * CFrame.new(0, -1.6, 0))
		local token = moveToken
		v:GetPropertyChangedSignal("Value"):Connect(function()
			if token ~= moveToken then return end
			buttonModel:PivotTo(target * CFrame.new(0, -1.6 * (1 - v.Value), 0))
		end)
		local t = TweenService:Create(v, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 })
		t.Completed:Connect(function()
			if token == moveToken then buttonModel:PivotTo(target) end
			v:Destroy()
		end)
		t:Play()
	else
		buttonModel:PivotTo(target)
	end
	if nameLabel then nameLabel.Text = "Drill Plot " .. index end
	if priceLabel then
		local price = DrillConfig.PlotPrices[index] or 0
		priceLabel.Text = price <= 0 and "FREE" or abbreviate(price)
	end
	if priceIcon then priceIcon.Visible = (DrillConfig.PlotPrices[index] or 0) > 0 end
	paintTag()
end

local buyBusy, buyBlockedUntil = false, 0
buttonPart.Touched:Connect(function(hit)
	local character = player.Character
	if not (character and hit:IsDescendantOf(character)) or buyBusy or os.clock() < buyBlockedUntil or not buttonAt then
		return
	end
	buyBusy = true
	-- press down (and back up, unless the button already moved to the next plot)
	local token = moveToken
	local rest = buttonBase.CFrame * buttonRest
	stopPress()
	local down = TweenService:Create(buttonPart, TweenInfo.new(0.08), { CFrame = rest * CFrame.new(0, -0.3, 0) })
	table.insert(pressTweens, down)
	down:Play()
	task.delay(0.12, function()
		if token ~= moveToken then return end
		local back = TweenService:Create(buttonPart, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = buttonBase.CFrame * buttonRest })
		table.insert(pressTweens, back)
		back:Play()
	end)
	local ok, result = pcall(function() return actionRemote:InvokeServer("buyPlot") end)
	if ok and type(result) == "table" and result.ok then
		-- one plot per step: the button needs a fresh step after it moves
		buyBlockedUntil = os.clock() + 1.2
	elseif not (ok and type(result) == "table" and result.reason == "cooldown") then
		MessageToPlayer.show("PurchaseUnavailable")
		buyBlockedUntil = os.clock() + 1.5
	end
	task.wait(0.35)
	buyBusy = false
end)

------------------------------------------------------------------------------------------
-- placed drills
------------------------------------------------------------------------------------------
local drawn = {} -- [cell] = { id, model, step, gui, fill, oilText, anchor, prompt }
local selectedId = nil

local function drillBillboard(drill, adornee, height)
	local gui = Instance.new("BillboardGui")
	gui.Name = "DrillInfo"
	gui.Size = UDim2.fromOffset(150, 88)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height - 0.5, 0)
	gui.MaxDistance = 28
	gui.LightInfluence = 0
	gui.Adornee = adornee
	gui.Parent = playerGui
	local color = DrillVisuals.rarityColor(drill.rarity)
	local nameLabel = Kit.text(gui, { Text = drill.name, Size = UDim2.new(1, 0, 0, 26), Stroke = 2.5, TextColor3 = Color3.new(1, 1, 1) })
	local rarity = Kit.text(gui, { Text = drill.rarity, Position = UDim2.fromOffset(0, 25), Size = UDim2.new(1, 0, 0, 18), Stroke = 2, TextColor3 = color })
	local rate = Kit.text(gui, { Text = "", Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 20), Stroke = 2, TextColor3 = Color3.fromRGB(150, 255, 140) })
	local tank = Kit.new("Frame", {
		Position = UDim2.new(0.1, 0, 0, 66), Size = UDim2.new(0.8, 0, 0, 20), BackgroundColor3 = Color3.fromRGB(25, 22, 35), ClipsDescendants = true,
	}, gui)
	Kit.corner(tank, 0.5)
	Kit.stroke(tank, 2.5, INK, true)
	local fill = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, tank)
	Kit.corner(fill, 0.5)
	Kit.gradient(fill, Color3.fromRGB(190, 160, 255), Color3.fromRGB(90, 55, 170))
	local oilText = Kit.text(tank, {
		Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.95, 0.85), Stroke = 1.5, ZIndex = 2,
	})
	return gui, fill, oilText, rate, nameLabel
end

local function clearDrill(cell)
	local d = drawn[cell]
	if not d then return end
	if d.model then d.model:Destroy() end
	if d.gui then d.gui:Destroy() end
	drawn[cell] = nil
end

local function drawDrill(cell, id, animate)
	clearDrill(cell)
	local drill = DrillConfig.DrillById[id]
	local c = cells[cell]
	if not (drill and c) then return end
	local model = DrillVisuals.placeOnPlot(drill, c.floor, math.min(c.cw, c.ch) - 1.4)
	if not model then return end
	model.Name = "PlacedDrill" .. cell
	model.Parent = folder
	local _, size = model:GetBoundingBox()
	local gui, fill, oilText, rateText = drillBillboard(drill, c.anchor, size.Y)
	local d = { id = id, model = model, step = DrillVisuals.animator(model), gui = gui, fill = fill, oilText = oilText, rateText = rateText, drill = drill }
	drawn[cell] = d
	if animate then
		local target = model:GetPivot()
		local v = Instance.new("NumberValue")
		v.Value = 0
		model:PivotTo(target * CFrame.new(0, 12, 0))
		v:GetPropertyChangedSignal("Value"):Connect(function()
			if model.Parent then model:PivotTo(target * CFrame.new(0, 12 * (1 - v.Value), 0)) end
		end)
		local t = TweenService:Create(v, TweenInfo.new(0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Value = 1 })
		t.Completed:Connect(function() v:Destroy() end)
		t:Play()
		d.step = nil
		task.delay(0.5, function()
			if drawn[cell] == d then d.step = DrillVisuals.animator(model) end
		end)
	end
end

-- an invisible anchor + prompt on every plot
for i, c in ipairs(cells) do
	local anchor = Instance.new("Part")
	anchor.Name = "PlotAnchor" .. i
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = c.floor * CFrame.new(0, 2.5, 0)
	anchor.Parent = folder
	c.anchor = anchor
	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 7
	prompt.Enabled = false
	prompt.Parent = anchor
	c.prompt = prompt
	prompt.Triggered:Connect(function()
		local placed = DrillConfig.placed(player)
		if placed[tostring(i)] then
			local ok, r = pcall(function() return actionRemote:InvokeServer("remove", i) end)
			if not (ok and type(r) == "table" and r.ok) then MessageToPlayer.show("PurchaseUnavailable") end
		elseif selectedId then
			local id = selectedId
			local ok, r = pcall(function() return actionRemote:InvokeServer("place", i, id) end)
			if not (ok and type(r) == "table" and r.ok) then MessageToPlayer.show("PurchaseUnavailable") end
		end
	end)
end

------------------------------------------------------------------------------------------
-- sync with your data
------------------------------------------------------------------------------------------
local firstSync = true
local refreshHotbar -- defined below

local function sync()
	local owned = player:GetAttribute("DrillPlots") or 0
	for i = 1, #cells do
		if i <= owned then
			openTile(i, not firstSync)
		else
			closeTile(i)
		end
	end
	if owned < #cells then
		if buttonAt ~= owned + 1 then moveButton(owned + 1, not firstSync) end
	else
		moveButton(nil)
	end
	local placed = DrillConfig.placed(player)
	for i = 1, #cells do
		local id = placed[tostring(i)]
		if id and i <= owned then
			if not drawn[i] or drawn[i].id ~= id then drawDrill(i, id, not firstSync) end
		else
			clearDrill(i)
		end
	end
	firstSync = false
	if refreshHotbar then refreshHotbar() end
end

------------------------------------------------------------------------------------------
-- hotbar: your drills that aren't placed
------------------------------------------------------------------------------------------
local SLOTS, SLOT, GAP = 9, 78, 8
local KEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
}
local gui = Kit.new("ScreenGui", { Name = "DrillHotbar", ResetOnSpawn = false, DisplayOrder = 6, Enabled = false }, playerGui)
local bar = Kit.new("Frame", {
	Name = "Bar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.fromOffset(SLOTS * SLOT + (SLOTS - 1) * GAP, SLOT), BackgroundTransparency = 1,
}, gui)
Kit.new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder,
}, bar)
local barScale = Kit.new("UIScale", {}, bar)
local hint = Kit.text(gui, {
	Name = "Hint", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -SLOT - 18), Size = UDim2.fromOffset(520, 28),
	Text = "", Stroke = 2.5, TextColor3 = Color3.fromRGB(255, 240, 200),
})

local menuBar
task.spawn(function()
	local buttons = playerGui:WaitForChild("Buttons", 30)
	menuBar = buttons and buttons:WaitForChild("Container", 30)
end)
local function fit()
	local cam = workspace.CurrentCamera
	local width = cam and cam.ViewportSize.X or 1200
	local left = 16
	if menuBar and menuBar.Visible then
		left = math.max(left, menuBar.AbsolutePosition.X + menuBar.AbsoluteSize.X + 16)
	end
	if left > width * 0.6 then left = 16 end
	local room = width - left - 16
	local scale = math.clamp(room / bar.Size.X.Offset, 0.5, 1)
	barScale.Scale = scale
	local half = bar.Size.X.Offset * scale / 2
	local center = math.max(width / 2, left + half)
	bar.Position = UDim2.new(0, center, 1, -8)
	hint.Position = UDim2.new(0, center, 1, -SLOT * scale - 18)
end

local slots = {}
for i = 1, SLOTS do
	local b = Kit.new("TextButton", {
		Name = "Slot" .. i, LayoutOrder = i, Size = UDim2.fromOffset(SLOT, SLOT), Text = "", AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(38, 40, 44), BackgroundTransparency = 0.25,
	}, bar)
	Kit.corner(b, 0.16)
	local stroke = Kit.stroke(b, 3, INK, true)
	local num = Kit.text(b, {
		Text = tostring(i), Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(16, 16), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
	})
	local count = Kit.text(b, {
		Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 3), Size = UDim2.fromOffset(34, 16),
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3, TextColor3 = Color3.fromRGB(255, 230, 120),
	})
	local rate = Kit.text(b, {
		Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(0.9, 0, 0, 18), ZIndex = 3,
		TextColor3 = Color3.fromRGB(150, 255, 140),
	})
	local scale = Kit.new("UIScale", {}, b)
	b.MouseEnter:Connect(function() TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.06 }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play() end)
	slots[i] = { button = b, stroke = stroke, count = count, rate = rate, num = num }
end

local shownIds = {}
local function select(id)
	if selectedId == id then
		selectedId = nil
	else
		selectedId = id
	end
	refreshHotbar()
end

refreshHotbar = function()
	local inv = DrillConfig.inventory(player)
	local list = {}
	for id, n in pairs(inv) do
		if n > 0 and DrillConfig.DrillById[id] then table.insert(list, DrillConfig.DrillById[id]) end
	end
	table.sort(list, function(a, b) return a.index > b.index end) -- best first
	if selectedId and not inv[selectedId] then selectedId = nil end
	local oilMult = Multipliers.oil(player)
	for i, s in ipairs(slots) do
		local drill = list[i]
		if shownIds[i] ~= (drill and drill.id) then
			shownIds[i] = drill and drill.id
			if s.view then s.view:Destroy() s.view = nil end
			if drill then
				s.view = DrillVisuals.viewport(s.button, drill, {
					Position = UDim2.fromScale(0.08, 0.04), Size = UDim2.fromScale(0.84, 0.74), ZIndex = 2,
				}, 25)
			end
		end
		s.drill = drill
		s.button.Visible = drill ~= nil -- only the drills you have
		if drill then
			s.count.Text = "x" .. inv[drill.id]
			s.rate.Text = fmtRate(drill.rate * oilMult) .. "/s"
			local on = selectedId == drill.id
			s.button.BackgroundTransparency = on and 0.05 or 0.25
			s.button.BackgroundColor3 = on and DrillVisuals.rarityColor(drill.rarity):Lerp(Color3.fromRGB(40, 40, 50), 0.55) or Color3.fromRGB(38, 40, 44)
			s.stroke.Color = on and Color3.new(1, 1, 1) or DrillVisuals.rarityColor(drill.rarity):Lerp(INK, 0.5)
			s.stroke.Thickness = on and 3.5 or 3
		else
			s.count.Text = ""
			s.rate.Text = ""
			s.button.BackgroundTransparency = 0.6
			s.button.BackgroundColor3 = Color3.fromRGB(38, 40, 44)
			s.stroke.Color = INK
			s.stroke.Thickness = 3
		end
	end
	if selectedId then
		hint.Text = "Walk onto one of your empty plots and press E to place it!"
	elseif #list > 0 then
		hint.Text = "Pick a drill to place it"
	elseif next(DrillConfig.placed(player)) == nil then
		hint.Text = "Buy drills at the Drill Shop with Iron!"
	else
		hint.Text = ""
	end
end

for i, s in ipairs(slots) do
	s.button.Activated:Connect(function()
		if s.drill then
			Kit.pop(s.button, 0.88)
			select(s.drill.id)
		end
	end)
end

local inZone = false
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inZone then return end
	for i, key in ipairs(KEYS) do
		if input.KeyCode == key then
			local s = slots[i]
			if s.drill then
				Kit.pop(s.button, 0.88)
				select(s.drill.id)
			end
			return
		end
	end
end)

local function setCoreBackpack(on)
	for _ = 1, 5 do
		local ok = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, on) end)
		if ok then return end
		task.wait(0.5)
	end
end

------------------------------------------------------------------------------------------
-- ghost of the selected drill on the plot you're standing next to
------------------------------------------------------------------------------------------
local ghost, ghostId, ghostCell
local function clearGhost()
	if ghost then ghost:Destroy() end
	ghost, ghostId, ghostCell = nil, nil, nil
end
local function showGhost(cell)
	if ghostId == selectedId and ghostCell == cell then return end
	clearGhost()
	local drill = DrillConfig.DrillById[selectedId]
	local c = cells[cell]
	ghost = DrillVisuals.placeOnPlot(drill, c.floor, math.min(c.cw, c.ch) - 1.4)
	if not ghost then return end
	for _, p in ipairs(ghost:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Transparency = 1 - (1 - p.Transparency) * 0.45
			p.CastShadow = false
		elseif p:IsA("Decal") or p:IsA("Texture") then
			p.Transparency = 0.6
		elseif p:IsA("ParticleEmitter") or p:IsA("Beam") or p:IsA("Light") then
			p.Enabled = false
		end
	end
	local h = Instance.new("Highlight")
	h.FillColor = Color3.fromRGB(90, 255, 110)
	h.OutlineColor = Color3.fromRGB(200, 255, 200)
	h.FillTransparency = 0.65
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = ghost
	ghost.Name = "DrillGhost"
	ghost.Parent = folder
	ghostId, ghostCell = selectedId, cell
end

------------------------------------------------------------------------------------------
-- "+123 Oil" when you collect
------------------------------------------------------------------------------------------
local function oilPopup(cell, amount)
	local c = cells[cell]
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromOffset(180, 40)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.Adornee = c.anchor
	g.StudsOffset = Vector3.new(0, 2, 0)
	g.Parent = playerGui
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, g)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4),
	}, holder)
	local label = Kit.text(holder, {
		Text = "+" .. abbreviate(amount), Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = Color3.fromRGB(215, 195, 255), Stroke = 2.5,
	})
	local icon = Kit.image(holder, { Image = DrillConfig.Icons.Oil, Size = UDim2.fromScale(1, 1), SizeConstraint = Enum.SizeConstraint.RelativeYY })
	local sc = Kit.new("UIScale", { Scale = 0.3 }, holder)
	TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1.1 }):Play()
	TweenService:Create(g, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, 6, 0) }):Play()
	task.delay(0.7, function()
		TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		TweenService:Create(icon, TweenInfo.new(0.35), { ImageTransparency = 1 }):Play()
		local s = label:FindFirstChildOfClass("UIStroke")
		if s then TweenService:Create(s, TweenInfo.new(0.35), { Transparency = 1 }):Play() end
	end)
	task.delay(1.1, function() g:Destroy() end)
end

------------------------------------------------------------------------------------------
-- every frame / every tick
------------------------------------------------------------------------------------------
local collectDebounce = {}
local accum = 0

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for _, d in pairs(drawn) do
		if d.step and d.model.Parent and (d.model:GetPivot().Position - camPos).Magnitude < 160 then
			d.step(t)
		end
	end

	accum += dt
	if accum < 0.2 then return end
	accum = 0

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local nowIn = root ~= nil and DrillConfig.isInside(root.Position)
	if nowIn ~= inZone then
		inZone = nowIn
		gui.Enabled = nowIn
		task.spawn(setCoreBackpack, not nowIn)
		if not nowIn then
			selectedId = nil
			clearGhost()
		end
		refreshHotbar()
	end
	-- (re-applied every tick: something else, like Freecam, may have switched it back on)
	if gui.Enabled ~= inZone then gui.Enabled = inZone end
	if inZone then fit() end

	local owned = player:GetAttribute("DrillPlots") or 0
	local placed = DrillConfig.placed(player)
	local oilMult = Multipliers.oil(player)

	-- prompts + ghost: only the nearest empty plot offers "Place"
	local nearestEmpty, nearestDist = nil, 9
	for i, c in ipairs(cells) do
		if i <= owned and root then
			local dist = (Vector3.new(c.floor.X, 0, c.floor.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
			if not placed[tostring(i)] and dist < nearestDist then
				nearestEmpty, nearestDist = i, dist
			end
		end
	end
	for i, c in ipairs(cells) do
		local id = placed[tostring(i)]
		if i > owned then
			c.prompt.Enabled = false
		elseif id then
			local drill = DrillConfig.DrillById[id]
			c.prompt.Enabled = true
			c.prompt.ActionText = "Remove"
			c.prompt.ObjectText = drill and drill.name or "Drill"
			c.prompt.HoldDuration = 0.6
		else
			local on = selectedId ~= nil and i == nearestEmpty
			c.prompt.Enabled = on
			c.prompt.ActionText = "Place"
			c.prompt.ObjectText = on and DrillConfig.DrillById[selectedId].name or ""
			c.prompt.HoldDuration = 0
		end
		-- the drill's billboard: rate + tank
		local d = drawn[i]
		if d then
			local rate = d.drill.rate * oilMult
			local stored = player:GetAttribute(DrillConfig.oilAttribute(i)) or 0
			local cap = rate * DrillConfig.StorageSeconds
			d.rateText.Text = fmtRate(rate) .. " Oil/s"
			d.fill.Size = UDim2.fromScale(math.clamp(stored / cap, 0, 1), 1)
			d.oilText.Text = stored >= cap and "FULL! " .. abbreviate(stored) or abbreviate(stored) .. " Oil"
			-- walk up to it to collect
			if root and stored >= 1 then
				local c2 = cells[i]
				local dist = (Vector3.new(c2.floor.X, 0, c2.floor.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
				if dist < 4.6 and t - (collectDebounce[i] or 0) > 0.8 then
					collectDebounce[i] = t
					task.spawn(function()
						local ok, r = pcall(function() return actionRemote:InvokeServer("collect", i) end)
						if ok and type(r) == "table" and r.ok and (r.oil or 0) > 0 then
							oilPopup(i, r.oil)
							if d.model.Parent then
								Kit.pop(d.fill.Parent, 1.2)
							end
						end
					end)
				end
			end
		end
	end

	if selectedId and nearestEmpty then
		showGhost(nearestEmpty)
	else
		clearGhost()
	end
end)

player:GetAttributeChangedSignal("DrillPlots"):Connect(sync)
player:GetAttributeChangedSignal("DrillPlaced"):Connect(sync)
player:GetAttributeChangedSignal("DrillInv"):Connect(function() refreshHotbar() end)
player:GetAttributeChangedSignal("Metal"):Connect(paintTag)
for _, id in ipairs({ "Upgrade_OilMultiplier", "DrillEnhance" }) do
	player:GetAttributeChangedSignal(id):Connect(function() refreshHotbar() end)
end

if player:GetAttribute("DataLoaded") ~= true then
	player:GetAttributeChangedSignal("DataLoaded"):Wait()
end
sync()
