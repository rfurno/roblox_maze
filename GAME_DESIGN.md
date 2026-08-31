# Maze Runner — Game Design (rebuild spec)

This is the source of truth for **gameplay**. Architecture, Rojo layout, and the rebuild roadmap are in **`DESIGN.md`**.

`GAME_LOGIC.md` is the inventory of the **live** place (`placeId: 16171071941`). Do not copy its scripts, tags, or bugs. Copy the *fantasy*: a shared-world obby maze you walk into, race, and badge.

MVP ships **without JetPack**. Insane is a gated climb that must be completable on foot.

---

## 1. Fantasy and audience

An obby-style maze runner in one shared Roblox place.

Players spawn in a central lobby, walk to a difficulty, enter a maze, and try to reach the exit fast without wasting the clock on deaths and detours. Completing a maze awards a badge, records a best time, and dumps them in a connector landing for the next maze.

No matchmaking. No rounds. No lives. No currency. The world is always there; mazes are baked geometry, not generated at runtime.

Audience: casual Roblox players who like obbies and a little speedrun. Easy 1 *is* the tutorial.

---

## 2. Design principles

1. **One run, one outcome.** Enter / fail / complete. No third state.
2. **Physical world stays.** Walking to Easy / Mild / Hard / Insane is the UX. No difficulty menu.
3. **Lethal hazards are learnable.** Beams, pads, chasers. RNG may scramble position; it may not kill.
4. **Pay for access or information, not for the game working.** MVP: All Maps + Insane door.
5. **Data-driven mazes.** Same run machine + a config table per maze.
6. **Easy is the tutorial.** No separate tutorial state machine.
7. **Bake at edit time, play as static geometry.** Players never wait on generation.

---

## 3. Core loop and run contract

```
Join
  → spawn in Main Lobby
  → walk to a difficulty landing (Insane blocked until owned)
  → cross Maze Gate
       • start Run (mazeId, startTime)
       • show timer + personal best + stamina
       • spawn that maze’s hunters (if any)
  → navigate, avoid hazards
       • fall off map → this maze’s entrance (run continues)
       • death → this maze’s entrance (run continues, hunters reset)
       • Give up / lobby portal → Fail, no save
  → touch Maze Exit (alive, run.mazeId matches this maze)
       • Complete
       • award maze badge (once)
       • save best time if faster
       • despawn hunters, hide run HUD
  → emerge in connector landing → next maze or portal home
```

### Run state

A player has **at most one run**.

| Field | Meaning |
|---|---|
| `InRun` | bool |
| `MazeId` | `EASY_1` … `INSANE_1` |
| `StartTime` | server clock at gate |

Timer elapsed = `now − StartTime`. Server owns it. Client only displays.

| Event | Result |
|---|---|
| Cross gate of maze A | If already in a run, that run **Fails**. Start a new run on A |
| Exit plate of A, alive, `MazeId == A` | **Complete** |
| Exit plate, dead or wrong maze | Ignore |
| Death | Not Fail. Respawn at **this maze’s entrance**. Timer keeps going. Hunters (if any) reset |
| Fall out of bounds | Teleport to this maze’s entrance. Timer keeps going |
| Lobby / Give-up portal | **Fail**. No BestTime write |
| Leave the game | **Fail** |

Complete writes BestTime only if faster than stored (or none stored). Fail never writes BestTime.

Analytics (once each, correctly):

- `Joined` — first spawn of the session, not every respawn
- `RunStarted` / `RunFailed` / `RunCompleted`

---

## 4. World layout

One static place.

**Main lobby** — only enabled SpawnLocation. Signs toward Easy / Mild / Hard / Insane. Shop (All Maps + Insane). Collector + time boards. Collectible spawn pads in the world, not inside maze corridors if they would break a race.

**Difficulty landings** — Easy, Mild, Hard, Insane. Insane landing is behind the paid door.

**Connector landings** — rest rooms *between runs*, not mid-run checkpoints:

