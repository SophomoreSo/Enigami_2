#!/usr/bin/env bash
# Run Enigami's test scenes and report honestly.
#
# Every test scene prints `[TAG] ---- N failures ----` and quits with 0 or 1.
# That exit code is the primary verdict, but it is not the only way a run can
# go wrong, so this also catches the two silent ones:
#
#   * a scene that hangs — the graphics tests do exactly this under --headless,
#     waiting forever for a window that never comes. Without a per-test timeout
#     a CI job sits there until the six-hour ceiling. Here it is a failure.
#   * a scene that dies before it finishes — exits 0, prints no summary. If the
#     script has a summary line in it and the run did not print one, that run
#     did not reach the end.
#
# Usage:
#   tests/run.sh [options] <dir-or-scene>...
#
#   --display           run with a window (graphics tests need one; default is --headless)
#   --timeout N         seconds allowed per scene (default 180)
#   --log-dir DIR       per-scene logs, for CI to upload (default .test-logs)
#   --quarantine FILE   known failures that report but do not fail the run
#                       (default tests/quarantine.txt; pass "" for none)
#   --exclude GLOB      skip scenes whose path matches; repeatable
#   --strict            also fail on SCRIPT ERROR lines, not just assertions
#   --godot PATH        the binary to use (default $GODOT, else `godot`)
#   --live-save         run against the desk's own save and settings. By default
#                       HOME is pointed at .test-home/ in the project, so a test's
#                       reset_profile() lands there and never on the slot you play
#
# $GODOT_ARGS is appended to every godot invocation, for the things a CI box
# needs and a desk does not (`--audio-driver Dummy`, say).
#
# Exits 0 only if every scene passed or was quarantined.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

GODOT="${GODOT:-godot}"
HEADLESS=1
TIMEOUT=180
LOG_DIR=".test-logs"
QUARANTINE_FILE="tests/quarantine.txt"
STRICT=0
LIVE_SAVE=0
TARGETS=()
EXCLUDES=()

while [ $# -gt 0 ]; do
	case "$1" in
		--display)    HEADLESS=0; shift ;;
		--timeout)    TIMEOUT="$2"; shift 2 ;;
		--log-dir)    LOG_DIR="$2"; shift 2 ;;
		--quarantine) QUARANTINE_FILE="$2"; shift 2 ;;
		--exclude)    EXCLUDES+=("$2"); shift 2 ;;
		--strict)     STRICT=1; shift ;;
		--live-save)  LIVE_SAVE=1; shift ;;
		--godot)      GODOT="$2"; shift 2 ;;
		-h|--help)    sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
		-*)           echo "run.sh: unknown option $1" >&2; exit 2 ;;
		*)            TARGETS+=("$1"); shift ;;
	esac
done

