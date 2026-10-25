class_name StoryMaker
extends World

## The story maker: a conversation written as a graph of nodes, set on a map
## made in the map creator (`Maps`), and played on the spot in one of three
## ways (`Mode`).
##
## A node is one beat of the story, and starts with nothing: what it holds
## are properties (`PROPERTIES`), added one at a time and taken away the same
## way — a `line`, who says what, the character or the player; an `emotion`,
## the expression it is said with; an `effect`, a motion of the letters' own;
## any number of `action`s, what anyone on stage does as it starts (a walk or
## a run toward the other or a few cells along, a pose held, a turn); and
## `choices`, the answers that make it a question. Where it leads is no
## property: the `next` node, or where each answer goes, or nowhere, which is
## the end. A node with nothing to say and something to do is a beat of
## staging, over as soon as it is done; one with nothing at all is passed
## straight through. The story starts at `start` and plays along the links; a
## node nothing leads to is kept on the desk and never played.
##
## The three ways it is played:
##
##   FREE     the player goes on playing, and the character talks free: each
##            line in a bubble over whoever says it, moving on by itself once
##            it has been read (`FreeTalk`). A press up close starts it, or
##            hurries it along. A question is asked in the box — the player
##            walked over and held for the answer — and the story goes on
##            free after it.
##   FROZEN   the player walks up and presses to talk, is walked the last
##            step over and held still, and the story runs in the box, a
##            press a line, a question's answers picked there (`Npc`).
##   NOVEL    nobody plays. The two of them stand facing each other on the
##            map, and the story is read like a scene, a press a line, in the
##            panel along the foot of the screen, with the answers to a
##            question picked there (`Cutscene`).
##
## Whatever else a node is given goes with it on to the picture and the sound
## bank, the way a row of the conversation tables does: a `camera`, a
## `sprite`, a `voice`.
##
## Two things happen here, one at a time. A story is **written**: `add_node`
## and its kin change the graph, and SAVE keeps it as a file (`Stories`). Or
## it is **played**: the map is stood up — empty, with no monster at its post,
## no box and nothing to dig, since a conversation has nobody to fight — and
## the story is set going on it whichever way `mode` says, with a body in it
## for the player where there is one to play. Leaving play goes back to the
## desk, with the story as it was. The story on the desk is kept while the
## game runs: left for the title and come back to, it is as it was left,
## saved or not.
##
## Nothing here draws. `story/view/story_maker_view.gd` attaches itself to
## this node; the desk the story is written at is `story/view/story_desk.gd`.

signal exit_requested()
## The story went from being written to being played, or back.
signal playing_changed(on: bool)

## The ways a story is played.
enum Mode { FREE, FROZEN, NOVEL }
## Each by the id the file writes it as, in `Mode`'s order.
const MODE_IDS := ["free", "frozen", "novel"]
## Who says a line, and who an action is about.
const NPC := "npc"
const PLAYER := "player"
## What an action can be: a walk or a run (`to` the other, or `left` or
## `right` by `steps` cells), a `pose` held, or a turn (`dir`: left, right,
## or toward the other).
const DO := ["walk", "run", "pose", "face"]
const TO := ["player", "npc", "left", "right", "up", "down"]
const DIRS := ["left", "right", "up", "down", "toward"]
## How the letters of a line can move, beyond what its expression does to
## them: `none` holds them still. A node naming none of these moves them as
## its expression does. The picture draws each (`Style.TEXT_EFFECTS`).
const EFFECTS := ["none", "wave", "shake", "bounce"]
const NEW_STEPS := 2
## What a node may be given, in the order the desk offers them and shows them:
## a `line`, an `emotion`, an `effect`, any number of `action`s, and
## `choices`. A node starts with none of them.
const PROPERTIES := ["line", "emotion", "effect", "action", "choices"]
## What a property starts as once it is added: a face that is no face yet,
## letters that wave — a walk toward the other, and one answer with nothing in
## it yet, are `add_action`'s and `add_choice`'s own.
const NEW_EMOTION := "neutral"
const NEW_EFFECT := "wave"
## How fast a walk and a run go, in pixels a second, for a novel's cast.
const WALK_SPEED := 70.0
const RUN_SPEED := 150.0
## The id the character goes by while the story is played: what a free line
## said is counted under (`Facts.line`).
const CHARACTER := "STORY"
## The game's own character, as a scene file names it: what the player is
## drawn as in a novel.
const PLAYER_SPRITE := "player"
## What a new story's character is called and looks like, what they call the
## player — the bench's own, to start from — and how it plays.
const NEW_NAME := "Old Tinker"
const NEW_SPRITE := "wizzard_m"
const NEW_PLAYER_NAME := "Knight"
const NEW_MODE := Mode.FROZEN
## Where a new story's first node stands on the desk, and how far along a node
## put in after another stands from it.
const FIRST_AT := Vector2i(40, 60)
const ALONG := Vector2i(280, 0)
## How far across the floor from the player's start the character stands, in
## cells, for a story that says nowhere (`spot`): in sight, and out of talking
## range, so a walk over is the first thing that happens.
const APART := 4
## Seconds a novel takes to come up out of black, and how far in its camera
## stands: close enough that the two of them are the picture, as the intro
## is framed.
const FADE := 0.6
const NOVEL_ZOOM := 1.5
## What a line says when it does not say: what a line in the database would.
const LINE_SPEED := 45
const LINE_EMOTION := "neutral"
const LINE_VOICE := "low"

