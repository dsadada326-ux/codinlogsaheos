-- DRILLING MANIA: the Furnace (Workspace.Furnace). Put in 25% / 50% / 100% of your Scrap,
-- watch it run down the track, then claim the Iron. The overhead sign shows the timer and
-- the cooldown (DrillConfig.Furnace.Cooldown).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local DrillConfig = require(ReplicatedStorage:WaitForChild("DrillConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local Multipliers = require(ReplicatedStorage:WaitForChild("Multipliers"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local MessageToPlayer = require(ReplicatedStorage:WaitForChild("MessageToPlayer"))
local Kit = require(ReplicatedStorage:WaitForChild("FishingUIKit"))

local actionRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DrillAction")

local F = DrillConfig.Furnace
local INK = Color3.fromRGB(12, 12, 18)
local GREEN = Color3.fromRGB(95, 235, 90)
local PIPE = Color3.fromRGB(58, 60, 72)
local ORANGE = Color3.fromRGB(255, 150, 40)

local furnace = workspace:WaitForChild("Furnace")
local machine = furnace:WaitForChild("Machine")

local function abbreviate(n)
	return NumberFormat.abbreviate(math.floor(n + 0.5))
end
local function commas(n)
	local s = tostring(math.floor(n))
	while true do
		local k
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return s
end
local function now()
	return workspace:GetServerTimeNow()
end
local function up(id)
	return UpgradeConfig.valueAt(id, player:GetAttribute(UpgradeConfig.levelAttribute(id)) or 0)
end

-- state: "idle" | "cooking" | "done" | "cooldown"
local function state()
	local t = now()
	if (player:GetAttribute("FurnaceScrap") or 0) > 0 then
		if t >= (player:GetAttribute("FurnaceEnd") or 0) then
			return "done", 1, 0
		end
		local s, e = player:GetAttribute("FurnaceStart") or 0, player:GetAttribute("FurnaceEnd") or 0
		return "cooking", math.clamp((t - s) / math.max(e - s, 0.01), 0, 1), e - t
	end
	local cd = (player:GetAttribute("FurnaceCooldown") or 0) - t
	if cd > 0 then
		return "cooldown", 0, cd
	end
	return "idle", 0, 0
end

local function timeText(s)
	s = math.max(0, math.ceil(s))
	if s >= 60 then
		return string.format("%dm %02ds", s // 60, s % 60)
	end
	return s .. "s"
end

------------------------------------------------------------------------------------------
-- window
------------------------------------------------------------------------------------------
local w = Kit.glass("FurnaceUI", "Furnace", { aspect = 1.08, tint = Color3.fromRGB(255, 225, 200) })
local body = w.body
w.panel:FindFirstChild("Title").TextColor3 = Color3.fromRGB(255, 200, 120)

local sub = Kit.text(w.panel, {
	Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.125), Size = UDim2.fromScale(0.8, 0.04),
	TextColor3 = Color3.fromRGB(255, 245, 230), Stroke = 2, Max = 22,
})

-- BIG SCRAP BAR --------------------------------------------------------------------------
local barBox = Kit.new("Frame", {
	Name = "ScrapBar", Position = UDim2.fromScale(0, 0.03), Size = UDim2.fromScale(1, 0.14), BackgroundColor3 = Color3.fromRGB(34, 36, 46),
}, body)
Kit.corner(barBox, 0.3)
Kit.stroke(barBox, 3.5, INK, true)
Kit.image(barBox, {
	Image = DrillConfig.Icons.Scrap, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromScale(1.5, 1.5),
	SizeConstraint = Enum.SizeConstraint.RelativeYY, ZIndex = 4,
})
local barTrack = Kit.new("Frame", {
	Position = UDim2.fromScale(0.07, 0.18), Size = UDim2.fromScale(0.9, 0.64), BackgroundColor3 = Color3.fromRGB(20, 21, 28), ClipsDescendants = true,
}, barBox)
Kit.corner(barTrack, 0.5)
local barFull = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(150, 155, 170), BackgroundTransparency = 0.55 }, barTrack)
Kit.corner(barFull, 0.5)
local barFill = Kit.new("Frame", { Size = UDim2.fromScale(0.25, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, barTrack)
Kit.corner(barFill, 0.5)
Kit.gradient(barFill, Color3.fromRGB(255, 205, 90), ORANGE)
for _, pct in ipairs({ 0.25, 0.5, 0.75 }) do
	Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(pct, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = INK,
		BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 3,
	}, barTrack)
end
local barText = Kit.text(barTrack, {
	Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.8), ZIndex = 4, Stroke = 2.5, Max = 30,
})

