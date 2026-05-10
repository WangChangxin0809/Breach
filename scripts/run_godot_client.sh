#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if [ "${GODOT_BIN:-}" ]; then
	GODOT="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
	GODOT="godot"
elif command -v godot4 >/dev/null 2>&1; then
	GODOT="godot4"
elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
	GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
else
	echo "Godot executable not found. Set GODOT_BIN to your Godot executable path." >&2
	exit 1
fi

exec "$GODOT" --path "$ROOT_DIR/client" "$@"
