# `main.tscn` — the level

`Main` (`Node2D`), the game's entry point (`run/main_scene` in `project.godot`), script: `scripts/main.gd`. Currently a single static level:

- `Ground`, `Platform1`, `Platform2`, `Platform3` — instances of `platform.tscn`, positioned/scaled per-instance to build the level layout. No platform-specific script; layout is entirely position + scale data on the instance.
- `Music` — `AudioStreamPlayer` playing `assets/audio/happy_bee.mp3` ("Happy Bee" by Kevin MacLeod, incompetech.com, CC BY 3.0 — attribution required if the game is published), looped, low volume (`volume_db = -20`), `autoplay = true`.
- `Player` — instance of `player.tscn`.
- `WaterPond`, `WaterPuddle` — instances of `water.tscn`, one at ground level and one on a ledge (`Platform2`), showing water can sit at the bottom or up on a platform. Every level is expected to have some water.
- `Enemy1`-`Enemy5` — instances of `enemy.tscn`, positioned near different platform clusters so the wander leash (see `enemy.md`) keeps them spread across the level rather than bunched together.
- `Seedling1`-`Seedling10` — instances of `seedling.tscn`, one or two per platform top, positioned to sit on each platform's top surface, each with a different `growth` value and `bloom_type` so the level shows the full range from barely-sprouted to fully bloomed.
- `BoundsTop`, `BoundsBottom`, `BoundsLeft`, `BoundsRight` — instances of `wall.tscn`, forming a box around the whole level so the player can't fly off-screen. Left/right instances are rotated 90° and scaled along the (now vertical) local x-axis to span the box's height.
- `HUD` — instance of `hud.tscn`, the on-screen water meter.

There is no level-loading or scene-management system yet — `main.tscn` *is* the level. If a second level is added, this needs a level-container/loader layer before it grows further (see Coding conventions in CODING.md — don't build that abstraction until it's needed).

`main.gd` (REQUIREMENTS.md Step 3) currently owns one responsibility: spawning. `_ready()` connects to `seed_popped` on every direct child that has it (each `Seedling`, found by checking `has_signal("seed_popped")` rather than hand-wiring each instance's signal in the `.tscn`, so seedlings added later are covered automatically). The handler instantiates `seed.tscn`, sets its `plant_type` to the popped hybrid, positions it a small fixed offset beside the plant, and adds it as a child of `Main`. Step 6 will extend this same script with goal tracking and the win overlay.
