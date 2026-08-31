# Maze Runner — Game Logic Inventory

Place: **Maze Runner** (`placeId: 16171071941`, universe `5585682598`)
Studio instance reviewed in Edit mode on 2026-08-31.

This document describes what the **live place** actually does. Rebuild gameplay is **`GAME_DESIGN.md`**; architecture and Rojo layout are **`DESIGN.md`**. Do not treat this inventory as the target design.

---

## 1. What the game is

An **obby-style maze runner** in a shared world.

Players spawn in a **central lobby**, pick a difficulty, walk into a maze, and try to reach the exit without dying. Completing a maze awards a **badge**, records a **best time**, and drops the player into a **landing / connector lobby** for the next maze in that difficulty.

Side systems layered on top:

- Collectible “Things” scattered around the world (collection / Halloween pumpkins)
- Hazards: turrets, lasers, pumpkin fire, damage pads, falling-off-map teleports, d20 dice, hunter bots
- Paid **waypoint maps** (solution overlay) per maze
- Paid **Insane maze + JetPack** gamepass
- World leaderboards for maze times and collector counts
- Breadcrumb trail (dev product, incomplete)

There is **no matchmaking, no rounds, no lives economy**. Death respawns at the enabled SpawnLocation (the main lobby spawn). Dying does **not** clear `InMaze` or hide the timer HUD — the run is simply not saved. Mazes are always present in the same place; they are not generated at runtime in the live game.

---

## 2. Core player loop

```
Join
  → spawn in Main Lobby (only enabled SpawnLocation)
  → walk to a difficulty landing
  → touch MazeEntranceTrigger
       • set InMaze = true, start stopwatch
       • show HUD timer + personal best
       • show waypoint + crouch buttons
       • HARD_1 only: spawn 4 HunterBots that chase this player
  → navigate maze, avoid hazards
  → touch MazeExit (CollectionService path requires Health > 0)
       • award completion badge
       • set InMaze = false, stop timer, save if new best
       • hide waypoint HUD (crouch button is left visible)
       • destroy that player's HunterBots
  → emerge in that maze's landing / next-lobby
  → either continue to the next maze or teleport back to Main Lobby
```

Death / character despawn:

- Respawn at main lobby `SpawnLocation`
- HunterBots assigned to that player are destroyed
- `InMaze` is **not** cleared; the stopwatch coroutine keeps writing `StopTime` until a later maze complete
- Timer HUD is **not** hidden; a later maze enter overwrites `StartTime`

Onboarding analytics funnel (AnalyticsService):

1. Player Joined — fired from `CharacterScript` on **every `CharacterAdded`**, not once per session
2. Player Entered Maze
3. Player Completed Maze

---

## 3. World layout

The place is one large static world. Folders under `Workspace`:

| Folder | Role |
|---|---|
| `Lobby` | Hub, shop, connector rooms between mazes |
| `Mazes` | The six playable mazes + empty `Solution` folder (runtime waypoint clones land here) |
| `Teleport Triggers` | All in-place and cross-place touch teleports, grouped by maze name |
| `Teleport Target Locations` | Named destination parts used by in-place teleports |
| `Leaderboard` | World SurfaceGui boards |
| `Things` | Runtime collectible instances (starts empty) |
| `ThingSpawnLocation` | 17 spawn pads for collectibles (all `Rank` = 1) |
| `Breadcrumbs` | Runtime dropped star trail (starts empty) |
| `Mechs` | Empty (legacy) |
| `Tokens` | Empty |
| `Player Blocker` | Empty at root; some mazes have their own |
| `Tutorial Assets` | Runtime tutorial clones (starts empty) |
| `EasterEggs` | Two Halloween Balloon tools |

### Hub rooms (`Workspace.Lobby`)

- **Main** — spawn lobby. Children: `Wall`, `Floor`, `AccessoryZone` (JetPack bounding cube + zone triggers)
- **Easy - Landing**, **Easy 1 to 2 Lobby**, **Easy 2 to 3 Lobby**
- **Mild - Landing**, **Mild 1 to 2 Lobby**, **Mild 2 to 3 Lobby**
- **Hard - Landing**, **Hard 1 to 2 Lobby**
- **Insane - Landing**, **Insane 1 to 2 Lobby** — gamepass-gated (checkpoint + slide eject)
- **Shop** — Insane gamepass prompt + breadcrumb “Star” bowl
- **Signs**, **Props**

Progression is **physical**, not a menu. Completing Easy 1 dumps you in Easy 1-to-2 lobby, from which you enter Easy 2, and so on.

### In-place teleport targets

Named parts under `Workspace.Teleport Target Locations`:

