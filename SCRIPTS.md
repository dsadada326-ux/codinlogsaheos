# Script map

Where each script in Studio goes in this repo. Taken from the Studio Explorer.
Use this when exporting scripts out of Studio.

**Do not create empty placeholder files.** Rojo overwrites a Studio script with
whatever its file contains, so an empty file would wipe the real script.

## ReplicatedStorage (ModuleScripts)

| Studio | File |
| --- | --- |
| ComboConfig | `src/ReplicatedStorage/ComboConfig.luau` |
| ConversionConfig | `src/ReplicatedStorage/ConversionConfig.luau` |
| Multipliers | `src/ReplicatedStorage/Multipliers.luau` |
| NumberFormat | `src/ReplicatedStorage/NumberFormat.luau` |
| PrestigeConfig | `src/ReplicatedStorage/PrestigeConfig.luau` |
| RebirthConfig | `src/ReplicatedStorage/RebirthConfig.luau` |
| SettingsConfig | `src/ReplicatedStorage/SettingsConfig.luau` |
| UpgradeConfig | `src/ReplicatedStorage/UpgradeConfig.luau` |
| ZoneConfig | `src/ReplicatedStorage/ZoneConfig.luau` |
| ButtonRelations.ButtonAnimation | `src/ReplicatedStorage/ButtonRelations/ButtonAnimation.luau` |
| ButtonRelations.ButtonController | `src/ReplicatedStorage/ButtonRelations/ButtonController.luau` |

## ServerScriptService (Scripts)

A Script with a ModuleScript inside it becomes a folder: the Script is
`init.server.luau` and the module sits next to it.

| Studio | File |
| --- | --- |
| AutoClickService | `src/ServerScriptService/AutoClickService.server.luau` |
| ButtonClickService | `src/ServerScriptService/ButtonClickService/init.server.luau` |
| ButtonClickService.ClickHandler | `src/ServerScriptService/ButtonClickService/ClickHandler.luau` |
| ConversionService | `src/ServerScriptService/ConversionService/init.server.luau` |
| ConversionService.Conversion | `src/ServerScriptService/ConversionService/Conversion.luau` |
| GlobalWS | `src/ServerScriptService/GlobalWS.server.luau` |
| Leaderstats | `src/ServerScriptService/Leaderstats.server.luau` |
| PlayerData | `src/ServerScriptService/PlayerData.server.luau` |
| RebirthService | `src/ServerScriptService/RebirthService.server.luau` |
| SettingsService | `src/ServerScriptService/SettingsService.server.luau` |
| TimeService | `src/ServerScriptService/TimeService.server.luau` |
| UpgradeService | `src/ServerScriptService/UpgradeService/init.server.luau` |
| UpgradeService.Upgrades | `src/ServerScriptService/UpgradeService/Upgrades.luau` |
| ZoneService | `src/ServerScriptService/ZoneService.server.luau` |

## StarterPlayer.StarterPlayerScripts (LocalScripts)

All go in `src/StarterPlayerScripts/` as `<Name>.client.luau`:

ButtonManager, ButtonVFXManager, ChatHints, ClickCursors, ConversionBoard,
MusicSetting, RebirthBoard, RebirthBoostsBoard, SettingsUI, TempZones,
TimeButtonFX, TimeGemsBoards, UIClickSound, UpgradeBoard, ZoneReveal

## Stays in Studio only

Rojo leaves these alone:

- `ReplicatedStorage.Remotes` (RemoteEvents and RemoteFunctions)
- `ReplicatedStorage.TimeButtonVfx`
- The ScreenGuis in StarterGui (CameraMode, CashGain, ClickRewards, Currencies,
  Buttons, Settings). Any scripts inside them aren't synced yet.
- Everything in Workspace (islands, boards, upgrade tree, zones)
