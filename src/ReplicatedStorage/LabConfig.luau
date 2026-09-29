-- THE LABORATORY (Workspace.Labratory) - a sub-island of Island 2.
-- A tycoon: step on a red button to build the next piece of the lab.
--   Chemistry Station  -> a mixing minigame on its screen makes Chemicals
--   Oxygen Generator   -> makes Oxygen (and a pump minigame for bursts)
--   Potion Brewer      -> Chemicals + Oxygen (+ CO2 later) = a random potion (luck!)
--   Potion Stand       -> sell your potions for Knowledge
--   Knowledge Shop     -> permanent upgrades, paid in Knowledge
-- Everything below can be tuned freely.
local LabConfig = {}

LabConfig.Currencies = {
	Chemicals = { attr = "Chemicals", icon = "rbxthumb://type=Asset&id=126431082865734&w=420&h=420", color = Color3.fromRGB(110, 235, 120) },
	Oxygen = { attr = "Oxygen", icon = "", color = Color3.fromRGB(120, 205, 255) },
	CarbonDioxide = { attr = "CarbonDioxide", icon = "", color = Color3.fromRGB(190, 195, 210), short = "CO2" },
	Knowledge = { attr = "Knowledge", icon = "rbxassetid://12691330734", color = Color3.fromRGB(255, 150, 220) },
}

-- where the lab is (currency rows, menu layout, hotbar)
LabConfig.Bounds = { center = Vector3.new(602, 20, -153), size = Vector3.new(112, 80, 162) }
function LabConfig.isInside(position)
	local b = LabConfig.Bounds
	local d = position - b.center
	return math.abs(d.X) <= b.size.X / 2 and math.abs(d.Z) <= b.size.Z / 2 and math.abs(d.Y) <= b.size.Y / 2
end

------------------------------------------------------------------------------------------
-- TYCOON PIECES (models: ReplicatedStorage.LabAssets.Items.<id>)
--   currency = what the red button costs.  after = what has to be built first.
--   button = where the red button sits (X, Z on the lab floor)
------------------------------------------------------------------------------------------
LabConfig.Items = {
	ChemistryStation = { name = "Chemistry Station", cost = 0, currency = "Chemicals", button = { 576, -121 },
		desc = "Mix Chemicals on its screen!" },
	MixingBench = { name = "Mixing Bench", cost = 30, currency = "Chemicals", after = "ChemistryStation", button = { 580, -131 },
		desc = "x2 Chemicals from every mix" },
	ChemTanks = { name = "Chemical Tanks", cost = 120, currency = "Chemicals", after = "MixingBench", button = { 591, -131 },
		desc = "+3 Chemicals every second" },
	OxygenGenerator = { name = "Oxygen Generator", cost = 350, currency = "Chemicals", after = "ChemTanks", button = { 568, -111 },
		desc = "Makes Oxygen + pump it for bursts" },
	PipeNetwork = { name = "Pipe Network", cost = 750, currency = "Chemicals", after = "OxygenGenerator", button = { 580, -111 },
		desc = "x1.5 Oxygen" },
	PotionBrewer = { name = "Potion Brewer", cost = 1200, currency = "Chemicals", after = "PipeNetwork", button = { 586, -121 },
		desc = "Brew random potions!" },
	LabWalls = { name = "Lab Walls", cost = 2000, currency = "Chemicals", after = "PotionBrewer", button = { 567, -131 },
		desc = "Make it look official" },
	CO2Extractor = { name = "CO2 Extractor", cost = 500, currency = "Oxygen", after = "PotionBrewer", button = { 591, -110 },
		desc = "Makes CO2 for better potions" },
	AdvancedBrewer = { name = "Advanced Brewer", cost = 12000, currency = "Chemicals", after = "CO2Extractor", button = { 603, -111 },
		desc = "Unlocks CO2 brews (x3 luck)" },
	ResearchComputers = { name = "Research Lab", cost = 30000, currency = "Chemicals", after = "AdvancedBrewer", button = { 556, -131 },
		desc = "+25% Knowledge from selling" },
	ReactorCore = { name = "Reactor Core", cost = 100000, currency = "Chemicals", after = "ResearchComputers", button = { 556, -111 },
		desc = "x2 Chemicals, Oxygen and CO2" },
	LabBeacon = { name = "Lab Beacon", cost = 400000, currency = "Chemicals", after = "ReactorCore", button = { 606, -139 },
		desc = "+25% brew luck (and it's huge)" },
}

