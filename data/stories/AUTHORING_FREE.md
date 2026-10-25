# Writing a free story for Enigami

A guide for writing a **free** story file by hand, or for handing to a
language model so it writes one. Everything a free story can do is here;
nothing that is not here exists, so a story that uses only what is on this
page plays.

## What a free story is

A conversation between **the character** (an NPC) and **the player**, on a
map, while **the player goes on playing**. Nothing holds them. Each line
comes out in **a speech bubble over whoever says it** — the character's
head, or the player's — typing in a letter at a time, and once it has been
read it moves on by itself to the next. There is no portrait and no name
tab: the bubble's tail points at the speaker, and the emotion is in how the
letters move.

The player starts it by walking up close and pressing to talk; after that a
press up close only hurries it — brings the rest of a line out, or moves
past one that is out. A **question** is the one thing not said in a bubble:
the player is walked over to the character, held, and the box opens at the
top of the screen with the answers under the line; the answer given, the
player is let go and the talk goes on free from where the answer leads.

The character's voice carries **eight cells (256 px)**. The player walking
further than that in the middle of the talk cuts it off, and it is not
resumed: the next press up close starts the story over from `start`. When
the story reaches an end it falls quiet, and a press starts it again from
`start`, every time.

It is written as a graph of **nodes**. Each node is one beat: a line, its
emotion and how its letters move; what either of them does on stage as the
beat starts — a walk, a run, a pose, a turn; and where it leads — the next
node, a question whose answers each lead somewhere, or nowhere, which is
the end. Branches are made only by the player's answers: a story has no
variables, no conditions, no memory from one playing to the next.

## How it is used

