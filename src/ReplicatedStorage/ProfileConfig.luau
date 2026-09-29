-- The Profile: which stats it lists, the Achievements, and the Titles they unlock.
-- Stats come from ProfileService (works for anyone, online or not). Add an achievement by adding a
-- line; `stat` is any key of the stats table below, `goal` is the number to reach.
local ProfileConfig = {}

-- the stat rows, in order
ProfileConfig.Stats = {
	{ key = "TimePlayed", label = "Time Played", format = "time", icon = "⏱" },
	{ key = "RunesRolled", label = "Runes Rolled", format = "number", icon = "🔮" },
	{ key = "RobuxSpent", label = "Robux Spent", format = "robux", icon = "💸" },
	{ key = "TotalButtons", label = "Total Buttons", format = "number", icon = "🔘" },
	{ key = "RuneBulk", label = "Rune Bulk", format = "number", icon = "📦" },
	{ key = "RuneSpeed", label = "Rune Speed", format = "mult", icon = "⚡" },
	{ key = "RuneLuck", label = "Rune Luck", format = "mult", icon = "🍀" },
}

ProfileConfig.Achievements = {
	{ id = "Play1h", name = "Getting Comfy", text = "Play for 1 hour", stat = "TimePlayed", goal = 3600 },
	{ id = "Play10h", name = "Regular", text = "Play for 10 hours", stat = "TimePlayed", goal = 36000 },
	{ id = "Play100h", name = "No Life", text = "Play for 100 hours", stat = "TimePlayed", goal = 360000 },
	{ id = "Runes100", name = "Rune Rookie", text = "Roll 100 runes", stat = "RunesRolled", goal = 100 },
	{ id = "Runes10k", name = "Rune Hoarder", text = "Roll 10K runes", stat = "RunesRolled", goal = 1e4 },
	{ id = "Runes1m", name = "Rune Lord", text = "Roll 1M runes", stat = "RunesRolled", goal = 1e6 },
	{ id = "Buttons1k", name = "Clicker", text = "Earn 1K Buttons", stat = "TotalButtons", goal = 1e3 },
	{ id = "Buttons1m", name = "Button Masher", text = "Earn 1M Buttons", stat = "TotalButtons", goal = 1e6 },
	{ id = "Buttons1b", name = "Button God", text = "Earn 1B Buttons", stat = "TotalButtons", goal = 1e9 },
	{ id = "Prestige1", name = "Fresh Start", text = "Prestige once", stat = "Prestige", goal = 1 },
	{ id = "Prestige5", name = "Veteran", text = "Reach Prestige 5", stat = "Prestige", goal = 5 },
	{ id = "Fish100", name = "Angler", text = "Catch 100 fish", stat = "FishCaught", goal = 100 },
	{ id = "Fish10k", name = "Sea Legend", text = "Catch 10K fish", stat = "FishCaught", goal = 1e4 },
	{ id = "Supporter", name = "Supporter", text = "Buy anything in the Shop", stat = "RobuxSpent", goal = 1 },
}

-- titles: `from` = the achievement that unlocks it (nil = everyone has it)
ProfileConfig.Titles = {
	{ id = "Newbie", text = "Newbie", color = Color3.fromRGB(200, 205, 215) },
	{ id = "Regular", text = "Regular", from = "Play10h", color = Color3.fromRGB(120, 210, 255) },
	{ id = "NoLife", text = "No Life", from = "Play100h", color = Color3.fromRGB(255, 90, 90) },
	{ id = "RuneLord", text = "Rune Lord", from = "Runes1m", color = Color3.fromRGB(190, 120, 255) },
	{ id = "ButtonGod", text = "Button God", from = "Buttons1b", color = Color3.fromRGB(255, 205, 60) },
	{ id = "Veteran", text = "Veteran", from = "Prestige5", color = Color3.fromRGB(255, 150, 60) },
	{ id = "SeaLegend", text = "Sea Legend", from = "Fish10k", color = Color3.fromRGB(80, 220, 230) },
	{ id = "Supporter", text = "Supporter", from = "Supporter", color = Color3.fromRGB(255, 120, 200) },
}

ProfileConfig.AchievementById = {}
for _, a in ipairs(ProfileConfig.Achievements) do ProfileConfig.AchievementById[a.id] = a end
ProfileConfig.TitleById = {}
for _, t in ipairs(ProfileConfig.Titles) do ProfileConfig.TitleById[t.id] = t end

function ProfileConfig.done(stats, achievementId)
	local a = ProfileConfig.AchievementById[achievementId]
	return a ~= nil and (stats[a.stat] or 0) >= a.goal
end

function ProfileConfig.titleUnlocked(stats, titleId)
	local t = ProfileConfig.TitleById[titleId]
	return t ~= nil and (t.from == nil or ProfileConfig.done(stats, t.from))
end

return ProfileConfig
