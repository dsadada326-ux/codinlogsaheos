-- Fills in the three beach boards on Fishing Frenzy: Fish Tier, Fish Prestige and Crab Conversion.
-- The SurfaceGuis live in PlayerGui (StarterGui.Fishing*Board) so they can be scrolled/clicked.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local FishingConfig = require(ReplicatedStorage:WaitForChild("FishingConfig"))
local FishingVisuals = require(ReplicatedStorage:WaitForChild("FishingVisuals"))
local abbreviate = require(ReplicatedStorage:WaitForChild("NumberFormat")).abbreviate
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local tierRemote = remotes:WaitForChild("FishTierUp")
local prestigeRemote = remotes:WaitForChild("FishPrestige")
local convertRemote = remotes:WaitForChild("ConvertCrabs")

local GREEN = ColorSequence.new(Color3.fromRGB(80, 225, 150), Color3.fromRGB(20, 150, 95))
local BLUE = ColorSequence.new(Color3.fromRGB(90, 200, 255), Color3.fromRGB(25, 115, 215))
local GREY = ColorSequence.new(Color3.fromRGB(150, 165, 185), Color3.fromRGB(85, 100, 125))
local PURPLE = ColorSequence.new(Color3.fromRGB(215, 140, 255), Color3.fromRGB(120, 55, 200))
local GOLD_BTN = ColorSequence.new(Color3.fromRGB(255, 245, 120), Color3.fromRGB(245, 180, 20))
local GREY_BTN = ColorSequence.new(Color3.fromRGB(200, 205, 215), Color3.fromRGB(120, 125, 140))
local RED_BTN = ColorSequence.new(Color3.fromRGB(255, 130, 120), Color3.fromRGB(215, 50, 50))

local function fmt(n)
	local s = string.format("%.2f", n)
	s = s:gsub("0+$", ""):gsub("%.$", "")
	return s
end

local function pop(obj, from)
	local s = obj:FindFirstChild("Pop") or Instance.new("UIScale")
	s.Name = "Pop"
	s.Parent = obj
	s.Scale = from
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- a list board: clears old rows and returns a function to (re)make them
local function makeRows(gui, count)
	local list = gui:WaitForChild("TierList")
	local template = list:WaitForChild("TierTemplate")
	template.Visible = false
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") and c ~= template then c:Destroy() end
	end
	local rows = {}
	for i = 1, count do
		local row = template:Clone()
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.Visible = true
		row.Parent = list
		rows[i] = row
	end
	return rows, list
end

local function paintRow(row, colors)
	local g = row:FindFirstChildOfClass("UIGradient")
	if g then g.Color = colors end
end

-- button that asks "Sure?" before doing something that resets progress
local function confirmButton(button, normalText, confirmText, action)
	local label = button:FindFirstChild("Label")
	local armed = false
	local busy = false
	local armToken = 0
	button.Activated:Connect(function()
		if busy then return end
		if not armed then
			armed = true
			armToken += 1
			local token = armToken
			if label then label.Text = confirmText end
			local g = button:FindFirstChildOfClass("UIGradient")
			if g then g.Color = RED_BTN end
			pop(button, 1.12)
			task.delay(3, function()
				if armed and token == armToken then
					armed = false
					if label then label.Text = normalText() end
					button:SetAttribute("Refresh", os.clock())
				end
			end)
			return
		end
		armed = false
		busy = true
		action()
		busy = false
		if label then label.Text = normalText() end
		button:SetAttribute("Refresh", os.clock())
	end)
	return function() return armed end
end

------------------------------------------------------------------------------------------
-- Fish Tier
------------------------------------------------------------------------------------------
task.spawn(function()
	local gui = playerGui:WaitForChild("FishingTierBoard")
	local rows = makeRows(gui, FishingConfig.MaxTier)
	local button = gui:WaitForChild("TierUpButton")
	local label = button:WaitForChild("Label")
	gui.Title.Text = "Fish Tier"
	gui.Subtitle.Text = "Resets Fish Meal, Rods, Auto-Fishers & your bucket for a permanent boost"

	local function buttonText()
		local t = FishingConfig.tier(player)
		if t >= FishingConfig.MaxTier then return "MAX TIER" end
		return "Tier Up"
	end

	local isArmed
	local function refresh()
		local t = FishingConfig.tier(player)
		local fishMeal = player:GetAttribute("FishMeal") or 0
		for i, row in ipairs(rows) do
			local def = FishingConfig.Tiers[i]
			row.TierName.Text = "Fish Tier " .. i
			local boost = "x" .. fmt(def.fishMeal) .. " Fish Meal"
			if def.unlock then boost ..= " + " .. def.unlock end
			if i == 1 then boost ..= " + Beach Runes" end
			row.Boost.Text = boost
			if i <= t then
				row.State.Text = "Achieved ✔"
				paintRow(row, GREEN)
			elseif i == t + 1 then
				row.State.Text = "Cost: " .. abbreviate(def.cost) .. " Fish Meal"
				paintRow(row, BLUE)
			else
				row.State.Text = "Locked"
				paintRow(row, GREY)
			end
		end
		if not (isArmed and isArmed()) then
			label.Text = buttonText()
			local nextTier = FishingConfig.Tiers[t + 1]
			local g = button:FindFirstChildOfClass("UIGradient")
			if g then g.Color = (nextTier and fishMeal >= nextTier.cost) and GOLD_BTN or GREY_BTN end
		end
	end

	isArmed = confirmButton(button, buttonText, "Sure? Resets Fish Meal!", function()
		local t = FishingConfig.tier(player)
		local nextTier = FishingConfig.Tiers[t + 1]
		if not nextTier then return end
		if (player:GetAttribute("FishMeal") or 0) < nextTier.cost then
			MessageToPlayer.show("NoFishMeal")
			return
		end
		local ok, result = pcall(function() return tierRemote:InvokeServer() end)
		if ok and result and result.ok then
			pop(rows[result.tier], 1.15)
		elseif ok and result and result.reason == "money" then
			MessageToPlayer.show("NoFishMeal")
		end
	end)

	-- first click on "Tier Up" when you can't afford it just tells you
	button:GetAttributeChangedSignal("Refresh"):Connect(refresh)
	player.AttributeChanged:Connect(function(attr)
		if attr == "FishTier" or attr == "FishMeal" then refresh() end
	end)
	refresh()
end)