LabConfig.Order = {
	"ChemistryStation", "MixingBench", "ChemTanks", "OxygenGenerator", "PipeNetwork", "PotionBrewer",
	"LabWalls", "CO2Extractor", "AdvancedBrewer", "ResearchComputers", "ReactorCore", "LabBeacon",
}

function LabConfig.ownedAttribute(id)
	return "LabOwned_" .. id
end

function LabConfig.owns(player, id)
	return player:GetAttribute(LabConfig.ownedAttribute(id)) == true
end

-- can this red button show up yet?
function LabConfig.available(player, id)
	local def = LabConfig.Items[id]
	return def ~= nil and not LabConfig.owns(player, id) and (def.after == nil or LabConfig.owns(player, def.after))
end

------------------------------------------------------------------------------------------
-- KNOWLEDGE SHOP (permanent upgrades). cost of the next level = floor(base * growth ^ level)
------------------------------------------------------------------------------------------
LabConfig.Upgrades = {
	{ id = "ChemMastery", name = "Chem Mastery", icon = "🧪", desc = "+50% Chemicals", max = 10, base = 10, growth = 1.9, per = 0.5 },
	{ id = "DeepBreath", name = "Deep Breath", icon = "💨", desc = "+50% Oxygen", max = 10, base = 15, growth = 1.9, per = 0.5 },
	{ id = "CarbonCapture", name = "Carbon Capture", icon = "🏭", desc = "+50% CO2", max = 10, base = 40, growth = 2, per = 0.5 },
	{ id = "LuckyBrew", name = "Lucky Brew", icon = "🍀", desc = "x1.25 brew luck", max = 8, base = 25, growth = 2.2, per = 0.25 },
	{ id = "Appraisal", name = "Appraisal", icon = "💰", desc = "+25% Knowledge from selling", max = 10, base = 20, growth = 2, per = 0.25 },
	{ id = "BulkBrew", name = "Bulk Brew", icon = "📦", desc = "+1 potion per brew", max = 4, base = 200, growth = 4, per = 1 },
}
LabConfig.UpgradeById = {}
for _, u in ipairs(LabConfig.Upgrades) do
	LabConfig.UpgradeById[u.id] = u
end

function LabConfig.upgradeAttribute(id)
	return "LabUp_" .. id
end

function LabConfig.level(player, id)
	return player:GetAttribute(LabConfig.upgradeAttribute(id)) or 0
end

function LabConfig.upgradeCost(id, level)
	local u = LabConfig.UpgradeById[id]
	return math.floor(u.base * u.growth ^ level)
end

------------------------------------------------------------------------------------------
-- PRODUCTION
------------------------------------------------------------------------------------------
LabConfig.Mix = {
	Base = 2, -- Chemicals per good mix
	PerfectBonus = 2, -- x2 for hitting the middle
	StreakMax = 10, -- every hit in a row adds +0.2x, up to x3
	StreakStep = 0.2,
	Zone = { 0.24, 0.12 }, -- size of the green zone: at streak 0 -> at max streak
	Speed = { 0.55, 0.95 }, -- marker speed (sweeps per second): at streak 0 -> at max streak
	Cooldown = 0.28,
}
LabConfig.Pump = {
	PerClick = 0.08, -- pressure per pump
	Decay = 0.12, -- pressure lost per second
	Burst = 8, -- Oxygen when the gauge is full
	Cooldown = 0.09,
}
LabConfig.Passive = {
	Chemicals = 3, -- per second (Chemical Tanks)
	Oxygen = 0.5, -- per second (Oxygen Generator)
	CarbonDioxide = 0.3, -- per second (CO2 Extractor)
}

