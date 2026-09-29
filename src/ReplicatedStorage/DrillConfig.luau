-- DRILLING MANIA (Island 1, Workspace.Islands.Island1.Zones.DrillZone)
--   Scrap field  -> walk near scrap to pick it up (Scrap)
--   Furnace      -> cook Scrap into Iron (attribute "Metal", shown as Iron)
--   Drill Shop   -> buy drills with Iron
--   Drill plots  -> buy land with Iron, place drills on it, drills pump Oil
--   Craft shop   -> Oil + Iron -> Coins
--   Enhancer     -> reset Drilling Mania for permanent multipliers
-- Everything here can be tuned freely.
local DrillConfig = {}

DrillConfig.Icons = {
	Scrap = "rbxassetid://126864658174743",
	Iron = "rbxassetid://112534478253431",
	Oil = "rbxthumb://type=Asset&id=11477042370&w=420&h=420",
	Coins = "rbxassetid://99928751746150",
}

-- the whole Drilling Mania area (currency rows + menu layout switch while you're inside)
DrillConfig.Bounds = { center = Vector3.new(-183, 10, -80), size = Vector3.new(114, 80, 140) }

function DrillConfig.isInside(position)
	local b = DrillConfig.Bounds
	local d = position - b.center
	return math.abs(d.X) <= b.size.X / 2 and math.abs(d.Z) <= b.size.Z / 2 and math.abs(d.Y) <= b.size.Y / 2
end

------------------------------------------------------------------------------------------
-- SCRAP (Workspace.SpawnPart)
------------------------------------------------------------------------------------------
DrillConfig.Scrap = {
	-- base numbers; the Scrap Upgrades board improves them
	Interval = 1.5, -- seconds between spawns (Upgrade ScrapSpawnSpeed)
	Capacity = 20, -- scrap on the field at once (Upgrade ScrapCapacity)
	Bulk = 1, -- scrap per spawn (Upgrade ScrapBulk)
	Range = 6, -- pickup radius in studs (Upgrade ScrapRange)
	-- what can spawn: model name in ReplicatedStorage.Scrap, weight, Scrap value
	Kinds = {
		{ model = "Screw", weight = 50, value = 1 },
		{ model = "Nut", weight = 30, value = 2 },
		{ model = "Gear", weight = 15, value = 4 },
		{ model = "Pipe", weight = 5, value = 10 },
	},
}

------------------------------------------------------------------------------------------
-- FURNACE (Workspace.Furnace)
------------------------------------------------------------------------------------------
DrillConfig.Furnace = {
	ScrapPerIron = 5, -- 5 Scrap -> 1 Iron (before Iron Yield)
	MinScrap = 5, -- need at least this much to start
	BaseSeconds = 4, -- every batch takes at least this long...
	SecondsPerScrap = 0.04, -- ...plus this per Scrap put in
	MaxSeconds = 90, -- never longer than this (before Furnace Speed)
	Cooldown = 10, -- seconds after claiming before it can be used again (the overhead countdown)
	Percents = { 25, 50, 100 },
}

function DrillConfig.furnaceSeconds(scrap, speed)
	local f = DrillConfig.Furnace
	local t = math.min(f.BaseSeconds + scrap * f.SecondsPerScrap, f.MaxSeconds)
	return t / math.max(speed or 1, 0.01)
end

------------------------------------------------------------------------------------------
-- DRILLS (models in ReplicatedStorage.Drills). price is in Iron, rate is Oil per second.
------------------------------------------------------------------------------------------
DrillConfig.Rarities = {
	Common = Color3.fromRGB(200, 205, 215),
	Uncommon = Color3.fromRGB(110, 230, 110),
	Rare = Color3.fromRGB(80, 170, 255),
	Epic = Color3.fromRGB(190, 100, 255),
	Legendary = Color3.fromRGB(255, 200, 40),
	Mythic = Color3.fromRGB(255, 80, 120),
	Godly = Color3.fromRGB(120, 255, 240),
}

-- UseDrillModels: false = every drill uses the built-in look (works everywhere).
-- Only turn it on once the drill meshes in ReplicatedStorage.Drills are uploaded to / shared
-- with THIS game (otherwise the live game shows only bits of them).
DrillConfig.UseDrillModels = false

-- model = a model in ReplicatedStorage.Drills. If its meshes can't load in this game (they
-- belong to another creator), a built-in drill is drawn instead in `body` / `accent` colours.
DrillConfig.Drills = {
	{ id = "Rusty", name = "Rusty Drill", model = "Drill1", rarity = "Common", rate = 3, price = 10,
		body = Color3.fromRGB(150, 95, 60), accent = Color3.fromRGB(110, 110, 115) },
	{ id = "Copper", name = "Copper Drill", model = "Drill2", rarity = "Common", rate = 6, price = 60,
		body = Color3.fromRGB(205, 120, 70), accent = Color3.fromRGB(240, 170, 110) },
	{ id = "Bronze", name = "Bronze Drill", model = "Drill4", rarity = "Uncommon", rate = 12, price = 250,
		body = Color3.fromRGB(170, 120, 55), accent = Color3.fromRGB(110, 230, 110) },
	{ id = "Twin", name = "Twin Drill", model = "Drill8", rarity = "Uncommon", rate = 22, price = 800,
		body = Color3.fromRGB(90, 150, 90), accent = Color3.fromRGB(200, 255, 170), bits = 2 },
	{ id = "Steam", name = "Steam Drill", model = "SteampunkDrill1", rarity = "Rare", rate = 40, price = 2500,
		body = Color3.fromRGB(120, 85, 50), accent = Color3.fromRGB(235, 185, 70), smoke = true },
	{ id = "Fusion", name = "Fusion Drill", model = "FusionDrill", rarity = "Rare", rate = 70, price = 8000,
		body = Color3.fromRGB(60, 110, 200), accent = Color3.fromRGB(90, 220, 255), glow = true },
	{ id = "Heavy", name = "Heavy Drill", model = "Drill6", rarity = "Epic", rate = 125, price = 25000,
		body = Color3.fromRGB(80, 70, 110), accent = Color3.fromRGB(200, 120, 255), bits = 2, glow = true },
	{ id = "Frost", name = "Frost Drill", model = "IceDrill1", rarity = "Epic", rate = 225, price = 80000,
		body = Color3.fromRGB(150, 200, 235), accent = Color3.fromRGB(210, 245, 255), glow = true, sparkle = Color3.fromRGB(200, 240, 255) },
	{ id = "Molten", name = "Molten Drill", model = "MoltenDrill", rarity = "Legendary", rate = 420, price = 250000,
		body = Color3.fromRGB(60, 35, 30), accent = Color3.fromRGB(255, 120, 30), glow = true, sparkle = Color3.fromRGB(255, 140, 40) },
	{ id = "Laser", name = "Laser Drill", model = "GreenBeamDrill", rarity = "Legendary", rate = 780, price = 800000,
		body = Color3.fromRGB(40, 45, 55), accent = Color3.fromRGB(80, 255, 110), bits = 3, glow = true, sparkle = Color3.fromRGB(120, 255, 140) },
	{ id = "DarkMatter", name = "Dark Matter Drill", model = "DarkMatterDrill1", rarity = "Mythic", rate = 1500, price = 2.5e6,
		body = Color3.fromRGB(30, 20, 45), accent = Color3.fromRGB(170, 60, 255), bits = 2, glow = true, sparkle = Color3.fromRGB(190, 90, 255) },
	{ id = "Nuclear", name = "Nuclear Drill", model = "Nuclear3", rarity = "Mythic", rate = 3000, price = 8e6,
		body = Color3.fromRGB(60, 65, 45), accent = Color3.fromRGB(190, 255, 40), bits = 3, glow = true, sparkle = Color3.fromRGB(200, 255, 60) },
	{ id = "Godly", name = "Godly Drill", model = "GodlyDrill4", rarity = "Godly", rate = 6500, price = 2.5e7,
		body = Color3.fromRGB(245, 240, 225), accent = Color3.fromRGB(255, 210, 60), bits = 3, glow = true, sparkle = Color3.fromRGB(255, 235, 120) },
	{ id = "Celestial", name = "Celestial Drill", model = "CelestialNexusDrill", rarity = "Godly", rate = 15000, price = 1e8,
		body = Color3.fromRGB(35, 40, 90), accent = Color3.fromRGB(120, 255, 240), bits = 4, glow = true, sparkle = Color3.fromRGB(150, 255, 255) },
}

