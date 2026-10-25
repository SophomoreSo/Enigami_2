class_name Npc
extends CharacterBody2D

## Someone to talk to, in one of two ways.
##
## **In the box** — `Mode.FREEZE`. Walk up and press interact, and the last
## step is walked for the player: to where people stand to talk, turned to face
## them (`_come_over`). Pushing the other way on that step is changing your
## mind, and nothing opens. Once they are there a conversation starts; each
## further press brings out the rest of the line coming in, or, with the line
## out, moves it on. Some lines end in a question — move up and down
## to pick an answer, interact to give it — and the answer decides what they
## say next. The player is held still while they listen — no walking, dashing
## or attacking — so a conversation ends by talking it through, or by
## something else carrying the player out of range.
##
## **Free** — `Mode.FREE`. What is said comes out in a bubble over whoever is
## saying it, and the player goes on playing: nothing is held, a line moves on
## by itself once it has been read, and a press up close only hurries it. It is
## never a fixed path. Every line is a rule that an event gets when the facts
## are right (see `FreeTalk`), and walking out of earshot in the middle of talk
## the player started cuts it off — to be picked up again next time.
##
## A press starts whichever `mode` says. What they notice — the player coming
## into earshot, a dash, a blow — they answer free in either mode, whenever
## their rules have something to say about it. Nothing here is drawn:
## `story/view/npc_view.gd`, `dialogue_box.gd` and `speech_bubble.gd` show it.
##
## They stand on the floor seen from above, as every body does: where they are
## is their feet, and they face any way on it (`facing`), turning to whoever is
## close enough to talk to. A line may direct the stage as it starts
## (`actions`, see `direct`): a walk or a run of theirs or the player's, a pose
## held until the talk is over, a turn. The story maker writes those; a line of
## the database's has none.
##
## What each NPC says lives in the content database, as rows under their id
## (see `Dialogue`, and `data/db/README.md`) — or is handed in, written
## somewhere else, in the same shape (`setup_with`).
##
## An NPC is deliberately not an Actor. Attacks find their targets through the
## "actors" group, so a bystander outside it can stand in the line of fire
## without ever being hit.

signal line_started(npc: Npc, node_id: String)
signal choice_made(npc: Npc, node_id: String, index: int)
signal conversation_ended(npc: Npc)

## What a press of interact starts: the conversation in the box, or free talk.
enum Mode { FREEZE, FREE }

## How wide they are, and how tall their art stands: the body the picture is
## stood on. On the floor they take up their width, and a little over half of
## it deep (`Actor._make_body`).
const BODY := Vector2(18.0, 28.0)
## How close the player has to stand for a press to count, centre to centre.
const TALK_RANGE := 64.0
## Where the player stands to talk in the box, centre to centre, on whichever
## side of them they came from: near enough to talk, and far enough apart that
## the two of them never stand inside each other.
const TALK_SPOT := 40.0
## How far a free talker's voice carries, centre to centre. They notice what the
## player does inside it, and talk the player started goes on only while the
## player stays in it: eight cells, far enough to try a move out in front of
## them.
const EARSHOT := 256.0
## Letters a line reveals per second, unless it sets its own `speed`. A press
## while one is still coming in finishes it rather than skipping it unread.
const REVEAL_RATE := 45.0
## Letters that make no sound as they type.
const QUIET := " .,!?;:'\"-…()"
## How fast a walk and a run a line asks of them go, in pixels a second, and
## how near where it is going is there — wider than a pixel, since a walk is
## stepped in whole frames.
const WALK_SPEED := 70.0
const RUN_SPEED := 150.0
const ARRIVE := 3.0
## How hard a walk pushes the player's body: a stroll, against a run's whole push.
const WALK_PACE := 0.45
## The four ways a line can send somebody, or turn them, by name.
const WAYS := {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}

