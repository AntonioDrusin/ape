# Architecture

Godot 4.7 project, GL Compatibility renderer. Engine version and renderer are pinned in `project.godot` — do not upgrade without checking these settings still make sense.

## Directory layout

- `scenes/` — one `.tscn` per composable game object (player, platform, level). No loose top-level scenes outside this folder.
- `scripts/` — one `.gd` per node that needs behavior, named after the node/scene it's attached to (`player.gd` on `Player`, not on some unrelated node).

## Scene tree

### `scenes/main.tscn` — the level

`Main` (`Node2D`), the game's entry point (`run/main_scene` in `project.godot`). Currently a single static level:

- `Ground`, `Platform1`, `Platform2`, `Platform3` — instances of `platform.tscn`, positioned/scaled per-instance to build the level layout. No platform-specific script; layout is entirely position + scale data on the instance.
- `Player` — instance of `player.tscn`.

There is no level-loading or scene-management system yet — `main.tscn` *is* the level. If a second level is added, this needs a level-container/loader layer before it grows further (see Coding conventions in CODING.md — don't build that abstraction until it's needed).

### `scenes/platform.tscn` — static level geometry

`Platform` (`StaticBody2D`) with a `CollisionShape2D` (`RectangleShape2D`) and two `Polygon2D` children (`Visual` body, `Top` accent strip) for rendering. No script. Scaling the root node scales collision and visuals together — this is the supported way to resize a platform instance, not editing the shape resource per-instance.

### `scenes/player.tscn` — the flying bug

`Player` (`CharacterBody2D`), script: `scripts/player.gd`.

- `CollisionShape2D` (`CircleShape2D`) — direct child of `Player`, sibling of `Visual`, so it is unaffected by visual flipping.
- `Visual` (`Node2D`) — groups everything that should mirror when the bug turns to face left/right (see `player.gd`'s facing logic). Contains the body/head/eye `Polygon2D`s and:
  - `Wings` (`Node2D`), script: `scripts/wings.gd` — owns wing-flap animation, isolated from movement logic so flap speed/state can be driven by the player script (`wings.flapping`) without either script knowing the other's internals.
- `Camera2D` — direct child of `Player`, sibling of `Visual`, so it never flips/rotates with the visual.

## Movement model

`player.gd` implements thrust-based flight, not platformer walk/jump:

- Input (`move_left/right/up/down`, mapped to WASD + arrows + Space in `project.godot`) applies acceleration (`thrust`) in the corresponding direction every physics tick.
- Constant `gravity` pulls down; `air_drag` decelerates velocity each frame (proportional drag, not a fixed friction constant), producing a floaty, bug-like feel rather than instant stop/start.
- `velocity.limit_length(max_speed)` caps top speed in any direction.
- Facing: when `abs(velocity.x)` exceeds a small deadzone, `Visual.scale.x` is eased toward `sign(velocity.x)` via `move_toward`, so the bug smoothly turns to face its direction of horizontal travel instead of flying backwards. Collision and camera are outside `Visual` specifically so this flip never affects them.
- `wings.flapping` is set from input/airborne state each tick; `wings.gd` owns the actual flap animation (sine oscillation, two speeds for idle vs. active).

## Known gaps / not yet built

- No level-transition, scoring, win/lose, or UI/HUD layer.
- No enemies or hazards.
- No save/settings system.
- Input actions are defined by hand in `project.godot`; there is no in-game rebinding UI.

Update this section as these are built, rather than leaving it to go stale.