DrillConfig.DrillById = {}
for i, d in ipairs(DrillConfig.Drills) do
	d.index = i
	DrillConfig.DrillById[d.id] = d
end

------------------------------------------------------------------------------------------
-- DRILL SHOP STOCK (like Grow a Garden): the shop restocks every RestockSeconds for
-- everyone at the same time. Each drill has a chance to be in stock and a stock count;
-- buying one uses up one. A Robux restock (Developer Product) rerolls just your shop.
------------------------------------------------------------------------------------------
DrillConfig.Stock = {
	RestockSeconds = 300, -- 5 minutes
	RestockProductId = 0, -- your 15 Robux Developer Product id goes here
	RestockPrice = 15, -- shown on the button
	-- per rarity: % chance to show up in a restock, and how many are in stock when it does
	Rarity = {
		Common = { chance = 100, min = 3, max = 6 },
		Uncommon = { chance = 80, min = 2, max = 4 },
		Rare = { chance = 55, min = 1, max = 3 },
		Epic = { chance = 35, min = 1, max = 2 },
		Legendary = { chance = 18, min = 1, max = 1 },
		Mythic = { chance = 8, min = 1, max = 1 },
		Godly = { chance = 3, min = 1, max = 1 },
	},
}

function DrillConfig.stockWindow(serverTime)
	return math.floor(serverTime / DrillConfig.Stock.RestockSeconds)
end