- Easy 1 → Easy 1-to-2 → Easy 2 → Easy 2-to-3 (dead end / lobby portal)
- Mild 1 → Mild 1-to-2 → Mild 2 → Mild 2-to-3
- Hard 1 → Hard 1-to-2
- Insane 1 → Insane 1-to-2

Every landing has a **return-to-lobby** portal. Using it during a run Fails that run.

**Insane gate (pick one mechanism, not both):** a door that is non-colliding **only for owners** (collision group or per-player local clone). Not a shared `CanCollide` part. Not a slide that boots people to lobby *and* a barrier.

**Fall volumes:** every maze, including Easy and Insane, has an out-of-bounds box that `MoveTo`s the player to **that maze’s entrance**.

---

## 5. Mazes

Six identities. Completing Easy 1 is a full run; Easy 2 is a new run. Six badges, six time boards.

| ID | Role | Board | Hazards | Bots | Secret badge |
|---|---|---|---|---|---|
| `EASY_1` | Tutorial. Sprint, beams, death-at-entrance | Two stacked 6×6 crate boards (baker preset) | Toggling kill beams | none | no |
| `EASY_2` | Same difficulty, longer | 6×6 (baker) | Timed fire pads | none | no |
| `MILD_1` | First real pressure | 12×12 walls (baker) | Beams, damage pads, d20 | 2 patrol | yes |
| `MILD_2` | Moving / two-board | Two 12×12 + safe elevators (baker) | Always-on lasers, drones, d20 | 2 patrol + 2 drones | yes |
| `HARD_1` | Chase | 12×12 (baker) | Hunters, d20 | 2 hunters | yes |
| `INSANE_1` | Paid vertical climb | Hand-authored vertical (baker optional) | Geometry; optional beams | none | yes |

### Per-maze config (data)

Every maze is a row, not a unique script:

```
id, displayName
badgeId
requiresPass?          -- only INSANE_1
entrance / exit / fallTarget / lobbyPortal
hunters: { mode: none|patrol|hunt, count }
hazards: [ { type, ... } ]
dice?: { randomPads[4..8], luckyPad }
secret?: { part, badgeId }   -- does NOT complete the run
```

### Secrets

Mild / Hard / Insane each have one hidden touch part. Awards a secret badge **once**. Does not set Complete, does not stop the timer, does not despawn hunters.

### d20 (Mild 1, Mild 2, Hard 1)

One die per maze. Touch → wait until it settles → read top face. **Never kills. Never completes the maze.** Run stays active.

| Face | Result |
|---|---|
| **1, 2, 3** | Teleport to a **random pad in this maze** from an authored list (4–8 pads: entrance, dead-ends, side rooms). Never lobby, never another maze, never the exit plate |
| **18, 19, 20** | Lucky teleport to a named pad (shortcut / overlook). Not onto the exit trigger |
| **4–17** | Nothing. Short cooldown, can roll again |

After a teleporting roll, destroy or lock the die for the rest of that run so it cannot be farmed.

### Elevators (Mild 2)

Prismatic (or equivalent) ping-pong platforms. **Safe.** No damage trap on the platform.

### Bots

- **Patrol** (Mild): walk authored waypoints. Contact = **instant kill** (readable; default health 100 / damage 100).
- **Hunt** (Hard): 2 hunters, retarget the run player about once per second. Contact = instant kill. Spawn on RunStarted, despawn on Complete/Fail, reset on death.

---

## 6. Movement

| | Value |
|---|---|
| WalkSpeed | 25 |
| JumpPower | 100 |
| UseJumpPower | **true** (always) |
| Sprint | Hold Left Shift or gamepad R2. +10 WalkSpeed, cap 35 (25+10) |
| Stamina | 100. Drain 10/s while sprinting. Regen 10/s when not. Exhausted at 0; sprint again after > 60 |
| Stamina HUD | Visible bar while sprinting or recovering (not full) |
| Crouch | **Hold C** or left-stick click. −9 WalkSpeed, JumpPower 0 while held. No HUD button |
| JetPack | **Not in MVP** |

---

## 7. Timer, stats, leaderboards

