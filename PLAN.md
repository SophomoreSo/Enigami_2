# Enigami v2: a 2D top-down game, the Hyper Light Drifter way

What has to change to take the present game — a 2D platformer in
`WIPGames/Enigami/` — and make the second one: a 2D game seen from above
and a little in front, drawn in pixel-art sprites, with no 3D model
anywhere in it or behind it. Written 2026-10-25 against the `graphics`
checkout as it stood that day: 125 test files, about 58,000 lines of
GDScript outside the tests, a content database of 41 tables, two
languages, five export targets.

This replaces `Enigami/V2-TRANSITION.md`'s first decision. That document
chose real 3D with an isometric camera and the Meshy–Blender–Kimodo
pipeline feeding GLBs into Godot; the user chose otherwise the same day:
2D, 2D sprites, no 3D models. Everything below assumes that, and where
the two documents differ this one holds.

Three sizes, and a fourth. **Keep** means the code or data comes over
with no more than renamed imports and the odd deleted branch. **Rework**
means the idea and most of the structure survive but the file is
substantially rewritten for a view from above. **New** means nothing
today does the job. **Drop** means it does not come over at all.

The short of it: because v2 is still 2D in Godot, far more carries than
the 3D route allowed. `circuit/`, `story/`, `perks/`, the whole UI, the
pixel camera, the cue and view mechanisms, the database and the tests'
harness all come over. What is rewritten is the vertical axis — jump,
fall, gravity, ropes, wall slides, crouching, gates in the floor — and
the rooms, which become floor plans walked round instead of platforms
jumped across.

---

## 0. What is decided, and what is left open

Decided by the user, 2026-10-25:

1. **2D, with 2D sprites, no 3D models.** No GLB, no `Node3D`, and the
   `Meshy/`, `Blender/`, `Kimodo/`, `Cascadeur/` folders are not the way
   a sprite is made any more.
2. **A new folder, this one**, with a commit for every important step. v1
   stays where it is, with its four checkouts and its CI, unfinished.
   This folder is one repository on one branch until the user says
   otherwise; the worktree rules in `Enigami/CLAUDE.md` are v1's and do
   not apply here.

Fixed here so the work can start, each a one-line change if the user
wants it otherwise:

3. **The view.** Three-quarter top-down, as Hyper Light Drifter: square,
   axis-aligned cells, a floor seen flat, a wall drawn as a top and a
   front one cell tall. Not isometric: no diamond tiles, no 2:1 grid.
   The cell stays 16 art pixels, drawn at 2× (`Sprites.PIXEL_SCALE`),
   so the 1280×720 window shows a 640×360 buffer through the same
   `PixelCamera` as today. Depth is y-sort: everything in a room sorts by
   where its feet are, so a body walks behind a pillar and in front of
   it. Godot's `Node2D.y_sort_enabled` and `TileMapLayer` do this.
4. **Facing.** Four directions — down, up, side — the side mirrored, as
   Hyper Light Drifter draws its Drifter; movement in eight. PixelLab
   makes characters in four or eight, so eight is a later choice, not a
   rewrite.
5. **Height.** None in play at first: no jump, no ledges, no stairs the
   body climbs. A pit, if a room has one, is Hyper Light Drifter's: step
   in, fall, lose a little health, stand again at the edge you left. A
   one-way drop off a ledge is the same mechanism and can come later.
   A lobbed thing — the rock, a Lobber's shot — fakes its arc the way
   every top-down game does: a shadow on the floor, the sprite lifted
   above it by a `height` the rules keep.
6. **The verbs.** Walk, dash (and chain dashes), hit toward the aim, cast
   and charge toward the aim, interact, sit, phone. The skill boards, the
   weapons, the heroes, the pet, the alarm, the raid's loot rule all
   carry; what goes is listed under `feature/` below.
7. **Where the pictures come from.** PixelLab for the heroes (a
   four-direction character from each hero's reference, its animations
   from the skeleton tool), for monsters that need more than the atlas
   gives, for portraits and for the top-down tilesets; 0x72's 16×16
   DungeonTileset II, already in the game under CC0 and itself a
   top-down three-quarter tileset, for monsters, props and the first
   rooms; code (`PixelDraw`) for the UI, as today.

Left to the user:

- The folder's name. `Enigami2` is a placeholder, a `mv` away.
- Which of the five hideout looks, if any, the top-down hideout takes
  after.
