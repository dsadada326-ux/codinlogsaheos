-- Sell NPC: talk to him (prompt Opens = "Sell") and pick an answer on the right.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local FishingConfig = require(ReplicatedStorage:WaitForChild("FishingConfig"))
local FishingVisuals = require(ReplicatedStorage:WaitForChild("FishingVisuals"))
local Kit = require(ReplicatedStorage:WaitForChild("FishingUIKit"))
local abbreviate = require(ReplicatedStorage:WaitForChild("NumberFormat")).abbreviate
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local sellRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SellFish")

local ICON = FishingVisuals.Icons.FishMeal

------------------------------------------------------------------------------------------
-- speech bubble over the NPC
------------------------------------------------------------------------------------------
local bubble = Kit.new("BillboardGui", {
	Name = "SellSpeech", Size = UDim2.fromOffset(300, 90), StudsOffset = Vector3.new(0, 3.2, 0),
	AlwaysOnTop = true, Enabled = false, MaxDistance = 60, ResetOnSpawn = false,
}, player:WaitForChild("PlayerGui"))
local bubbleFrame = Kit.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.85), Size = UDim2.fromScale(1, 0.85),
	BackgroundColor3 = Color3.new(1, 1, 1),
}, bubble)
Kit.corner(bubbleFrame, 0.3)
Kit.stroke(bubbleFrame, 3, Kit.Ink, true)
local tail = Kit.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(18, 18), Rotation = 45,
	BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 0,
}, bubbleFrame)
Kit.stroke(tail, 3, Kit.Ink, true)
local bubbleText = Kit.new("TextLabel", {
	BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), FontFace = Kit.Font, TextScaled = true, Text = "",
	TextColor3 = Kit.Ink, ZIndex = 2,
}, bubbleFrame)
Kit.new("UIPadding", { PaddingLeft = UDim.new(0.06, 0), PaddingRight = UDim.new(0.06, 0), PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.14, 0) }, bubbleText)
local bubbleScale = Kit.new("UIScale", {}, bubbleFrame)

local sayToken = 0
local function say(text)
	sayToken += 1
	local token = sayToken
	bubble.Enabled = true
	bubbleScale.Scale = 0.6
	TweenService:Create(bubbleScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	bubbleText.Text = text
	bubbleText.MaxVisibleGraphemes = 0
	task.spawn(function()
		for i = 1, #text do
			if token ~= sayToken then return end
			bubbleText.MaxVisibleGraphemes = i
			task.wait(0.022)
		end
		bubbleText.MaxVisibleGraphemes = -1
	end)
end

------------------------------------------------------------------------------------------
-- answer buttons on the right side of the screen
------------------------------------------------------------------------------------------
local gui = Kit.new("ScreenGui", { Name = "SellDialog", ResetOnSpawn = false, DisplayOrder = 19, Enabled = false }, player.PlayerGui)
local options = Kit.new("Frame", {
	Name = "Options", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -24, 0.5, 0), Size = UDim2.fromScale(0.27, 0.46),
	BackgroundTransparency = 1,
}, gui)
Kit.new("UISizeConstraint", { MinSize = Vector2.new(240, 220), MaxSize = Vector2.new(420, 380) }, options)
Kit.new("UIListLayout", { Padding = UDim.new(0.04, 0), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }, options)

local function option(order, style, text)
	local b, paint, label = Kit.button(options, { Name = "Option" .. order, Size = UDim2.fromScale(1, 0.22), LayoutOrder = order }, text)
	paint(style)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.fromScale(0.72, 0.62)
	label.Position = UDim2.fromScale(0.44, 0.5)
	local number = Kit.new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.03, 0.5), Size = UDim2.fromScale(0.1, 0.7),
		FontFace = Kit.Font, TextScaled = true, Text = tostring(order) .. ".", TextColor3 = Color3.new(1, 1, 1),
	}, b)
	Kit.stroke(number, 2.5)
	-- price chip on the right
	local chip = Kit.new("Frame", {
		Name = "Chip", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromScale(0.3, 0.66),
		BackgroundColor3 = Color3.fromRGB(15, 25, 40), BackgroundTransparency = 0.35, Visible = false,
	}, b)
	Kit.corner(chip, 0.35)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder,
	}, chip)
	local chipText = Kit.text(chip, { Text = "", Size = UDim2.fromScale(0, 0.8), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Max = 22 })
	local chipIcon = Kit.image(chip, { Image = ICON, Size = UDim2.fromScale(0.8, 0.8), SizeConstraint = Enum.SizeConstraint.RelativeYY, LayoutOrder = 2 })
	return { button = b, paint = paint, label = label, chip = chip, chipText = chipText, chipIcon = chipIcon, style = style }
end

