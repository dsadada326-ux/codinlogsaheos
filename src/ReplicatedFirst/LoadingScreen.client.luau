-- Custom loading screen. Runs from ReplicatedFirst, so it starts before
-- anything else in the game has loaded.
--
-- Setup in Studio: move the "Loading" ScreenGui from StarterGui into
-- ReplicatedFirst (next to this script). If it's left in StarterGui it still
-- works, but only shows once the player's GUI has arrived.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local MIN_DISPLAY_TIME = 3 -- seconds; stops the screen from just flashing
local FADE_TIME = 0.6

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local loadingGui = ReplicatedFirst:FindFirstChild("Loading")
if loadingGui then
	loadingGui = loadingGui:Clone()
	loadingGui.Parent = playerGui
else
	loadingGui = playerGui:WaitForChild("Loading")
end

loadingGui.ResetOnSpawn = false
loadingGui.IgnoreGuiInset = true
loadingGui.DisplayOrder = 1000
loadingGui.Enabled = true

ReplicatedFirst:RemoveDefaultLoadingScreen()

local loadingBar = loadingGui:WaitForChild("LoadingBar")
local fill = loadingBar:WaitForChild("Fill")
local title = loadingBar:FindFirstChild("Title")
local extra = title and title:FindFirstChild("Extra")

local fillHeight = fill.Size.Y
local startTime = os.clock()

local function setProgress(alpha: number)
	alpha = math.clamp(alpha, 0, 1)
	TweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
		Size = UDim2.new(alpha, 0, fillHeight.Scale, fillHeight.Offset),
	}):Play()
	if extra then
		extra.Text = string.format("%d%%", math.floor(alpha * 100))
	end
end

setProgress(0)

-- Animated "Loading..." dots on the title while we wait
local loading = true
if title then
	task.spawn(function()
		local dots = 0
		while loading do
			dots = dots % 3 + 1
			title.Text = "Loading" .. string.rep(".", dots)
			task.wait(0.4)
		end
	end)
end

-- Wait for the game itself to finish replicating
if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Preload everything under these services. Progress goes up per asset.
local toPreload = {}
for _, service in { workspace, game:GetService("ReplicatedStorage"), game:GetService("StarterGui") } do
	for _, descendant in service:GetDescendants() do
		table.insert(toPreload, descendant)
	end
end

local total = #toPreload
local done = 0
if total > 0 then
	ContentProvider:PreloadAsync(toPreload, function()
		done += 1
		setProgress(done / total)
	end)
end
setProgress(1)

-- Keep it up for at least MIN_DISPLAY_TIME
local elapsed = os.clock() - startTime
if elapsed < MIN_DISPLAY_TIME then
	task.wait(MIN_DISPLAY_TIME - elapsed)
end

loading = false
if title then
	title.Text = "Ready!"
end
task.wait(0.3)

-- Fade everything out, then remove the screen
local fadeInfo = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local fadeTargets = loadingGui:GetDescendants()
for _, object in fadeTargets do
	local goal = {}
	if object:IsA("GuiObject") then
		goal.BackgroundTransparency = 1
	end
	if object:IsA("ImageLabel") or object:IsA("ImageButton") then
		goal.ImageTransparency = 1
	end
	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		goal.TextTransparency = 1
		goal.TextStrokeTransparency = 1
	end
	if object:IsA("UIStroke") then
		goal.Transparency = 1
	end
	if next(goal) then
		TweenService:Create(object, fadeInfo, goal):Play()
	end
end

task.wait(FADE_TIME)
loadingGui:Destroy()
