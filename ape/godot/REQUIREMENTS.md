# Requirements: Flower Guard Hazard

Adds a new hazard, `flower_guard.tscn`, that patrols near a cluster of
flowers and punishes *lingering* close to one — specifically to kill the
current exploit where a full-tank bug can just sit right next to a
seedling and hold Space, since the droplet's arc is generous enough that
point-blank spam barely needs aim. The guard doesn't block the flower
outright (there's no gate the player can't influence): it builds aggro the
longer the bug dwells nearby, telegraphs clearly before it commits, and
only actually punishes on a lunge the player had a real window to dodge.
Camping to spam-water becomes a bet against a readable clock instead of a
free action; a quick swoop for pollen/seed pickup stays essentially safe,
since it doesn't linger long enough to build aggro.

This document is the source of truth for *what* to build. Build it in the
numbered steps below, in order — each step ends in a playable, testable
game. After each step, ask the user to playtest (per CLAUDE.md, don't drive
the game yourself) and update ARCHITECTURE.md before moving on.

## Explicit design decisions (don't re-ask these)

- **Agency over gating.** The flower is never actually inaccessible — there
  is no state where the player *can't* act, only one where acting is
  riskier. This is the whole point: the player always gets to choose
  whether to eat the risk for one more shot/pickup or bail.
- **Aggro is proximity-and-dwell driven, not action-specific.** The guard
  doesn't care whether the player is firing, sucking, or just hovering —
  it only cares how long the bug has stayed within `notice_range` of the
  flower it's guarding. This keeps the guard's logic self-contained (no
  new signals/state needed from `player.gd`) and naturally punishes the
  point-blank-spam case (which requires dwelling close) while barely
  touching pollen/seed pickup (which is already a quick in-and-out).
- **Telegraph is mandatory and generous.** Aggro crossing the threshold
  doesn't lunge immediately — it enters a windup pose (visibly rears back,
  buzz pitch rises) held for `windup_duration` (~0.4–0.6s, tuned so a player
  paying attention always has time to peel off). Only after windup
  completes does the guard actually lunge.
- **Leaving `notice_range` during windup cancels the lunge** and lets aggro
  decay back down — the bail is always available, right up until the
  lunge itself starts.
- **Punishment reuses the existing gnat-touch contract exactly**: on
  lunge-contact, duck-typed calls to `steal_water()` and `lose_pollen()`
  (mirrors `enemy.gd`). **Seeds are never touched**, same rule and same
  reasoning `enemy.gd` already documents — losing a seed is too punishing
  for a "friction, not failure" hazard.
- **No lose state; this is friction.** A hit costs water/pollen progress,
  never the run. Matches GAMEPLAY.md's existing "Enemies are friction, not
  failure" rule — the guard is a variation on that rule, not an exception
  to it.
- **After a lunge (hit or miss), the guard resets**: aggro drops to zero
  and it can't re-notice for `reaggro_cooldown`, so a single close call
  buys the player breathing room rather than an immediate second threat.
- **Not every flower needs a guard.** Placement is a level-design choice
  (Step 4) — guards go on flowers where point-blank camping is the likely
  play (e.g. ones with generous water nearby), not blanket-applied
  everywhere.

## Incremental build steps

### Step 1 — Guard scene, patrol only

- New scene `scenes/flower_guard.tscn` + `scripts/flower_guard.gd`. Unlike
  `enemy.tscn`'s random leash-wander, the guard's patrol is a deterministic
  circle around the flower it's assigned to guard (`guarded_flower`, a
  sibling-node reference set in `main.tscn`, per the scene-level-association
  direction below) — constant orbit radius/speed. Unlike the gnat's
  constant idle spin, the guard's visual stays level/horizontal at all
  times, but flips (smoothly, mirroring `player.gd`'s facing flip) when its
  direction of travel around the circle changes, and its wings flap
  continuously (reuses `wings.gd`, same as the player). No aggro, no notice
  range, no touch effect yet — it's just a visible thing circling a flower.
- Placed once in `main.tscn` near a single flower cluster for testing.

**Testable:** a new hazard patrols visibly near a flower and does nothing
else yet.

### Step 2 — Aggro build/decay + telegraph (no punishment yet)

- Add `notice_range`, `aggro_build_rate`, `aggro_decay_rate`, and
  `aggro_threshold` to the guard (values live on the guard's own
  `@export`s or a new tuning resource, per CODING.md's "tuning is data"
  rule — see Architectural direction).
- Each frame: if the player is within `notice_range` of the *guarded
  flower* (not the guard's own position — the flower is what's being
  camped), aggro rises toward 1.0 at `aggro_build_rate`; otherwise it
  decays at `aggro_decay_rate`.
- Crossing `aggro_threshold` switches the guard into a windup pose held for
  `windup_duration`: visual cue (e.g. rearing back / tightening its
  circling) plus a buzz whose pitch rises with aggro. If the player leaves
  `notice_range` during windup, cancel back to patrol and let aggro decay
  as normal — no lunge fires.

**Testable:** hover/camp near the guarded flower and watch the guard's
buzz/visual escalate and freeze into a windup pose after a few seconds;
back off before it commits and watch it stand down instead of attacking.

### Step 3 — Lunge + punishment

- If windup completes without the player leaving `notice_range`, the guard
  dashes at the player's current position at `lunge_speed` (a real Area2D
  move, not instant), then reverts to patrol regardless of whether it
  connected.
