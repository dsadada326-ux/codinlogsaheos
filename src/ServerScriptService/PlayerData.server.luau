local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local DATASTORE_NAME = "PlayerData_v14"
local AUTOSAVE_SECONDS = 60
local ATTEMPTS = 3

-- Everything listed here is saved for every player, and shows up as an
-- attribute on the Player (that's what the Currencies UI reads).
-- To save a new currency, just add it to this list.
local DEFAULTS = {
	Buttons = 0,
	ButtonValue = 1, -- cash per button (grows over time; a rebirth should reset it to 1)
	Cash = 0,
	Rebirths = 0,
	Time = 0,
	Wheat = 0,
	Iron = 0,
	Gold = 0,
	Gems = 0, -- limited currency; nothing hands these out automatically
}

-- upgrade levels and unlock flags are saved too (added automatically from UpgradeConfig)
local UpgradeConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("UpgradeConfig"))

for _, id in ipairs(UpgradeConfig.Order) do
	DEFAULTS[UpgradeConfig.levelAttribute(id)] = 0

	if UpgradeConfig.needsUnlock(id) then
		DEFAULTS[UpgradeConfig.unlockAttribute(id)] = 0
	end
end

-- settings are saved too (added automatically from SettingsConfig)
local SettingsConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("SettingsConfig"))

for _, key in ipairs(SettingsConfig.Order) do
	DEFAULTS[SettingsConfig.attributeOf(key)] = SettingsConfig.Settings[key].Default
end

-- zone unlocks are saved too, so they survive a rebirth (added automatically from ZoneConfig)
local ZoneConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("ZoneConfig"))

for _, zone in ipairs(ZoneConfig.Zones) do
	if not ZoneConfig.alwaysOpen(zone) then
		DEFAULTS[ZoneConfig.flagAttribute(zone)] = false
	end
end

-- prestige level and Upgrade Tree purchases (added automatically from PrestigeConfig)
local PrestigeConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("PrestigeConfig"))

DEFAULTS.Prestige = 0

for _, treeDefs in ipairs({ PrestigeConfig.Tree, PrestigeConfig.Island2Tree, PrestigeConfig.FishTree or {} }) do
	for node in pairs(treeDefs) do
		DEFAULTS[PrestigeConfig.treeAttribute(node)] = false
	end
end

-- runes: how many of each you own, how many you've opened per stand, and saved stand unlocks
local RuneConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("RuneConfig"))

for poolName, pool in pairs(RuneConfig.Pools) do
	DEFAULTS[RuneConfig.openedAttribute(poolName)] = 0
	DEFAULTS["Unlocked_Rune_" .. poolName] = false

	for _, rune in ipairs(pool.runes) do
		DEFAULTS[RuneConfig.countAttribute(poolName, rune.name)] = 0
	end
end

-- Coins, Tycoon purchases, and Equipment (added automatically from their configs)
local TycoonConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TycoonConfig"))
local EquipmentConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("EquipmentConfig"))

DEFAULTS.Coins = 0
DEFAULTS.EquippedIndex = 0

for item in pairs(TycoonConfig.Items) do
	DEFAULTS[TycoonConfig.ownedAttribute(item)] = false
end

for _, id in ipairs(EquipmentConfig.Order) do
	DEFAULTS[EquipmentConfig.ownedAttribute(id)] = false
end

-- Island 2
DEFAULTS.Wood = 0
DEFAULTS.Island2Unlocked = false
DEFAULTS.TreeTier = 1

-- total seconds played (the Playtime leaderstat and leaderboard)
DEFAULTS.Playtime = 0

-- Shop + Profile (ShopService / ProfileService)
DEFAULTS.Tickets = 0
DEFAULTS.TicketSeconds = 0 -- playtime towards the next Ticket
DEFAULTS.RobuxSpent = 0
DEFAULTS.TotalButtons = 0 -- every Button ever earned (Buttons itself resets on prestige)
DEFAULTS.EquippedTitle = ""
do
	local ShopConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("ShopConfig"))
	for _, boost in ipairs(ShopConfig.Boosts) do
		DEFAULTS[ShopConfig.boostAttribute(boost)] = 0 -- when the Ticket boost runs out (server time)
	end
	-- passes bought with Tickets are saved (Robux ones are also re-checked with Roblox on join)
	for _, pass in ipairs(ShopConfig.Passes) do
		DEFAULTS[ShopConfig.passAttribute(pass.key)] = false
	end
	DEFAULTS[ShopConfig.passAttribute(ShopConfig.Bundle.key)] = false