## The story on the desk from one visit to the next — see `_exit_tree`.
static var _kept: Dictionary = {}

## The name the story was last saved or opened under, or "" for one that never was.
var story_id: String = ""
## The map it is set on, by id (`Maps`); "" for whichever there is.
var map_id: String = ""
var mode: int = NEW_MODE
var npc_name: String = NEW_NAME
var sprite: String = NEW_SPRITE
var player_name: String = NEW_PLAYER_NAME
## The cell of the map the character stands in, or (-1, -1) for across the
## floor from the player's start.
var spot := Vector2i(-1, -1)
## The nodes, by id: each `at` on the desk, `speaker`, `text`, `emotion`,
## `effect`, `actions`, and `next` or `choices` — and whatever else it was
## given.
var nodes: Dictionary = {}
## The node the story starts at, or "" for none.
var start: String = ""
## Whether the story has changed since it was last saved or opened.
var unsaved: bool = false

var playing: bool = false
## The map stood up while the story is played, and who is in it: the player's
## body and the character, FREE or FROZEN; the scene, a NOVEL.
var room: MadeRoom = null
var player: Player = null
var npc: Npc = null
var scene: Cutscene = null
## weapon id -> the graph the body carries: a copy of the profile's, as on the bench.
var graphs: Dictionary = {}

## The id the next node put in gets: one past every id there is.
var _next_id: int = 1

func _ready() -> void:
	Arena.register(self)
	# Whoever stands on the map is drawn in the order of their feet down it.
	y_sort_enabled = true
	Cues.emit_cue(&"music_start")
	# Copies only: nothing played here reaches the hideout.
	for w in Weapons.ids():
		graphs[w] = GameState.weapon_board(String(w)).duplicate_board()
	if _kept.is_empty():
		new_story()
	else:
		_take(_kept)
		story_id = String(_kept.get("id", ""))
		unsaved = bool(_kept.get("unsaved", false))

## What is on the desk is kept for the next visit, whatever way this one ends.
func _exit_tree() -> void:
	_kept = story()
	_kept["id"] = story_id
	_kept["unsaved"] = unsaved

## Forgets the story kept from the last visit, so the next starts on a new one.
static func forget() -> void:
	_kept = {}

## --- the story --------------------------------------------------------------

## A story nobody has written anything in: no nodes, the bench's own character,
## set on whichever map there is, played in the box.
func new_story() -> void:
	story_id = ""
	map_id = ""
	mode = NEW_MODE
	npc_name = NEW_NAME
	sprite = NEW_SPRITE
	player_name = NEW_PLAYER_NAME
	spot = Vector2i(-1, -1)
	nodes = {}
	start = ""
	_next_id = 1
	unsaved = false

func node_count() -> int:
	return nodes.size()

func holds(id: String) -> bool:
	return nodes.has(id)

## Node `id` as it stands — the node itself, not a copy — or nothing for one
## there is not.
func node(id: String) -> Dictionary:
	return nodes.get(id, {})

## Every node's id, in the order they were put in.
func ids() -> PackedStringArray:
	var all: Array = nodes.keys()
	all.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	return PackedStringArray(all)

func text_of(id: String) -> String:
	return String(node(id).get("text", ""))

## Who says the node's line — the character's, for a node with none.
func speaker_of(id: String) -> String:
	return String(node(id).get("speaker", NPC))

## The node's expression — neutral, for a node that wears none.
func emotion_of(id: String) -> String:
	return String(node(id).get("emotion", LINE_EMOTION))

## The motion in the node's letters, or "" for its expression's own.
func effect_of(id: String) -> String:
	return String(node(id).get("effect", ""))

## Whether node `id` has a line: who says what, if only nothing yet.
func has_line(id: String) -> bool:
	return node(id).has("text")

## Whether node `id` has been given property `kind` (`PROPERTIES`). Answers
## are there once added, whether or not any is left to lead anywhere.
func has_property(id: String, kind: String) -> bool:
	var n := node(id)
	match kind:
		"line":
			return n.has("text")
		"emotion":
			return n.has("emotion")
		"effect":
			return n.has("effect")
		"action":
			return not (n.get("actions", []) as Array).is_empty()
		"choices":
			return n.has("choices")
	return false