`Lobby`, `Easy 1 Entrance`, `Easy 2 Entrance`, `Easy 2 Lobby`, `Mild 1 Entrance`, `Mild 2 Entrance`, `Mild 2 Lobby`, `Mild 2 Exit`, `Hard 1 Entrance`, `Hard 1 Exit`

### Teleport Triggers (`Workspace.Teleport Triggers`)

These are **not** inside maze folders. `TeleportManager` iterates every child of every subfolder here.

| Group | Parts |
|---|---|
| Easy 1 | `TeleportTrigger` → `Lobby` |
| Easy 2 | `TeleportTrigger` → `Easy 2 Lobby`; `TeleportTrigger` → `Lobby` |
| Mild 1 | `TeleportTrigger` → `Lobby`; `TeleportTrigger` → `Mild 2 Lobby`; **8× `TeleportTrap` → `Mild 1 Entrance`** |
| Mild 2 | **6× `TeleportTrap` → `Mild 2 Entrance`**; `TeleportTrigger` → `Lobby` |
| Hard 1 | `TeleportTrigger` → `Lobby`; **2× `TeleporTrigger` (typo) → `Hard 1 Entrance`** |
| Vertical 1 | 2× `TeleportTrigger` → `Lobby` |
| Other Experiences | `TeleportTrigger` to place `13056501521` (cross-place; shows Teleporting GUI) |

Fall / out-of-bounds traps exist for **Mild 1, Mild 2, and Hard 1 only**. Easy 1, Easy 2, and Insane have no floor-fall `TeleportTrap`. Fall teleports do **not** reset the timer.

### SpawnLocations

Only `Workspace.SpawnLocation` is **Enabled**. Disabled pads (visual/physical only):

`SpawnLocation Exit Easy 1`, `SpawnLocation Entrance Easy 2`, `SpawnLocation Exit Mild 1`, `SpawnLocation Mild 2`, `SpawnLocation Hard 1`, `SpawnLocation Entrance Insane`, `SpawnLocation Exit Insane`

`StarterPlayer.CharacterUseJumpPower` is **false** (engine JumpHeight ≈ 7.2). Live WalkSpeed 25 is applied by client `StaminaScript`, not by `StarterPlayer` (WalkSpeed 16).

---

## 4. Mazes

Internal IDs (used everywhere in scripts / datastores / remotes):

| ID | Player-facing name | Board | Badge on exit |
|---|---|---|---|
| `EASY_1` | Easy 1 | Two 6×6 crate/container boards | `437680051584782` |
| `EASY_2` | Easy 2 | Two 6×6 boards + stairs | `3303135643125970` |
| `MILD_1` | Mild / “a Little Harder” 1 | One 12×12 wall board (66 `Maze Wall` + 1 `Wall`) | `4069310029355913` |
| `MILD_2` | Mild 2 | Two 12×12 boards + 2 elevators | `2975952186957333` |
| `HARD_1` | Hard 1 | One 12×12 floor (516 parts) + walls (573 parts) | `3987381879139424` |
| `VERTICAL_1` | Insane 1 | Tall/vertical board (**2763** `Wall` parts) | `1846732522957557` |

`ServerConfiguration.MAZES` maps each maze to a waypoint gamepass and (except HARD_1 in config) a completion badge key. HARD_1 still awards a badge from the exit part’s `BadgeId` value.

Each maze folder has a common skeleton:

- `Entrance` — arch, sign, shining lights, entrance plate, **MazeEntranceTrigger** (`MazeName` StringValue)
- `Exit` — exit plate, **MazeExit** (`BadgeId`, `MazeId`)
- `Arena` — outer walls/floor
- `Board…` — the actual maze geometry
- `Bots` — empty, pre-placed patrol bots, or HunterBot spawn pads
- `Player Blocker` — 2–3 walls (EASY_1 has **none**)
- `Traps` / `Turrets` / `Props` as needed

CollectionService `MazeExit` is on all six exit plates. A duplicate child script `Exit Maze` also exists on **EASY_1, MILD_1, MILD_2 only** (not EASY_2 / HARD_1 / VERTICAL_1). The CollectionService path refuses dead players; the child `Exit Maze` script does **not** check health.

### EASY_1

- Theme: shipping containers as walls (`BoardCrates6x6` × 2)
- **Turrets**: 3 turret groups (Beam + BeamTrigger + Turret model). Beams toggle on/off every 3 seconds (first wait 3s, starting **off**). Touching `BeamTrigger` deals **100 damage** (instant kill at default health)
- **Barrels**: 3 yellow barrels; **one** has `Ooze Script`
- `Bots` folder empty; no `Player Blocker`; no `Traps` folder
- Waypoint pass: `WAYPOINTS_EASY_1` (id `705277031`)
- Solution stored as 9 Arrow models in `ReplicatedStorage.Maze Solution.EASY_1`

