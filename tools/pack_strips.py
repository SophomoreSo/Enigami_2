#!/usr/bin/env python3
"""Pack a PixelLab character's animation frames into the strips the game reads.

A hero's folder under graphics/assets/sprites/<id>/ holds one strip an
animation a facing, `<id>.<anim>.<face>.png`: square frames side by side,
the frame's side the strip's height, the feet on the same row in every frame
(graphics/assets/sprites/HEROES.md). PixelLab hands back a frame a PNG, a
folder a direction, on the character's own canvas (32x48, say). This fetches
them, lays each frame on a square canvas, lines the feet up, and writes the
strips.

    tools/pack_strips.py <spec.json> <out dir>

The spec names the hero and, per animation, the PixelLab frame URLs by
direction, as get_character prints them, with `{i}` where the frame number
goes and the frame count beside it:

    {
      "id": "legna_dennis",
      "faces": {"down": "south", "up": "north", "side": "east"},
      "animations": {
        "idle": {"frames": 4, "south": "https://.../south/{i}.png?t=...", ...},
        ...
      }
    }

Frames are read from `<out dir>/.frames/<anim>/<direction>/<i>.png` when they
are there, and fetched into that folder when they are not, so a second run
costs nothing and a frame drawn over by hand is kept. That folder is Godot's
to ignore (a `.gdignore` is written into it) and git's (`.gitignore`).

The baseline every frame is stood on is the lowest drawn row of the down
idle's first frame, on the square canvas, for every facing; a frame whose lowest drawn row
is elsewhere is shifted to it, so a clip drawn on a bigger canvas stands on
the same feet. Pass `--no-align` to keep PixelLab's rows as they are.
"""

import json
import os
import subprocess
import sys
import urllib.request

from PIL import Image


def fetch(url: str, path: str) -> Image.Image:
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        try:
            with urllib.request.urlopen(url, timeout=60) as r, open(path, "wb") as f:
                f.write(r.read())
        except Exception:
            # A Python with no certificates of its own: curl has the system's.
            subprocess.run(["curl", "-sfL", url, "-o", path], check=True)
    return Image.open(path).convert("RGBA")


def lowest_row(im: Image.Image) -> int:
    """The bottom-most row with anything drawn in it, or -1 for an empty frame."""
    bbox = im.getbbox()
    return -1 if bbox is None else bbox[3] - 1


def square(im: Image.Image, side: int, shift: int) -> Image.Image:
    """`im` on a transparent `side` by `side` canvas, centred across, its bottom
    on the canvas's bottom, moved down by `shift` rows (up for a negative)."""
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    x = (side - im.width) // 2
    y = side - im.height + shift
    out.alpha_composite(im, (x, max(y, 0)) if y >= 0 else (x, 0), (0, -y) if y < 0 else (0, 0))
    return out


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    spec = json.load(open(sys.argv[1]))
    out_dir = sys.argv[2]
    align = "--no-align" not in sys.argv
    hero = spec["id"]
    faces = spec["faces"]
    anims = spec["animations"]
    os.makedirs(out_dir, exist_ok=True)
    cache = os.path.join(out_dir, ".frames")
    os.makedirs(cache, exist_ok=True)
    open(os.path.join(cache, ".gdignore"), "a").close()

    # The frames, a list per animation per direction.
    frames = {}
    side = 0
    for anim, a in anims.items():
        frames[anim] = {}
        for face, direction in faces.items():
            if direction not in a:
                continue
            got = []
            for i in range(int(a["frames"])):
                url = a[direction].replace("{i}", str(i))
                got.append(fetch(url, os.path.join(cache, anim, direction, f"{i}.png")))
            frames[anim][face] = got
            for im in got:
                side = max(side, im.width, im.height)
    if side == 0:
        print("nothing to pack", file=sys.stderr)
        return 1

    # The baseline every frame is stood on — the idle's first frame's feet, on
    # the square canvas — and every strip against it, on that canvas too: the
    # clips come on canvases of their own sizes, and only the square they all
    # go on compares.
    # One baseline for every facing: the down idle's, which is what the game
    # stands the sprite by (`Sprites.art_rect`), so a body turning does not
    # step up or down a pixel.
    first = "down" if "down" in frames.get("idle", {}) else next(iter(frames.get("idle", {})), None)
    for face in faces:
        if "idle" not in frames or face not in frames["idle"] or first is None:
            print(f"{hero}: no idle for the {face} facing, so nothing is packed for it", file=sys.stderr)
            continue
        base = lowest_row(square(frames["idle"][first][0], side, 0))
        for anim in anims:
            if face not in frames[anim]:
                continue
            cells = []
            for n, im in enumerate(frames[anim][face]):
                low = lowest_row(square(im, side, 0))
                shift = 0
                if align and low >= 0 and low != base:
                    # The body drawn higher or lower on its canvas than the
                    # idle's is: moved back onto the idle's feet.
                    shift = base - low
                cells.append(square(im, side, shift))
            strip = Image.new("RGBA", (side * len(cells), side), (0, 0, 0, 0))
            for n, cell in enumerate(cells):
                strip.alpha_composite(cell, (n * side, 0))
            name = f"{hero}.{anim}.{face}.png"
            strip.save(os.path.join(out_dir, name))
            rows = sorted({lowest_row(c) for c in cells})
            print(f"{name}: {len(cells)} frames of {side}, feet on row {rows}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
