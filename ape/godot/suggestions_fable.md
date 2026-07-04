# Design review: why this game is fun, where it isn't, and what to do about it

Written from the design docs (GAMEPLAY.md, REQUIREMENTS.md, ARCHITECTURE.md) as of the
completed proboscis/droplet rework. This is an opinion document, not a task list.

## Why it's fun

**Two pleasures that feed each other.** The fantasy is well-chosen: floaty, slightly
demanding flight *plus* a garden that only ever changes because you flew somewhere and did
something. Each half makes the other better — flight is the friction that makes gardening
feel earned, and gardening gives the flight a destination. Games with only one of these
(pure movement toys, pure idle gardens) burn out faster.

**You author things into existence.** The hybrid loop — pollen from one bloom, carried to a
different bloom, watered into a seed, planted into a plant *that didn't exist in the world
before* — is the emotional core. It's a creation loop, not a collection loop, and that's a
meaningfully stronger hook than "gather 4 of X."

**State is legible without UI.** Two carry slots, each capped at one, telegraphed by color
and shape on the bee itself. The player's mental model is always answerable at a glance.
The chart and goal panel reusing the *actual* in-world plant rendering (via `PlantData` /
`PlantIconSource`) is quietly excellent — the player never translates between chart
language and world language, and the architecture makes drift impossible.

**The droplet rework added a skill axis the game was missing.** Before it, watering was a
soak: hover and wait. Now water is sucked deliberately, carried as a finite tank, and
*fired* as a projectile that arcs under gravity and can miss — with misses unrefunded. One
button, context-split by proximity (near water: suck; away: spray), no mode switch. That's
elegant input design, and it converts the most-repeated verb in the game from passive to
expressive.

**Failure is friction, not punishment.** No lose state, gnats cost a trip rather than the
run, same-type pollination is a no-op, fizzle combos are a "huh" not a fail. Experimenting
is always safe. Combined with 5–10 minute runs and re-rolled goals, this is a genuinely
replayable, low-stress shape.

**The feel rules are the right ones.** "Nothing snaps" and "every action answers back" are
the two conventions that most reliably separate games that feel alive from games that feel
like spreadsheets, and they're enforced architecturally (pattern 6), not just aspired to.

## Why it isn't (yet)

**Aim was made to matter, but nothing makes you aim.** The droplet arc is "the whole
skill" per REQUIREMENTS.md — but plants are stationary and the bee can hover point-blank
above any seedling and fire straight into it. There is currently no force in the game that
creates *distance* between the shooter and the target, so the miss/waste economy the
rework built barely activates. The skill axis exists but the game never asks for it.

**Water scarcity is nominal.** Water is free and infinite at the pool; the only cost of a
wasted shot is a return flight, and auto-suck (Step 5) made refilling fully passive —
drift near the surface and the tank fills. That was the right call for friction, but it
means the tank is never a real resource decision, just a timer between trips. The water
meter carries almost no tension.

**The mid-run flattens into a checklist.** The loop's verbs (water → pollinate → water →
carry → plant → water) are great the first two times through; by goal plant #3 and #4 the
player is executing a known route with no new decisions. Nothing escalates, nothing about
the fourth hybrid is harder or more interesting than the first. The random goal roll
varies *which* plants, not *how it plays*.

**Discovery is shallower than it wants to be.** GAMEPLAY.md calls discovery "part of the
feel," but the combo chart documents all 8 real pairings up front — the only genuine
discoveries are the 2 undocumented fizzles, and a fizzle is (deliberately) an anticlimax.
After one read of the chart, the discovery well is dry.

**Replay motivation is thin.** With no scoring, no timing, and no record of a run, "play
again" re-rolls goals but offers the player no way to know whether this run was *better*
than the last one. The game respects the no-lose-state philosophy but currently gives
mastery nothing to point at.

**Feedback is promised but placeholder.** Fire, hit-splash, and miss-splash all reuse
existing clips (`water_pour.wav`, `seed_plant.wav`). "Every action answers back" is
weakest exactly where it matters most now: hit vs. miss on a small fast droplet needs to
be tellable apart *by ear*, because the visual splash happens far from where the player is
looking (they're flying).

## What to do — prioritized

1. **Give the player a reason to shoot from range.** This is the highest-leverage fix
   because the mechanic is already built. Cheapest version: let gnat swarms loiter near
   goal-relevant seedlings, so hovering close means losing water/pollen and the safe play
   is lobbing droplets from outside the swarm's leash. That reuses the existing enemy,
   keeps "friction, not failure," and instantly activates the aim skill. (Alternatives:
   plants in alcoves the bug can't hover directly over; a plant type that closes when the
   bug is near.)

2. **Quantize the water meter into shots.** Tune `water_per_shot` so a full tank is a
   small legible number of droplets (say 6–8) and render the meter as pips, not a bar —
   consistent with the "shape and color, not numbers" readability rule. Now "do I have
   enough to finish this plant or do I refill first?" becomes an actual per-trip decision,
   which is all the scarcity this game needs. No change to auto-suck required.

3. **Escalate across the four goals.** Keep the verbs identical but make each successive
   goal ask a bit more: later goal plants roll toward hybrids whose parents grow farther
   apart, or whose plots sit in gnat-patrolled/awkward-to-hover spots. Zero new systems —
   it's a goal-rolling and level-layout change — but it turns the checklist into a ramp.

4. **Put a gentle score on the win screen.** Time, droplets fired vs. hits, blooms grown —
   shown *only at the end*, never during play (the garden stays pressure-free). This gives
   replays a target without adding a lose state, and it's nearly free: `Main` already
   tracks goals and spawns the overlay.

5. **Make discovery earnable: fill the chart in as you do it.** Show each combo row as
   silhouettes until the player performs that pairing once, then reveal it (persist
   nothing; per-run is fine and fits re-rolled goals). This directly deepens the stated
   discovery pillar. It does soften the "chart tells you the 8 pairings" decision in
   GAMEPLAY.md — if that guarantee matters for first-time onboarding, reveal parent
   *types* but not outcomes.

6. **Replace the placeholder audio, hit vs. miss first.** The hit-splash should be round
   and rewarding, the miss-splash flat and damp — distinguishable without looking. This is
   the single cheapest "game feel" win available and the docs already flag it as pending.

7. **Playtest the seed weight against its own kill criterion.** GAMEPLAY.md says the ~10%
   speed cost should feel like "an errand with stakes, not a chore — if it does, cut it."
   That's a testable claim; test it, especially now that runs also include water ferrying,
   which stacks a second errand on top.

The through-line: the bones — fantasy, loop, legibility, feel rules — are genuinely
strong, and the droplet rework built a good skill mechanic. Almost everything on the list
above is about *activating* systems that already exist (aim, the tank, the goals, the
chart) rather than adding new ones, which is exactly where this project's own
"add it when the second case appears" philosophy says the effort should go.
