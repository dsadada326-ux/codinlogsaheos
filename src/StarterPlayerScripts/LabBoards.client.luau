-- Fills in the two Laboratory boards at the far end of the Potion Stand path:
--   Lab Level          (StarterGui.LabLevelBoard): spend Chemicals, rebuild the lab stronger
--   Advancement Marks  (StarterGui.LabMarkBoard):  needs max Lab Level, a much bigger reset
-- Same look + flow as the Fish Tier / Fish Prestige boards. LabService checks the real rules.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local LabConfig = require(ReplicatedStorage:WaitForChild("LabConfig"))
local abbreviate = require(ReplicatedStorage:WaitForChild("NumberFormat")).abbreviate
local actionRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LabAction")

local GREEN = ColorSequence.new(Color3.fromRGB(90, 235, 150), Color3.fromRGB(20, 150, 90))
local TEAL = ColorSequence.new(Color3.fromRGB(90, 235, 215), Color3.fromRGB(20, 130, 150))
local GREY = ColorSequence.new(Color3.fromRGB(150, 160, 180), Color3.fromRGB(80, 90, 115))
local PURPLE = ColorSequence.new(Color3.fromRGB(215, 140, 255), Color3.fromRGB(120, 55, 200))
local GOLD_BTN = ColorSequence.new(Color3.fromRGB(255, 245, 120), Color3.fromRGB(245, 180, 20))
local GREY_BTN = ColorSequence.new(Color3.fromRGB(200, 205, 215), Color3.fromRGB(120, 125, 140))
local RED_BTN = ColorSequence.new(Color3.fromRGB(255, 130, 120), Color3.fromRGB(215, 50, 50))

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII" }

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

local function invoke(action)
	local ok, r = pcall(function() return actionRemote:InvokeServer(action) end)
	return ok and type(r) == "table" and r or { ok = false }
end

-- a little message over the board
local function flash(gui, text, color)
	local sub = gui:FindFirstChild("Subtitle")
	if not sub then return end
	local old, oldColor = sub.Text, sub.TextColor3
	sub.Text = text
	sub.TextColor3 = color
	pop(sub, 1.2)
	task.delay(2, function()
		if sub.Text == text then
			sub.Text = old
			sub.TextColor3 = oldColor
		end
	end)
end

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
	return rows
end

local function paintRow(row, colors)
	local g = row:FindFirstChildOfClass("UIGradient")
	if g then g.Color = colors end
end

-- asks "Sure?" before a reset
local function confirmButton(button, normalText, confirmText, action)
	local label = button:FindFirstChild("Label")
	local armed, busy, armToken = false, false, 0
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
-- Lab Level
------------------------------------------------------------------------------------------
task.spawn(function()
	local gui = playerGui:WaitForChild("LabLevelBoard")
	local rows = makeRows(gui, LabConfig.MaxLevel)
	local button = gui:WaitForChild("TierUpButton")
	local label = button:WaitForChild("Label")
	gui.Title.Text = "Lab Level"
	gui.Subtitle.Text = "Resets Chemicals, Oxygen, CO2 & your lab buildings. Knowledge + the Knowledge Shop stay!"

	local function buttonText()
		return LabConfig.labLevel(player) >= LabConfig.MaxLevel and "MAX LEVEL" or "Level Up"
	end

	local isArmed
	local function refresh()
		local lv = LabConfig.labLevel(player)
		local chem = player:GetAttribute("Chemicals") or 0
		for i, row in ipairs(rows) do
			local def = LabConfig.Levels[i]
			row.TierName.Text = "Lab Level " .. i
			local boost = "x" .. fmt(def.prod) .. " Production  x" .. fmt(def.luck) .. " Luck"
			if def.sell > 1 then boost ..= "  x" .. fmt(def.sell) .. " Knowledge" end
			if def.unlock then boost ..= "  + " .. def.unlock end
			row.Boost.Text = boost
			if i <= lv then
				row.State.Text = "Achieved ✔"
				paintRow(row, GREEN)
			elseif i == lv + 1 then
				row.State.Text = "Cost: " .. abbreviate(def.cost) .. " Chemicals"
				paintRow(row, TEAL)
			else
				row.State.Text = "Locked"
				paintRow(row, GREY)
			end
		end
		if not (isArmed and isArmed()) then
			label.Text = buttonText()
			local nextLevel = LabConfig.Levels[lv + 1]
			local g = button:FindFirstChildOfClass("UIGradient")
			if g then g.Color = (nextLevel and chem >= nextLevel.cost) and GOLD_BTN or GREY_BTN end
		end
	end

	isArmed = confirmButton(button, buttonText, "Sure? Resets your lab!", function()
		local lv = LabConfig.labLevel(player)
		local nextLevel = LabConfig.Levels[lv + 1]
		if not nextLevel then return end
		if (player:GetAttribute("Chemicals") or 0) < nextLevel.cost then
			flash(gui, "Need " .. abbreviate(nextLevel.cost) .. " Chemicals!", Color3.fromRGB(255, 120, 120))
			return
		end
		local r = invoke("levelUp")
		if r.ok then
			pop(rows[r.level], 1.15)
			flash(gui, "LAB LEVEL " .. r.level .. "!", Color3.fromRGB(140, 255, 170))
		elseif r.reason == "cost" then
			flash(gui, "Not enough Chemicals!", Color3.fromRGB(255, 120, 120))
		end
	end)

	button:GetAttributeChangedSignal("Refresh"):Connect(refresh)
	player.AttributeChanged:Connect(function(attr)
		if attr == "LabLevel" or attr == "Chemicals" then refresh() end
	end)
	refresh()
end)

