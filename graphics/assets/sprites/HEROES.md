# The heroes' sprites

Each of the four heroes (`data/db/heroes/heroes.sql`) is drawn from a folder
of their own here, `graphics/assets/sprites/<id>/` — a sprite sheet an
animation, painted straight in its own colours, made with PixelLab from the
hero's reference sprite and dropped in. With the folder there, the hero is
played as it, their face is drawn from it on the bench's screen and in the
dialogue box; until it is there they are played as the player's own art, with
the atlas character the roster names standing in for their face.

```
graphics/assets/sprites/legna_dennis/legna_dennis.idle.png
graphics/assets/sprites/legna_dennis/legna_dennis.run.png
...                                                       a strip an animation
```

After dropping a folder in, run the editor or `godot --headless --path . --import`
once so the files are imported, and the hero is there.

## The frame

- **Square frames, side by side in one row.** The loader reads the frame's
  side off the idle strip's height, so a strip of 6 frames at 48 is 288 by
  48. Every strip of a hero is frames of that one size.
- **Feet on the same row in every frame, facing right.** The feet are read
  off the first idle frame — its lowest drawn row is put on the floor — so
  every other frame keeps its feet on that row. The game flips the sprite to
  face left.
- **How tall.** The rooms are built for a body about a floor cell tall (16
  pixels of art): a figure of 26 to 40 pixels stands one to two and a half
  cells, and a crouch should fit a cell. The sprite is drawn at twice its
  size.
- **Transparent background, no anti-aliasing**, pixel-perfect.

## The animations

A strip is `<id>.<animation>.png`, one per row of this table. A strip left
out is not an animation of the hero, and the game falls back to idle for it.

| Strip | What it shows | Rate | Loops |
|---|---|---|---|
| `idle` | standing at rest, breathing | 5 a second | yes |
| `run` | a running cycle | 12 a second | yes |
| `crouch` | crouched low, shifting a little | 3 a second | yes |
| `hit` | flinching from a blow | 8 a second | no |
| `rise` | going up off a jump | 10 a second | no |
| `fall` | falling | 6 a second | yes |
| `wall_slide` | back to a wall on the facing side, sliding down it | 6 a second | yes |
| `dash` | a dash, stretched long and low | 20 a second | no |
| `hang` | hanging from a rope by one fist straight over the head, the fist on the frame's middle column — the rope's line runs into it, and how high it is over the body's middle is the roster's `hands`: twice its pixels above the feet, less 15 | — | — |
| `climb_up` | climbing up a rope hand over hand, both hands on the frame's middle column, legs round the rope; played while the hands go up it | 8 a second | yes |
| `climb_down` | climbing down a rope hand under hand, the same way | 8 a second | yes |
| `sit` | sitting on a bench, on a seat 4 pixels off the floor | — | — |

The rates are `SkinnedCharacter.ANIMS` (graphics/skin/skinned_character.gd).
The loader takes however many frames a strip has.

## Making them

From here on a hero's strips are rendered from a 3D character: a mesh made
by Meshy AI, rigged in Blender to the skeleton of NVIDIA Kimodo's generated
motion, cleaned up in Cascadeur, and rendered side on in a pixel look into
this folder. That is the four folders beside the checkouts, `Meshy`,
`Blender`, `Kimodo` and `Cascadeur` in `WIPGames/Enigami/` (`PIPELINE.md`
there), one a step; `Blender/run.py render <id> --install` puts the strips
here.

Legna Dennis's present strips were made with PixelLab from her reference
sprite: a character rotated from it (`create_character`, v3, side view),
each clip animated on its east direction, and the frames packed into strips
here with the feet on one row. Who each hero is, in words for a tool, is the
roster's `prompt`.
