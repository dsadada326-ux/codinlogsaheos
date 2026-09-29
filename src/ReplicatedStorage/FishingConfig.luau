-- Fishing Frenzy (Island 1's sub-island): everything about fishing lives here, shared by the
-- server (FishingService = the real rules) and every fishing client script.
--
-- Currencies:  FishMeal  sell fish for it; buys rods, auto-fishers and Fish Tiers
--              Shells    walk over shells on the sand; buys Shell Upgrades
--              Crabs     convert Fish Meal on the Conversion board (Tier 3+); only buys Fishing tree nodes
-- Progress:    FishTier 0-8 (Fish Tier board)  ->  FishPrestige 0-3 (Prestige board, needs max tier)
local PrestigeConfig = require(script.Parent:WaitForChild("PrestigeConfig"))
local RuneConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("RuneConfig"))

local FishingConfig = {}

FishingConfig.IslandName = "FishingFrenzySub-1"

------------------------------------------------------------------------------------------
-- rarities (weights before Luck). Luck makes every rarer tier more likely:
--   weight = base * luck ^ (LuckExponent * (rarity index - 1))
------------------------------------------------------------------------------------------
FishingConfig.LuckExponent = 0.2 -- 8 tiers: gentler than before so the top ones stay rare

FishingConfig.Rarities = {
	{ name = "Common", weight = 60, color = Color3.fromRGB(215, 215, 215) },
	{ name = "Rare", weight = 26, color = Color3.fromRGB(70, 165, 255) },
	{ name = "Epic", weight = 10, color = Color3.fromRGB(185, 95, 255) },
	{ name = "Legendary", weight = 3.2, color = Color3.fromRGB(255, 195, 40) },
	{ name = "Mythic", weight = 0.7, color = Color3.fromRGB(255, 70, 150) },
	{ name = "Abyssal", weight = 0.09, color = Color3.fromRGB(80, 90, 255) },
	{ name = "Astral", weight = 0.01, color = Color3.fromRGB(60, 255, 230) },
	{ name = "Heavenly", weight = 0.001, color = Color3.fromRGB(255, 245, 160) },
}

FishingConfig.RarityIndex = {}
for i, r in ipairs(FishingConfig.Rarities) do
	FishingConfig.RarityIndex[r.name] = i
end

