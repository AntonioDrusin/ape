# Ape

A 2D Godot game (side-view, platformer-style) where the player controls a flying bug that flaps and thrusts through a level of platforms.

- Architecture, scene tree layout, and system responsibilities: see [ARCHITECTURE.md](ARCHITECTURE.md).
- Coding conventions and practices to follow when writing GDScript or scenes: see [CODING.md](CODING.md).
- Planned gameplay features and the incremental build plan for them: see [REQUIREMENTS.md](REQUIREMENTS.md).

Keep ARCHITECTURE.md in sync with the code: update its Patterns section and scene catalog when scenes/systems are added, moved, renamed, or change role. Detail deliberately does *not* live in docs — node structure, signal signatures, and tuning values live only in the `.tscn`/`.gd` files, and rationale lives as a script comment at the line a future edit would break (see "Where information lives" in ARCHITECTURE.md). There are no per-scene doc files; don't create them.

## Running the game

Godot Engine is installed locally at `G:\SteamLibrary\steamapps\common\Godot Engine`. Use the `godot.sh` launcher script at the repo root (`C:\dev\ai-tests\godot.sh`) instead of hardcoding the path elsewhere:

```bash
./godot.sh --path ape/godot --editor   # open the project in the editor
./godot.sh --path ape/godot            # run the game
```

### After adding or renaming a `class_name`

Godot only rebuilds the global class cache (`.godot/global_script_class_cache.cfg`) by scanning scripts when the editor opens — running the game directly does not trigger it. Until that happens, any script referencing the new/renamed class fails to parse (silently, from the game's perspective — it just stops working, e.g. a node with no behavior). After adding or renaming a `class_name`, run:

```bash
./rescan-scripts.sh   # headless editor pass that just rebuilds the class cache, no UI
```

### Visually checking a change

To see a change running (not just editor/typecheck), use the helper scripts at the repo root (`C:\dev\ai-tests`):

```bash
./run-game.sh                                        # launch the game in the background, tracks PID in .godot-game.pid
powershell -File screenshot-game.ps1 [outputPath]    # bring the game window to front and screenshot it (default: %TEMP%\claude\godot_screenshot.png)
./stop-game.sh                                       # close the game window started by run-game.sh
```

Note: Git Bash's `$!` does not match the real Windows PID for a launched GUI process, so `run-game.sh` looks up the actual PID via `tasklist` after launch rather than trusting the job PID directly.

### Testing changes

Don't launch/screenshot/drive the game yourself to verify a change. Ask the user to test it (describe what to try) and report back what they see.
