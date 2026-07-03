# `intro_screen.tscn` — how-to-play overlay

`IntroScreen` (`CanvasLayer`), script: `scripts/intro_screen.gd`. A full-screen `ColorRect` behind a centered `VBoxContainer` of three `Label`s: a title, a short block of instruction text (controls + goal), and a "Press SPACE to start" prompt.

`Main` (`main.gd`) pauses the tree in `_ready()` before this overlay is shown, so `intro_screen.gd` sets its own `process_mode` to `PROCESS_MODE_ALWAYS` in `_ready()` to keep receiving input while everything else is frozen. `_unhandled_input()` watches for `ui_accept` (Space/Enter by default); on press it emits `start_requested` — which `Main` connects to in order to unpause — and then frees itself, since it has no further purpose once the level starts.
