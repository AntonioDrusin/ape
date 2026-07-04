# Requirements: Controlled Water Interactions

Replaces the current automatic watering (hover over a bloomed... no, over a
seedling with water in the tank and it drains proportionally to time) with a
player-aimed mechanic: **Space fires the proboscis.** Close to a water
source it sucks; away from one, carrying water, it launches an actual water
droplet that flies forward and only waters a plant if it physically hits it.

This document is the source of truth for *what* to build. Build it in the
numbered steps below, in order — each step ends in a playable, testable
game. After each step, ask the user to playtest (per CLAUDE.md, don't drive
the game yourself) and update ARCHITECTURE.md before moving on.

## What changes, and why

Today, `move_up` is bound to W, Up-arrow, *and* Space, and every bit of water
transfer is automatic and proximity-based: rest motionless on water and the
tank fills; hover over a seedling with any water in the tank and it drains
into growth every frame. There's no aim, no miss, no discrete "shot" — it's
a soak, not a squirt.

The new version:

1. **Space stops flying you up** (Up-arrow/W already do that — the double
   binding was redundant) and becomes the **proboscis** button instead.
2. **Close to water, deploying the proboscis sucks it up** — same fill-the-
   tank effect as today, but now it only happens while Space is held *and*
   the bug is within a small distance of a water surface, with the
   proboscis visibly shaking side-to-side (~20% of its width) while it
   drinks, so sucking reads as an active, slightly effortful thing rather
   than passive idling.
3. **Away from water, with water in the tank, pressing Space fires a water
   droplet** — a real projectile launched forward (player's facing
   direction) plus a bit of the player's own velocity, that then falls
   under gravity. It is no longer a vertical drip straight down.
4. **A flower only gets watered if a droplet physically hits it.** The
   continuous "hover + drain" growth math is gone; growth now advances in
   fixed increments, one per droplet that collides with the plant. A shot
   that misses just splashes and is wasted — aim matters now.

## Explicit design decisions (don't re-ask these)

- One droplet per Space press (`is_action_just_pressed`), not hold-to-spray.
  Each shot costs a fixed, discrete amount of tank water — makes firing
  a real decision instead of a hose you leave running.
- Sucking is the opposite: continuous while held (`is_action_pressed`) and
  in range, matching how drinking already feels today.
- Whichever behavior applies is purely proximity-driven off the same press:
  near a water surface, Space sucks; not near one, Space fires. There is no
  separate mode-switch input.
- A miss (droplet times out or hits the ground/water without touching a
  seedling) is not refunded. No "auto-aim" or homing — the arc is the whole
  skill.
- Landing/perching on the water surface (the existing rest-height snap in
  `player.gd`) is unrelated to sucking and keeps working exactly as it does
  today; it's just physical resting, not a gate for filling the tank.
- Pollen collection and pollination are unaffected — they stay the existing
  hover-based interaction. Only *watering a seedling* changes.
- `seedling.gd`'s public `water(amount: float)` keeps its existing signature
  and per-call semantics (advance growth/seed-progress by
  `100.0 / grow_time * amount`, i.e. "amount" is seconds-of-watering-
  equivalent). A droplet hit just calls it once with a fixed
  seconds-equivalent constant instead of the player calling it every physics
  frame with `delta` — so this feature needs **zero changes to
  `seedling.gd`**.

## Incremental build steps

### Step 1 — Free Space from `move_up`

- In `project.godot`'s `[input]` section, remove the Space `InputEventKey`
  from the `move_up` action (keep W and Up-arrow).
- Add a new input action, `use_proboscis`, bound to Space only.
- No script changes yet — Space simply does nothing this step.

**Testable:** flying up only works via W/Up-arrow; Space no longer flies,
does nothing else yet.

### Step 2 — Manual sucking (replaces automatic drinking)

