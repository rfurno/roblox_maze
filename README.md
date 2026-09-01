# Maze Runner

Rebuild of the live Maze Runner place (`16171071941`). **Rojo** owns Luau; an unpublished Studio place owns geometry. **ProfileStore** owns player profiles; OrderedDataStore owns leaderboards.

## Docs

| File | What |
|---|---|
| [`GAME_DESIGN.md`](GAME_DESIGN.md) | Locked product spec (gameplay, run contract, mazes, MVP) |
| [`DESIGN.md`](DESIGN.md) | Architecture, remotes, data, rebuild roadmap |
| [`GAME_LOGIC.md`](GAME_LOGIC.md) | Inventory of the **live** place — not the target design |

## Status

**PRs 1–8 done** (see `DESIGN.md` PR Plan). First playable is live: Easy 1–2, Mild 1–2, and Hard 1 are baked runs with the run contract, HUD, Easy 1 kill beams, and unwired Mild/Hard dress (dice pads, secrets, waypoints, BotSpawns). Next is PR 9 (Insane blockout).

Unpublished place **135988241030750**, universe **10764621894**. New badge/pass IDs. No JetPack in MVP. Place-native version notes: disabled `ServerScriptService.DevLog`.

## Tooling

Rojo maps `src/` and `Packages/` only. It does **not** overwrite `Workspace`.

```
src/shared     → ReplicatedStorage.Shared
src/server     → ServerScriptService  (Main, Session, MazeRun, Baker, …)
Packages/      → ServerScriptService.Packages  (ProfileStore)
src/client     → StarterPlayer.StarterPlayerScripts
```

Port is **not** the Rojo default. 21 Days uses `34872`; this game uses **`34873`** (`servePort` in `default.project.json`).

The Studio plugin cannot connect unless the server is running:

```bash
cd /Users/renatoalmeida/Dev/roblox_maze
rojo serve
```

Then in Studio connect the Rojo plugin to **`localhost:34873`**.

ProfileStore is **vendored** at `Packages/ProfileStore.luau` from [MadStudioRoblox/ProfileStore](https://github.com/MadStudioRoblox/ProfileStore). `wally.toml` is ready for `lm-loleris/profilestore@1.0.3` when Wally is installed; do not `wally install` until then or it may replace the vendored file.

Studio: ProfileStore uses `.Mock` unless `Workspace.UseStudioDataStores == true`. Do not point Studio at production DataStore keys.

## Layout

```
src/shared/Constants.luau MazeConfig.luau
src/server/Main.server.luau Session.luau MazeRun.luau WorldNav.luau …
src/server/Baker/          Studio command (RunBake Disabled)
src/client/                Movement / Input / HUD / HudGuis
Packages/ProfileStore.luau
```