**Timer** — server elapsed; client formats `HH:MM:SS:mmm`. Show personal best if one exists. HUD on while `InRun`; hide on Complete or Fail.

**Persistence**

- **ProfileStore** (player session): `{ Things = {}, LastSession = "N/A", BestTimes = {} }`. Key `tostring(userId)`. Not for leaderboards.
- **OrderedDataStore** `MazeRunnerStats` **per Roblox scope** (`EASY_1` … `INSANE_1`, `COLLECTOR`). Key `tostring(userId)`. Times as integer milliseconds.

Maze boards ascending (fastest first). Collector descending. HUD personal-best reads `BestTimes` on the profile; boards read ODS.

**World boards** — six time panels + one Collector panel, top 10, refresh ~60–70s. No pumpkin board.

No per-player debounce that drops legitimate pickups or time saves.

---

## 8. Collectibles

One catalog. One profile map `Things[id] = count`. One collector score.

MVP catalog: **8** items (reuse the non-seasonal toys: Jiffies, bird, octopus, etc.). Seasonal skins are later catalog rows with a `season` field, not a second datastore.

Spawn loop:

1. Clear current world Things
2. Wait cooldown (20s live / 2s Studio)
3. Spawn **6** onto unused pads (uniform unless a pad has Rank)
4. Live **60s** (5s Studio)
5. Repeat

Pickup: touch → server destroys model → increment `Things[id]` and COLLECTOR by 1. No 10-second debounce.

Achievements panel: always available from lobby HUD. Grey uncollected; check + count when collected. Use display names, not internal keys.

---

## 9. Monetization (MVP)

| Product | Unlocks |
|---|---|
| **All Maps** | Toggle solution overlay for **whatever maze the player is in** |
| **Insane** | Insane door |

No per-maze map passes. No breadcrumbs. No ProcessReceipt until a real developer product exists (none in MVP).

**Maps:** if owned, HUD button while `InRun` toggles a **client-local** clone of `ReplicatedStorage.MazeSolution.<MAZE_ID>` (baker stamps world CFrames). Click again destroys the local clone. Not a shared `Workspace.Mazes.Solution`.

**Insane:** ownership checked on the door. Shop prompt in the lobby.

**Post-MVP (not specified beyond this):** JetPack accessory, legal only in lobby + Insane, either its own pass or folded into Insane. Insane must remain completable without it.

---

## 10. HUD and input

| Element | When |
|---|---|
| Timer + PB | `InRun` |
| Stamina bar | sprinting or recovering |
| Give up | `InRun` (confirms → lobby, Fail) |
| Map toggle | `InRun` and owns All Maps |
| Achievements | always |
| Crouch | **no button** (hold C) |
| JetPack / accessories | **not in MVP** |
| Teleporting | only for cross-place (none required in MVP) |

---

## 11. Maze baker (edit-time only)

Source: `src/server/Baker` (Rojo). `RunBake` is Disabled. Not required by Session or MazeRun at runtime. Invoke `MazeBaker.Bake("EASY_1")` from the Studio command bar. Re-bake destroys that maze’s `Board*` folder only.

### What it stamps

Floor, walls from a template, perimeter, entrance/exit openings, tagged gate + exit plates, **void-shell** fall volume (under-floor slab + outer skirts — not a solid maze AABB), optional Solution overlay (unique-path centerline at world CFrames).

### What it does not stamp

Turrets, fire pads, bots, d20, secrets, lobby. Those come from maze config after the bake.

### Easy 1 preset (first consumer)

| Param | Value |
|---|---|
| `mazeId` | `EASY_1` |
| `seed` | knobbable while iterating; **lock an integer** for the shipped layout |
| `gridWidth` / `gridHeight` | 6 / 6 |
| `layers` | 2 |
| `cellSize` | 24 |
| `wallHeight` | 10.7 |
| `wallTemplate` | shipping-container model (clone, don’t unique-union) |
| `origin` | Easy landing CFrame |
| `entranceCell` | south, layer 1 |
| `exitCell` | north, layer 2 |
| `algorithm` | recursive backtracker (perfect maze) |
| `bakeSolution` | true |
| `layerConnector` | stairs at a cell on the unique path |