1. Write one file, `data/stories/<id>.json`, where `<id>` is lowercase
   letters, digits and single underscores, at most 24 characters
   (`grove_watch`).
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
	"mode": "free",
	"name": "Grove Watch",
	"sprite": "elf_m",
	"player_name": "Knight",
	"spot": [12, 19],
	"start": "1",
	"nodes": { "1": { ... }, "2": { ... } }
}
```

| Key | Required | Values | Meaning |
|---|---|---|---|
| `map` | no | a map id | The map it plays on. Shipped: `moonlit_grove` (a grove at night, lanterns, ruins) and the raid rooms `raid_0_1` … `raid_4_4`. Left out or unknown, whichever map there is. |
| `mode` | yes | `free` | Always `free` for a story written from this page. |
| `name` | yes | text | The character's name. In a free story it is seen only on the box, when a question is asked. |
| `sprite` | yes | a character | What they look like; see **Sprites**. |
| `player_name` | yes | text | The player's name, likewise seen only on a question. |
| `spot` | no | `[x, y]` cells | Where the character stands on the map. Left out, along the floor from the player's start. |
| `start` | yes | a node id | The node a press starts. Must name a node. |
| `nodes` | yes | object | The nodes, by id. Ids are **numeric strings** — `"1"`, `"2"`, … |

### A node

```json
"3": {
	"at": [600, 60],
	"speaker": "npc",
	"text": "Careful on the left. The stone there is loose.",
	"emotion": "thinking",
	"hold": 2.5,
	"actions": [{"who": "npc", "do": "face", "dir": "left"}],
	"next": "4"
}
```

| Key | Values | Meaning |
|---|---|---|
| `at` | `[x, y]` | Where the node sits on the desk's sheet. Only the desk reads it. Lay nodes out left to right 280 apart and branches 160 apart down: `[40, 60]`, `[320, 60]`, `[600, 60]`; a branch under node 3 at `[600, 220]`. |
| `speaker` | `npc` · `player` | Whose head the bubble opens over. Default `npc`. |
| `text` | text | The line. A node with no `text` must have `actions` or `choices`. |
| `emotion` | see **Emotions** | How the letters move, unless `effect` says otherwise. Default `neutral`. |
| `effect` | `none` · `wave` · `shake` · `bounce` | How the letters move, overriding the emotion's own motion. |
| `speed` | letters per second | How fast the line types. Default 45. |
| `hold` | seconds | How long the bubble stays up once the line is all out, before the story moves on. Left out: 0.8 s plus one second per 22 letters, and never under 1.6 s. See **Timing**. |
| `actions` | list | What happens on stage as the node starts; see **Actions**. |
| `next` | a node id, or `""` | Where the story goes when the line has been read. Left out or `""`, the story ends here and falls quiet. |
| `choices` | list of `{"text", "next"}` | A question. The player is walked over and the box opens with the answers under the line, picked with up and down; the talk goes on free from the one given. The node leads by its answers and must not also have `next`. An answer with `"next": ""` ends the story. Every answer needs `text`. |

Directions a node may also carry:

| Key | Values | Meaning |
|---|---|---|
| `sfx` | `shoot` `zap` `slash` `hit` `explode` `jump` `dash` `hurt` `death` `pickup` `place` `erase` `ui` `deny` `extract` `parry` `boss` | A sound once, as the line starts. |
| `voice` | `low` · `mid` · `high` · `none` | The blip that plays while the line types. |
| `camera` | `{"focus": "npc"\|"player"\|"both", "zoom": 1.5, "shake": 6, "time": 0.4}` or `"reset"` | Read only while the box is open, so in a free story only on a **question** node. On any other node it is ignored: the camera stays the player's. |
| `sprite`, `name` | a character; text | Likewise read only on a question node, where the box has a portrait and a tab. A bubble has neither. |

## Emotions

A bubble has no face, so the emotion shows in the letters alone:

| `emotion` | Letters | Use it for |
|---|---|---|
| `neutral` | still | plain talk |
| `happy` | gentle ripple | warmth, jokes, greetings |
| `sad` | still | grief, regret |
| `angry` | tremble | anger, threats |
| `surprised` | still | shock, realisation |
| `thinking` | still | questions, hesitation, recall |
| `scared` | small tremble | fear, dread |

Since `sad`, `surprised` and `thinking` look like `neutral` in a bubble, put
their feeling in the words — or give the node an `effect`: `wave` ripples,
`shake` trembles, `bounce` hops each letter in turn, `none` holds them
still. On a question node, where the box opens, the emotion also picks the
portrait's expression.

## Actions

Each action is one thing one of them does as the node starts. A node may
have several; they start together, and the line types while they move.

```json
{"who": "npc", "do": "walk", "to": "player"}
{"who": "npc", "do": "run", "to": "left", "steps": 3}
{"who": "npc", "do": "pose", "pose": "hit"}
{"who": "player", "do": "face", "dir": "toward"}
```

| Key | Values | Meaning |
|---|---|---|
| `who` | `npc` · `player` | Who does it. |
| `do` | `walk` · `run` · `pose` · `face` | A walk (70 px/s), a run (150 px/s), a pose held, a turn. |
| `to` | `player` · `npc` · `left` · `right` | For a walk or run: toward the other, stopping 40 px short; or so many cells left or right. |
| `steps` | number | For `left`/`right`: how many cells. Default 2. |
| `pose` | see below | For `pose`: held until the talk is over, or the next pose. |
| `dir` | `left` · `right` · `toward` | For `face`: which way to turn; `toward` faces the other. |

Prefer to move **the character**. The player is free to walk, so a walk
given to the player fights whatever they are doing; a `face` on the player
is harmless, a `walk` or `run` is a surprise. If the player must be
somewhere for a beat, ask it in the words ("Come over here") rather than
walking them.

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

## Timing

Nothing waits for a press, so the story's pace is in the file.

- **A line stays up** for `hold` seconds after it has typed, or, left out,
  0.8 s plus a second per 22 letters, never under 1.6 s. A 40-letter line is
  up about 2.6 s after typing; typing itself is 45 letters a second. Raise
  `hold` on a line that should hang (a threat, a last word); lower it for a
  quick exchange.
- **A node with no `text`** — a staging beat — is over the moment it starts.
  Its actions start, no bubble opens, and the next node comes at once; the
  walk goes on under the next line. So a walk is given room by the line
  that follows it: a run of four cells takes about 1.7 s, a walk 3.6 s, and
  the line over it should hold at least that long.
- **Earshot.** Talk the player started goes on only while they stay within
  256 px of the character. A walk that takes the character away must stay
  inside that, or the player loses the thread.
- **A press** while a line is typing brings the rest out; a press while it
  is up moves on early. The player sets the pace faster, never slower.
- **A question stops everything**: the player is walked over, held, and the
  box opens. Use one when the branch matters; between questions keep the
  talk ambient.

## Writing well for the bubble

- **Line length.** A bubble is 280 px wide and at most four rows: keep a
  line under **~50 characters** (two rows). Longer lines wrap further and
  cover the scene; a line that needs more than four rows does not fit at
  all. Korean counts about double per character.
- **Answers.** Two to four per question, each under ~40 characters. The
  question's own line is in the box and may run to ~110 characters.
- **Short beats.** A free story is heard while playing: many short lines
  beat a few long ones. A speaker change opens a new bubble over the other
  head, which reads as a reply; use the player's lines for that.
- **Ends and loops.** Every branch ends on a node with no `next` and no
  `choices`, or leads back to a question. A node nothing leads to is a
  mistake. Remember that the whole story starts over on the next press, so
  write the `start` line as something the character could say again.
- **Hubs.** The common shape: a short greeting chain → a question → answers
  that each lead to a short chain of bubbles and back to the question → one
  answer that leads to a farewell with no `next`.
- **Language.** Text is shown as written; Korean, Japanese and Chinese
  render. JSON rules apply: escape a double quote as `\"`. One language per
  file — a story file is not translated.

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