### EASY_2

- Two 6×6 boards (`Board6x6-1`, `Board6x6-2`) with stairs between them
- **PumpkinTraps** (2): visual fire builds over 15s (heat/size steps at 5s + 5s + 5s), then both fire emitters + touch triggers enable for 5s. Touch deals **30 + 30** damage (2s apart)
- `Bots` folder empty
- No child `Exit Maze` script (CollectionService only)
- Waypoint pass: `WAYPOINTS_EASY_2` (id `938971066`)
- Solution is a `Solution` model (36 descendants)

### MILD_1

- 12×12 board: 66 `Maze Wall` parts + 1 `Wall`
- **5 DamageTraps**: 100 damage on touch
- **Turrets**: **1** turret group, same 100-damage 3s toggle as Easy 1
- **2 BattleBots**: patrol 4 `Patrol End Points` via the bot `NPC` script / PathfindingService. Contact uses a child Trap Script. The sibling `Pathfinding` script is a leftover that walks to a hardcoded `TEST_DESTINATION`. Ragdoll on death is configured **off** (`RagdollEnabled=false`)
- **d20 dice** (teleport target: `Mild 1 Entrance`)
- **Jailbreaker** secret at exit (badge `443964865251442`) — tagged `Jailbreaker`, **no** local `JairbreakerScript`. Touch only awards the badge (does **not** fire `MazeCompleted`)
- Waypoint pass: `WAYPOINTS_MILD_1` (id `705103513`)
- Solution: 11 Arrow models

### MILD_2

- Two 12×12 boards: `Board12x12 1` Walls **575** parts + **2 Elevator** models; `Board12x12 2` Walls **576** parts + Floor **513** parts
- **Elevators**: PrismaticConstraint ping-pongs every 6 seconds (~-16 to +16). Each platform has a Trap Script (**100** damage)
- **Lasers**: 11 `BeamTrigger` parts, 100 damage. Controller connects touch only — it does **not** toggle like Easy/Mild 1. Beams are always-on
- **Bots**: 2 GoldBots, 2 BattleBots (patrol), **5 Sci Fi Drones**
- Drones fire a damaging **ring projectile** every 3s; ring tweens to a Target over 10s and deals **100** on touch
- d20 dice (teleport target: `Mild 2 Exit`)
- **3 Jailbreaker** parts (badge `1309464804730436`) — each tagged **and** has `JairbreakerScript`, so they award the secret badge **and** fire `MazeCompleted` (stops the timer)
- Waypoint pass: `WAYPOINTS_MILD_2` (id `730377265`)
- Solution: 2 `Solution` models (343 descendants)

### HARD_1

- 12×12 floor (516 parts) + walls (573 parts)
- **No pre-placed combat bots.** `Bots` folder has `BotSpawnLocation1` and `BotSpawnLocation2`
- On maze enter, **4 HunterBots** are cloned from `ServerStorage.Bots.HunterBot`, assigned `Configuration.Player = player.Name`, parented under the maze `Bots` folder, and chase that player every **1s** via the bot `NPC` script’s pathfinding. Destroyed on maze complete, character despawn, or player leave. Re-entering after death spawns a fresh set of 4
- Template leftover: `Configuration.Player` on the ServerStorage HunterBot is set to `ylwfrog`. Template `NPC` is Enabled; `NPC1`, `Pathfinding`, and `SolveMaze` are Disabled
- d20 dice (teleport target: `Hard 1 Exit`), Jailbreaker (badge `2607997495211781`, tagged **and** has `JairbreakerScript`), BattleBot **prop**
- No child `Exit Maze` script
- Waypoint pass: `WAYPOINTS_HARD_1` (id `754828532`)
- Config has no `COMPLETION_BADGE_ID` key, but the exit plate still awards `3987381879139424`
- Solution: 1 `Solution` model (156 descendants)

### VERTICAL_1 (Insane)

- Huge vertical maze (`Board` with **2763** Wall parts)
- **Gamepass-gated** (`PASSES.VERTICAL_1` / id `940187199`)
  - Shop proximity prompt in lobby (`Workspace.Lobby.Shop.GamePass.Insane 1`)
  - `GamePassCheckpoint` at Insane landing: invisible (`Transparency = 1`), `CanCollide = true` by default. On touch, if **this** player owns the pass, the part’s `CanCollide` becomes false; if not, it is set true. This is a **shared** part, so one owner can open the barrier for everyone until a non-owner touches it
  - `Slide.SafeSlide` (`SlideGamepassCheckScript`): if the player does **not** own the pass, they are teleported to `Lobby`. Owners pass through
  - Owning the pass also unlocks the **JetPack** accessory button (`GamepassAvailable` → `ToolAvailableRemote`)