------------------------------------------------------------------------------------------
-- fish (models: ReplicatedStorage.FishingAssets.Fish[id], imported from Workspace.FishModels).
-- value = Fish Meal for an average-size one (bigger fish are worth more). length = how long
-- the held model is, in studs.
------------------------------------------------------------------------------------------
FishingConfig.Fish = {
	-- Common
	{ id = "Goldfish", name = "Goldfish", rarity = "Common", value = 6, kg = { 0.87, 3.5 }, length = 2.4 },
	{ id = "ClownFish", name = "Clownfish", rarity = "Common", value = 7, kg = { 0.95, 3.8 }, length = 2.4 },
	{ id = "Starfish", name = "Starfish", rarity = "Common", value = 8, kg = { 0.1, 0.3 }, length = 2.4 },
	{ id = "Stingray", name = "Stingray", rarity = "Common", value = 8, kg = { 2.6, 10.4 }, length = 2.4 },
	{ id = "Pufferfish", name = "Pufferfish", rarity = "Common", value = 9, kg = { 0.92, 3.7 }, length = 2.4 },
	{ id = "Seahorse", name = "Seahorse", rarity = "Common", value = 10, kg = { 0.63, 2.5 }, length = 1.5 },
	{ id = "Snowfish", name = "Snowfish", rarity = "Common", value = 11, kg = { 2.78, 11.1 }, length = 2.4 },
	{ id = "HaloMinnow", name = "Halo Minnow", rarity = "Common", value = 11, kg = { 1.38, 5.5 }, length = 2.4 },
	-- Rare
	{ id = "ButterflyFish", name = "Butterfly Fish", rarity = "Rare", value = 35, kg = { 1.73, 6.9 }, length = 2 },
	{ id = "Penguin", name = "Penguin", rarity = "Rare", value = 41, kg = { 0.58, 2.3 }, length = 2.2 },
	{ id = "Crocodile", name = "Crocodile", rarity = "Rare", value = 48, kg = { 8.24, 33.0 }, length = 2.9 },
	{ id = "Jellyfish", name = "Jellyfish", rarity = "Rare", value = 54, kg = { 1.77, 7.1 }, length = 2.9 },
	{ id = "SeaTurtle", name = "Sea Turtle", rarity = "Rare", value = 60, kg = { 2.42, 9.7 }, length = 2.9 },
	{ id = "CloudshellTurtle", name = "Cloudshell Turtle", rarity = "Rare", value = 66, kg = { 1.41, 5.6 }, length = 2.9 },
	-- Epic
	{ id = "Shark", name = "Shark", rarity = "Epic", value = 200, kg = { 4.8, 19.2 }, length = 3.3 },
	{ id = "MohawkTang", name = "Mohawk Tang", rarity = "Epic", value = 220, kg = { 1.41, 5.6 }, length = 2.2 },
	{ id = "Seal", name = "Seal", rarity = "Epic", value = 250, kg = { 4.5, 18.0 }, length = 3.3 },
	{ id = "KingNewt", name = "King Newt", rarity = "Epic", value = 270, kg = { 3.23, 12.9 }, length = 3.3 },
	{ id = "Walrus", name = "Walrus", rarity = "Epic", value = 290, kg = { 3.98, 15.9 }, length = 3.3 },
	{ id = "SeaToad", name = "Sea Toad", rarity = "Epic", value = 310, kg = { 0.7, 2.8 }, length = 3.3 },
	{ id = "ChickenFish", name = "Chicken Fish", rarity = "Epic", value = 340, kg = { 2.38, 9.5 }, length = 3.3 },
	{ id = "SeraphSeahorse", name = "Seraph Seahorse", rarity = "Epic", value = 360, kg = { 1.55, 6.2 }, length = 2.5 },
	{ id = "MutantPiranha", name = "Mutant Piranha", rarity = "Epic", value = 380, kg = { 1.62, 6.5 }, length = 3.3 },
	-- Legendary
	{ id = "Swordfish", name = "Swordfish", rarity = "Legendary", value = 1200, kg = { 11.42, 45.7 }, length = 3.7 },
	{ id = "PurpleOctupus", name = "Purple Octopus", rarity = "Legendary", value = 1300, kg = { 3.92, 15.7 }, length = 3.7 },
	{ id = "Dolphin", name = "Dolphin", rarity = "Legendary", value = 1400, kg = { 5.38, 21.5 }, length = 3.7 },
	{ id = "Squid", name = "Squid", rarity = "Legendary", value = 1400, kg = { 5.25, 21.0 }, length = 3.7 },
	{ id = "SeaKitty", name = "Sea Kitty", rarity = "Legendary", value = 1500, kg = { 4.03, 16.1 }, length = 3.7 },
	{ id = "ArchangelDolphin", name = "Archangel Dolphin", rarity = "Legendary", value = 1600, kg = { 2.74, 11.0 }, length = 3.7 },
	{ id = "Cloudfish", name = "Cloudfish", rarity = "Legendary", value = 1700, kg = { 1.66, 6.6 }, length = 3.7 },
	{ id = "DreamBunnyfish", name = "Dream Bunnyfish", rarity = "Legendary", value = 1700, kg = { 1.58, 6.3 }, length = 3.7 },
	{ id = "VenomFrog", name = "Venom Frog", rarity = "Legendary", value = 1800, kg = { 3.08, 12.3 }, length = 3.7 },
	{ id = "ToxicFishBear", name = "Toxic Fish Bear", rarity = "Legendary", value = 1900, kg = { 7.76, 31.0 }, length = 3.7 },
	{ id = "DustMiteMinnow", name = "Dust Mite Minnow", rarity = "Legendary", value = 2000, kg = { 1.28, 5.1 }, length = 3.7 },
	{ id = "OrbitingArchfish", name = "Orbiting Archfish", rarity = "Legendary", value = 2000, kg = { 3.75, 15.0 }, length = 3.7 },
	{ id = "PhotonicMudskipper", name = "Photonic Mudskipper", rarity = "Legendary", value = 2100, kg = { 2.38, 9.5 }, length = 3.7 },
	{ id = "MeteorSiphono", name = "Meteor Siphono", rarity = "Legendary", value = 2200, kg = { 5.06, 20.2 }, length = 3.7 },
	{ id = "PulsarAxolotl", name = "Pulsar Axolotl", rarity = "Legendary", value = 2300, kg = { 2.78, 11.1 }, length = 3.7 },
	-- Mythic
	{ id = "FireFish", name = "Fire Fish", rarity = "Mythic", value = 9000, kg = { 2.04, 8.2 }, length = 4.1 },
	{ id = "Orca", name = "Orca", rarity = "Mythic", value = 9600, kg = { 8.4, 33.6 }, length = 4.1 },
	{ id = "Axolotl", name = "Axolotl", rarity = "Mythic", value = 10000, kg = { 4.09, 16.4 }, length = 4.1 },
	{ id = "MagicFish", name = "Magic Fish", rarity = "Mythic", value = 11000, kg = { 2.16, 8.7 }, length = 4.1 },
	{ id = "AnglerFish", name = "Angler Fish", rarity = "Mythic", value = 11000, kg = { 5.06, 20.2 }, length = 4.1 },
	{ id = "CoconutCrab", name = "Coconut Crab", rarity = "Mythic", value = 12000, kg = { 4.8, 19.2 }, length = 4.1 },
	{ id = "CelestialManta", name = "Celestial Manta", rarity = "Mythic", value = 12000, kg = { 4.8, 19.2 }, length = 3.9 },
	{ id = "DreamNautilus", name = "Dream Nautilus", rarity = "Mythic", value = 13000, kg = { 4.87, 19.5 }, length = 4.1 },
	{ id = "MutantCrocodile", name = "Mutant Crocodile", rarity = "Mythic", value = 14000, kg = { 14.04, 56.2 }, length = 4.1 },
	{ id = "RadioactiveCrab", name = "Radioactive Crab", rarity = "Mythic", value = 14000, kg = { 3.65, 14.6 }, length = 4.1 },
	{ id = "GammaHammerhead", name = "Gamma Hammerhead", rarity = "Mythic", value = 15000, kg = { 4.44, 17.8 }, length = 4.1 },
	{ id = "NebulaLamprey", name = "Nebula Lamprey", rarity = "Mythic", value = 15000, kg = { 5.85, 23.4 }, length = 4.1 },
	{ id = "QuasarGoldfish", name = "Quasar Goldfish", rarity = "Mythic", value = 16000, kg = { 2.83, 11.3 }, length = 4.1 },
	{ id = "GorgonianStarCoral", name = "Gorgonian Star Coral", rarity = "Mythic", value = 17000, kg = { 2.12, 8.5 }, length = 4.1 },
	{ id = "SolarPufferSquid", name = "Solar Puffer Squid", rarity = "Mythic", value = 17000, kg = { 0.92, 3.7 }, length = 4.1 },
	-- Abyssal
	{ id = "FishLobster", name = "Fish Lobster", rarity = "Abyssal", value = 90000, kg = { 2.29, 9.2 }, length = 4.5 },
	{ id = "Thunderfin", name = "Thunderfin", rarity = "Abyssal", value = 97000, kg = { 2.29, 9.2 }, length = 4.5 },
	{ id = "Whale", name = "Whale", rarity = "Abyssal", value = 100000, kg = { 10.58, 42.3 }, length = 4.5 },
	{ id = "HappyScallop", name = "Happy Scallop", rarity = "Abyssal", value = 110000, kg = { 0.15, 0.6 }, length = 4.5 },
	{ id = "CandyUnicorn", name = "Candy Unicorn", rarity = "Abyssal", value = 120000, kg = { 4.09, 16.4 }, length = 4.5 },
	{ id = "DarkAngelSquid", name = "Dark Angel Squid", rarity = "Abyssal", value = 120000, kg = { 2.42, 9.7 }, length = 4.1 },
	{ id = "MoonJellyfish", name = "Moon Jellyfish", rarity = "Abyssal", value = 130000, kg = { 2.25, 9.0 }, length = 3.4 },
	{ id = "ToxicTurtle", name = "Toxic Turtle", rarity = "Abyssal", value = 140000, kg = { 4.32, 17.3 }, length = 4.5 },
	{ id = "PlasmaStoneCrab", name = "Plasma Stone Crab", rarity = "Abyssal", value = 140000, kg = { 1.38, 5.5 }, length = 4.5 },
	{ id = "RoboticSawfish", name = "Robotic Sawfish", rarity = "Abyssal", value = 150000, kg = { 7.76, 31.0 }, length = 4.5 },
	{ id = "EclipseUrchin", name = "Eclipse Urchin", rarity = "Abyssal", value = 160000, kg = { 2.25, 9.0 }, length = 4.5 },
	{ id = "CometUnicornfish", name = "Comet Unicornfish", rarity = "Abyssal", value = 160000, kg = { 3.59, 14.4 }, length = 4.5 },
	{ id = "MilkywayCrab", name = "Milkyway Crab", rarity = "Abyssal", value = 170000, kg = { 2.16, 8.7 }, length = 4.5 },
	-- Astral
	{ id = "Cloudray", name = "Cloudray", rarity = "Astral", value = 1000000, kg = { 5.51, 22.0 }, length = 4.5 },
	{ id = "Skullfish", name = "Skullfish", rarity = "Astral", value = 1100000, kg = { 9.25, 37.0 }, length = 4.9 },
	{ id = "DragonFish", name = "Dragon Fish", rarity = "Astral", value = 1200000, kg = { 18.61, 74.4 }, length = 4.9 },
	{ id = "MoonShark", name = "Moon Shark", rarity = "Astral", value = 1200000, kg = { 8.08, 32.3 }, length = 4.9 },
	{ id = "Crystalfin", name = "Crystalfin", rarity = "Astral", value = 1300000, kg = { 5.78, 23.1 }, length = 4.9 },
	{ id = "FishGiraffe", name = "Fish Giraffe", rarity = "Astral", value = 1400000, kg = { 5.85, 23.4 }, length = 4.9 },
	{ id = "HeavenLeviathan", name = "Heaven Leviathan", rarity = "Astral", value = 1400000, kg = { 7.14, 28.6 }, length = 4.9 },
	{ id = "SleepyWhale", name = "Sleepy Whale", rarity = "Astral", value = 1500000, kg = { 9.33, 37.3 }, length = 4.9 },
	{ id = "ToxicSeaDragon", name = "Toxic Sea Dragon", rarity = "Astral", value = 1600000, kg = { 22.58, 90.3 }, length = 4.9 },
	{ id = "GravitonEel", name = "Graviton Eel", rarity = "Astral", value = 1700000, kg = { 4.5, 18.0 }, length = 4.9 },
	{ id = "DarkMatterSeadog", name = "Dark Matter Seadog", rarity = "Astral", value = 1800000, kg = { 3.43, 13.7 }, length = 4.9 },
	{ id = "SuperclusterKraken", name = "Supercluster Kraken", rarity = "Astral", value = 1800000, kg = { 2.51, 10.0 }, length = 4.9 },
	{ id = "AuroraNudibranch", name = "Aurora Nudibranch", rarity = "Astral", value = 1900000, kg = { 1.19, 4.7 }, length = 4.9 },
	-- Heavenly
	{ id = "LionFlameFish", name = "Lion Flame Fish", rarity = "Heavenly", value = 15000000, kg = { 5.85, 23.4 }, length = 5.3 },
	{ id = "ThroneNimbus", name = "Throne Nimbus", rarity = "Heavenly", value = 17000000, kg = { 4.93, 19.7 }, length = 5.3 },
	{ id = "DreamAxolotl", name = "Dream Axolotl", rarity = "Heavenly", value = 19000000, kg = { 4.21, 16.8 }, length = 5.3 },
	{ id = "WastelandShark", name = "Wasteland Shark", rarity = "Heavenly", value = 21000000, kg = { 10.4, 41.6 }, length = 5.3 },
	{ id = "ChronosDreadWhale", name = "Chronos Dread Whale", rarity = "Heavenly", value = 23000000, kg = { 12.3, 49.2 }, length = 5.3 },
	{ id = "WormholeMoray", name = "Wormhole Moray", rarity = "Heavenly", value = 25000000, kg = { 4.44, 17.8 }, length = 5.3 },
	{ id = "SingularityManta", name = "Singularity Manta", rarity = "Heavenly", value = 27000000, kg = { 5.12, 20.5 }, length = 5.3 },
	{ id = "SupernovaClam", name = "Supernova Clam", rarity = "Heavenly", value = 28000000, kg = { 1.51, 6.1 }, length = 5.3 },
}

