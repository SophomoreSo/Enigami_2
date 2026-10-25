# The player, drawn the map way

The player is not cut from the atlas. It is this folder: a character drawn
once, and poses that say where each of its pixels goes. The idea is
[aarthificial's](https://gist.github.com/aarthificial/a77bf477c6bfa51507ffc1e8f18c5635);
the port is `graphics/skin/`.

```
player.skin.png     what the pixels look like — the character, once, in one 20×24 frame
player.map.png      a colour of its own for every skin pixel. Made once, then kept.
player.idle.png     the poses: one strip per animation, frames the skin's size side by
player.run.png      side, every pixel painted not in a colour but in the map's colour
player.dash.png     of the skin pixel it stands for
player.hit.png
player.sit.png      sitting on a bench, on a seat four pixels off the floor (`BenchView.SEAT`)
```

It is drawn side on, so it shows for every way the body faces, mirrored for
the left (`ActorView`). It is the art the player is played as until the hero
picked has a folder of their own, in the four facings
(`graphics/assets/sprites/HEROES.md`).

At load, `SkinnedCharacter` turns each strip into what `skin_sprite.gdshader`
reads — red and green name a skin pixel — and the shader takes the colour from
the skin. Nothing is baked: the PNGs here are the source and the asset.

## To reskin

Edit `player.skin.png`. That is all. Every frame of every pose takes its
colours from it, so a new plate, a new cape or a lit visor is one file. Keep
the size, and keep every pixel that is drawn drawn: a frame naming a pixel
that went transparent draws nothing there.

## To change a pose, or add one

Open the strip beside `player.map.png` and paint with the map's colours — the
eyedropper is the whole tool. A pixel painted in a colour the map does not have
is dropped with a warning; check a folder before committing it with

```bash
godot --headless --path . --script graphics/skin/pixel_map_tool.gd -- check res://graphics/assets/sprites/player
```

A new animation is a new strip, `player.<name>.png`, a line for how it plays
in `SkinnedCharacter.ANIMS`, and a case in `PlayerView._animate` that asks for
it. A strip that is not there is not an animation of the character;
`ActorView.play` falls back to idle.

## To make a character painted straight

A folder with the strips alone — `<name>.<anim>.png`, each a row of square
frames in their own colours, no skin and no map — is a character too
(`SkinnedCharacter`, "painted"): drawn as it is, with no reskinning. That is
what a sprite sheet made outside the game is, as the heroes' are; the frame,
the strips and what each shows are in `../HEROES.md`.

## To make a new character this way

Draw `<name>.skin.png` in `graphics/assets/sprites/<name>/`, then

```bash
godot --headless --path . --script graphics/skin/pixel_map_tool.gd -- map res://graphics/assets/sprites/<name>/<name>.skin.png
```

writes the map. Paint the strips in it, and name the character wherever an
atlas character is named: `Style`, a dialogue file's `sprite`, a scene's cast.
`Sprites` answers for both kinds.

The map is made once and kept: frames are painted in it, and a remade map
would make every one of them name the wrong pixel. Redrawing the skin so that
new pixels are drawn means giving the map colours for them — `--force` remakes
it, and then every strip is repainted.

## The rules the loader holds you to

- The map is the skin's size, and every strip is a row of frames that size.
- A skin is at most 256 pixels a side: the shader carries a coordinate in a byte.
- The first idle frame is where the feet are read from: its lowest drawn row
  is put on the floor.