local handOpt = option(1, "blue", "Sell Item In Hand?")
local allOpt = option(2, "green", "Sell All?")
local doubleOpt = option(3, "gold", "Sell All [2x]")
local leaveOpt = option(4, "red", "Nevermind")
doubleOpt.chip.Visible = true
doubleOpt.chipText.Text = "R$"
doubleOpt.chipIcon.Visible = false

------------------------------------------------------------------------------------------
-- state
------------------------------------------------------------------------------------------
local open = false
local npcPosition
local quote = { all = 0, count = 0, held = 0 }

local function refresh()
	local ok, q = pcall(function() return sellRemote:InvokeServer("quote") end)
	if not ok or not q or not q.ok then return end
	quote = q
	handOpt.chip.Visible = q.held > 0
	handOpt.chipText.Text = abbreviate(q.held)
	handOpt.paint(q.held > 0 and "blue" or "grey")
	handOpt.label.Text = q.held > 0 and "Sell Item In Hand?" or "Sell Item In Hand?"
	allOpt.chip.Visible = q.count > 0
	allOpt.chipText.Text = abbreviate(q.all)
	allOpt.label.Text = q.count > 0 and ("Sell All? (" .. q.count .. ")") or "Sell All?"
	allOpt.paint(q.count > 0 and "green" or "grey")
	doubleOpt.paint(q.count > 0 and "gold" or "grey")
end

local function close()
	if not open then return end
	open = false
	sayToken += 1
	gui.Enabled = false
	task.delay(1.2, function()
		if not open then bubble.Enabled = false end
	end)
end

local function openDialog(prompt)
	local stand = prompt.Parent and prompt.Parent.Parent
	local rig = stand and stand:FindFirstChild("Rig")
	bubble.Adornee = rig and rig:FindFirstChild("Head") or prompt.Parent
	npcPosition = prompt.Parent.Position
	open = true
	gui.Enabled = true
	for i, opt in ipairs({ handOpt, allOpt, doubleOpt, leaveOpt }) do
		local s = opt.button:FindFirstChild("Slide") or Kit.new("UIScale", { Name = "Slide" }, opt.button)
		s.Scale = 0
		task.delay(0.05 * i, function()
			TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
	end
	say("Hello! Got junk for me?")
	refresh()
	if quote.count == 0 then
		say("Hello! ...your bucket's empty. Go catch something!")
	end
end

local function thanks(amount, count)
	local lines = {
		"Pleasure doing business!",
		"Now THAT'S a haul!",
		"Smells fishy... I love it!",
		"Come back with more!",
	}
	say(lines[math.random(#lines)] .. "\n+" .. abbreviate(amount) .. " Fish Meal")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		FishingVisuals.popup(root.Position + Vector3.new(0, 3, 0), "+" .. abbreviate(amount), Color3.fromRGB(255, 225, 120), ICON, count >= 10)
	end
end

local busy = false
local function sell(mode)
	if busy then return end
	busy = true
	local ok, result = pcall(function() return sellRemote:InvokeServer(mode) end)
	busy = false
	if ok and result and result.ok then
		thanks(result.amount, result.count)
	elseif ok and result and result.reason == "nothing" then
		if mode == "hand" then
			MessageToPlayer.show("HoldAFish")
			say("You're not holding a fish, pal!")
		else
			MessageToPlayer.show("NoFishToSell")
			say("Your bucket's empty!")
		end
	end
	refresh()
end

handOpt.button.Activated:Connect(function() sell("hand") end)
allOpt.button.Activated:Connect(function() sell("all") end)
doubleOpt.button.Activated:Connect(function()
	if quote.count == 0 then
		MessageToPlayer.show("NoFishToSell")
		say("Nothing to double, friend!")
		return
	end
	if FishingConfig.SellDoubleProductId == 0 then
		say("The 2x deal isn't ready yet. Soon!")
		return
	end
	MarketplaceService:PromptProductPurchase(player, FishingConfig.SellDoubleProductId)
end)
leaveOpt.button.Activated:Connect(function()
	say("See ya!")
	close()
end)

-- the Robux sale comes back through FishingEvent
ReplicatedStorage.Remotes:WaitForChild("FishingEvent").OnClientEvent:Connect(function(kind, amount, count, doubled)
	if kind == "sold" and open then
		thanks(amount or 0, count or 0)
		refresh()
	end
end)

-- held fish changes -> new quote
local function watchCharacter(character)
	character.ChildAdded:Connect(function(c) if open and c:IsA("Tool") then refresh() end end)
	character.ChildRemoved:Connect(function(c) if open and c:IsA("Tool") then refresh() end end)
end
if player.Character then watchCharacter(player.Character) end
player.CharacterAdded:Connect(watchCharacter)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt:GetAttribute("Opens") ~= "Sell" then return end
	if open then close() else openDialog(prompt) end
end)

task.spawn(function()
	while true do
		task.wait(0.3)
		if open then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not root or not npcPosition or (root.Position - npcPosition).Magnitude > 22 then
				close()
			end
		end
	end
end)
