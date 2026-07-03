# Ape

A 2D Godot game (side-view, platformer-style) where the player controls a flying bug that flaps and thrusts through a level of platforms.

- Architecture, scene tree layout, and system responsibilities: see [ARCHITECTURE.md](ARCHITECTURE.md).
- Coding conventions and practices to follow when writing GDScript or scenes: see [CODING.md](CODING.md).
- Planned gameplay features and the incremental build plan for them: see [REQUIREMENTS.md](REQUIREMENTS.md).

Keep both documents in sync with the code: update ARCHITECTURE.md when scenes/systems are added, moved, or renamed.

## Running the game

Godot Engine is installed locally at `G:\SteamLibrary\steamapps\common\Godot Engine`. Use the `godot.sh` launcher script at the repo root (`C:\dev\ai-tests\godot.sh`) instead of hardcoding the path elsewhere:

```bash
./godot.sh --path ape/godot --editor   # open the project in the editor
./godot.sh --path ape/godot            # run the game
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
