-- Rod Shop (prompt Opens = "RodShop"): frosted glass list of every rod.
--   Each row: the rod, its name, Luck / Speed, and Equip / Equipped / price button.
--   Side panel: your next upgrade spinning on a sunburst.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local FishingConfig = require(ReplicatedStorage:WaitForChild("FishingConfig"))
local FishingVisuals = require(ReplicatedStorage:WaitForChild("FishingVisuals"))
local Kit = require(ReplicatedStorage:WaitForChild("FishingUIKit"))
local abbreviate = require(ReplicatedStorage:WaitForChild("NumberFormat")).abbreviate
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyRemote = remotes:WaitForChild("BuyRod")
local equipRemote = remotes:WaitForChild("EquipRod")
local rodModels = ReplicatedStorage:WaitForChild("FishingAssets"):WaitForChild("Rods")

local ICON = FishingVisuals.Icons.FishMeal

local w = Kit.glass("RodShop", "Fishing Rods", { side = true, main = 0.75, aspect = 1.55 })

local function fmt(n)
	local s = string.format("%.2f", n)
	s = s:gsub("0+$", ""):gsub("%.$", "")
	return s
end

-- rod model in a viewport, stood up and slightly tilted, framed to fit
local function rodViewport(parent, rod, props, tilt)
	local vpf = Kit.new("ViewportFrame", {
		BackgroundTransparency = 1, Ambient = Color3.fromRGB(175, 175, 175), LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
	})
	for k, v in pairs(props) do vpf[k] = v end
	vpf.Parent = parent
	local source = rodModels:FindFirstChild(rod.model)
	if not source then return vpf end
	local model = source:Clone()
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ParticleEmitter") then d:Destroy() end
	end
	local worldModel = Kit.new("WorldModel", {}, vpf)
	model.Parent = worldModel

	local cf, size = model:GetBoundingBox()
	local up
	if size.X >= size.Y and size.X >= size.Z then up = cf.RightVector
	elseif size.Z >= size.Y and size.Z >= size.X then up = cf.LookVector
	else up = cf.UpVector end
	local offset = CFrame.lookAlong(Vector3.zero, up):Inverse() * CFrame.new(-cf.Position)
	model:PivotTo(CFrame.Angles(0, 0, math.rad(tilt or -18)) * CFrame.Angles(math.rad(90), 0, 0) * offset * model:GetPivot())

	local c2, s2 = model:GetBoundingBox()
	local cam = Kit.new("Camera", { FieldOfView = 30 }, vpf)
	vpf.CurrentCamera = cam
	local radius = math.max(s2.X, s2.Y) * 0.5
	cam.CFrame = CFrame.lookAt(c2.Position + Vector3.new(0, 0, radius / math.tan(math.rad(15)) * 1.05 + s2.Z), c2.Position)
	return vpf, model, c2.Position
end

local function rodState(rod)
	local index = FishingConfig.RodIndex[rod.id]
	if (player:GetAttribute("EquippedRod") or 1) == index then return "equipped" end
	if FishingConfig.ownsRod(player, rod.id) then return "owned" end
	return "locked"
end

------------------------------------------------------------------------------------------
-- the list
------------------------------------------------------------------------------------------
local list = Kit.new("ScrollingFrame", {
	Name = "List", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 7, ScrollBarImageColor3 = Color3.fromRGB(250, 250, 250), ScrollBarImageTransparency = 0.3,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
}, w.body)
Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 16) }, list)
local layout = Kit.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local rows = {}

local function makeRow(i, rod)
	local row = Kit.new("Frame", {
		Name = rod.id, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 130), BackgroundColor3 = Color3.fromRGB(235, 245, 235),
		BackgroundTransparency = 0.45,
	}, list)
	Kit.corner(row, 0.16)
	Kit.stroke(row, 3, Color3.fromRGB(8, 10, 14), true)

	rodViewport(row, rod, { Position = UDim2.fromScale(0.02, 0.04), Size = UDim2.fromScale(0.2, 0.92) }, -8)

	Kit.text(row, {
		Text = rod.model, Position = UDim2.fromScale(0.26, 0.1), Size = UDim2.fromScale(0.44, 0.36),
		TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4, Max = 44,
	})
	local statRow = Kit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.26, 0.5), Size = UDim2.fromScale(0.44, 0.22) }, row)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder,
	}, statRow)
	Kit.text(statRow, {
		Text = "🍀 x" .. fmt(rod.luck) .. " Luck", Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = Color3.fromRGB(150, 255, 130), LayoutOrder = 1, Max = 26, Stroke = 2.5,
	})
	Kit.text(statRow, {
		Text = "⚡ x" .. fmt(rod.speed) .. " Speed", Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = Color3.fromRGB(150, 215, 255), LayoutOrder = 2, Max = 26, Stroke = 2.5,
	})

	local button, paint, label = Kit.button(row, {
		Name = "Action", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.97, 0, 0.5, 0), Size = UDim2.fromScale(0.26, 0.4),
	}, "Equip")
	label.Size = UDim2.fromScale(0.86, 0.66)
	-- price: "12M [icon]"
	local priceRow = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, button)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
	}, priceRow)
	local price = Kit.text(priceRow, { Text = "", Size = UDim2.fromScale(0, 0.62), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Max = 30, Stroke = 2.5 })
	Kit.image(priceRow, { Image = ICON, Size = UDim2.fromScale(0.7, 0.7), SizeConstraint = Enum.SizeConstraint.RelativeYY, LayoutOrder = 2 })

	local busy = false
	button.Activated:Connect(function()
		if busy then return end
		local state = rodState(rod)
		if state == "equipped" then return end
		busy = true
		local ok, result
		if state == "owned" then
			ok, result = pcall(function() return equipRemote:InvokeServer(rod.id) end)
		else
			ok, result = pcall(function() return buyRemote:InvokeServer(rod.id) end)
			if ok and result and not result.ok and result.reason == "money" then
				MessageToPlayer.show("NoFishMeal")
				Kit.pop(button, 0.85)
			end
		end
		if ok and result and result.ok then
			Kit.pop(row, 1.04)
		end
		busy = false
	end)

	rows[i] = { row = row, rod = rod, paint = paint, label = label, priceRow = priceRow, price = price }
