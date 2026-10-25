# Writing a frozen story for Enigami

A guide for writing a **frozen** story file by hand, or for handing to a
language model so it writes one. Everything a frozen story can do is here;
nothing that is not here exists, so a story that uses only what is on this
page plays.

## What a frozen story is

A conversation between **the character** (an NPC) and **the player**, on a
map. The player walks up to the character and presses to talk; the game walks
them the last step over, holds them still, and the story runs in **the box at
the top of the screen**: a press per line, the character's portrait on the
left and the player's on the right, a question's answers picked with up and
down. When the story ends the player is let go.

It is written as a graph of **nodes**. Each node is one beat: a line somebody
says, with an expression and a motion in its letters; what either of them
does on stage as the beat starts — a walk, a run, a pose, a turn; and where
it leads — the next node, or a question whose answers each lead somewhere,
or nowhere, which is the end. A node can also be a beat of pure staging,
with nothing said.

The story can move the player (`actions` on the `player`): walk them over,
step them back, turn them away, sit them down. Branches are made only by
the player's answers: a story has no variables, no conditions, no memory
from one playing to the next. If a branch must "remember" something, lead
it along a different chain of nodes.

## How it is used

1. Write one file, `data/stories/<id>.json`, where `<id>` is lowercase
   letters, digits and single underscores, at most 24 characters
   (`old_tinker_2`).
2. In the game: title → **STORY MAKER** → **LOAD** → pick it → **PLAY**.
   `ESC` comes back to the desk, where the nodes show as a sheet and can be
   edited.
3. To check a file without playing it:
   `tests/run.sh tests/story/story_maker_test.tscn` reads every file in this
   folder and fails on the mistakes under **The checker**.

## The file

```json
{
	"map": "moonlit_grove",
	"mode": "frozen",
	"name": "Old Tinker",
	"sprite": "wizzard_m",
	"player_name": "Knight",
	"spot": [12, 19],
	"start": "1",
	"nodes": { "1": { ... }, "2": { ... } }
}
```

| Key | Required | Values | Meaning |
|---|---|---|---|
| `map` | no | a map id | The map it plays on. Shipped: `moonlit_grove` (a grove at night, lanterns, ruins) and the raid rooms `raid_0_1` … `raid_4_4`. Left out or unknown, whichever map there is. |
| `mode` | yes | `frozen` | Always `frozen` for a story written from this page. |
| `name` | yes | text | The character's name, on the tab when they speak. |
| `sprite` | yes | a character | What they look like; see **Sprites**. |
| `player_name` | yes | text | The name on the tab when the player speaks. |
| `spot` | no | `[x, y]` cells | Where the character stands on the map. Left out, along the floor from the player's start. |
| `start` | yes | a node id | Where the story begins. Must name a node. |
| `nodes` | yes | object | The nodes, by id. Ids are **numeric strings** — `"1"`, `"2"`, … |

### A node

```json
"4": {
	"at": [900, 20],
	"speaker": "npc",
	"text": "I tinker. Mostly with things that explode.",
	"emotion": "surprised",
	"effect": "shake",
	"actions": [{"who": "npc", "do": "pose", "pose": "hit"}],
	"next": "3"
}
```

| Key | Values | Meaning |
|---|---|---|
| `at` | `[x, y]` | Where the node sits on the desk's sheet. Only the desk reads it. Lay nodes out left to right 280 apart and branches 160 apart down: `[40, 60]`, `[320, 60]`, `[600, 60]`; a branch under node 3 at `[600, 220]`. |
| `speaker` | `npc` · `player` | Who says the line. Default `npc`. |
| `text` | text | The line, shown in the box. A node with no `text` must have `actions` or `choices`. |
| `emotion` | see **Emotions** | The portrait's expression, and how the letters move unless `effect` says otherwise. Default `neutral`. |
| `effect` | `none` · `wave` · `shake` · `bounce` | How the letters move, overriding the emotion's own motion. |
| `actions` | list | What happens on stage as the node starts; see **Actions**. |
| `next` | a node id, or `""` | Where a press leads. Left out or `""`, the story ends here. |
| `choices` | list of `{"text", "next"}` | A question: the answers stand under the line in the box, picked with up and down. The node leads by its answers and must not also have `next`. An answer with `"next": ""` ends the story. Every answer needs `text`. |

Directions a node may also carry, read by the picture and the sound:

