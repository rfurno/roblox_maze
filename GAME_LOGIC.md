# Maze Runner — Game Logic Inventory

Place: **Maze Runner** (`placeId: 16171071941`)
Studio instance reviewed in Edit mode.

This document describes what the live place actually does, as implemented. It is the source of truth for a from-scratch rebuild. Legacy, duplicated, and unfinished pieces are called out at the end.

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

There is **no matchmaking, no rounds, no lives economy**. Death respawns at the enabled SpawnLocation (the main lobby spawn). Mazes are always present in the same place; they are not generated at runtime in the live game.

---

## 2. Core player loop

```
Join
  → spawn in Main Lobby (only enabled SpawnLocation)
  → walk to a difficulty landing
  → touch MazeEntranceTrigger
       • start stopwatch
       • show HUD timer + personal best
       • show waypoint + crouch buttons
       • HARD_1 only: spawn 4 HunterBots that chase this player
  → navigate maze, avoid hazards
  → touch MazeExit (must be alive)
       • award completion badge
       • stop timer, save if new best
       • hide waypoint HUD
       • destroy that player's HunterBots
  → emerge in that maze's landing / next-lobby
  → either continue to the next maze or teleport back to Main Lobby
```

Onboarding analytics funnel (AnalyticsService):

1. Player Joined
2. Player Entered Maze
3. Player Completed Maze

---

## 3. World layout

The place is one large static world. Folders under `Workspace`:

| Folder | Role |
|---|---|
| `Lobby` | Hub, shop, connector rooms between mazes |
| `Mazes` | The six playable mazes + empty `Solution` folder |
| `Teleport Triggers` | Touch parts that move players in-place or to another experience |
| `Teleport Target Locations` | Named destination parts used by in-place teleports |
| `Leaderboard` | World SurfaceGui boards |
| `Things` | Runtime collectible instances |
| `ThingSpawnLocation` | 17 spawn pads for collectibles |
| `Breadcrumbs` | Runtime dropped star trail |
| `Mechs` | Empty (legacy) |
| `Tokens` | Empty |
| `Player Blocker` | Empty at root; some mazes have their own |
| `Tutorial Assets` | Runtime tutorial clones |
| `EasterEggs` | Two Halloween Balloon tools |

### Hub rooms (`Workspace.Lobby`)

- **Main** — spawn lobby, walls, floor, AccessoryZone (JetPack allowed here)
- **Easy - Landing**, **Easy 1 to 2 Lobby**, **Easy 2 to 3 Lobby**
- **Mild - Landing**, **Mild 1 to 2 Lobby**, **Mild 2 to 3 Lobby**
- **Hard - Landing**, **Hard 1 to 2 Lobby**
- **Insane - Landing**, **Insane 1 to 2 Lobby** — gamepass-gated
- **Shop** — Insane gamepass prompt + breadcrumb “Star” bowl
- **Signs**, **Props**

Progression is **physical**, not a menu. Completing Easy 1 dumps you in Easy 1-to-2 lobby, from which you enter Easy 2, and so on.

### In-place teleport targets

Named parts under `Workspace.Teleport Target Locations`:

`Lobby`, `Easy 1 Entrance`, `Easy 2 Entrance`, `Easy 2 Lobby`, `Mild 1 Entrance`, `Mild 2 Entrance`, `Mild 2 Lobby`, `Mild 2 Exit`, `Hard 1 Entrance`, `Hard 1 Exit`

Most maze folders also have **TeleportTrap** parts that send a fallen player back to that maze’s entrance. Each maze folder has a **TeleportTrigger** back to `Lobby`.

One **Other Experiences** trigger teleports to place `13056501521` (cross-place).

### SpawnLocations

Only `Workspace.SpawnLocation` is **Enabled**. All maze entrance/exit SpawnLocations exist but are disabled (used as visual/physical pads, not Roblox respawn points).

---

## 4. Mazes

Internal IDs (used everywhere in scripts / datastores / remotes):

| ID | Player-facing name | Board | Badge on exit |
|---|---|---|---|
| `EASY_1` | Easy 1 | Two 6×6 crate/container boards | `437680051584782` |
| `EASY_2` | Easy 2 | Two 6×6 boards + stairs | `3303135643125970` |
| `MILD_1` | Mild / “a Little Harder” 1 | One 12×12 wall board | `4069310029355913` |
| `MILD_2` | Mild 2 | Two 12×12 boards + elevator | `2975952186957333` |
| `HARD_1` | Hard 1 | One 12×12 floor+walls | `3987381879139424` |
| `VERTICAL_1` | Insane 1 | Tall/vertical board (~2763 wall parts) | `1846732522957557` |