## The properties node `id` has, in the order `PROPERTIES` tells them,
## whatever order they were added in; an action once, however many there are.
func properties_of(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for kind in PROPERTIES:
		if has_property(id, kind):
			out.append(kind)
	return out

## Whether property `kind` can be added to node `id`: one it does not have yet
## — or an action, of which it may have any number.
func can_add(id: String, kind: String) -> bool:
	return holds(id) and PROPERTIES.has(kind) and (kind == "action" or not has_property(id, kind))

## Adds property `kind` to node `id`, as it starts: a line said by whoever's
## turn it is (`_speaker_for`) with nothing said yet, a face that is none yet,
## letters that wave, a walk toward the other, one answer to write. Its place
## — an action's or an answer's among the node's, 0 for the rest — or -1 for
## one that cannot be added.
func add_property(id: String, kind: String) -> int:
	if not can_add(id, kind):
		return -1
	match kind:
		"line":
			nodes[id]["speaker"] = _speaker_for(id)
			nodes[id]["text"] = ""
		"emotion":
			nodes[id]["emotion"] = NEW_EMOTION
		"effect":
			nodes[id]["effect"] = NEW_EFFECT
		"action":
			return add_action(id)
		"choices":
			return add_choice(id)
	unsaved = true
	return 0

## Takes property `kind` off node `id`, whole: every action, every answer.
## Whether it had it.
func remove_property(id: String, kind: String) -> bool:
	if not has_property(id, kind):
		return false
	var n: Dictionary = nodes[id]
	match kind:
		"line":
			n.erase("speaker")
			n.erase("text")
		"emotion":
			n.erase("emotion")
		"effect":
			n.erase("effect")
		"action":
			n.erase("actions")
		"choices":
			n.erase("choices")
	unsaved = true
	return true

## Who a line put on node `id` is said by: the other of whoever says the line
## of the node that leads on to it, so a conversation goes turn and turn about
## — or whoever asked, for a node one of their answers leads to, since the
## answer was the other's; the character, with neither.
func _speaker_for(id: String) -> String:
	for other in ids():
		if not has_line(other):
			continue
		if next_of(other) == id:
			return PLAYER if speaker_of(other) == NPC else NPC
		for c in choices_of(other):
			if String((c as Dictionary).get("next", "")) == id:
				return speaker_of(other)
	return NPC

func at_of(id: String) -> Vector2i:
	var at = node(id).get("at", [0, 0])
	return Vector2i(int(at[0]), int(at[1])) if at is Array and (at as Array).size() == 2 else Vector2i.ZERO

func next_of(id: String) -> String:
	return String(node(id).get("next", ""))

func choices_of(id: String) -> Array:
	return node(id).get("choices", [])

func actions_of(id: String) -> Array:
	return node(id).get("actions", [])

## Whether `id` asks a question: it has answers, and they are where it leads.
func asks(id: String) -> bool:
	return not choices_of(id).is_empty()

## Puts a node in at `at` on the desk, and says its id: with no properties
## at all — or, given a `speaker` or a `text`, with a line, which a story
## written the old way, or by a test, comes with. The first node put in is
## where the story starts.
func add_node(at: Vector2i, speaker: String = "", text: String = "") -> String:
	var id := str(_next_id)
	_next_id += 1
	nodes[id] = {"at": [at.x, at.y]}
	if speaker != "" or text != "":
		nodes[id]["speaker"] = PLAYER if speaker == PLAYER else NPC
		nodes[id]["text"] = text
	if start == "":
		start = id
	unsaved = true
	return id

## Puts a node in after `after`, along from it on the desk, and leads `after`
## on to it where `after` led nowhere yet. With `with_line` it has a line, said
## by whoever's turn it is, so a conversation written straight on goes turn and
## turn about; without, nothing. The new node's id.
func add_node_after(after: String, with_line: bool = false) -> String:
	var id := add_node(at_of(after) + ALONG if holds(after) else FIRST_AT)
	if holds(after) and not asks(after) and next_of(after) == "":
		link(after, id)
	if with_line:
		add_property(id, "line")
	return id

## Takes node `id` off the desk, and off every link that led to it. Whether
## there was such a node.
func remove_node(id: String) -> bool:
	if not holds(id):
		return false
	nodes.erase(id)
	for other in nodes:
		var n: Dictionary = nodes[other]
		if String(n.get("next", "")) == id:
			n.erase("next")
		for c in n.get("choices", []):
			if String((c as Dictionary).get("next", "")) == id:
				(c as Dictionary).erase("next")
	if start == id:
		start = ""
	unsaved = true
	return true

func move_node(id: String, at: Vector2i) -> bool:
	if not holds(id):
		return false
	if at_of(id) != at:
		nodes[id]["at"] = [at.x, at.y]
		unsaved = true
	return true

## Changes what node `id` says, giving it a line first where it has none.
func set_text(id: String, text: String) -> bool:
	if not holds(id):
		return false
	if not has_line(id):
		add_property(id, "line")
	if text_of(id) != text:
		nodes[id]["text"] = text
		unsaved = true
	return true

## Gives node `id`'s line to `speaker`. A node with no line has nobody to give.
func set_speaker(id: String, speaker: String) -> bool:
	if not holds(id) or not has_line(id) or (speaker != NPC and speaker != PLAYER):
		return false
	if speaker_of(id) != speaker:
		nodes[id]["speaker"] = speaker
		unsaved = true
	return true

## Gives node `id` to the other of the two.
func toggle_speaker(id: String) -> bool:
	return set_speaker(id, PLAYER if speaker_of(id) == NPC else NPC)

## The node's expression: one of the emotions the picture draws, which the
## database declares (`emotions`) — neutral among them. Set where it has none,
## it is added; `remove_property` takes it away.
func set_emotion(id: String, emotion: String) -> bool:
	if not holds(id) or not emotions().has(emotion):
		return false
	_set_or_clear(id, "emotion", emotion)
	return true

## The motion in the node's letters: one of `EFFECTS`. Set where it has none,
## it is added; `remove_property` takes it away, and the letters move as the
## expression asks.
func set_effect(id: String, effect: String) -> bool:
	if not holds(id) or not EFFECTS.has(effect):
		return false
	_set_or_clear(id, "effect", effect)
	return true

func _set_or_clear(id: String, key: String, value: String) -> void:
	var n: Dictionary = nodes[id]
	if String(n.get(key, "")) == value:
		return
	if value == "":
		n.erase(key)
	else:
		n[key] = value
	unsaved = true

## Leads node `id` on to `to`, or nowhere for "". Not to itself, which would
## go round for ever, and not from a question, whose answers are where it leads.
func link(id: String, to: String) -> bool:
	if not holds(id) or to == id or asks(id) or (to != "" and not holds(to)):
		return false
	_set_or_clear(id, "next", to)
	return true

## Gives node `id` an answer, and makes it a question: its `next` goes, the
## answers being where it leads from now on. The answer's place.
func add_choice(id: String, text: String = "") -> int:
	if not holds(id):
		return -1
	var n: Dictionary = nodes[id]
	if not n.has("choices"):
		n["choices"] = []
	n.erase("next")
	(n["choices"] as Array).append({"text": text})
	unsaved = true
	return (n["choices"] as Array).size() - 1

func set_choice_text(id: String, i: int, text: String) -> bool:
	var c := _choice(id, i)
	if c.is_empty():
		return false
	if String(c.get("text", "")) != text:
		c["text"] = text
		unsaved = true
	return true

## Leads answer `i` of node `id` on to `to`, or nowhere for "".
func link_choice(id: String, i: int, to: String) -> bool:
	var c := _choice(id, i)
	if c.is_empty() or (to != "" and not holds(to)):
		return false
	if String(c.get("next", "")) != to:
		if to == "":
			c.erase("next")
		else:
			c["next"] = to
		unsaved = true
	return true

## Takes answer `i` off node `id`. With no answer left it is no question,
## and leads on by its `next` again; its answers are still there to write,
## until `remove_property` takes them away.
func remove_choice(id: String, i: int) -> bool:
	if _choice(id, i).is_empty():
		return false
	var all: Array = nodes[id]["choices"]
	all.remove_at(i)
	unsaved = true
	return true

func _choice(id: String, i: int) -> Dictionary:
	var all := choices_of(id)
	if i < 0 or i >= all.size() or not all[i] is Dictionary:
		return {}
	return all[i]

## Gives node `id` something to do as it starts: `who` does `do` — a walk
## toward the other, say. The action's place.
func add_action(id: String, who: String = NPC, do: String = "walk") -> int:
	if not holds(id) or not DO.has(do):
		return -1
	var n: Dictionary = nodes[id]
	if not n.has("actions"):
		n["actions"] = []
	var a := {"who": PLAYER if who == PLAYER else NPC, "do": do}
	_fit_action(a)
	(n["actions"] as Array).append(a)
	unsaved = true
	return (n["actions"] as Array).size() - 1

## Changes one thing about action `i` of node `id`: its `who`, its `do`, where
## a walk goes (`to`, and `steps` along), the `pose` held, or the way faced
## (`dir`). A value that is none of what that key takes is refused.
func set_action(id: String, i: int, key: String, value) -> bool:
	var a := _action(id, i)
	if a.is_empty():
		return false
	match key:
		"who":
			if value != NPC and value != PLAYER:
				return false
		"do":
			if not DO.has(value):
				return false
		"to":
			if not TO.has(value):
				return false
		"dir":
			if not DIRS.has(value):
				return false
		"steps":
			value = maxi(int(value), 1)
		"pose":
			if String(value) == "":
				return false
		_:
			return false
	if a.get(key, null) == value:
		return true
	a[key] = value
	_fit_action(a)
	unsaved = true
	return true

func remove_action(id: String, i: int) -> bool:
	if _action(id, i).is_empty():
		return false
	var all: Array = nodes[id]["actions"]
	all.remove_at(i)
	if all.is_empty():
		nodes[id].erase("actions")
	unsaved = true
	return true

func _action(id: String, i: int) -> Dictionary:
	var all := actions_of(id)
	if i < 0 or i >= all.size() or not all[i] is Dictionary:
		return {}
	return all[i]

## An action with what its kind needs and nothing else: a walk has somewhere
## to go, a pose a pose, a turn a way.
static func _fit_action(a: Dictionary) -> void:
	match String(a.get("do", "")):
		"walk", "run":
			a.erase("pose")
			a.erase("dir")
			if not TO.has(String(a.get("to", ""))):
				a["to"] = TO[0]
			if String(a["to"]) == "left" or String(a["to"]) == "right":
				a["steps"] = maxi(int(a.get("steps", NEW_STEPS)), 1)
			else:
				a.erase("steps")
		"pose":
			for key in ["to", "steps", "dir"]:
				a.erase(key)
			if String(a.get("pose", "")) == "":
				a["pose"] = "idle"
		"face":
			for key in ["to", "steps", "pose"]:
				a.erase(key)
			if not DIRS.has(String(a.get("dir", ""))):
				a["dir"] = "toward"

func set_start(id: String) -> bool:
	if not holds(id):
		return false
	if start != id:
		start = id
		unsaved = true
	return true

## The nodes the story reaches from its start, in the order it first comes to
## them: what is played.
func reachable() -> PackedStringArray:
	var out := PackedStringArray()
	if not holds(start):
		return out
	var queue: Array = [start]
	var seen := {start: true}
	while not queue.is_empty():
		var id: String = queue.pop_front()
		out.append(id)
		var leads: Array = []
		if asks(id):
			for c in choices_of(id):
				leads.append(String((c as Dictionary).get("next", "")))
		else:
			leads.append(next_of(id))
		for to in leads:
			if to != "" and holds(to) and not seen.has(to):
				seen[to] = true
				queue.append(to)
	return out

## Whether there is anything to play: a node the story reaches with something
## to say.
func has_lines() -> bool:
	for id in reachable():
		if text_of(id).strip_edges() != "":
			return true
	return false

## The expressions a node may wear: the emotions the database declares, which
## are the ones the picture draws.
static func emotions() -> PackedStringArray:
	var out := PackedStringArray()
	for r in Db.rows("SELECT id FROM emotions ORDER BY rowid"):
		out.append(String(r["id"]))
	if out.is_empty():
		out.append(LINE_EMOTION)
	return out

func set_mode(m: int) -> void:
	m = clampi(m, 0, MODE_IDS.size() - 1)
	if m != mode:
		mode = m
		unsaved = true

## The mode by its id in the file. Whether it was one.
func set_mode_id(id: String) -> bool:
	var m := MODE_IDS.find(id)
	if m < 0:
		return false
	set_mode(m)
	return true

func mode_id() -> String:
	return MODE_IDS[mode]

func set_map(id: String) -> void:
	if id != map_id:
		map_id = id
		unsaved = true

func set_npc_name(called: String) -> void:
	if called != npc_name:
		npc_name = called
		unsaved = true

func set_sprite(art: String) -> void:
	if art != sprite:
		sprite = art
		unsaved = true

func set_player_name(called: String) -> void:
	if called != player_name:
		player_name = called
		unsaved = true

func set_spot(cell: Vector2i) -> void:
	if cell != spot:
		spot = cell
		unsaved = true

## The map the story would be played on: its own, where that is kept, else the
## first there is; "" with none kept anywhere.
func map_to_play() -> String:
	if map_id != "" and Maps.exists(map_id):
		return map_id
	var ids := Maps.ids()
	return String(ids[0]) if not ids.is_empty() else ""

## --- keeping ----------------------------------------------------------------

## The story as a file has it: what SAVE writes, and what `_take` reads.
func story() -> Dictionary:
	var out := {"map": map_id, "mode": mode_id(), "name": npc_name, "sprite": sprite,
		"player_name": player_name, "start": start, "nodes": nodes.duplicate(true)}
	if spot.x >= 0 and spot.y >= 0:
		out["spot"] = [spot.x, spot.y]
	return out

## Puts a story as a file has it on the desk, squared off: a mode that is not
## one is the new story's, a node's speaker one of the two, its place a pair of
## whole numbers, an action what its kind needs, a link to a node that is not
## there no link. A story written the old way, as a list of `lines`, is a
## chain of nodes, one leading to the next.
func _take(s: Dictionary) -> void:
	map_id = String(s.get("map", ""))
	var m := String(s.get("mode", MODE_IDS[NEW_MODE]))
	mode = MODE_IDS.find(m) if MODE_IDS.has(m) else NEW_MODE
	npc_name = String(s.get("name", NEW_NAME))
	sprite = String(s.get("sprite", NEW_SPRITE))
	player_name = String(s.get("player_name", NEW_PLAYER_NAME))
	spot = Vector2i(-1, -1)
	var at = s.get("spot", null)
	if at is Array and (at as Array).size() == 2:
		spot = Vector2i(int(at[0]), int(at[1]))
	nodes = {}
	start = ""
	_next_id = 1
	var given = s.get("nodes", null)
	if given is Dictionary:
		for id in given:
			if not (given[id] is Dictionary):
				continue
			nodes[String(id)] = _squared(given[id])
			_next_id = maxi(_next_id, int(String(id)) + 1)
		for id in nodes:
			var n: Dictionary = nodes[id]
			if n.has("next") and not holds(String(n["next"])):
				n.erase("next")
			for c in n.get("choices", []):
				if (c as Dictionary).has("next") and not holds(String(c["next"])):
					(c as Dictionary).erase("next")
		start = String(s.get("start", ""))
		if not holds(start):
			var all := ids()
			start = all[0] if not all.is_empty() else ""
	else:
		var lines = s.get("lines", [])
		var last := ""
		for l in (lines if lines is Array else []):
			var line: Dictionary = l if l is Dictionary else {"text": String(l)}
			var id := add_node(FIRST_AT + ALONG * nodes.size(), String(line.get("speaker", NPC)), String(line.get("text", "")))
			for key in line:
				if not nodes[id].has(key):
					nodes[id][key] = line[key]
			if last != "":
				link(last, id)
			last = id

## A node as the file gave it, with what every node has and nothing wrong.
static func _squared(given: Dictionary) -> Dictionary:
	var n := given.duplicate(true)
	var at = n.get("at", [0, 0])
	n["at"] = [int(at[0]), int(at[1])] if at is Array and (at as Array).size() == 2 else [0, 0]
	# A line is a speaker and words: either one there is the line, the other
	# filled; neither, no line.
	if n.has("text") or n.has("speaker"):
		n["speaker"] = PLAYER if String(n.get("speaker", NPC)) == PLAYER else NPC
		n["text"] = String(n.get("text", ""))
	if n.has("next"):
		n["next"] = String(n["next"])
	if String(n.get("emotion", "")) == "":
		n.erase("emotion")
	elif n.has("emotion"):
		n["emotion"] = String(n["emotion"])
	if not EFFECTS.has(String(n.get("effect", ""))):
		n.erase("effect")
	var given_choices = n.get("choices", null)
	if given_choices is Array:
		var choices: Array = []
		for c in given_choices:
			if c is Dictionary:
				var kept := {"text": String(c.get("text", ""))}
				if String(c.get("next", "")) != "":
					kept["next"] = String(c["next"])
				choices.append(kept)
			elif c is String:
				choices.append({"text": String(c)})
		# Answers added are kept with none left in them: the property is there.
		n["choices"] = choices
		if not choices.is_empty():
			n.erase("next")
	else:
		n.erase("choices")
	var actions: Array = []
	var given_actions = n.get("actions", [])
	for a in (given_actions if given_actions is Array else []):
		if a is Dictionary and DO.has(String(a.get("do", ""))):
			var kept: Dictionary = (a as Dictionary).duplicate()
			kept["who"] = PLAYER if String(kept.get("who", NPC)) == PLAYER else NPC
			_fit_action(kept)
			actions.append(kept)
	if actions.is_empty():
		n.erase("actions")
	else:
		n["actions"] = actions
	return n

## Keeps the story as `called` (`Stories.save`). "" once it is kept, and
## otherwise why it was not, as an id for the desk to spell: `name` for a
## name with nothing in it to file a story under, `write` for a file that
## could not be written.
func save_as(called: String) -> String:
	var id := Stories.id_for(called)
	if id == "":
		return "name"
	if Stories.save(id, story()) != OK:
		return "write"
	story_id = id
	unsaved = false
	return ""

## Puts the story `id` on the desk in place of the one there. Whether there
## was such a story.
func open(id: String) -> bool:
	var found := Stories.load_story(id)
	if found.is_empty():
		return false
	_take(found)
	story_id = id
	unsaved = false
	return true

## Mistakes in the story that would otherwise show up as one that plays
## wrong, phrased the way `Dialogue.problems` phrases them.
func problems() -> Array:
	return problems_in(story())

## The same check against a story as a file has it — so the checker can be put
## in front of a broken one without a broken file having to live in the
## project: a way of playing that is none of the three, a start that names no
## node, a node that says and does nothing, one said by nobody, an expression
## or a motion nobody draws, an action that is none, a link to a node that is
## not there, and a node nothing leads to. A story written the old way is
## read as `_take` reads it.
static func problems_in(s: Dictionary) -> Array:
	var found: Array = []
	var m := String(s.get("mode", MODE_IDS[NEW_MODE]))
	if not MODE_IDS.has(m):
		found.append("mode '%s' is none of %s" % [m, ", ".join(MODE_IDS)])
	var given = s.get("nodes", null)
	if not given is Dictionary:
		var lines = s.get("lines", [])
		if not lines is Array or (lines as Array).is_empty():
			return found + ["no lines"]
		for i in (lines as Array).size():
			var l = lines[i]
			if l is Dictionary:
				var who := String(l.get("speaker", NPC))
				if who != NPC and who != PLAYER:
					found.append("line %d is said by '%s', who is neither %s nor %s" % [i + 1, who, NPC, PLAYER])
			elif not l is String:
				found.append("line %d is not a line" % (i + 1))
		return found
	var all: Dictionary = given
	if all.is_empty():
		return found + ["no lines"]
	var start_id := String(s.get("start", ""))
	if not all.has(start_id):
		found.append("start -> %s" % start_id)
	var moods := emotions()
	var led := {}
	for id in all:
		var n = all[id]
		var at := "node %s" % id
		if not n is Dictionary:
			found.append("%s is not a node" % at)
			continue
		var who := String(n.get("speaker", NPC))
		if who != NPC and who != PLAYER:
			found.append("%s is said by '%s', who is neither %s nor %s" % [at, who, NPC, PLAYER])
		var actions = n.get("actions", [])
		if not actions is Array:
			actions = []
		var asked = n.get("choices", [])
		if String(n.get("text", "")).strip_edges() == "" and (actions as Array).is_empty() \
				and not (asked is Array and not (asked as Array).is_empty()):
			found.append("%s says nothing and does nothing" % at)
		if n.has("emotion") and not moods.has(String(n["emotion"])):
			found.append("%s wears '%s', which nobody draws" % [at, n["emotion"]])
		if n.has("effect") and not EFFECTS.has(String(n["effect"])):
			found.append("%s moves its letters '%s', which is none of %s" % [at, n["effect"], ", ".join(EFFECTS)])
		for a in actions:
			if not a is Dictionary or not DO.has(String((a as Dictionary).get("do", ""))):
				found.append("%s does something that is none of %s" % [at, ", ".join(DO)])
		var choices = n.get("choices", [])
		if not choices is Array:
			choices = []
		var links: Array = []
		if not (choices as Array).is_empty():
			if String(n.get("next", "")) != "":
				found.append("%s has both a next node and answers — the answers win" % at)
			for c in choices:
				if not c is Dictionary or String((c as Dictionary).get("text", "")).strip_edges() == "":
					found.append("%s has an answer with no text" % at)
					continue
				links.append(String((c as Dictionary).get("next", "")))
		else:
			links.append(String(n.get("next", "")))
		for to in links:
			if to == "":
				continue
			if not all.has(to):
				found.append("%s -> %s" % [at, to])
			else:
				led[to] = true
	for id in all:
		if String(id) != start_id and not led.has(String(id)):
			found.append("node %s is led to by nothing" % id)
	return found

## --- what is played ---------------------------------------------------------

## The character, as `Dialogue.character` would read one out of the database
## and an `Npc` takes one (`Npc.setup_with`): every node the story reaches, in
## the box as `nodes` from `start`, each leading on or asking its question, and
## free as `rules`, the first answering a press and each leading on, so the
## story is told the same way whichever way it is played.
func character() -> Dictionary:
	var box := {}
	var rules := {}
	var played := reachable()
	for id in played:
		var row := _as_row(id)
		box[id] = row
		var rule := row.duplicate(true)
		rule["once"] = 0
		if id == start:
			rule["listens"] = FreeTalk.TALK
		if String(rule.get("text", "")) == "":
			# Nothing to read: a beat of staging goes by as soon as it has started.
			rule["hold"] = 0.0
		rules[id] = rule
	var def := {"id": CHARACTER, "name": npc_name, "sprite": sprite, "player_name": player_name,
		"nodes": box, "rules": rules}
	if not played.is_empty():
		def["start"] = start
	return def

## Node `id` as a row of the conversation tables: what it says and who says
## it, saying what a line in the database would where it does not say itself,
## where it leads, what it does, and whatever else it was given carried
## through.
func _as_row(id: String) -> Dictionary:
	var row: Dictionary = node(id).duplicate(true)
	row.erase("at")
	row["id"] = id
	row["text"] = text_of(id).strip_edges()
	row["speaker"] = speaker_of(id)
	if not row.has("speed"):
		row["speed"] = LINE_SPEED
	if not row.has("emotion"):
		row["emotion"] = LINE_EMOTION
	if not row.has("voice"):
		row["voice"] = LINE_VOICE
	if asks(id):
		row.erase("next")
	elif String(row.get("next", "")) == "":
		row.erase("next")
	return row

## The story as a directed scene (`Cutscene.handed`), for a NOVEL: the
## character standing at `npc_at` and the player at `player_at` on the floor,
## facing each other with the camera in close on them, and a beat a node — the
## start first, bringing the picture up out of black, each leading on by id or
## asking its question, and doing as its actions say.
func scene_script(npc_at: Vector2, player_at: Vector2) -> Dictionary:
	var beats: Array = []
	for id in reachable():
		var row := _as_row(id)
		var beat := {"id": id, "say": row["speaker"], "text": row["text"], "speed": row["speed"],
			"voice": row["voice"], "emotion": row["emotion"]}
		if row.has("effect"):
			beat["effect"] = row["effect"]
		if asks(id):
			beat["choices"] = row["choices"]
		else:
			beat["next"] = String(row.get("next", ""))
		var directions := _directions(actions_of(id))
		if beats.is_empty():
			directions.push_front({"fade": "in", "time": FADE})
		if not directions.is_empty():
			beat["do"] = directions
		beats.append(beat)
	var toward := player_at - npc_at
	return {
		"camera": {"zoom": NOVEL_ZOOM},
		"marks": {NPC: [npc_at.x, npc_at.y], PLAYER: [player_at.x, player_at.y]},
		"cast": {
			NPC: {"name": npc_name, "sprite": sprite, "at": NPC, "facing": way_word(toward)},
			PLAYER: {"name": player_name, "sprite": PLAYER_SPRITE, "at": PLAYER,
				"facing": way_word(-toward)},
		},
		"beats": beats,
	}

## The way `v` goes, as a scene's words: the one of the four it goes most
## along, and right for nowhere at all.
static func way_word(v: Vector2) -> String:
	if v == Vector2.ZERO:
		return "right"
	if absf(v.y) > absf(v.x):
		return "down" if v.y > 0.0 else "up"
	return "right" if v.x > 0.0 else "left"

## A node's actions as a scene's directions: a walk or a run is a `move` up
## near the other, or `by` so many cells along; a pose is an `anim` held; a
## turn is a `face`, left, right or toward the other.
static func _directions(actions: Array) -> Array:
	var out: Array = []
	for a in actions:
		var who := String(a.get("who", NPC))
		var other := PLAYER if who == NPC else NPC
		match String(a.get("do", "")):
			"walk", "run":
				var d := {"move": who, "speed": RUN_SPEED if String(a["do"]) == "run" else WALK_SPEED}
				var to := String(a.get("to", TO[0]))
				if Npc.WAYS.has(to):
					var v: Vector2 = (Npc.WAYS[to] as Vector2) * float(int(a.get("steps", NEW_STEPS)) * Room.CELL)
					d["by"] = [v.x, v.y]
				else:
					d["near"] = other
					d["gap"] = Npc.TALK_SPOT
				out.append(d)
			"pose":
				out.append({"anim": who, "play": String(a.get("pose", "idle"))})
			"face":
				var dir := String(a.get("dir", "toward"))
				if dir == "toward":
					out.append({"face": who, "toward": other})
				else:
					out.append({"face": who, "dir": dir})
	return out

## --- playing ----------------------------------------------------------------

## Stands the map up and sets the story going on it. "" once it is, and
## otherwise why not, as an id for the desk to spell: `empty` for a story with
## nothing in it to say, `map` for no map to play it on.
func play() -> String:
	if playing:
		return ""
	if not has_lines():
		return "empty"
	var stage := Maps.load_room(map_to_play())
	if stage == null:
		return "map"
	playing = true
	_stand(stage)
	playing_changed.emit(true)
	return ""

## Back to the desk: the map and everyone on it goes, and the story is as it was.
func stop() -> void:
	if not playing:
		return
	_strike()
	playing = false
	# A scene makes itself the world while it runs; this is the world again.
	Arena.register(self)
	playing_changed.emit(false)

## Whether a novel is being read: a scene is up, and not over.
func reading() -> bool:
	return playing and scene != null and is_instance_valid(scene) and not scene.done

func _stand(stage: MadeRoom) -> void:
	room = stage
	if mode != Mode.NOVEL:
		player = Player.new()
		player.collision_layer = 2
		player.collision_mask = 1
		add_child(player)
		_arm()
		room.player = player
	add_child(room)
	room.build(Vector2i.ZERO, _empty_record(room), {}, 0)
	var at := room.spawn_point()
	var post := _post(room, at)
	if mode == Mode.NOVEL:
		scene = Cutscene.new()
		scene.scene_id = "story"
		scene.own_stage = false
		scene.handed = scene_script(post, at)
		scene.finished.connect(stop)
		add_child(scene)
		return
	player.room = room
	player.global_position = at
	player.velocity = Vector2.ZERO
	npc = Npc.new()
	npc.setup_with(character())
	npc.mode = Npc.Mode.FREE if mode == Mode.FREE else Npc.Mode.FREEZE
	npc.free_story = mode == Mode.FREE
	npc.collision_layer = 0
	npc.collision_mask = 1
	npc.position = post
	add_child(npc)

## The map's record with nothing in it to fight or find: a conversation's
## stage, not a raid's room.
static func _empty_record(stage: MadeRoom) -> Dictionary:
	var rec := stage.record()
	rec["enemies"] = []
	rec["loot"] = []
	rec["digs"] = []
	rec.erase("box")
	return rec

## Where the character stands: in the cell the story says, where the map has
## room to stand in it; otherwise on the floor APART cells across from the
## player's start — to the right where there is floor, else to the left, and
## as far as the floor goes; and with no floor to either side, on the start.
func _post(stage: MadeRoom, at: Vector2) -> Vector2:
	if _standable(stage, spot):
		return stage.stand_point(spot)
	var from := Vector2i(int(floor(at.x / Room.CELL)), int(floor(at.y / Room.CELL)))
	for side: int in [1, -1]:
		var found := Vector2i(-1, -1)
		var c := from
		for i in APART:
			c.x += side
			if not _standable(stage, c):
				break
			found = c
		if found.x >= 0:
			return stage.stand_point(found)
	return at

## Room to stand in cell `c`: open floor, and no pit.
static func _standable(stage: MadeRoom, c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= stage.cols or c.y >= stage.rows:
		return false
	return not stage.is_solid(c.x, c.y) and not stage.is_pit(c.x, c.y)

## A kit's worth off the rack, as the bench hands one out.
func _arm() -> void:
	var all := Weapons.ids()
	var kit: Array = []
	var boards: Array = []
	for k in mini(Player.MAX_WEAPONS, all.size()):
		kit.append(all[k])
		boards.append(graphs[String(kit[k])])
	player.setup_kit(kit, boards, 0)

func _strike() -> void:
	Attacks.clear_in_flight(self)
	for n: Node in [player, npc, scene, room]:
		if n == null or not is_instance_valid(n):
			continue
		if n is Player:
			# Out of the hunt now rather than at the end of the frame.
			n.remove_from_group("player")
		# Nothing being struck gets another turn (`Raid._enter_room`).
		n.process_mode = Node.PROCESS_MODE_DISABLED
		n.queue_free()
	player = null
	npc = null
	scene = null
	room = null

## The character in talking range, with something to say.
func use_nearby() -> bool:
	return npc != null and is_instance_valid(npc) and npc.answers_press()

func leave() -> void:
	exit_requested.emit()
