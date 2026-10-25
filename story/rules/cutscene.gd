class_name Cutscene
extends Node2D

## Plays a directed scene out of `data/scenes/<id>.json` — the prologue, and
## anything else that wants to move people about and be read a line at a time.
## The format is in `data/scenes/README.md`; `CutsceneScript` reads the file.
##
## What happens here is the sequencing and the staging: whose turn it is to
## speak, how far the line has typed, who is walking where on the floor the
## stage is — seen from above, so a mark is a point on it and a walk goes any
## way across it — and when a beat is done with. A beat may lead on to another by its `id` (`next`), or ask a
## question whose `choices` each lead somewhere — the story maker's novels
## branch that way; the prologue's beats go one after the other, as beats
## naming no `next` do. What any of it looks or sounds like is not decided
## here.
## Directions this module has no use for — `anim`, `sfx`, `camera`, `fade` — go
## out untouched on the `scene_direction` cue for the picture and the sound bank
## to answer, which is what lets a writer add a new kind of direction without a
## line changing in `feature/`.
##
## Nothing is drawn here: `story/view/cutscene_view.gd` shows the stage and
## the narration, and `story/view/cutscene_actor_view.gd` shows the cast.

signal finished()
## A beat started. The index is into `beats`, so a view can tell a new beat from
## a re-read of the same one.
signal beat_started(index: int)

## Letters a second when a beat does not say.
const REVEAL_RATE := 34.0
## Letters that make no sound while typing, so a voice does not click on spaces.
const QUIET := " .,!?;:'\"-…()"

var scene_id: String = "intro"
## A scene handed in rather than read: set before the node enters the tree,
## in the shape `CutsceneScript.scene` reads a file into, and played in place
## of `scene_id`'s file — the story maker's, written at its desk.
var handed: Dictionary = {}
## Whether the scene is a stage of its own, which its picture draws a floor
## for. One staged on a floor that is there already — a made map's — is not,
## and its cast stand on that.
var own_stage: bool = true
## The whole file, kept for the picture to read its own keys out of, exactly as
## an `Npc` keeps its dialogue file. The rules take `marks`, `cast` and `beats`
## out of it below and never look at the rest.
var data: Dictionary = {}
## Everyone in the scene, by their name in the file.
var cast: Dictionary = {}
var marks: Dictionary = {}
var beats: Array = []

## Which beat is playing, -1 before the first and beats.size() once it is over.
var index: int = -1
## Which answer is highlighted while a question is open.
var selected: int = 0
## beat id -> its place in `beats`, for a beat that leads on by id.
var _by_id: Dictionary = {}
## How much of the current beat's line has been typed.
var revealed: float = 0.0
var done: bool = false

## Cast members the beat running now told to walk, so the beat knows when they
## have all arrived.
var _moving: Array[CutsceneActor] = []
## Seconds the beat running now is still waiting out — a `wait` direction, or
## the beat's own `hold`.
var _wait_left: float = 0.0

func _ready() -> void:
	Arena.register(self)
	# The cast are drawn in the order of their feet down the floor, as every
	# body is.
	y_sort_enabled = true
	var def := handed if not handed.is_empty() else CutsceneScript.scene(scene_id)
	data = def
	if def.is_empty():
		# A missing file must not strand the player on a black screen with
		# nothing to press: the scene is simply over.
		_finish()
		return
	marks = def.get("marks", {})
	beats = def.get("beats", [])
	for i in beats.size():
		if beats[i] is Dictionary and (beats[i] as Dictionary).has("id"):
			_by_id[String(beats[i]["id"])] = i
	_build_cast(def.get("cast", {}))
	# The stage is standing but no beat has run yet. A view is attached as this
	# node enters the tree — before this `_ready` — so it has not had a chance
	# to frame anything, and the first beat is very often a camera direction.
	# Saying so here gives it that chance before the scene starts.
	Cues.emit_cue(&"scene_staged", {"scene": scene_id, "marks": marks})
	_next_beat()

## --- the stage --------------------------------------------------------------

func _build_cast(entries: Dictionary) -> void:
	for who in entries:
		var entry = entries[who]
		if not entry is Dictionary:
			continue
		var a := CutsceneActor.new()
		a.setup(String(who), entry)
		# On no collision layer of their own: the cast walk through each other,
		# are stopped by a stage's walls, and nothing in the world can touch them.
		a.collision_layer = 0
		a.collision_mask = 1
		add_child(a)
		cast[String(who)] = a
		if entry.has("at"):
			a.place_at(_place(entry["at"]))
		else:
			# Cast but not yet on: an `enter` direction walks them in.
			a.on_stage = false
			a.place_at(Vector2.ZERO)

