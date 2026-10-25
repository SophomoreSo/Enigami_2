#!/usr/bin/env bash
# Build the import cache, and refuse to go further if the project does not parse.
#
# `.godot/` is gitignored, so a fresh checkout has no class cache at all and
# every `class_name` is an undeclared identifier until this has run. It is the
# first step of every job, not a fallback for when one errors.
#
# Godot exits 0 from `--import` even when scripts fail to parse, so the exit
# code is not the verdict here — the log is.
#
#   --allow-errors   report parse errors but do not fail (the module-split job
#                    deletes autoloads on purpose, and expects the noise)

set -uo pipefail

ALLOW_ERRORS=0
[ "${1:-}" = "--allow-errors" ] && ALLOW_ERRORS=1

GODOT="${GODOT:-godot}"
LOG="${RUNNER_TEMP:-/tmp}/import.log"

"$GODOT" --headless --import --path . 2>&1 | tee "$LOG"

errors=$(grep -c 'Parse Error\|SCRIPT ERROR' "$LOG")
if [ "$errors" -gt 0 ]; then
	if [ "$ALLOW_ERRORS" -eq 1 ]; then
		echo "::warning title=Import was noisy::$errors parse error line(s), allowed for this job."
		exit 0
	else
		echo "::error title=The project does not parse::$errors parse error line(s) during import."
		grep -n 'Parse Error\|SCRIPT ERROR' "$LOG" | head -20
		exit 1
	fi
fi

echo "Import clean."
