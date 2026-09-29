-- Skill Tree (ported from the old game). Buy nodes with Stars; Stars are granted on a timer.
--   Type "Multiplier": x(1 + PerLevelValue * level) on that Currency (Money / Gold / Time / Coins /
--                      Rebirths / Stars). Several nodes on the same currency multiply together.
--   Type "Stat":       + PerLevelValue * level to that Stat (StarSpeed = seconds off the Stars timer,
--                      RuneBulk = extra runes per roll, RuneLuck = +x rune luck).
-- Price of level n = BasePrice x PriceMultipliers[1] x ... x PriceMultipliers[n-1] (rounded each step).
-- Levels are saved as Skill_<NodeId> attributes (spaces removed). The Root is always level 1.
local SkillTreeConfig = {
	Currency = "Stars",
	CurrencyIcon = "rbxassetid://113703238920088",
	Root = "Root",
	HexStepScale = 0.04,

	-- Stars: BaseAmount every BaseSeconds (Star Speed nodes take seconds off, never below MinSeconds)
	StarTimer = { BaseSeconds = 300, BaseAmount = 1, MinSeconds = 60 },

	DirectionOffsets = {
		Up = Vector2.new(0, -1),
		Down = Vector2.new(0, 1),
		UpRight = Vector2.new(0.8660254, -0.5),
		DownRight = Vector2.new(0.8660254, 0.5),
		UpLeft = Vector2.new(-0.8660254, -0.5),
		DownLeft = Vector2.new(-0.8660254, 0.5),
	},

	Nodes = {
		Root = {
			Name = "Ascension Core", Description = "The source of your ascended power. Always active.",
			Icon = "rbxassetid://103310603470243", Levels = 1, BasePrice = 0, Type = "None", PriceMultipliers = {},
		},
		Wealth = {
			Name = "Money Gain I", Description = "+10% Money gained per level.", Icon = "rbxassetid://74760303647639",
			Levels = 3, BasePrice = 5, Requires = "Root", Direction = "UpRight",
			Type = "Multiplier", Currency = "Money", PerLevelValue = 0.1, PriceMultipliers = { 3, 2 },
		},
		Trickle = {
			Name = "Money Gain II", Description = "+15% Money gained per level.", Icon = "rbxassetid://74760303647639",
			Levels = 2, BasePrice = 140, Requires = "Wealth", Direction = "UpRight",
			Type = "Multiplier", Currency = "Money", PerLevelValue = 0.15, PriceMultipliers = { 1.21 },
		},
		Alchemy = {
			Name = "Money Gain III", Description = "+12% Money gained per level.", Icon = "rbxassetid://74760303647639",
			Levels = 2, BasePrice = 220, Requires = "Trickle", Direction = "UpRight",
			Type = "Multiplier", Currency = "Money", PerLevelValue = 0.12, PriceMultipliers = { 1.59 },
		},
		Thrift = {
			Name = "Money Gain IV", Description = "+12% Money gained per level.", Icon = "rbxassetid://74760303647639",
			Levels = 3, BasePrice = 18, Requires = "Alchemy", Direction = "DownRight",
			Type = "Multiplier", Currency = "Money", PerLevelValue = 0.12, PriceMultipliers = { 1.94, 1.57 },
		},
		Prosperity = {
			Name = "Money Gain V", Description = "+20% Money gained per level.", Icon = "rbxassetid://74760303647639",
			Levels = 2, BasePrice = 45, Requires = "Thrift", Direction = "UpRight",
			Type = "Multiplier", Currency = "Money", PerLevelValue = 0.2, PriceMultipliers = { 1.67 },
		},
		["Golden Touch"] = {
			Name = "Gold Gain I", Description = "+10% Gold gained per level.", Icon = "rbxassetid://130575145070200",
			Levels = 5, BasePrice = 50, Requires = "Interest", Direction = "DownRight",
			Type = "Multiplier", Currency = "Gold", PerLevelValue = 0.1, PriceMultipliers = { 1.6, 1.5, 1.25, 1.33 },
		},
		Prospector = {
			Name = "Gold Gain II", Description = "+15% Gold gained per level.", Icon = "rbxassetid://130575145070200",
			Levels = 3, BasePrice = 180, Requires = "Golden Touch", Direction = "DownRight",
			Type = "Multiplier", Currency = "Gold", PerLevelValue = 0.15, PriceMultipliers = { 1.33, 1.5 },
		},
		Chronos = {
			Name = "Time Gain I", Description = "+10% Time gained per level.", Icon = "rbxassetid://104436607164470",
			Levels = 5, BasePrice = 8, Requires = "Trickle", Direction = "DownRight",
			Type = "Multiplier", Currency = "Time", PerLevelValue = 0.1, PriceMultipliers = { 2.25, 1.94, 1.57, 1.55 },
		},
		Fortune = {
			Name = "Coin Gain I", Description = "+5% Coins gained per level.", Icon = "rbxassetid://93735592939451",
			Levels = 6, BasePrice = 3, Requires = "Chronos", Direction = "DownRight",
			Type = "Multiplier", Currency = "Coins", PerLevelValue = 0.05, PriceMultipliers = { 1.67, 3, 2, 1.67, 2 },
		},
		Interest = {
			Name = "Coin Gain II", Description = "+15% Coins gained per level.", Icon = "rbxassetid://93735592939451",
			Levels = 2, BasePrice = 40, Requires = "Fortune", Direction = "DownRight",
			Type = "Multiplier", Currency = "Coins", PerLevelValue = 0.15, PriceMultipliers = { 1.5 },
		},
		Salvage = {
			Name = "Coin Gain III", Description = "+15% Coins gained per level.", Icon = "rbxassetid://93735592939451",
			Levels = 2, BasePrice = 35, Requires = "Interest", Direction = "Down",
			Type = "Multiplier", Currency = "Coins", PerLevelValue = 0.15, PriceMultipliers = { 1.57 },
		},
		Haste = {
			Name = "Star Speed I", Description = "Grants Stars 30 seconds faster per level.", Icon = "rbxassetid://110529597322649",
			Levels = 4, BasePrice = 8, Requires = "Root", Direction = "Down",
			Type = "Stat", Stat = "StarSpeed", PerLevelValue = -30, PriceMultipliers = { 2.5, 3, 6 },
		},
		Meditation = {
			Name = "Star Speed II", Description = "Grants Stars 30 seconds faster per level.", Icon = "rbxassetid://110529597322649",
			Levels = 2, BasePrice = 500, Requires = "Haste", Direction = "DownRight",
			Type = "Stat", Stat = "StarSpeed", PerLevelValue = -30, PriceMultipliers = { 1.25 },
		},
		Attunement = {
			Name = "Rune Bulk I", Description = "+1 Rune rolled per roll, per level.", Icon = "rbxassetid://101935509296686",
			Levels = 5, BasePrice = 10, Requires = "Root", Direction = "UpLeft",
			Type = "Stat", Stat = "RuneBulk", PerLevelValue = 1, PriceMultipliers = { 2, 4.5, 1.44, 1.54 },
		},
		Attunement2 = {
			Name = "Rune Bulk II", Description = "+1 Rune rolled per roll, per level.", Icon = "rbxassetid://101935509296686",
			Levels = 5, BasePrice = 150, Requires = "Attunement", Direction = "UpLeft",
			Type = "Stat", Stat = "RuneBulk", PerLevelValue = 1, PriceMultipliers = { 2, 4.5, 1.44, 1.54 },
		},
		-- was "Fish Luck I" in the old game (no fishing here), now Rune Luck
		AnglersLuck = {
			Name = "Rune Luck I", Description = "+10% Rune Luck per level.", Icon = "rbxassetid://87821576554128",
			Levels = 5, BasePrice = 300, Requires = "Attunement2", Direction = "Up",
			Type = "Stat", Stat = "RuneLuck", PerLevelValue = 0.1, PriceMultipliers = { 1.5, 1.5, 1.75, 2 },
		},
		Reincarnate = {
			Name = "Rebirth Gain I", Description = "+15% Rebirths gained per level.", Icon = "rbxassetid://120864196642745",
			Levels = 2, BasePrice = 190, Requires = "Trickle", Direction = "UpLeft",
			Type = "Multiplier", Currency = "Rebirths", PerLevelValue = 0.15, PriceMultipliers = { 1.26 },
		},
		Renewal = {
			Name = "Rebirth Gain II", Description = "+10% Rebirths gained per level.", Icon = "rbxassetid://120864196642745",
			Levels = 4, BasePrice = 8, Requires = "Reincarnate", Direction = "Up",
			Type = "Multiplier", Currency = "Rebirths", PerLevelValue = 0.1, PriceMultipliers = { 2.25, 2.22, 1.63 },
		},
		Bounty = {
			Name = "Star Gain I", Description = "+20% Stars granted per level.", Icon = "rbxassetid://113703238920088",
			Levels = 5, BasePrice = 15, Requires = "Haste", Direction = "DownLeft",
			Type = "Multiplier", Currency = "Stars", PerLevelValue = 0.2, PriceMultipliers = { 2.67, 1.75, 1.43, 10 },
		},
		Cascade = {
			Name = "Star Gain II", Description = "+20% Stars granted per level.", Icon = "rbxassetid://113703238920088",
			Levels = 2, BasePrice = 200, Requires = "Bounty", Direction = "DownLeft",
			Type = "Multiplier", Currency = "Stars", PerLevelValue = 0.2, PriceMultipliers = { 2.5 },
		},
		Windfall = {
			Name = "Star Gain III", Description = "+25% Stars granted per level.", Icon = "rbxassetid://113703238920088",
			Levels = 2, BasePrice = 200, Requires = "Cascade", Direction = "Down",
			Type = "Multiplier", Currency = "Stars", PerLevelValue = 0.25, PriceMultipliers = { 1.25 },
		},
	},
}