- Whether the four 3D pipeline folders beside v1's checkouts are deleted
  or left as a record. Nothing here reads them.

---

## 1. Project and process

| Item | Size | Notes |
|---|---|---|
| New Godot 4.5 project: `project.godot`, autoloads, input map | Rework | the same autoload names (`Loc`, `Db`, `Cues`, `GameState`, `TimeCtl`, `Arena`, `Audio`, `Views`, `Fx`, `CueVisuals`, `Sprites`, `Perks`, …); `gl_compatibility` stays, so mobile keeps every shader it has; the input map loses `jump`, `sprint`'s crouch half and the climb directions, and gains nothing new — `move_up`/`move_down` already exist |
| Repository | New | this folder, `git init`, one branch, `.gitignore` for `.godot/`, `.test-home/`, `.test-logs/`; a commit a step of §13 |
| `Enigami/CLAUDE.md`, memory | Rework | a line in v1's saying v2 lives here and is not one of its checkouts; a memory for the same |
| CI (`.github/workflows/ci.yml`) | Keep | the five jobs carry as they are: rules headless, module split, graphics under Xvfb, the two build jobs; only the test lists change. Nothing 3D under Xvfb, so no Mesa slowdown |
| `export_presets.cfg` | Keep | |
| `README.md`, `ARCHITECTURE.md`, `data/db/README.md`, `localization/README.md` | Rework | "a 2D platformer" becomes "a 2D top-down game"; the module map and the rule are unchanged |
| `.taskmaster/`, `prd.txt`, `AGENTS.md` | Drop | start clean; a v2 PRD if Task Master is wanted again |

## 2. The engine: `circuit/` (2,400 lines)

| Item | Size | Notes |
|---|---|---|
| `Components`, `SkillBoard`, `SkillRunner`, `Payload`, `BoardCode` | Keep | they name nothing of the picture or the physics; 16 tests come with them |
| `parts` table and the parts' effects | Keep | the effects are read in `feature/attacks/`; the two or three that mean "down" (gravity on a bolt, an arc) get the faked-height reading of §0.5 there, not here |

## 3. The rules: `feature/` (14,200 lines, 62 files)

| Item | Size | Notes |
|---|---|---|
| `GameState` (profile, stash, forge, boards, hero, slots, perks hook) | Keep | v1 saves are not loaded; a chance to drop fields |
| `Heroes`, `Monsters.DEX`, `Boards`, `Magic`, `Rune`, `Pool`, `TimeCtl`, `Arena`, `Weapons.DEFS`, `Loadout`, `Charge` | Keep | |
| `Phone` (alarm, photos, lure) | Keep | the lure's reach is already a distance |
| `Actor` (303) | Rework | `facing: int` (a sign) becomes `facing: Vector2` and a `face: int` of the four; `move_and_slide` on the plane with no gravity; the hurt box stays a 2D shape, the collision shape shrinks to the feet |
| `Player` (1,547) | Rework | the largest single rewrite in the rules: `GRAVITY`, `_apply_gravity`, the jump and its buffer, the wall kick, the ledge, the crouch, the whole rope (`_swing`, `_spin`, the hands) go — roughly half the file; walk, dash, sprint, aim, the kit, the cast and charge, interact, sit, possess, the stamina carry |
| The player machine (`Machine`, `FsmNode`, `data/db/machines/player.sql`) | Rework | the mechanism stays; the eight states become: `idle`, `walk`, `dash`, `hurt`, `sit`, and the senses and actions lose `gravity`, `cling`, `jump`, `duck`, `swing`, `leap`; `brake`/`run`/`dash`/`rush` carry |
| `Enemy` (647), the five AIs (`runner`, `turret`, `walker`, `jumper`, `flyer`) | Rework | `runner`, `turret`, `walker` carry as plane movement; `jumper` becomes a lunge on the floor; `flyer` becomes a body with a `height` and a shadow, which only ground attacks miss |
| `Pet` | Keep | follows on the plane already |
| Attacks: `Melee`, `Burst`, `DashSlash`, `Headbutt` | Keep | a melee arc, a circle and a dash are already shapes on a plane and aimed by a `Vector2` |
| `Projectile` (621) | Rework | `gravity` on a bolt becomes the faked arc: a `height` that rises and falls while the body flies straight on the floor; a wall bounce stays a bounce |
| Input: `Hands`, `InputState`, `InputMiddleware`, `WalkTo`, `ComputerHands`, `HandsOff`, `InputProvider` | Keep | `jump` goes from the action list; the stick already gives a `Vector2` |
| `AimAssist`, `AimCurve` | Keep | aiming in 2D from the body toward the pointer or the stick is what they do now |
| `World` | Keep | |
| `Raid`, `RaidMap` (floor of 7×5 rooms, doorways, gates) | Rework | rooms join on all four sides by doorways; the gate — the only way up or down between floors of rooms — goes, and `raid_rooms` is one floor plan reached by walking; `entry`, `boss`, `treasure`, `danger`, the `exit` kinds (`arbiter`, `toll`, `crack`) carry |
| `Room` (958), `HandLaidRoom`, `MadeRoom` | Rework | `W`×`H` of 40×22 cells stays a screen; `solid` becomes a floor plan: floor, wall, pit, prop footprint; `FLOOR_ROW`, `DOOR_ROWS`, `GATE_*` go; a doorway is a gap in any wall; what the room puts down (monsters, boxes, dig spots, benches, pickups) stands at a cell on the floor and carries |
| `Maps`, `MapMaker` (the map creator as a world) | Rework | the three layers (`back`, `plan`, `dressing`) become `floor`, `walls`, `props`, y-sorted; the creator's cursor, brushes, saving as SQL carry |
| `HideoutWorld`, `Station`, `Bench`, `Pickup`, `TreasureBox`, `DigSpot`, `Diamond`, `LostKit`, `PhoneProp` | Keep | each is a thing at a point the player walks up to; "near enough" is already a distance |
| `Gate` | Drop | see `Raid` |
| `HangingRope` | Drop | |
| `LooseRock` (the rock weapon) | Rework | thrown with the faked arc, lies where it lands, picked back up: all of that but the arc carries |
| `FallingThing` | Drop | nothing falls from a ceiling seen from above |
| `StuckShuriken` | Rework | it sticks in a wall or lies on the floor where it stopped; the rule is the same, the wall test is a cell test |
| `Sandbox`, `DragonTower`, `DragonTest`, `JeanGreyTest`, `JeanGreyBase`, `LightingTest` | Rework | the bench's sandbox carries as a flat room; the dragon test's tower is a platformer set piece and goes; the other two are kept only if the user wants them |
| Foliage rules, `VelocityBuffer`'s air | Keep | grass seen from above sways the same way |