if [ ${#TARGETS[@]} -eq 0 ]; then
	echo "run.sh: nothing to run. Give it a directory or a .tscn." >&2
	exit 2
fi

command -v "$GODOT" >/dev/null 2>&1 || { echo "run.sh: no godot at '$GODOT'" >&2; exit 2; }

# Thirty-odd scenes call GameState.reset_profile(), and Godot keeps user:// under
# $HOME — so run as they were, the tests overwrote the save and the settings of
# whoever ran them. A HOME of the project's own keeps every run out of the desk's
# files, and keeps what a run wrote (user://shots, say) where it can be found.
# XDG_DATA_HOME would send a Linux box somewhere else; it goes with it.
if [ "$LIVE_SAVE" -eq 0 ]; then
	export HOME="$PROJECT_ROOT/.test-home"
	unset XDG_DATA_HOME XDG_CONFIG_HOME XDG_CACHE_HOME
	mkdir -p "$HOME"
fi

# Collect scenes, in a stable order so two runs are comparable.
SCENES=()
for t in "${TARGETS[@]}"; do
	if [ -d "$t" ]; then
		while IFS= read -r s; do SCENES+=("$s"); done < <(find "$t" -name '*.tscn' | sort)
	elif [ -f "$t" ]; then
		SCENES+=("$t")
	else
		echo "run.sh: no such scene or directory: $t" >&2
		exit 2
	fi
done

# The screenshot scenes are the reason this exists: they assert nothing, and
# they wait on `frame_post_draw`, which a compositor is free to stop sending to
# a window nobody is looking at. Useful output, wrong thing to gate a build on.
if [ ${#EXCLUDES[@]} -gt 0 ]; then
	KEPT=()
	for s in "${SCENES[@]}"; do
		skip=0
		for glob in "${EXCLUDES[@]}"; do
			# shellcheck disable=SC2053  # glob on the right is the point
			[[ "$s" == $glob ]] && { skip=1; break; }
		done
		[ "$skip" -eq 0 ] && KEPT+=("$s")
	done
	SCENES=("${KEPT[@]}")
fi

if [ ${#SCENES[@]} -eq 0 ]; then
	echo "run.sh: every scene was excluded." >&2
	exit 2
fi

QUARANTINED=""
if [ -n "$QUARANTINE_FILE" ] && [ -f "$QUARANTINE_FILE" ]; then
	QUARANTINED=$(grep -v '^[[:space:]]*#' "$QUARANTINE_FILE" | grep -v '^[[:space:]]*$')
fi

is_quarantined() {
	[ -n "$QUARANTINED" ] && printf '%s\n' "$QUARANTINED" | grep -qxF "$1"
}

# A timeout that does not need GNU coreutils, because macOS has no `timeout`
# and this script is the same one people run locally.
run_with_timeout() {
	local secs="$1"; shift
	"$@" &
	local pid=$!
	( sleep "$secs"; kill -9 "$pid" 2>/dev/null ) &
	local watcher=$!
	wait "$pid" 2>/dev/null
	local code=$?
	kill -9 "$watcher" 2>/dev/null
	wait "$watcher" 2>/dev/null
	return $code
}

mkdir -p "$LOG_DIR"
ARGS=(--path "$PROJECT_ROOT")
[ "$HEADLESS" -eq 1 ] && ARGS+=(--headless)
# shellcheck disable=SC2206  # word splitting is the point
[ -n "${GODOT_ARGS:-}" ] && ARGS+=(${GODOT_ARGS})

printf '%-44s %-9s %9s %8s  %s\n' SCENE VERDICT FAILURES SECONDS NOTE
printf '%s\n' "------------------------------------------------------------------------------------------"

passed=0; failed=0; quarantined=0
FAILED_SCENES=()
FAILED_LOGS=()
SUMMARY_ROWS=()

for scene in "${SCENES[@]}"; do
	log="$LOG_DIR/$(echo "${scene%.tscn}" | tr '/' '_').log"
	start=$(date +%s)
	run_with_timeout "$TIMEOUT" "$GODOT" "${ARGS[@]}" "res://$scene" >"$log" 2>&1
	code=$?
	secs=$(( $(date +%s) - start ))

	summary=$(grep -o -- '---- [0-9][0-9]* failures ----' "$log" | tail -1 | grep -o '[0-9][0-9]*')
	script_errors=$(grep -c 'SCRIPT ERROR:' "$log")
	expects_summary=0
	[ -f "${scene%.tscn}.gd" ] && grep -q -- '---- %d failures ----' "${scene%.tscn}.gd" && expects_summary=1

	verdict=PASS
	note=""
	if [ "$code" -eq 137 ] || [ "$code" -eq 124 ]; then
		verdict=TIMEOUT
		note="killed after ${TIMEOUT}s — hung, never quit"
	elif [ "$code" -ne 0 ]; then
		verdict=FAIL
		note="exit $code"
	elif [ "$expects_summary" -eq 1 ] && [ -z "$summary" ]; then
		verdict=FAIL
		note="no summary printed — died before the end"
	elif [ -n "$summary" ] && [ "$summary" -gt 0 ]; then
		# Belt and braces: a scene that counts failures but still exits 0.
		verdict=FAIL
		note="$summary failing assertion(s), but exited 0"
	elif [ "$STRICT" -eq 1 ] && [ "$script_errors" -gt 0 ]; then
		verdict=FAIL
		note="$script_errors SCRIPT ERROR line(s)"
	elif [ "$script_errors" -gt 0 ]; then
		note="$script_errors SCRIPT ERROR line(s), not fatal"
	fi

	if [ "$verdict" != PASS ] && is_quarantined "$scene"; then
		note="known failure, quarantined${note:+ — $note}"
		verdict=QUARANTINE
	fi

	case "$verdict" in
		PASS)       passed=$((passed + 1)) ;;
		QUARANTINE) quarantined=$((quarantined + 1)) ;;
		*)          failed=$((failed + 1)); FAILED_SCENES+=("$scene"); FAILED_LOGS+=("$log") ;;
	esac

	printf '%-44s %-9s %9s %8s  %s\n' "$scene" "$verdict" "${summary:--}" "$secs" "$note"
	SUMMARY_ROWS+=("| \`$scene\` | $verdict | ${summary:--} | ${secs}s | $note |")
done

echo
echo "$passed passed, $failed failed, $quarantined quarantined  (logs in $LOG_DIR/)"
if [ ${#FAILED_SCENES[@]} -gt 0 ]; then
	echo
	echo "Failed:"
	for fs in "${FAILED_SCENES[@]}"; do echo "  $fs"; done

	# The per-scene log is where the diagnosis lives, and it reaches a person
	# only if the artifact survives — which in the first CI run it did not. So
	# put the end of it in the run's own output as well, where nothing can drop
	# it. A crash prints its backtrace here; an assertion prints what it wanted.
	for i in "${!FAILED_SCENES[@]}"; do
		fs="${FAILED_SCENES[$i]}"
		fl="${FAILED_LOGS[$i]}"
		echo
		[ -n "${GITHUB_ACTIONS:-}" ] && echo "::group::last 60 lines — $fs"
		echo "----- $fl -----"
		tail -60 "$fl" 2>/dev/null || echo "(no log)"
		[ -n "${GITHUB_ACTIONS:-}" ] && echo "::endgroup::"
	done
fi

# A readable table on the run's summary page, when there is one.
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
	{
		echo "### $passed passed · $failed failed · $quarantined quarantined"
		echo
		echo "| Scene | Verdict | Failures | Time | Note |"
		echo "|---|---|---|---|---|"
		printf '%s\n' "${SUMMARY_ROWS[@]}"
	} >> "$GITHUB_STEP_SUMMARY"
fi

[ "$failed" -eq 0 ]