| Key | Values | Meaning |
|---|---|---|
| `camera` | `{"focus": "npc"\|"player"\|"both", "zoom": 1.5, "shake": 6, "time": 0.4}` or `"reset"` | Moves the camera as the line starts; `shake` alone shakes without moving. A node without one leaves the camera where it was. The box brings black bars in, so a close-up reads well here. |
| `sfx` | `shoot` `zap` `slash` `hit` `explode` `jump` `dash` `hurt` `death` `pickup` `place` `erase` `ui` `deny` `extract` `parry` `boss` | A sound once, as the line starts. |
| `voice` | `low` · `mid` · `high` · `none` | The blip that plays while the line types. |
| `speed` | letters per second | How fast the line types. Default 45. |
| `sprite` | a character | Swaps the speaker's portrait for this line only. |
| `name` | text | Overrides the name on the tab for this line. |

## Emotions

| `emotion` | Portrait | Letters | Use it for |
|---|---|---|---|
| `neutral` | hops while talking | still | plain talk |
| `happy` | bigger hop, sparkles | gentle ripple | warmth, jokes, greetings |
| `sad` | cooled, still, a falling tear | still | grief, regret |
| `angry` | reddened, trembling, a vein | tremble | anger, threats |
| `surprised` | a big hop, an `!` | still | shock, realisation |
| `thinking` | still, `...` | still | questions, hesitation, recall |
| `scared` | pale, trembling, sweat | small tremble | fear, dread |

`effect` overrides the letters only: `wave` ripples, `shake` trembles,
`bounce` hops each letter in turn, `none` holds them still.

## Actions

Each action is one thing one of them does as the node starts. A node may
have several; they start together. In a frozen story **the line types while
they move**: a walk and its line happen at once, and a press moves on
whether or not the walk is done. For a walk the player should watch, give it
a node of its own with no `text` — a staging beat, over as soon as the
actions are done — and put the line on the node after.

```json
{"who": "player", "do": "walk", "to": "npc"}
{"who": "npc", "do": "run", "to": "left", "steps": 3}
{"who": "npc", "do": "pose", "pose": "hit"}
{"who": "player", "do": "face", "dir": "toward"}
```

| Key | Values | Meaning |
|---|---|---|
| `who` | `npc` · `player` | Who does it. The player is held still by the box, but the story may still move them. |
| `do` | `walk` · `run` · `pose` · `face` | A walk (slow), a run (fast), a pose held, a turn. |
| `to` | `player` · `npc` · `left` · `right` | For a walk or run: toward the other, stopping 40 px short; or so many cells left or right. |
| `steps` | number | For `left`/`right`: how many cells. Default 2. |
| `pose` | see below | For `pose`: held until the talk is over, or the next pose. |
| `dir` | `left` · `right` · `toward` | For `face`: which way to turn; `toward` faces the other. |

Poses a sprite has:

- Any atlas character: `idle`, `run`.
- These ten also have `hit` (a flinch, good for shock or a blow):
  `dwarf_f` `dwarf_m` `elf_f` `elf_m` `knight_f` `knight_m` `lizard_f`
  `lizard_m` `wizzard_f` `wizzard_m`.
- The player: `idle`, `run`, `crouch`, `hit`, `rise`, `fall`, `wall_slide`,
  `dash`, `hang`, `sit`.

## Sprites

`angel` `big_demon` `big_zombie` `chort` `doc` `dwarf_f` `dwarf_m` `elf_f`
`elf_m` `goblin` `imp` `knight_f` `knight_m` `lizard_f` `lizard_m`
`masked_orc` `ogre` `orc_shaman` `orc_warrior` `pumpkin_dude` `skelet`
`tiny_zombie` `wizzard_f` `wizzard_m` `wogol`, or `player`, the game's own
character. A name not on the list draws as `wizzard_m`.

## Writing well for the box

- **Line length.** The box is about 600 px wide in a pixel font: keep a
  line under ~110 characters (two rows). Long lines wrap; they read badly.
- **Answers.** Two to four per question, each under ~40 characters.
- **Pace.** One thought per node; a press is a beat. Put a reaction on its
  own node with its own emotion.
- **Staging reads.** Open with the player walked to the character (a
  staging node, then the first line); a `pose: hit` on a shock; `face: left`
  when someone turns away; a `camera` close-up on the line that matters.
- **Ends.** Every branch ends on a node with no `next` and no `choices`, or
  leads back to the question. A node nothing leads to is a mistake.
- **Hubs.** The common shape: a greeting chain → a question hub → answers
  that each lead to a short chain and back to the hub → one answer that
  leads to a farewell with no `next`.
- **Language.** Text is shown as written; Korean, Japanese and Chinese
  render. JSON rules apply: escape a double quote as `\"`. One language per
  file — a story file is not translated.