## 4. The picture: `graphics/` (30,300 lines, 86 files)

| Item | Size | Notes |
|---|---|---|
| `PixelCamera`, `VelocityBuffer` | Keep | the low-resolution buffer upscaled with a smooth sub-pixel slide is exactly Hyper Light Drifter's camera; a y-sorted world root goes under it |
| `PixelDraw`, `UiKit`, `Style`, every `graphics/ui/*.gd` (skill editor 3,400, title 1,460, map table 1,400, phone, HUD, menus, settings, monster dex, hero select, results, bench drawer, …) | Keep | 15,000 lines of UI that the 3D route would have redrawn; `Style` loses its rope and platform colours and gains the tile names of §4's tilesets |
| `Sprites` (atlas slicing, character frames) | Keep | the atlas is a top-down pack: its monsters face a side and flip, which is how a top-down game draws them; a hero's frames are asked by `(anim, face)` instead of `anim` |
| `SkinnedCharacter`, `PixelMap`, `pixel_map_tool` (the skin-and-map technique) | Keep | `ANIMS` is rewritten (§11); the painted-straight loader learns the four-direction layout; the skin-and-map player art is side-view and is retired in favour of the heroes (`player/` goes, the technique stays for anyone who wants a reskinnable character) |
| `Views` (the watcher), `ActorView`, `PlayerView`, `EnemyView`, `PetView` | Rework | the pattern stays untouched; `PlayerView._animate` maps the new states and `actor.face` to a strip; the view's sprite is offset so the feet sit on the body's origin, which is the y-sort key |
| `ProjectileView`, `MeleeArcView`, `AreaBurstView`, `DashSlashView`, `StuckShurikenView`, `LooseRockView` | Keep | a projectile with a `height` draws its shadow at the origin and its sprite above |
| `PickupView`, `BenchView`, `TreasureBoxView`, `DigSpotView`, `DiamondView`, `LostKitView`, `PhonePropView` | Keep | sprites at a point; each gets a y-sort origin at its base |
| `GateView`, `Rope` (697), `rope.gd` drawing | Drop | |
| `RoomView` (456), `MadeRoomView` (547), `RockTiles`, `GroveTiles`, `MapTiles` (705), `MapCells`, `GroveGroundView` | Rework | the code-drawn rock and grove, side on, go; a room is a `TileMapLayer` per layer (floor, walls, props) on a y-sorted root, its tiles from a `TileSet` built at boot out of the atlas and the PixelLab tilesets; a wall cell paints a top and, where the cell below is floor, a front; autotiling by Godot's terrain sets |
| `RaidView`, `SandboxView`, `MapMakerView`, `TowerView`, the test views | Rework/Drop | `RaidView` and `MapMakerView` carry with the new layers; `TowerView` and `DragonTestView` go with their worlds |
| `HideoutWorldView`, `HideoutScenery`, the five looks (`hideout_brass/keep/grove/city/orbit`, 5,800 lines), `HideoutThemes`, the HIDEOUT THEME page | Drop, then New | the five are side-on pictures drawn in code; the top-down hideout is a tiled interior with the same stations, one look, from a tileset. The user picks which of the five it takes after, if any, and the theme page goes |
| `Lighting` (714, deferred 2D), `Lamp`, `Shine`, `Glass`, `Glazing`, `ShadowCaster`, the light shaders | Rework | a canvas system, so it carries where the 3D route dropped it; what changes is what a shadow is. The wall-figure shadow and the normals from a sprite's edge assume a side view and go; a lamp lights the floor round it, a body gets a blob shadow at its feet drawn by its view, `Glass`/`Glazing` stay as surface effects. If this is more than the look wants, `Lighting` is one `remove_child` away and lamps draw as additive glow |
| `Fx` (shake, sparks, rings, floating numbers, pools), `CueVisuals` | Keep | 2D effects at a point; a cue with a `height` lifts its effect |
| `Foliage` drawing, `foliage.gdshader` | Keep | tufts drawn at a point on the floor, swaying in the velocity buffer; from above they are the same tufts, y-sorted |
| Shaders: `actor_sprite`, `skin_sprite`, `picture_grade`, `glow`, `ambient`, `out_there` | Keep | `figure_shadow`, `bodies`, `shadow`, `light`, `lighting.gdshaderinc` go or shrink with `Lighting` |
| Portraits (dialogue, hero select) | Rework | today cropped from the side-view idle; from the down-facing idle, or a PixelLab portrait per hero (`create_portrait_character`) kept beside the strips |
| `LogoCard`, fonts, logos, `launch_paper.png` | Keep | |

