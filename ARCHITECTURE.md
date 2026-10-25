# Six modules

> Enigami v2: the same six modules as v1, seen from above. The modules, the
> rule and the three mechanisms are v1's, unchanged; the table at the end
> is revised row by row as each step of `PLAN.md` lands, and a row that
> still speaks of a platformer's thing is one not yet reached.

The project is split so that **a change to what the game does**, **a change to
how the game looks**, **a change to what the game tells**, **a change to how a
skill board runs**, **a change to how a thumb plays it** and **a change to what
a player buys for themselves** are edits to disjoint sets of files. Branches working in parallel — one per module — can
then be merged without any of them touching another's lines.

```
circuit/     the engine. A board, the pulse that runs it, the payload it builds.
feature/     the rules. What happens, and when.
graphics/    the picture. What that looks like.
story/       the telling. Who speaks, what is staged, and how that reads.
mobile/      the glass. The console a thumb plays on, and where its buttons stand.
perks/       the perks. What a player buys for themselves with gold, a step at a time.
app/         the shell they sit in: the seam, the screen flow, the sound bank.
tests/       circuit/ · feature/ · graphics/ · story/ · mobile/ · perks/ · shared/, the same split

data/          the content database, and the scenes. Content the modules read.
localization/  every word the game says, one folder per language.
```

`circuit/` is the engine under the rules: `Components`, `SkillBoard`,
`SkillRunner`, `Payload` and `BoardCode`. It names nothing but itself and `Loc` —
not a weapon, not an actor, not a hit — so it can be tested on its own and
changed without a rule or a picture changing under it. Its parts are rows in
the content database, which `components.gd` reads through `Db`, the one other
name in it. What it needs from the game is handed in: a runner is given its base payload (`base_payload_provider`),
and the weapons, the player and the attacks are built on top of it in `feature/`.

`story/`, `mobile/` and `perks/` are whole subsystems rather than one side of
one — a conversation has both a shape and a look, and so does a console on the
glass, and so does a perk — so each carries the same seam inside itself:

```
story/rules/   the conversation and the staging. What is said, and what follows.
story/view/    the box, the portraits, the camera. What that looks like.
mobile/input/  whether the console is up, and the actions a thumb holds down.
mobile/view/   the console drawn on the glass, and the screen that moves its buttons.
perks/rules/   what each perk adds and costs, which a profile has bought, the buying, the bench's toggles.
perks/view/    the page they are bought on, at the hideout's perk station.
```

That is why they are modules and not a folder in each of the other two:
everything about a conversation, about playing with thumbs, or about a perk is
in one place, and a branch writing one opens no file the others touch.

## The rule

**A picture may read the rules it draws. A rule may never mention its picture.**

One rule, applied between the modules and again inside `story/` and `mobile/`:

```
circuit/       reads none of them, only Loc — and Db, for its parts
feature/       may read  circuit/
graphics/      may read  feature/ · circuit/ · mobile/input/
story/rules/   may read  feature/
story/view/    may read  story/rules/ · graphics/ · feature/
mobile/input/  reads none of them, only the shell it presses keys for
mobile/view/   may read  mobile/input/ · graphics/ · feature/
perks/rules/   may read  feature/
perks/view/    may read  perks/rules/ · graphics/ · feature/
```

Nothing in `feature/`, `story/rules/`, `perks/rules/` or `circuit/` draws,
names a colour, loads a sprite, plays a sound, or holds a reference to a
screen. There is a standing check for this: delete the four graphics autoloads
(`Sprites`, `Fx`, `Views`, `CueVisuals`) from `project.godot` and every test
under `tests/circuit`, `tests/feature`, `tests/story` **and `tests/perks`**
still passes — raids run,
hits resolve, boards fire, conversations run to their last line, nothing is
drawn. CI runs it on every push. `tests/shared/module_test` checks the same rule
class by class, from the code: every row of the table above is a row in it, the
one-line exceptions below are pinned to the file that has each, an edge that
was cut on purpose is listed there so it cannot come back, and no rule folder
may name the engine's own drawing, sound or asset names either.

`story/view/` reads `graphics/` the way any screen does — `UiKit`, `PixelDraw`,
`Style`, `Sprites`, `Fx` — and adds nothing to it. Back the other way there is
exactly one line, `Views` handing an unrecognised node to `StoryViews`. That is
a hand-off and not a dependency on the telling: `graphics/` names that one entry
point and nothing else — no story node, no story view, nothing a conversation
does — so what the box looks like and what the HUD looks like are still never
the same edit.

The shell in `app/` is the one place allowed to know all of them: `app/game.gd`
is the composition root, and builds screens out of `graphics/`, `story/view/`
and `mobile/view/` to drive `feature/` and `story/rules/`. What it asks a world
while one is up — whether a board is open over it, whether a panel of its own
is, whether the player stands by something to use — it asks through `World`
(`feature/world/world.gd`), so a new thing to use is that world's edit and not
the shell's.

`graphics/` reads `mobile/input/` the way it reads any state — every menu has a
second layout for mobile mode — and names one thing in `mobile/view/`: `graphics/ui/controls_panel.gd`
opens `TouchLayoutEditor` from SET BUTTON POSITIONS, because the control
settings are where a player looks for it. It opens the screen and takes nothing
else. It names `perks/view/` the same way, three times, each a page it puts up and
nothing more: `graphics/views/hideout_world_view.gd` puts `PerkPage` in the
frame every station's panel stands in, when the hideout's perk station is used,
and `graphics/views/raid_view.gd` puts `PerkScreen` up as the PERKS tab of the
screen the graph, the map and the monster dictionary are pages of, and
`graphics/views/sandbox_view.gd` puts it up as the same tab on the bench. The hideout's workbench has that tab
too, and the shell, which may name anything, puts it up there.

**What the perks add reaches the rules through one hook.** `perks/rules/` may
read `feature/`, so the rules cannot read it back: a perk raises a number the
rules hold — the player's health, stamina, mana, pace, the wait between casts,
the gold a raid finds — without being named there. `GameState.boost(stat)` asks
every function in `GameState.boost_sources` what it adds to a stat named by a
word, and `Perks` (`perks/rules/perks.gd`, an autoload) puts its own there as it
starts. The rules ask `boost` and hear `boosts_changed`; who answers is not
their business, and a perk changed — a step dearer, a perk more — changes no
rule. What a profile has bought is kept with it, in `GameState.perks`, the way
`memory` is kept for the telling.