------------------------------------------------------------------------------------------
-- Fish Prestige
------------------------------------------------------------------------------------------
task.spawn(function()
	local gui = playerGui:WaitForChild("FishingPrestigeBoard")
	local rows = makeRows(gui, FishingConfig.MaxPrestige)
	local button = gui:WaitForChild("TierUpButton")
	local label = button:WaitForChild("Label")
	gui.Title.Text = "Fish Prestige"
	gui.Subtitle.Text = "Needs Fish Tier " .. FishingConfig.MaxTier .. ". Resets Tiers, Shells, Shell Upgrades & Crabs (the Tree stays!)"

	local function buttonText()
		if FishingConfig.prestige(player) >= FishingConfig.MaxPrestige then return "MAX PRESTIGE" end
		return "Prestige"
	end

	local isArmed
	local function refresh()
		local p = FishingConfig.prestige(player)
		local t = FishingConfig.tier(player)
		for i, row in ipairs(rows) do
			local def = FishingConfig.Prestiges[i]
			row.TierName.Text = "Fish Prestige " .. i
			row.Boost.Text = "x" .. fmt(def.fishMeal) .. " Fish Meal  x" .. fmt(def.luck) .. " Luck  x" .. fmt(def.shells) .. " Shells"
			if i <= p then
				row.State.Text = "Achieved ✔"
				paintRow(row, GREEN)
			elseif i == p + 1 then
				row.State.Text = t >= FishingConfig.MaxTier and "Ready!" or ("Needs Fish Tier " .. FishingConfig.MaxTier .. " (" .. t .. "/" .. FishingConfig.MaxTier .. ")")
				paintRow(row, PURPLE)
			else
				row.State.Text = "Locked"
				paintRow(row, GREY)
			end
		end
		if not (isArmed and isArmed()) then
			label.Text = buttonText()
			local g = button:FindFirstChildOfClass("UIGradient")
			if g then g.Color = (p < FishingConfig.MaxPrestige and t >= FishingConfig.MaxTier) and GOLD_BTN or GREY_BTN end
		end
	end

	isArmed = confirmButton(button, buttonText, "Sure? Big reset!", function()
		if FishingConfig.prestige(player) >= FishingConfig.MaxPrestige then return end
		if FishingConfig.tier(player) < FishingConfig.MaxTier then
			MessageToPlayer.show("NeedTier")
			return
		end
		local ok, result = pcall(function() return prestigeRemote:InvokeServer() end)
		if ok and result and result.ok then
			pop(rows[result.prestige], 1.15)
		elseif ok and result and result.reason == "tier" then
			MessageToPlayer.show("NeedTier")
		end
	end)

	button:GetAttributeChangedSignal("Refresh"):Connect(refresh)
	player.AttributeChanged:Connect(function(attr)
		if attr == "FishTier" or attr == "FishPrestige" then refresh() end
	end)
	refresh()
end)