`ServerConfiguration.MAZES` maps each maze to a waypoint gamepass and (except HARD_1 in config) a completion badge key. HARD_1 still awards a badge from the exit part’s `BadgeId` value.

Each maze folder has a common skeleton:

- `Entrance` — arch, sign, shining lights, entrance plate, **MazeEntranceTrigger** (`MazeName` StringValue)
- `Exit` — exit plate, **MazeExit** (`BadgeId`, `MazeId`)
- `Arena` — outer walls/floor
- `Board…` — the actual maze geometry
- `Bots` — empty, pre-placed patrol bots, or HunterBot spawn pads
- `Player Blocker` — walls (most mazes)
- `Traps` / `Turrets` / `Props` as needed

### EASY_1

- Theme: shipping containers as walls (`BoardCrates6x6` × 2)
- **Turrets**: 3 turret groups. Beams toggle on/off every 3 seconds. Touching `BeamTrigger` deals **100 damage** (instant kill at default health).
- **Barrels**: yellow barrels (ooze scripts exist on some; pathing is messy)
- No bots
- Waypoint pass: `WAYPOINTS_EASY_1` (id `705277031`)
- Solution stored as Arrow models in `ReplicatedStorage.Maze Solution.EASY_1`

### EASY_2

- Two 6×6 boards with stairs between them
- **PumpkinTraps** (2): visual fire builds over 15s, then both fire emitters + touch triggers enable for 5s. Touch deals **30 + 30** damage (2s apart).
- No bots
- Waypoint pass: `WAYPOINTS_EASY_2` (id `938971066`)

### MILD_1

- 12×12 `Maze Wall` parts
- **5 DamageTraps**: 100 damage on touch
- **Turrets**: same 100-damage toggling beams as Easy 1
- **2 BattleBots**: patrol 4 `Patrol End Points` via PathfindingService. Contact uses a child Trap Script. Ragdoll on death.
- **d20 dice** trap (see §7)
- **Jailbreaker** secret at exit (badge `443964865251442`)
- Waypoint pass: `WAYPOINTS_MILD_1` (id `705103513`)

### MILD_2

- Two 12×12 boards (`Walls` models of ~575 parts, plus a 513-part Floor on board 2)
- **Elevators** on board 1: PrismaticConstraint ping-pongs every 6 seconds (~-16 to +16). Platform has a Trap Script.
- **Lasers**: BeamTriggers deal 100 damage (controller does **not** toggle like Easy/Mild 1 — beams appear always-on)
- **Bots**: 2 GoldBots, 2 BattleBots (patrol), **5 Sci Fi Drones**
- Drones fire a damaging **ring projectile** every 3s; ring tweens to a Target over 10s and deals **100** on touch
- d20 dice + 3 Jailbreaker parts (badge `1309464804730436`)
- Waypoint pass: `WAYPOINTS_MILD_2` (id `730377265`)

### HARD_1

- 12×12 floor (516) + walls (573)
- **No pre-placed combat bots.** `Bots` folder has `BotSpawnLocation1` and `BotSpawnLocation2`.
- On maze enter, **4 HunterBots** are cloned from `ServerStorage.Bots.HunterBot`, assigned `Configuration.Player = player.Name`, and chase that player every 1s via pathfinding. Destroyed on maze complete, character despawn, or player leave.
- d20 dice, Jailbreaker (badge `2607997495211781`), BattleBot **prop**
- Waypoint pass: `WAYPOINTS_HARD_1` (id `754828532`)
- Config has no `COMPLETION_BADGE_ID` key, but the exit plate still awards `3987381879139424`

### VERTICAL_1 (Insane)

- Huge vertical maze (`Board` with thousands of Wall parts)
- **Gamepass-gated** (`PASSES.VERTICAL_1` / id `940187199`)
  - Shop proximity prompt in lobby
  - `GamePassCheckpoint` at Insane landing: if player owns the pass, the checkpoint `CanCollide` becomes false; otherwise it stays solid
  - Owning the pass also unlocks the **JetPack** accessory button
