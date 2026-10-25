# Sprite credits

`dungeon_atlas.png` is taken unmodified from **16x16 DungeonTileset II v1.7**
by **0x72**, as is the tile table in `graphics/atlas/dungeon_atlas_frames.gd`.

- Source: https://0x72.itch.io/dungeontileset-ii
- Licence: **CC0 1.0 Universal** (public domain dedication) — the author states
  "You can use this tileset for whatever you like (CC-0). Credit is not
  necessary." It is given here anyway.

`DungeonAtlasFrames.TILE_LIST` is the pack's own `tile_list_v1.7` verbatim: one
line per tile, `name x y width height`. `graphics/sprites.gd` parses it at
boot and slices the atlas into `AtlasTexture` frames, so no per-frame files are
stored. It sits in a script rather than beside the atlas because Godot leaves
plain text files out of an exported build unless a preset filters them in.

Only a handful of the 370 tiles are used. Which tile stands for each monster
and each weapon is a look rather than a fact about the atlas, so it lives in
`graphics/style.gd`: `Style.MONSTER` and `Style.WEAPON`.

## The player

`player/` is the game's own: a dark-plate figure with a cape and cyan circuit
glow, drawn for Enigami. It is not cut from the atlas but drawn the map way —
a skin, a map, and poses painted in the map's colours (see `player/README.md`).

The technique is **aarthificial's**, from the gist
https://gist.github.com/aarthificial/a77bf477c6bfa51507ffc1e8f18c5635 (MIT,
copyright (c) 2023 aarthificial). `graphics/skin/` is a port of it to Godot:
`PixelMap` is his `PixelMap` and `TexturePostprocessor` — the map's lookup, and
the encoding of a painted frame into skin coordinates — done as the strips load
rather than on import, and `skin_sprite.gdshader` is the lookup on the GPU.
