#!/usr/bin/env bash
# Fetch godot-sqlite's binaries from the release bin/ was taken from.
#
# The desktop and Android libraries are committed, so a fresh checkout opens,
# tests and exports without running this. The iOS ones are not: the static
# libraries and the godot-cpp archives they depend on come to 280MB, for a
# platform that is not built until there is a team id to sign with. CI runs
# this before an iOS export, and so does anyone exporting one at a desk.
#
# Usage:
#   addons/godot-sqlite/fetch.sh ios     the iOS xcframeworks (gitignored)
#   addons/godot-sqlite/fetch.sh web     the web builds (gitignored; no preset today)
#   addons/godot-sqlite/fetch.sh all     everything the release carries
#
# VERSION must stay the one README.md here names: mixing releases mixes
# godot-cpp versions, and a library built against a newer engine will not load.

set -euo pipefail

VERSION="v4.7"
URL="https://github.com/2shady4u/godot-sqlite/releases/download/${VERSION}/bin.zip"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WHAT="${1:-ios}"

case "$WHAT" in
	ios) PATTERNS=('bin/libgdsqlite.ios.*' 'bin/libgodot-cpp.ios.*') ;;
	web) PATTERNS=('bin/libgdsqlite.web.*') ;;
	all) PATTERNS=('bin/*') ;;
	*)   echo "fetch.sh: ios, web or all — not '$WHAT'" >&2; exit 2 ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Fetching godot-sqlite $VERSION ($WHAT)…"
curl -fsSL -o "$TMP/bin.zip" "$URL"
( cd "$TMP" && unzip -q -o bin.zip "${PATTERNS[@]}" )
mkdir -p "$HERE/bin"
cp -R "$TMP/bin/." "$HERE/bin/"
echo "Now in $HERE/bin:"
( cd "$HERE/bin" && ls -d libgdsqlite.* libgodot-cpp.* 2>/dev/null )