func _place(value) -> Vector2:
	return CutsceneScript.resolve_place(value, marks)

## --- running ----------------------------------------------------------------

func _process(delta: float) -> void:
	if done:
		return
	if _wait_left > 0.0:
		_wait_left = maxf(0.0, _wait_left - delta)
	_type(delta)
	# A beat with a line waits to be read; one without is over as soon as its
	# directions are, so a scene can move somebody without asking for a press
	# — unless it asks a question, which waits for its answer.
	if _directions_done() and line() == "" and choices().is_empty():
		_next_beat()

func _type(delta: float) -> void:
	var text := line()
	if text == "" or line_finished():
		return
	var before := int(revealed)
	revealed = minf(revealed + reveal_rate() * delta, float(text.length()))
	for i in range(before, int(revealed)):
		if i % 2 == 0 and not QUIET.contains(text[i]):
			Cues.emit_cue(&"scene_letter", {"scene": scene_id, "beat": beat(), "index": i})
			break

## On from the beat running now: to the beat its `next` names — none being
## the end — or, for one naming none, the beat after it in the file.
func _next_beat() -> void:
	var b := beat()
	if index >= 0 and b.has("next"):
		_go_to(String(b["next"]))
	else:
		_start_beat(index + 1)

## To the beat called `id`. A name no beat has, or none, is the end.
func _go_to(id: String) -> void:
	if id == "" or not _by_id.has(id):
		index = beats.size()
		_finish()
		return
	_start_beat(int(_by_id[id]))

func _start_beat(i: int) -> void:
	index = i
	revealed = 0.0
	selected = 0
	_moving.clear()
	_wait_left = 0.0
	if index >= beats.size():
		_finish()
		return
	var b := beat()
	_wait_left = maxf(float(b.get("hold", 0.0)), 0.0)
	for d in b.get("do", []):
		if d is Dictionary:
			_direct(d)
	if line() != "":
		Cues.emit_cue(&"scene_line", {"scene": scene_id, "beat": b})
	beat_started.emit(index)

## Carries out one direction. The ones that move something are done here; every
## other one is announced and left to whoever draws or plays it.
func _direct(d: Dictionary) -> void:
	if d.has("move"):
		var who := _who(d["move"])
		if who != null:
			who.on_stage = true
			who.walk_to(_walk_target(who, d), float(d.get("speed", CutsceneActor.WALK_SPEED)))
			_moving.append(who)
		return
	if d.has("place"):
		var who := _who(d["place"])
		if who != null:
			who.on_stage = true
			who.place_at(_place(d.get("at", null)))
		return
	if d.has("enter"):
		var who := _who(d["enter"])
		if who != null:
			who.on_stage = true
			who.place_at(_place(d.get("at", null)))
			if d.has("to"):
				who.walk_to(_place(d["to"]), float(d.get("speed", CutsceneActor.WALK_SPEED)))
				_moving.append(who)
		return
	if d.has("exit"):
		var who := _who(d["exit"])
		if who != null:
			who.stop()
			who.on_stage = false
		return
	if d.has("face"):
		var who := _who(d["face"])
		if who != null:
			if d.has("toward"):
				who.face(point_of(d["toward"]) - who.global_position)
			else:
				who.face(CutsceneScript.way(String(d.get("dir", "right"))))
		return
	if d.has("wait"):
		_wait_left = maxf(_wait_left, float(d["wait"]))
		return
	# Nothing here moves: it belongs to the picture or the sound bank.
	var extra := {"scene": scene_id, "direction": d}
	if d.has("anim"):
		var who := _who(d["anim"])
		if who != null:
			# Held on the cast member rather than sent as a moment, because it
			# is state: the view reads it every frame until something else is
			# asked for. The cue still goes out for anything else listening.
			who.forced_anim = String(d.get("play", ""))
			extra["who"] = who.cast_id
			Cues.at(&"scene_direction", who.global_position, extra)
			return
	Cues.emit_cue(&"scene_direction", extra)

func _who(value) -> CutsceneActor:
	var a = cast.get(String(value), null)
	return a if a is CutsceneActor else null