var npc_id: String = "SAGE"
var display_name: String = ""
## The whole dialogue file, as `Dialogue` read it.
var data: Dictionary = {}
var nodes: Dictionary = {}
var start: String = ""
## The way they face on the floor, a unit vector. They turn to whoever is close
## enough to talk to.
var facing: Vector2 = Vector2.RIGHT
## The side they were last turned to, 1 right and -1 left, for art drawn side
## on to be mirrored by when they face straight up or down the screen.
var _side: int = 1
var body_size: Vector2 = BODY
## The node being said, or "" when nobody is talking.
var node_id: String = ""
## How many letters of the current line are out so far.
var revealed: float = 0.0
## Which answer is highlighted while a question is open.
var selected: int = 0
## True while the player stands close enough to talk.
var in_range: bool = false
## True while the player is close enough to hear them talk free.
var in_earshot: bool = false
## What a press starts. A character with no conversation in the box talks free;
## whoever stages them may say otherwise, since which way a character talks
## where is the game's to decide.
var mode: int = Mode.FREEZE
## Their free talk, in either mode: see `FreeTalk`.
var free_talk: FreeTalk
## What the view must play regardless of motion — a pose a line holds them in
## (`direct`) — or "" to let the view choose from how fast they are moving.
var forced_anim: String = ""
## Whether a story told free asks its questions in the box: a line with
## answers walks the player over and opens there, and the answer given, the
## talk goes on free from where it leads. The story maker sets it.
var free_story: bool = false
## Which way a line turned them, or zero for none: while one holds they do not
## turn back to the player of their own accord.
var _faced: Vector2 = Vector2.ZERO
## A walk a line asked of them: where to, how fast, and whether it is under way.
var _walk_to: Vector2 = Vector2.ZERO
var _walk_speed: float = 0.0
var _walking: bool = false
## A walk a line asked of the player, on the player's own line; null between.
var _story_walk: WalkTo = null
## The player being talked to, held still until the conversation ends.
var _listener: Player = null
## The walk bringing the player over to talk, from the press until they get
## here or change their mind; null the rest of the time. And the line it
## opens on once they are here: the start, or a question asked mid free talk.
var _approach: WalkTo = null
var _approach_to: String = ""

func setup(id: String) -> void:
	npc_id = id
	_take(Dialogue.character(id))

## Someone handed their conversation rather than reading it: `def` in the
## shape `Dialogue.character` reads one into — their name and sprite, `nodes`
## and a `start` for the box, `rules` for free talk — for a character written
## somewhere other than the database: the story maker's.
func setup_with(def: Dictionary) -> void:
	npc_id = String(def.get("id", npc_id))
	_take(def)

func _take(def: Dictionary) -> void:
	data = def
	display_name = String(data.get("name", npc_id))
	nodes = data.get("nodes", {})
	start = String(data.get("start", ""))
	mode = Mode.FREEZE if start != "" else Mode.FREE
	free_talk = FreeTalk.new(npc_id, data)
	free_talk.started.connect(_on_free_line)

func _ready() -> void:
	if data.is_empty():
		setup(npc_id)
	add_to_group("npcs")
	# On a floor seen from above nothing falls: the body slides where it is
	# pushed, and stops against what it meets.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(body_size.x, body_size.x * 0.6)
	shape.shape = rect
	add_child(shape)

func _physics_process(delta: float) -> void:
	_walk()
	move_and_slide()

	var player := _player()
	# Wherever the player's hands are: their own body, or a monster they are in.
	var away := INF if player == null else global_position.distance_to(player.vessel().global_position)
	var was_in_earshot := in_earshot
	in_range = away <= TALK_RANGE
	in_earshot = away <= EARSHOT
	if _faced == Vector2.ZERO and not _walking and (in_range or (free_talk.is_talking() and in_earshot)):
		face(player.vessel().global_position - global_position)
	if is_talking():
		# Walking off mid-sentence is how a player says they are done listening
		# — unless it is the line walking one of them, which is not that.
		if not in_range and not _walking and not _player_walking():
			end_conversation()
		elif current_line() == "" and not is_choosing() and not _walking and not _player_walking():
			# Nothing to read: a beat of staging is over once what it does is done.
			_go(String(current_node().get("next", "")))
		else:
			var before := int(revealed)
			revealed = minf(revealed + reveal_rate() * delta, float(current_line().length()))
			_announce_letters(before)
	_talk_free(delta, player, was_in_earshot)
	if _approach != null:
		_mind_approach(player)
	if not in_range or player.input_locked or not _nearest(player):
		return
	if is_choosing():
		if Input.is_action_just_pressed("move_up"):
			move_selection(-1)
		if Input.is_action_just_pressed("move_down"):
			move_selection(1)
	if Input.is_action_just_pressed("interact"):
		if mode == Mode.FREEZE or is_talking():
			interact()
		elif answers_press() and not player.talk_locked:
			free_talk.press()

