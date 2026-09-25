# codinlogsaheos

Roblox game scripts, synced into Roblox Studio with [Rojo](https://rojo.space).

## Layout

| Folder | Goes into Studio at |
| --- | --- |
| `src/ServerScriptService` | ServerScriptService |
| `src/ReplicatedStorage` | ReplicatedStorage |
| `src/StarterGui` | StarterGui |
| `src/StarterPlayerScripts` | StarterPlayer.StarterPlayerScripts |
| `src/StarterCharacterScripts` | StarterPlayer.StarterCharacterScripts |

File names decide the script type:

- `Name.server.luau` is a Script
- `Name.client.luau` is a LocalScript
- `Name.luau` is a ModuleScript

Every mapping uses `$ignoreUnknownInstances`, so Rojo only touches scripts that
have a file here. Parts, boards, VFX and anything else in Studio are left alone.

## Syncing

1. `git pull`
2. `rojo serve`
3. In Studio, open the Rojo plugin and click **Connect**.
