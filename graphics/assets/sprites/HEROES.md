# The heroes' sprites

Each of the four heroes (`data/db/heroes/heroes.sql`) is drawn from a folder
of their own here, `graphics/assets/sprites/<id>/` — a sprite sheet an
animation a facing, painted straight in its own colours, made with PixelLab
from the hero's reference and dropped in. With the folder there, the hero is
played as it, their face is drawn from it on the bench's screen and in the
dialogue box; until it is there they are played as the player's own art, with
the atlas character the roster names standing in for their face.

```
graphics/assets/sprites/legna_dennis/legna_dennis.idle.down.png
graphics/assets/sprites/legna_dennis/legna_dennis.idle.up.png
graphics/assets/sprites/legna_dennis/legna_dennis.idle.side.png
graphics/assets/sprites/legna_dennis/legna_dennis.walk.down.png
...                                               a strip an animation a facing
```

After dropping a folder in, run the editor or `godot --headless --path . --import`
once so the files are imported, and the hero is there.

## The facings

The game is seen from above and a little in front, so a body has four ways to
face and three to draw: `down` the screen, toward whoever is looking; `up` it,
away; and `side`, to the right, which the game mirrors for the left
(`Actor.facing_name`, `ActorView`). A body walking a diagonal shows its side.
A strip with no facing in its name, `<id>.<anim>.png`, is taken as drawn side
on and shown for every facing, mirrored for the left — that is how the
player's own art and the atlas's characters are drawn.

The down facing of an animation also answers to the plain name — `idle` is
`idle.down` — for whatever draws a face with no body to face by: the portrait
on a hero's card and in the dialogue box.

## The frame

- **Square frames, side by side in one row.** The loader reads the frame's
  side off the idle strip's height, so a strip of 4 frames at 48 is 192 by
  48. Every strip of a hero is frames of that one size.
- **Feet on the same row in every frame and every facing.** The feet are
  read off the first idle frame of the down facing — its lowest drawn row is
  put on the floor, which is the body's position — so every other frame of
  every facing keeps its feet on that row. `tools/pack_strips.py` lines them
  up.
- **How tall.** The rooms are built for a body about a floor cell tall (16
  pixels of art, drawn at twice its size): a figure of 26 to 40 pixels
  stands one to two and a half cells.
- **Transparent background, no anti-aliasing**, pixel-perfect.

## The animations

A strip is `<id>.<animation>.<facing>.png`, one per row of this table per
facing. A strip left out is not an animation of the hero, and the game falls
back to idle for it.

| Strip | What it shows | Rate | Loops |
|---|---|---|---|
| `idle` | standing at rest, breathing | 5 a second | yes |
| `walk` | a walking cycle | 10 a second | yes |
| `dash` | a dash, stretched long and low | 20 a second | no |
| `hit` | flinching from a blow | 8 a second | no |
| `cast` | a cast: an arm thrust out, the hand open | 10 a second | no |
| `sit` | sitting on a bench, on a seat 4 pixels off the floor | — | — |

The rates are `SkinnedCharacter.ANIMS` (graphics/skin/skinned_character.gd).
The loader takes however many frames a strip has.

## Making them

With PixelLab (the `pixellab` MCP tools), from the hero's reference:

1. `create_character` in v3 with the reference as `reference_image_url`,
   `view` "low top-down", `n_directions` 4 — south, east, north and west,
   of which the game uses three. Who each hero is, in words for the tool, is
   the roster's `prompt`.
2. `animate_character` for each row of the table, `directions` south, east
   and north: `breathing-idle` for the idle, `walking` for the walk,
   `taking-punch` for the hit and `fireball` for the cast as template
   animations; the dash and the sit as v3 custom animations of four frames
   with `keep_first_frame` false.
3. `tools/pack_strips.py` with a spec naming the frame URLs `get_character`
   prints, into this folder: south is `down`, north is `up`, east is `side`.

Legna Dennis's strips were made that way from the south rotation of her
earlier side-view character. The other three were drawn by `create_character`
in v3 from their prompts alone, 48 pixels, and animated the same way; their
frames come at 68. `tools/spec_from_listing.py` turns what `get_character`
prints into the spec `pack_strips.py` reads.

| Hero | PixelLab character |
|---|---|
| Legna Dennis | `70f26012-1d54-494f-8380-1a4433459e48` |
| Dren Repus | `3fae2840-9e3b-4a36-9238-c547d5958c8f` |
| Reniart Lamina | `237da68f-2cc3-4f18-9aa8-a07978b3aa9b` |
| Sett Eragic | `f7a0125d-eb59-4eed-bb6e-9158e5ac1524` |