-- PERCENT CHIPS --------------------------------------------------------------------------
local CHIP_X = { 0.17, 0.5, 0.83 }
local chips = {}
local selected = 100

for i, pct in ipairs(F.Percents) do
	local b, paint, label = Kit.button(body, {
		Name = "Chip" .. pct, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(CHIP_X[i], 0.22),
		Size = UDim2.fromScale(0.25, 0.13),
	}, pct .. "%")
	label.Position = UDim2.fromScale(0.5, 0.38)
	label.Size = UDim2.fromScale(0.8, 0.55)
	local small = Kit.text(b, {
		Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromScale(0.85, 0.26), Stroke = 1.5, Max = 16,
	})
	chips[i] = { button = b, paint = paint, small = small, pct = pct }
end

-- THE TRACK (pipes from each chip, merging into the middle, down to the Iron box) ----------
local function pipe(pos, size, vertical)
	local f = Kit.new("Frame", { Position = pos, Size = size, BackgroundColor3 = PIPE, ClipsDescendants = true, ZIndex = 2 }, body)
	Kit.corner(f, 0.5)
	Kit.stroke(f, 3, INK, true)
	local fill = Kit.new("Frame", {
		Size = vertical and UDim2.fromScale(1, 0) or UDim2.fromScale(0, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0, ZIndex = 3,
	}, f)
	Kit.corner(fill, 0.5)
	Kit.gradient(fill, Color3.fromRGB(170, 255, 140), Color3.fromRGB(40, 185, 60), vertical and 0 or 90)
	return { frame = f, fill = fill, vertical = vertical }
end

local PW = 0.035 -- pipe thickness (of the body width)
local stubs, joins = {}, {}
for i, x in ipairs(CHIP_X) do
	stubs[i] = pipe(UDim2.fromScale(x - PW / 2, 0.35), UDim2.fromScale(PW, 0.1), true)
end
-- horizontal joins toward the middle (left and right chips)
joins[1] = pipe(UDim2.fromScale(CHIP_X[1] - PW / 2, 0.43), UDim2.fromScale(0.5 - CHIP_X[1] + PW / 2, 0.035), false)
joins[3] = pipe(UDim2.fromScale(0.5 - PW / 2, 0.43), UDim2.fromScale(CHIP_X[3] - 0.5 + PW / 2, 0.035), false)
joins[3].fill.AnchorPoint = Vector2.new(1, 0)
joins[3].fill.Position = UDim2.fromScale(1, 0)
local trunk = pipe(UDim2.fromScale(0.5 - PW / 2, 0.45), UDim2.fromScale(PW, 0.14), true)

-- IRON RESULT BOX -----------------------------------------------------------------------
local result = Kit.new("Frame", {
	Name = "Result", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.585), Size = UDim2.fromScale(0.36, 0.25),
	BackgroundColor3 = Color3.fromRGB(45, 55, 75), ZIndex = 4,
}, body)
Kit.corner(result, 0.18)
local resultStroke = Kit.stroke(result, 4, INK, true)
Kit.gradient(result, Color3.fromRGB(120, 150, 200), Color3.fromRGB(40, 55, 90))
Kit.sunburst(result, Color3.fromRGB(200, 225, 255))
local ironIcon = Kit.image(result, {
	Image = DrillConfig.Icons.Iron, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.62, 0.62),
	SizeConstraint = Enum.SizeConstraint.RelativeYY, ZIndex = 5,
})
local iconScale = Kit.new("UIScale", {}, ironIcon)
local ironAmount = Kit.text(result, {
	Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.97), Size = UDim2.fromScale(0.9, 0.26), ZIndex = 6, Stroke = 2.5,
})
local progressText = Kit.text(result, {
	Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.97, 0.03), Size = UDim2.fromScale(0.5, 0.2), ZIndex = 6, Stroke = 2,
	TextColor3 = Color3.fromRGB(170, 255, 150), TextXAlignment = Enum.TextXAlignment.Right,
})

-- ACTION BUTTON -------------------------------------------------------------------------
local action, paintAction, actionLabel = Kit.button(body, {
	Name = "Action", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.5, 0.12),
}, "SMELT")