## Free talk, every frame: whether they can hear the game at all, the player
## coming into earshot or walking out of it, and the line being said moving on.
func _talk_free(delta: float, player: Player, was_in_earshot: bool) -> void:
	# A conversation in the box has all of the player's attention, theirs or
	# anybody's: free talk holds its tongue until it is over.
	var hushed := player == null or player.talk_locked
	free_talk.listening = in_earshot and not hushed
	if hushed:
		free_talk.cut()
		return
	if in_earshot and not was_in_earshot:
		free_talk.hear(FreeTalk.NEAR)
	elif was_in_earshot and not in_earshot and free_talk.is_talking() and free_talk.asked:
		# Walking off is how a player says they are done listening. What they
		# walked out on was never said, so it is what comes up again.
		free_talk.cut()
		free_talk.hear(FreeTalk.LEAVE)
	var saying := free_talk.line_id
	var before := int(free_talk.revealed)
	free_talk.step(delta)
	if saying != "" and free_talk.line_id == saying:
		_blip(free_talk.current_line(), free_talk.current_rule(), before, int(free_talk.revealed),
			free_speaker().global_position)
	elif saying != "" and free_talk.line_id == "" and _approach == null and not is_talking():
		# The talk is over: a pose it held them in, and a turn, are let go of.
		_clear_directions()

## Whether a press of interact here would get an answer: in the box, always;
## free, while a line is being said, or while there is something to say.
func answers_press() -> bool:
	if not in_range:
		return false
	if mode == Mode.FREEZE or is_talking():
		return true
	return free_talk.is_talking() or free_talk.would_answer(FreeTalk.TALK)

## Whoever is saying the free line: the player, or them.
func free_speaker() -> Node2D:
	if free_talk.speaker() == "player":
		var player := _player()
		if player != null:
			return player.vessel()
	return self

## A free line starting. The cue carries the whole rule, the way the box's
## carries its line, so the sound bank plays what the rule names. A line of
## a story told free that asks a question is not said free at all: the
## player is walked over, and it opens in the box, where answers are picked.
func _on_free_line(rule_id: String) -> void:
	var rule := free_talk.current_rule()
	if free_story and not (rule.get("choices", []) as Array).is_empty():
		free_talk.cut()
		_come_over(rule_id)
		return
	direct(rule.get("actions", []))
	Cues.at(&"talk", free_speaker().global_position, {"npc": npc_id, "rule": rule_id, "line": rule})

## Two NPCs in reach of the player: the nearer one hears the press.
func _nearest(player: Player) -> bool:
	var at := player.vessel().global_position
	var mine := global_position.distance_to(at)
	for n in get_tree().get_nodes_in_group("npcs"):
		if n != self and n is Npc and (n as Npc).in_range \
				and (n as Npc).global_position.distance_to(at) < mine:
			return false
	return true

## One press of interact: come over to talk, finish the line coming in, give
## the highlighted answer, move on to the next line, or — where there is none —
## stop.
func interact() -> void:
	if not is_talking():
		_come_over()
		return
	if not line_finished():
		revealed = float(current_line().length())
		return
	if not choices().is_empty():
		choose(selected)
		return
	_go(String(current_node().get("next", "")))

## Gives answer `index` to the question now open. In a story told free, the
## answer given, the talk goes on free from where it leads.
func choose(index: int) -> void:
	if not is_choosing() or index < 0 or index >= choices().size():
		return
	var from := node_id
	var to := String(choices()[index].get("next", ""))
	choice_made.emit(self, from, index)
	if free_story:
		end_conversation()
		if to != "" and free_talk.rules.has(to):
			free_talk.say(to)
		return
	_go(to)

## Moves the highlight, wrapping at either end so the last answer is one press
## away from the first.
func move_selection(step: int) -> void:
	if not is_choosing():
		return
	selected = wrapi(selected + step, 0, choices().size())
	Cues.emit_cue(&"ui", {"kind": "arm"})

## Puts the highlight on answer `index`: an answer picked by pointing at it —
## its plate, on the glass — rather than stepped to. It gives nothing; `choose`
## and `interact` do that.
func select(index: int) -> void:
	if not is_choosing() or index < 0 or index >= choices().size() or index == selected:
		return
	selected = index
	Cues.emit_cue(&"ui", {"kind": "arm"})

## A press to talk. The player is walked over to where people stand to talk,
## `TALK_SPOT` out on the side they are on — whichever way across the floor
## that is — and turned to face them, and the conversation opens once they are
## there — on `start`, or on the line `to` names; for one standing there
## already it opens at once. The walk goes on the player's own input line,
## after anything that holds them, and it is theirs to refuse: a push the
## other way takes the body back, and nothing opens.
func _come_over(to: String = "") -> void:
	var player := _player()
	if player == null or _approach != null:
		return
	_approach_to = to if to != "" else start
	# The walk goes on the player's line, which drives whichever body their
	# hands are in, so it is that body that is walked over.
	var body := player.vessel()
	var away := body.global_position - global_position
	if away.length() < 0.5:
		# Standing right on them: back off the way they are not facing.
		away = -body.facing
	var spot := global_position + away.normalized() * TALK_SPOT
	if body.global_position.distance_to(spot) <= WalkTo.THERE:
		_go(_approach_to)
		return
	_approach = WalkTo.new(spot, -away.normalized())
	player.input.add(_approach)

