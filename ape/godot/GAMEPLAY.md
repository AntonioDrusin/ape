# Gameplay: Pollination

What the game is and how it should feel to play. This is a direction document, not a task list — for architecture and code patterns see [ARCHITECTURE.md](ARCHITECTURE.md).

## The fantasy

You're a small flying bug tending a garden. The pleasure is twofold: the *flying* — thrust-based, floaty, a little demanding to control well — and the *gardening* — watching plants change state as a direct result of what you carry and where you deliver it. Nothing in the garden moves on its own; every change is something the player caused by flying somewhere and hovering.

The bee is always carrying legible cargo. At a glance the player should be able to answer: what pollen am I holding, what seed am I holding, which flowers nearby are ready for something? The world telegraphs state through color and shape, not menus or numbers.

## The core loop

Water turns a seedling into a bloom. A bloom offers pollen. Pollen carried to a *different kind* of bloom cross-pollinates it, marking it to produce a hybrid seed on its next watering. That seed, carried to an empty plot, becomes a new seedling — of a plant that didn't exist in the world before the player made it exist. Growing the round's four target plants (rolled fresh each run) wins.

Everything hangs off two carry slots — one pollen, one seed — held simultaneously but each capped at one. The bee never juggles more than that, so the player's mental state is always simple: what color is on my abdomen, what's hanging beneath me.

Discovery is part of the feel: the combo chart tells you the 8 real pairings, but the 2 fizzle pairs are deliberately *not* documented — finding out Daisy+Apple goes nowhere is a small "huh" moment, not a failure state. Same-type pollination is a no-op rather than a punishment, so experimenting never costs the player their pollen.

## Feel and pacing

- **Nothing snaps.** Every state change — bloom, pollinate, seed pop, pickup, goal check-off, win — animates over 0.15–0.4s. A garden that pops between states like a slideshow breaks the fantasy that these are living plants.
- **Every action answers back.** A sound and a visual, together, for every player-triggered change. Silence on a successful action reads as "did that work?" — the one feeling this game must never produce.
- **The seed makes you feel its weight.** Carrying a seed costs a touch of top speed (~10%) — just enough that delivering it across the map feels like an errand with stakes, not a free action. It should never feel like a chore; if it does in testing, cut it.
- **Enemies are friction, not failure.** Gnat swarms steal water and knock pollen off on touch — they cost you a trip, not the game. There's no lose state; the pressure is "avoid the detour," not "avoid dying."
- **A win run runs 5–10 minutes.** Long enough that the loop (water → pollinate → water → carry → plant → water) plays out a few times across different plant pairs, short enough to replay immediately with a new random goal set.

## Readability rules

- Pollen colors (white, pink, purple, red, orange) must stay tellable apart at bee-butt size and against every level background — color alone carries the information, so it has to survive at a glance, in motion, from a distance.
- The combo chart and goal panel use the *same* rendering as the in-world plants (same shapes, same colors, just smaller) — the player should never have to translate between "chart language" and "world language."
- UI is anchored, not pixel-placed, and never eats more of the play space than it must. The garden is the point; the panels are reference material at the edges.

## Where the feel comes from architecturally

Plant facts (types, pollen colors, combos, names) live in one table (`PlantData`) that both gameplay and UI read from — this is what keeps the chart, the icons, and the actual pollination outcomes from ever drifting apart, which matters because the whole discovery loop depends on the chart being trustworthy. See ARCHITECTURE.md's Patterns section for the mechanics of how this and the feedback/animation conventions are enforced in code.
