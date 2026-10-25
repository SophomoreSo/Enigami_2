# The game's own tiles

Each folder is one Wang tileset made with PixelLab (`create_topdown_tileset`,
`mode: pro`, 16 px tiles, `view: low top-down`, the view the heroes are drawn
in), kept as it came: `sheet.png`, the tiles in a grid, and `tiles.json`, the
metadata that says what each tile of the sheet is — its slice of it
(`bounding_box`), its four corners (`corners`) and, for a set with walls, the
4x4 pattern of terrain round it (`pattern_4x4`). `graphics/tiles/terrain_tiles.gd`
reads them and picks a tile for every cell; `graphics/tiles/map_tiles.gd` says
which set draws which place.

A set holds two terrains. A **wall set** (25 tiles, `transition_size: 1.0`) is
a floor and a wall standing on it, with the wall's front face between; a **pit
set** (16 tiles, `transition_size: 0.25`, a cliff) is a pit's dark and the
floor round it. A tileset of the game's is a wall set and, where its floor can
have pits, a pit set that shares the floor — the pit set's upper terrain was
made from the wall set's lower base tile (`upper_base_tile_id`), so the two
floors are one.

| Folder | PixelLab id | Lower → upper |
|---|---|---|
| `rock_walls` | `b9c1c0d3-3490-48c6-99f1-5925b35c8dd8` | dark dungeon floor of worn grey flagstones → rough grey cave rock wall of cut stone blocks |
| `rock_pits` | `dc803437-cb82-4cb0-a6e4-53d262b98cbd` | bottomless pit, black with a crumbling stone edge → the same floor |
| `grove_walls` | `7e81814e-5917-4a0e-8d60-74090107ef96` | mossy forest floor of dark earth, moonlit → ancient ruined stone wall under moss and ivy |
| `grove_pits` | `77789c2e-1505-46e7-bb8a-a026c28495c7` | deep dark hole in the earth with roots → the same floor |
| `keep_walls` | `27fceb13-6752-43eb-a894-7b13e7a2e476` | swept flagstone floor of a hideout hall → dark brick wall with lanterns in its face |

Made on 2026-10-25 under the project's PixelLab subscription; PixelLab's terms
(https://pixellab.ai/termsofservice) govern their use. To make another: ask
for the set, `get_topdown_tileset` for its download links once it is done,
and put its `image?inline=true` and `metadata` here as `sheet.png` and
`tiles.json` under a folder named `<tileset id>_walls` or `<tileset id>_pits`.
