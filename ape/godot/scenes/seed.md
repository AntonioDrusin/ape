# `seed.tscn` — popped seed

`Seed` (`Area2D`, group `seed`), script: `scripts/seed.gd`. Spawned by `Main` (`main.gd`) when a `Seedling` finishes `SEED_GROWING` (see `scenes/seedling.md`). Two children: a `CollisionShape2D` (`CircleShape2D`, for the future pickup detection in Step 4) and `Body`, a small `Polygon2D` seed shape.

`plant_type` (`@export`, typed `PlantData.PlantType`) is set by `main.gd` right after instantiation, from the hybrid the popping plant produced. `_ready()` colors `Body` via `PlantData.seed_color(plant_type)` — the same table `seedling.gd` uses for its swelling pod, so the seed's color matches what the player watched grow — then plays a short arc-with-a-bounce entrance (`_play_pop_in()`): the seed starts above and offset to a random side, tweens down toward its rest position with a bounce ease. This is the first use of `create_tween()` in the codebase (everything else animates via `_process()`); kept short (~0.35s) per REQUIREMENTS.md's "nothing snaps" guidance.

Pickup (REQUIREMENTS.md Step 4) happens entirely on the player's side: `player.gd`'s `WaterSensor` poll detects the `seed` group area each physics tick, and if the player's seed slot is empty, reads `plant_type` off it and calls `queue_free()` — the seed scene itself has no pickup logic or signal, it's purely a passive detectable that gets consumed.
