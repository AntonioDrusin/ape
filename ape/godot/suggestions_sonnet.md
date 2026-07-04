# Why the game is fun, why it isn't, what to improve

Based on a read of `REQUIREMENTS.md`, `ARCHITECTURE.md`, `GAMEPLAY.md`, and
`player.gd` (the just-implemented proboscis rework).

## Why it's fun

- **Two skills, one body.** Thrust-based flight (imprecise, floaty,
  drag-based) is already a mini-skill on its own; layering an aimed
  water-shot on top means "fly well" and "aim well" now compound rather than
  being separate minigames. That's the strongest thing in the design.
- **Legible state, zero UI-reading.** Pollen color on the abdomen, seed
  underneath, tank level — everything you need to decide "what do I do next"
  is visible on the bug itself. No stopping to check a menu.
- **Discovery via omission.** Deliberately not documenting the 2 fizzle
  pairs in the combo chart is a nice touch — it turns "read the wiki" into
  "try it and find out," and because fizzling costs nothing (same-type is a
  no-op, fizzle just clears your pollen with no punishment), experimentation
  is free. That's rare restraint.
- **"Every action answers back."** The fit-and-finish discipline (sound +
  visual for suck/fire/hit/miss, nothing snaps, 0.15–0.4s on every
  transition) means the moment-to-moment feedback loop is going to feel
  *tight* even before content is added. This is the kind of thing that's
  invisible when done right and glaring when missing — good that it's a
  named policy.
- **The new aim mechanic gives the water loop actual failure.** Before this
  change, watering was "hover long enough" — no skill expression at all.
  Now a bad shot is wasted resource and time. That's a real improvement in
  kind, not just degree.

## Why it might not land

- **The aim mechanic has no aiming input.** Reading `player.gd:274-282`, a
  shot's direction is just *your current velocity + a horizontal kick in
  your facing direction* — there's no up/down aim control at all. "Aim" is
  entirely "position your body's height and horizontal velocity correctly,
  then fire straight-ish forward." That can absolutely work, but it means
  the skill ceiling is capped by flight control alone; a droplet doesn't let
  you *choose* a trajectory, just inherit one. Worth explicitly deciding
  whether that's the intended skill (I suspect it is — "you're aiming with
  your whole body," consistent with the flying-focused fantasy) versus
  something that'll feel like the shot "didn't do what I wanted" in
  practice.
- **Misses cost time, not failure.** There's no losing state anywhere
  (`ARCHITECTURE.md`: "there's no losing state"), and enemies are explicitly
  friction not failure. Combined with unlimited water refills at any pool, a
  miss just means "fly back and refill, try again." That's fine for a
  low-stakes garden game, but it means the new aiming skill has low
  consequence — the tension of "did I hit it" is emotional, not systemic. If
  shots feel unrewarding in playtest, the fix isn't more punishment, it's
  more *reward* on a hit (a stronger visual/audio payoff, maybe a small
  growth bonus for a clean multi-hit streak) rather than a harsher miss.
- **One static level.** `main.gd` is "currently *the* single static level
  (there is no level-loader... per CODING.md, don't build one until a
  second level exists)." Replayability is currently just re-rolled goal
  plants in the same space. A 5–10 minute win run replayed a few times on
  identical geometry will plateau in interest faster than the mechanical
  depth (hybrids, aiming) would suggest — level variety is probably the
  highest-leverage thing missing, not more mechanics.
- **Skill asymmetry between systems.** Watering now requires real aim;
  pollen collection and seed pickup are still pure hover/instant-touch, no
  skill at all. That's a deliberate, documented choice ("Pollen collection
  and pollination are unaffected"), and it's reasonable to keep pollen as
  the "easy" half of the loop for pacing — but it does mean two-thirds of
  the core loop (pollen → cross-pollinate → seed → plant) still has zero
  player-skill expression, only the watering step does. Worth watching in
  playtest whether pollen/seed steps start feeling like tedious transit
  between the one part of the game with actual gameplay.

## What to do to improve

1. **Playtest Step 5's fire feel first** (it's marked Done) — specifically
   whether the lack of a distinct up/down aim reads as "skillful" or
   "arbitrary." If it's the latter, the fix is probably giving
   `move_up`/`move_down` a stronger effect on shot arc rather than adding a
   new aim input — keep it one-handed.
2. **A second level** before more mechanics — the design already has the
   depth (hybrids × aim × enemies-as-friction); it's under-exercised by
   having only one arena to exercise it in.
3. **Make a hit feel disproportionately good relative to a miss** rather
   than making misses hurt more — matches the "nothing punishes, discovery
   is free" ethos already established for fizzles.
4. **Sanity-check the tuning numbers** in `data/player_tuning.tres`
   (`droplet_fire_interval`, `water_per_shot`, tank size vs. suck fill time)
   — this is where "aiming feels good vs. feels stingy" usually lives in
   practice, separate from the mechanic design itself.
</content>
</invoke>