## The walk over, each frame: they are here, and the conversation opens; or it
## ended without them — they pushed the other way, something carried them off,
## a screen came up over the game.
func _mind_approach(player: Player) -> void:
	if _approach.arrived and player != null and in_range:
		_approach = null
		_go(_approach_to)
	elif _approach.done or player == null or not in_range or player.input_locked:
		_approach.cancel()
		_approach = null

## --- what a line directs ----------------------------------------------------

## Carries out a line's `actions` as it starts: each `who` — `npc`, them, or
## `player` — does `do`. A `walk` or a `run` goes `to` the other, stopping
## `TALK_SPOT` short of them on the side it comes from, or `left`, `right`,
## `up` or `down` so many `steps` of the room's cells; theirs is their own, the
## player's goes on the player's line (`WalkTo`), as the walk over to talk does,
## and is theirs to refuse. A `pose` is held until the talk is over
## (`forced_anim`). A `face` turns them `left`, `right`, `up`, `down` or
## `toward` the other, and they stay turned. The story maker writes these
## (`StoryMaker.DO`).
func direct(actions: Array) -> void:
	var player := _player()
	for a in actions:
		if not a is Dictionary:
			continue
		var mine := String(a.get("who", "npc")) != "player"
		var theirs: Node2D = player.vessel() if player != null else null
		var body: Node2D = self if mine else theirs
		var other: Node2D = theirs if mine else self
		if body == null:
			continue
		match String(a.get("do", "")):
			"walk", "run":
				var run := String(a["do"]) == "run"
				var spot := body.global_position
				var to := String(a.get("to", "player"))
				if WAYS.has(to):
					spot += (WAYS[to] as Vector2) * float(maxi(int(a.get("steps", 1)), 1)) * Room.CELL
				elif other != null:
					var toward := other.global_position - body.global_position
					if toward == Vector2.ZERO:
						toward = Vector2.RIGHT
					spot = other.global_position - toward.normalized() * TALK_SPOT
				if mine:
					walk_to(spot, RUN_SPEED if run else WALK_SPEED)
				else:
					_walk_player(player, spot, run)
			"pose":
				if mine:
					forced_anim = String(a.get("pose", ""))
				else:
					player.forced_anim = String(a.get("pose", ""))
			"face":
				var way := Vector2.ZERO
				var dir := String(a.get("dir", "toward"))
				if WAYS.has(dir):
					way = WAYS[dir]
				elif other != null:
					way = other.global_position - body.global_position
				if way != Vector2.ZERO:
					body.face(way)
					if mine:
						_faced = way.normalized()

## Walks them to `spot`, at `speed`, facing the way they go.
func walk_to(spot: Vector2, speed: float = WALK_SPEED) -> void:
	_walk_to = spot
	_walk_speed = maxf(speed, 1.0)
	_walking = true

func stop_walk() -> void:
	_walking = false
	velocity = Vector2.ZERO

func walking() -> bool:
	return _walking

## A step of a walk a line asked of them, before the body moves.
func _walk() -> void:
	if not _walking:
		velocity = Vector2.ZERO
		return
	var gap := _walk_to - global_position
	if gap.length() <= ARRIVE:
		# Right where it was going, not near it, so a walk lands the same every time.
		global_position = _walk_to
		stop_walk()
	else:
		velocity = gap.normalized() * _walk_speed
		face(gap)

## The player walked to `spot` for a line: a stroll, or a run's whole push.
func _walk_player(player: Player, spot: Vector2, run: bool) -> void:
	_cancel_story_walk()
	_story_walk = WalkTo.new(spot)
	_story_walk.pace = 1.0 if run else WALK_PACE
	player.input.add(_story_walk)

func _player_walking() -> bool:
	return _story_walk != null and not _story_walk.done

func _cancel_story_walk() -> void:
	if _story_walk != null and not _story_walk.done:
		_story_walk.cancel()
	_story_walk = null

## Lets go of everything a line directed: the pose, the turn, a walk still under way.
func _clear_directions() -> void:
	forced_anim = ""
	_faced = Vector2.ZERO
	stop_walk()
	_cancel_story_walk()
	var player := _player()
	if player != null:
		player.forced_anim = ""

