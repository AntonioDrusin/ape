# `hud.tscn` — water meter

`HUD` (`CanvasLayer`), script: `scripts/hud.gd`, with a `Control` anchored top-left containing a `ProgressBar` (`WaterMeter`, range 0-1). `hud.gd` finds the player via the `player` group in `_ready()` and connects to its `water_level_changed` signal — the HUD reaches out to the player rather than the player knowing about the HUD, so `player.gd` stays UI-agnostic.

`WaterMeter` is themed blue (`StyleBoxFlat` overrides on `background`/`fill`) with a `ShaderMaterial` (`assets/shaders/water_meter.gdshader`) giving both bars a rippling top edge (vertex displacement) and a shimmering brightness pulse (fragment) — purely cosmetic, doesn't touch `value`. `clip_contents = true` on `WaterMeter` keeps its `Bubbles` child (`CPUParticles2D`, rectangle emission spanning the bar) contained to the bar's rect as small bubbles drift upward and fade, matching the CPUParticles2D convention used elsewhere (`WaterDrip`, `PollenPuff`).