- In `player.gd`, remove the automatic `drinking` fill (currently: landed on
  water + no directional input → fill every frame). Replace with: sucking is
  active while `Input.is_action_pressed("use_proboscis")` **and** the bug is
  within a new `tuning.water_suck_distance` of a water surface (reuse the
  existing `water_sensor` overlap against the `"water"` group — same
  distance-to-surface math the landing snap already computes, just without
  requiring the landed/idle state).
- While sucking: fill the tank exactly as today (`water_fill_time`), and
  play the shake — a small sine-driven left-right offset (or scale.x
  wobble) on `proboscis`, amplitude ~20% of its width, decaying/absent when
  not sucking. `proboscis.visible` is true only while sucking (firing gets
  its own visibility in Step 3).
- Landing/resting physics (the rest-height snap) is untouched — it's
  independent of whether the player is holding the button.

**Testable:** hover near water and hold Space to see the proboscis appear
and shake while the tank fills; letting go or drifting away stops it. Space
away from water does nothing yet.

### Step 3 — Fire a real water droplet

- New scene `scenes/water_droplet.tscn` + `scripts/water_droplet.gd`: a
  small `Area2D` (monitoring, not monitorable — mirrors the "active
  exception" described below) carrying its own `velocity: Vector2`. Each
  frame: `velocity.y += tuning.droplet_gravity * delta`,
  `position += velocity * delta`. Despawns (`queue_free`) after a max
  lifetime or once it leaves the playable area — whichever is simpler to
  wire against the existing camera/level bounds.
- In `player.gd`: on `Input.is_action_just_pressed("use_proboscis")` when
  *not* in suck range and `water_level > 0.0`, emit a new signal
  `water_fired(position: Vector2, velocity: Vector2)` from the proboscis
  tip, where `velocity = velocity + Vector2(facing_x * tuning.droplet_forward_speed, 0.0)`
  (player's current velocity plus a forward kick in the facing direction),
  and drain a fixed `tuning.water_per_shot` from `water_level`. Play a brief
  proboscis "fire" pose: it visibly enlarges for the duration of the pulse,
  reusing the existing carry-pop-style tween for the timing. Ideally the
  enlargement flares only the tip/bottom (the emitting end), not the whole
  shape uniformly, since that's what would actually happen to something
  squirting water — but a uniform scale-up is an acceptable first-pass
  approximation; refine to a flare (e.g. scaling a bottom-anchored tip
  sub-node, or a non-uniform scale weighted toward the tip) in Step 5 if the
  uniform version doesn't read well. Also play a launch sound.
- In `main.gd`: connect to the player's `water_fired` signal (Pattern 1 —
  Main owns spawning) and instantiate `water_droplet.tscn` at the given
  position/velocity.

**Testable:** flying away from water with a full-ish tank and pressing Space
launches a visible droplet that arcs forward and down and disappears; no
flower interaction yet (Step 4).

### Step 4 — Droplet-collision watering (replaces hover-drain)

- Remove the old hover-drain block in `player.gd` entirely (the
  `hovered_seedling && water_level > 0.0 → hovered_seedling.water(delta)`
  logic, and the `water_drip` CPU-particle toggle that went with it).
- `water_droplet.gd` monitors its own overlaps each frame (or reacts to
  `area_entered`) for the `"seedling"` group. On hitting one: call
  `hovered.get_parent().water(tuning.water_per_droplet)` once, play a small
  absorb splash (particle + sound) at the seedling, and free itself. On
  hitting the ground/a platform/water without having hit a seedling first:
  play a plainer splash and free itself (a miss).

**Testable:** the full new loop — suck water near the pool, fly to a
seedling, fire, watch growth advance only on an actual hit; deliberately
missing wastes the shot and the tank drains with nothing to show for it.

### Step 5 — Fit-and-finish pass

Nothing new mechanically — tune and polish what Steps 1–4 built:

- Balance `tuning.water_per_shot` / `tuning.water_per_droplet` /
  `tuning.droplet_forward_speed` / `tuning.droplet_gravity` so a full tank
  reliably waters a seedling from empty to bloom in a similar number of
  "shots" as the old drain took in seconds, and the arc is generous enough
  to hit a hovered-over flower without pixel-perfect aim, but still
  requires actually flying to the flower and facing it.
- `tuning.water_suck_distance` tuned so sucking feels reachable while
  hovering just above the surface, not just while perched on it.
- Sounds for: suck loop (can reuse/rework the existing `water_sound` loop),
  fire (one-shot, pitch-varied per REQUIREMENTS-style convention seen
  elsewhere in the code), hit-splash, and miss-splash — every action
  answers back, per GAMEPLAY.md.
- If Step 3's uniform fire-pose scale-up doesn't read well, refine it to a
  bottom-anchored flare (the tip widening, not the whole proboscis).
- Confirm the shake reads clearly at gameplay size/zoom and doesn't fight
  the existing facing-flip tween.

## Architectural direction

Follow CODING.md throughout (static typing, signals over tree-reaching,
compose scenes, no dead code). Specifics for this feature:

- **New input action, not a repurposed one.** `use_proboscis` is its own
  action bound to Space in `project.godot`; don't overload `move_up` with a
  runtime check for "is this Space or a real up-input" — that's exactly the
  kind of implicit conditional Pattern 4 warns against.
- **`Main` still owns spawning (Pattern 1).** The player never
  `instantiate()`s `water_droplet.tscn` itself; it emits `water_fired` and
  `main.gd` does the instancing, exactly like `seed_popped`/`seed_planted`
  already work.
- **New, named deviation from Pattern 2.** Every existing detectable
  (`water`, a seedling's `HoverZone`, `seed`, `plot`) is passive — the
  player's sensor is the only thing that ever polls. A fired water droplet
  breaks that: it's the moving, transient thing, and it has to detect its
  *own* collisions (against seedlings and the ground) because nothing else
  is positioned to poll for it every frame. Add this as a new, explicit
  entry in ARCHITECTURE.md's Patterns list (don't leave it as an
  undocumented exception) — something like: "Fired projectiles are the one
  active exception to passive detectables: a `WaterDroplet` carries its own
  short-lived collision poll because it, not the player, is what's moving
  through the world during its lifetime."
- **Tuning stays data, not code.** All new constants
  (`water_suck_distance`, `water_per_shot`, `water_per_droplet`,
  `droplet_forward_speed`, `droplet_gravity`, shake amplitude/speed) go in
  `GameplayTuning`/`data/player_tuning.tres` under a new
  `@export_group("Proboscis")`, alongside the existing `Water` group — not
  hardcoded in `player.gd` or `water_droplet.gd`.
- **`seedling.gd` is out of scope.** Its `water(amount)` contract already
  supports discrete calls; don't add a droplet-specific API to it.
- **CPUParticles2D only** (Pattern 6) for suck shake feedback, launch
  puff, and both splash variants — the project is pinned to the GL
  Compatibility renderer.
- **Update ARCHITECTURE.md at the end of every step** (CLAUDE.md requires
  it): the new Pattern above, the scene-catalog entry for
  `water_droplet.tscn`, and removing any language in the `player.tscn`/
  `water.tscn` catalog entries that describes the old automatic behavior.

## Fit and finish

Apply continuously; Step 5 is the sweep for anything missed.

- **Nothing snaps.** The shake, the fire pose, and both splashes animate
  briefly (0.15–0.4 s), consistent with the rest of the game.
- **Every action answers back.** Sucking, firing, hitting, and missing each
  get a sound and a visual — silence on any of these reads as broken.
- **Readability.** The player must be able to tell, at a glance, whether
  they're currently in suck range or fire range (the proboscis's state —
  hidden, shaking, or in its fire pose — is enough; no separate UI needed).
- **Game feel.** The core flying feel must not regress — firing a droplet
  is a discrete button press, not a held state that fights movement input,
  since the player still needs both hands (thumbs) on directional input
  while aiming.