- On contact during the lunge: duck-typed `steal_water()` /
  `lose_pollen()` calls exactly like `enemy.gd`'s `_on_body_entered` (seeds
  untouched), plus a distinct hit sound (not the calm buzz).
- After the lunge resolves (hit or miss), aggro resets to 0 and
  `reaggro_cooldown` gates it from re-noticing the player immediately.

**Testable:** the full loop — dwell too long near the guarded flower, watch
the telegraph, then either get caught by the lunge (losing held pollen/some
water) or successfully bail during windup; after a lunge, the guard leaves
the player alone for a beat before it can threaten again.

### Step 4 — Placement and tuning pass

- Decide which flower clusters in the level get a guard (not all of them —
  see design decisions above) and place `flower_guard.tscn` instances
  accordingly.
- Tune `notice_range` / `aggro_build_rate` / `aggro_threshold` /
  `windup_duration` together so that: firing from actual range (using the
  droplet's real arc) never builds enough aggro to matter, but sitting
  point-blank and spraying repeatedly reliably triggers a windup within a
  few shots. A quick pollen/seed swoop should essentially never trigger it.

**Testable:** watering from a sensible range feels unaffected by the
guard; point-blank camping reliably gets contested within a few seconds.

### Step 5 — Fit-and-finish pass

- Sounds for: calm patrol buzz (loop, volume-faded per the existing
  convention), rising aggro/windup tone, lunge whoosh, and hit (distinct
  from the gnat's `steal_sound` so the two hazards read as different
  threats).
- Confirm "nothing snaps": patrol → notice → windup → lunge → reset all
  read as continuous motion, not state pops.
- Confirm the windup pose is readable at gameplay zoom/size from the
  distance a player would realistically be reacting from.

## Architectural direction

Follow CODING.md throughout (static typing, signals over tree-reaching,
compose scenes, no dead code). Specifics for this feature:

- **`flower_guard.gd` is a self-directed active entity**, same category as
  `enemy.gd`: it owns its own movement (`_process`, leash-patrol) and
  detects the player itself via `body_entered` (the player is a physics
  body, not an `Area2D` detectable), rather than being polled by the
  player's sensor per Pattern 2. Don't force it into the passive-detectable
  mold — it needs to track the player's distance and initiate its own
  lunge, which passive detectables structurally can't do.
- **No new player-side code for punishment.** Reuse `steal_water()` and
  `lose_pollen()` exactly as `enemy.gd` calls them — the guard is a new
  hazard *behavior*, not a new hazard *contract*.
- **Tuning stays data**, per the existing `Water`/`Proboscis`
  `@export_group`s on `GameplayTuning` — add a `FlowerGuard` group there
  (`notice_range`, `aggro_build_rate`, `aggro_decay_rate`,
  `aggro_threshold`, `windup_duration`, `lunge_speed`, `reaggro_cooldown`)
  rather than hardcoding constants in `flower_guard.gd`, matching how
  `enemy.gd` currently keeps its own knobs as local `@export`s (fine to
  follow either precedent, but stay consistent within the new script).
- **Which flower a guard watches is a scene-level association**, not a
  runtime search — wire the guard to its target flower the same way
  `enemy.gd`'s leash is anchored to its own spawn position (an `@export`
  or a sibling-node reference set up in `main.tscn`), not by having the
  guard hunt the tree for the nearest seedling every frame.
- **Update ARCHITECTURE.md at the end of every step**: add
  `flower_guard.tscn` to the scene catalog (mirroring the `enemy.tscn`
  entry's style), and note in the catalog that it's a second self-directed
  hazard alongside the gnat cloud, not a new named Pattern (the "active
  entity" shape is already established by `enemy.gd`, so this doesn't need
  its own bullet in the Patterns list — just the catalog entry).

## Fit and finish

Apply continuously; Step 5 is the sweep for anything missed.

- **Nothing snaps.** Patrol, notice, windup, lunge, and reset all animate
  continuously (0.15–0.4s beats where discrete, per the rest of the game).
- **Every action answers back.** The guard's own state changes (noticing,
  winding up, lunging, hitting) each get a sound and a visual cue distinct
  enough from the gnat cloud's that the player can tell the two hazards
  apart at a glance.
- **Readability.** The player must always be able to tell, before it
  happens, that a lunge is coming — the windup is the entire fairness
  contract for this hazard. If a lunge ever reads as unavoidable or
  unforeshadowed in testing, that's a bug in the telegraph, not an
  acceptable hazard.
- **Enemies are friction, not failure** (GAMEPLAY.md). This hazard costs a
  trip — lost water, lost pollen — never a lose state.