- Waypoint pass: `WAYPOINTS_VERTICAL_1` (id `940441143`, tool name “Waypoints Insane 1”)
- No bots, no traps folder, no Jailbreaker
- No child `Exit Maze` script
- JetPack is **restricted outside AccessoryZone** (see §5)
- Solution: 1 `Solution` model (414 descendants)

---

## 5. Movement and character

Defaults in `ServerConfiguration`:

- WalkSpeed **25**
- JumpPower **100**

`StarterPlayer` still has engine defaults (WalkSpeed 16, JumpHeight ≈ 7.2, **`CharacterUseJumpPower = false`**). Live speed is applied by `StaminaScript` (`humanoid.WalkSpeed = 25`). Jump power 100 is only forced when a JetPack boost is applied (`humanoid.UseJumpPower = true`).

### Sprint

Client `StaminaScript`:

- Hold Left Shift (gamepad R2 is *intended* but the condition is written as `KeyCode ~= LeftShift or KeyCode == ButtonR2`, so R2 does not actually start sprint)
- +10 WalkSpeed, cap 46
- Stamina 100, drain 10/s, regen 10/s
- Exhausted at 0; can sprint again after stamina > 60
- Disabled while a boost (JetPack) is active

### Crouch

HUD button in maze (shown on maze enter; **not** hidden on maze complete). Fires BindableEvent `Animate`. `UserInput` LocalScript plays animation `rbxassetid://16676342149`, WalkSpeed −9, JumpPower 0. Toggle off resets WalkSpeed to 25 and JumpPower to **50** (not 100 — mismatch with server default, and `UseJumpPower` is still false so this often does nothing). Keyboard C is commented out.

StarterGui: Crouch **frame** is visible; the image button starts `Visible = false` until maze enter.

### JetPack accessory

- Template in `ServerStorage.AccessoryTemplates` (`JetPack`, plus Blue/White variants unused by the current attach path)
- Config: `TOOLS.JetPack` — type ACCESSORY, requires gamepass `940187199`
- Boost while equipped: WalkSpeed **30**, JumpPower **100**, `UseJumpPower = true`
- Client HUD button `AccessoriesImageButton` (productName JetPack, starts hidden) fires `AttachAccessoryRemote`
- Server `AccessoryHandler` clones accessory onto character, unequips any previous accessory sharing the same Attachment name, applies boost via `BoostPlayer`
- `AccessoryRestrictor` keeps it inside an axis-aligned cube built from `AccessoryBoundaryMark` parts (4 marks under `Lobby.Main.AccessoryZone`, each tagged twice). `ZoneTrigger` parts: 5 in Main AccessoryZone + 1 in `Easy - Landing`. Touching a zone trigger: inside cube → restore tool UI; outside → unequip + hide button

---

## 6. Timer, stats, leaderboards

### Per-run timer

On player join (`CharacterAdded`), `CharacterScript` fires `SetupTimer`. `MazeStats` creates `ReplicatedStorage.Timer/<PlayerName>` with `StartTime` and `StopTime` **StringValues** (they store `tick()` as a string).

On maze enter:

- `player.InMaze = true`
- StartTime = `tick()`
- coroutine writes `tick()` into StopTime every 0.5s while `InMaze`
- client is sent personal best via `ShowTimerRemote`

On maze complete (`MazeCompleted` bindable):

- `InMaze = false`
- elapsed = stop − start
- if elapsed < previous best (or no previous), save as BestTime

Client `TimerScript` listens to StopTime.Changed and formats `HH:MM:SS:mmm`. Shows “Best: …” if best > 0.

Death / leave does **not** fire `MazeCompleted`, so the live timer can keep running in the lobby.

### Persistence (OrderedDataStore)

Store name: **`BotJamMazeRunnerStatsStore`**

Scopes: `EASY_1`, `EASY_2`, `MILD_1`, `MILD_2`, `HARD_1`, `VERTICAL_1`, `COLLECTOR`, `PUMPKIN`

Key format: `scope/stat/userId` (e.g. `EASY_1/BestTime/123`)

Times are stored as **milliseconds** (`math.round(seconds * 1000)`) so OrderedDataStore ranking works with integers. Collector/pumpkin counts are stored as raw integers.

