# Scene files

One file per directed scene, named after its id in lower case: the scene played
as `intro` reads `intro.json`. Edit these to change what the opening says, who
is on stage, where they walk, what they do and what it sounds like — no code
involved.

`tests/story/intro_test.tscn` checks every file here for misspelt directions,
people who are not in the cast, marks that do not exist and beats that do
nothing. Run it after an edit.

## The file

```json
{
	"floor": 420,
	"defaults": {"speed": 34, "voice": "low"},
	"marks": {
		"door":   [90, 420],
		"middle": [330, 420],
		"bench":  [520, 420]
	},
	"cast": {
		"you":    {"name": "Knight", "sprite": "player", "at": "door"},
		"tinker": {"name": "Old Tinker", "sprite": "wizzard_m", "at": "bench", "facing": "left"}
	},
	"beats": [
		{"text": "The seal held for a thousand years."},
		{"do": [{"move": "you", "to": "middle"}, {"sfx": "extract"}]},
		{"say": "tinker", "text": "You're late."}
	]
}
```

| Key | Meaning |
|---|---|
| `floor` | The y the stage floor sits at. Everyone stands on it. Default 420. |
| `marks` | Named places, `[x, y]`. Anywhere a direction names a place it can use one of these instead of writing the numbers out. |
| `cast` | Everyone who can appear, by the name the directions call them. |
| `defaults` | Keys every beat gets unless it sets them itself. Any beat key can go here. |
| `beats` | The scene, played top to bottom. |

## The cast

| Key | Meaning |
|---|---|
| `name` | The name on the tab when they speak. Defaults to their key. |
| `sprite` | Their character: one from the sprite atlas — `knight_m`, `wizzard_m`, `elf_f`… — or the game's own, `player`. An unknown one draws as the bystander fallback. |
| `at` | The mark they start on. **Leave it out and they start off stage**, waiting for an `enter`. |
| `facing` | `left` · `right`. Which way they start. Default `right`. |

## A beat

A beat is one press of the key. It can say something, do things, or both.

| Key | Values | Meaning |
|---|---|---|
| `text` | string | What is on screen for this beat. A beat with text waits for a press; one without moves on as soon as its directions finish. |
| `id` | string | A name for the beat, for another to lead to. |
| `next` | a beat's `id` | Where the beat leads once it is read. Leave it out to go on to the beat after it in the file; `""` ends the scene. |
| `choices` | list of `{"text", "next"}` | A question's answers, picked with up and down and given with the press. Where each leads is its `next`; one leading nowhere ends the scene. |
| `say` | a cast name | Who is saying it — puts their name on the tab. Leave it out for narration with nobody behind it. |
| `name` | string | Overrides the name on the tab for this beat. |
| `speed` | letters per second | How fast it types. Default 34. |
| `hold` | seconds | Waits this long after the beat's directions before it is done. |
| `do` | list of directions | Things that happen as the beat starts. They all start **together**. |
| `sfx` `voice` | see below | Sound for the beat itself, the same keys a dialogue line uses. |

A press part-way through the typing brings the rest of the line out at once. A
press after that cuts short anything the beat is still doing — a walk lands on
its mark — and moves on. **A press always makes something happen**, so a scene
can never be sat in front of, waiting.

`Esc` skips the whole scene.

## Directions

Each one is an object in `do`. The verb is also the name of whoever it is
about, so `{"move": "you", "to": "bench"}` reads as "move you to bench".

| Direction | Keys | What it does |
|---|---|---|
| `move` | `to` (a place), or `near` (a cast name) with `gap` (px short of them), or `by` (px along, left for less than nothing); `speed` (px/s, default 70) | Walks them there along the floor, facing the way they go. The beat waits until they arrive. |
| `place` | `at` (a place) | Puts them there at once, no walking. |
| `enter` | `at` (a place), and optionally `to` and `speed` | Brings someone on stage at `at`. With `to` they walk on from there. |
| `exit` | — | Takes them off stage. They stop being drawn. |
| `face` | `dir`: `left` · `right`, or `toward` (a cast name) | Turns them. |
| `anim` | `play`: `idle` · `run` · `hit` | Holds them in an animation until something else is asked for. `""` hands them back to walking and standing on their own. |
| `wait` | seconds, as the value | Holds the beat open this long. |
| `sfx` | a sound id, as the value | Plays it once. |
| `camera` | object, or `"reset"` | Where the camera goes — see below. |
| `fade` | `"in"` · `"out"`, and `time` | Fades the picture up from black or down to it. A scene opens on black, so the first beat usually fades `in`. |

Only the first five move anything. The rest are handed to the picture and the
sound bank untouched, which is why a new kind of direction is a key here and a
handler in `graphics/` — never a change to `feature/`.

### Camera

```json
{"camera": {"focus": "tinker", "zoom": 1.4, "shake": 6, "time": 0.6}}
```

| Key | Values | Meaning |
|---|---|---|
| `focus` | a cast name, a mark, or `[x, y]` | What to centre on. |
| `zoom` | 1 or more | How far in. Default 1. |
| `shake` | pixels | A shake as the beat starts. On its own it leaves the framing alone. |
| `time` | seconds | How long the move takes. 0 cuts. Default 0.4. |

`"camera": "reset"` eases back to the scene's own framing.

A `camera` at the top level of the file, beside `marks`, is where the camera
**rests** — the framing every direction moves away from and `"reset"` returns
to. Leave it out and the scene is framed on the middle of everywhere it names,
which is usually right; give it a `focus` and a `zoom` when it is not.

> A camera direction is a **one-shot move**, not a follow. Focusing on someone
> who is walking in the same beat frames where they set off, not where they end
> up — name the mark they are heading for instead.

### Sounds

Every sound is synthesised, so `sfx` names one from the bank in
`app/audio/audio.gd`: `shoot` `slash` `hit` `explode` `jump` `dash` `hurt`
`death` `pickup` `place` `erase` `ui` `deny` `extract` `parry` `boss` `voice`.
An unknown id plays nothing and warns in the output.

`voice` is the blip under the typing — `low` · `mid` · `high` · `none` — and
belongs on the beat rather than in `do`, the same as in a dialogue file.

## When the opening plays

`intro.json` is played once, in front of a profile's first hideout, and then
never again: `GameState.intro_seen` is written into the save the moment the
scene ends, however it ended. Wiping a profile earns it back.

To watch it again without wiping a save, run
`godot res://tests/story/intro_test.tscn`, or clear the flag from the
`user://enigami_save.json` the game keeps.

## Exporting

These are plain files, not resources: an export preset needs `data/scenes/*.json`
in its non-resource include filter, or the scenes will be missing from the build.
