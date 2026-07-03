# Architecture

Godot 4.7 project, GL Compatibility renderer. Engine version and renderer are pinned in `project.godot` — do not upgrade without checking these settings still make sense.

## Directory layout

- `scenes/` — one `.tscn` per composable game object (player, platform, level). No loose top-level scenes outside this folder. Each `.tscn` has a same-named `.md` file next to it (e.g. `hud.tscn` / `hud.md`) documenting its node structure and behavior in detail; ARCHITECTURE.md only holds a short summary + link. When a scene's nodes or behavior change, update its `.md` file (and the summary here if it's now stale) in the same change.
- `scripts/` — one `.gd` per node that needs behavior, named after the node/scene it's attached to (`player.gd` on `Player`, not on some unrelated node).
- `assets/` — non-script, non-scene resources, grouped by type (`assets/audio/`).

## Scene tree

Each scene has a short summary below; see its linked `.md` file (next to the `.tscn` in `scenes/`) for full node structure and behavior detail.

### [`scenes/main.tscn`](scenes/main.md) — the level

`Main` (`Node2D`), script: `scripts/main.gd`. The game's entry point. Composes instances of all other scenes (platforms, walls, player, water, enemies, seedlings, HUD, intro screen) into the single static level that currently exists — there is no level-loading/scene-management system yet. `main.gd` pauses the tree on `_ready()` until `IntroScreen` signals `start_requested`, and owns spawning: it connects to every child's `seed_popped` signal (if it has one) in `_ready()` and instantiates `seed.tscn` beside the plant that popped it. Step 6 will extend this same script with goal tracking and win-overlay logic.

### [`scenes/intro_screen.tscn`](scenes/intro_screen.md) — how-to-play overlay

`IntroScreen` (`CanvasLayer`), script: `scripts/intro_screen.gd`. A full-screen instructions overlay shown while `Main` keeps the tree paused; presses Space (`ui_accept`) to emit `start_requested` and free itself, letting `Main` unpause and start the level.

### [`scenes/platform.tscn`](scenes/platform.md) — static level geometry

`Platform` (`StaticBody2D`), no script. Scriptless collision + visual rectangle, resized by scaling the root.

### [`scenes/wall.tscn`](scenes/wall.md) — level boundary

`Wall` (`StaticBody2D`), no script. Same structure as `platform.tscn` but styled as a boundary, used to box in the level.

### [`scenes/water.tscn`](scenes/water.md) — water

`Water` (`Area2D`, group `water`), script: `scripts/water.gd`. A non-blocking area the player detects and rests on; exposes `get_surface_y()` only, knows nothing about the player.

### [`scenes/player.tscn`](scenes/player.md) — the flying bug

`Player` (`CharacterBody2D`), script: `scripts/player.gd`. The controllable bug — thrust-based flight, water sensing, pollen carrying/visuals, wing animation. See "Movement model" below for behavior.

### [`scenes/enemy.tscn`](scenes/enemy.md) — bug swarm hazard

`Enemy` (`Area2D`, group `enemy`), script: `scripts/enemy.gd`. Drifts within a leash radius of its spawn point and steals water from the player on touch.

### [`scenes/seedling.tscn`](scenes/seedling.md) — growing plant

`Seedling` (`Node2D`), script: `scripts/seedling.gd` (`@tool`). A plant lifecycle state machine (`GROWING → BLOOMED → POLLINATED → SEED_GROWING → (seed pops) → BLOOMED`), fully reachable: watering drives `GROWING`, pollination drives `POLLINATED`, and watering a `POLLINATED` plant again drives `SEED_GROWING`, which pops a seed (`seed_popped` signal, handled by `Main`) and reverts to `BLOOMED`.

### [`scenes/seed.tscn`](scenes/seed.md) — popped seed

`Seed` (`Area2D`, group `seed`), script: `scripts/seed.gd`. Currently inert beyond its spawn-in animation — carrying and planting land in Step 4.

### [`scenes/hud.tscn`](scenes/hud.md) — water meter

