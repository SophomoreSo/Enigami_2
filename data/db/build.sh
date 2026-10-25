#!/usr/bin/env bash
# Build data/enigami.db from the SQL in this folder.
#
# schema.sql first, then every .sql in the folders beside it (dialogue/…) in
# path order, all in one transaction with foreign keys on — so a line that
# leads to a line that does not exist, or names an emotion nobody draws, is a
# failed build here rather than a conversation cut short in front of a
# player, and a broken seed leaves no database behind rather than half of one.
#
# The database is committed, built: the game and the tests read it as it is,
# and nothing at run time needs sqlite3. What is checked in has to be the
# build of what is checked in beside it, so a hash of the sources goes into
# `meta` as `source_hash`, and tests/story/dialogue_test fails when the .sql
# has moved on and this was not run. The recipe is repeated in that test;
# change one, change both.
#
# Usage:
#   data/db/build.sh
#
# Needs the sqlite3 command line: macOS has it, Linux has it as a package
# (`apt install sqlite3`), Windows from https://sqlite.org/download.html.
# $SQLITE names another binary.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/../enigami.db"
TMP="$OUT.building"
SQLITE="${SQLITE:-sqlite3}"

command -v "$SQLITE" >/dev/null 2>&1 || { echo "build.sh: no sqlite3 on PATH (or set \$SQLITE)" >&2; exit 2; }

# The sources, in the order they are read, as paths relative to this folder.
# Byte order rather than the locale's, so the hash is the same on every
# machine — and the same one the test computes.
rels=("schema.sql")
while IFS= read -r f; do
	rels+=("${f#./}")
done < <(cd "$HERE" && find . -mindepth 2 -name '*.sql' | LC_ALL=C sort)

hash_of() {
	if command -v shasum >/dev/null 2>&1; then
		shasum -a 256 | cut -d' ' -f1
	else
		sha256sum | cut -d' ' -f1
	fi
}

rm -f "$TMP"
{
	echo "PRAGMA foreign_keys = ON;"
	echo "BEGIN;"
	for rel in "${rels[@]}"; do
		echo "-- ---- $rel"
		cat "$HERE/$rel"
		echo
	done
	echo "COMMIT;"
} | "$SQLITE" -bail "$TMP"

# Belt and braces: the deferred constraints were checked at COMMIT above, and
# this asks again in a way that prints what is wrong rather than one line.
broken="$("$SQLITE" "$TMP" "PRAGMA foreign_key_check;")"
if [ -n "$broken" ]; then
	echo "build.sh: foreign keys broken (table, rowid, parent, index):" >&2
	echo "$broken" >&2
	rm -f "$TMP"
	exit 1
fi
ok="$("$SQLITE" "$TMP" "PRAGMA integrity_check;")"
if [ "$ok" != "ok" ]; then
	echo "build.sh: integrity_check said: $ok" >&2
	rm -f "$TMP"
	exit 1
fi

listing=""
for rel in "${rels[@]}"; do
	listing+="$rel"$'\n'"$(hash_of < "$HERE/$rel")"$'\n'
done
source_hash="$(printf '%s' "$listing" | hash_of)"
"$SQLITE" "$TMP" "INSERT OR REPLACE INTO meta (key, value) VALUES ('source_hash', '$source_hash'); VACUUM;"

mv -f "$TMP" "$OUT"
echo "Built $(basename "$OUT") from ${#rels[@]} file(s) — $(du -h "$OUT" | cut -f1), sources ${source_hash:0:12}"
"$SQLITE" "$OUT" "SELECT '  ' || character_id || ' talks free: ' || count(*) || ' rules, ' || (SELECT count(*) FROM criteria c WHERE c.character_id = r.character_id) || ' criteria, ' || (SELECT count(*) FROM changes c WHERE c.character_id = r.character_id) || ' changes' FROM rules r GROUP BY character_id ORDER BY character_id;"
"$SQLITE" "$OUT" "SELECT '  ' || id || ': ' || (SELECT count(*) FROM nodes WHERE character_id = characters.id) || ' lines, ' || (SELECT count(*) FROM choices WHERE character_id = characters.id) || ' answers' FROM characters ORDER BY id;"
"$SQLITE" "$OUT" "SELECT '  ' || id || ' machine: ' || (SELECT count(*) FROM states WHERE machine_id = machines.id) || ' states, ' || (SELECT count(*) FROM steps WHERE machine_id = machines.id) || ' steps, ' || (SELECT count(*) FROM conditions WHERE machine_id = machines.id) || ' conditions, ' || (SELECT count(*) FROM transitions WHERE machine_id = machines.id) || ' ways' FROM machines ORDER BY id;"
"$SQLITE" "$OUT" "SELECT '  ' || (SELECT count(*) FROM parts) || ' parts, ' || (SELECT count(*) FROM effects) || ' effects, ' || (SELECT count(*) FROM inversions) || ' opposites, ' || (SELECT count(*) FROM codes) || ' numbers given out; ' || (SELECT count(*) FROM boards) || ' boards, ' || (SELECT count(*) FROM board_parts) || ' parts placed on them';"
"$SQLITE" "$OUT" "SELECT '  ' || (SELECT count(*) FROM menus) || ' menus, ' || (SELECT count(*) FROM menu_items) || ' items on them';"
"$SQLITE" "$OUT" "SELECT '  ' || (SELECT count(*) FROM foliage) || ' kinds of foliage, ' || (SELECT count(*) FROM growths) || ' grown in the rooms';"
"$SQLITE" "$OUT" "SELECT '  ' || (SELECT count(*) FROM lights) || ' kinds of light: ' || group_concat(n || ' ' || type, ', ') FROM (SELECT type, count(*) AS n FROM lights GROUP BY type ORDER BY type);"
"$SQLITE" "$OUT" "SELECT '  ' || (SELECT count(*) FROM maps) || ' maps, ' || (SELECT count(*) FROM map_layers) || ' layers, ' || (SELECT count(*) FROM map_rows) || ' rows of cells';"
"$SQLITE" "$OUT" "SELECT '  the raid: ' || count(*) || ' rooms, ' || (SELECT count(*) FROM raid_rooms WHERE exit IS NOT NULL) || ' with a way out' FROM raid_rooms;"
"$SQLITE" "$OUT" "SELECT '  ' || count(*) || ' sounds in the bank, ' || sum(use_flag = 'Y') || ' played from a file' FROM sounds;"
"$SQLITE" "$OUT" "SELECT '  ' || count(*) || ' heroes to play as' FROM heroes;"
