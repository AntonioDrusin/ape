#!/usr/bin/env bash
# Launches the Ape game (not the editor) in the foreground, streaming logs
# verbosely to this terminal. Blocks until the game exits (Ctrl+C to stop).
# Usage: ./run-game.sh

set -euo pipefail

cd "$(dirname "$0")"

exec ./godot.sh --path ape/godot --verbose
