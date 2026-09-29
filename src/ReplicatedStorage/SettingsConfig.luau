-- One entry per settings row. The Key must match the Frame name under
-- Settings > Container > Container > ScrollingFrame exactly.
local SettingsConfig = {}

SettingsConfig.Order = {
	"Music", "SFX", "VFX", "SaveLastPos", "Chat Hints", "HideMaxUpgrades", "NightTime",
	"AutoUpgradeStarter", -- the ON/OFF panel on the Starter board (Prestige 1+), not in the Settings menu
}

SettingsConfig.Settings = {
	Music = {
		DisplayName = "Music",
		Default = true,
	},
	SFX = {
		DisplayName = "SFX",
		Default = true,
	},
	VFX = {
		DisplayName = "VFX",
		Default = true,
	},
	SaveLastPos = {
		DisplayName = "Save Last Position",
		Default = true,
	},
	["Chat Hints"] = {
		DisplayName = "Chat Hints",
		Default = true,
	},
	HideMaxUpgrades = {
		DisplayName = "Hide Maxed Upgrades",
		Default = true,
	},
	NightTime = {
		DisplayName = "Night Time",
		Default = false,
	},
	AutoUpgradeStarter = {
		DisplayName = "Auto Upgrade",
		Default = true,
	},
}

-- the saved attribute name for a setting ("Chat Hints" -> "Setting_ChatHints")
function SettingsConfig.attributeOf(key)
	return "Setting_" .. key:gsub("%s", "")
end

return SettingsConfig
