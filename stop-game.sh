#!/usr/bin/env bash
# Stops the Ape game previously launched with run-game.sh.
# Usage: ./stop-game.sh

set -euo pipefail

cd "$(dirname "$0")"

PIDFILE=".godot-game.pid"

if [ ! -f "$PIDFILE" ]; then
	echo "No PID file found ($PIDFILE) - is the game running? Falling back to killing by name."
	taskkill //IM godot.windows.opt.tools.64.exe //F || echo "Nothing to stop."
	exit 0
fi

PID=$(cat "$PIDFILE")
if tasklist //FI "PID eq $PID" 2>/dev/null | grep -q godot; then
	taskkill //PID "$PID" //F
	echo "Stopped game (PID $PID)"
else
	echo "No running game found for PID $PID"
fi

rm -f "$PIDFILE"
