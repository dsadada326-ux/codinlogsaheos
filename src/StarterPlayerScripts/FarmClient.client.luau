-- The Wheat Farm on Island 2 (client side). Ported from the old game's FarmManager.
-- Draws your plots: owned plots show their growth stage (Wheat0 -> Wheat5), the next plot
-- shows a buy button with its price. Walk onto the button to buy, walk into grown wheat
-- to harvest. Everything here is only on your screen; FarmService checks the real rules.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local FarmConfig = require(ReplicatedStorage:WaitForChild("FarmConfig"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyRemote = remotes:WaitForChild("BuyFarmSlot")
local claimRemote = remotes:WaitForChild("ClaimWheat")
local rewardRemote = remotes:WaitForChild("FarmReward")

local assets = ReplicatedStorage:WaitForChild("FarmAssets")
local wheatModels = assets:WaitForChild("Wheat")
local buttonTemplate = assets:WaitForChild("WheatButton")

local slotsFolder = workspace:WaitForChild("Islands"):WaitForChild("Island2")
	:WaitForChild("Zones"):WaitForChild("Farm"):WaitForChild("FarmLayer"):WaitForChild("Slots")

-- our plants live in their own folder so the zone reveal effects never touch them
local plantsFolder = workspace:FindFirstChild("FarmPlants") or Instance.new("Folder")
plantsFolder.Name = "FarmPlants"
plantsFolder.Parent = workspace

local farmZone = ZoneConfig.find("Farm")

local drawn = {} -- [index] = { model, kind = "stage" | "button", stage, conns }
local buyBusy = false
local buyBlockedUntil = 0
local claimDebounce = {}

local function isMine(hit)
	local character = player.Character

	return character ~= nil and hit:IsDescendantOf(character)
end

local function slotPart(index)
	return slotsFolder:FindFirstChild(tostring(index))
end

local function clear(index)
	local d = drawn[index]

	if not d then
		return
	end

	for _, c in ipairs(d.conns) do
		c:Disconnect()
	end

	if d.model then
		d.model:Destroy()
	end

	drawn[index] = nil
end

local function place(template, slot)
	local model = template:Clone()
	model:PivotTo(slot.CFrame * template:GetPivot())
	model.Parent = plantsFolder

	return model
end

-- little "grew!" pop on a model
local function pop(model, from)
	local ok = pcall(function()
		model:ScaleTo(from)
	end)

	if not ok then
		return
	end

	local value = Instance.new("NumberValue")
	value.Value = from

	value:GetPropertyChangedSignal("Value"):Connect(function()
		if model.Parent then
			pcall(model.ScaleTo, model, value.Value)
		end
	end)

	local tween = TweenService:Create(value, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 })
	tween.Completed:Connect(function()
		value:Destroy()
	end)
	tween:Play()
end

-- PLANTS ---------------------------------------------------------------------------
local function drawStage(index, stage)
	local slot = slotPart(index)
	local template = wheatModels:FindFirstChild(FarmConfig.StageModelNames[stage + 1] or "")

	if not (slot and template) then
		return
	end

	local previous = drawn[index]
	local grew = previous and previous.kind == "stage" and stage > (previous.stage or 0)

	clear(index)

	local model = place(template, slot)
	local d = { model = model, kind = "stage", stage = stage, conns = {} }
	drawn[index] = d

	if grew then
		pop(model, 0.85)
	end

	local hitbox = model:FindFirstChild("Hitbox")

	if hitbox and stage >= FarmConfig.MaxStage then
		table.insert(d.conns, hitbox.Touched:Connect(function(hit)
			if not isMine(hit) then
				return
			end

			local now = os.clock()

			if claimDebounce[index] and now - claimDebounce[index] < 0.5 then
				return
			end

			claimDebounce[index] = now
			claimRemote:FireServer(index)
		end))
	end
end

-- BUY BUTTON -----------------------------------------------------------------------
local function paintPriceTag(d)
	local slot = FarmConfig.Slots[d.index]
	local tag = d.tag

	if not (slot and tag) then
		return
	end

	local affordable = (slot.Price or 0) <= (player:GetAttribute("Gold") or 0)
	local design = tag:FindFirstChild("Design", true)

	if design then
		for _, child in ipairs(design:GetChildren()) do
			if child.Name:sub(-2) == "On" then
				child.Enabled = affordable
			elseif child.Name:sub(-3) == "Off" then
				child.Enabled = not affordable
			end
		end
	end
end

local function pressButton(button, restCF)
	TweenService:Create(button, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { CFrame = restCF * CFrame.new(0, -0.3, 0) }):Play()

	task.delay(0.12, function()
		if button.Parent then
			TweenService:Create(button, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = restCF }):Play()
		end
	end)
end

