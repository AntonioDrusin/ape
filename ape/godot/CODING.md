# Coding practices

Kept short and specific to this project on purpose — add to this list only when a real problem justifies it, not speculatively.

1. **Type everything.** Use static typing on all variables, parameters, and return types (`var speed: float`, `func foo(x: int) -> void`). Godot's type checker catches whole classes of bugs at parse time instead of at runtime — use it.

2. **DRY tunable values, don't DRY structure.** Repeated *numbers* (a speed, a radius, a color used in two places) become an `@export var` or a `const`, so there's one place to tune them and they show up in the Inspector. Repeated *node structure* (two similar platforms, two similar enemies) should stay as separate scene instances with different data, not a shared script trying to branch on a type flag — see point 4.

3. **Keep scripts scoped to the node they're attached to.** A script should own the behavior of its own node and talk to others through exported references, signals, or `%UniqueName` — never reach across the tree with long relative paths (`get_node("../../Foo/Bar")`). If two nodes need to coordinate, prefer the child emitting a signal the parent connects to, over the child calling up into the parent directly (see `wings.gd`/`player.gd`: the player reads/sets `wings.flapping`, it doesn't reach into wing internals).

4. **Compose scenes, don't branch on type.** New level content (platforms, enemies, pickups) should be new scenes instantiated into the level, or exported parameters on an existing scene — not `if type == "moving"` conditionals bolted onto one script. If two things need to share real behavior, factor it into a shared script/scene both instance, added when the second case actually appears (not preemptively).

5. **No dead code or commented-out blocks.** Delete unused scenes, scripts, and code paths rather than leaving them "just in case" — git history is the undo button.

6. **Match existing naming:** scenes/scripts in `snake_case.gd` / `PascalCase.tscn`-node-names as already used, signals named as past-tense events (`died`, `platform_touched`), functions as verbs. Consistency across the project matters more than any individual name choice.
