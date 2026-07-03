# Requirements: Pollination Update

Turns the current sandbox (fly, drink, water seedlings) into a real game with a goal:
**cross-pollinate flowers to breed hybrid plants, and grow the target set of plants shown on screen to win.**

This document is the source of truth for *what* to build. Build it in the numbered steps below, in order — each step ends in a playable, testable game. After each step, ask the user to playtest (per CLAUDE.md, don't drive the game yourself) and update ARCHITECTURE.md before moving on.

## Core loop

1. Water a seedling until it reaches 100% growth and blooms.
2. Hover over a bloomed flower to collect its pollen — the pollen sits visibly on the bee's abdomen ("butt"), colored by the flower it came from.
3. Carry that pollen to a *different* bloomed flower and hover over it to pollinate it. The pair (pollen type + flower type) determines what hybrid seed the plant will produce, per the combo chart.
4. A pollinated plant needs a **second full watering** to produce a seed. When done, a seed pops out and drops beside the plant.
5. Fly into the seed to pick it up, carry it to an empty **plot** (dirt spots placed around the map), and hover to plant it. It becomes a new seedling of the hybrid type — water it to grow it to bloom.
6. The **combo chart** on the right edge of the screen always shows which pollen + flower pairs produce which plants.
7. The **goal panel** shows the set of plants to grow this round. When every goal plant exists somewhere in the level at full bloom, the player wins.

Enemies (gnat swarms) remain the pressure: they steal water on touch, and (Step 7) knock carried pollen off the bee.

## Plant types and combos

### Base plants (already exist as `BloomType`)

Each base plant has a distinct pollen color. Colors must be distinguishable from each other at bee-butt size:

| Plant | Pollen color |
|---|---|
| Daisy | White |
| Tulip | Pink |
| Berry | Purple |
| Apple | Red |
| Sunflower | Orange |

### Hybrid combos (8)

Combos are **unordered** — pollen A on flower B gives the same result as pollen B on flower A. Hybrids are new bloom variants, built in the same Polygon2D style as the existing five.

| Combo | Result |
|---|---|
| Daisy + Tulip | Rose |
| Daisy + Berry | Lavender |
| Daisy + Sunflower | Starbloom |
| Tulip + Berry | Orchid |
| Tulip + Sunflower | Firelily |
| Berry + Apple | Plum |
| Apple + Sunflower | Pumpkin |
| Apple + Tulip | Cherry |

The two remaining base pairs (Daisy + Apple, Berry + Sunflower) **fizzle**: the pollen is consumed in a puff of dust and nothing happens. Fizzles are *not* shown on the chart — discovering them the hard way is part of the fun.

### Explicit design decisions (don't re-ask these)

- One pollen slot: the bee carries at most one pollen at a time. Collecting from another bloom **replaces** the carried pollen (no drop key needed).
- One seed slot, independent of the pollen slot — the bee can carry a seed and pollen simultaneously.
- Same-type pollination (Daisy pollen on a Daisy) is a no-op: nothing happens, pollen is kept.
- Hybrids do not offer pollen and cannot be pollinated — they are end products. Only the five base plants participate in combos.
- A plant that produced a seed reverts to the bloomed state and can be pollinated again — seeds are renewable.
- Seeds can only be deposited on empty plots (no dropping mid-air). Provide at least 2 more plots than the goal requires so the player can't dead-end.

## Incremental build steps

### Step 1 — Plant lifecycle state machine [COMPLETE]

Refactor `seedling.gd` from a bare `growth` value to an explicit lifecycle:

`GROWING → BLOOMED → POLLINATED → SEED_GROWING → (seed pops) → BLOOMED`

- All visuals derive from `state` + a per-state progress value. Existing growth/bloom visuals map onto `GROWING`.
- A `BLOOMED` base plant shows a visible pollen cue (small colored dots/glow at the flower center in its pollen color) so the player can see it's collectible.
- Keep the `@tool` live-preview working for `growth` and `bloom_type` in the editor.
- No new gameplay yet — the game must play exactly as before. This step is pure groundwork and must not regress anything.

**Testable:** game plays as today; bloomed base flowers now show pollen dots.

### Step 2 — Pollen pickup and pollination [COMPLETE]

- Hovering over a `BLOOMED` base flower with an **empty** pollen slot collects its pollen. A clearly visible colored blob appears on the rear of the bee's `Visual` (it mirrors with facing, like the proboscis).
- Hovering over a *different*-colored `BLOOMED` base flower while carrying pollen pollinates it: state → `POLLINATED`, resulting hybrid type computed from the combo table and stored on the plant, pollen slot cleared. Hovering a *same*-colored flower while carrying pollen is a no-op.
- A **`shed_pollen`** action (bound to `Q`) drops carried pollen outright with a puff, independent of any hover target — since pollen is only ever collected from an empty slot, this is how the player discards an unwanted color to go collect a different one.
- `POLLINATED` visual: the flower visibly changes — gentle sparkle particles (CPU) and a slight color shimmer — so the player knows it's waiting for water.
- Fizzle pairs: dust-puff particle, pollen consumed, state stays `BLOOMED`.
- Same-type: nothing happens.

**Testable:** collect pollen, see it on the bee, pollinate a second flower, see it change; `Q` sheds carried pollen.

### Step 3 — Seed production [COMPLETE]

- A `POLLINATED` plant accepts watering again (same hover-and-drain mechanic as growing): a second full watering moves it through `SEED_GROWING` — visually, a seed pod swells at the flower center.
- When complete, a **seed** (new scene) pops out with a small arc/bounce and comes to rest on the ground/platform beside the plant. The seed's look encodes its hybrid type (color/tiny icon).
- The parent plant reverts to `BLOOMED`.

**Testable:** water a pollinated flower, watch a seed pop out.

### Step 4 — Seed carrying and plots [COMPLETE]

- **Plot** (new scene): a small dirt mound, visually obvious as "plantable here". Place 8–10 around `main.tscn` on ground and platforms.
- Flying into a loose seed picks it up (if the seed slot is free); it hangs visibly beneath the bee.
- Hovering over an empty plot while carrying a seed plants it: the seed disappears, and a new seedling of the hybrid type appears in the plot at growth 0. It grows via watering like any seedling and blooms into the hybrid flower.
- Hybrid bloom visuals: 8 new bloom variants in the seedling scene, same Polygon2D style and structure as the existing five.

**Testable:** the full loop — bloom, pollinate, water, seed, carry, plant, grow the hybrid.

### Step 5 — Combo chart panel [COMPLETE]

- A panel anchored to the **right edge** of the screen, always visible, listing the 8 combos: `[mini plant icon] + [mini plant icon] = [mini plant icon]` per row.
- Icons must match the in-world plants (same shapes/colors, scaled down) so the player can map chart → world at a glance.
- Semi-transparent background; must not obscure gameplay; must stay anchored correctly if the window is resized.
- Key "1" can show and hide the panel.

**Testable:** chart readable at a glance; matches actual combo outcomes exactly.

### Step 6 — Goal panel and win condition [COMPLETE]

- A **goal panel** (top-right, above the Combo chart panel) shows this round's target plants as mini icons: 4 plants — 3 hybrids + 1 base type, chosen at random per run (seeded at level start).
- A goal entry checks off (visibly: color fills in, checkmark, small flourish) when a plant of that type reaches full bloom anywhere in the level. It un-checks if that condition stops holding only if trivial to track — otherwise once checked, it stays checked (prefer the simpler rule).
- When all goals are checked: **win overlay** — congratulatory message, celebration (particles, sound sting), and a "Play again" button that reloads the level with a fresh random goal set.

**Testable:** grow the target set, see the win screen, restart works.

### Step 7 — Enemy interference

- Gnat swarms now also knock the carried **pollen** off the bee on touch (in addition to stealing water). The pollen is lost — puff particle + the existing steal sound. Carried seeds are safe (losing a seed would be too punishing).
- Add 1–2 enemies patrolling near plot clusters so late-game carrying has tension.
- Tune so this is pressure, not misery: brief invulnerability (~1.5 s) after being hit so a single swarm can't drain everything in one overlap.

**Testable:** flying through a swarm while carrying pollen loses it; the game feels tenser but fair.

### Step 8 — Fit-and-finish pass

A dedicated polish step; see the checklist below. Nothing new mechanically — this step makes everything already built feel good.

## Architectural direction

Follow CODING.md throughout (static typing, signals over tree-reaching, compose scenes, no dead code). Specifics for this feature:

- **Single source of truth for plant data.** Create `scripts/plant_data.gd` — a script with typed enums/const tables defining: all plant types (base + hybrid), pollen colors, the combo table, and display names. Gameplay *and* UI (combo chart, goal panel, seed icons) all read from this one table. The combo chart must be *generated* from the data, never hand-maintained in the UI scene.
- **Lifecycle as an enum state machine** in `seedling.gd`, not scattered booleans. Every visual is a function of `(state, progress, plant_type)`.
- **Player stays the actor; polling stays the pattern.** Pollen pickup, pollination, seed pickup, and planting all use the existing `WaterSensor.get_overlapping_areas()` poll, filtered by group (`seedling`, `seed`, `plot`) — consistent with how watering and water-landing already work. Plants/seeds/plots stay passive detectables.
- **Player state exposed via signals.** `player.gd` gains `pollen_changed(type)` and `seed_changed(type)` signals mirroring `water_level_changed`; the HUD subscribes, the player never knows about UI.
- **New scenes:** `seed.tscn` (Area2D, group `seed`) and `plot.tscn` (Area2D, group `plot`), each with its own script scoped to its own node.
- **Win logic lives on `Main`.** Add `main.gd` to the Main node owning goal selection, goal tracking, and the win overlay. Do **not** introduce autoloads/singletons — there is one level, and per the project's convention, that abstraction waits until a second level exists.
- **HUD growth:** combo chart and goal panel are new Control branches inside `hud.tscn`'s CanvasLayer, each with its own script.
- **CPU particles only** (`CPUParticles2D`) — the project is pinned to the GL Compatibility renderer.
- **Update ARCHITECTURE.md at the end of every step** (CLAUDE.md requires it), including the "Known gaps" section.

## Fit and finish

Apply continuously; Step 8 is the sweep for anything missed.

**Feedback for every action.** Every player-triggered state change needs at minimum a sound *and* a visual response: pollen pickup, pollination, fizzle, seed pop, seed pickup, planting, goal check-off, win. Silence + snap = bug.

**Nothing snaps.** State changes animate: scale-pop tweens on pickups and check-offs, fade/scale-in for blooms, an arc with a bounce for the seed pop. Keep tweens short (0.15–0.4 s) so the game stays snappy.

**Audio.** Source CC0 (preferably Kenney, matching `water_steal.ogg`) or CC-BY sounds; record every source in CREDITS.md. Balance against the music (which sits at −20 dB): effects should read clearly without startling. Vary pitch slightly (`pitch_scale` ±10%) on repeated sounds.

**Readability.**
- Pollen colors must be tellable apart at gameplay size and against all level backgrounds. Pair color with position/shape where possible (the chart swatches use the same rendering as the bee-butt blob).
- The player must always be able to answer at a glance: What pollen am I carrying? What seed am I carrying? Which flowers are bloomed/pollinated? What do I still need to grow?

**UI discipline.** All panels anchored with Godot anchors (no hardcoded pixel positions that break on resize), consistent font and panel styling across water meter, chart, and goal panel, semi-transparent backgrounds, nothing overlapping the play space more than necessary.

**Game feel.** The bee's handling is the core pleasure — do not degrade it. Carrying a seed may add a *slight* heaviness (~10% max-speed reduction) if it feels good in testing; cut it if it frustrates.

**Balance starting points** (tune in playtesting, expose as `@export`s): first growth 0→bloom ≈ 5 s of watering (current), pollinated→seed ≈ 4 s, water meter mechanics unchanged. A full win run should take roughly 5–10 minutes.

**Verification.** Every step ends with: game launches clean (no script errors in the console), previous mechanics still work, and a short "what to try" note for the user to playtest.