------------------------------------------------------------------------------------------
-- Advancement Marks
------------------------------------------------------------------------------------------
task.spawn(function()
	local gui = playerGui:WaitForChild("LabMarkBoard")
	local rows = makeRows(gui, LabConfig.MaxMark)
	local button = gui:WaitForChild("TierUpButton")
	local label = button:WaitForChild("Label")
	gui.Title.Text = "Advancement Marks"
	gui.Subtitle.Text = "Needs Lab Level " .. LabConfig.MaxLevel .. ". Resets Lab Levels, Knowledge & the Knowledge Shop too!"

	local function buttonText()
		return LabConfig.labMark(player) >= LabConfig.MaxMark and "ALL MARKS" or "Advance"
	end

	local isArmed
	local function refresh()
		local m = LabConfig.labMark(player)
		local lv = LabConfig.labLevel(player)
		for i, row in ipairs(rows) do
			local def = LabConfig.Marks[i]
			row.TierName.Text = "Advancement Mark " .. (ROMAN[i] or i)
			local boost = "x" .. fmt(def.prod) .. " Production  x" .. fmt(def.knowledge) .. " Knowledge  x" .. fmt(def.luck) .. " Luck"
			if (def.bulk or 0) > 0 then boost ..= "  +" .. def.bulk .. " Potion" .. (def.bulk > 1 and "s" or "") end
			row.Boost.Text = boost
			if i <= m then
				row.State.Text = "Achieved ✔"
				paintRow(row, GREEN)
			elseif i == m + 1 then
				row.State.Text = lv >= LabConfig.MaxLevel and "Ready!" or ("Needs Lab Level " .. LabConfig.MaxLevel .. " (" .. lv .. "/" .. LabConfig.MaxLevel .. ")")
				paintRow(row, PURPLE)
			else
				row.State.Text = "Locked"
				paintRow(row, GREY)
			end
		end
		if not (isArmed and isArmed()) then
			label.Text = buttonText()
			local g = button:FindFirstChildOfClass("UIGradient")
			if g then g.Color = (m < LabConfig.MaxMark and lv >= LabConfig.MaxLevel) and GOLD_BTN or GREY_BTN end
		end
	end

	isArmed = confirmButton(button, buttonText, "Sure? Big reset!", function()
		if LabConfig.labMark(player) >= LabConfig.MaxMark then return end
		if LabConfig.labLevel(player) < LabConfig.MaxLevel then
			flash(gui, "Reach Lab Level " .. LabConfig.MaxLevel .. " first!", Color3.fromRGB(255, 120, 120))
			return
		end
		local r = invoke("advance")
		if r.ok then
			pop(rows[r.mark], 1.15)
			flash(gui, "ADVANCEMENT MARK " .. (ROMAN[r.mark] or r.mark) .. "!", Color3.fromRGB(230, 170, 255))
		end
	end)

	button:GetAttributeChangedSignal("Refresh"):Connect(refresh)
	player.AttributeChanged:Connect(function(attr)
		if attr == "LabLevel" or attr == "LabMark" then refresh() end
	end)
	refresh()
end)