**The two layouts.** Which one a menu is in is one question, `UiKit.mobile()`,
asked through the kit so the telling's pictures can ask it too without naming
the console. A screen built of Controls gets its thumb's size from the kit — a
pixel button, a page's frame, a slider, a switch are each built at one size or
the other — and is built again by whoever holds it when the mode is thrown, the
way it is for a language. A screen that draws itself (`SkillEditor`,
`DialogueBox`, `CutsceneBox`) asks every frame and keeps both
layouts, the thumb's under its own "for a thumb" heading; the desk's is the
path nothing in that section touches.

**The one exception.** `feature/world/sandbox.gd` names `Npc`, to stand someone
on the bench to talk to. A world that stages a character has to name one, the
same way `app/game.gd` names `Cutscene` to play the intro. It spawns one and
says who it is; it reaches into nothing else, and it is the only file in
`feature/` that mentions `story/`. The other way round needs no exception: the
story maker (`story/rules/story_maker.gd`) is a `World` that stands a made map
up with a player in it and a character on it, and `story/rules/` may read
`feature/` — so a screen of the telling's own, opened from the title, is
written inside `story/` and the shell only opens it.

## How the modules talk

Three mechanisms, and no others.

### 1. Views — for anything with a position

`graphics/views.gd` watches the scene tree. Whenever a node it recognises
enters, it attaches a view to it as a child. The gameplay node is never told.

```
Player  (feature/actors/player.gd)   ← walks, dashes, casts
└── View (graphics/views/player_view.gd)  ← the knight, the weapon, the rings
```

A view reads its parent's public state every frame and draws from it. It never
writes back. Adding a visual to something is therefore a graphics-only edit,
and adding a monster is a feature-only edit — an unrecognised node simply gets
no view, and a monster with no entry in `Style` draws with a fallback.

To give something a view, add a case to `Views.view_script_for` — or, for a
node in `story/rules/`, to `StoryViews.view_script_for` in
`story/view/story_views.gd`, which `Views` falls through to once its own table
has missed. One watcher, two tables, so putting a new character on screen is an
edit inside `story/` alone.

### 2. Cues — for moments

`Cues` (`app/cues.gd`) carries named moments out of the rules:

```gdscript
# feature/
Cues.at(&"dash", global_position, {"kind": "chain"})

# graphics/cue_visuals.gd          # app/audio/audio_cues.gd
&"dash": _dash(pos, kind)          &"dash": Audio.play("dash", pitch)
```

Cue names are not declared anywhere central, on purpose: a new cue is one
`emit` in a feature file and one handler in a graphics file, and the two
branches never open the same file. An unhandled cue is silence, not an error.

**Moments are cues; state is polled.** Whether an actor is burning is state —
the view reads `actor.burn_time` each frame. The instant it was set alight is
a moment. If you find yourself emitting a cue every frame, it was state.

**A cue carries ids, never a line.** `refused` says `stamina`; `boss_phase`
says which monster and which phase. `graphics/cue_visuals.gd` spells them out
of `localization/` (`hud.fx`), so what a moment shows is in the language being
played, and `tests/shared/loc_test` fails a rule that writes a line into a cue.

**One listener sits on the rules' side.** Free talk (`story/rules/free_talk.gd`)
hears cues too: a character who talks free answers moments — a chained dash, a
blow — and those are cues already, so the rules that send them never learn
anybody is watching. Which cues are moments a character can notice, and what
each has to carry, is the `events` table in the content database;
`tests/story/free_talk_test` fails on one that nothing sends.

### 3. Style — for the look of a thing the rules name

`graphics/style.gd` holds every colour, glyph and atlas character, keyed by the
ids the rules already use. `Components` carries heat and ports, never a colour;
`Monsters` carries hit points and AI, never a sprite; `Weapons` carries damage
multipliers, never a tint.

Every lookup in `Style` falls back, so the two branches can land in either
order: a part added on the feature branch draws in its category's colour until
someone gives it a glyph.

### Text — every word, in every language

Not a fourth mechanism either: like the conversations below, the words are
data every module reads. No screen and no rule spells out what it says. `Loc`
(`app/loc.gd`) reads it out of `localization/<lang>/<domain>.json`, and each
module asks by name:

```gdscript
# circuit/ · feature/                       # graphics/
Components.name_for(id)                     Loc.t("hud.map.title")
Loc.t("hud.extract.needs_scrap", [20, 4])   Loc.t("menu.title.start")
```

It sits in `app/` for the same reason `Cues` does. The rules name a part, a
monster and a facility; the picture names a button and a heading; neither
should have to reach into the other to find out how that word is spelled today.
The format, and how a translation falls back while it is half-written, are in
`localization/README.md`.

The English still in `Weapons.DEFS`, `Monsters.DEFS`,
`GameState.FACILITY_INFO`, `Controls.ACTIONS`, `Raid.TUTORIAL_STEPS`, and in
`data/` — a part's `name` and `description`, a line's `text` — is the
**fallback** under all of it, so a part added on the
feature branch is named on screen before anybody translates it — the same way
a part with no glyph yet draws in its category's colour.
`tests/shared/loc_test` compares the two and fails if they drift.

Silkscreen is Latin-only, so a language whose writing it does not carry brings
a face of its own, in its own folder — Korean ships 둥근모꼴, a 16-pixel bitmap
face. That makes two pixel grids on one screen: Latin on `UiKit.PIXEL`'s two,
Hangul on one, both whole pixels. `UiKit.pixel_grid()` is where that number
lives, and the pixel tests ask it before holding a screen to a grid. See **The
face** in that README.

### Conversations — content the modules read

Conversations are data, not a fourth mechanism: rows in the content database,
`data/enigami.db`, built from the SQL under `data/db/` (format in its README)
and read through `Db` (`app/db.gd`), the one script that names SQLite. Each
side reads only its own columns of a line:

| Columns | Read by |
|---|---|
| `text` `next` `choices` `speaker` `name` `speed` | `story/rules/dialogue.gd` and `npc.gd` — the conversation itself |
| `emotion` `sprite` | `story/view/dialogue_box.gd`, polling the NPC's current line |
| `camera` | `story/view/npc_view.gd`, through `Fx.direct` / `Fx.release` |
| `sfx` `voice` | `app/audio/audio_cues.gd`, from the `talk` and `talk_letter` cues, which carry the line |

Three of those four rows are inside `story/` now. That is the point of the
module: a new kind of direction — a column nobody reads yet — is written, read
and drawn without leaving it, and `app/audio/` stays the one outside hand,
because sound belongs to the shell wherever it is asked for.

