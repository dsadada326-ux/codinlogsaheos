local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))
local setSetting = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("SetSetting")

local gui = playerGui:WaitForChild("Settings")
local outer = gui:WaitForChild("Container")
local scroll = outer.Container.ScrollingFrame
local tabsRow = outer.Buttons

-- colors for the toggle pill: green "ON" / red "OFF"
local ON_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(85, 255, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(166, 255, 0)),
})
local OFF_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 60)),
})

local function setToggleLook(toggle, on)
	local selected = toggle.Frame.Selected
	local title = toggle.Frame.Title
	local titleTop = title.Title

	selected.Color = on and ON_COLORS or OFF_COLORS

	local text = on and "ON" or "OFF"
	title.Text = text
	titleTop.Text = text
end

local function bounce(toggle)
	local scale = toggle:FindFirstChildOfClass("UIScale")

	if not scale then
		return
	end

	scale.Scale = 0.85

	TweenService:Create(
		scale,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

-- hover in / hover out, on any button's own UIScale (works for tabs, toggles, Close, the sidebar icon...)
local HOVER_SCALE = 1.08

local HOVER_HIGHLIGHT_COLOR = Color3.fromRGB(120, 200, 255)

local function addHover(button)
	local scale = button:FindFirstChildOfClass("UIScale")

	-- some buttons (like the sidebar icon) also have a background glow + one
	-- or more borders, which brighten on hover for a clearer highlight
	local glow = button:FindFirstChild("Gradient")
	local glowTransparency = glow and glow.BackgroundTransparency

	local strokes = {}

	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("UIStroke") then
			table.insert(strokes, {
				stroke = child,
				color = child.Color,
				thickness = child.Thickness,
			})
		end
	end

	local function enter()
		if scale then
			TweenService:Create(
				scale,
				TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = HOVER_SCALE }
			):Play()
		end

		if glow then
			TweenService:Create(
				glow,
				TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = math.max(glowTransparency - 0.4, 0) }
			):Play()
		end

		for _, entry in ipairs(strokes) do
			TweenService:Create(
				entry.stroke,
				TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Color = HOVER_HIGHLIGHT_COLOR, Thickness = entry.thickness + 0.04 }
			):Play()
		end
	end

	local function leave()
		if scale then
			TweenService:Create(
				scale,
				TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end

		if glow then
			TweenService:Create(
				glow,
				TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = glowTransparency }
			):Play()
		end

		for _, entry in ipairs(strokes) do
			TweenService:Create(
				entry.stroke,
				TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Color = entry.color, Thickness = entry.thickness }
			):Play()
		end
	end

	if not scale and not glow and #strokes == 0 then
		return
	end

	button.MouseEnter:Connect(enter)
	button.MouseLeave:Connect(leave)
end

-- one row per setting -----------------------------------------------------------------
local rows = {}

for _, key in ipairs(SettingsConfig.Order) do
	local def = SettingsConfig.Settings[key]
	local row = scroll:FindFirstChild(key)

	if row then
		local template = row:WaitForChild("Template")
		local attribute = SettingsConfig.attributeOf(key)

		template.Title.Text = def.DisplayName
		template.Title.Title.Text = def.DisplayName

		local toggle = template:WaitForChild("Toggle")
		addHover(toggle)

		local function refresh()
			local on = player:GetAttribute(attribute)

			if on == nil then
				on = def.Default
			end

			setToggleLook(toggle, on)
		end

		toggle.Activated:Connect(function()
			local current = player:GetAttribute(attribute)

			if current == nil then
				current = def.Default
			end

			setSetting:FireServer(key, not current)
			bounce(toggle)
		end)

		player:GetAttributeChangedSignal(attribute):Connect(refresh)
		refresh()

		rows[key] = row
	end
end

-- category tabs (only "Gameplay" has rows right now; "Titles" just shows empty) ----------
local function setTabSelected(tab, selected)
	tab.Frame.Selected.Enabled = selected
	tab.Frame.Selected.Transparency = NumberSequence.new(selected and 0 or 1)
end

local function selectTab(name)
	for _, tab in ipairs(tabsRow:GetChildren()) do
		if tab:IsA("GuiButton") then
			setTabSelected(tab, tab.Name == name)
		end
	end

	-- every settings row belongs to "Gameplay" for now
	for _, row in pairs(rows) do
		row.Visible = name == "Gameplay"
	end
end

for _, tab in ipairs(tabsRow:GetChildren()) do
	if tab:IsA("GuiButton") then
		tab.Activated:Connect(function()
			selectTab(tab.Name)
		end)

		addHover(tab)
	end
end

selectTab("Gameplay")

-- open / close -------------------------------------------------------------------------
local closeButton = outer.Header:WaitForChild("Close")
local openButton = playerGui:WaitForChild("Buttons"):WaitForChild("SideContainer"):WaitForChild("Settings")
local openScale = outer:WaitForChild("OpenScale")
local openPressScale = openButton:FindFirstChildOfClass("UIScale")

local function popIn(scaleObject)
	scaleObject.Scale = 0.7

	TweenService:Create(
		scaleObject,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

local function openSettings()
	gui.Enabled = true
	popIn(openScale)
end

local function closeSettings()
	gui.Enabled = false
end

closeButton.Activated:Connect(closeSettings)
addHover(closeButton)

-- the sidebar icon opens the panel, or closes it again if it's already open
openButton.Activated:Connect(function()
	if openPressScale then
		bounce(openButton)
	end

	if gui.Enabled then
		closeSettings()
	else
		openSettings()
	end
end)

addHover(openButton)

-- the gear in the top bar (TopbarMenu) opens it too
game:GetService("ReplicatedStorage"):WaitForChild("HudActions").Event:Connect(function(action)
	if action ~= "Settings" then return end
	if gui.Enabled then
		closeSettings()
	else
		openSettings()
	end
end)

-- Night Time: applies locally, right away and on every future toggle
local DAY_TIME = 14
local NIGHT_TIME = 0

local function applyNightTime()
	local on = player:GetAttribute(SettingsConfig.attributeOf("NightTime"))

	if on == nil then
		on = SettingsConfig.Settings.NightTime.Default
	end

	TweenService:Create(
		Lighting,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ ClockTime = on and NIGHT_TIME or DAY_TIME }
	):Play()
end

player:GetAttributeChangedSignal(SettingsConfig.attributeOf("NightTime")):Connect(applyNightTime)

-- wait for the setting to actually load in before applying it once
if player:GetAttribute("DataLoaded") then
	applyNightTime()
else
	local connection

	connection = player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		if player:GetAttribute("DataLoaded") then
			connection:Disconnect()
			applyNightTime()
		end
	end)
end
