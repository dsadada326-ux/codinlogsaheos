local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))

local boardsFolder = workspace
	:WaitForChild("Islands"):WaitForChild("Island1"):WaitForChild("Zones")
	:WaitForChild("Leaderboards"):WaitForChild("Leaderboards")

local UPDATE_EVERY = 60 -- seconds
local TOP = 10

local function formatPlaytime(seconds)
	seconds = math.floor(seconds or 0)

	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds % 3600 / 60)

	if hours > 0 then
		return hours .. "h " .. minutes .. "m"
	end

	return minutes .. "m"
end

-- the numbers get astronomically big, so boards store log10 of the value (keeps the order,
-- fits in an OrderedDataStore integer)
local function encode(value)
	return math.floor(math.log10(math.max(value, 0) + 1) * 1e6)
end

local function decode(stored)
	return 10 ^ (stored / 1e6) - 1
end

local BOARDS = {
	{ board = "Cash", attribute = "Cash", title = "Cash Leaderboard", format = function(v) return NumberFormat.abbreviate(v) .. " Cash" end },
	{ board = "Buttons", attribute = "Buttons", title = "Buttons Leaderboard", format = function(v) return NumberFormat.abbreviate(v) .. " Buttons" end },
	{ board = "Rebirths", attribute = "Rebirths", title = "Rebirths Leaderboard", format = function(v) return NumberFormat.abbreviate(v) .. " Rebirths" end },
	{ board = "PlayTime", attribute = "Playtime", title = "PlayTime Leaderboard", format = formatPlaytime, raw = true },
	{ board = "Robux", comingSoon = true, title = "Robux Leaderboard" },
}

local canUse = not (RunService:IsStudio() and game.GameId == 0)
local names = {}

local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end

	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and name or ("User " .. userId)

	return names[userId]
end

local function findDeep(root, name)
	return root:FindFirstChild(name, true)
end

local function render(def, entries)
	local model = boardsFolder:FindFirstChild(def.board)
	local gui = model and model:FindFirstChild("SurfaceGuiPart") and model.SurfaceGuiPart:FindFirstChildOfClass("SurfaceGui")

	if not gui then
		return
	end

	local title = findDeep(gui, "CurrencyTitleLabel")

	if title then
		title.Text = def.title
	end

	local template = findDeep(gui, "PlacementTemplate")

	if not template then
		return
	end

	local list = template.Parent

	for _, child in ipairs(list:GetChildren()) do
		if child.Name == "Placement" then
			child:Destroy()
		end
	end

	for rank, entry in ipairs(entries) do
		local row = template:Clone()
		row.Name = "Placement"
		row.Visible = true
		row.LayoutOrder = rank

		local placement = findDeep(row, "PlacementText")
		local username = findDeep(row, "Username")
		local amount = findDeep(row, "CurrencyAmount")

		if placement then placement.Text = entry.placement or (rank .. ".") end
		if username then username.Text = entry.name end
		if amount then amount.Text = entry.amount end

		row.Parent = list
	end
end

local stores = {}

for _, def in ipairs(BOARDS) do
	if not def.comingSoon and canUse then
		stores[def.board] = DataStoreService:GetOrderedDataStore("LB_" .. def.board)
	end
end

local function update()
	for _, def in ipairs(BOARDS) do
		if def.comingSoon then
			render(def, { { placement = "", name = "Coming soon!", amount = "" } })
		elseif not canUse then
			render(def, { { placement = "", name = "Publish the game to see leaderboards", amount = "" } })
		else
			local store = stores[def.board]

			-- save everyone's current value
			for _, player in ipairs(Players:GetPlayers()) do
				if player:GetAttribute("DataLoaded") == true then
					local value = player:GetAttribute(def.attribute) or 0
					local stored = def.raw and math.floor(value) or encode(value)

					pcall(store.SetAsync, store, tostring(player.UserId), stored)
				end
			end

			-- read the top of the board
			local ok, pages = pcall(store.GetSortedAsync, store, false, TOP)

			if ok and pages then
				local entries = {}

				for _, item in ipairs(pages:GetCurrentPage()) do
					local value = def.raw and item.value or decode(item.value)

					table.insert(entries, {
						name = nameOf(tonumber(item.key)),
						amount = def.format(value),
					})
				end

				render(def, entries)
			end
		end
	end
end

task.wait(5)

while true do
	local ok, err = pcall(update)

	if not ok then
		warn("[Leaderboards] " .. tostring(err))
	end

	task.wait(UPDATE_EVERY)
end