`Db` sits in `app/` for the reason `Loc` does: it is content every module may
read, and none should have to know it is a table. It is read-only, opened
once, and answers with nothing rather than an error when the extension or the
file is missing on a platform. `feature/` and `story/rules/` may name it, as
they may `Loc`, and so may `circuit/components.gd`, for the parts;
`tests/shared/module_test` says so. Nothing else names
`SQLite` at all — a module asks `Db` for rows and gets dictionaries.

The player's movement is rows in it too — `machines`, `states`, `steps`,
`conditions` and `transitions` — built into `FSMNode`s by `Machine`
(`feature/core/machine.gd`). All of the machine is content: the states, what
each does every frame, which can follow which, and what opens each way,
which is a question about what the player senses —
`not dashing and on_floor and dir != 0`. What stays code is the words the
rows are written in, handed over by `Player._setup_fsm`: the actions a step
takes, each one thing the body does on a frame, and the senses a condition
reads. A row naming one the player does not have is reported, not guessed at.

So are the skill boards' parts — `parts`, their `ports`, their `effects` and
their numbers in a shared code, `codes` — read once by `Components`
(`circuit/components.gd`), and the boards the game ships with, `boards` and
`board_parts`, built by `Boards` (`feature/core/boards.gd`): each weapon's
graph as a new profile gets it, and every monster's. A part
is its numbers and what it does to a flow, each effect a change to one field
of the payload; what an effect *means* — what a form spawns, what a flag does
to a hit — is code, `SkillRunner._apply` and `feature/attacks/`, and the rows
name it by field. A board is its parts and the way each faces: which feeds
which is walked, not stored. Every board is rooted: its root, one of its parts
(`SkillBoard.root`), is where every cycle starts — a weapon's own attack form,
which the player moves but never takes off — and there is no INPUT part. A flow
goes from a part into the one beside it and leaves the board by the middle of
its right edge (`SkillBoard.way_out`), and there is no OUTPUT part either.
A weapon *is* its graph (`GameState.weapon_boards`): one each, carried into a
raid as a copy, lost and won back with the weapon. Each weapon keeps three
(`GameState.GRAPH_PRESETS`, `graph_presets`), one on it and the others put
away as blueprints, the way a share code is one: putting another on trades the
parts across (`switch_preset`), so a part is only ever on the graph in use. What
a part looks like stays in `Style`.

The `text` in a conversation's rows is the English fallback. What is actually said is
laid over it from `localization/<lang>/dialogue/<id>.json`, by node name —
words only, never where a line leads. Scenes are still files,
`data/scenes/<id>.json`, and work the same way, by beat.

The menus are rows as well — `menus` and `menu_items` — read by `Menus`
(`graphics/ui/menus.gd`) for the title screen and the shell's pause menu: a
menu is its name, and its items in order, each opening a menu or naming an
act of the screen's by its id. The screen keeps only the acts, and the look.
An item that opens a menu says that menu's name, so a heading is written
once and every door to it says it; the English in the rows is laid under
`localization/<lang>/menu.json` by id.

`story/rules/` hands a line on as it came out of the table, keyed by column
name, and never names a column it does not use, so the rule above still holds:
a new kind of direction is a column in `data/db/schema.sql`, a value in a
character's file, and a handler on the presentation side. A column declared
`JSON` arrives parsed, which is how `camera` reaches the picture as the
dictionary it always read.

A character can also talk **free** — in a bubble over whoever is speaking,
while the player goes on playing — and that is rows as well: `rules`, each
with the event it answers, the `criteria` the `facts` must meet, and the
`changes` it makes once it has been said (**Free talk** in
`data/db/README.md`). The split is the same one. `story/rules/free_talk.gd`
reads a rule's `text`, `listens`, `once`, `next`, `triggers`, `speaker`,
`speed` and `hold`, and decides what is said and when; `story/view/speech_bubble.gd`
reads its `emotion`; the sound bank its `sfx` and `voice`, off the same `talk`
cues the box sends. What a free talker remembers is kept with the profile
(`GameState.memory`), which saves it without reading it, and what the game
counts `GameState.facts()` hands over by name — so nothing in `feature/`
knows what anybody said.

### The player's input — a line anything may stand on

The player never reads `Input`. Everything they are asked to do comes down one
line, `Player.input` (`feature/input/`), after aarthificial's devlog on
stealing control from players: an empty `InputState` goes in at the head,
every `InputMiddleware` on the line has its say, and the body does whatever
comes out of the far end.

```
Hands          the keys, a pad, the console, the pointer: what the player says
ComputerHands  something playing the body in their place — a demo, a test: what
               the player said dropped, and what the computer says instead
AimAssist      a stick's aim bent toward what it is near: what they meant
HandsOff       a screen over the game, a conversation in the box: the hands taken off
WalkTo         the walk over to talk: the body driven somewhere, and given back
               to a push the other way
```

Each stands at its rank — what fills the state in, what helps it, then what
holds it, then what steers — so a walk still moves a body nobody may move, the
way the devlog's navigation comes after its dialogue. What lasts (which way and how
hard, a button held, where to aim) is read for its value; what happens (a dash
pressed, a cast let go of) is an act, which any stop may raise and a gate shut
anywhere on the line drops. `input_locked` and `talk_locked` are two
`HandsOff`s on that line, and `controls_locked()` asks the line.

The line also says whose the body is. Anything on it may answer `takes_over()`:
a hold that is the game's own — a conversation, a stun — a walk, and the
computer's hands do; a hold that is a screen's does not, since a window over
the game is the player's own doing. `Player.taken_over()` asks the line, and
`Pointer` asks the player: while the computer has the body the crosshair is the
computer's — it rests where it was, or goes where `ComputerHands.point_at`
leads it — and the system pointer is shown beside it, moving nothing.

So a system that wants the player's body — `Npc` walks them over before a
conversation in the box — puts a middleware on the line and takes it off
again, or lets it finish, and nothing else on the line, the player included,
has to hear about it.

## Where does it go?