- Maze boards: **ascending** (fastest first)
- Collector / Pumpkin boards: **descending** (most first)

`PlayerStats` exposes BindableFunctions: `GetStatsFunction`, `SaveStatsFunction`, `GetTop10Function`, plus `IncrementStats` (10s debounce **per player**, not per stat — a second collectible inside 10s will not increment the ordered store).

### World leaderboards

`Workspace.Leaderboard` panels, refreshed every **70s**:

| Panel | `MazeId` |
|---|---|
| Easy 1 Leaderboard Panel | `EASY_1` |
| Easy 2 Leaderboard Panel | `EASY_2` |
| Mild 1 Leaderboard Panel | `MILD_1` |
| Mild 2 Leaderboard Panel | `MILD_2` |
| Hard 1 Leaderboard Panel | `HARD_1` |
| Insane 1 Leaderboard Panel | `VERTICAL_1` |
| Collector Leaderboard Panel | `COLLECTOR` |

There is a PUMPKIN datastore but **no pumpkin leaderboard panel**. `Leaderboard` would treat `PUMPKIN` as descending if such a panel existed.

Each panel has a `MazeId` StringValue and a SurfaceGui with Names/Score/Photos slots 1–10.

---

## 7. Collectibles (“Things”)

ProfileService store: **`BotJamMazePlayerProfile`**, key `Player_<userId>`

Profile template:

```
Things = {}       -- map of thingName → count
LastSession = "N/A"
Pumpkins = {}
```

In Studio, the store is **mocked** (`ProfileStore.Mock`), so Studio sessions do not write live data.

`ThingSpawn` loop:

1. Destroy all current Things
2. Wait cooldown (20s live / 2s Studio)
3. Spawn **8** things, weighted by rarity, onto unused `ThingSpawnLocation` pads (rank-weighted; every pad’s Rank is 1, so this is uniform)
4. Stay spawned for 120s live / 5s Studio
5. Repeat

Catalog (`ThingTemplates` in ServerStorage + rarity table in `ThingSpawn`):

| Key | Display | Rarity | Tag |
|---|---|---|---|
| PinkJiffy | Pink Jiffy | 0.10 | — |
| YellowJiffy | Yellow Jiffy | 0.10 | — |
| BlueJiffy | Blue Jiffy | 0.05 | — |
| RO01Red | Red RO-01 | 0.09 | — |
| OctopusToy | Octopus Toy | 0.09 | — |
| Native | Native | 0.10 | — |
| Bird | Blue Bird | 0.10 | — |
| HalloweenPumpkin1 | Halloween Pumpkin | 0.05 | pumpkin |
| HalloweenPumpkin2 | Halloween Pumpkin 2 | 0.05 | pumpkin |
| Pumpkin | Pumpkin | 0.10 | pumpkin |
| Pumpkin2 / 3 / 4 | Pumpkin 2–4 | 0.10 each | pumpkin |
| PumpkinFace | Pumpkin Face | 0.05 | pumpkin |

The **`ThingPart`** child of each template is tagged `Thing` (not the model). On spawn, pumpkin items also get CollectionService tag `pumpkin` on that `ThingPart`.

`CollectionController` listens for `Thing` touch → destroy ancestor model, fire `ThingCollected`, increment COLLECTOR or PUMPKIN ordered-store count.

Pumpkin profile split is **broken**:

- `CollectionController` fires `ThingCollected` with the listener tag `"Thing"` (not `"pumpkin"`) even for pumpkins
- `CharacterScript` writes to profile `Pumpkins` only if the event tag equals `"Pumpkin"` (capital P)
- Result: every pickup, pumpkin or not, goes into profile `Things`. OrderedDataStore `PUMPKIN` still increments when the part has tag `pumpkin`

Achievements HUD (`AchievementsScript`) lists every catalog key, greys out uncollected, shows checkmark + count for collected. Labels use the **internal key** (`PinkJiffy`), not the display name. Always reachable from Tools GUI (not maze-gated). Item-detail / BuyNow frame exists unused.

---

## 8. Monetization

### Gamepasses (`ServerConfiguration.PASSES`)

| Key | ID | Unlocks |
|---|---|---|
| WAYPOINTS_EASY_1 | 705277031 | Solution overlay for Easy 1 |
| WAYPOINTS_EASY_2 | 938971066 | Easy 2 map |
| WAYPOINTS_MILD_1 | 705103513 | Mild 1 map |
| WAYPOINTS_MILD_2 | 730377265 | Mild 2 map |
| WAYPOINTS_HARD_1 | 754828532 | Hard 1 map |
| WAYPOINTS_VERTICAL_1 | 940441143 | Insane 1 map |
| VERTICAL_1 | 940187199 | Insane maze access + JetPack |