------------------------------------------------------------------------------------------
-- painting
------------------------------------------------------------------------------------------
local function preview(pct)
	local scrap = math.floor((player:GetAttribute("Scrap") or 0) * pct / 100)
	local iron = scrap >= F.MinScrap and math.max(1, math.floor(scrap / F.ScrapPerIron * Multipliers.iron(player))) or 0
	return scrap, iron, DrillConfig.furnaceSeconds(scrap, up("FurnaceSpeed"))
end

local function setPipe(p, k)
	k = math.clamp(k, 0, 1)
	p.fill.Size = p.vertical and UDim2.fromScale(1, k) or UDim2.fromScale(k, 1)
end

local lastState
local function paint()
	local st, progress, left = state()
	local scrap = player:GetAttribute("Scrap") or 0
	local chipIndex = table.find(F.Percents, selected) or 3

	sub.Text = F.ScrapPerIron .. " Scrap = " .. string.format("%.2f", Multipliers.iron(player)):gsub("%.?0+$", "") .. " Iron  -  Cooldown " .. F.Cooldown .. "s"

	-- the big bar
	if st == "idle" or st == "cooldown" then
		local s = preview(selected)
		barFill.Size = UDim2.fromScale(selected / 100, 1)
		barText.Text = commas(scrap) .. " Scrap   (" .. selected .. "% = " .. commas(s) .. ")"
	else
		local inside = player:GetAttribute("FurnaceScrap") or 0
		barFill.Size = UDim2.fromScale(1 - progress, 1)
		barText.Text = "Melting " .. commas(inside) .. " Scrap..."
	end

	-- chips
	for i, c in ipairs(chips) do
		local s = preview(c.pct)
		c.small.Text = abbreviate(s) .. " Scrap"
		local busy = st == "cooking" or st == "done"
		if busy then
			c.paint(i == chipIndex and "green" or "grey")
		else
			c.paint(i == chipIndex and "gold" or (s >= F.MinScrap and "blue" or "grey"))
		end
	end

	-- the track: selected stub -> join -> trunk, filling green with progress
	local k = (st == "cooking") and progress or (st == "done" and 1 or 0)
	for i = 1, 3 do
		stubs[i].frame.BackgroundColor3 = (i == chipIndex) and Color3.fromRGB(80, 84, 100) or PIPE
		setPipe(stubs[i], i == chipIndex and k / 0.25 or 0)
	end
	for i, j in pairs(joins) do
		setPipe(j, i == chipIndex and (k - 0.25) / 0.25 or 0)
	end
	local trunkStart = chipIndex == 2 and 0.25 or 0.5
	setPipe(trunk, (k - trunkStart) / (1 - trunkStart))

	-- result box
	if st == "idle" or st == "cooldown" then
		local s, iron, secs = preview(selected)
		ironAmount.Text = iron > 0 and ("+" .. abbreviate(iron) .. " Iron") or "Need " .. F.MinScrap .. " Scrap"
		progressText.Text = iron > 0 and timeText(secs) or ""
		ironIcon.ImageTransparency = iron > 0 and 0.35 or 0.7
		resultStroke.Color = INK
	else
		ironAmount.Text = "+" .. abbreviate(player:GetAttribute("FurnaceIron") or 0) .. " Iron"
		progressText.Text = st == "done" and "100%" or math.floor(progress * 100) .. "%"
		ironIcon.ImageTransparency = st == "done" and 0 or (0.5 - progress * 0.4)
		resultStroke.Color = st == "done" and Color3.fromRGB(255, 220, 80) or INK
	end

	-- button
	if st == "idle" then
		local s = preview(selected)
		paintAction(s >= F.MinScrap and "green" or "grey")
		actionLabel.Text = "SMELT " .. selected .. "%"
	elseif st == "cooking" then
		paintAction("grey")
		actionLabel.Text = "Smelting... " .. timeText(left)
	elseif st == "done" then
		paintAction("gold")
		actionLabel.Text = "CLAIM IRON!"
	else
		paintAction("red")
		actionLabel.Text = "Cooling down " .. timeText(left)
	end

	if st ~= lastState then
		if st == "done" then
			Kit.pop(result, 1.25)
		end
		lastState = st
	end
end

for i, c in ipairs(chips) do
	c.button.Activated:Connect(function()
		local st = state()
		if st == "cooking" or st == "done" then return end
		selected = c.pct
		Kit.pop(c.button, 0.85)
		paint()
	end)
