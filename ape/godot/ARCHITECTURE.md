# Architecture

Godot 4.7 project, GL Compatibility renderer. Engine version and renderer are pinned in `project.godot` — do not upgrade without checking these settings still make sense.

## Directory layout

- `scenes/` — one `.tscn` per composable game object (player, platform, level). No loose top-level scenes outside this folder.
- `scripts/` — one `.gd` per node that needs behavior, named after the node/scene it's attached to (`player.gd` on `Player`, not on some unrelated node).
- `assets/` — non-script, non-scene resources, grouped by type (`assets/audio/`).

## Scene tree

### `scenes/main.tscn` — the level

`Main` (`Node2D`), the game's entry point (`run/main_scene` in `project.godot`). Currently a single static level:

- `Ground`, `Platform1`, `Platform2`, `Platform3` — instances of `platform.tscn`, positioned/scaled per-instance to build the level layout. No platform-specific script; layout is entirely position + scale data on the instance.
- `Music` — `AudioStreamPlayer` playing `assets/audio/happy_bee.mp3` ("Happy Bee" by Kevin MacLeod, incompetech.com, CC BY 3.0 — attribution required if the game is published), looped, low volume (`volume_db = -20`), `autoplay = true`.
- `Player` — instance of `player.tscn`.
- `WaterPond`, `WaterPuddle` — instances of `water.tscn`, one at ground level and one on a ledge (`Platform2`), showing water can sit at the bottom or up on a platform. Every level is expected to have some water.
- `Enemy1`-`Enemy5` — instances of `enemy.tscn`, positioned near different platform clusters so the wander leash (see below) keeps them spread across the level rather than bunched together.
- `Seedling1`-`Seedling10` — instances of `seedling.tscn`, one or two per platform top, positioned to sit on each platform's top surface, each with a different `growth` value and `bloom_type` so the level shows the full range from barely-sprouted to fully bloomed.
- `BoundsTop`, `BoundsBottom`, `BoundsLeft`, `BoundsRight` — instances of `wall.tscn`, forming a box around the whole level so the player can't fly off-screen. Left/right instances are rotated 90° and scaled along the (now vertical) local x-axis to span the box's height.
- `HUD` — instance of `hud.tscn`, the on-screen water meter.

There is no level-loading or scene-management system yet — `main.tscn` *is* the level. If a second level is added, this needs a level-container/loader layer before it grows further (see Coding conventions in CODING.md — don't build that abstraction until it's needed).

### `scenes/platform.tscn` — static level geometry

`Platform` (`StaticBody2D`) with a `CollisionShape2D` (`RectangleShape2D`) and two `Polygon2D` children (`Visual` body, `Top` accent strip) for rendering. No script. Scaling the root node scales collision and visuals together — this is the supported way to resize a platform instance, not editing the shape resource per-instance.

### `scenes/wall.tscn` — level boundary

`Wall` (`StaticBody2D`) with a `CollisionShape2D` (`RectangleShape2D`) and a single `Polygon2D` (`Visual`), same base size as `platform.tscn` but a flat stone color and no grass `Top` strip — unlike ground, a boundary wall is seen edge-on and rotated, so a grass accent wouldn't read correctly. Same scale-to-resize convention as `platform.tscn`.

### `scenes/water.tscn` — water

`Water` (`Area2D`, group `water`), script: `scripts/water.gd`, with a `CollisionShape2D` (`RectangleShape2D`) and two `Polygon2D` children (`Visual` body, `Surface` highlight strip), mirroring `platform.tscn`'s structure but with an `Area2D` root instead of `StaticBody2D` — water doesn't block the player like solid ground. `water.gd` only exposes `get_surface_y()` (the world-space Y of the top of the collision shape, accounting for scale); it doesn't know about the player at all — the player is the one that queries overlapping water and decides how to react (see Movement model below). Scaling the root resizes collision and visuals together, same convention as `platform.tscn`.

### `scenes/player.tscn` — the flying bug

`Player` (`CharacterBody2D`), script: `scripts/player.gd`.

