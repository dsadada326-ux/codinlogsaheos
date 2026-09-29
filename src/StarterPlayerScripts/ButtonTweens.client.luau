-- Hover / click tween for every button on the player's screen (ScreenGuis only, not the 3D boards).
--   hover  -> grows a little     press -> squishes     release -> bounces back
-- Buttons that already animate themselves (they have their own UIScale) are left alone.
-- To turn it off for one button, give it the attribute NoTween = true.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SCALE_NAME = "ButtonTween"
local HOVER = 1.07
local PRESS = 0.9

local hoverInfo = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local pressInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local releaseInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local done = setmetatable({}, { __mode = "k" })

local function onScreen(button)
	-- only 2D menus/HUD: skip anything drawn on a SurfaceGui or BillboardGui
	return button:FindFirstAncestorWhichIsA("ScreenGui") ~= nil
		and button:FindFirstAncestorWhichIsA("SurfaceGui") == nil
		and button:FindFirstAncestorWhichIsA("BillboardGui") == nil
end

local function setup(button)
	if done[button] or not button:IsA("GuiButton") or not onScreen(button) then
		return
	end

	if button:GetAttribute("NoTween") == true then
		return
	end

	-- it already has its own scale animation (Settings, Teleport cards, Runes tabs...)
	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("UIScale") and child.Name ~= SCALE_NAME then
			return
		end
	end

	done[button] = true

	local scale = button:FindFirstChild(SCALE_NAME) or Instance.new("UIScale")
	scale.Name = SCALE_NAME
	scale.Scale = 1
	scale.Parent = button

	local hovering = false

	local function play(info, value)
		TweenService:Create(scale, info, { Scale = value }):Play()
	end

	button.MouseEnter:Connect(function()
		hovering = true
		play(hoverInfo, HOVER)
	end)

	button.MouseLeave:Connect(function()
		hovering = false
		play(hoverInfo, 1)
	end)

	button.MouseButton1Down:Connect(function()
		play(pressInfo, PRESS)
	end)

	button.MouseButton1Up:Connect(function()
		play(releaseInfo, hovering and HOVER or 1)
	end)

	-- touch / gamepad: a quick squish-and-bounce on every click
	button.Activated:Connect(function(input)
		if input and input.UserInputType == Enum.UserInputType.MouseButton1 then
			return -- the mouse already got its press/release above
		end

		scale.Scale = PRESS
		play(releaseInfo, 1)
	end)
end

for _, d in ipairs(playerGui:GetDescendants()) do
	setup(d)
end

-- menus that get (re)built or cloned later
playerGui.DescendantAdded:Connect(function(d)
	if d:IsA("GuiButton") then
		task.defer(setup, d) -- let whoever made it add its own UIScale first
	end
end)