Purchase flow: HUD waypoint button or shop prompt → `GamePassRemoteFunction` / `GamepassRequestFunction` → `MarketplaceService:PromptGamePassPurchase` if not owned → return ownership bool.

On character spawn, `CharacterScript` always fires `GamepassAvailable` for id `940187199`; `GamepassController` then shows the JetPack button only if owned.

### Waypoints (paid map)

On maze enter, waypoint button appears and is bound to that maze id (`productName`). Click:

1. Prompt/check the maze’s waypoint pass
2. If owned, clone `ReplicatedStorage.Maze Solution.<MAZE_ID>` into `Workspace.Mazes.Solution` (toggle: click again destroys it)

Easy 1 / Mild 1 solutions are **Arrow** models. Easy 2 / Mild 2 / Hard 1 / Vertical 1 are **Solution** path models.

TopbarPlus dropdown for buying all maps is **commented out** in `GUISetup`.

### Insane + JetPack

Lobby shop part `Insane 1` (gamepassId 940187199). Two gates at Insane landing:

1. Invisible `GamePassCheckpoint` collision barrier (shared `CanCollide`)
2. `Slide.SafeSlide` that teleports non-owners to `Lobby`

Owning the pass fires `GamepassAvailable` → client shows JetPack button and disables the lock SurfaceGui on `GamePassLockSign`.

### Breadcrumbs (unfinished)

Shop model `Star` with productId `"Star"`. Client `BuyTool` (RunContext Client) fires `PurchaseDevProduct` RemoteEvent. Server `BreadcrumbsHandler` treats **any** that event as “reload breadcrumbs”: add 30, cap 100, stored as `IntValue BreadcrumbAmount` on the character (not persisted).

While amount > 0, every 2s if the player moved > 1 stud, clone a Star mesh into `Workspace.Breadcrumbs`.

There is **no MarketplaceService.ProcessReceipt** handler in the place, so a real developer product purchase is not wired. The remote is a client-fireable “give me breadcrumbs” event.

---

## 9. Special hazards

### d20 dice (`CollectionService` tag `d20`)

Present in MILD_1, MILD_2, HARD_1 trap folders (one model each). Each model is tagged **twice**, so `d20Trigger` connects twice.

Touch any face part → wait until the die stops → read the highest-Y face with attribute `Face`:

- Faces **1, 2, 3** → Explosion (BlastRadius 60) then destroy the die
- Faces **18, 19, 20** → teleport using the die’s `Teleport_Target_Place_ID` / `Teleport_Target_Location`, then destroy
  - MILD_1 → `Mild 1 Entrance`
  - MILD_2 → `Mild 2 Exit`
  - HARD_1 → `Hard 1 Exit`
- Other faces: nothing

Place ID is `0` on all three, so these are in-place `MoveTo` teleports.

### Jailbreaker

Hidden parts at MILD_1 / MILD_2 / HARD_1 exits. CollectionService tag is **`Jailbreaker`** (not `JailbreakerTrigger`).

| Maze | Tagged parts | Local `JairbreakerScript` | On touch |
|---|---|---|---|
| MILD_1 | 1 | no | badge only |
| MILD_2 | 3 | yes (all 3) | badge + `MazeCompleted` |
| HARD_1 | 1 | yes | badge + `MazeCompleted` |

The CollectionService handler (`JailbreakerTrigger` script) **only awards the badge**. `MazeCompleted` (timer stop / hunter cleanup) is fired only by the misspelled local `JairbreakerScript`.

### Fall / out-of-bounds

`TeleportTrap` / `TeleporTrigger` parts under `Workspace.Teleport Triggers` `MoveTo` the player back to that maze’s entrance (or Hard 1 Entrance). These do **not** reset the timer. See the table in §3 — Easy 1 / Easy 2 / Insane have none.

---

## 10. Tutorial (partially abandoned)

`TutorialHandler` knows three steps:

1. `Tutorial` → clone “Gate Tutorial” into Workspace, show “Beam to Gates”
2. `Beam to Gates` complete → skip “Fire to Paint Tile”, jump to “Get the Battery”
3. `Get the Battery` complete → hide

`ReplicatedFirst.Tutorials` still has UI frames for all three. Nothing in the current join flow fires the initial `Tutorial` event, so this never starts for new players.

---

## 11. UI (StarterGui)