## Where a `move` goes: `to` a place; `near` somebody, stopping `gap` short
## of them on the side it comes from; or `by` so far from where they stand —
## a number for across, left for less than nothing, or a pair for across and
## down the floor.
func _walk_target(who: CutsceneActor, d: Dictionary) -> Vector2:
	if d.has("near"):
		var other := point_of(d["near"])
		var toward := other - who.global_position
		if toward == Vector2.ZERO:
			toward = -who.facing
		return other - toward.normalized() * float(d.get("gap", 0.0))
	if d.has("by"):
		return who.global_position + CutsceneScript.offset(d["by"])
	return _place(d.get("to", null))

func _directions_done() -> bool:
	if _wait_left > 0.0:
		return false
	for a in _moving:
		if is_instance_valid(a) and a.walking():
			return false
	return true

## --- what a press does ------------------------------------------------------

## One press: finish the typing if it is still running, otherwise give the
## answer picked to a question, or else cut short whatever the beat is still
## doing and move on. A press always makes something happen, so a scene can
## never be sat in front of waiting.
func press() -> void:
	if done:
		return
	if line() != "" and not line_finished():
		revealed = float(line().length())
		return
	if is_choosing():
		choose(selected)
		return
	_cut_short()
	_next_beat()

func _cut_short() -> void:
	for a in _moving:
		if is_instance_valid(a):
			a.finish_walk()
	_wait_left = 0.0

## The answers the beat running now offers; empty when it is not a question.
func choices() -> Array:
	var c = beat().get("choices", [])
	return c if c is Array else []

## True once a question has been asked in full and is waiting for an answer.
func is_choosing() -> bool:
	return not done and line_finished() and not choices().is_empty()

## Moves the highlight, wrapping at either end.
func move_selection(step: int) -> void:
	if not is_choosing():
		return
	selected = wrapi(selected + step, 0, choices().size())
	Cues.emit_cue(&"ui", {"kind": "arm"})

## Gives answer `index` to the question now open: on to where it leads.
func choose(index: int) -> void:
	if not is_choosing() or index < 0 or index >= choices().size():
		return
	var c = choices()[index]
	_cut_short()
	_go_to(String(c.get("next", "")) if c is Dictionary else "")

## Out of the whole scene, however far through it is.
func skip() -> void:
	if done:
		return
	index = beats.size()
	_finish()

func _finish() -> void:
	if done:
		return
	done = true
	Cues.emit_cue(&"scene_finished", {"scene": scene_id})
	finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	if event.is_action_pressed("ui_cancel"):
		skip()
		get_viewport().set_input_as_handled()
	elif is_choosing() and (event.is_action_pressed("move_up") or event.is_action_pressed("ui_up")):
		move_selection(-1)
		get_viewport().set_input_as_handled()
	elif is_choosing() and (event.is_action_pressed("move_down") or event.is_action_pressed("ui_down")):
		move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		press()
		get_viewport().set_input_as_handled()

## --- what the picture reads -------------------------------------------------

## Where a name in the file points: a cast member, a mark, or a pair of numbers
## written out. The picture needs this as much as the staging does — a `camera`
## direction names a place exactly the way a `move` does — so it is public.
func point_of(value) -> Vector2:
	var a := _who(value)
	if a != null:
		return a.global_position
	return _place(value)

func beat() -> Dictionary:
	if index < 0 or index >= beats.size():
		return {}
	var b = beats[index]
	return b if b is Dictionary else {}

## The whole line of the beat running now, typed or not.
func line() -> String:
	return String(beat().get("text", ""))

## The part of it typed so far.
func visible_text() -> String:
	return line().left(int(revealed))

func line_finished() -> bool:
	return int(revealed) >= line().length()

func reveal_rate() -> float:
	return maxf(float(beat().get("speed", REVEAL_RATE)), 1.0)

## Who is speaking this beat, or "" when it is narration with nobody behind it.
func speaker() -> String:
	return String(beat().get("say", ""))

## The name on the tab, which a beat may set itself.
func speaker_name() -> String:
	if beat().has("name"):
		return String(beat()["name"])
	var a := _who(speaker())
	if a == null:
		return ""
	return String(a.cast.get("name", a.cast_id))

## Whether the scene is waiting on a press rather than on something finishing.
func waiting_for_press() -> bool:
	return not done and line() != "" and _directions_done()