`HUD` (`CanvasLayer`), script: `scripts/hud.gd`. On-screen water meter that listens to the player's `water_level_changed` signal.

### `scripts/plant_data.gd` — plant data table

`PlantData` (`class_name`, not attached to any node) is the single source of truth for plant data: the `PlantType` enum, `POLLEN_COLORS` (typed const table mapping each *base* type to its pollen color, read via `PlantData.pollen_color(type)`), `SEED_COLORS` (covers all 13 types including hybrids, read via `PlantData.seed_color(type)` — used for the seed pod swelling on the parent plant and the loose `seed.tscn` visual, both of which need a color for hybrid results too), and `COMBO_TABLE` (the 8 successful hybrid combos, read via `PlantData.combo_result(a, b)`). Gameplay and UI must both read plant facts from here — display names land in this file when Step 5's combo chart needs them; nothing else may hardcode this data.

`PlantType` holds `NONE = -1` (the fizzle/no-result sentinel), the five base plants at their original values `0`-`4`, and the 8 hybrid types appended after them — all with explicit values, so `bloom_type` ints already saved in `main.tscn` keep mapping to the same base plants regardless of how the enum grows. Hybrid *visuals* aren't built until Step 4; for now `PlantType` values beyond the base five are pure data, produced by pollination and not yet rendered anywhere.

`combo_result(a, b)` looks up an unordered base pair (via `_pair_key`, `mini(a,b)*100 + maxi(a,b)`) in `COMBO_TABLE` and returns `PlantType.NONE` if the pair isn't listed. Only the 8 successful combos are in the table — the 2 documented fizzle pairs are exactly the base pairs left over, so there's no separate fizzle table to keep in sync. Same-type pollination (`a == b`) is the caller's responsibility to filter out before calling `combo_result`, since it's a no-op rather than a fizzle.

### `scenes/hud.tscn` — water meter

`HUD` (`CanvasLayer`), script: `scripts/hud.gd`, with a `Control` anchored top-left containing a `ProgressBar` (`WaterMeter`, range 0-1). `hud.gd` finds the player via the `player` group in `_ready()` and connects to its `water_level_changed` signal — the HUD reaches out to the player rather than the player knowing about the HUD, so `player.gd` stays UI-agnostic.

`WaterMeter` is themed blue (`StyleBoxFlat` overrides on `background`/`fill`) with a `ShaderMaterial` (`assets/shaders/water_meter.gdshader`) giving both bars a rippling top edge (vertex displacement) and a shimmering brightness pulse (fragment) — purely cosmetic, doesn't touch `value`. `clip_contents = true` on `WaterMeter` keeps its `Bubbles` child (`CPUParticles2D`, rectangle emission spanning the bar) contained to the bar's rect as small bubbles drift upward and fade, matching the CPUParticles2D convention used elsewhere (`WaterDrip`, `PollenPuff`).

## Movement model

`player.gd` implements thrust-based flight, not platformer walk/jump:

