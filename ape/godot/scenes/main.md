# `main.tscn` — the level

`Main` (`Node2D`), the game's entry point (`run/main_scene` in `project.godot`), script: `scripts/main.gd`. Currently a single static level:

- `Ground`, `Platform1`-`Platform10` — instances of `platform.tscn`, positioned/scaled per-instance to build the level layout. No platform-specific script; layout is entirely position + scale data on the instance.
- `Music` — `AudioStreamPlayer` playing `assets/audio/happy_bee.mp3` ("Happy Bee" by Kevin MacLeod, incompetech.com, CC BY 3.0 — attribution required if the game is published), looped, low volume (`volume_db = -20`), `autoplay = true`.
- `Player` — instance of `player.tscn`.
- `WaterPond`, `WaterPuddle` — instances of `water.tscn`, one at ground level and one on a ledge (`Platform2`), showing water can sit at the bottom or up on a platform. Every level is expected to have some water.
- `Enemy1`-`Enemy5` — instances of `enemy.tscn`, positioned near different platform clusters so the wander leash (see `enemy.md`) keeps them spread across the level rather than bunched together.
- `Seedling1`-`Seedling10` — instances of `seedling.tscn`, one or two per platform top, positioned to sit on each platform's top surface, each with a different `growth` value and `bloom_type` so the level shows the full range from barely-sprouted to fully bloomed.
- `Plot1`-`Plot9` (REQUIREMENTS.md Step 4) — instances of `plot.tscn`, spread across `Ground` and most platforms near (but not on top of) the existing seedlings, more than the 4-plant goal (Step 6) will ever require so the player can't dead-end without an empty plot to plant into.
- `BoundsTop`, `BoundsBottom`, `BoundsLeft`, `BoundsRight` — instances of `wall.tscn`, forming a box around the whole level so the player can't fly off-screen. Left/right instances are rotated 90° and scaled along the (now vertical) local x-axis to span the box's height.
- `HUD` — instance of `hud.tscn`, the on-screen water meter, combo chart, and goal panel.
- `IntroScreen` — instance of `intro_screen.tscn`, the pre-level how-to-play overlay (see `intro_screen.md`).

There is no level-loading or scene-management system yet — `main.tscn` *is* the level. If a second level is added, this needs a level-container/loader layer before it grows further (see Coding conventions in CODING.md — don't build that abstraction until it's needed).

`Main` carries `groups=["main"]` in the `.tscn` itself (not `add_to_group()` in the script) so the group membership exists the instant the node is created — `GoalPanel` (a child of `HUD`, itself a child of `Main`) looks `Main` up via this group in its own `_ready()`, which runs *before* `Main`'s own `_ready()` (children ready bottom-up), so the membership has to be there ahead of any script running.

`main.gd` owns three responsibilities: the intro gate, spawning, and (Step 6) goal tracking/the win overlay. `_ready()` pauses the tree (`get_tree().paused = true`) so nothing moves until the player has read the instructions, and connects to `IntroScreen`'s `start_requested` signal to unpause once it fires. It also connects to `seed_popped`, `seed_planted`, and `bloomed` on every direct child that has them (each `Seedling`/`Plot`, found by checking `has_signal(...)` rather than hand-wiring each instance's signal in the `.tscn`, so instances added later are covered automatically). The seed-popped handler (REQUIREMENTS.md Step 3) instantiates `seed.tscn`, sets its `plant_type` to the popped hybrid, positions it a small fixed offset beside the plant, and adds it as a child of `Main`. The seed-planted handler (REQUIREMENTS.md Step 4) instantiates `seedling.tscn` at the plot's position with `growth = 0` and `bloom_type` set to the planted hybrid.

### Goal tracking and win condition (Step 6)

`_ready()` calls `_select_goals()` before wiring seedlings: `randomize()` (rolled once per level load — REQUIREMENTS.md's "seeded at level start" — so `reload_current_scene()` on "Play again" gets a fresh set), then 1 random entry from `PlantData.BASE_TYPES` plus 3 random entries from a shuffled `PlantData.HYBRID_TYPES` become `goal_types`, backing a `goal_progress: Dictionary[PlantType, bool]` seeded `false`. `goal_selected(goal_types)` fires once so `GoalPanel` can build its rows.

Each `Seedling`'s new `bloomed(bloom_type)` signal (emitted on entering `BLOOMED`) drives `_on_seedling_bloomed()`: if that type is a goal and not already checked, it flips to `true` and fires `goal_checked(goal_type)`, then calls `player.celebrate_goal()` (a big multi-colored confetti burst plus a chime, see `scenes/player.md`) so the feedback reads as coming from the bee — progress only ever moves forward, matching REQUIREMENTS.md's "prefer the simpler rule" (no un-checking).

Connecting a `Seedling`'s `seed_popped`/`bloomed` signals is factored into `_wire_seedling(child)`, called from two places: `_ready()`'s loop over the level's starting children, *and* `_on_plot_seed_planted()` right after `add_child(seedling)` for a freshly planted hybrid. Both call sites matter — a seedling planted mid-run is created well after `_ready()`'s loop has already finished, so without also wiring it at spawn time its eventual `bloomed` signal would go nowhere and its goal would silently never check off. `_wire_seedling()` also calls `Seedling.is_bloomed()` right after connecting and feeds `_on_seedling_bloomed()` directly if true, since children placed already-bloomed in the editor fire `bloomed` (if at all, gated on `not Engine.is_editor_hint()`) before `_ready()`'s connection exists — child `_ready()` runs before `Main`'s.

Once every entry in `goal_progress` is `true`, `Main` emits `won`, pauses the tree, and instantiates `win_overlay.tscn` as a child of itself (see `win_overlay.md`) — not pre-placed in the `.tscn` like `IntroScreen`, since it's a terminal, one-shot UI element rather than something every run needs from the start.
