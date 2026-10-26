class_name GhostTest
extends World

## A proving ground for POSSESS: steal a diamond out of a guarded building
## without going in yourself — as a ghost, from one guard to the next.
##
## The player has the rock, and the rock's graph puts their hands into whatever
## it strikes. A monster they are in walks past the rest as one of them, picks
## the rock back up, and throws it on into the next — so the way in is from one
## guard to another. The diamond can be carried by any of them (`Diamond`), but
## the theft is only done when the player's own body has it back in the nook it
## started from (`GhostBase.in_start`).
##
## Nothing is free here the way it is at the bench: a guard who sees the body,
## or sees a monster the player is in throw, attacks it as it would anywhere,
## and the body has `BODY_HEALTH` whatever the profile has built — three of a
## Gunman's shots. The body falling ends the attempt, and so does the theft; either way the
## ground is set again a moment later, and R sets it again at once. Parts are
## free, as on the bench, and the graph is the test's own. What it looks like
## is `graphics/views/ghost_test_view.gd`.

signal exit_requested()
signal editing_changed(on: bool)
## The graph changed under the screen.
signal board_changed()
## The diamond was brought back to the nook in the player's own hands, `seconds`
## into the attempt.
signal stolen(seconds: float)
## The player's body fell, and the attempt with it.
signal fell()
## Every guard is back at their post, the diamond on its island and the player in
## the nook.
signal floor_reset()

const WEAPON := "ROCK"
## The body's health here, the same for everyone: what a Gunman's shot is
## weighed against (`Monsters.DEFS`), so three of them are the end of it and
## two are, after anything else has landed.
const BODY_HEALTH := 100.0
## Seconds between an attempt ending and the ground being set again.
const RESET_DELAY := 2.4

var room: GhostBase
var player: Player
var diamond: Diamond
## The graph the rock carries here: `ghost`, in the content database.
var board: SkillBoard
## The editor's pool: unused, because parts are unlimited here as on the bench.
var inventory: Dictionary = {}
var total_guards: int = 0
## Seconds since the screen opened, and since this attempt began.
var elapsed: float = 0.0
var attempt: float = 0.0
## The quickest theft since the screen opened, or 0 before the first.
var best: float = 0.0
## Whether this attempt is over — stolen or fallen — and waiting to be set again.
var over: bool = false
## Counts down while a finished attempt waits to be set again.
var reset_in: float = 0.0

## The rock's graph in this test, `ghost` in the content database
## (`data/db/boards/ghost_test.sql`): its throw, and POSSESS on it twice.
static func ghost_board() -> SkillBoard:
	return Boards.build("ghost", Loc.t("hud.ghost.board"))

func _ready() -> void:
	Arena.register(self)
	Cues.emit_cue(&"music_start")
	# The bodies are drawn in the order of their feet down the floor.
	y_sort_enabled = true

	room = GhostBase.new()
	add_child(room)
	var guards := room.guard_records()
	total_guards = guards.size()
	room.build(Vector2i.ZERO, {"kind": "entry", "danger": 1, "region": 0, "variant": 0,
		"enemies": guards, "loot": []}, {}, 0)

	board = ghost_board()
	diamond = Diamond.new()
	diamond.room = room
	diamond.kept_at = room.diamond_point()
	add_child(diamond)
	_new_player()
	diamond.place(room.diamond_point())

## A body in the nook with the rock in hand: a fresh one every attempt, since a
## fallen one is gone.
func _new_player() -> void:
	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	player.room = room
	room.player = player
	player.global_position = room.spawn_point()
	player.setup(WEAPON, board)
	player.max_health = BODY_HEALTH
	player.health = BODY_HEALTH
	player.died.connect(_on_player_died)
	diamond.player = player

func _process(delta: float) -> void:
	elapsed += delta
	if reset_in > 0.0:
		reset_in -= delta
		if reset_in <= 0.0:
			reset_floor()
		return
	if over:
		return
	attempt += delta
	if diamond.carried_by_player() and room.in_start(player.global_position):
		over = true
		best = attempt if best <= 0.0 else minf(best, attempt)
		reset_in = RESET_DELAY
		stolen.emit(attempt)

func _on_player_died(_a: Actor) -> void:
	if over:
		return
	over = true
	reset_in = RESET_DELAY
	fell.emit()

## The guards still standing who have seen something to go after: the body, or
## a monster the player is in giving itself away.
func alerted() -> int:
	var n := 0
	for c in room.get_children():
		if c is Enemy and not c.dead and not (c as Enemy).piloted() and (c as Enemy).aggro:
			n += 1
	return n

## Everything back where it started: the guards at their posts the way they
## were looking, the diamond on its island, the rock in hand and the body in the
## nook with full meters, and nothing left in flight.
func reset_floor() -> void:
	reset_in = 0.0
	over = false
	attempt = 0.0
	Attacks.clear_in_flight(self)
	if player != null and is_instance_valid(player):
		# Out of the hunt now rather than at the end of the frame.
		player.remove_from_group("player")
		player.queue_free()
	for c in room.get_children():
		if c is Enemy:
			c.remove_from_group("actors")
			c.queue_free()
		elif c is LooseRock:
			c.queue_free()
	var guards := room.guard_records()
	room.data["enemies"] = guards
	for e in guards:
		room._spawn_enemy(e)
	total_guards = guards.size()
	_new_player()
	diamond.place(room.diamond_point())
	floor_reset.emit()

func set_editing(on: bool) -> void:
	if editing == on:
		return
	editing = on
	if player != null and is_instance_valid(player):
		player.input_locked = on
	editing_changed.emit(on)

func on_board_changed() -> void:
	if player != null and is_instance_valid(player):
		player.rebuild_runner()
	board_changed.emit()

func leave() -> void:
	exit_requested.emit()