- Waypoint pass: `WAYPOINTS_VERTICAL_1` (id `940441143`, tool name “Waypoints Insane 1”)
- No bots, no traps folder
- JetPack is **restricted outside AccessoryZone** (Main lobby + Easy landing zone triggers). Leaving the cube unequips it.

---

## 5. Movement and character

Defaults in `ServerConfiguration`:

- WalkSpeed **25**
- JumpPower **100**

`StarterPlayer` still has engine defaults (WalkSpeed 16, JumpPower ~50). Live speed is applied by `StaminaScript` (`humanoid.WalkSpeed = 25`).

### Sprint

Client `StaminaScript`:

- Hold Left Shift (gamepad R2 is *intended* but the condition is written as `KeyCode ~= LeftShift or KeyCode == ButtonR2`, so R2 does not actually start sprint)
- +10 WalkSpeed, cap 46
- Stamina 100, drain 10/s, regen 10/s
- Exhausted at 0; can sprint again after stamina > 60
- Disabled while a boost (JetPack) is active

### Crouch

HUD button in maze (shown on maze enter). Fires BindableEvent `Animate`. `UserInput` LocalScript plays animation `rbxassetid://16676342149`, WalkSpeed −9, JumpPower 0. Toggle off resets WalkSpeed to 25 and JumpPower to **50** (not 100 — mismatch with server default). Keyboard C is commented out.

### JetPack accessory

- Template in `ServerStorage.AccessoryTemplates` (`JetPack`, plus Blue/White variants unused by the current attach path)
- Config: `TOOLS.JetPack` — type ACCESSORY, requires gamepass `940187199`
- Boost while equipped: WalkSpeed **30**, JumpPower **100**
- Client HUD button `AccessoriesImageButton` (productName JetPack) fires `AttachAccessoryRemote`
- Server `AccessoryHandler` clones accessory onto character, unequips any previous accessory sharing the same Attachment name, applies boost via `BoostPlayer`
- `AccessoryRestrictor` keeps it inside a bounding cube defined by `AccessoryBoundaryMark` parts. ZoneTrigger touch: inside cube → restore tool UI; outside → unequip + hide

---

## 6. Timer, stats, leaderboards

### Per-run timer

On player join, `CharacterScript` fires `SetupTimer`. `MazeStats` creates `ReplicatedStorage.Timer/<PlayerName>` with `StartTime` and `StopTime` StringValues.

On maze enter:

- `player.InMaze = true`
- StartTime = `tick()`
- coroutine writes `tick()` into StopTime every 0.5s while `InMaze`
- client is sent personal best via `ShowTimerRemote`

On maze complete:

- `InMaze = false`
- elapsed = stop − start
- if elapsed < previous best (or no previous), save as BestTime

Client `TimerScript` listens to StopTime.Changed and formats `HH:MM:SS:mmm`. Shows “Best: …” if best > 0.

### Persistence (OrderedDataStore)

Store name: **`BotJamMazeRunnerStatsStore`**

Scopes: `EASY_1`, `EASY_2`, `MILD_1`, `MILD_2`, `HARD_1`, `VERTICAL_1`, `COLLECTOR`, `PUMPKIN`

Key format: `scope/stat/userId` (e.g. `EASY_1/BestTime/123`)

Times are stored as **milliseconds** (`math.round(seconds * 1000)`) so OrderedDataStore ranking works with integers. Collector/pumpkin counts are stored as raw integers.

- Maze boards: **ascending** (fastest first)
- Collector / Pumpkin boards: **descending** (most first)

`PlayerStats` exposes BindableFunctions: `GetStatsFunction`, `SaveStatsFunction`, `GetTop10Function`, plus `IncrementStats` (10s debounce per player).

### World leaderboards

`Workspace.Leaderboard` panels, refreshed every **70s**:

- Easy 1, Easy 2, Mild 1, Mild 2, Hard 1, Insane 1 (times)
- Collector (COLLECTOR count)
- There is a PUMPKIN datastore but **no pumpkin leaderboard panel**

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
3. Spawn **8** things, weighted by rarity, onto unused `ThingSpawnLocation` pads (rank-weighted)
4. Stay spawned for 120s live / 5s Studio
5. Repeat

Catalog (`ThingTemplates`):

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

Templates are tagged `Thing`. `CollectionController` listens for `Thing` touch → destroy model, fire `ThingCollected`, increment COLLECTOR or PUMPKIN count.

