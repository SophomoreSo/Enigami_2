# Stories

Conversations written in the story maker (title → **STORY MAKER**), one file
each: `first_meeting.json` is the story `first_meeting`. SAVE writes them here
when the game is run from the project — the editor, or `godot --path` — and
what is here is committed and ships with the game. An exported game cannot
write into itself: it keeps the stories written on that machine under
`user://stories/`, and reads these as the ones it came with. `Stories`
(`story/rules/stories.gd`) is what knows where.

`first_meeting` is the Old Tinker met in the Moonlit Grove, with a question
in it, to play and to start from.

[AUTHORING.md](AUTHORING.md) points at the same format written for whoever
writes a story from outside the desk — by hand, or a language model handed
the page — one guide per way it is played, each complete on its own:
[AUTHORING_FROZEN.md](AUTHORING_FROZEN.md) for a conversation in the box,
[AUTHORING_FREE.md](AUTHORING_FREE.md) for talk in bubbles while the player
plays. Each has every value a key may take, what plays on screen, what the
checker refuses, and a worked example with staging, a hub and endings.

## The file

A story is a graph of nodes, each one beat of it, starting at `start` and
going along the links.

```json
{
	"map": "moonlit_grove",
	"mode": "frozen",
	"name": "Old Tinker",
	"sprite": "wizzard_m",
	"player_name": "Knight",
	"spot": [12, 19],
	"start": "1",
	"nodes": {
		"1": {"at": [40, 60], "speaker": "npc", "text": "So the seal let somebody through.",
			"emotion": "happy", "actions": [{"who": "npc", "do": "walk", "to": "player"}], "next": "2"},
		"2": {"at": [320, 60], "speaker": "npc", "text": "What would you like to know?",
			"choices": [{"text": "Who are you?", "next": "3"}, {"text": "Nothing.", "next": ""}]},
		"3": {"at": [600, 60], "speaker": "npc", "text": "I tinker.", "effect": "shake",
			"actions": [{"who": "npc", "do": "pose", "pose": "hit"}], "next": "2"}
	}
}
```

| Key | Meaning |
|---|---|
| `map` | The map it is set on, by id — one made in the map creator (`Maps`). Leave it out, or name one that is not there, and it is played on whichever map there is. |
| `mode` | How it is played: `free`, `frozen` or `novel` — see below. Default `frozen`. |
| `name` | The character's name, on the tab when they speak. |
| `sprite` | What they look like: one from the sprite atlas — `wizzard_m`, `knight_f`, `elf_m`… — or the game's own, `player`. |
| `player_name` | The name on the tab when the player speaks. |
| `spot` | The cell of the map the character stands in, `[x, y]`. Leave it out and they stand along the floor from the player's start. |
| `start` | The node the story starts at. |
| `nodes` | The nodes, by id — a number each, as the desk gives them. |

### A node

Every key but `at` is a property, and a node starts with none of them: on
the desk they are added one at a time under **+ PROPERTY** — the line
(`speaker` and `text`), the expression (`emotion`), the letters (`effect`),
an action (`actions`, as many as it takes), the answers (`choices`) — and
`next` is made by dragging a port. A node with none of them says nothing and
does nothing, and is passed straight through.

| Key | Meaning |
|---|---|
| `at` | Where it stands on the desk, `[x, y]`. Only the desk reads it. |
| `speaker` | Who says its line: `npc`, the character, or `player`. With `text`, the line. |
| `text` | What is said. A node with no line, or nothing in it, and something to do is a beat of staging, over as soon as it is done. |
| `emotion` | The expression: `neutral`, `happy`, `sad`, `angry`, `surprised`, `thinking`, `scared` — what the portrait does, and how the letters move. Leave it out for neutral. |
| `effect` | How the letters move, in place of what the expression does to them: `none` holds them still, `wave` ripples them, `shake` trembles them, `bounce` hops them in turn. Leave it out to let the expression move them. |
| `actions` | What anyone on stage does as the node starts, a list — see below. |
| `next` | The node it leads to. Leave it out, or `""`, to end the story there. |
| `choices` | A question's answers, each `text` and where it leads, `next`. A node with answers leads by them and has no `next`. An answer leading nowhere ends the story. An empty list is answers added with none written yet: no question, and it leads by `next`. |

Whatever else a node carries goes with it as a row of the conversation
tables would — a `camera`, a `sprite`, a `voice`, an `sfx` — read by the
picture and the sound bank the way a line in `data/db/dialogue/` is
(`data/db/README.md`, **A line**). A novel reads a node's `speed` and
`voice`.

### An action

| Key | Meaning |
|---|---|
| `who` | Who does it: `npc` or `player`. |
| `do` | `walk` or `run` somewhere, `pose` held, or `face` a way. |
| `to` | For a walk or a run: `player` or `npc`, up to the other, stopping a step short of them; or `left` or `right`, `steps` cells along. |
| `steps` | How many cells a walk left or right goes. Default 2. |
| `pose` | For a pose: one the sprite has — an atlas character's `idle`, `run` and sometimes `hit`; the player's `idle`, `run`, `crouch`, `hit`, `rise`, `fall`, `wall_slide`, `dash`, `hang` and `sit`. Held until the talk is over. |
| `dir` | For a turn: `left`, `right`, or `toward` the other. |

A walk starts as the node does. In a novel the node waits for it before its
line can be moved on from; in the box and free, the line types while they go.

## The three ways

| `mode` | What happens |
|---|---|
| `free` | The player goes on playing. The character talks free: a press up close starts the story, and each line comes out in a bubble over whoever says it, moving on by itself once it has been read. A question is asked in the box — the player walked over and held for the answer — and the story goes on free after it. |
| `frozen` | The player walks up and presses to talk, is walked the last step over and held still, and the story runs in the box at the top of the screen, a press a line, the answers to a question picked with up and down. |
| `novel` | Nobody plays. The two of them stand facing each other on the map, and the story is read like a scene, a press a line, in the panel along the foot of the screen, the answers picked there. `Esc` skips it. |

The map is stood up empty whichever way: no monster at its post, no box,
nothing to dig. The story is told the same way in all three — its nodes, along
its links — so a story written for one reads the same in the others.

A story written the old way, as a list of `lines`, still reads: it is a chain
of nodes, one leading to the next.

`tests/story/story_maker_test.tscn` checks every file here the way the dialogue
files are checked: a way of playing that is none, a start that names no node,
a node that says and does nothing, one said by nobody, an expression or a
motion nobody draws, an action that is none, a link to a node that is not
there, and a node nothing leads to. Run it after an edit by hand.

## Exporting

These are plain files, not resources: an export preset needs `data/*.json`
in its non-resource include filter — which takes this folder in with the
scenes — or the stories will be missing from the build.