-- rolls a shop: { [drillId] = count }. The same seed gives the same shop, so everyone in
-- a restock window sees the same drills (a Robux restock uses its own seed).
function DrillConfig.rollStock(seed)
	local rng = Random.new(seed)
	local stock = {}
	for _, d in ipairs(DrillConfig.Drills) do
		local r = DrillConfig.Stock.Rarity[d.rarity] or { chance = 50, min = 1, max = 1 }
		if rng:NextNumber(0, 100) < r.chance then
			stock[d.id] = rng:NextInteger(r.min, r.max)
		end
	end
	return stock
end

function DrillConfig.stock(player)
	return DrillConfig.decode(player:GetAttribute("DrillStock"))
end

-- a drill holds this many seconds of Oil before it's full (walk up to it to collect)
DrillConfig.StorageSeconds = 300
DrillConfig.MaxOwnedPerDrill = 99

------------------------------------------------------------------------------------------
-- PLOTS (Workspace.Full is the grass cover; buying a plot uncovers the dirt beneath)
------------------------------------------------------------------------------------------
DrillConfig.Grid = { cols = 5, rows = 5 } -- 5 x 5 = 25 plots
DrillConfig.PlotPrices = { -- in Iron; plot 1 is free
	0, 25, 75, 200, 500, 1200, 3000, 7500, 18000, 45000,
	1.1e5, 2.75e5, 7e5, 1.75e6, 4.5e6, 1.1e7, 2.8e7, 7e7, 1.75e8, 4.5e8,
	1.1e9, 2.8e9, 7e9, 1.8e10, 4.5e10,
}
DrillConfig.MaxPlots = #DrillConfig.PlotPrices

-- where plot `index` sits, in Workspace.Full's local space (X/Z), starting at the corner
-- where the red button starts and going row by row
function DrillConfig.cellOffset(index, fullSize)
	local g = DrillConfig.Grid
	local col = (index - 1) % g.cols
	local row = math.floor((index - 1) / g.cols)
	local cw, ch = fullSize.X / g.cols, fullSize.Z / g.rows
	return Vector3.new(fullSize.X / 2 - cw / 2 - col * cw, 0, fullSize.Z / 2 - ch / 2 - row * ch), cw, ch
end

------------------------------------------------------------------------------------------
-- CRAFTING (Workspace.Craft): Oil + Iron -> Coins
------------------------------------------------------------------------------------------
DrillConfig.Recipes = {
	{ id = "Pouch", name = "Coin Pouch", oil = 50, iron = 5, coins = 10, color = Color3.fromRGB(255, 215, 80) },
	{ id = "Stack", name = "Coin Stack", oil = 600, iron = 30, coins = 150, color = Color3.fromRGB(255, 180, 50) },
	{ id = "Chest", name = "Coin Chest", oil = 8000, iron = 250, coins = 2500, color = Color3.fromRGB(255, 140, 40) },
	{ id = "Vault", name = "Coin Vault", oil = 120000, iron = 2000, coins = 45000, color = Color3.fromRGB(255, 90, 60) },
}
DrillConfig.RecipeById = {}
for _, r in ipairs(DrillConfig.Recipes) do
	DrillConfig.RecipeById[r.id] = r
end

------------------------------------------------------------------------------------------
-- ENHANCER (Workspace["Enhancer-tiererset"]): reset Drilling Mania for permanent boosts.
-- Each tier needs that much Oil in hand. Boosts stack (tier 2 keeps tier 1's too).
------------------------------------------------------------------------------------------
DrillConfig.Enhancer = {
	{ name = "Bronze Enhance", oil = 25000, color = Color3.fromRGB(230, 140, 70), boosts = { scrap = 2, oil = 1.5 } },
	{ name = "Silver Enhance", oil = 750000, color = Color3.fromRGB(200, 215, 235), boosts = { iron = 2, oil = 2 } },
	{ name = "Gold Enhance", oil = 2.5e7, color = Color3.fromRGB(255, 205, 50), boosts = { coins = 3, oil = 2, scrap = 2 } },
}

-- what an Enhance resets
DrillConfig.ResetCurrencies = { "Scrap", "Metal", "Oil" }

function DrillConfig.enhanceBoost(player, kind)
	local tier = player:GetAttribute("DrillEnhance") or 0
	local m = 1
	for i = 1, math.min(tier, #DrillConfig.Enhancer) do
		m *= DrillConfig.Enhancer[i].boosts[kind] or 1
	end
	return m
end

------------------------------------------------------------------------------------------
-- saved data helpers
------------------------------------------------------------------------------------------
function DrillConfig.oilAttribute(cell)
	return "DrillOil_" .. cell
end

local HttpService = game:GetService("HttpService")
function DrillConfig.decode(text)
	local ok, t = pcall(HttpService.JSONDecode, HttpService, text or "{}")
	return ok and type(t) == "table" and t or {}
end
function DrillConfig.encode(t)
	return HttpService:JSONEncode(t)
end

-- inventory: { [drillId] = count }   placed: { ["cell"] = drillId }
function DrillConfig.inventory(player)
	return DrillConfig.decode(player:GetAttribute("DrillInv"))
end
function DrillConfig.placed(player)
	return DrillConfig.decode(player:GetAttribute("DrillPlaced"))
end

return DrillConfig