It does not check `to`, `steps`, `pose`, `dir`, `sprite`, `map`, `hold` or
the sound ids: a wrong one is ignored or draws as the default. Use only the
values on this page.

## What a free story cannot do

- **No conditions, variables or memory.** It cannot ask whether the player
  did something, remember a past playing, or change what later lines say.
- **No waiting on the player.** Only a question holds them; nothing else
  waits for a press, an arrival, or anything they do.
- **Two parties only**, `npc` and `player`.
- **Nothing is given or taken**: no items, gold, parts, health, unlocks.
- **No music, no spawning, no changing the map.** The map is stood up empty
  and stays so.
- **It plays only from the desk**: title → STORY MAKER → LOAD → PLAY.

## A complete example

A watchman calls out as the player presses, keeps talking while they look
around, asks one question in the box, and goes on free from the answer.

```json
{
	"map": "moonlit_grove",
	"mode": "free",
	"name": "Grove Watch",
	"sprite": "elf_m",
	"player_name": "Knight",
	"spot": [14, 19],
	"start": "1",
	"nodes": {
		"1": {"at": [40, 60], "speaker": "npc", "text": "Hey. You. Keep off the moss.",
			"actions": [{"who": "npc", "do": "face", "dir": "toward"}], "next": "2"},
		"2": {"at": [320, 60], "speaker": "player", "text": "The moss?", "emotion": "thinking", "next": "3"},
		"3": {"at": [600, 60], "speaker": "npc", "text": "It glows when it's stepped on. Then they come.",
			"emotion": "scared", "hold": 3.0, "next": "4"},
		"4": {"at": [880, 60], "actions": [{"who": "npc", "do": "walk", "to": "left", "steps": 2}], "next": "5"},
		"5": {"at": [1160, 60], "speaker": "npc", "text": "Lost two lanterns to them last week.",
			"emotion": "sad", "hold": 3.5, "next": "6"},
		"6": {"at": [1440, 60], "speaker": "npc", "text": "You're not from the keep. So what are you here for?",
			"emotion": "thinking", "camera": {"focus": "both", "zoom": 1.4, "time": 0.5},
			"choices": [
				{"text": "Who are \"they\"?", "next": "7"},
				{"text": "Just passing through.", "next": "9"},
				{"text": "None of your business.", "next": "11"}
			]},
		"7": {"at": [1720, 20], "speaker": "npc", "text": "Small. Quick. Too many eyes.",
			"emotion": "scared", "effect": "shake", "next": "8"},
		"8": {"at": [2000, 20], "speaker": "npc", "text": "Stay in the lantern light and they don't bother you.",
			"hold": 3.0, "next": "6"},
		"9": {"at": [1720, 220], "speaker": "npc", "text": "Then pass quickly. And quietly.",
			"emotion": "happy", "next": "10"},
		"10": {"at": [2000, 220], "speaker": "player", "text": "Noted.", "hold": 1.6, "next": "6"},
		"11": {"at": [1720, 380], "speaker": "npc", "text": "Suit yourself.",
			"emotion": "angry", "actions": [{"who": "npc", "do": "face", "dir": "left"}], "next": "12"},
		"12": {"at": [2000, 380], "speaker": "npc", "text": "Mind the moss, all the same.",
			"emotion": "neutral", "hold": 2.5}
	}
}
```

Nodes `1`–`5` play in bubbles while the player is free to move; `4` is a
staging beat, over at once, and `5` holds long enough for the walk under
it. Node `6` is the question: the player is walked over and it opens in the
box, with the close-up. `8` and `10` lead back to it; `12` ends the story,
and the next press begins again at `1`.

## A brief to hand to a model

Paste this page, then something like:

> Write a free story file for Enigami in the format above. Character: a
> nervous goblin scout (`sprite`: `goblin`) in the Moonlit Grove who talks
> to the player while they explore. The player is called "Knight". About
> twelve nodes: a greeting the goblin could repeat, three or four short
> bubbles that keep going while the player moves (one over the player as a
> reply), one question in the box with three answers — one branch where the
> goblin walks off two cells and keeps talking, one friendly branch, one
> that ends it — every branch ending or returning to the question. Lines
> under 50 characters, answers under 40, a `hold` on any line that should
> linger, at least three emotions and one `effect`. Output only the JSON.

Then save the output as `data/stories/<id>.json` and run the checker.