FishingConfig.FishById = {}
FishingConfig.FishByRarity = {}
for _, f in ipairs(FishingConfig.Fish) do
	FishingConfig.FishById[f.id] = f
	FishingConfig.FishByRarity[f.rarity] = FishingConfig.FishByRarity[f.rarity] or {}
	table.insert(FishingConfig.FishByRarity[f.rarity], f)
end

------------------------------------------------------------------------------------------
-- rods (models: ReplicatedStorage.FishingAssets.Rods[model]). luck multiplies rarity odds,
-- speed divides the bite wait. Saved as Rod_<id> = true; EquippedRod = index in this list.
------------------------------------------------------------------------------------------
FishingConfig.Rods = {
	{ id = "Wooden", model = "Wooden Rod", price = 0, luck = 1, speed = 1 },
	{ id = "Bronze", model = "Bronze Rod", price = 100, luck = 1.15, speed = 1.05 },
	{ id = "Steel", model = "Steel Rod", price = 350, luck = 1.3, speed = 1.1 },
	{ id = "Iron", model = "Iron Rod", price = 1e3, luck = 1.5, speed = 1.15 },
	{ id = "SteelRope", model = "Steel Rope Rod", price = 3e3, luck = 1.75, speed = 1.2 },
	{ id = "IronRope", model = "Iron Rope Rod", price = 8e3, luck = 2, speed = 1.25 },
	{ id = "FullBronze", model = "Full Bronze Rod", price = 2e4, luck = 2.3, speed = 1.3 },
	{ id = "FullSteel", model = "Full Steel Rod", price = 5e4, luck = 2.7, speed = 1.35 },
	{ id = "SteelGold", model = "Steel Gold Rod", price = 1.2e5, luck = 3.1, speed = 1.4 },
	{ id = "Gold", model = "Gold Rod", price = 3e5, luck = 3.6, speed = 1.45 },
	{ id = "GoldDiamond", model = "Gold Diamond Rod", price = 7.5e5, luck = 4.2, speed = 1.5 },
	{ id = "Ruby", model = "Ruby Rod", price = 2e6, luck = 5, speed = 1.55 },
	{ id = "Crystal", model = "Crystal Rod", price = 5e6, luck = 6, speed = 1.6 },
	{ id = "Emerald", model = "Emerald Rod", price = 1.2e7, luck = 7, speed = 1.65 },
	{ id = "Toxic", model = "Toxic Rod", price = 3e7, luck = 8.5, speed = 1.7 },
	{ id = "Frozen", model = "Frozen Rod", price = 7.5e7, luck = 10, speed = 1.75 },
	{ id = "Knight", model = "Knight Rod", price = 2e8, luck = 12, speed = 1.8 },
	{ id = "Obsidian", model = "Obsidian Rod", price = 5e8, luck = 14, speed = 1.85 },
	{ id = "Galaxy", model = "Galaxy Rod", price = 1.2e9, luck = 17, speed = 1.9 },
	{ id = "Angel", model = "Angel Rod", price = 3e9, luck = 20, speed = 2 },
	{ id = "UFO", model = "UFO Rod", price = 8e9, luck = 24, speed = 2.1 },
	{ id = "Disco", model = "Disco Rod", price = 2e10, luck = 28, speed = 2.2 },
	{ id = "Plasma", model = "Plasma Rod", price = 5e10, luck = 33, speed = 2.3 },
	{ id = "Nova", model = "Nova Rod", price = 1.25e11, luck = 38, speed = 2.4 },
	{ id = "Genesis", model = "Genesis Rod", price = 3e11, luck = 44, speed = 2.5 },
	{ id = "Stellar", model = "Stellar Rod", price = 7.5e11, luck = 50, speed = 2.65 },
	{ id = "Cosmic", model = "Cosmic Rod", price = 2e12, luck = 57, speed = 2.8 },
	{ id = "Divine", model = "Divine Rod", price = 5e12, luck = 65, speed = 3 },
}