------------------------------------------------------------------------------------------
-- LAB LEVELS (Lab Level board) and ADVANCEMENT MARKS (Advancement board)
--   Lab Level: costs Chemicals. Resets Chemicals, Oxygen, CO2 and every lab building
--              (the first red button is free again). Knowledge + the Knowledge Shop stay.
--              prod = x Chemicals, Oxygen and CO2.  luck = x brew luck.  sell = x Knowledge.
--   Advancement Mark: needs Lab Level MaxLevel. Resets Lab Levels, Knowledge and the Knowledge
--              Shop too. Values are the TOTAL bonus while you hold that mark (they don't stack).
------------------------------------------------------------------------------------------
LabConfig.Levels = {
	{ cost = 100e3, prod = 1.5, luck = 1.1, sell = 1 },
	{ cost = 350e3, prod = 2.25, luck = 1.2, sell = 1.15 },
	{ cost = 1e6, prod = 3.5, luck = 1.3, sell = 1.3, unlock = "Faster mixing streaks" },
	{ cost = 3.5e6, prod = 5, luck = 1.45, sell = 1.5 },
	{ cost = 10e6, prod = 8, luck = 1.6, sell = 1.75, unlock = "+1 potion per brew" },
	{ cost = 35e6, prod = 12, luck = 1.8, sell = 2 },
	{ cost = 100e6, prod = 18, luck = 2, sell = 2.5 },
	{ cost = 350e6, prod = 25, luck = 2.5, sell = 3, unlock = "Advancement Marks" },
}
LabConfig.MaxLevel = #LabConfig.Levels

LabConfig.Marks = {
	{ name = "Mark I", prod = 2, knowledge = 1.5, luck = 1.25 },
	{ name = "Mark II", prod = 3, knowledge = 2, luck = 1.5, bulk = 1 },
	{ name = "Mark III", prod = 5, knowledge = 3, luck = 1.75, bulk = 1 },
	{ name = "Mark IV", prod = 8, knowledge = 4, luck = 2, bulk = 2 },
	{ name = "Mark V", prod = 12, knowledge = 6, luck = 2.5, bulk = 3 },
}
LabConfig.MaxMark = #LabConfig.Marks

local NONE = { prod = 1, luck = 1, sell = 1, knowledge = 1, bulk = 0 }
function LabConfig.labLevel(player)
	return math.clamp(player:GetAttribute("LabLevel") or 0, 0, LabConfig.MaxLevel)
end
function LabConfig.labMark(player)
	return math.clamp(player:GetAttribute("LabMark") or 0, 0, LabConfig.MaxMark)
end
function LabConfig.levelDef(player)
	return LabConfig.Levels[LabConfig.labLevel(player)] or NONE
end
function LabConfig.markDef(player)
	return LabConfig.Marks[LabConfig.labMark(player)] or NONE
end
-- everything the levels + marks multiply production by
function LabConfig.progressProd(player)
	return (LabConfig.levelDef(player).prod or 1) * (LabConfig.markDef(player).prod or 1)
end
-- extra potions per brew from levels + marks
function LabConfig.extraPotions(player)
	return (LabConfig.labLevel(player) >= 5 and 1 or 0) + (LabConfig.markDef(player).bulk or 0)
end

-- mixing streak bonus per hit (Lab Level 3+ makes streaks worth more)
function LabConfig.streakStep(player)
	return LabConfig.Mix.StreakStep * (LabConfig.labLevel(player) >= 3 and 1.5 or 1)
end

local function up(player, id, per)
	return 1 + LabConfig.level(player, id) * per
end

function LabConfig.chemMultiplier(player)
	return up(player, "ChemMastery", 0.5) * (LabConfig.owns(player, "ReactorCore") and 2 or 1) * LabConfig.progressProd(player)
end
function LabConfig.oxygenMultiplier(player)
	return up(player, "DeepBreath", 0.5) * (LabConfig.owns(player, "PipeNetwork") and 1.5 or 1) * (LabConfig.owns(player, "ReactorCore") and 2 or 1)
		* LabConfig.progressProd(player)
end
function LabConfig.co2Multiplier(player)
	return up(player, "CarbonCapture", 0.5) * (LabConfig.owns(player, "ReactorCore") and 2 or 1) * LabConfig.progressProd(player)
end
function LabConfig.sellMultiplier(player)
	return up(player, "Appraisal", 0.25) * (LabConfig.owns(player, "ResearchComputers") and 1.25 or 1)
		* (LabConfig.levelDef(player).sell or 1) * (LabConfig.markDef(player).knowledge or 1)
end
function LabConfig.luck(player, brew)
	return (brew and brew.luck or 1) * (1.25 ^ LabConfig.level(player, "LuckyBrew")) * (LabConfig.owns(player, "LabBeacon") and 1.25 or 1)
		* (LabConfig.levelDef(player).luck or 1) * (LabConfig.markDef(player).luck or 1)
end

------------------------------------------------------------------------------------------
-- POTIONS (weight = how common; luck multiplies every non-Common weight)
------------------------------------------------------------------------------------------
LabConfig.Rarities = {
	Common = Color3.fromRGB(200, 205, 215), Uncommon = Color3.fromRGB(110, 230, 110), Rare = Color3.fromRGB(80, 170, 255),
	Epic = Color3.fromRGB(190, 100, 255), Legendary = Color3.fromRGB(255, 200, 40), Mythic = Color3.fromRGB(255, 80, 120),
	Godly = Color3.fromRGB(120, 255, 240),
}

LabConfig.Potions = {
	{ id = "Fizzy", name = "Fizzy Tonic", rarity = "Common", weight = 30, value = 5, color = Color3.fromRGB(150, 235, 120) },
	{ id = "Bubble", name = "Bubble Brew", rarity = "Common", weight = 25, value = 6, color = Color3.fromRGB(120, 200, 255) },
	{ id = "Speed", name = "Speed Serum", rarity = "Uncommon", weight = 14, value = 15, color = Color3.fromRGB(80, 230, 255) },
	{ id = "Glow", name = "Glow Juice", rarity = "Uncommon", weight = 11, value = 18, color = Color3.fromRGB(255, 240, 90) },
	{ id = "Strength", name = "Strength Elixir", rarity = "Rare", weight = 7, value = 45, color = Color3.fromRGB(255, 80, 80) },
	{ id = "Frost", name = "Frost Flask", rarity = "Rare", weight = 5, value = 55, color = Color3.fromRGB(190, 240, 255) },
	{ id = "Shadow", name = "Shadow Draught", rarity = "Epic", weight = 5.5, value = 150, color = Color3.fromRGB(150, 70, 255) },
	{ id = "Phoenix", name = "Phoenix Potion", rarity = "Legendary", weight = 2, value = 500, color = Color3.fromRGB(255, 140, 30) },
	{ id = "Cosmic", name = "Cosmic Concoction", rarity = "Mythic", weight = 0.45, value = 2000, color = Color3.fromRGB(255, 90, 220) },
	{ id = "Philosopher", name = "Philosopher's Brew", rarity = "Godly", weight = 0.05, value = 10000, color = Color3.fromRGB(255, 225, 90) },
}
LabConfig.PotionById = {}
for i, p in ipairs(LabConfig.Potions) do
	p.index = i
	LabConfig.PotionById[p.id] = p
end

-- brews: what they cost and how lucky they are
LabConfig.Brews = {
	{ id = "Basic", name = "Basic Brew", cost = { Chemicals = 40, Oxygen = 10 }, luck = 1, needs = "PotionBrewer" },
	{ id = "Advanced", name = "CO2 Brew", cost = { Chemicals = 150, Oxygen = 40, CarbonDioxide = 15 }, luck = 3, noCommon = true, needs = "AdvancedBrewer" },
}
LabConfig.BrewById = {}
for _, b in ipairs(LabConfig.Brews) do
	LabConfig.BrewById[b.id] = b
end

-- chance (0-1) of each potion for a brew, with the player's luck
function LabConfig.odds(player, brew)
	local luck = LabConfig.luck(player, brew)
	local weights, total = {}, 0
	for _, p in ipairs(LabConfig.Potions) do
		local w = p.weight
		if p.rarity ~= "Common" then
			w *= luck
		elseif brew and brew.noCommon then
			w = 0
		end
		weights[p.id] = w
		total += w
	end
	for id, w in pairs(weights) do
		weights[id] = w / total
	end
	return weights
end

function LabConfig.roll(player, brew, rng)
	local odds = LabConfig.odds(player, brew)
	local r = (rng and rng:NextNumber() or math.random())
	for _, p in ipairs(LabConfig.Potions) do
		r -= odds[p.id]
		if r <= 0 then
			return p
		end
	end
	return LabConfig.Potions[#LabConfig.Potions]
end

-- saved potion bag: { [potionId] = count }
local HttpService = game:GetService("HttpService")
function LabConfig.potions(player)
	local ok, t = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("LabPotions") or "{}")
	return ok and type(t) == "table" and t or {}
end
function LabConfig.encode(t)
	return HttpService:JSONEncode(t)
end

return LabConfig