- **Names.** Refer to the player by `player_name` in the text if a name is
  needed; the character's `name` is the only other name the story has.

## The checker

`StoryMaker.problems_in` rejects, and `story_maker_test` fails on:

- a `mode` that is not `free` or `frozen`
- a `start` that names no node
- a node whose `speaker` is neither `npc` nor `player`
- a node that says nothing and does nothing (no `text`, no `actions`, no
  `choices`)
- an `emotion` not in the list above, or an `effect` not in its four
- an action whose `do` is not `walk`, `run`, `pose`, `face`
- a node with both `next` and `choices`
- an answer with empty `text`
- a `next` that names a node that is not there
- a node nothing leads to from `start`

It does not check `to`, `steps`, `pose`, `dir`, `sprite`, `map` or the sound
ids: a wrong one is ignored or draws as the default. Use only the values on
this page.

## What a frozen story cannot do

- **No conditions, variables or memory.** It cannot ask whether the player
  did something, remember a past playing, or change what later lines say.
- **Two parties only**, `npc` and `player`.
- **Nothing is given or taken**: no items, gold, parts, health, unlocks.
- **No music, no spawning, no changing the map.** The map is stood up empty
  and stays so.
- **It plays only from the desk**: title → STORY MAKER → LOAD → PLAY.

## A complete example

The player is walked up to a scared elf who has lost a light; a hub with
three answers, two of which loop back; an ending.

```json
{
	"map": "moonlit_grove",
	"mode": "frozen",
	"name": "Lantern Keeper",
	"sprite": "elf_f",
	"player_name": "Knight",
	"spot": [14, 19],
	"start": "1",
	"nodes": {
		"1": {"at": [40, 60], "actions": [{"who": "player", "do": "walk", "to": "npc"}], "next": "2"},
		"2": {"at": [320, 60], "speaker": "npc", "text": "Stop there. The lanterns — did you touch them?",
			"emotion": "scared", "actions": [{"who": "npc", "do": "face", "dir": "toward"}], "next": "3"},
		"3": {"at": [600, 60], "speaker": "player", "text": "I only just got here.", "next": "4"},
		"4": {"at": [880, 60], "speaker": "npc", "text": "Then one of them went out on its own. That has never happened.",
			"emotion": "thinking", "camera": {"focus": "both", "zoom": 1.4, "time": 0.6},
			"choices": [
				{"text": "Show me which one.", "next": "5"},
				{"text": "Lanterns go out. It's night.", "next": "8"},
				{"text": "I should go.", "next": "10"}
			]},
		"5": {"at": [1160, 20], "speaker": "npc", "text": "This way. Keep up.",
			"actions": [{"who": "npc", "do": "run", "to": "right", "steps": 4}], "next": "6"},
		"6": {"at": [1440, 20], "actions": [{"who": "player", "do": "run", "to": "npc"}], "next": "7"},
		"7": {"at": [1720, 20], "speaker": "npc", "text": "There. Cold as a stone, and the oil still in it.",
			"emotion": "sad", "effect": "none", "sfx": "place", "next": "4"},
		"8": {"at": [1160, 220], "speaker": "npc", "text": "Not these. I light them. I would know.",
			"emotion": "angry", "actions": [{"who": "npc", "do": "pose", "pose": "hit"}], "next": "9"},
		"9": {"at": [1440, 220], "speaker": "player", "text": "All right. All right. I believe you.",
			"emotion": "surprised", "next": "4"},
		"10": {"at": [1160, 380], "speaker": "npc", "text": "Go, then. If you see a light moving that should not be — run.",
			"emotion": "scared", "effect": "shake", "actions": [{"who": "npc", "do": "face", "dir": "left"}]}
	}
}
```

Nodes `1` and `6` are staging beats, a walk with no line, so the player sees
the move before the next line comes. Node `4` is the hub; `7` and `9` lead
back to it; `10` ends the story.

## A brief to hand to a model

Paste this page, then something like:

> Write a frozen story file for Enigami in the format above. Character: a
> suspicious goblin merchant (`sprite`: `goblin`) in the Moonlit Grove. The
> player is called "Knight". About twelve nodes: the player walked up to the
> goblin on a staging node, a greeting, a question hub with three answers —
> one hostile branch where the goblin runs off two steps and comes back, one
> friendly branch, one that ends it — every branch ending or returning to the
> hub. Use at least four different emotions, two `effect`s, and one `camera`
> close-up. Lines under 100 characters, answers under 40. Output only the
> JSON.

Then save the output as `data/stories/<id>.json` and run the checker.
