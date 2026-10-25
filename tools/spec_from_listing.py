#!/usr/bin/env python3
"""Turn what PixelLab's get_character prints into a spec for pack_strips.py.

    tools/spec_from_listing.py <hero id> < listing.txt > spec.json

It reads the `animations` block of the listing: a line per animation, its
name first (`idle — 3 dir ...`), and under it a line per direction with the
frame URL and the frames it runs to (`south: https://.../{i}.png?t=... (i=0..3)`).
South is the hero's `down` facing, north `up`, and east `side`.
"""
import json
import re
import sys

hero = sys.argv[1]
anims = {}
current = None
for line in sys.stdin:
    head = re.match(r"^\s{2}(\w+) — ", line)
    if head:
        current = head.group(1)
        anims[current] = {}
        continue
    frame = re.match(r"^\s{4}(south|east|north|west): (\S+) \(i=0\.\.(\d+)\)", line)
    if frame and current is not None:
        anims[current][frame.group(1)] = frame.group(2)
        anims[current]["frames"] = int(frame.group(3)) + 1
json.dump({"id": hero, "faces": {"down": "south", "up": "north", "side": "east"}, "animations": anims}, sys.stdout, indent=2)
print()
