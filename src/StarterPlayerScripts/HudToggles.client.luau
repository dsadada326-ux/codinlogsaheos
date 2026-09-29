-- The two arrow toggles on the sides of the screen.
--   Left arrow  -> slides the left-side buttons (Shop, Profile, Settings, Free...) off the left edge,
--                  one after another. The Bubbles counter stays.
--   Right arrow -> slides the currencies off the right edge.
-- Click again to bring them back. The arrows flip to point the way things will come back from.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local side = playerGui:WaitForChild("Buttons"):WaitForChild("SideContainer")
local leftToggle = side:WaitForChild("ToggleButton")

local currencies = playerGui:WaitForChild("Currencies"):WaitForChild("MainCurrenciesFrame")
local rightToggle = currencies:WaitForChild("ToggleButton")
local currencyList = currencies:WaitForChild("CurrenciesFrame")

local OUT = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local IN = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SPIN = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local STAGGER = 0.04

local function spinArrow(arrow, rotation)
	TweenService:Create(arrow, SPIN, { Rotation = rotation }):Play()
end

-- while closed, each arrow slides over to hug its edge of the screen, and back when opened
local SLIDE = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local LEFT_ARROW_HOME = leftToggle.Position
local RIGHT_ARROW_HOME = rightToggle.Position

-- (both arrows are anchored on their right edge, and sized relative to their container)
local LEFT_ARROW_EDGE = UDim2.new(leftToggle.Size.X.Scale + 0.06, 0, LEFT_ARROW_HOME.Y.Scale, LEFT_ARROW_HOME.Y.Offset)
local RIGHT_ARROW_EDGE = UDim2.new(0.97, 0, RIGHT_ARROW_HOME.Y.Scale, RIGHT_ARROW_HOME.Y.Offset)

local function slideArrow(arrow, position, hidden)
	-- when closing, let the buttons start leaving first so the arrow chases them out
	task.delay(hidden and 0.08 or 0, function()
		TweenService:Create(arrow, SLIDE, { Position = position }):Play()
	end)
end

-- the arrows rest the way they're built in the GUI, and turn 180 degrees while their side is hidden
local LEFT_SHOWN = leftToggle.Rotation % 360
local RIGHT_SHOWN = rightToggle.Rotation % 360
leftToggle.Rotation = LEFT_SHOWN
rightToggle.Rotation = RIGHT_SHOWN

------------------------------------------------------------------------------------------
-- left side buttons
------------------------------------------------------------------------------------------
local leftHidden = false
local leftItems = {} -- [gui] = its normal position
local leftOrder = {} -- top to bottom, so they leave one after another

local function isLeftItem(child)
	return child:IsA("GuiObject") and child ~= leftToggle
end

local function sortLeft()
	table.sort(leftOrder, function(a, b)
		return a.AbsolutePosition.Y < b.AbsolutePosition.Y
	end)
end

local function hiddenPosition(home, extraOffset)
	-- far enough left to be fully off-screen
	return UDim2.new(home.X.Scale - 1.8, home.X.Offset - (extraOffset or 0), home.Y.Scale, home.Y.Offset)
end

local function addLeftItem(child, offsetOnly)
	if leftItems[child] then return end

	leftItems[child] = child.Position
	table.insert(leftOrder, child)

	if leftHidden then
		child.Position = offsetOnly and (child.Position - UDim2.fromOffset(300, 0)) or hiddenPosition(child.Position)
	end
end

for _, child in ipairs(side:GetChildren()) do
	if isLeftItem(child) then addLeftItem(child) end
end

side.ChildAdded:Connect(function(child)
	if isLeftItem(child) then addLeftItem(child) end
end)

-- the owner's OWNER button sits on the left too (only owners have it)
local ownerOffsetItems = {}
task.spawn(function()
	local owner = playerGui:WaitForChild("OwnerPanel", 30)
	local toggle = owner and owner:WaitForChild("Toggle", 10)

	if toggle then
		ownerOffsetItems[toggle] = toggle.Position
		if leftHidden then toggle.Position = toggle.Position - UDim2.fromOffset(300, 0) end
	end
end)

local function setLeft(hidden)
	leftHidden = hidden
	sortLeft()

	for i, item in ipairs(leftOrder) do
		local home = leftItems[item]

		if item.Parent and home then
			task.delay((i - 1) * STAGGER, function()
				if leftHidden ~= hidden then return end
				TweenService:Create(item, hidden and OUT or IN, {
					Position = hidden and hiddenPosition(home) or home,
				}):Play()
			end)
		end
	end

	for item, home in pairs(ownerOffsetItems) do
		if item.Parent then
			TweenService:Create(item, hidden and OUT or IN, {
				Position = hidden and (home - UDim2.fromOffset(300, 0)) or home,
			}):Play()
		end
	end

	spinArrow(leftToggle, hidden and LEFT_SHOWN + 180 or LEFT_SHOWN)
	slideArrow(leftToggle, hidden and LEFT_ARROW_EDGE or LEFT_ARROW_HOME, hidden)
end

leftToggle.Activated:Connect(function()
	setLeft(not leftHidden)
end)

------------------------------------------------------------------------------------------
-- right side currencies
------------------------------------------------------------------------------------------
local rightHidden = false
local listHome = currencyList.Position
local arrowHome = RIGHT_SHOWN

local function setRight(hidden)
	rightHidden = hidden

	TweenService:Create(currencyList, hidden and OUT or IN, {
		Position = hidden and UDim2.new(listHome.X.Scale + 1.3, listHome.X.Offset, listHome.Y.Scale, listHome.Y.Offset) or listHome,
	}):Play()

	spinArrow(rightToggle, hidden and arrowHome + 180 or arrowHome)
	slideArrow(rightToggle, hidden and RIGHT_ARROW_EDGE or RIGHT_ARROW_HOME, hidden)
end

rightToggle.Activated:Connect(function()
	setRight(not rightHidden)
end)
