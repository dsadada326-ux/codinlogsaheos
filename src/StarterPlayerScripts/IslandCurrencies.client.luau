-- Shows only the current island's currencies in the currency list:
--   Island 1: Buttons, Cash, Rebirths, Time, Coins      Island 2: Wood
--   Fishing Frenzy: Fish Meal, Shells, Crabs
-- Other scripts still decide WHEN a row unlocks (Rebirths, Time, ...). This only hides rows that
-- don't belong on the island you're standing on, and puts back what those scripts wanted
-- when you travel back.
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local ISLAND_ROWS = {
	Island1 = { Button = true, Money = true, Rebirths = true, Time = true, Coins = true },
	Island2 = { Wood = true, Wheat = true, Ores = true, Gold = true },
	FishingFrenzy = { FishMeal = true, Shells = true, Crab = true },
	-- Drilling Mania (a corner of Island 1, see DrillConfig.Bounds)
	DrillingMania = { Scrap = true, Metal = true, Oil = true, Coins = true },
	-- the Laboratory (Island 2's sub-island, see LabConfig.Bounds)
	Labratory = { Chemicals = true, Oxygen = true, CarbonDioxide = true, Knowledge = true },
}

-- rows that always show on that island, even before their unlock script shows them
local ALWAYS = {
	DrillingMania = { Scrap = true, Metal = true, Oil = true, Coins = true },
	Labratory = { Chemicals = true, Oxygen = true, CarbonDioxide = true, Knowledge = true },
}

local DrillConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("DrillConfig"))
local LabConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("LabConfig"))

-- StarterGui.MessageToPlayerText.RedIsland: names whichever island you're standing on
local ISLAND_LABEL = {
	Island1 = { text = "Red Island", gradient = ColorSequence.new(Color3.fromRGB(255, 130, 120), Color3.fromRGB(200, 20, 20)) },
	Island2 = { text = "Blue Island", gradient = ColorSequence.new(Color3.fromRGB(120, 190, 255), Color3.fromRGB(20, 90, 220)) },
	FishingFrenzy = { text = "Fishing Frenzy", gradient = ColorSequence.new(Color3.fromRGB(130, 240, 255), Color3.fromRGB(20, 150, 220)) },
	DrillingMania = { text = "Drilling Mania", gradient = ColorSequence.new(Color3.fromRGB(255, 210, 110), Color3.fromRGB(150, 90, 30)) },
	Labratory = { text = "The Laboratory", gradient = ColorSequence.new(Color3.fromRGB(170, 255, 170), Color3.fromRGB(40, 170, 80)) },
}

local function updateIslandLabel(island)
	local gui = player.PlayerGui:FindFirstChild("MessageToPlayerText")
	local label = gui and gui:FindFirstChild("RedIsland")
	if not label then
		return
	end

	local def = ISLAND_LABEL[island] or ISLAND_LABEL.Island1
	label.Text = def.text

	local gradient = label:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = def.gradient
	end
end

local hitboxes = workspace:WaitForChild("IslandHitboxes")

-- which island you're over (the hitboxes sit above the islands, so only X/Z is checked)
local function islandAt(position)
	if DrillConfig.isInside(position) then
		return "DrillingMania"
	end
	if LabConfig.isInside(position) then
		return "Labratory"
	end
	for name in pairs(ISLAND_ROWS) do
		local box = hitboxes:FindFirstChild(name)
		if box then
			local p = box.CFrame:PointToObjectSpace(position)
			if math.abs(p.X) <= box.Size.X / 2 and math.abs(p.Z) <= box.Size.Z / 2 then
				return name
			end
		end
	end
	return nil
end

local currentIsland = "Island1"
updateIslandLabel(currentIsland)
local wanted = {}     -- row -> the visibility the unlock scripts asked for
local ourSet = {}      -- row -> { value, time } of our last change, so we can ignore its echo

local function allowed(row)
	local rows = ISLAND_ROWS[currentIsland]
	return rows == nil or rows[row.Name] == true
end

local function applyRow(row)
	local forced = ALWAYS[currentIsland] and ALWAYS[currentIsland][row.Name]
	local value = (wanted[row] or forced) and allowed(row) or false
	if row.Visible ~= value then
		ourSet[row] = { value = value, time = os.clock() }
		row.Visible = value
	end
end

local function watchList(list)
	local function track(row)
		if not row:IsA("GuiObject") then
			return
		end
		wanted[row] = row.Visible
		row:GetPropertyChangedSignal("Visible"):Connect(function()
			local mine = ourSet[row]
			if mine and mine.value == row.Visible and os.clock() - mine.time < 0.5 then
				ourSet[row] = nil
				return -- the echo of our own change
			end
			wanted[row] = row.Visible
			if row.Visible and not allowed(row) then
				applyRow(row)
			end
		end)
		applyRow(row)
	end

	for _, row in ipairs(list:GetChildren()) do
		track(row)
	end
	list.ChildAdded:Connect(track)
end

local function findList(gui)
	local main = gui:WaitForChild("MainCurrenciesFrame", 10)
	return main and main:WaitForChild("CurrenciesFrame", 10)
end

local list
local function hook(gui)
	local l = findList(gui)
	if l then
		list = l
		wanted = {}
		watchList(l)
	end
end

local gui = player.PlayerGui:FindFirstChild("Currencies")
if gui then
	task.spawn(hook, gui)
end
player.PlayerGui.ChildAdded:Connect(function(child)
	if child.Name == "Currencies" then
		task.spawn(hook, child)
	end
	if child.Name == "MessageToPlayerText" then
		task.defer(updateIslandLabel, currentIsland)
	end
end)

-- check where you are a few times a second
while true do
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local island = root and islandAt(root.Position)

	if island and island ~= currentIsland then
		currentIsland = island
		updateIslandLabel(currentIsland)
		if list then
			for row in pairs(wanted) do
				if row.Parent == list then
					applyRow(row)
				end
			end
		end
	end

	task.wait(0.25)
end
