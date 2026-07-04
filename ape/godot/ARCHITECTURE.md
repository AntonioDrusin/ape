# Architecture

Godot 4.7 project, GL Compatibility renderer. Engine version and renderer are pinned in `project.godot` — do not upgrade without checking these settings still make sense.

## Directory layout

- `scenes/` — one `.tscn` per composable game object (player, platform, level). No loose top-level scenes outside this folder.
- `scripts/` — one `.gd` per node that needs behavior, named after the node/scene it's attached to (`player.gd` on `Player`, not on some unrelated node).
- `assets/` — non-script, non-scene resources, grouped by type (`assets/audio/`, `assets/shaders/`).
- `data/` — `.tres` tuning resources (e.g. `player_tuning.tres`), instances of a `Resource` subclass in `scripts/` (e.g. `gameplay_tuning.gd`). Balance knobs that aren't tied to a single node instance live here rather than as `@export` vars on the script, so they're editable as data without a code change.

## Where information lives

Docs hold only what the code can't express:

- **Rationale anchored to code** (why a node is structured this way, why an ordering matters, why an approach was chosen) lives as a comment in the script, at the line a future edit would break.
- **Cross-scene contracts and conventions** live here, once, as the named patterns below.
- **Everything else** — node lists, signal signatures, tuning values — lives only in the `.tscn`/`.gd` files. Don't restate it in docs; open the code.

When a scene's role changes or a pattern is added/broken, update the catalog entry or pattern here in the same change.

## Patterns

Every scene and script follows these; deviate deliberately and say why in a comment.

1. **Signals up, calls down; `Main` owns spawning.** Gameplay children announce events with past-tense signals (`seed_popped`, `seed_planted`, `bloomed`); `Main` connects to them (duck-typed via `has_signal`, so instances added later are covered automatically) and is the only place that instantiates scenes into the level at runtime. No scene ever touches the tree above itself.
2. **Passive detectables, one sensor poll.** Everything the bug interacts with in the world (`water`, a seedling's `HoverZone`, `seed`, `plot` — group names match the scene) is an `Area2D` that knows nothing about the player. The player's `WaterSensor` polls overlaps once per physics tick and owns all interaction logic; a detectable at most exposes a method or property for the player to call.
3. **UI reaches into gameplay, never the reverse.** HUD elements find `player`/`main` via groups and connect to their signals; gameplay scripts stay UI-agnostic. Each HUD panel is self-contained — its own script, its own toggle input — independent of its siblings.
4. **`PlantData` is the single source of truth for plant facts** (types, colors, combos, display names). Gameplay and UI both read from it; nothing else may hardcode plant data. UI content is *generated* from it (the combo chart builds rows from `PlantData.all_combos()`, icons are extracted from `seedling.tscn` via `PlantIconSource`) rather than hand-authored copies that could drift.
5. **Feedback conventions.** `CPUParticles2D` only — the GL Compatibility renderer has no GPU particles. One-shot SFX get slight `pitch_scale` randomization per play; looping SFX are volume-faded in/out, never hard play/stopped. Visuals are a pure function of state (`_update_visuals()`-style, no visual state stored elsewhere), and transitions animate briefly (~0.15–0.4s — "nothing snaps", per REQUIREMENTS.md).

## Scene catalog

Orientation only — read the `.tscn`/`.gd` for detail.

- `main.tscn` — the entry point, and currently *the* single static level (there is no level-loader; per CODING.md, don't build one until a second level exists). `main.gd` owns the intro pause gate, all runtime spawning (popped seeds, planted seedlings, the win overlay), and goal tracking: 4 random goal plants rolled per run, checked off as they bloom, win overlay when all 4 are done.
- `intro_screen.tscn` — how-to-play overlay shown while `Main` keeps the tree paused; emits `start_requested` on Space and frees itself.
- `platform.tscn` / `wall.tscn` — scriptless `StaticBody2D` geometry. Resize instances by scaling the root (collision and visuals scale together); never edit the shape resource per-instance. Walls are flat-colored with no grass strip since they're seen edge-on and rotated.
- `water.tscn` — passive detectable the player rests on and drinks from; exposes `get_surface_y()` only.
- `player.tscn` — the flying bug: thrust-based flight (not platformer walk/jump), drinking, watering, pollen and seed carrying — all world interaction via the pattern-2 sensor poll. Everything that mirrors when the bug turns is under `Visual`; collision and camera are deliberately outside it.
- `enemy.tscn` — gnat-cloud hazard drifting on a leash around its spawn point; steals water and knocks off carried pollen from the player on touch (seeds are never touched).
- `seedling.tscn` — plant lifecycle state machine: `GROWING → BLOOMED → POLLINATED → SEED_GROWING → (pops a seed) → BLOOMED`, so seeds are renewable. `@tool`, so growth/bloom edits preview live in the editor. One `Bloom/<Name>` visual subtree per plant type, named exactly by `PlantData.display_name()` — a lookup contract relied on by `seedling.gd` and `PlantIconSource`. Bloom polygon colors are hand-authored in the `.tscn` to *match* `PlantData` (a deliberate pattern-4 exception; only pollen cues and seed pods are colored from `PlantData` at runtime).
- `seed.tscn` / `plot.tscn` — the passive detectables of the carry-and-plant loop: a loose seed is consumed by the player's poll; a plot's `plant()` emits `seed_planted` for `Main` to spawn the new seedling.
- `hud.tscn` — `WaterMeter` (player water level), `ComboChart` (toggle "1"), `GoalPanel` (toggle "2"). The two panels are child-node-free custom-`_draw()` Controls whose rows are generated per pattern 4 (combos from `PlantData`, goals from `Main`'s roll).
- `win_overlay.tscn` — spawned by `Main` on win rather than pre-placed (one-shot terminal UI, unlike `IntroScreen`); "Play again" reloads the scene, which re-rolls the goals.
- `scripts/plant_data.gd` (`PlantData`, not attached to a node) — the pattern-4 data table: `PlantType` enum (explicit values — `bloom_type` ints saved in `main.tscn` must keep mapping to the same plants), color tables, `ACCEPTS_POLLEN`, the hybrid combo table.
- `scripts/plant_icon_source.gd` (`PlantIconSource`, not attached to a node) — extracts bloom polygon/color data by instantiating `seedling.tscn` off-tree, so UI icons can never drift from the in-world plant visuals and no live seedling (with its collision/groups) ever backs a decorative icon.

## Known gaps / not yet built

- The pollination game (REQUIREMENTS.md) is at Step 7 of 8: the full core loop is playable end to end and winnable — bloom, pollinate, water to pop a seed, carry it, plant it, bloom the hybrid, complete all 4 goal plants for the win overlay. Enemies now also knock pollen off the bee on touch. Still missing: the fit-and-finish pass (Step 8).
- No level-transition or scoring beyond the single win condition — nothing consumes `water_level` besides watering, and there's no losing state (Step 7's enemies are pressure, not failure).
- No save/settings system.
- Input actions are defined by hand in `project.godot`; there is no in-game rebinding UI.

Update this section as these are built, rather than leaving it to go stale.
