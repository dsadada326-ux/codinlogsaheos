local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

local IslandTwoConfig = require(ReplicatedStorage:WaitForChild("IslandTwoConfig"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local woodChop = remotes:WaitForChild("WoodChop")
local tierUpRemote = remotes:WaitForChild("TierUp")
local IslandTransition = require(game:GetService("ReplicatedStorage"):WaitForChild("IslandTransition"))

local island2 = workspace:WaitForChild("Islands"):WaitForChild("Island2")
local buttonModel = island2:WaitForChild("BlueButton"):WaitForChild("Button")
local buttonPart = buttonModel:WaitForChild("Button")
-- the Island 2 tree model is optional: without one, the Tree board (TreeUpgradeBoard) shows the HP
-- and the "+Wood" popup floats above the board instead
local startFolder = island2:WaitForChild("Zones"):WaitForChild("Island2Starter")
local tree = startFolder:FindFirstChild("Tree1")
local hasTree = tree ~= nil
if not hasTree then
	tree = Instance.new("Model") -- stand-in with no parts
end
local cursors = island2:WaitForChild("BlueButton"):FindFirstChild("ClickCursors")

local startZone = ZoneConfig.find("Island2Start")

local function settingOn(key)
	local value = player:GetAttribute(SettingsConfig.attributeOf(key))

	if value == nil then
		return SettingsConfig.Settings[key].Default
	end

	return value
end

local function uiFont()
	local ok, font = pcall(function()
		return player.PlayerGui.Currencies.MainCurrenciesFrame.CurrenciesFrame.Money.Value.FontFace
	end)

	return ok and font or Font.fromEnum(Enum.Font.FredokaOne)
end

local function makeLabel(parent, name, size, position, color, text)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size = size
	l.Position = position
	l.TextScaled = true
	l.FontFace = uiFont()
	l.TextColor3 = color
	l.Text = text or ""
	l.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(20, 20, 30)
	stroke.Parent = l

	return l
end

-- Island 2's click cursors aren't used yet: keep them hidden
if cursors then
	for _, d in ipairs(cursors:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		end
	end
end

------------------------------------------------------------------------------------------
-- the Blue Button's cooldown: the number shows "Ready!" or seconds left, the bar fills red
------------------------------------------------------------------------------------------
local layout = buttonModel:WaitForChild("Counter"):WaitForChild("SurfaceGui"):WaitForChild("Frame"):WaitForChild("ComboLayout")
local countLabel = layout:WaitForChild("TextLabel")
local shadow = layout:FindFirstChild("DropShadow")
local extras = layout:WaitForChild("ComboExtras")
local bar = extras:WaitForChild("ComboBar")
local fill = bar:FindFirstChild("Fill")

for _, name in ipairs({ "ComboTier", "ComboMultiplier", "ComboFire" }) do
	local x = extras:FindFirstChild(name)
	if x then x.Visible = false end
end

extras.Visible = true
if extras:IsA("CanvasGroup") then extras.GroupTransparency = 0 end

local READY_COLOR = Color3.fromRGB(120, 255, 140)
local COOL_COLOR = Color3.fromRGB(255, 70, 70)

local fillGradient = fill and fill:FindFirstChildOfClass("UIGradient")
if fillGradient then fillGradient.Enabled = false end

local function setCount(text, color)
	if countLabel.Text ~= text then
		countLabel.Text = text
		if shadow then shadow.Text = text end
	end

	countLabel.TextColor3 = color
end

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	local readyAt = player:GetAttribute("BlueReadyAt") or 0
	local left = readyAt - now
	local cooldown = IslandTwoConfig.cooldown(player)
	local growLeft = (player:GetAttribute("TreeRespawnAt") or 0) - now

	if growLeft > 0 then
		-- the tree is growing back: same countdown as the Tree board
		setCount("Growing " .. math.ceil(growLeft) .. "s", COOL_COLOR)

		if fill then
			fill.BackgroundColor3 = COOL_COLOR
			fill.Size = UDim2.fromScale(1, math.clamp(1 - growLeft / IslandTwoConfig.RespawnSeconds, 0, 1))
		end
	elseif left > 0.02 then
		setCount(string.format("%.1fs", left), COOL_COLOR)

		if fill then
			fill.BackgroundColor3 = COOL_COLOR
			fill.Size = UDim2.fromScale(1, math.clamp(1 - left / cooldown, 0, 1))
		end
	else
		setCount("Ready!", READY_COLOR)

		if fill then
			fill.BackgroundColor3 = READY_COLOR
			fill.Size = UDim2.fromScale(1, 1)
		end
	end
end)

-- press animation + click sound
local buttonHome = buttonPart.CFrame
local pressing = false

local function press()
	if pressing then
		return
	end

	pressing = true

	local down = TweenService:Create(buttonPart, TweenInfo.new(0.06, Enum.EasingStyle.Quad), { CFrame = buttonHome * CFrame.new(0, -0.5, 0) })
	down:Play()
	down.Completed:Wait()

	local up = TweenService:Create(buttonPart, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = buttonHome })
	up:Play()
	up.Completed:Wait()

	pressing = false
end

local clickSound = SoundService:FindFirstChild("ButtonValidClickSound")
local detector = buttonModel:WaitForChild("ClickPart"):WaitForChild("ClickDetector")

local localReadyAt = 0
local lastLocalSound = 0

local function playClickSound()
	if clickSound and settingOn("SFX") then
		clickSound:Stop()
		clickSound.TimePosition = 0
		clickSound:Play()
	end
end

detector.MouseClick:Connect(function()
	local now = workspace:GetServerTimeNow()

	if (player:GetAttribute("TreeRespawnAt") or 0) > now then
		MessageToPlayer.show("ButtonUnavailable")
		return -- the tree is growing back
	end

	if (player:GetAttribute("BlueReadyAt") or 0) > now then
		return -- cooling down
	end

	if now < localReadyAt then
		return -- clicked again before the server's cooldown came back
	end
	localReadyAt = now + math.max(IslandTwoConfig.cooldown(player) * 0.9, 0.1)

	lastLocalSound = os.clock()
	playClickSound()
end)

-- a hit the server counted always clicks, even if the check above guessed "not ready yet"
woodChop.OnClientEvent:Connect(function()
	if os.clock() - lastLocalSound > 0.25 then
		playClickSound()
	end
	lastLocalSound = 0
end)

------------------------------------------------------------------------------------------
-- the tree: name + HP bar above it, shakes when hit, falls when chopped, grows back
------------------------------------------------------------------------------------------
local treeParts = {}

for _, d in ipairs(tree:GetDescendants()) do
	if d:IsA("BasePart") then
		table.insert(treeParts, { inst = d, cframe = d.CFrame, canCollide = d.CanCollide })
	end
end

local treeCf, treeSize
if hasTree then
	treeCf, treeSize = tree:GetBoundingBox()
else
	local board = workspace:WaitForChild("TreeUpgradeBoard")
	treeCf, treeSize = board.CFrame, board.Size
end
local treeTop = treeCf.Position + Vector3.new(0, treeSize.Y / 2, 0)

local anchor = Instance.new("Part")
anchor.Name = "TreeUiAnchor"
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanQuery = false
anchor.CanTouch = false
anchor.Transparency = 1
anchor.Size = Vector3.new(0.2, 0.2, 0.2)
anchor.CFrame = CFrame.new(treeTop + Vector3.new(0, 3.5, 0))
anchor.Parent = workspace

local billboard = Instance.new("BillboardGui")
billboard.Name = "TreeHealth"
billboard.Size = UDim2.fromOffset(240, 78)
billboard.AlwaysOnTop = true
billboard.LightInfluence = 0
billboard.MaxDistance = 160
billboard.Adornee = anchor
billboard.Parent = anchor

local panel = Instance.new("Frame")
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
panel.BackgroundTransparency = 0.15
panel.Size = UDim2.fromScale(1, 1)
panel.Parent = billboard
Instance.new("UICorner", panel).CornerRadius = UDim.new(0.2, 0)
local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 3
panelStroke.Color = Color3.fromRGB(70, 140, 255)
panelStroke.Parent = panel

local title = makeLabel(panel, "Title", UDim2.fromScale(0.9, 0.38), UDim2.fromScale(0.5, 0.25), Color3.fromRGB(160, 220, 255), "Starter Tree")

local hpBack = Instance.new("Frame")
hpBack.AnchorPoint = Vector2.new(0.5, 0.5)
hpBack.Position = UDim2.fromScale(0.5, 0.7)
hpBack.Size = UDim2.fromScale(0.86, 0.34)
hpBack.BackgroundColor3 = Color3.fromRGB(40, 12, 12)
hpBack.Parent = panel
Instance.new("UICorner", hpBack).CornerRadius = UDim.new(0.5, 0)
local hpStroke = Instance.new("UIStroke")
hpStroke.Thickness = 2
hpStroke.Color = Color3.fromRGB(10, 10, 16)
hpStroke.Parent = hpBack

local hpFill = Instance.new("Frame")
hpFill.Size = UDim2.fromScale(1, 1)
hpFill.BackgroundColor3 = Color3.fromRGB(90, 230, 90)
hpFill.Parent = hpBack
Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0.5, 0)