| Change | File |
|---|---|
| New skill component | a row in `data/db/parts/parts.sql` — its category, heat, cells, ports and what it does to a flow, as effects, and what it does instead after an INVERT, as `inversions` — and a number on the end of `codes` there, or no board carrying it can be shared; then `data/db/build.sh`. A new *kind* of effect, form or trigger is code: `SkillRunner._apply`, `Payload`, `feature/attacks/`. Its colour, glyph and icon in `graphics/style.gd` |
| The share code — what it carries, how long it is | `circuit/board_code.gd`; COPY and PASTE under the board, and the words for its refusals, `graphics/ui/skill_editor.gd` |
| New monster | `feature/actors/monsters.gd`; its attack, a board in `data/db/boards/monsters.sql`; its sprite and colour in `graphics/style.gd` |
| How the player looks — plate, cape, glow | `graphics/assets/sprites/player/player.skin.png`, and nothing else: every pose beside it is painted in the colours of a map that names its pixels, and takes theirs from it. See that folder's README and `graphics/skin/` |
| A new pose for the player | a strip beside the skin, painted in the map's colours; how it plays, `SkinnedCharacter.ANIMS`; when, `PlayerView._animate` |
| New NPC or dialogue | a file in `data/db/dialogue/`, then `data/db/build.sh` — see `data/db/README.md`; no code. New *kinds* of direction: a column in `data/db/schema.sql`, read in `story/view/dialogue_box.gd` (emotion, portrait), `story/view/npc_view.gd` (camera) or `app/audio/audio_cues.gd` (sound) |
| How the letters of a line can move — a new effect, or how one looks | `Style.TEXT_EFFECTS` and `Style.letter_offset` in `graphics/style.gd`, which every box and bubble draws with; its id in `StoryMaker.EFFECTS`, and its name under `hud.story.effect` in `localization/` |
| Content better kept as rows than as a file | a table in `data/db/schema.sql`, read through `Db` (`app/db.gd`) |
| A weapon that is thrown — the rock: one of it, out of the hand once thrown, lying where it lands until it is picked back up | `thrown` on its row of `Weapons.DEFS` (`feature/core/weapons.gd`). Whose hands it is in, `Player.holders`: thrown out of them in `_on_fired` — the flow that finds it in the hand is the rock, any other a copy of it (`Projectile.ghost`) — and taken back with `take_back`; a monster the player is in picks it up and lets it go on `release`. The bolt that is the rock comes down as a `LooseRock` (`feature/world/loose_rock.gd`), which a room writes into its record when it is walked out of (`Room.save_state`). How it looks: the rock tile, drawn in code in `Style.DRAWN_TILES` and handed out by `Sprites.texture` like an atlas tile; held upright, `Style.WEAPON`'s `upright` and `grip`; in the air, `ProjectileView._draw_thrown`; on the floor, `graphics/views/loose_rock_view.gd` |
| A board the game ships with — a weapon's graph as it starts, a monster's | `data/db/boards/`, then `data/db/build.sh`; the weapon or the monster names it by id, and a weapon names its root part beside it (`Weapons.DEFS`) |
| The player's movement — its states, what each does, which can follow which, and when | `data/db/machines/player.sql`, then `data/db/build.sh`. A new action for a step to take, or a new sense for a condition to read, `_setup_fsm` in `feature/actors/player.gd` |
| How the hideout looks — the hall seen from above, what stands at each station and how it lights for somebody standing there | The hall is a floor plan the rules lay (`HideoutWorld.PLAN`, a `MadeRoom`), drawn as any made room is: its floor and walls from the atlas (`MadeRoomView`, `AtlasTiles`), its lanterns from its dressing (`HideoutWorld.DRESSING`). What stands at a station is `graphics/views/station_view.gd` (`StationView`): the rack, the counter, the perks' plinth and the gate's door, out of the atlas's own fittings, sorted among the bodies by their feet. The sign hung over a station, and what it says, is `graphics/views/hideout_world_view.gd`; the signs' colours are the `HIDEOUT_` constants in `graphics/style.gd`. Where the stations stand is the rules' (`HideoutWorld.STATION_CELLS`) |
| What grows on the rooms' floors — grass, flowers, a bush — and how it sways: how tall and how thick it stands, how far a push or the wind moves it; and what a room grows of each, how many, how long | a row of `foliage` and one of `growths` in `data/db/foliage/foliage.sql`, then `data/db/build.sh` — see **Foliage** in `data/db/README.md`. How a patch is drawn — its picture and its mask, pixel by pixel — `graphics/foliage.gd`; how its pixels move for a push and for the wind, `graphics/assets/shaders/foliage.gdshader`. Where in a room a patch may grow, `_grow_foliage` in `graphics/views/room_view.gd`; its colours, `Style.FOLIAGE_LOOK`. Nothing in `feature/` knows it is there |
| What moving things do to the air the picture is drawn in — what writes into it (a body, a bolt, a blast's ring), how stiff it is and how fast a push dies — for the foliage, or anything else drawn that should give way | `graphics/velocity_buffer.gd`, aarthificial's velocity buffer, and the step it takes every frame, `graphics/assets/shaders/velocity.gdshader`; the `PixelCamera` carries one on its own grid. Any shader reads it through the globals `velocity_buffer`, `velocity_area` and `velocity_time`, declared in `project.godot` |
| The light the picture is shown in — the passes the world is drawn through once it has been drawn, and how dark a room is with no lamp lit | `graphics/lighting.gd`, aarthificial's deferred lights, which the `PixelCamera` carries on its own grid beside the velocity buffer and whose picture it shows. The world is drawn unlit into two buffers — its colours, the camera's own, and the way every pixel of it faces — and then every light is added to it, a pass each — a shining thing's (`Shine`) and a `Lamp`'s alike: `ambient.gdshader` the light there is with none lit, `light.gdshader` a light of any of Blender's four types, `shadow.gdshader` where one does not reach (thrown all one way for a sun), `figure_shadow.gdshader` the shadow a body throws out of a round light's plane, `bodies.gdshader` where the bodies stand and how far forward, and `lighting.gdshaderinc` what all of them share. `Lighting.ambient` is how dark a room is: white, the room as it was always drawn, until the view of a world sets it darker (`pixels.lighting.ambient`). With no lamp on the screen and the room that light, none of it runs, and the picture is the buffer the world was drawn into. A shader knows it is drawing the second buffer by the global `normals_size`, declared in `project.godot` |
| The light a thing gives — a lantern, a lightbulb, a fire, a fireplace, a torch, a strip of neon — its type, Blender's point, spot, area or sun, and its numbers: colour, power, how big, how far, which way, how wide, how much of it the air catches, whether it throws a shadow, how it flickers | a row of `lights` in `data/db/lights/lights.sql`, then `data/db/build.sh` — see **A light** in `data/db/README.md`. It is a property of the thing that gives it and not a node: a `Shine` (`graphics/shine.gd`), given with `Shine.give(thing, kind)` and taken with `Shine.put_out`, which is where the thing is, turns as it turns, and is out while it is hidden. What a thing does with its own from moment to moment — dimmer, brighter, another colour — is its `level` and `color`. Who gives one: the map creator's props (`graphics/views/made_room_view.gd`), and the hideout's lanterns, which are its dressing's (`HideoutWorld.DRESSING`). Nothing in `feature/` knows one is lit. `tests/graphics/lighting_test` |
| A lamp in a fight — where it is, what colour, how bright, how far it reaches, whether it points, how much of it the air catches, whether what stands in it throws a shadow | a `Lamp` (`graphics/lamp.gd`), put wherever the thing that shines is by that thing's view, and carried along with it; the light reads it as a point, or a spot if it points (`Lamp.as_shine`). The ones there are, each with its numbers at the head of its file: what a bolt throws (`ProjectileView`), a blast's flash (`AreaBurstView`), a body on fire (`ActorView`), and a room's way out (`RoomView`). Nothing in `feature/` knows one is lit |
| What throws a shadow | a `ShadowCaster` (`graphics/shadow_caster.gd`), put by a view: a body's is a box the size of it (`ActorView`), a room's rock every line where it meets the open air (`RoomView.air_lines`). Rock throws its edges' shadow in every light; a body only in a spot's or a sun's, where a spot inside it still has it throw one, as from the body's edge nearest the light (`ShadowCaster.beyond`). In a round light — a point's, an area's: a lantern, a fire, a bolt — a body is in front of the light or behind it, as the world draws the two (`Lighting._rank`: by z, then the tree): with the light in front, it throws its figure on the wall behind it, `WALL_SCALE` bigger about the light and `WALL_DARK` dark; with the light behind, a patch at its feet, leaning away from the light (the `FEET_` numbers, gone while it is off the ground), and it stands dark against the light but for a rim (`FACE`, `RIM_NEAR`, and the `RIM_` shares in `light.gdshader`) — all in `graphics/lighting.gd` (`_throw`). Its figure is what it is drawn as (`ShadowCaster.figures`: the sprite, and the player's weapon), or its box with none. No light throws one off a body that is its own — given by its view or anything of it, as a body on fire is (`Lighting._own`). How many lamps throw shadows at once, `Lighting.MASKS` |
| Which way a thing faces to a lamp; what gives its own light; and what is the back of the picture | A sprite wearing `Sprites.material_for` faces out at its edge by itself — `EDGE_FACING` in `lighting.gdshaderinc`, which `actor_sprite.gdshader` and `skin_sprite.gdshader` both draw. Something drawn in code says how it faces by drawing that: a twin of itself on `Lighting.NORMAL_LAYER`, painted in `Lighting.faces`'s colours — the rock's is `RoomView.draw_faces`. Whatever says nothing is flat, lit alike from anywhere. What gives its own light — a bolt, a spark, a number, a bar of health — wears `Lighting.glow()`, and no lamp brightens it and no dark room dims it. And what everything else is drawn in front of — a room's floor — goes on `Lighting.BACKDROP_LAYER`: flat, and not drawn a second time to say so. |
| Glass — what is seen through it, what a mirror shows and across which face, how tinted and how far into it, and where in the picture it stands | a `Glass` (`graphics/glass.gd`), panes of one kind put by a view in front of what they should show through and behind what should stand in front of them; it draws nothing into the picture, only into the marks of the pixel camera's `Glazing` (`graphics/glazing.gd`, on `Glazing.LAYER`). That pass comes after the light: it draws the world once more for where the glass is (`glass.gdshader`), anything drawn over a pane wiping its mark out, and puts the glass into the lit picture (`glazing.gdshader`) — clear glass tints what is behind it, a mirror shows the picture across its nearest face to the air, and a back mirror (`Glass.Kind.BACK_MIRROR`), which faces the eye, shows what stands in front of it `Glass.shift` off, read off the marks. How tinted, how much a mirror shows and how deep it fades, `Glazing.CLEAR_TINT` and the `MIRROR_` constants; how much a back mirror shows and how far off, `BACK_SHOWS` and `BACK_SHIFT`. Nothing behind any glass but the back of the picture is drawn on the world's layers (a made map's moon is the back of the picture, with a glowing twin in the normals), or a back mirror would show it. Nothing is worked out with no glass on the screen. `tests/graphics/glass_test` |
| A menu — what it is called, what is on it, in what order, and what each item says or opens | `data/db/menus/menus.sql`, then `data/db/build.sh` — see **A menu** in `data/db/README.md`. What an item that opens no menu *does* is the screen's, by the item's id: `acts_for` in `graphics/ui/title_screen.gd`, `_pause_acts` in `app/game.gd`. How the items look — a tile's mark, a button's colour — stays with the screen |
| A new directed scene, or a new staging direction | a file in `data/scenes/` — see its README; no code. A new direction is a case in `story/rules/cutscene.gd` and, if it shows, `story/view/cutscene_view.gd` |
| How a conversation behaves — range, reveal speed, who is held still, where the player is walked to stand | `story/rules/npc.gd`. How it reads on screen, `story/view/dialogue_box.gd` |
| Something that takes the player's controls for a while — holds them, walks them somewhere, presses for them | an `InputMiddleware` in `feature/input/`, put on `player.input` and taken off again or left to finish; see `InputProvider`. What the player's own hands say is `Hands`; how a walk gets there and is refused, `WalkTo`. If it leaves the body the computer's rather than the player's, it answers `takes_over()` |
| Something that plays the character in the player's place — a demo, a scripted test | a `ComputerHands` on `player.input`: told which way to walk, what is held and pressed, and where to point. It drops what the player's hands say and points with the game's crosshair. Which pointer is on the screen meanwhile, and what a window over it does, `app/pointer.gd` |
| How a stick's aim is helped — the least virtual size a target keeps, how far its pull reaches, how steep the ground between two may get | `feature/input/aim_curve.gd`, the curve from where the stick points to where the weapon does, after t3ssel8r's devlog on aim assist. What counts as a target, and how a change in them fades in, `feature/input/aim_assist.gd`; how much of it the player wants, a row in `graphics/ui/controls_panel.gd` |
| The crouch — how low, how small a thing to hit, what asks for it | `Player.CROUCH_BODY` and `CROUCH_HURT_RADIUS`; its steps and the ways in and out of it, rows in `data/db/machines/player.sql`; its pose, `player.crouch.png`. Down held is what asks (`Hands`): how far a gamepad's stick has to be pushed for that is `move_down`'s dead zone in `project.godot`; the console's stick has to be dragged far out below its ring, `TouchPad.STICK_CROUCH`, or as far as the glass goes, `TouchPad.gate` |
| The sprint — how fast, and what asks for it | `Player.SPRINT_SPEED`: a pace of the run, not a state. The `sprint` action asks (`Hands`): a key, a gamepad's stick clicked in, and the console's stick dragged far out to a side of its ring, `TouchPad.STICK_SPRINT` — beside `STICK_RUN`, how far it is dragged inside the ring before it walks, `STICK_FAR`, how far the knob follows a thumb, `gate`, which brings the sprint and the crouch in to what a thumb can reach where the glass ends first, and `_draw_reach`, which marks the walk on the ring and the other two on lines out past it, and lights them as they are reached |
| Someone who talks free, and what they notice | a file in `data/db/dialogue/` of `rules`, `criteria` and `changes` — see **Free talk** in `data/db/README.md`; no code. A new kind of moment to notice, a row of `events` in `data/db/schema.sql` naming the cue. How free talk is picked and paced, `story/rules/free_talk.gd`; how the bubble looks, `story/view/speech_bubble.gd` |
| What anyone actually says, on any screen, in any language | `localization/<lang>/` — see its README. A new language is a folder and an entry in `LANGUAGES` in `app/loc.gd` |
| What an emotion looks like | `EMOTIONS` in `graphics/style.gd` |
| Retune damage | `feature/` |
| The raid's floor — which map stands where, what kind of room, how dangerous, which way out | `data/db/floors/raid.sql` (`raid_rooms`), then `data/db/build.sh`; `RaidMap.lay` reads it and each room's map (`Maps`), the exits' terms are `RaidMap.EXITS`. A room's doorways, gates and exit are marks in its map (`MadeRoom.WAYS`, `EXIT`), laid in the map creator. `tests/feature/floor_test` |
| The ways between a raid's rooms — a doorway in any of the four walls, walked straight through to the room beyond | marked in each room's map (`MadeRoom`: `<`, `>`, `U`, `D`; `door_rect`, `arrival_at`), and joined where the floor has a room beyond (`RaidMap.doors_for`); a generated room cuts a doorway the mouth's width in each wall with a room beyond (`Room._generate`, `DOOR_ROWS` and `DOOR_COLS`), and walking out through one is `Raid._update_window` |
| Retune a part — its heat, what it adds or multiplies, how long it slows the fight | `data/db/parts/parts.sql`, then `data/db/build.sh` |
| Retune a board's timing — ticks, cooldowns, a pulse's life | `circuit/skill_runner.gd` |
| The lighting test — its ground, what hangs in it, what its keys change | not here yet: it comes back with the light (PLAN.md, step 16) |
| A story written in the story maker — what a node is: a stack of properties, none to start with (`StoryMaker.PROPERTIES`) — who says what, its expression, the motion in its letters, what anyone does as it starts, the answers that make it a question — and where it leads; how nodes and their properties are put in, changed, linked and taken away; how a story is handed to a character in the box or free and to a scene as a novel; what PLAY stands up and where the character stands | `story/rules/story_maker.gd`, a `World` like the map creator's: it writes and it plays, one at a time, and keeps the story on its desk between visits. The three ways it plays are the game's own — `Npc` in the box or free, given the story in the shape `Dialogue.character` reads one (`Npc.setup_with`), a question in a free story asked in the box (`Npc.free_story`), and `Cutscene` handed the story as a scene (`Cutscene.handed`), laying no stage of its own on a map's floor (`own_stage`), its beats leading on by id (`next`, `choices`). What a line directs on the stage is `Npc.direct` — a walk, a pose held (`forced_anim`, which `Player` carries too), a turn — and a scene's `move` near someone or by so far across and down, and `face` toward, or any of the four ways. The motion in the letters is `effect`, drawn by `Style.TEXT_EFFECTS` in every box and bubble. `tests/story/story_maker_test` |
| Where stories are kept, and what one is called | `story/rules/stories.gd`: `data/stories/` in the project when the game is run from it, `user://stories/` in an exported game; a story's id is its file's name, filed as a map's is. The files are content like the rest of `data/`, and a format note is beside them |
| The story maker's desk — the bar, the column of what the story is set on and how it plays, the sheet the nodes stand on with their ports and links, the inspector the node picked is written up in — + PROPERTY, and a panel a property, after Blender's — what the pointer and the keys do, what a played story's screen is | `story/view/story_desk.gd`, a screen that asks the maker for every change; `story/view/story_maker_view.gd` puts it up, and for a story played with a body in it the camera, the raid's HUD and the map's light (`MapTiles.ambient`) — a novel brings its own camera and panel (`CutsceneView`). Its words are `hud.story` in `localization/`; the door to it is a row of the `title` menu and an act of the title's. `tests/graphics/story_desk_test` |
| A map made in the map creator — what a cell of one can hold, what stands where it says, and how one is picked up as a room | `feature/world/made_room.gd`: a `MadeRoom` is a hand-laid room whose layers are properties of it — `plan`, the ground and what stands on it, the one layer the rules read; `back` and `dressing`, the picture's — with the `tileset` that draws them, so a scene holding one is the room. A new thing to lay in the plan is a mark there — a monster's is a letter in `MONSTERS` — and what `record` makes of it; then its picture on the table, `MapTable.paint_mark`, and its name under `hud.maker.mark` in `localization/`. A new kind of ground is a mark in `GROUND`, as solid as the rest, and its look in every tileset. Shut in past its edge on every side (`_build_collision`), where every tileset draws ground on. It is a `Room`, drawn by a view of its own (below) |
| A bench, or another thing to sit on — where it stands, how near is near enough, what sits the body down and what stands it up | `feature/world/bench.gd` (`Bench`, read by interact itself, as a treasure box is) and `sit`, `stand_up` and `_mind_seat` in `feature/actors/player.gd`; a room's are `Room.benches`, from its record's `benches` or `add_bench`: the hideout's and a made map's wherever `MadeRoom.BENCH` was laid on the plan (the hideout's, `HideoutWorld.PLAN`). How it looks, `graphics/views/bench_view.gd` (`BenchView.paint`, which the map creator's table draws it with too), and the body sitting on it, `player.sit.png` in `graphics/assets/sprites/player/`, on the seat `BenchView.SEAT` stands at |
| Where maps are kept, and what one is called | `feature/world/maps.gd`: the ones the game ships with in the content database (the `maps`, `map_layers` and `map_rows` tables, built from `data/db/maps/`), and the ones made on a machine in `user://maps.db`, the same tables, which `Db.writable` opens; a map's id is `Maps.id_for` its name. Run from the project, SAVE writes the map out as `data/db/maps/<id>.sql` too. The format is **A map** in data/db/README.md |
| The map creator — what laying is, a step back, a map's least, greatest and new size, what PLAY stands up and with what kit, what a death does | `feature/world/map_maker.gd`, a `World` like the bench (`MIN_SIZE`, `MAX_SIZE`, `NEW_SIZE`). It lays and it plays, one at a time, and keeps the map on its table between visits. `tests/feature/map_maker_test` |
| The map creator's table — the tools, the tabs and their tiles, the bar, the MAP settings, the sheet and the grips on the map's edges that size it, what the pointer and the keys do on it, what a played map's screen is | `graphics/ui/map_table.gd`, a screen that asks the maker for every change (a size dragged to is `MapMaker.resize` with the cells it moved by) and draws its sheet in the map's tileset, in chunks, again only where a change reaches; a tab's tiles are the tileset's own pictures (`MapTiles.icon`). `graphics/views/map_maker_view.gd` puts it up, and for a played map the camera, the raid's HUD, the assembly overlay and the tileset's light (`MapTiles.ambient`). Its words are `hud.maker` in `localization/`; the door to it is a row of the `title` menu and an act of the title's. `tests/graphics/map_table_test` |
| A tileset — its floor, its walls and the pits in its floor, as tiles of the game's own; what the creator's table draws each cell as | a script in `graphics/tiles/` that extends `MapTiles` (`map_tiles.gd`), its id in `MapTiles.IDS` and `of`, its two Wang tilesets made with PixelLab under `graphics/assets/tiles/<id>_walls` and `<id>_pits` (`TerrainTiles`, `terrain_tiles.gd`, which picks each tile of a dual grid from the cells round it, the wall's face in the wall's cell and its top above), and its words under `hud.maker.tiles` in `localization/`; `grove_tiles.gd`, the Moonlit Grove, `rock_tiles.gd`, a raid's rock, and `keep_tiles.gd`, the hideout's hall, are the three. Which place is drawn in which is `Style.RAID_TILESET`, `HIDEOUT_TILESET` and `STAGE_TILESET`; a made map names its own. A room lays them (`MapTiles.lay`, `RoomView._lay_tiles`) and the creator's table draws them in chunks (`MapTiles.paint_area`, `MapTable`). A tileset whose tiles are not there yet is drawn out of the atlas's floor and walls (`AtlasTiles`) |
| What can be put about a made map — a lantern, a lightbulb, a fire, a fireplace, the glowing caps, the fireflies, the grass, the flowers, a bush, a fern — what each is made of, and the light it gives | `MapTiles.PROPS`, the marks and their names; their pictures `MadeRoomView.paint_prop` (standing in a room, and still on the creator's table, `MapTiles.paint_prop_still`), the foliage `Foliage` (`graphics/foliage.gd`, and a still of it `MapTiles.paint_foliage_still`); the light each gives, its row of `lights`, through `Shine.give` in `MadeRoomView._dress` |
| Retune shake, sparks, hitstop *feel* | `graphics/cue_visuals.gd` — except hitstop and dilation, see below |
| Something spawned again and again — a spark, a ring, a number that floats off | borrow it from a `Pool` (`feature/core/pool.gd`, after aarthificial's devlog on pooling), lent to the screen it is for, and let it hand itself back once it has played out; a screen that goes takes back whatever it still had out. `graphics/fx.gd`'s sparks, rings and words are drawn that way |
| HUD layout, editor look — where a thing sits, not what it says | `graphics/ui/` |
| The monster dictionary — which monsters have an entry, what a skill is, when one is met or seen | `Monsters.DEX` and `Monsters.skills_of` in `feature/actors/monsters.gd`; what has been met and seen is the profile's (`GameState.bestiary`), written as a raid goes (`Raid._meet`, off `Enemy.attacked`). The page is `graphics/ui/monster_dex.gd`, a skill drawn by `graphics/ui/board_picture.gd` — the assembly screen's drawing with nothing to press — and its words `hud.dex` in `localization/`. `tests/feature/bestiary_test` |
| The phone — its alarm, the ringing and which monsters it calls, where it lies when put down, and its photos as files | `Phone` (`feature/core/phone.gd`), an autoload the world it is in ticks (`Raid._process`, `HideoutWorld._process`); a monster called to a sound is `Enemy.lure_to`, and what a call does to each kind of monster `Enemy.moves` and the AI under it; the phone lying on a floor is a `PhoneProp` (`feature/world/phone_prop.gd`), laid by `Raid.put_phone_down` and `HideoutWorld.put_phone_down` and laid again when its room is walked back into (`Raid._enter_room`); a parked raid keeps it (`Phone.to_save`). `tests/feature/phone_test` |
| Who the player can play as — the roster, the order the heroes stand in, what each looks like, who is played as | `Heroes` (`feature/core/heroes.gd`) reads the `heroes` table (`data/db/heroes/heroes.sql`); the pick is `GameState.hero`, kept with the profile and set by `GameState.set_hero`. What a hero can do is to come: a column of the table when it does |
| A hero's own sprites — the folder, the frame, the strips, what each animation shows, how they are made | `graphics/assets/sprites/HEROES.md`; how they are rendered from a 3D character — Meshy's mesh, Blender's rig and pixel render, Kimodo's motion, Cascadeur's cleanup — the `Meshy`, `Blender`, `Kimodo` and `Cascadeur` folders beside the checkouts in `WIPGames/Enigami/` (`PIPELINE.md` there), one a step, outside the game; a folder of strips painted straight is a `SkinnedCharacter` with `painted` on (graphics/skin/skinned_character.gd). Which art a hero is played as and drawn from, `Style.hero_play_art` and `Style.hero_portrait_art`; the player's view wears the hero picked, and changes with the pick (`PlayerView._on_hero`, `ActorView.rewear`); what hangs over the head asks the view how tall the art stands (`PlayerView.head_y`) |
| The bench's screen — the cards in a row, the cursor, the portrait and the name on each, what the keys do on it | `graphics/ui/hero_select.gd`, which the shell puts up when the body sits on a bench and takes down when it stands (`app/game.gd`: `_on_cue` on the `sit` cue, `_open_heroes`, `_hero_picked`); a raid holds the player under it with `Raid.set_choosing`, the hideout with its `set_editing`, the sandbox with a drawer of `set_tools_open`. Its words are `hud.heroes` in `localization/`. `tests/graphics/hero_select_test` |
| The phone on the screen — the handset sliding up and down, the home screen and its apps, the camera's viewfinder and its shutter, the gallery, the alarm's page, the settings' rows | `graphics/ui/phone_screen.gd`, which the shell puts up on `open_phone` and takes down (`app/game.gd`: `_toggle_phone`, `_phone_app`, `_phone_down`); the raid holds the player under it with `Raid.set_on_phone`, the hideout with its `set_editing`; the world's picture for the viewfinder is `PixelCamera.picture`; the phone on the floor is `graphics/views/phone_prop_view.gd`, and what the alarm sounds like is `app/audio/audio_cues.gd` under `phone` and `phone_ring`. Its words are `hud.phone` in `localization/`, its key `open_phone` in `controls`. `tests/graphics/phone_test` |
| The screen the graph, the map, the monster dictionary and the perks are pages of — the tabs along its top, its back arrow, its veil | `graphics/ui/screen_tabs.gd`, drawn by every page (`SkillEditor`, `MapPanel`, `MonsterDex`, `PerkScreen`), the first three tabs wherever it comes up (`ScreenTabs.PAGES`) and PERKS after them in a raid, on the bench and at the hideout's workbench (`PAGES_WITH_PERKS`), which `app/game.gd` puts up there. What a press on a tab puts up is the view that opens it: `graphics/views/raid_view.gd` for a raid, whose map's page is the floor plan, and `graphics/ui/screen_pages.gd` for everywhere with no map, whose map's page says so (`hud.map.none`). The tabs' words are `hud.tabs` in `localization/`. `tests/graphics/editor_close_test` |
| How a menu is laid out in mobile mode — a row's height, a word's size, a page's width | the kit's: `THUMB`, `THUMB_TEXT` and `THUMB_PAGE` in `graphics/ui/ui_kit.gd`, which every page built of Controls takes them from. What is *on* a page there is that screen's own — the "for a thumb" section of `skill_editor.gd`, `dialogue_box.gd` and the rest, `_build_for_a_thumb` in `controls_panel.gd` |
| The resolution the world is drawn at | `graphics/pixel_camera.gd` (the size comes from `Sprites.PIXEL_SCALE`) |
| A new sound | a row of `sounds` in `data/db/sounds/sounds.sql` — its file's path, the prompt it is made from, and whether the file is in use — and what plays it in `app/audio/audio_cues.gd`; `app/audio/audio.gd` plays what the table gives it and makes nothing of its own |
| What a moment says on screen — WINDED, a boss's second form | `hud.fx` in `localization/`, spelled in `graphics/cue_visuals.gd`; the rule sends the id |
| A setting on both settings pages — a volume, the language, the screen | `graphics/ui/settings_rows.gd` for the game's, `graphics/ui/video_rows.gd` for the machine's; the title and the pause menu both ask for the rows |
| A new thing a press of `interact` can use in a world | that world's `use_nearby()`, see `feature/world/world.gd`; the shell asks and names nothing |
| What the forge costs, and that a weapon is its graph — one each, deployed as a copy, lost and won back with the weapon | `feature/core/game_state.gd` (`FORGE_COST`, `FORGE_INPUTS`, `weapon_board`, `die`, `extract`); the screens only ask |
| A control on the on-screen console — where it sits, whether it is a key or a stick, what it says | `CONTROLS` in `mobile/view/touch_pad.gd`, and its word in `controls.pad` in `localization/`. What pressing it does to the game is `mobile/input/touch.gd`, which sends the action a keyboard would and is the only thing that knows a finger from a key |
| Where a player may move a console button, and what is kept of it | `mobile/view/touch_layout_editor.gd`; the arrangement itself, `TouchPad.layout` in `mobile/view/touch_pad.gd` |
| A new screen | `app/game.gd`, plus its Control in `graphics/ui/` |
| A new place to stand a player, opened from the title | a `World` in `feature/world/`, its view in `graphics/views/` and a case for it in `Views.view_script_for`, a state and a `goto_` in `app/game.gd`, and its door: a row of the `title` menu in `data/db/menus/menus.sql` and an act in `TitleScreen.acts_for`, with a mark for its tile in `TitleScreen.MARKS`. The map creator is one made this way. One that is the telling's — the story maker — lives in `story/rules/` with its view in `story/view/` and its case in `StoryViews.view_script_for`, and the rest is the same |

### The one thing that looks like a picture but is not

Hitstop and time dilation scale `Engine.time_scale`, so they move the
simulation: a dilated fight really is slower for everything in it, which is the
whole point of the `TIME DILATION` part. They are a rule, and they live in
`feature/core/time_control.gd`. Screen shake, sparks and damage numbers change
nothing and live in `graphics/fx.gd` — and so does what a dilated fight looks
like: the pixel camera reads `TimeCtl.is_dilated()` every frame and grades its
picture into the slow-motion look (`graphics/assets/shaders/picture_grade.gdshader`),
easing on the wall clock, since its own frame time is the dilated one.

## Autoloads

| Name | Module | What it is |
|---|---|---|
| `Loc` | app | every word, in the language being played |
| `Db` | app | the content database, `data/enigami.db` — the conversations, the state machines, the parts and the boards the game ships with, the menus, the lines that hang in the rooms and what grows on their floors, as tables — read-only |
| `Cues` | app | the seam |
| `Audio`, `AudioCues` | app | the sound bank — the files the `sounds` table lists and switches on, silent until one is made — and what each cue sounds like |
| `Pointer` | app | where the game is pointing and who is doing it — the player's hand, at the speed the setting asks, with the system's arrow hidden under it; the computer, with the arrow shown beside it; or the system alone, for a window |
| `Video` | app | whether the window takes the whole display, and whether an impact may move the camera |
| `Arena` | feature | the node live world objects are parented to |
| `TimeCtl` | feature | hitstop and dilation |
| `GameState` | feature | the profile, the stash, the raid in progress |
| `Sprites` | graphics | the atlas, sliced |
| `Fx` | graphics | shake, and the sparks, rings and floating numbers it lends out of its pools |
| `Views` | graphics | attaches views to gameplay nodes |
| `CueVisuals` | graphics | what each cue looks like |

`story/`, `circuit/` and `mobile/` add none. Story's nodes are spawned by
whatever stages them — `app/game.gd` for the intro, `Sandbox` for the bench —
and their views are attached by `Views` like any other. The circuit is classes
the rules make instances of. The console's input is a static class, `Touch`,
and its picture is built by `app/game.gd`. Keep it that way: an autoload is the
one thing a module's branch cannot add without touching `project.godot`.

`project.godot` is the one file any branch may need to touch — adding an
autoload, an input action, a collision layer or a global shader uniform. Its autoload block is grouped
by module so two additions rarely collide.
