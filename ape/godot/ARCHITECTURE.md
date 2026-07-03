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
- `WaterSensor` (`Area2D`) with its own `CollisionShape2D` (same `CircleShape2D` as the body) — direct child of `Player`, used to detect overlapping `water` group areas each physics frame via `get_overlapping_areas()`. Kept as a plain sensor (no signals) since the player only needs a per-frame snapshot, not enter/exit events.
- `Visual` (`Node2D`) — groups everything that should mirror when the bug turns to face left/right (see `player.gd`'s facing logic). Contains the body/head/eye `Polygon2D`s and:
  - `Proboscis` (`Polygon2D`) — hidden by default, shown by `player.gd` while the bug is resting on water and drinking.
  - `Wings` (`Node2D`), script: `scripts/wings.gd` — owns wing-flap animation, isolated from movement logic so flap speed/state can be driven by the player script (`wings.flapping`) without either script knowing the other's internals.
- `Camera2D` — direct child of `Player`, sibling of `Visual`, so it never flips/rotates with the visual.

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

## Known gaps / not yet built

- No level-transition, scoring, win/lose, or win condition tied to a full water meter — drinking fills `water_level` but nothing consumes it yet.
- No enemies or hazards.
- No save/settings system.
- Input actions are defined by hand in `project.godot`; there is no in-game rebinding UI.

Update this section as these are built, rather than leaving it to go stale.