local hpText = makeLabel(hpBack, "HP", UDim2.fromScale(0.95, 0.9), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1), "5 / 5 HP")
hpText.ZIndex = 3

local treeShown = nil
local treeDown = false

local function setTreeVisible(visible, animate)
	for _, p in ipairs(treeParts) do
		local part = p.inst
		part.CanCollide = visible and p.canCollide
		part.CanQuery = visible

		if animate then
			if visible then
				part.LocalTransparencyModifier = 1
				part.CFrame = p.cframe * CFrame.new(0, -4, 0)
				TweenService:Create(part, TweenInfo.new(0.5), { LocalTransparencyModifier = 0 }):Play()
				TweenService:Create(part, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = p.cframe }):Play()
			else
				-- fall over and sink, fading out
				local pivot = treeCf.Position - Vector3.new(0, treeSize.Y / 2, 0)
				local fallen = CFrame.new(pivot) * CFrame.Angles(0, 0, math.rad(80)) * CFrame.new(-pivot) * p.cframe
				TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = fallen * CFrame.new(0, -2, 0) }):Play()
				TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.25), { LocalTransparencyModifier = 1 }):Play()
			end
		else
			part.LocalTransparencyModifier = visible and 0 or 1
			part.CFrame = p.cframe
		end
	end
end