Achievements HUD (`AchievementsScript`) lists every catalog item, greys out uncollected, shows checkmark + count for collected. Always visible from Tools GUI (not maze-gated).

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

### Waypoints (paid map)

On maze enter, waypoint button appears and is bound to that maze id (`productName`). Click:

1. Prompt/check the maze’s waypoint pass
2. If owned, clone `ReplicatedStorage.Maze Solution.<MAZE_ID>` into `Workspace.Mazes.Solution` (toggle: click again destroys it)

Easy/Mild 1 solutions are **Arrow** models. Mild 2 / Hard / Easy 2 / Vertical are **Solution** path parts.

TopbarPlus dropdown for buying all maps is **commented out** in `GUISetup`.

### Insane + JetPack

Lobby shop part `Insane 1` (gamepassId 940187199). Checkpoint barrier at Insane landing. Owning the pass fires `GamepassAvailable` → client shows JetPack button and disables the lock SurfaceGui.

### Breadcrumbs (unfinished)

Shop model `Star` with productId `"Star"`. Client `BuyTool` fires `PurchaseDevProduct` RemoteEvent. Server `BreadcrumbsHandler` treats **any** that event as “reload breadcrumbs”: add 30, cap 100, stored as `IntValue BreadcrumbAmount` on the character (not persisted).

While amount > 0, every 2s if the player moved > 1 stud, clone a Star mesh into `Workspace.Breadcrumbs`.

There is **no MarketplaceService.ProcessReceipt** handler in the place, so a real developer product purchase is not wired. The remote is a client-fireable “give me breadcrumbs” event.

---

## 9. Special hazards

### d20 dice (`CollectionService` tag `d20`)

Present in MILD_1, MILD_2, HARD_1 trap folders.

Touch → wait until the die stops → read the highest-Y face:

- Faces **1, 2, 3** → Explosion (BlastRadius 60) then destroy the die
- Faces **18, 19, 20** → teleport using the die’s `Teleport_Target_Place_ID` / `Teleport_Target_Location`, then destroy
- Other faces: nothing

### Jailbreaker

Hidden parts at MILD_1 / MILD_2 / HARD_1 exits. Touch awards a **secret badge** (ids in §4) and also fires `MazeCompleted` (so it can stop the timer as if the maze were finished). Dual implementation: CollectionService `JailbreakerTrigger` **and** local `JairbreakerScript` on the parts.

### Fall / out-of-bounds

`TeleportTrap` parts around mazes `MoveTo` the player back to that maze’s entrance target. These do **not** reset the timer.

---

## 10. Tutorial (partially abandoned)

`TutorialHandler` knows three steps:

1. `Tutorial` → clone “Gate Tutorial” into Workspace, show “Beam to Gates”
2. `Beam to Gates` complete → skip “Fire to Paint Tile”, jump to “Get the Battery”
3. `Get the Battery` complete → hide

`ReplicatedFirst.Tutorials` still has UI frames for all three. Nothing in the current join flow fires the initial `Tutorial` event, so this likely never starts for new players.

---

## 11. UI (StarterGui)

| ScreenGui | When | Contents |
|---|---|---|
| Teleporting | Cross-place teleport | Full-screen “Teleporting” label |
| Tools | Always | Waypoints (maze only), Crouch (maze only), Achievements, Accessories/JetPack (pass + zone) |
| Timer | Maze run | Live time + best time |
| AchievementsGui | Toggle | Collection grid + unused item-detail / BuyNow frame |

`GUIConfiguration` has a unused score-image set (P_0 … P_100). Stamina has **no HUD bar**.

---

## 12. Audio

`RandomMusicPlayer` cycles a list of 7 SoundIds on `SoundService.BackgroundMusic`. The wait-between-tracks is set to **2 seconds** (comment says 5 minutes). It waits until the current track stops, then picks another.

---

## 13. Data & identity

| Store | Kind | Purpose |
|---|---|---|
| `BotJamMazePlayerProfile` | ProfileService | Things, Pumpkins, LastSession |
| `BotJamMazeRunnerStatsStore` | OrderedDataStore, per-scope | BestTime, collector counts |

Owner user id in config: `3757284903`.

Character flag attributes: `IsAlive`, `InMaze`.

---

## 14. Script map (rebuild-relevant)

### Server (`ServerScriptService`)