end

-- Fishing Frenzy (added automatically from FishingConfig)
local FishingConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("FishingConfig"))

DEFAULTS.FishMeal = 0
DEFAULTS.Shells = 0
DEFAULTS.Crabs = 0
DEFAULTS.FishCaught = 0
DEFAULTS.FishTier = 0
DEFAULTS.FishPrestige = 0
DEFAULTS.EquippedRod = 1
DEFAULTS.FishInventory = "[]" -- the fish you're carrying (JSON), turned back into tools by FishingService
DEFAULTS.AutoSell = false -- the Auto Sell gamepass switch (Inventory window)

for _, rod in ipairs(FishingConfig.Rods) do
	if rod.id ~= "Wooden" then
		DEFAULTS[FishingConfig.rodAttribute(rod.id)] = false
	end
end

for _, u in ipairs(FishingConfig.ShellUpgrades) do
	DEFAULTS[FishingConfig.shellUpAttribute(u.id)] = 0
end

for n in ipairs(FishingConfig.AutoFishers) do
	DEFAULTS[FishingConfig.autoFisherAttribute(n)] = false
end
-- fish you've caught at least once (the "NEW!" badge + the fish index)
for _, fish in ipairs(FishingConfig.Fish) do
	DEFAULTS["FishFound_" .. fish.id] = false
end

-- Drilling Mania (DrillService)
DEFAULTS.Scrap = 0
DEFAULTS.Metal = 0 -- shown as "Iron"
DEFAULTS.Oil = 0
DEFAULTS.DrillPlots = 0 -- plots bought
DEFAULTS.DrillInv = "{}" -- drills owned but not placed (JSON)
DEFAULTS.DrillPlaced = "{}" -- which drill sits on which plot (JSON)
DEFAULTS.DrillEnhance = 0 -- Enhancer tier
DEFAULTS.DrillStock = "{}" -- what's left in your Drill Shop this restock (JSON)
DEFAULTS.DrillStockWindow = -1 -- which 5-minute restock that stock belongs to
DEFAULTS.FurnaceScrap = 0 -- Scrap cooking right now (0 = empty)
DEFAULTS.FurnaceIron = 0 -- Iron it will give
DEFAULTS.FurnaceStart = 0 -- server time it started
DEFAULTS.FurnaceEnd = 0 -- server time it's done
DEFAULTS.FurnaceCooldown = 0 -- server time it can be used again
do
	local DrillConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("DrillConfig"))
	for cell = 1, DrillConfig.MaxPlots do
		DEFAULTS[DrillConfig.oilAttribute(cell)] = 0 -- Oil waiting in each drill
	end
end

-- The Laboratory (LabService)
DEFAULTS.Chemicals = 0
DEFAULTS.Oxygen = 0
DEFAULTS.CarbonDioxide = 0 -- shown as "CO2"
DEFAULTS.Knowledge = 0
DEFAULTS.LabPotions = "{}" -- potions you're carrying (JSON)
DEFAULTS.LabLevel = 0 -- Lab Level 0-8 (Lab Level board)
DEFAULTS.LabMark = 0 -- Advancement Marks 0-5 (needs max Lab Level)
do
	local LabConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("LabConfig"))
	for id in pairs(LabConfig.Items) do
		DEFAULTS[LabConfig.ownedAttribute(id)] = false
	end
	for _, u in ipairs(LabConfig.Upgrades) do
		DEFAULTS[LabConfig.upgradeAttribute(u.id)] = 0
	end
	for id in pairs(LabConfig.ExtraById) do
		DEFAULTS[LabConfig.extraAttribute(id)] = false -- staff + decor from the Lab Shop
	end
end

-- an unpublished place has no DataStore access, so only try when it can work
local datastoreUsable = not (RunService:IsStudio() and game.GameId == 0)

if not datastoreUsable then
	warn(
		"[PlayerData] This place isn't published yet, so DataStore isn't available. "
			.. "Data works during this session but is NOT saved. To test saving: publish the place, "
			.. "then turn on Studio Access to API Services in Game Settings > Security."
	)
end

local store = datastoreUsable
		and DataStoreService:GetDataStore(DATASTORE_NAME)
	or nil