end

-- iron icon wiggles when ready
task.spawn(function()
	while true do
		if w.isOpen() and lastState == "done" then
			TweenService:Create(iconScale, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { Scale = 1.12 }):Play()
			task.wait(0.35)
			TweenService:Create(iconScale, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { Scale = 1 }):Play()
			task.wait(0.35)
		else
			iconScale.Scale = 1
			task.wait(0.2)
		end
	end
end)

------------------------------------------------------------------------------------------
-- effects on the machine (only on your screen)
------------------------------------------------------------------------------------------
local emitFuse = furnace:FindFirstChild("EmitFuse")
local function smoke(on)
	if not emitFuse then return end
	local linger = emitFuse:FindFirstChild("lingervfx")
	if linger then
		for _, e in ipairs(linger:GetDescendants()) do
			if e:IsA("ParticleEmitter") then e.Enabled = on end
		end
	end
end
local function burst()
	if not emitFuse then return end
	for _, e in ipairs(emitFuse:GetDescendants()) do
		if e:IsA("ParticleEmitter") and e.Parent:IsA("Attachment") then
			e:Emit(25)
		end
	end
end

local busy = false
action.Activated:Connect(function()
	if busy then return end
	local st = state()
	if st == "idle" then
		busy = true
		local ok, r = pcall(function() return actionRemote:InvokeServer("furnaceStart", selected) end)
		if ok and type(r) == "table" and r.ok then
			Kit.pop(barBox, 0.92)
			burst()
		else
			Kit.pop(action, 0.85)
			MessageToPlayer.show("PurchaseUnavailable")
		end
		busy = false
	elseif st == "done" then
		busy = true
		local ok, r = pcall(function() return actionRemote:InvokeServer("furnaceClaim") end)
		if ok and type(r) == "table" and r.ok then
			Kit.pop(result, 1.3)
			burst()
		else
			Kit.pop(action, 0.85)
		end
		busy = false
	else
		Kit.pop(action, 0.9)
	end
	paint()
end)

------------------------------------------------------------------------------------------
-- the prompt on the machine + the overhead sign
------------------------------------------------------------------------------------------
local prompt = machine:FindFirstChildWhichIsA("ProximityPrompt", true)
if not prompt then
	local att = machine:FindFirstChildOfClass("Attachment") or Instance.new("Attachment", machine)
	prompt = Instance.new("ProximityPrompt")
	prompt.Parent = att
end
prompt.ActionText = "Open"
prompt.ObjectText = "Furnace"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false
prompt.Style = Enum.ProximityPromptStyle.Custom
prompt.Triggered:Connect(function(who)
	if who == player then
		if w.isOpen() then w.hide() else w.open() end
	end
end)
Kit.closeWhenFar(w, function() return machine.Position end, 22)
w.onOpen = paint

local overhead = furnace:WaitForChild("Overhead"):WaitForChild("BillboardGui")
local countdown = overhead:WaitForChild("Countdown")
local progressBar = overhead:FindFirstChild("Progress")
local bar = progressBar and progressBar:FindFirstChild("Bar")

local lastSmoke
RunService.Heartbeat:Connect(function()
	local st, progress, left = state()
	if st == "idle" then
		countdown.Text = "Ready!"
		countdown.TextColor3 = Color3.fromRGB(150, 255, 140)
	elseif st == "cooking" then
		countdown.Text = timeText(left)
		countdown.TextColor3 = Color3.fromRGB(255, 210, 120)
	elseif st == "done" then
		countdown.Text = "Claim!"
		countdown.TextColor3 = Color3.fromRGB(255, 235, 90)
	else
		countdown.Text = "Cooldown " .. timeText(left)
		countdown.TextColor3 = Color3.fromRGB(255, 130, 120)
	end
	if progressBar then
		progressBar.Visible = st == "cooking" or st == "cooldown"
		if bar then
			local k = st == "cooking" and progress or (st == "cooldown" and (left / F.Cooldown) or 0)
			bar.Size = UDim2.fromScale(math.clamp(k, 0, 1), 1)
		end
	end
	local smoking = st == "cooking"
	if smoking ~= lastSmoke then
		lastSmoke = smoking
		smoke(smoking)
	end
	prompt.ActionText = st == "done" and "Claim Iron" or "Open"
	if w.isOpen() then
		paint()
	end
end)