| Script | Job |
|---|---|
| `ServerConfiguration` | Speeds, pass ids, badge ids, maze table, JetPack boost |
| `CharacterScript` | Profile init, join funnel, collectible writes, boost apply |
| `PlayerDataHandler` | ProfileService wrapper |
| `PlayerStats` + `DSHelper` | OrderedDataStore I/O |
| `MazeEntranceTrigger` / `MazeExit` | Tag-based enter/exit |
| `MazeStats` | Timer + best-time save |
| `Leaderboard` | World boards |
| `TeleportManager` + `SafeTeleport` | Touch teleports |
| `ThingSpawn` + `CollectionController` | Collectible spawn/pickup |
| `HunterBotHandler` | Per-player hunter bots on HARD_1 |
| `GamePassPurchaseHandler` + `GamepassController` | Pass prompts + JetPack unlock |
| `AccessoryHandler` + `AccessoryRestrictor` | Equip / zone |
| `BadgeHandler` (module + script) | Award on `AwardBadge` bindable |
| `BreadcrumbsHandler` | Star trail |
| `JailbreakerTrigger` / `d20Trigger` | Tagged secrets/hazards |
| `TutorialHandler` | Unused tutorial state machine |
| `RandomMusicPlayer` | BGM |
| `MazeGenerator` / `MazeGenerator Orig` | Offline image-to-maze builders (see below) |
| `Draft` / `TODO` | Scratch / notes — not game logic |

### Client

- `StarterCharacterScripts`: `StaminaScript`, `GUISetup`, `UserInput`, `TimerScript`
- Tools LocalScripts: waypoints, crouch, achievements

### Per-instance (cloned with the maze)

Turret controllers, trap scripts, lift scripts, BattleBot/GoldBot/HunterBot NPC+pathfinding+trap, drone FireScript, shop prompts, Insane checkpoint.

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
- HARD_1 hunter bots (4, chase the entering player, despawn after)
- Waypoint overlay gated per maze
- Insane gate + JetPack + zone restriction
- Collectibles + collector leaderboard
- World time leaderboards
- Sprint with stamina
- Hazard types: kill beams, damage pads, pumpkin fire, drone rings, d20, fall teleports back to entrance

### Duplicated (pick one in the rebuild)

- Maze exit is handled **twice**: CollectionService `MazeExit` **and** a child `Exit Maze` script on each plate. Same for Jailbreaker.
- `BadgeHandler` exists as both ModuleScript and Script (the Script requires the Module and connects the bindable — that part is fine, the dual exit firing is not).

### Broken / incomplete (do not copy blindly)

- Breadcrumbs: client can fire `PurchaseDevProduct` with no receipt processing
- Tutorial never starts
- TopbarPlus shop UI is commented out
- Stamina bar assets exist in `GUIConfiguration` but are unused
- Crouch restores JumpPower 50, not 100
- Sprint gamepad branch is logically wrong
- `RandomMusicPlayer` interval is 2 seconds, not 5 minutes
- HARD_1 completion badge missing from `ServerConfiguration.MAZES` but present on the part
- Pumpkin counts are stored but have no leaderboard panel
- `MazeGenerator*` and `Draft` are editor leftovers
- ProfileService is mocked in all Studio sessions
- `Tokens`, `Mechs`, `Workspace.Breadcrumbs` start empty; MechTemplates exist but nothing spawns them (`SpawnMechRemote` is unused)
- `TODO` script is a one-line note: “Reward users for completing your core loop with feedback, currency, items, and achievements.” There is **no currency**.

### Suggested rebuild modules (names only, not a commitment)

1. **Session / Player** — join, profile, attributes
2. **MazeRun** — enter, timer, exit, badge, best time
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
4. Die to turrets / traps and respawn in the main lobby (timer lost)
5. Fall off a maze and be put back at that maze’s entrance (timer keeps running)
6. Buy a map gamepass and toggle a solution overlay for the maze they are in
7. On Hard 1, be chased by hunter bots that disappear when they finish or leave
8. Find jailbreaker secrets on Mild/Hard exits for extra badges
9. Be blocked from Insane until they own the Insane gamepass; then use a JetPack in the allowed lobby zone
10. Pick up world collectibles that persist and show in an Achievements/collection panel
11. See top-10 fastest times per maze and top collectors on lobby boards
12. Sprint with a stamina limit
)