local sessionData = {} -- [player] = the table that came from the store
local canSave = {}     -- [player] = true only if their data loaded fine
local saving = {}      -- [player] = true while a save is running

local function keyFor(player)
	return "Player_" .. player.UserId
end

local function loadData(player)
	if not store then
		return false, nil
	end

	for attempt = 1, ATTEMPTS do
		local ok, result = pcall(store.GetAsync, store, keyFor(player))

		if ok then
			return true, result
		end

		warn("[PlayerData] load failed for " .. player.Name .. " (try " .. attempt .. "): " .. tostring(result))

		if attempt < ATTEMPTS then
			task.wait(attempt)
		end
	end

	return false, nil
end

local function saveData(player)
	if not store or not canSave[player] then
		return false
	end

	-- one save at a time per player
	while saving[player] do
		task.wait(0.1)
	end

	local data = sessionData[player]

	if not data then
		return false
	end

	for name, default in pairs(DEFAULTS) do
		local value = player:GetAttribute(name)

		if value == nil then
			value = default
		end

		data[name] = value
	end

	-- LastPosition is a Vector3, which DataStores can't hold directly
	local lastPosition = player:GetAttribute("LastPosition")

	if typeof(lastPosition) == "Vector3" then
		data.LastPosition = { x = lastPosition.X, y = lastPosition.Y, z = lastPosition.Z }
	else
		data.LastPosition = nil
	end

	saving[player] = true

	local ok, err

	for attempt = 1, ATTEMPTS do
		ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function()
				return data
			end)
		end)

		if ok then
			break
		end

		warn("[PlayerData] save failed for " .. player.Name .. " (try " .. attempt .. "): " .. tostring(err))

		if attempt < ATTEMPTS then
			task.wait(attempt)
		end
	end

	saving[player] = nil

	return ok
end

local function onPlayerAdded(player)
	local ok, saved = loadData(player)

	if not player.Parent then
		return -- left while loading
	end

	if not ok and store and not RunService:IsStudio() then
		-- never let someone play (and later overwrite their save) on empty data
		player:Kick("Your data could not be loaded. Please rejoin.")
		return
	end

	local data = type(saved) == "table" and saved or {}

	-- Money was renamed to Cash: carry old saves over
	if data.Cash == nil and tonumber(data.Money) then
		data.Cash = tonumber(data.Money)
	end

	sessionData[player] = data
	canSave[player] = ok -- if the load failed we never save over it

	for name, default in pairs(DEFAULTS) do
		local value = data[name]

		if typeof(default) == "boolean" then
			if typeof(value) ~= "boolean" then
				value = default
			end
		elseif typeof(default) == "string" then
			if typeof(value) ~= "string" then
				value = default
			end
		else
			value = tonumber(value) or default
		end

		player:SetAttribute(name, value)
	end

	-- LastPosition is stored as a plain {x, y, z} table; turn it back into a Vector3
	local savedPosition = data.LastPosition

	if typeof(savedPosition) == "table"
		and typeof(savedPosition.x) == "number"
		and typeof(savedPosition.y) == "number"
		and typeof(savedPosition.z) == "number" then
		player:SetAttribute("LastPosition", Vector3.new(savedPosition.x, savedPosition.y, savedPosition.z))
	end

	player:SetAttribute("DataLoaded", true)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- read-only look at anyone's save (the Profile search): ServerStorage.ReadSavedData:Invoke(userId)
do
	local reader = Instance.new("BindableFunction")
	reader.Name = "ReadSavedData"
	reader.OnInvoke = function(userId)
		if not store or type(userId) ~= "number" then
			return nil
		end
		local ok, result = pcall(store.GetAsync, store, "Player_" .. userId)
		return ok and type(result) == "table" and result or nil
	end
	reader.Parent = game:GetService("ServerStorage")
end

-- players who joined before this script started (Studio)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveData(player)

	sessionData[player] = nil
	canSave[player] = nil
end)

-- autosave
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)

		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(saveData, player)
		end
	end
end)

-- save everyone when the server shuts down
game:BindToClose(function()
	if not store then
		return
	end

	local pending = 0

	for _, player in ipairs(Players:GetPlayers()) do
		pending += 1

		task.spawn(function()
			saveData(player)
			pending -= 1
		end)
	end

	while pending > 0 or next(saving) ~= nil do
		task.wait(0.1)
	end
end)