local function popup(text, color, position, big)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(position + Vector3.new((math.random() - 0.5) * 4, 0, (math.random() - 0.5) * 2))
	p.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(big and 220 or 120, big and 50 or 38)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = p
	gui.Parent = p

	local l = makeLabel(gui, "Text", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), color, text)

	TweenService:Create(gui, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { StudsOffsetWorldSpace = Vector3.new(0, 4, 0) }):Play()
	local fade = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5)
	TweenService:Create(l, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(l:FindFirstChildOfClass("UIStroke"), fade, { Transparency = 1 }):Play()
	Debris:AddItem(p, 1)
end

local function shake()
	if treeDown then
		return
	end

	for _, p in ipairs(treeParts) do
		local part = p.inst
		local offset = CFrame.new((math.random() - 0.5) * 0.5, 0, (math.random() - 0.5) * 0.5) * CFrame.Angles(0, 0, math.rad((math.random() - 0.5) * 6))
		part.CFrame = p.cframe * offset
		TweenService:Create(part, TweenInfo.new(0.25, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { CFrame = p.cframe }):Play()
	end
end

local function refreshTree(animate)
	local open = ZoneConfig.isRevealed(player, startZone)
	local respawnAt = player:GetAttribute("TreeRespawnAt") or 0
	local down = respawnAt > workspace:GetServerTimeNow()
	local tier = IslandTwoConfig.tier(player)

	title.Text = tier.name
	billboard.Enabled = open and hasTree

	local wantVisible = open and not down

	if treeShown ~= wantVisible then
		setTreeVisible(wantVisible, animate and treeShown ~= nil)
		treeShown = wantVisible
	end

	treeDown = down

	local hp = player:GetAttribute("TreeHP") or IslandTwoConfig.maxHP(player)
	local maxHp = player:GetAttribute("TreeMaxHP") or IslandTwoConfig.maxHP(player)
	local ratio = maxHp > 0 and math.clamp(hp / maxHp, 0, 1) or 0

	TweenService:Create(hpFill, TweenInfo.new(0.2), {
		Size = UDim2.fromScale(ratio, 1),
		BackgroundColor3 = Color3.fromRGB(230, 70, 60):Lerp(Color3.fromRGB(90, 230, 90), ratio),
	}):Play()
end

-- live text while the tree is down ("Growing back... 3s")
RunService.Heartbeat:Connect(function()
	local respawnAt = player:GetAttribute("TreeRespawnAt") or 0
	local left = respawnAt - workspace:GetServerTimeNow()

	if left > 0 then
		hpText.Text = string.format("Growing back... %ds", math.ceil(left))
	else
		local hp = player:GetAttribute("TreeHP") or 0
		local maxHp = player:GetAttribute("TreeMaxHP") or 0
		hpText.Text = NumberFormat.abbreviate(hp) .. " / " .. NumberFormat.abbreviate(maxHp) .. " HP"
	end
end)

woodChop.OnClientEvent:Connect(function(damage, hp, maxHp, wood)
	if hasTree then
		popup("-" .. NumberFormat.abbreviate(damage), Color3.fromRGB(255, 90, 80), treeTop, false)
	end

	if settingOn("VFX") then
		shake()
	end

	if wood then
		task.delay(0.15, function()
			popup("+" .. NumberFormat.amount(wood) .. " Wood", Color3.fromRGB(255, 190, 110), treeTop + Vector3.new(0, 2, 0), true)
		end)
	end
end)

for _, attribute in ipairs({ "TreeHP", "TreeMaxHP", "TreeRespawnAt", "TreeTier", "Island2Unlocked", ZoneConfig.flagAttribute(startZone) }) do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		refreshTree(true)
	end)
end

refreshTree(false)

------------------------------------------------------------------------------------------
-- the Tier board
------------------------------------------------------------------------------------------
local tiersModel = island2:WaitForChild("Tiers")
local tierGui = tiersModel:WaitForChild("Tier"):FindFirstChildOfClass("SurfaceGui")
local currentGui = tiersModel:WaitForChild("CurrentTier"):FindFirstChildOfClass("SurfaceGui")

local function find(root, name)
	return root and root:FindFirstChild(name, true)
end

local fromLabel, toLabel = find(tierGui, "From"), find(tierGui, "To")
local costLabel = find(tierGui, "CostVariable")
local buyLabel = find(tierGui, "BuyLabel")
local buyButton = find(tierGui, "BuyButton")

local function refreshTiers()
	local tier, index = IslandTwoConfig.tier(player)
	local nextTier = IslandTwoConfig.Tiers[index + 1]

	if fromLabel then fromLabel.Text = tier.name end

	if nextTier then
		if toLabel then toLabel.Text = nextTier.name end
		if costLabel then costLabel.Text = NumberFormat.abbreviate(nextTier.cost) end
		if buyLabel then buyLabel.Text = "Tier Up" end
	else
		if toLabel then toLabel.Text = "Max Tier" end
		if costLabel then costLabel.Text = "-" end
		if buyLabel then buyLabel.Text = "Maxed" end
	end

	-- reached tiers look like the Starter Tree card (green), later ones keep their own look
	if currentGui then
		for i, _ in ipairs(IslandTwoConfig.Tiers) do
			local card = currentGui:FindFirstChild("Tier" .. i, true)

			if card and card:IsA("GuiObject") then
				local stroke = card:FindFirstChildOfClass("UIStroke")

				if card:GetAttribute("OrigBg") == nil then
					card:SetAttribute("OrigBg", card.BackgroundColor3)
					if stroke then card:SetAttribute("OrigStroke", stroke.Color) end
				end

				local reached = i <= index
				card.BackgroundColor3 = reached and Color3.fromRGB(0, 140, 12) or card:GetAttribute("OrigBg")

				if stroke then
					stroke.Color = reached and Color3.fromRGB(1, 79, 0) or (card:GetAttribute("OrigStroke") or stroke.Color)
				end
			end
		end
	end

	-- "Current Tier: Starter Tree"
	if currentGui then
		for _, d in ipairs(currentGui:GetDescendants()) do
			if d:IsA("TextLabel") and d.Text:find("^Current Tier:") then
				d.Text = "Current Tier: " .. tier.name
			end
		end
	end

	if buyButton and buyButton:IsA("GuiObject") then
		local affordable = nextTier and (player:GetAttribute("Wood") or 0) >= nextTier.cost
		buyButton.BackgroundColor3 = affordable and Color3.fromRGB(90, 220, 90) or Color3.fromRGB(220, 70, 70)
	end
end

if buyButton and buyButton:IsA("GuiButton") then
	buyButton.Activated:Connect(function()
		local ok, result = pcall(function()
			return tierUpRemote:InvokeServer()
		end)

		if not (ok and type(result) == "table" and result.ok) then
			MessageToPlayer.show("PurchaseUnavailable")
		end
	end)
end

player:GetAttributeChangedSignal("TreeTier"):Connect(refreshTiers)
player:GetAttributeChangedSignal("Wood"):Connect(refreshTiers)
refreshTiers()

------------------------------------------------------------------------------------------
-- the Island 2 board on Island 1 ("Red Island -> Blue Island"): Unlock, then Travel
------------------------------------------------------------------------------------------
local levelUp = workspace:WaitForChild("OtherBoards"):WaitForChild("Island2LevelUp")
local lvGui = levelUp:FindFirstChild("SurfaceGuiPart") and levelUp.SurfaceGuiPart:FindFirstChildOfClass("SurfaceGui")
local lvCan = find(lvGui, "CanBuy")
local lvCant = find(lvGui, "CantBuy")
local lvCost = find(lvGui, "Cost")
local lvProgress = find(lvGui, "ProgressLabel")
local lvRequirement = find(lvGui, "RequirementLabel")

local function setButtonText(button, text)
	if not button then return end
	for _, d in ipairs(button:GetDescendants()) do
		if d:IsA("TextLabel") then d.Text = text end
	end
end

local function refreshLevelUp()
	local unlocked = player:GetAttribute("Island2Unlocked") == true
	local owned = 0

	for i = 1, 14 do
		if player:GetAttribute("Tree_Upgrade" .. i) == true then owned += 1 end
	end

	local can = unlocked or IslandTwoConfig.canUnlock(player)

	if lvCan then lvCan.Visible = can end
	if lvCant then lvCant.Visible = not can end
	setButtonText(lvCan, unlocked and "Travel" or "Unlock")
	setButtonText(lvCant, "Unlock")

	if lvCost then
		lvCost.Text = unlocked and "Unlocked!" or ("Prestige " .. IslandTwoConfig.UnlockPrestige)
	end

	if lvProgress then lvProgress.Text = owned .. " / 14" end
	if lvRequirement then lvRequirement.Text = "Upgrade Tree Nodes" end
end

if lvCan and lvCan:IsA("GuiButton") then
	lvCan.Activated:Connect(function()
		IslandTransition.travel("Island2")
	end)
end

for _, attribute in ipairs({ "Island2Unlocked", "Prestige" }) do
	player:GetAttributeChangedSignal(attribute):Connect(refreshLevelUp)
end

for i = 1, 14 do
	player:GetAttributeChangedSignal("Tree_Upgrade" .. i):Connect(refreshLevelUp)
end

refreshLevelUp()

------------------------------------------------------------------------------------------
-- the Travel button in the side menu (once Island 2 is unlocked)
------------------------------------------------------------------------------------------
local travelButton = player:WaitForChild("PlayerGui"):WaitForChild("Buttons"):WaitForChild("SideContainer"):WaitForChild("Travel", 10)

local function onIsland2()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	return root and (root.Position - buttonPart.Position).Magnitude < 250
end

local function refreshTravel()
	if not travelButton then return end
	travelButton.Visible = player:GetAttribute("Island2Unlocked") == true

	for _, d in ipairs(travelButton:GetDescendants()) do
		if d:IsA("TextLabel") then
			d.Text = onIsland2() and "Red Island" or "Blue Island"
		end
	end
end

if travelButton then
	travelButton.Activated:Connect(function()
		local target = onIsland2() and "Island1" or "Island2"

		IslandTransition.travel(target)

		task.wait(0.3)
		refreshTravel()
	end)

	player:GetAttributeChangedSignal("Island2Unlocked"):Connect(refreshTravel)

	task.spawn(function()
		while true do
			refreshTravel()
			task.wait(1)
		end
	end)
end