| ScreenGui | When | Contents |
|---|---|---|
| Teleporting | Cross-place teleport | Full-screen “Teleporting” label |
| Tools | Always | Waypoints (shown on maze enter, hidden on complete), Crouch (shown on maze enter, **not** hidden on complete), Achievements (always), Accessories/JetPack (pass + zone) |
| Timer | Maze run | Live time + best time (not hidden on death or complete) |
| AchievementsGui | Toggle | Collection grid + unused item-detail / BuyNow frame |

`GUIConfiguration` has an unused score-image set (P_0 … P_100). Stamina has **no HUD bar**.

---

## 12. Audio

`RandomMusicPlayer` cycles a list of 7 SoundIds on `SoundService.BackgroundMusic`. Outer loop interval is **2 seconds** (comment says 5 minutes), but `playRandomMusic` first polls every **5s** until the current track is not `Playing`, then picks another and plays it. Net effect: next track starts shortly after the current one ends, not every 2 seconds.

Track ids: `1837560230`, `1836842889`, `5410086218`, `1846368080`, `7024220835`, `1847661821`, `72215777970446`.

---

## 13. Data & identity

| Store | Kind | Purpose |
|---|---|---|
| `BotJamMazePlayerProfile` | ProfileService | Things, Pumpkins, LastSession |
| `BotJamMazeRunnerStatsStore` | OrderedDataStore, per-scope | BestTime, collector counts |

Owner user id in config: `3757284903`.

Character / player flag attributes: `IsAlive` (on player, set true on spawn, false on despawn/leave), `InMaze` (on player).

---

## 14. Script map (rebuild-relevant)

### Server (`ServerScriptService`)

| Script | Job |
|---|---|
| `ServerConfiguration` | Speeds, pass ids, badge ids, maze table, JetPack boost |
| `CharacterScript` | Profile init, join funnel (per spawn), collectible writes, boost apply |
| `PlayerDataHandler` | ProfileService wrapper |
| `PlayerStats` + `DSHelper` | OrderedDataStore I/O |
| `MazeEntranceTrigger` / `MazeExit` | Tag-based enter/exit |
| `MazeStats` | Timer + best-time save |
| `Leaderboard` | World boards |
| `TeleportManager` + `SafeTeleport` | Touch teleports under `Workspace.Teleport Triggers` |
| `ThingSpawn` + `CollectionController` | Collectible spawn/pickup |
| `HunterBotHandler` | Per-player hunter bots on HARD_1 |
| `GamePassPurchaseHandler` + `GamepassController` | Pass prompts + JetPack unlock |
| `AccessoryHandler` + `AccessoryRestrictor` | Equip / zone |
| `BadgeHandler` (module + script) | Award on `AwardBadge` bindable |
| `BreadcrumbsHandler` | Star trail |
| `JailbreakerTrigger` | Tag `Jailbreaker` → badge only |
| `d20Trigger` | Tagged dice |
| `TutorialHandler` | Unused tutorial state machine |
| `RandomMusicPlayer` | BGM |
| `MazeGenerator` / `MazeGenerator Orig` | Offline image-to-maze builders (see below) |
| `Draft` / `TODO` | Scratch / notes — not game logic |

### Client

- `StarterCharacterScripts`: `StaminaScript`, `GUISetup`, `UserInput`, `TimerScript`
- Tools LocalScripts: `WaypointScript`, `CrouchingScript`, `AchievementsScript`

### Per-instance (cloned with the maze / lobby)

Turret controllers, trap scripts, lift scripts, BattleBot/GoldBot/HunterBot NPC+pathfinding+trap, drone FireScript, shop prompts, Insane checkpoint + slide eject.

Bots live as templates in `ServerStorage.Bots` (`BattleBot`, `HunterBot`) and as already-placed copies inside Mild mazes.

---

## 15. How mazes were built (not how they run)

`MazeGenerator` and `MazeGenerator Orig` are **build tools left in ServerScriptService**. They embed a grayscale pixel matrix (likely from a maze image) and stamp Parts:

- Dark cells (`<= 70` or `< 50`) → wall
- Mid cells → green “Solution” balls (path overlay)
- Light cells → floor (Orig only)

They parent into `Workspace.Mazes.Folder`, which **does not exist** in the live tree. The playable mazes are already baked geometry (containers, wall models, vertical walls). Do not treat these scripts as runtime generation.

---

## 16. Rebuild notes — what is actually load-bearing vs leftover

### Load-bearing (keep the *behavior*)

- Hub → maze → landing → next maze physical layout
- Six mazes with the identities, badges, and gamepasses above
- Enter = start timer + HUD; Exit (alive) = badge + best time
- HARD_1 hunter bots (4, chase the entering player every 1s, despawn on complete / death / leave)
- Waypoint overlay gated per maze
- Insane gates (shared collision checkpoint **and** slide-eject to Lobby) + JetPack + zone restriction
- Collectibles + collector leaderboard
- World time leaderboards
- Sprint with stamina
- Hazard types: kill beams, damage pads, pumpkin fire, drone rings, d20, fall teleports back to entrance (Mild/Hard only)

