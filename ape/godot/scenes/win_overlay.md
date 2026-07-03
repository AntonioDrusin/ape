# `win_overlay.tscn` — win screen (Step 6)

`WinOverlay` (`CanvasLayer`), script: `scripts/win_overlay.gd`. Not pre-placed in `main.tscn` — `Main` preloads and `add_child()`s it only once `won` fires (see `main.md`'s "Goal tracking and win condition" section), since unlike `IntroScreen` it isn't needed from the start of every run.

Structure mirrors `intro_screen.tscn` (full-screen `ColorRect` behind a centered `VBoxContainer`), reversed to appear at the end rather than the start:

- `Background` — full-screen `ColorRect`, a dark green-gold tint distinct from the intro screen's blue-grey.
- `CelebrationAnchor` — a zero-size `Control` anchored dead-center, existing purely so its child `Celebration` (`CPUParticles2D`, one-shot burst, warm gold color) gets a screen-center origin from Control anchoring without a `Node2D` needing anchors of its own (which it can't have).
- `VBoxContainer` — centered, containing `Title` ("You Win!"), `Subtitle`, and `PlayAgainButton` — the project's first actual `Button` node (`intro_screen.tscn` only needed a keypress, no earlier scene needed a real button).
- `WinSound` — `AudioStreamPlayer` playing `assets/audio/win_fanfare.wav` (procedurally generated, see `CREDITS.md`).

`Main` pauses the tree before instantiating this scene, so `_ready()` sets `process_mode = PROCESS_MODE_ALWAYS` (same reason `intro_screen.gd` does) to keep receiving `PlayAgainButton`'s input and let the particles/sound play. `_ready()` also starts the celebration burst and plays the sting immediately. `PlayAgainButton.pressed` calls `get_tree().reload_current_scene()`, which re-instantiates `Main` from scratch — its `_ready()` re-rolls `goal_types` via `randomize()` and re-pauses for a fresh `IntroScreen`, so no explicit unpause/reset bookkeeping is needed here beyond unpausing before the reload.
