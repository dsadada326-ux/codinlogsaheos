-- Draws every ProximityPrompt with Style = Custom (the Fishing Frenzy stalls, auto-fisher
-- buttons ...). Dark rounded card, a key tile, a small ObjectText line and a big ActionText.
-- Tapping / clicking the card also triggers it (phones).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local INK = Color3.fromRGB(10, 18, 30)

local folder = Instance.new("Folder")
folder.Name = "CustomPrompts"
folder.Parent = playerGui

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end

local function keyText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		local s = UserInputService:GetStringForKeyCode(prompt.GamepadKeyCode)
		return (s ~= "" and s) or "X"
	end
	local s = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	if s == "" then s = prompt.KeyboardKeyCode.Name end
	return s
end

local function build(prompt, inputType)
	local gui = new("BillboardGui", {
		Name = "Prompt",
		Adornee = prompt.Parent,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(250, 78),
		StudsOffsetWorldSpace = Vector3.new(0, 0.5, 0),
		SizeOffset = Vector2.new(0, 0.5),
		Active = true,
		ResetOnSpawn = false,
		ClipsDescendants = false,
	}, folder)

	local card = new("TextButton", {
		Name = "Card", Text = "", AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(22, 30, 44), BackgroundTransparency = 0.12,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, card)
	new("UIStroke", { Thickness = 3, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 185, 210)), Rotation = 90,
	}, card)
	local scale = new("UIScale", { Scale = 0 }, card)

	local key = new("Frame", {
		Name = "Key", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, key)
	new("UIStroke", { Thickness = 3, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, key)
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 200, 215)), Rotation = 90 }, key)
	local keyLabel = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), FontFace = FONT, TextScaled = true,
		Text = keyText(prompt, inputType), TextColor3 = INK, ZIndex = 2,
	}, key)
	new("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0), PaddingLeft = UDim.new(0.12, 0), PaddingRight = UDim.new(0.12, 0) }, keyLabel)

	-- hold fill (only used when HoldDuration > 0)
	local fill = new("Frame", {
		Name = "Fill", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.fromRGB(120, 230, 255), BackgroundTransparency = 0.4,
	}, key)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, fill)

	local objectText = new("TextLabel", {
		Name = "Object", BackgroundTransparency = 1, Position = UDim2.fromOffset(78, 8), Size = UDim2.new(1, -88, 0, 22),
		FontFace = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
		Text = prompt.ObjectText, TextColor3 = Color3.fromRGB(175, 225, 255),
	}, card)
	new("UIStroke", { Thickness = 2, Color = INK }, objectText)

	local actionText = new("TextLabel", {
		Name = "Action", BackgroundTransparency = 1, Position = UDim2.fromOffset(78, 30), Size = UDim2.new(1, -88, 0, 38),
		FontFace = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
		Text = prompt.ActionText, TextColor3 = Color3.new(1, 1, 1),
	}, card)
	new("UIStroke", { Thickness = 3, Color = INK }, actionText)

	if prompt.ObjectText == "" then
		actionText.Position = UDim2.fromOffset(78, 18)
		actionText.Size = UDim2.new(1, -88, 0, 42)
	end

	-- click / tap the card
	local holding = false
	card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			holding = true
			prompt:InputHoldBegin()
		end
	end)
	card.InputEnded:Connect(function(input)
		if holding and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			holding = false
			prompt:InputHoldEnd()
		end
	end)

	local connections = {}
	local holdTween
	table.insert(connections, prompt.PromptButtonHoldBegan:Connect(function()
		if prompt.HoldDuration > 0 then
			fill.Size = UDim2.fromScale(1, 0)
			holdTween = TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
			holdTween:Play()
		end
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 0.92 }):Play()
	end))
	table.insert(connections, prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then holdTween:Cancel() end
		fill.Size = UDim2.fromScale(1, 0)
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end))
	table.insert(connections, prompt.Triggered:Connect(function()
		scale.Scale = 1.15
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		key.BackgroundColor3 = Color3.fromRGB(140, 255, 120)
		task.delay(0.25, function() key.BackgroundColor3 = Color3.new(1, 1, 1) end)
	end))
	table.insert(connections, prompt:GetPropertyChangedSignal("ActionText"):Connect(function() actionText.Text = prompt.ActionText end))
	table.insert(connections, prompt:GetPropertyChangedSignal("ObjectText"):Connect(function() objectText.Text = prompt.ObjectText end))

	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	return function()
		for _, c in ipairs(connections) do c:Disconnect() end
		local t = TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
		t:Play()
		t.Completed:Connect(function() gui:Destroy() end)
	end
end

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
	local cleanup = build(prompt, inputType)
	prompt.PromptHidden:Wait()
	cleanup()
end)