FishingConfig.RodIndex = {}
for i, r in ipairs(FishingConfig.Rods) do
	r.name = r.model
	FishingConfig.RodIndex[r.id] = i
end

function FishingConfig.rodAttribute(id)
	return "Rod_" .. id
end

function FishingConfig.ownsRod(player, id)
	return id == "Wooden" or player:GetAttribute(FishingConfig.rodAttribute(id)) == true
end

function FishingConfig.equippedRod(player)
	local rod = FishingConfig.Rods[player:GetAttribute("EquippedRod") or 1]
	if rod and FishingConfig.ownsRod(player, rod.id) then
		return rod
	end
	return FishingConfig.Rods[1]
end

------------------------------------------------------------------------------------------
-- casting
------------------------------------------------------------------------------------------
FishingConfig.BiteTime = { 3, 7 }   -- seconds (random), divided by Speed
FishingConfig.MinBiteTime = 1.5 -- never before the bobber has landed
-- Auto Sell gamepass: create it (Creator Hub > your experience > Monetization > Passes) and paste its
-- ID here. While it's 0 the button shows "Coming Soon" in live games (in Studio you get it free to test).
FishingConfig.AutoSellPassId = 0
FishingConfig.AutoSellPrice = 199 -- only shown on the button (Robux)
FishingConfig.AutoSellInterval = 1.5 -- seconds between auto-sells