local function drawButton(index)
	local slot = slotPart(index)
	local def = FarmConfig.Slots[index]

	if not (slot and def) then
		return
	end

	clear(index)

	local model = place(buttonTemplate, slot)
	local button = model:WaitForChild("Button")
	local restCF = button.CFrame
	local d = { model = model, kind = "button", index = index, conns = {} }
	drawn[index] = d

	local tag = button:FindFirstChild("PriceTag")

	if tag then
		d.tag = tag
		tag.Adornee = button

		local nameLabel = tag:FindFirstChild("NameLabel", true)
		local priceLabel = tag:FindFirstChild("PriceLabel", true)

		if nameLabel then
			nameLabel.Text = def.Name
		end

		if priceLabel then
			priceLabel.Text = (def.Price or 0) <= 0 and "FREE" or NumberFormat.abbreviate(def.Price)
		end

		paintPriceTag(d)
	end

	pop(model, 0.6)

	table.insert(d.conns, button.Touched:Connect(function(hit)
		if not isMine(hit) or buyBusy or os.clock() < buyBlockedUntil then
			return
		end

		buyBusy = true
		pressButton(button, restCF)

		local ok, result = pcall(function()
			return buyRemote:InvokeServer()
		end)

		if not (ok and type(result) == "table" and result.ok) then
			MessageToPlayer.show("PurchaseUnavailable")
			buyBlockedUntil = os.clock() + 1.5 -- don't spam the message while standing on it
		end

		task.wait(0.3)
		buyBusy = false
	end))
end

-- DRAW EVERYTHING ------------------------------------------------------------------
local function render()
	local open = ZoneConfig.isRevealed(player, farmZone)
	local owned = open and FarmConfig.owned(player) or 0

	for index = 1, #FarmConfig.Slots do
		local d = drawn[index]

		if open and index <= owned then
			local stage = player:GetAttribute(FarmConfig.stageAttribute(index)) or 0

			if not d or d.kind ~= "stage" or d.stage ~= stage then
				drawStage(index, stage)
			end
		elseif open and index == owned + 1 then
			if not d or d.kind ~= "button" then
				drawButton(index)
			end
		elseif d then
			clear(index)
		end
	end
end

local function repaintTags()
	for _, d in pairs(drawn) do
		if d.kind == "button" then
			paintPriceTag(d)
		end
	end
end

-- "+X" orb when you earn Wheat (at the plot) or Gold (at the Sell Wheat board)
local sellBoard = workspace:WaitForChild("OtherBoards"):WaitForChild("SellWheat")
local goldIcon = "rbxassetid://130575145070200"

task.spawn(function()
	local sellBoardPart = sellBoard:WaitForChild("SurfaceGuiPart", math.huge)
	local conversion = sellBoardPart:FindFirstChild("Conversion", true)
	local gl = conversion and conversion:FindFirstChild("GoldLabel")

	if gl then
		-- the icon right after the Gold number
		for _, child in ipairs(conversion:GetChildren()) do
			if child:IsA("ImageLabel") and child.LayoutOrder >= gl.LayoutOrder and child.Image ~= FarmConfig.WheatIcon then
				goldIcon = child.Image
			end
		end
	end
end)

local function orb(position, amount, icon, color)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position + Vector3.new(math.random(-8, 8) / 10, 0, math.random(-8, 8) / 10)
	anchor.Parent = plantsFolder

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(4, 1.3)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Adornee = anchor
	gui.Parent = anchor

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = "+" .. NumberFormat.abbreviate(amount)
	label.LayoutOrder = 1
	label.Parent = holder

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(40, 25, 5)
	stroke.Parent = label

	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = icon
	image.Size = UDim2.fromScale(1, 1)
	image.SizeConstraint = Enum.SizeConstraint.RelativeYY
	image.LayoutOrder = 2
	image.Parent = holder

	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = holder

	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 6.5, 0) }):Play()

	task.delay(0.8, function()
		local fade = TweenInfo.new(0.4)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		TweenService:Create(image, fade, { ImageTransparency = 1 }):Play()
	end)

	task.delay(1.3, function()
		anchor:Destroy()
	end)
end

rewardRemote.OnClientEvent:Connect(function(kind, amount, index)
	if kind == "Wheat" then
		local slot = slotPart(index)

		if slot then
			orb(slot.Position, amount, FarmConfig.WheatIcon, Color3.fromRGB(255, 226, 120))
		end
	elseif kind == "Gold" then
		local sellBoardPart = sellBoard:FindFirstChild("SurfaceGuiPart")

		if sellBoardPart then
			orb(sellBoardPart.Position, amount, goldIcon, Color3.fromRGB(255, 205, 60))
		end
	end
end)

-- WATCH ----------------------------------------------------------------------------
player:GetAttributeChangedSignal("FarmSlots"):Connect(render)
player:GetAttributeChangedSignal(ZoneConfig.flagAttribute(farmZone)):Connect(render)
player:GetAttributeChangedSignal("Gold"):Connect(repaintTags)

for index = 1, #FarmConfig.Slots do
	player:GetAttributeChangedSignal(FarmConfig.stageAttribute(index)):Connect(render)
end

slotsFolder.ChildAdded:Connect(function()
	task.defer(render)
end)

render()