end

for i, rod in ipairs(FishingConfig.Rods) do
	makeRow(i, rod)
end

-- keep rows a nice height as the window scales
local function resizeRows()
	local h = math.max(80, math.floor(list.AbsoluteSize.Y * 0.36))
	for _, r in ipairs(rows) do r.row.Size = UDim2.new(1, 0, 0, h) end
end
list:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeRows)

------------------------------------------------------------------------------------------
-- side panel: next upgrade
------------------------------------------------------------------------------------------
local side = w.side
local sideTitle = Kit.text(side, {
	Text = "Next upgrade:", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.04), Size = UDim2.fromScale(0.9, 0.08),
	TextColor3 = Color3.fromRGB(255, 225, 90), Max = 24, Stroke = 2.5,
})
local sideName = Kit.text(side, {
	Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.13), Size = UDim2.fromScale(0.92, 0.09), Max = 26, Stroke = 2.5,
})
local stage = Kit.new("Frame", {
	Name = "Stage", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.24), Size = UDim2.fromScale(0.96, 0.46),
	BackgroundTransparency = 1,
}, side)
Kit.sunburst(stage, Color3.fromRGB(255, 255, 240))
local sideStats = Kit.text(side, {
	Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromScale(0.92, 0.08),
	TextColor3 = Color3.fromRGB(150, 225, 255), Max = 22, Stroke = 2.5, RichText = true,
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

local sideView, sideModel, sideCenter, shownRod
local function showSide(rod)
	if not rod then
		sideTitle.Text = "All rods owned!"
		sideName.Text = "You're a legend 🎣"
		sideStats.Text = ""
		sidePrice.Text = ""
		sidePriceIcon.Visible = false
		if sideView then sideView:Destroy() sideView = nil end
		shownRod = nil
		return
	end
	sideTitle.Text = "Next upgrade:"
	sideName.Text = rod.model
	sideStats.Text = '<font color="#96FF82">🍀 x' .. fmt(rod.luck) .. '</font>   ⚡ x' .. fmt(rod.speed)
	local afford = (player:GetAttribute("FishMeal") or 0) >= rod.price
	sidePrice.Text = abbreviate(rod.price)
	sidePrice.TextColor3 = afford and Color3.fromRGB(150, 255, 120) or Color3.fromRGB(255, 110, 110)
	sidePriceIcon.Visible = true
	if shownRod ~= rod then
		shownRod = rod
		if sideView then sideView:Destroy() end
		sideView, sideModel, sideCenter = rodViewport(stage, rod, { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, -30)
	end
end

-- slow spin on the side rod
RunService.RenderStepped:Connect(function(dt)
	if w.isOpen() and sideModel and sideModel.Parent and sideCenter then
		sideModel:PivotTo(CFrame.new(sideCenter) * CFrame.Angles(0, dt * 0.9, 0) * CFrame.new(-sideCenter) * sideModel:GetPivot())
	end
end)

------------------------------------------------------------------------------------------
-- refresh
------------------------------------------------------------------------------------------
local function refresh()
	local fishMeal = player:GetAttribute("FishMeal") or 0
	local nextRod
	for _, r in ipairs(rows) do
		local state = rodState(r.rod)
		if state == "equipped" then
			r.label.Visible, r.priceRow.Visible = true, false
			r.label.Text = "Equipped"
			r.paint("gold")
		elseif state == "owned" then
			r.label.Visible, r.priceRow.Visible = true, false
			r.label.Text = "Equip"
			r.paint("green")
		else
			if not nextRod then nextRod = r.rod end
			r.label.Visible, r.priceRow.Visible = false, true
			r.price.Text = r.rod.price == 0 and "FREE" or abbreviate(r.rod.price)
			r.paint(fishMeal >= r.rod.price and "green" or "red")
		end
	end
	showSide(nextRod)
end

player.AttributeChanged:Connect(function(attr)
	if w.isOpen() and (attr == "FishMeal" or attr == "EquippedRod" or attr:sub(1, 4) == "Rod_") then
		refresh()
	end
end)

local standPosition
w.onOpen = function()
	resizeRows()
	refresh()
	-- scroll so your equipped rod is near the top
	task.defer(function()
		local r = rows[player:GetAttribute("EquippedRod") or 1]
		if r then
			list.CanvasPosition = Vector2.new(0, math.max(0, r.row.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y - 6))
		end
	end)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt:GetAttribute("Opens") ~= "RodShop" then return end
	standPosition = prompt.Parent and prompt.Parent:IsA("BasePart") and prompt.Parent.Position or nil
	if w.isOpen() then w.hide() else w.open() end
end)

Kit.closeWhenFar(w, function() return standPosition end, 22)