FishingConfig.ReelWindow = 3      -- seconds you have to click once it bites
FishingConfig.CastDistance = 16     -- studs in front of you
FishingConfig.BaseBackpack = 20     -- fish you can carry

------------------------------------------------------------------------------------------
-- Shell Upgrades (the Shell Upgrades stall). level attribute: ShellUp_<id>
------------------------------------------------------------------------------------------
FishingConfig.ShellUpgrades = {
	{ id = "FishValue", name = "Fish Value", desc = "+10% Fish Meal from selling", max = 25, cost = 10, growth = 1.35, per = 0.10 },
	{ id = "Luck", name = "Lucky Hook", desc = "+5% Luck", max = 25, cost = 15, growth = 1.4, per = 0.05 },
	{ id = "BiteSpeed", name = "Quick Bait", desc = "Fish bite 5% faster", max = 15, cost = 20, growth = 1.45, per = 0.05 },
	{ id = "Backpack", name = "Bigger Bucket", desc = "+5 fish you can carry", max = 10, cost = 25, growth = 1.5, per = 5 },
	{ id = "ShellMagnet", name = "Shell Magnet", desc = "+1 stud shell pickup range", max = 10, cost = 30, growth = 1.45, per = 1 },
	{ id = "ShellValue", name = "Shell Value", desc = "+15% Shells from pickups", max = 20, cost = 40, growth = 1.4, per = 0.15 },
}