## 5. The telling: `story/` (6,400 lines)

| Item | Size | Notes |
|---|---|---|
| `Dialogue`, `Npc`, `Facts`, `FreeTalk`, `Stories`, `StoryMaker`, `Cutscene`, `CutsceneScript`, `CutsceneActor` and the dialogue tables | Keep | 2D positions, distances and "walk here" directions are what they are now; a staged character gains a `face` to turn to |
| `DialogueBox`, `SpeechBubble`, `CutsceneBox`, `Letterbox`, `StoryDesk` (1,387), `StoryMakerView` | Keep | the bubble's anchor is already a 2D point; the portrait changes with §4 |
| `NpcView`, `CutsceneActorView`, `CutsceneView` | Rework | an NPC draws like a hero, by `(anim, face)`; the camera is the same `Camera2D` |

## 6. The glass: `mobile/` (1,500 lines)

| Item | Size | Notes |
|---|---|---|
| `TouchPad` (1,032) | Rework | the left stick's ring already walks and, pushed out, sprints; the "out below crouches" step goes, and the stick steers in eight directions instead of a side; the right side keeps the cast stick that charges and aims and the HIT/USE key; the jump key goes. A twin-stick phone layout, which is what a MOBA's is |
| `TouchLayoutEditor`, `mobile/input/` | Keep | |

## 7. The perks: `perks/` (350 lines)

Keep as is.

## 8. The shell: `app/` (2,950 lines)

| Item | Size | Notes |
|---|---|---|
| `Loc`, `Db`, `Cues`, `Audio`, `AudioCues`, `Controls`, `Video`, `Pointer` | Keep | `Controls.ACTIONS` loses jump and crouch |
| `Game` (1,121: screen flow, worlds, `goto_` states), `main.tscn` | Keep | the flow is the flow; the worlds it stands up are the reworked ones |

## 9. The content database: `data/` (41 tables)