------------------------------------------------------------------------------------------
-- Crab Conversion (Tier 3+)
------------------------------------------------------------------------------------------
task.spawn(function()
	local gui = playerGui:WaitForChild("FishingConversionBoard")
	local list = gui:WaitForChild("TierList")
	list.Visible = false
	local button = gui:WaitForChild("TierUpButton")
	local label = button:WaitForChild("Label")
	gui.Title.Text = "Crab Conversion"
	gui.Subtitle.Text = "Turn Fish Meal into Crabs. Crabs buy the Fishing Upgrade Tree!"

	local old = gui:FindFirstChild("ConvertBody")
	if old then old:Destroy() end
	local bodyFrame = Instance.new("Frame")
	bodyFrame.Name = "ConvertBody"
	bodyFrame.AnchorPoint = Vector2.new(0.5, 0)
	bodyFrame.Position = list.Position
	bodyFrame.Size = list.Size
	bodyFrame.BackgroundTransparency = 1
	bodyFrame.Parent = gui

	local function card(y, h, colors)
		local f = Instance.new("Frame")
		f.Position = UDim2.fromScale(0, y)
		f.Size = UDim2.fromScale(1, h)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.Parent = bodyFrame
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0.2, 0) c.Parent = f
		local s = Instance.new("UIStroke") s.Thickness = 4 s.Color = Color3.fromRGB(12, 30, 55) s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = f
		local g = Instance.new("UIGradient") g.Color = colors g.Rotation = 90 g.Parent = f
		return f
	end
	local function text(parent, t, pos, size, color)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = pos
		l.Size = size
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.Text = t
		l.TextColor3 = color or Color3.new(1, 1, 1)
		l.Parent = parent
		local s = Instance.new("UIStroke") s.Thickness = 3 s.Color = Color3.fromRGB(12, 30, 55) s.Parent = l
		return l
	end
	local function icon(parent, image, pos, size)
		local i = Instance.new("ImageLabel")
		i.BackgroundTransparency = 1
		i.Image = image
		i.Position = pos
		i.Size = size
		i.ScaleType = Enum.ScaleType.Fit
		i.Parent = parent
		return i
	end

	-- rate: [fish meal icon] 1K  ->  [crab icon] 1
	local rate = card(0, 0.42, BLUE)
	icon(rate, FishingVisuals.Icons.FishMeal, UDim2.fromScale(0.06, 0.12), UDim2.fromScale(0.16, 0.76))
	local rateLeft = text(rate, abbreviate(FishingConfig.FishMealPerCrab), UDim2.fromScale(0.22, 0.2), UDim2.fromScale(0.22, 0.6))
	text(rate, "➜", UDim2.fromScale(0.44, 0.15), UDim2.fromScale(0.12, 0.7))
	local rateRight = text(rate, "1", UDim2.fromScale(0.56, 0.2), UDim2.fromScale(0.2, 0.6))
	icon(rate, FishingVisuals.Icons.Crabs, UDim2.fromScale(0.77, 0.12), UDim2.fromScale(0.16, 0.76))

	local get = card(0.5, 0.42, GREEN)
	local getTitle = text(get, "You'll get:", UDim2.fromScale(0.05, 0.08), UDim2.fromScale(0.9, 0.34))
	local getAmount = text(get, "0 Crabs", UDim2.fromScale(0.05, 0.42), UDim2.fromScale(0.9, 0.5), Color3.fromRGB(255, 235, 140))

	-- lock cover
	local lock = card(0, 0.92, GREY)
	lock.ZIndex = 5
	for _, d in ipairs(lock:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex = 5 end end
	local lockText = text(lock, "🔒 Unlocks at Fish Tier " .. FishingConfig.ConversionTier, UDim2.fromScale(0.05, 0.3), UDim2.fromScale(0.9, 0.4))
	lockText.ZIndex = 6

	local function refresh()
		local unlocked = FishingConfig.tier(player) >= FishingConfig.ConversionTier
		lock.Visible = not unlocked
		local fishMeal = player:GetAttribute("FishMeal") or 0
		local batches = math.floor(fishMeal / FishingConfig.FishMealPerCrab)
		local crabs = math.floor(batches * FishingConfig.crabMultiplier(player))
		local mult = FishingConfig.crabMultiplier(player)
		rateRight.Text = fmt(mult)
		getAmount.Text = abbreviate(crabs) .. " Crabs"
		getTitle.Text = "Converting " .. abbreviate(batches * FishingConfig.FishMealPerCrab) .. " Fish Meal gives:"
		label.Text = unlocked and "Convert" or "Locked"
		local g = button:FindFirstChildOfClass("UIGradient")
		if g then g.Color = (unlocked and crabs > 0) and GOLD_BTN or GREY_BTN end
	end

	local busy = false
	button.Activated:Connect(function()
		if busy then return end
		if FishingConfig.tier(player) < FishingConfig.ConversionTier then
			MessageToPlayer.show("NeedTier")
			return
		end
		busy = true
		local ok, result = pcall(function() return convertRemote:InvokeServer() end)
		busy = false
		if ok and result and result.ok then
			pop(get, 1.12)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				FishingVisuals.popup(root.Position + Vector3.new(0, 3, 0), "+" .. abbreviate(result.crabs), Color3.fromRGB(255, 130, 110), FishingVisuals.Icons.Crabs, true)
			end
		elseif ok and result and result.reason == "money" then
			MessageToPlayer.show("NoFishMeal")
		end
		refresh()
	end)

	player.AttributeChanged:Connect(function(attr)
		if attr == "FishTier" or attr == "FishMeal" or attr:sub(1, 12) == "FishUpgrade" or attr:find("Fish") then refresh() end
	end)
	refresh()
end)