-- saved attribute for a node's level ("Golden Touch" -> "Skill_GoldenTouch")
function SkillTreeConfig.attribute(id)
	return "Skill_" .. id:gsub("[^%w]", "")
end

function SkillTreeConfig.level(player, id)
	if id == SkillTreeConfig.Root then
		return 1
	end

	return player:GetAttribute(SkillTreeConfig.attribute(id)) or 0
end

-- { [id] = level } for every owned node (Root included)
function SkillTreeConfig.levels(player)
	local out = {}

	for id in pairs(SkillTreeConfig.Nodes) do
		local lvl = SkillTreeConfig.level(player, id)

		if lvl > 0 then
			out[id] = lvl
		end
	end

	return out
end

function SkillTreeConfig.priceForLevel(node, level)
	local price = node.BasePrice or 0

	for i = 1, level - 1 do
		price = math.round(price * (node.PriceMultipliers and node.PriceMultipliers[i] or 1))
	end

	return price
end

-- x multiplier on a currency from every Multiplier node
function SkillTreeConfig.multiplier(player, currency)
	local total = 1

	for id, node in pairs(SkillTreeConfig.Nodes) do
		if node.Type == "Multiplier" and node.Currency == currency then
			local lvl = SkillTreeConfig.level(player, id)

			if lvl > 0 then
				total *= 1 + (node.PerLevelValue or 0) * lvl
			end
		end
	end

	return total
end

-- + bonus on a stat from every Stat node
function SkillTreeConfig.flat(player, stat)
	local total = 0

	for id, node in pairs(SkillTreeConfig.Nodes) do
		if node.Type == "Stat" and node.Stat == stat then
			total += (node.PerLevelValue or 0) * SkillTreeConfig.level(player, id)
		end
	end

	return total
end

function SkillTreeConfig.starSeconds(player)
	local t = SkillTreeConfig.StarTimer
	return math.max(t.MinSeconds, t.BaseSeconds + SkillTreeConfig.flat(player, "StarSpeed"))
end

function SkillTreeConfig.starAmount(player)
	return math.floor(SkillTreeConfig.StarTimer.BaseAmount * SkillTreeConfig.multiplier(player, "Stars") * 100 + 0.5) / 100
end

return SkillTreeConfig
