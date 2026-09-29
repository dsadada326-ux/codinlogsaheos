# codinlogsaheos

The whole Roblox game as files, synced into Roblox Studio with [Rojo](https://rojo.space).
Exported from the place file on 2026-09-28.

## Layout

`src/` mirrors the Studio Explorer. Each folder under `src/` is a service
(Workspace, ReplicatedStorage, ServerScriptService, StarterGui, ...), except
`src/StarterPlayerScripts` and `src/StarterCharacterScripts`, which go inside
StarterPlayer.

| File | Becomes in Studio |
| --- | --- |
| `Name.server.luau` | Script |
| `Name.client.luau` | LocalScript |
| `Name.luau` | ModuleScript |
| `Name/init.server.luau` (etc.) | A script with children; the other files in `Name/` are its children |
| `Name.meta.json` | Extra script properties (Disabled, RunContext) |
| folder | Folder |
| `Name.rbxmx` | Anything else, with everything inside it: parts, models, ScreenGuis, VFX, remotes |

A few things are left in Studio only and not synced:

- Terrain and Camera
- The three `Workspace.Rig` models, `Workspace.Islands.Portals` (two empty folders),
  `Workspace.Islands.Island2.Zones.GoldRune` and `Workspace.Labratory.Ground`,
  because each shares its name with a sibling and Rojo needs unique names.

`ASSETS.md` lists every asset ID the game uses.

## Syncing

1. `git pull`
2. `rojo serve`
3. In Studio, open the Rojo plugin and click **Connect**.

Rojo syncs one way, from these files into Studio. Changes made directly in
Studio are overwritten by the next sync unless they're saved back here, so
save a backup (File > Save to File As) before connecting.