- Input (`move_left/right/up/down`, mapped to WASD + arrows + Space in `project.godot`) applies acceleration (`thrust`) in the corresponding direction every physics tick.
- Constant `gravity` pulls down; `air_drag` decelerates velocity each frame (proportional drag, not a fixed friction constant), producing a floaty, bug-like feel rather than instant stop/start.
- `velocity.limit_length(max_speed)` caps top speed in any direction.
- Facing: when `abs(velocity.x)` exceeds a small deadzone, `Visual.scale.x` is eased toward `sign(velocity.x)` via `move_toward`, so the bug smoothly turns to face its direction of horizontal travel instead of flying backwards. Collision and camera are outside `Visual` specifically so this flip never affects them.
- `wings.flapping` is set from input/airborne state each tick; `wings.gd` owns the actual flap animation (sine oscillation, two speeds for idle vs. active).
- Water resting: since `water.tscn`'s `Area2D` doesn't block movement like a floor, `player.gd` emulates landing on it each physics tick — while falling or still (`velocity.y >= 0`) and overlapping a `water` group area (via `WaterSensor`), once the bug's Y reaches the water's `get_surface_y()`, its position is pinned there and `velocity.y` zeroed, the same way `is_on_floor()` would behave on solid ground. Thrusting upward lifts it back off on the next tick.
- Drinking: while resting on water (see above) with no active movement input, the bug is "landed on water" and drinks — `Proboscis` becomes visible and `water_level` fills from 0 to 1 over `water_fill_time` (4s), emitting `water_level_changed` for `hud.gd` to display.
- Water theft: `player.gd` exposes `steal_water(amount)`, called by `enemy.gd` on touch (see `scenes/enemy.tscn` above) — clamps `water_level` down and re-emits `water_level_changed` the same way drinking does, so the HUD reacts identically regardless of which direction the level moved.
- Watering: each physics tick, `player.gd` checks `WaterSensor`'s overlapping areas (same poll used for water landing, just filtered to the `seedling` group instead of `water`) for a `HoverZone`, resolving the hovered `Seedling` once per tick. If `water_level > 0` and a seedling is hovered, it calls `water(delta)` on the zone's parent `Seedling` (see `scenes/seedling.tscn` above), draining `water_level` from 1 to 0 over `water_drain_time` (2s) the same way drinking fills it, and re-emitting `water_level_changed`. `Proboscis` and `WaterDrip` both reflect this state so the drip is visibly the source of the growth.
- Pollen (REQUIREMENTS.md Step 2): the same per-tick hovered-seedling lookup also drives `_handle_pollen_hover()`, independent of `water_level` — hovering only interacts with `BLOOMED` flowers. With an empty pollen slot, hovering calls `collect_pollen()` and picks it up (`has_pollen`/`pollen_type`, mirrored on `PollenBlob`). Carrying pollen and hovering the *same*-colored flower is a no-op; hovering a *different*-colored one calls `pollinate()` and reacts to the result (clears pollen either way, plays success or fizzle feedback). This is self-limiting rather than debounced: once a flower leaves `BLOOMED`, continued hovering does nothing further, the same way the watering poll above relies on `growth` capping out. `has_pollen`/`pollen_type` are exposed via `pollen_changed(has_pollen, pollen_type)`, mirroring `water_level_changed`, emitted only on actual change (not every frame while hovering). The `shed_pollen` input action (edge-triggered via `is_action_just_pressed`, bound to `Q`) drops carried pollen outright with a puff, independent of any hover target.
- Seed production (REQUIREMENTS.md Step 3): `player.gd`'s existing `hovered_seedling.water(delta)` call site is unchanged — `seedling.gd`'s `water(delta)` now branches on `state` itself, raising `growth` while `GROWING` or `seed_progress` while `POLLINATED`/`SEED_GROWING` (a plain var mirroring how `growth` tracks `GROWING`; entering `SEED_GROWING` and popping the seed are both transitions in `seed_progress`'s setter, the same bidirectional-transition pattern `growth`'s setter already uses for `GROWING ⇄ BLOOMED`). Popping emits `seed_popped(hybrid_type, at_position)`, which `Main` (`main.gd`) listens for on every seedling to instantiate `seed.tscn` beside the plant — the plant itself never touches the scene tree above it.

## Known gaps / not yet built

- The pollination game (REQUIREMENTS.md) is at Step 3 of 8: pollen pickup, pollination, and seed production are playable (`GROWING → BLOOMED → POLLINATED → SEED_GROWING → pop → BLOOMED`, with a `shed_pollen` action to drop carried pollen), but the popped seed is inert — no carrying, plots, combo chart, goal panel, or win condition yet. Hybrid `PlantType`s exist as data (`plant_data.gd`, now including `SEED_COLORS`) and are producible via pollination, but have no bloom visuals until Step 4.
- No level-transition, scoring, or win/lose — drinking and watering seedlings both move `water_level` but nothing else consumes it.
- No save/settings system.
- Input actions are defined by hand in `project.godot`; there is no in-game rebinding UI.

Update this section as these are built, rather than leaving it to go stale.
