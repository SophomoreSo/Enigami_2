#!/usr/bin/env bash
# Export one preset, and insist something actually came out.
#
# Usage: export.sh <preset> <output-path> [release|debug]
#
# Godot returns nonzero when a preset is misconfigured, which is most of the
# ways an export goes wrong. It is less reliable about an export that produces
# nothing, so the size check below is the one that catches a silent dud.

set -euo pipefail

PRESET="$1"
OUT="$2"
MODE="${3:-release}"
GODOT="${GODOT:-godot}"

mkdir -p "$(dirname "$OUT")"

echo "Exporting $PRESET ($MODE) -> $OUT"
"$GODOT" --headless "--export-$MODE" "$PRESET" "$OUT"

if [ ! -e "$OUT" ]; then
	# iOS with export_project_only writes a directory of files beside the path
	# it was given rather than the file itself.
	if [ -n "$(ls -A "$(dirname "$OUT")" 2>/dev/null)" ]; then
		echo "No $OUT, but $(dirname "$OUT") is not empty:"
		ls -lh "$(dirname "$OUT")"
		exit 0
	fi
	echo "::error title=Export produced nothing::$PRESET wrote neither $OUT nor anything beside it."
	exit 1
fi

size=$(wc -c < "$OUT" | tr -d ' ')
if [ "$size" -lt 1000000 ]; then
	echo "::error title=Export looks empty::$OUT is only $size bytes."
	exit 1
fi

echo "$OUT — $(du -h "$OUT" | cut -f1)"