FishingConfig.ShellUpgradeById = {}
for _, u in ipairs(FishingConfig.ShellUpgrades) do
	FishingConfig.ShellUpgradeById[u.id] = u
end

function FishingConfig.shellUpAttribute(id)
	return "ShellUp_" .. id
end

function FishingConfig.shellUpLevel(player, id)
	return player:GetAttribute(FishingConfig.shellUpAttribute(id)) or 0
end

function FishingConfig.shellUpCost(id, level)
	local u = FishingConfig.ShellUpgradeById[id]
	return math.floor(u.cost * u.growth ^ level)
end

------------------------------------------------------------------------------------------
-- Shells on the sand
------------------------------------------------------------------------------------------
FishingConfig.MaxShells = 28
FishingConfig.ShellSpawnEvery = 2.5
FishingConfig.BasePickupRange = 4
FishingConfig.ShellSizes = {
	{ id = "Small", chance = 70, amount = 1, scale = 0.8 },
	{ id = "Medium", chance = 24, amount = 3, scale = 1.1 },
	{ id = "Large", chance = 5.5, amount = 10, scale = 1.5 },
	{ id = "Golden", chance = 0.5, amount = 50, scale = 1.3 },
}

------------------------------------------------------------------------------------------
-- Fish Tiers (Fish Tier board). Tier Up costs Fish Meal and resets Fish Meal, rods and
-- auto-fishers. Tier 3 unlocks the Conversion board.
------------------------------------------------------------------------------------------
FishingConfig.Tiers = {
	{ cost = 1e4, fishMeal = 1.5 },
	{ cost = 1e5, fishMeal = 2 },
	{ cost = 1e6, fishMeal = 3, unlock = "Conversion Board" },
	{ cost = 1e7, fishMeal = 5 },
	{ cost = 1e8, fishMeal = 8 },
	{ cost = 1e9, fishMeal = 12 },
	{ cost = 1e10, fishMeal = 20 },
	{ cost = 1e11, fishMeal = 35 },
}
FishingConfig.MaxTier = #FishingConfig.Tiers
FishingConfig.ConversionTier = 3

function FishingConfig.tier(player)
	return player:GetAttribute("FishTier") or 0