### Duplicated (pick one in the rebuild)

- Maze exit is handled **twice** on EASY_1 / MILD_1 / MILD_2: CollectionService `MazeExit` **and** child `Exit Maze` (no health check). EASY_2 / HARD_1 / VERTICAL_1 are CollectionService only
- Jailbreaker: CollectionService tag `Jailbreaker` (badge only) **and** local `JairbreakerScript` on MILD_2 / HARD_1 (badge + maze complete). MILD_1 is tag-only
- `BadgeHandler` exists as both ModuleScript and Script (the Script requires the Module and connects the bindable — that part is fine, the dual exit firing is not)
- Each d20 model is CollectionService-tagged twice
- HunterBot has unused `NPC1` / `Pathfinding` / `SolveMaze` scripts on the template

### Broken / incomplete (do not copy blindly)

- Breadcrumbs: client can fire `PurchaseDevProduct` with no receipt processing
- Tutorial never starts
- TopbarPlus shop UI is commented out
- Stamina bar assets exist in `GUIConfiguration` but are unused
- Crouch restores JumpPower 50, not 100, and `UseJumpPower` is false by default
- Sprint gamepad branch is logically wrong
- `RandomMusicPlayer` interval constant is 2 seconds (comment says 5 minutes); actual gap is “until current track ends”
- HARD_1 completion badge missing from `ServerConfiguration.MAZES` but present on the part
- Pumpkin counts increment the ordered store but are never written to profile `Pumpkins` (tag mismatch)
- `IncrementStats` 10s debounce is per-player, so two pickups inside 10s only count once on the collector board
- Death does not clear `InMaze` or hide the timer
- Analytics “Player Joined” fires on every respawn
- `GamePassCheckpoint.CanCollide` is global, not per-player
- Pumpkin counts are stored but have no leaderboard panel
- `MazeGenerator*` and `Draft` are editor leftovers
- ProfileService is mocked in all Studio sessions
- `Tokens`, `Mechs`, `Workspace.Breadcrumbs` start empty; MechTemplates exist but nothing spawns them (`SpawnMechRemote` is unused)
- `TODO` script is a one-line note: “Reward users for completing your core loop with feedback, currency, items, and achievements.” There is **no currency**
- Easy 1 / Easy 2 / Insane have no fall-respawn traps
- Hard 1 fall parts are named `TeleporTrigger`

### Suggested rebuild modules (names only, not a commitment)

1. **Session / Player** — join, profile, attributes
2. **MazeRun** — enter, timer, exit, badge, best time (clear timer on death)
3. **WorldNav** — lobby teleports, fall-respawn to entrance
4. **Hazards** — beams, pads, projectiles, dice (data-driven)
5. **Bots** — patrol vs hunt, per-maze config
6. **Collectibles** — spawn table, pickup, collection UI
7. **Monetization** — gamepasses (maps, insane, jetpack)
8. **Leaderboards** — ordered stats + SurfaceGui / modern UI
9. **Movement** — walk, sprint/stamina, crouch, jetpack + zone

---

## 17. Player-facing feature list (acceptance for a rebuild)

A rebuilt version that “does what this game does” should let a player:

1. Spawn in a shared lobby with signs pointing to Easy / Mild / Hard / Insane
2. Enter Easy 1, get a live timer, reach the exit, get a badge, see time on a world board
3. Continue through Easy 2, Mild 1, Mild 2, Hard 1 in connector lobbies
4. Die to turrets / traps and respawn in the main lobby (run is not saved; current live code also leaves the timer HUD running)
5. Fall off Mild/Hard mazes and be put back at that maze’s entrance (timer keeps running). Easy/Insane have no equivalent floor traps
6. Buy a map gamepass and toggle a solution overlay for the maze they are in
7. On Hard 1, be chased by hunter bots that disappear when they finish, die, or leave
8. Find jailbreaker secrets on Mild/Hard exits for extra badges (Mild 2 / Hard 1 also stop the timer; Mild 1 does not)
9. Be blocked from Insane until they own the Insane gamepass (collision checkpoint + slide that boots non-owners to the lobby); then use a JetPack in the allowed lobby zone
10. Pick up world collectibles that persist and show in an Achievements/collection panel
11. See top-10 fastest times per maze and top collectors on lobby boards
12. Sprint with a stamina limit
