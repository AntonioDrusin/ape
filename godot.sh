#!/usr/bin/env bash
# Launches the local Godot Engine install.
# Usage: ./godot.sh [args...]
# e.g. ./godot.sh --path ape/godot

GODOT_BIN="G:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"

exec "$GODOT_BIN" "$@"
