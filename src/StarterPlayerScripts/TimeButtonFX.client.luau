local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))
local timeReward = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TimeReward")

local pad = workspace
	:WaitForChild("Islands")
	:WaitForChild("Island1")
	:WaitForChild("Zones")
	:WaitForChild("Time")
	:WaitForChild("TimeButton")
	:WaitForChild("Button")

local TIME_ICON = "rbxassetid://104436607164470"
local GLOW_COLOR = Color3.fromRGB(150, 225, 255)

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

-- while you stand on the pad: your shockwave VFX (ReplicatedStorage.TimeButtonVfx) ripples
-- out of it, and the pad does a little press-down tween every time Time comes in.
-- The pad itself keeps its own red color.
local vfxTemplate = ReplicatedStorage:WaitForChild("TimeButtonVfx")

local vfx = vfxTemplate:Clone()
vfx.Name = "TimeButtonVfxLocal"
vfx.Anchored = true
vfx.CanCollide = false
vfx.CanQuery = false
vfx.CanTouch = false
vfx.Transparency = 1
vfx.CFrame = pad.CFrame * CFrame.new(0, pad.Size.Y / 2 + 0.05, 0)
vfx.Parent = workspace

local emitters = {}

for _, d in ipairs(vfx:GetDescendants()) do
	if d:IsA("ParticleEmitter") then
		d.Enabled = false
		table.insert(emitters, d)
	end
end

local padHome = pad.CFrame
local pressing = false

local function setActive(on)
	local show = on and settingOn("VFX")

	for _, e in ipairs(emitters) do
		e.Enabled = show

		if show then
			e:Emit(1) -- first ring right away
		end
	end
end

-- quick press down and spring back (local only; the real pad never moves)
local function press()
	if pressing then
		return
	end

	pressing = true

	local down = TweenService:Create(
		pad,
		TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = padHome * CFrame.new(0, -0.35, 0) }
	)

	down:Play()
	down.Completed:Wait()

	local up = TweenService:Create(
		pad,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ CFrame = padHome }
	)

	up:Play()
	up.Completed:Wait()

	pressing = false
end

player:GetAttributeChangedSignal("OnTimeButton"):Connect(function()
	setActive(player:GetAttribute("OnTimeButton") == true)
end)

setActive(player:GetAttribute("OnTimeButton") == true)

-- "+5 Time" popups floating up from the pad --------------------------------------------
local anchor = Instance.new("Attachment")
anchor.Name = "TimePopupAnchor"
anchor.Position = Vector3.new(0, pad.Size.Y / 2 + 3, 0)
anchor.Parent = pad

local function popup(amount)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = anchor
	gui.StudsOffsetWorldSpace = Vector3.new((math.random() - 0.5) * 3, 0, (math.random() - 0.5) * 3)
	gui.Parent = anchor

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = row

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 0.8)
	label.Text = "+" .. NumberFormat.amount(amount)
	label.TextScaled = true
	label.FontFace = uiFont()
	label.TextColor3 = GLOW_COLOR
	label.Parent = row

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(20, 30, 50)
	stroke.Parent = label

	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(0.25, 0.9)
	icon.Image = TIME_ICON
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = row

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = icon

	local info = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 4, 0) }):Play()

	local fade = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	TweenService:Create(icon, fade, { ImageTransparency = 1 }):Play()

	Debris:AddItem(gui, 1.1)
end

timeReward.OnClientEvent:Connect(function(amount, onButton)
	-- only show them when you're at the pad (Auto Time works silently elsewhere)
	if onButton then
		task.spawn(press)

		if settingOn("VFX") then
			popup(amount)
		end
	end
end)

-- the Time row in the currency list shows once Time is unlocked --------------------------
local timeZone = ZoneConfig.find("Time")

local function applyTimeRow()
	local currencies = player.PlayerGui:FindFirstChild("Currencies")
	local row = currencies
		and currencies:FindFirstChild("MainCurrenciesFrame")
		and currencies.MainCurrenciesFrame:FindFirstChild("CurrenciesFrame")
		and currencies.MainCurrenciesFrame.CurrenciesFrame:FindFirstChild("Time")

	if row then
		row.Visible = ZoneConfig.isRevealed(player, timeZone)
	end
end

player:GetAttributeChangedSignal(ZoneConfig.flagAttribute(timeZone)):Connect(applyTimeRow)

player.PlayerGui.ChildAdded:Connect(function(child)
	if child.Name == "Currencies" then
		task.defer(applyTimeRow)
	end
end)

applyTimeRow()

player:GetAttributeChangedSignal(SettingsConfig.attributeOf("VFX")):Connect(function()
	setActive(player:GetAttribute("OnTimeButton") == true)
end)