end

------------------------------------------------------------------------------------------
-- Fishing Prestige (max 3). Needs max Fish Tier. Resets tiers, Fish Meal, rods, auto-fishers,
-- Shells, Shell Upgrades and Crabs; keeps the Fishing tree and Total Fish Caught.
------------------------------------------------------------------------------------------
FishingConfig.Prestiges = {
	{ fishMeal = 3, luck = 1.5, shells = 1.5 },
	{ fishMeal = 10, luck = 2, shells = 2.5 },
	{ fishMeal = 30, luck = 3, shells = 4 },
}
FishingConfig.MaxPrestige = #FishingConfig.Prestiges

function FishingConfig.prestige(player)
	return player:GetAttribute("FishPrestige") or 0
end

------------------------------------------------------------------------------------------
-- Conversion (Fish Meal -> Crabs), Tier 3+
------------------------------------------------------------------------------------------
FishingConfig.FishMealPerCrab = 1000

------------------------------------------------------------------------------------------
-- Auto-fishers: one per bridge, bought at the button by the bridge. AutoFisher_<n> = true.
-- Each one catches a fish every Interval seconds and sells it for you.
------------------------------------------------------------------------------------------
FishingConfig.AutoFishers = {
	{ price = 500 }, { price = 3e3 }, { price = 1.6e4 }, { price = 8e4 },
	{ price = 4e5 }, { price = 2e6 }, { price = 1e7 }, { price = 5e7 },
}
FishingConfig.AutoFisherInterval = 10
FishingConfig.AutoFisherLuck = 0.5   -- x your luck
FishingConfig.AutoFisherValue = 0.6  -- x what the fish would sell for

function FishingConfig.autoFisherAttribute(n)
	return "AutoFisher_" .. n
end

------------------------------------------------------------------------------------------
-- Robux: Sell All 2x (Developer Product). 0 = not set up yet.
------------------------------------------------------------------------------------------
FishingConfig.SellDoubleProductId = 0

------------------------------------------------------------------------------------------
-- multipliers (everything that boosts fishing, in one place)
------------------------------------------------------------------------------------------
local function tree(player, kind)
	return PrestigeConfig.treeMultiplier(player, kind)
end

function FishingConfig.fishMealMultiplier(player)
	local t = FishingConfig.Tiers[FishingConfig.tier(player)]
	local p = FishingConfig.Prestiges[FishingConfig.prestige(player)]
	return (t and t.fishMeal or 1)
		* (p and p.fishMeal or 1)
		* (1 + FishingConfig.shellUpLevel(player, "FishValue") * FishingConfig.ShellUpgradeById.FishValue.per)
		* tree(player, "fishmeal")
		* RuneConfig.boost(player, "fishmeal")
end

function FishingConfig.luck(player)
	local p = FishingConfig.Prestiges[FishingConfig.prestige(player)]
	return FishingConfig.equippedRod(player).luck
		* (1 + FishingConfig.shellUpLevel(player, "Luck") * FishingConfig.ShellUpgradeById.Luck.per)
		* (p and p.luck or 1)
		* tree(player, "fishluck")
		* RuneConfig.boost(player, "fishluck")
end

function FishingConfig.speed(player)
	return FishingConfig.equippedRod(player).speed
		* (1 + FishingConfig.shellUpLevel(player, "BiteSpeed") * FishingConfig.ShellUpgradeById.BiteSpeed.per)
		* tree(player, "fishspeed")
end

function FishingConfig.shellMultiplier(player)
	local p = FishingConfig.Prestiges[FishingConfig.prestige(player)]
	return (1 + FishingConfig.shellUpLevel(player, "ShellValue") * FishingConfig.ShellUpgradeById.ShellValue.per)
		* (p and p.shells or 1)
		* tree(player, "shells")
		* RuneConfig.boost(player, "shells")
end

function FishingConfig.crabMultiplier(player)
	return tree(player, "crabs")
end

function FishingConfig.autoFisherMultiplier(player)
	return tree(player, "autofish")
end

-- the cast power bar: 0..1 -> x1.0 .. x1.5 (luck + fish weight for that cast)
FishingConfig.CastPowerMin = 1
FishingConfig.CastPowerMax = 1.5
function FishingConfig.castMultiplier(power)
	return FishingConfig.CastPowerMin + (FishingConfig.CastPowerMax - FishingConfig.CastPowerMin) * math.clamp(power or 0, 0, 1)
