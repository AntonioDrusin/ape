#!/usr/bin/env bash
# Launches the Ape game (not the editor) in the background.
# Usage: ./run-game.sh
# Writes the process id to .godot-game.pid so stop-game.sh / screenshot-game.sh can find it.

set -euo pipefail

cd "$(dirname "$0")"

PIDFILE=".godot-game.pid"

IMAGE_NAME="godot.windows.opt.tools.64.exe"

if [ -f "$PIDFILE" ] && tasklist //FI "PID eq $(cat "$PIDFILE")" 2>/dev/null | grep -q godot; then
	echo "Game already running with PID $(cat "$PIDFILE")"
	exit 0
fi

./godot.sh --path ape/godot >/tmp/godot-game.log 2>&1 &

# Git Bash's $! is an MSYS pid, not the real Windows pid for a launched GUI
# process, so look up the real one via tasklist once it appears.
GAME_PID=""
for _ in $(seq 1 20); do
	sleep 0.5
	GAME_PID=$(tasklist //FI "IMAGENAME eq $IMAGE_NAME" //FO CSV //NH 2>/dev/null | tail -n1 | cut -d, -f2 | tr -d '"')
	[ -n "$GAME_PID" ] && break
done

if [ -z "$GAME_PID" ]; then
	echo "Game did not appear to start - check /tmp/godot-game.log"
	exit 1
fi

echo "$GAME_PID" > "$PIDFILE"
echo "Game launched, PID $GAME_PID (see $PIDFILE)"