Later presets: Easy 2 (6×6, one or two layers); Mild/Hard (12×12, `Wall` template). Insane may stay hand-authored vertical.

The old `MazeGenerator` pixel-matrix scripts are **not** ported.

---

## 12. Rebuild modules

If it isn’t here, it isn’t in the game.

| Module | Job |
|---|---|
| **Session** | Join, profile, attributes, Joined analytics |
| **MazeRun** | Gate/exit, timer, badge, best time, hunter spawn, HUD flags. Only place `InRun` flips |
| **WorldNav** | Lobby portals, fall volumes, death-to-entrance, Give-up, d20 teleports |
| **Hazards** | KillBeam, DamagePad, TimedFire, ProjectileRing, MovingPlatform (safe), Dice |
| **Bots** | Patrol vs Hunt from maze config |
| **Collectibles** | Spawn table, pickup, collection UI |
| **Monetization** | All Maps, Insane door |
| **Leaderboards** | Ordered stats + SurfaceGui |
| **Movement** | Walk, sprint/stamina, crouch |
| **Maze baker** | Studio stamp; Easy 1 first |

---

## 13. What we will not build (MVP)

- JetPack, accessory zone, boost-on-equip
- Breadcrumbs / Star / fake developer products
- Tutorial state machine
- d20 explosion / random kill
- Dual exit scripts, dual jailbreaker, dual pumpkin inventory
- Mechs, tokens, TopbarPlus shop
- Shared CanCollide insane barrier + slide eject
- Runtime procedural mazes
- Lives, coins, matchmaking, seasons-as-a-mode, a second place
- Per-maze waypoint gamepasses

---

## 14. Acceptance (MVP)

A player can:

1. Spawn in a shared lobby with signs to Easy / Mild / Hard / Insane
2. Enter Easy 1 (baked 6×6×2 crate maze), see a live timer and PB, die to a beam, appear at **that maze’s entrance** with the timer still running, then finish and get a badge + board time
3. Give up to lobby and confirm the run did **not** save
4. Continue Easy 2 → Mild 1 → Mild 2 → Hard 1 through connector rooms; each is its own run
5. Fall off any maze (including Easy and Insane) and land at that maze’s entrance
6. On Hard 1, be chased by **two** hunters that reset on death and vanish on complete / give-up
7. Roll the d20 on Mild/Hard: a 1–3 scrambles them inside the maze; they do not die; the timer keeps going
8. Find a secret on Mild/Hard/Insane for an extra badge **without** completing the maze
9. Be blocked from Insane until they own Insane; then complete it **on foot**
10. Buy All Maps and toggle a solution overlay for the maze they are in
11. Pick up world collectibles that persist and show in Achievements
12. See top-10 times per maze and top collectors on lobby boards
13. Sprint with a visible stamina bar; crouch by holding C

Rebuild order (each step playable):

1. Maze baker + Easy 1 preset
2. Session + MazeRun + WorldNav on that Easy 1
3. HUD (timer, PB, stamina, give-up)
4. Easy 1 beams
5. Remaining mazes (baker presets and/or hand-dress)
6. Hazards + bots per config
7. Stats, leaderboards, badges
8. Collectibles + panel
9. Insane door + All Maps overlay

---

## 15. Defaults for leftover product calls

These were open in the plan; this spec locks them:

| Call | Default |
|---|---|
| Hunter / bot contact | Instant kill |
| MVP SKUs | Two: All Maps + Insane (not folded into one) |
| Lobby portal in every connector | Yes |
| Collectible cadence | 6 spawned, 60s live, 8 catalog items |
| d20 low faces | 1, 2, and 3 all random-teleport; 4–8 pads per maze |
| Easy 1 seed | Knob while iterating; lock before ship |
| Baker coverage | Easy 1/2 and Mild/Hard grids; Insane may be hand-authored |
| JetPack | Post-MVP; pass vs bundle undecided |