end

-- the reel minigame: the line starts at Start and drains every second; each click pulls it
-- up by Click. Reach 1 (the green) to land the fish, hit 0 and it gets away.
-- Rarer fish pull harder; better rods (Speed) make every click count for more.
FishingConfig.Fight = {
	Start = 0.4,
	Click = 0.06,
	Drain = { 0.10, 0.13, 0.16, 0.20, 0.24, 0.28, 0.32, 0.36 }, -- per second, by rarity
	Goal = 0.88, -- the green zone starts here
}

function FishingConfig.fightFor(player, fish)
	local f = FishingConfig.Fight
	local drain = f.Drain[FishingConfig.RarityIndex[fish.rarity] or 1] or 0.2
	local click = f.Click * math.clamp(FishingConfig.equippedRod(player).speed, 1, 3) ^ 0.5
	-- fastest possible win: ~12 clicks a second
	local need = (f.Goal - f.Start)
	local minTime = need / math.max(click * 12 - drain, 0.01)
	return { start = f.Start, click = click, drain = drain, goal = f.Goal, minTime = minTime }
end

function FishingConfig.backpackSize(player)
	return FishingConfig.BaseBackpack + FishingConfig.shellUpLevel(player, "Backpack") * FishingConfig.ShellUpgradeById.Backpack.per
end

function FishingConfig.pickupRange(player)
	return FishingConfig.BasePickupRange + FishingConfig.shellUpLevel(player, "ShellMagnet") * FishingConfig.ShellUpgradeById.ShellMagnet.per
end

------------------------------------------------------------------------------------------
-- rolling a fish
------------------------------------------------------------------------------------------
function FishingConfig.rarityChances(luck)
	local weights, total = {}, 0
	for i, r in ipairs(FishingConfig.Rarities) do
		local w = r.weight * math.max(luck, 1) ^ (FishingConfig.LuckExponent * (i - 1))
		weights[i] = w
		total += w
	end
	local chances = {}
	for i, w in ipairs(weights) do
		chances[i] = w / total
	end
	return chances
end

-- "1 in N" for one fish at base luck (shown when you catch it)
function FishingConfig.oneIn(fishId, luck)
	local fish = FishingConfig.FishById[fishId]
	if not fish then return 1 end
	local chances = FishingConfig.rarityChances(luck or 1)
	local index = FishingConfig.RarityIndex[fish.rarity]
	local pool = FishingConfig.FishByRarity[fish.rarity]
	local chance = (chances[index] or 0) / math.max(#pool, 1)
	return chance > 0 and math.max(1, math.floor(1 / chance + 0.5)) or math.huge
end

function FishingConfig.rollFish(rng, luck)
	local chances = FishingConfig.rarityChances(luck)
	local r = rng:NextNumber()
	local rarity = FishingConfig.Rarities[1].name
	for i, c in ipairs(chances) do
		r -= c
		if r <= 0 then
			rarity = FishingConfig.Rarities[i].name
			break
		end
	end

	local pool = FishingConfig.FishByRarity[rarity]
	local fish = pool[rng:NextInteger(1, #pool)]
	-- weights lean small: most fish are average-ish, big ones are rarer
	local roll = rng:NextNumber() ^ 1.8
	local kg = fish.kg[1] + (fish.kg[2] - fish.kg[1]) * roll
	kg = math.floor(kg * 100 + 0.5) / 100

	return fish, kg
end

-- Fish Meal a fish sells for before multipliers
function FishingConfig.baseValue(fish, kg)
	local mid = (fish.kg[1] + fish.kg[2]) / 2
	return fish.value * (0.5 + 0.5 * (kg / mid)) -- an average-size fish = its value
end

function FishingConfig.formatKg(kg)
	if kg >= 1000 then
		return string.format("%.1ft", kg / 1000)
	elseif kg >= 10 then
		return string.format("%.0fkg", kg)
	end
	return (string.format("%.2fkg", kg):gsub("0kg$", "kg"))
end

------------------------------------------------------------------------------------------
-- where you are
------------------------------------------------------------------------------------------
function FishingConfig.island()
	local islands = workspace:FindFirstChild("Islands")
	return islands and islands:FindFirstChild(FishingConfig.IslandName)
end

return FishingConfig
