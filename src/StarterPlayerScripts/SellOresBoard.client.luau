-- The Sell Ores board on Island 2 (ported from the old game's SellOresBoardManager).
-- Shows your Ores and what they're worth in Gold; Sell turns them all into Gold.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local OreConfig = require(ReplicatedStorage:WaitForChild("OreConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local sellRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SellOres")

local board = workspace:WaitForChild("OtherBoards"):WaitForChild("SellOres")
local surfacePart = board:WaitForChild("SurfaceGuiPart", math.huge)
local holder = surfacePart:WaitForChild("SellOresBoardTemplate"):WaitForChild("Holder")
local buttons = holder:WaitForChild("Buttons")
local canSell = buttons:WaitForChild("CanSell")
local cantSell = buttons:WaitForChild("CantSell")
local conversion = holder:WaitForChild("Conversion")
local oresLabel = conversion:WaitForChild("OresLabel")
local goldLabel = conversion:WaitForChild("GoldLabel")

-- the Gold icon on this board (the image after the Gold number)
local goldIcon = "rbxassetid://130575145070200"

for _, child in ipairs(conversion:GetChildren()) do
	if child:IsA("ImageLabel") and child.Image ~= OreConfig.Icon then
		goldIcon = child.Image
	end
end

local busy = false

local function bounce(button, from)
	local scale = button:FindFirstChild("AffordPopScale")

	if not scale then
		return
	end

	scale.Scale = from
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function goldPopup(amount)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = surfacePart.Position
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 1.8)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = anchor
	gui.Parent = anchor

	local holderFrame = Instance.new("Frame")
	holderFrame.BackgroundTransparency = 1
	holderFrame.Size = UDim2.fromScale(1, 1)
	holderFrame.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holderFrame

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 205, 60)
	label.Text = "+" .. NumberFormat.abbreviate(amount)
	label.LayoutOrder = 1
	label.Parent = holderFrame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(40, 25, 5)
	stroke.Parent = label

	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = goldIcon
	image.Size = UDim2.fromScale(1, 1)
	image.SizeConstraint = Enum.SizeConstraint.RelativeYY
	image.LayoutOrder = 2
	image.Parent = holderFrame

	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = holderFrame

	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 7, 0) }):Play()

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

local function refresh()
	local ores = player:GetAttribute("Ores") or 0

	oresLabel.Text = NumberFormat.abbreviate(ores)
	goldLabel.Text = NumberFormat.abbreviate(math.floor(ores * OreConfig.goldRate(player)))

	local can = ores > 0
	canSell.Visible = can
	cantSell.Visible = not can
end

canSell.Activated:Connect(function()
	if busy then
		return
	end

	busy = true

	local ok, result = pcall(function()
		return sellRemote:InvokeServer()
	end)

	if ok and type(result) == "table" and result.ok then
		bounce(canSell, 1.18)
		goldPopup(result.gold)
	else
		bounce(canSell, 0.85)
		MessageToPlayer.show("NoOres")
	end

	refresh()
	task.wait(0.2)
	busy = false
end)

cantSell.Activated:Connect(function()
	bounce(cantSell, 0.85)
	MessageToPlayer.show("NoOres")
end)

player:GetAttributeChangedSignal("Ores"):Connect(refresh)

refresh()
