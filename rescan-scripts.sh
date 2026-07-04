#!/usr/bin/env bash
# Forces Godot to rescan scripts and rebuild the global class_name cache
# (.godot/global_script_class_cache.cfg) without opening the editor UI.
# Run this after adding or renaming a `class_name` in ape/godot/scripts/ -
# otherwise other scripts referencing that class fail to parse until the
# editor is opened at least once.
# Usage: ./rescan-scripts.sh

set -euo pipefail

cd "$(dirname "$0")"

./godot.sh --path ape/godot --editor --headless --quit
