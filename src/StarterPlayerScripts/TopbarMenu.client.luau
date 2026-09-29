-- Top bar buttons, next to Roblox's own (the menu / chat / mic pill):
--   [ ••• | gear ]   ••• drops down Redeem Codes + Updates, the gear opens Settings.
-- They fire ReplicatedStorage.HudActions ("Codes" / "Updates" / "Settings"), which MenuPopups and
-- SettingsUI listen to. The old Settings / Codes / Updates HUD buttons are hidden in StarterGui.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local actions = ReplicatedStorage:WaitForChild("HudActions")

-- reuse the game's own icons
local ICONS = {
	Settings = "rbxassetid://92605503093811",
	Codes = "rbxassetid://104921418887428",
	Updates = "rbxassetid://97295553305625",
}

local DARK = Color3.fromRGB(18, 18, 21)
local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end

local gui = new("ScreenGui", {
	Name = "TopbarMenu", ResetOnSpawn = false, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None,
	DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

-- the pill
local pill = new("Frame", {
	Name = "Pill", BackgroundColor3 = DARK, BackgroundTransparency = 0.08, Size = UDim2.fromOffset(96, 44), -- same as Roblox's pill
}, gui)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)

local function pillButton(name, x)
	local b = new("ImageButton", {
		Name = name, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, x, 0.5, 0), Size = UDim2.fromOffset(40, 40), Image = "",
	}, pill)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
	b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.88 }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 1 }):Play() end)
	return b
end

-- "•••" (three dots drawn as circles so it looks the same everywhere)
local more = pillButton("More", 24)
local dots = new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(26, 26),
}, more)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, dots)
for i = -1, 1 do
	local d = new("Frame", {
		BackgroundColor3 = DARK, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, i * 7, 0.5, 0), Size = UDim2.fromOffset(4, 4),
	}, dots)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, d)
end

-- gear
local gear = pillButton("Settings", 72)
local gearIcon = new("ImageLabel", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(32, 32), Image = ICONS.Settings, ScaleType = Enum.ScaleType.Fit,
}, gear)

------------------------------------------------------------------------------------------
-- the drop-down
------------------------------------------------------------------------------------------
local drop = new("Frame", {
	Name = "Dropdown", BackgroundColor3 = DARK, BackgroundTransparency = 0.15, Size = UDim2.fromOffset(250, 0),
	AutomaticSize = Enum.AutomaticSize.Y, Visible = false,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, drop)
new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, drop)
new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, drop)
local dropScale = new("UIScale", {}, drop)

local function setDrop(open)
	if open == drop.Visible then return end
	if open then
		drop.Visible = true
		dropScale.Scale = 0.85
		TweenService:Create(dropScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		more.BackgroundTransparency = 0.85
	else
		drop.Visible = false
		more.BackgroundTransparency = 1
	end
end

local function row(order, action, text)
	local b = new("TextButton", {
		Name = action, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1, AutoButtonColor = false, Text = "",
	}, drop)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, b)
	new("ImageLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(36, 36), Image = ICONS[action], ScaleType = Enum.ScaleType.Fit,
	}, b)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 60, 0, 0), Size = UDim2.new(1, -66, 1, 0),
		FontFace = FONT, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, Text = text,
	}, b)
	b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.1), { BackgroundTransparency = 0.9 }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.1), { BackgroundTransparency = 1 }):Play() end)
	b.Activated:Connect(function()
		setDrop(false)
		actions:Fire(action)
	end)
	return b
end

row(1, "Codes", "Redeem Codes")
row(2, "Updates", "Updates")

more.Activated:Connect(function()
	setDrop(not drop.Visible)
end)

gear.Activated:Connect(function()
	setDrop(false)
	local s = new("UIScale", { Scale = 0.85 }, gearIcon)
	TweenService:Create(gearIcon, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Rotation = gearIcon.Rotation + 90 }):Play()
	TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(0.3, function() s:Destroy() end)
	actions:Fire("Settings")
end)

-- click anywhere else: close the drop-down
UserInputService.InputBegan:Connect(function(input)
	if not drop.Visible then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local p = Vector2.new(input.Position.X, input.Position.Y)
	local function inside(g)
		local a, s = g.AbsolutePosition, g.AbsoluteSize
		return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
	end
	if not inside(drop) and not inside(pill) then
		setDrop(false)
	end
end)

------------------------------------------------------------------------------------------
-- sit in the top bar, just right of Roblox's buttons
------------------------------------------------------------------------------------------
local function place()
	local inset = GuiService.TopbarInset -- the free part of the top bar
	local h = inset.Height > 0 and inset.Height or 58
	local size = math.clamp(h - 14, 32, 44)
	local x = (inset.Width > 0 and inset.Min.X or 104) + 12
	pill.Size = UDim2.fromOffset(size * 2 + 8, size)
	-- Roblox's own buttons sit 12px down with a 2px gap under them (44px tall in a 58px bar): match that
	local top = inset.Min.Y + math.max(0, h - size - 2)
	pill.Position = UDim2.fromOffset(x, top)
	more.Size = UDim2.fromOffset(size - 4, size - 4)
	gear.Size = UDim2.fromOffset(size - 4, size - 4)
	more.Position = UDim2.new(0, size / 2 + 2, 0.5, 0)
	gear.Position = UDim2.new(0, size * 1.5 + 6, 0.5, 0)
	dots.Size = UDim2.fromOffset(size * 0.6, size * 0.6)
	gearIcon.Size = UDim2.fromOffset(size * 0.75, size * 0.75)
	drop.Position = UDim2.fromOffset(x, top + size + 8)
end
place()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