- `CollisionShape2D` (`CircleShape2D`) — direct child of `Player`, sibling of `Visual`, so it is unaffected by visual flipping.
- `WaterSensor` (`Area2D`) with its own `CollisionShape2D` (same `CircleShape2D` as the body) — direct child of `Player`, used to detect overlapping `water` and `seedling` group areas each physics frame via `get_overlapping_areas()`. Kept as a plain sensor (no signals) since the player only needs a per-frame snapshot, not enter/exit events.
- `Visual` (`Node2D`) — groups everything that should mirror when the bug turns to face left/right (see `player.gd`'s facing logic). Contains the body/head/eye `Polygon2D`s and:
  - `Proboscis` (`Polygon2D`) — hidden by default, shown by `player.gd` while the bug is resting on water and drinking, or watering a seedling. Since it's inside `Visual`, it mirrors with facing automatically, so the tip stays on the correct side of the bug.
    - `WaterDrip` (`CPUParticles2D`) — positioned at the proboscis tip, `emitting` toggled by `player.gd` while watering a seedling. CPU (not GPU) particles to match the project's GL Compatibility renderer.
  - `PollenBlob` (`Polygon2D`) — the bee-butt pollen cue (REQUIREMENTS.md Step 2), positioned on the rear of `Body`, opposite `Proboscis` so both read correctly regardless of facing since both live inside `Visual`. Hidden by default; `player.gd` toggles `visible` and sets `color` from `PlantData.pollen_color()` whenever carried pollen changes.
    - `PollenPuff` (`CPUParticles2D`, one-shot) — played by `player.gd` on a fizzle or a `shed_pollen` drop.
  - `PollenCollectSound`, `PollinateSound`, `PollenPuffSound` (`AudioStreamPlayer2D`) — one-shot SFX for pollen pickup, successful pollination, and fizzle/shed respectively, each with a small `pitch_scale` randomization per play (matches the fit-and-finish "vary pitch on repeated sounds" guidance). Streams are procedurally generated tones (see `CREDITS.md`), not sourced audio.
  - `Wings` (`Node2D`), script: `scripts/wings.gd` — owns wing-flap animation, isolated from movement logic so flap speed/state can be driven by the player script (`wings.flapping`) without either script knowing the other's internals.
- `Camera2D` — direct child of `Player`, sibling of `Visual`, so it never flips/rotates with the visual.

### `scenes/enemy.tscn` — bug swarm hazard

`Enemy` (`Area2D`, group `enemy`), script: `scripts/enemy.gd`, with a `CollisionShape2D` (`CircleShape2D`) and a `Visual` (`Node2D`) containing several tiny dark `Polygon2D` specks clustered off-center to read as a cloud of gnats, plus a `StealSound` (`AudioStreamPlayer2D`) playing `assets/audio/water_steal.ogg` (Kenney "Interface Sounds", CC0, no attribution required).

- Movement: unlike the player, the enemy isn't a `CharacterBody2D` — it just drifts. Each tick it eases (`move_toward`) toward `_target`, a random point within `wander_radius` of its spawn position (`_home`), picked in `_pick_new_target()` on a random timer (`retarget_min`-`retarget_max`) or on arrival. This is a leash around the spawn point, not free-roaming, so enemies placed near different platforms in `main.tscn` stay spread across the level instead of drifting into one cluster.
- `Visual` continuously spins (`spin_speed`) independent of movement, giving the speck cluster a chaotic buzzing look without needing per-speck animation logic.
- Touch detection: `Enemy` is `monitoring = true` / `monitorable = false` and connects its own `body_entered` signal — the player (`CharacterBody2D`) is a physics body Area2D can detect directly, so unlike the water/player-sensor pair (Area2D-vs-Area2D, needs polling) this is a one-shot signal.
- Stealing: on `body_entered`, if the body exposes `steal_water()` (i.e. the player), the enemy calls it directly with `steal_amount` and plays `StealSound`. `player.gd` owns clamping `water_level` and emitting `water_level_changed` itself (mirrors how `water_level` filling works in reverse) — the enemy doesn't reach into the player's state.

### `scenes/seedling.tscn` — growing plant

`Seedling` (`Node2D`), script: `scripts/seedling.gd` (`@tool`, so growth/bloom edits preview live in the editor). Three children:

- `HoverZone` — `Area2D` (group `seedling`, `monitorable = true`, `monitoring = false` — it only needs to be detected, not detect anything itself) with a `CollisionShape2D` (`CircleShape2D`), positioned over the plant. This is what the player's `WaterSensor` polls to know it's hovering over this seedling (see Movement model below); `seedling.gd` itself never touches this node, it just sits in the tree as a detectable proxy for "over this plant."
- `Sprout` — the small stem/leaves/bud (`Polygon2D`s) always present, scaled down at low growth.
- `Bloom` — one `Node2D` per `PlantData.PlantType` variant (`Daisy`, `Tulip`, `Berry`, `Apple`, `Sunflower`), each a distinct colorful flower/fruit shape built from a few `Polygon2D`s. Only the node matching the exported `bloom_type` is visible. Its last child, `PollenCue`, is three small diamond `Polygon2D` dots at the flower center, each paired with a slightly larger white `Polygon2D` sibling drawn just before it (`DotNBorder`) so the grain reads with a white outline against any bloom color; `seedling.gd` sets the `Dot1`-`Dot3` `color` directly to the plant's pollen color from `PlantData` (the borders stay plain white, which is why the color is set per-dot in script rather than via `PollenCue.modulate` — modulate would tint the borders too). Visible only in the `BLOOMED` state to signal collectible pollen.

The plant is an explicit lifecycle state machine (`State` enum): `GROWING → BLOOMED → POLLINATED → SEED_GROWING → (seed pops) → BLOOMED`. `state` is a plain (non-exported) var derived at `_ready` from `growth`; `SEED_GROWING` exists in the enum but is not yet reachable (seed production is a later REQUIREMENTS.md step). Every visual is a function of `(state, progress, bloom_type)` in `_update_visuals()` — no visual state lives anywhere else.

`POLLINATED` (REQUIREMENTS.md Step 2) is reached via `pollinate(incoming: PlantData.PlantType) -> PollinateResult`, called by `player.gd` when the bee hovers a `BLOOMED` flower while carrying different-colored pollen. It resolves `PlantData.combo_result()` and either stores the hybrid on `hybrid_result` and advances state (`SUCCESS`), or leaves state untouched (`FIZZLE`) — the fizzle puff itself plays on the *player*, since it's the carried pollen that's consumed, not the flower. `collect_pollen()` is the mirror read for pickup: valid only while `BLOOMED`, returns `bloom_type` without mutating the plant (pollen isn't depleted by collecting it; only pollination advances state). `_update_visuals()`'s `POLLINATED` branch shows a `Sparkle` (`CPUParticles2D`) and a sine-driven `bloom.modulate` shimmer; the shimmer is driven by `_process()`, which the `state` setter enables/disables via `set_process()` — gated off whenever `Engine.is_editor_hint()` is true, so the `@tool` preview stays static like `growth`/`bloom_type` already are, instead of animating inside the editor.

`growth` (`@export_range(0, 100)`) is the `GROWING` state's progress. It drives the whole plant's `scale` (`lerp(0.12, 1.0, growth / 100)` — barely visible near 0, full size at 100) and, once `growth` passes `BLOOM_START` (70), fades `Bloom` in and scales it from 0 to full over the remaining range while hiding `Sprout/Bud` (the bloom replaces the bud, it doesn't sit alongside it). Reaching 100 flips `state` to `BLOOMED` (the setter keeps this in sync both directions so the editor preview works). `bloom_type` (`@export`, typed `PlantData.PlantType`) picks which flower/fruit variant shows — instances in `main.tscn` each set both to different values so the level shows a range of growth stages and a different bloom per seedling. `water(delta)` raises `growth` at a fixed rate (`100 / grow_time`, default 5s for 0%→100%) — called by `player.gd` each physics tick the bug hovers over `HoverZone` (see Movement model below).

### `scripts/plant_data.gd` — plant data table

`PlantData` (`class_name`, not attached to any node) is the single source of truth for plant data: the `PlantType` enum, `POLLEN_COLORS` (typed const table mapping each base type to its pollen color, read via `PlantData.pollen_color(type)`), and `COMBO_TABLE` (the 8 successful hybrid combos, read via `PlantData.combo_result(a, b)`). Gameplay and UI must both read plant facts from here — display names land in this file when Step 5's combo chart needs them; nothing else may hardcode this data.

`PlantType` holds `NONE = -1` (the fizzle/no-result sentinel), the five base plants at their original values `0`-`4`, and the 8 hybrid types appended after them — all with explicit values, so `bloom_type` ints already saved in `main.tscn` keep mapping to the same base plants regardless of how the enum grows. Hybrid *visuals* aren't built until Step 4; for now `PlantType` values beyond the base five are pure data, produced by pollination and not yet rendered anywhere.

`combo_result(a, b)` looks up an unordered base pair (via `_pair_key`, `mini(a,b)*100 + maxi(a,b)`) in `COMBO_TABLE` and returns `PlantType.NONE` if the pair isn't listed. Only the 8 successful combos are in the table — the 2 documented fizzle pairs are exactly the base pairs left over, so there's no separate fizzle table to keep in sync. Same-type pollination (`a == b`) is the caller's responsibility to filter out before calling `combo_result`, since it's a no-op rather than a fizzle.

### `scenes/hud.tscn` — water meter

`HUD` (`CanvasLayer`), script: `scripts/hud.gd`, with a `Control` anchored top-left containing a `ProgressBar` (`WaterMeter`, range 0-1). `hud.gd` finds the player via the `player` group in `_ready()` and connects to its `water_level_changed` signal — the HUD reaches out to the player rather than the player knowing about the HUD, so `player.gd` stays UI-agnostic.

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

## Known gaps / not yet built

- The pollination game (REQUIREMENTS.md) is at Step 2 of 8: pollen pickup and pollination are playable (`BLOOMED → POLLINATED`, with a `shed_pollen` action to drop carried pollen), but `SEED_GROWING` is still unreachable — no seed production, seed carrying, plots, combo chart, goal panel, or win condition yet. Hybrid `PlantType`s exist as data (`plant_data.gd`) and are producible via pollination, but have no bloom visuals until Step 4.
- No level-transition, scoring, or win/lose — drinking and watering seedlings both move `water_level` but nothing else consumes it.
- No save/settings system.
- Input actions are defined by hand in `project.godot`; there is no in-game rebinding UI.

Update this section as these are built, rather than leaving it to go stale.