## Whether the player is being walked over to talk.
func approaching() -> bool:
	return _approach != null

func end_conversation() -> void:
	if not is_talking():
		return
	_release_listener()
	_clear_directions()
	node_id = ""
	revealed = 0.0
	selected = 0
	conversation_ended.emit(self)

## The cue carries the whole line, so whatever it says about how it looks and
## sounds reaches the picture and the sound bank without this reading it.
func _go(to: String) -> void:
	if to == "":
		end_conversation()
		return
	if not nodes.has(to):
		push_warning("NPC %s has no dialogue node '%s'" % [npc_id, to])
		end_conversation()
		return
	node_id = to
	revealed = 0.0
	selected = 0
	if _listener == null:
		_listener = _player()
		if _listener != null:
			_listener.talk_locked = true
			# Face to face, whichever way they were standing — and in whichever
			# body.
			var body := _listener.vessel()
			body.face(global_position - body.global_position)
	direct(current_node().get("actions", []))
	Cues.at(&"talk", global_position, {"npc": npc_id, "node": to, "line": current_node()})
	line_started.emit(self, node_id)

## An NPC taken away mid-sentence must not leave the player frozen, nor
## walking over to talk to nobody.
func _exit_tree() -> void:
	if _approach != null:
		_approach.cancel()
		_approach = null
	_cancel_story_walk()
	_release_listener()

func _release_listener() -> void:
	if _listener != null and is_instance_valid(_listener):
		_listener.talk_locked = false
	_listener = null

## Letters coming out are a moment a voice can blip along with. At most one a
## frame, so a fast line is a patter rather than a buzz, and never for spaces or
## punctuation.
func _announce_letters(before: int) -> void:
	_blip(current_line(), current_node(), before, int(revealed), global_position)

## The same for any line, box or free: `text` came out from letter `from` up to
## `to`, said at `at`, and `line` is the row it came from.
func _blip(text: String, line: Dictionary, from: int, to: int, at: Vector2) -> void:
	for i in range(from, mini(to, text.length())):
		if i % 2 == 0 and not QUIET.contains(text[i]):
			Cues.at(&"talk_letter", at, {"npc": npc_id, "line": line, "index": i})
			return

func is_talking() -> bool:
	return node_id != ""

func current_node() -> Dictionary:
	return nodes.get(node_id, {})

func current_line() -> String:
	return String(current_node().get("text", ""))

## The part of the current line revealed so far.
func visible_text() -> String:
	return current_line().left(int(revealed))

func line_finished() -> bool:
	return int(revealed) >= current_line().length()

## Letters per second for the current line.
func reveal_rate() -> float:
	return maxf(float(current_node().get("speed", REVEAL_RATE)), 1.0)

## Who says the current line: "npc" or "player".
func speaker() -> String:
	return String(current_node().get("speaker", "npc"))

func speaker_name() -> String:
	var node := current_node()
	if node.has("name"):
		return String(node["name"])
	if speaker() == "player":
		return String(data.get("player_name", Loc.t("hud.dialogue.player")))
	return display_name

## The answers the current line offers; empty when it is not a question.
func choices() -> Array:
	return current_node().get("choices", [])

## True once a question has been asked in full and is waiting for an answer.
## Answers cannot be picked while the question is still coming in.
func is_choosing() -> bool:
	return is_talking() and line_finished() and not choices().is_empty()

## Whether a press on a plain line brings up another line rather than ending.
func has_more() -> bool:
	return is_talking() and choices().is_empty() and String(current_node().get("next", "")) != ""

## Turns them to face `dir` on the floor; nothing for no way at all.
func face(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	facing = dir.normalized()
	if facing.x != 0.0:
		_side = 1 if facing.x > 0.0 else -1

## The side they are turned to: 1 right, -1 left (`Actor.side`).
func side() -> int:
	return _side

## Which of a character's facings shows the way they face: down, up or side
## (`Actor.facing_name`).
func facing_name() -> String:
	return Actor.face_name_of(facing)

## The player, as long as they are staying. A world being swapped out is freed
## at the end of the frame, and until then its player is still in the group:
## the world coming in would otherwise meet them for a frame, standing wherever
## they stood in the old one — and a free talker would greet somebody who is
## not there.
func _player() -> Player:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and not p.dead and not _leaving(p):
			return p
	return null

static func _leaving(n: Node) -> bool:
	while n != null:
		if n.is_queued_for_deletion():
			return true
		n = n.get_parent()
	return false