| Item | Size | Notes |
|---|---|---|
| `parts`, `boards`, `board_parts`, `categories`, `ports`, `effects`, `inversions`, `codes`, `renamed_parts`, `retired_parts` | Keep | |
| `heroes` | Rework | `hands` (the hang pose's fist) goes; `prompt` stays as what PixelLab is told |
| `perks`, `perk_steps`, `menus`, `menu_items`, `sounds`, `voices`, `emotions`, `characters`, `nodes`, `choices`, `facts`, `events`, `rules`, `criteria`, `changes`, `conditions`, `transitions`, `meta` | Keep | |
| `machines`, `states`, `steps` | Rework | the schema stays; `player.sql` is rewritten to §3's states |
| `maps`, `map_layers`, `map_rows` | Rework | the schema stays — a layer is a grid of characters — but the layer names become `floor`, `walls`, `props`, and the 16 shipped maps (`raid_*`, `moonlit_grove`) are platformer cross-sections and are redrawn as floor plans in the map creator; `width`/`height` stay 40×22 |
| `raid_rooms` | Keep | the 7×5 floor, the kinds, the exits; a room joins its neighbours on every side |
| `foliage`, `growths`, `lights` | Keep | lights as rows carry straight into §4's lamps |
| `ropes`, `hangings` | Drop | |
| `build.sh`, `schema.sql`, the SQL-as-source rule, `data/scenes/`, `data/stories/` | Keep | |

## 10. Words: `localization/`

Keep `eng/` and `kor/`. Drop the keys for jump, crouch, climb, wall slide,
ropes, gates and the hideout theme page; add keys for pits and anything
§13 adds. `tests/shared/loc_test` finds every drift.

## 11. Art and the pipeline

| Item | Size | Notes |
|---|---|---|
| `Meshy/`, `Blender/`, `Kimodo/`, `Cascadeur/`, `PIPELINE.md` | Drop | not read, not run; left where they are until the user says delete |
| The heroes' strips (`HEROES.md`) | Rework | a hero's folder holds `<id>.<anim>.<face>.png` for `face` in `down`, `up`, `side`, square frames in a row, the feet at the frame's bottom middle; `ANIMS` becomes `idle`, `walk`, `dash`, `hurt`, `cast`, `hit`, `sit`, each in three faces; `hang`, `climb_*`, `rise`, `fall`, `wall_slide`, `crouch` go. Made with PixelLab: `create_character` (four directions) from each hero's reference, `animate_with_skeleton_v3` or `animate_character` per animation, frames packed into strips by a small script kept in `tools/` |
| Legna Dennis's present strips | Drop | side view only; remade through the new spec from the same reference. Her `prompt` row carries |
| The other three heroes | New | the same way, from their rows' prompts |
| Monsters | Keep, then New | the atlas's monsters carry as they are; one that the atlas has no character for comes from PixelLab's `create_character` with `n_directions` 4 |
| Tilesets | New | a rock tileset and a grove tileset from `create_topdown_tileset`, each a floor, a wall with a top and a front, and props; the atlas's own floor and wall tiles stand in until they exist |
| The hideout interior | New | one top-down tileset and its props |
| Portraits | New | one per hero, `create_portrait_character`, or cropped from the down idle |
| Sound | Keep | the `sounds` table and its silence-until-made rule |

## 12. Tests: `tests/` (125 files, 33,800 lines)

| Item | Size | Notes |
|---|---|---|
| `tests/run.sh`, the headless/windowed split, `quarantine.txt`, the 15 fps CI reproduction | Keep | |
| `tests/circuit` (16), `tests/perks` (2), `tests/story` (10), `tests/shared` (6) | Keep | `module_test`'s table loses the rows of what was dropped |
| `tests/feature` (106) | Rework | the ones about the plane carry with the room's new builder: cast, trigger, speed, range, hurt, lost kit, bestiary, possess, kit, rune, stamina, input, aim assist, sprint, bench, pool, magic, phone, dash, dash move, floor, perks' reach, and most of the raid's; the ones about the vertical axis go: `jump`, `swing`, `crouch`, `wall`, `gate`, `rock`'s arc, `falling`, the ledge and rope ones. Roughly 70 carry, 25 go, 10 are new (pits, four-way doorways, facing, the faked arc) |
| `tests/graphics` (78) | Rework | pixel-reading tests of the same UI on the same `PixelCamera`, so most carry as they are; the room, rope, hideout-look and lighting-shadow ones are rewritten or dropped |
| `tests/mobile` (12) | Rework | the stick's crouch step and the jump key go from the layout tests |

---

## 13. The order, a commit a step

Each line is a commit on this folder's one branch, after which the game
runs and the tests named in it pass. A step that turns out to be two
things is two commits.

1. **The plan.** This file, `.gitignore`. *(this commit)*
2. **The empty project.** `project.godot` with the autoload names and the
   input map, `app/` (`Loc`, `Db`, `Cues`, `Audio`, `Controls`, `Video`,
   `Pointer`), `localization/`, `data/` with `schema.sql`, `build.sh` and
   every kept table's SQL, `enigami.db` built. `tests/run.sh` and
   `tests/shared`. `ARCHITECTURE.md` with the module rule, `README.md`.
   CI with the rules job.
3. **The engine.** `circuit/` and `tests/circuit`, unchanged.
4. **The rules that need no room.** `feature/core/` (`GameState`,
   `Heroes`, `Weapons`, `Boards`, `Magic`, `Rune`, `Pool`, `TimeCtl`,
   `Arena`, `Phone`, `Machine`, `FsmNode`), `feature/input/`, `perks/`,
   their tests. The module-split CI job.
5. **A body on a floor.** `Actor` and `Player` reworked: eight-way walk,
   four-way facing, dash, the stamina, the new `player.sql`. A flat test
   room with walls. `tests/feature/input`, `dash_move`, `sprint`,
   `stamina`.
6. **The picture's floor.** `graphics/` brought over whole, minus what
   §4 drops; `PixelCamera` over a y-sorted world; `Sprites`,
   `SkinnedCharacter` reading `(anim, face)`; `PlayerView` playing the
   new states. The player drawn as the atlas knight until a hero exists.
   The graphics CI job. `tests/graphics` that read the UI.
7. **One hero, four ways.** The new `HEROES.md`; the strip-packing script
   in `tools/`; Legna Dennis remade with PixelLab in three faces and
   seven animations; the hero select and her portrait. The player is
   played as her.
8. **Hitting things.** `feature/attacks/` with the faked arc,
   `Loadout`, `Charge`, `Enemy` with the five AIs on the plane, the
   atlas monsters, `Fx` and `CueVisuals`. One room with monsters in it.
   `tests/feature/cast`, `trigger`, `speed`, `range`, `hurt`, `kit`,
   `rune`, `rock` (without its arc test), `aim_assist`, `possess`, the
   skill editor over it.
9. **Rooms as floor plans.** `Room`, `HandLaidRoom`, `MadeRoom` on
   `TileMapLayer`s from a `TileSet` built out of the atlas; four-way
   doorways; `RaidMap` and `Raid` without gates; the first maps redrawn;
   pickups, boxes, dig spots, the lost kit, extraction.
   `tests/feature/floor`, `lost_kit`, `bestiary`, `pool`, the raid tests.
10. **Pits and the arc.** Falling into a pit and standing up at its edge;
    the lobbed projectile's shadow and height; the `flyer` and `jumper`
    AIs on it. New tests for each.
11. **The glass.** `mobile/` as the twin-stick layout; `tests/mobile`.
12. **The hideout.** `HideoutWorld` and its stations, the bench, the
    hero select, the shop, the perks page, the phone, over one tiled
    interior; the hideout's tests.
13. **The telling.** `story/` whole; `NpcView` by `(anim, face)`; the
    intro cutscene restaged on a floor; `tests/story`.
14. **The map creator.** `MapMaker`, `Maps`, the map table and panel
    on the three new layers; saving a floor plan as SQL; the shipped
    maps redrawn in it. The story maker's desk over a made map.
15. **Tilesets of the game's own.** The rock and grove tilesets from
    PixelLab with Godot terrain sets; the rooms' autotiling; `Style`'s
    tile names; the raid dressed.
16. **Light.** `Lighting` reworked for a view from above, or taken out
    and lamps drawn as glow; `lights` rows read; the lighting tests.
17. **The other heroes and the monsters the atlas lacks.** Through §7's
    pipeline, one commit a hero.
18. **The builds.** The export presets, the two build jobs, a `v2.0.0`
    tag when the user says.

Rough weight, by lines that need writing rather than copying: the rooms
and their pictures (steps 9, 14, 15) are about half of it; the body and
its attacks (5, 8, 10) a quarter; the hideout, the glass, the light and
the art the rest. The UI, the engine, the telling, the perks, the shell
and the database — some 35,000 lines — copy.
