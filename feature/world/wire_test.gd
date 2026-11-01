class_name WireTest
extends World

## A proving ground for Legna Dennis's sight (`Sight`): a vault shut by an
## electric gate, and the wire it draws its power down run under the floor
## and through the walls from a generator somewhere else (`WireBase`). With
## the sight on — the vision key, once — the wires show, and which way the
## power comes along each; followed back, they are the way to the generators
## to crash, and so into the vault. Standing on its core, the attempt is done.
##
## The player is Legna Dennis here whoever the profile plays as
## (`Player.hero`), with a sword to crash things with, and her body has
## `BODY_HEALTH` whatever the profile has built: the gates shock, and the body
## falling ends the attempt too. Either way the ground is set again a moment
## later, and R sets it again at once. What it looks like is
## `graphics/views/wire_test_view.gd`.

signal exit_requested()
## The vault's core reached, `seconds` into the attempt.
signal reached(seconds: float)
## The body fell, and the attempt with it.
signal fell()
## Every generator running and every gate up again, and the body back where
## it came in.
signal floor_reset()

const HERO := "legna_dennis"
const WEAPON := "SWORD"
const BODY_HEALTH := 100.0
## Seconds between an attempt ending and the ground being set again.
const RESET_DELAY := 2.4

var room: WireBase
var player: Player
## Seconds since the screen opened, and since this attempt began.
var elapsed: float = 0.0
var attempt: float = 0.0
## The quickest way into the vault since the screen opened, or 0 before the
## first.
var best: float = 0.0
## Whether this attempt is over — in the vault, or fallen — and waiting to be
## set again.
var over: bool = false
## Counts down while a finished attempt waits to be set again.
var reset_in: float = 0.0

func _ready() -> void:
	Arena.register(self)
	Cues.emit_cue(&"music_start")
	# The bodies are drawn in the order of their feet down the floor.
	y_sort_enabled = true
	room = WireBase.new()
	add_child(room)
	room.build(Vector2i.ZERO, {"kind": "entry", "danger": 1, "region": 0, "variant": 0,
		"enemies": [], "loot": [], "digs": []}, {}, 0)
	_new_player()

## Legna Dennis where the hall is come into, sword in hand: a fresh body every
## attempt, since a fallen one is gone.
func _new_player() -> void:
	player = Player.new()
	player.hero = HERO
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	player.room = room
	room.player = player
	player.global_position = room.spawn_point()
	player.setup(WEAPON, Boards.build(String(Weapons.get_def(WEAPON).get("board", "sword"))))
	player.max_health = BODY_HEALTH
	player.health = BODY_HEALTH
	player.died.connect(_on_player_died)

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
	if player != null and is_instance_valid(player) and room.on_core(player.global_position):
		over = true
		best = attempt if best <= 0.0 else minf(best, attempt)
		reset_in = RESET_DELAY
		reached.emit(attempt)

func _on_player_died(_a: Actor) -> void:
	if over:
		return
	over = true
	reset_in = RESET_DELAY
	fell.emit()

## How many of the generators are crashed, and how many there are.
func crashed() -> int:
	return room.generators.filter(func(g: Generator) -> bool: return not g.running()).size()

## Whether the vault's gate is up.
func vault_shut() -> bool:
	var gate: ElectricGate = room.gates.get(WireBase.VAULT_GATE)
	return gate != null and gate.is_up()

## Everything back where it started: every generator running and every gate
## up, nothing in flight, and a fresh body where the hall is come into.
func reset_floor() -> void:
	reset_in = 0.0
	over = false
	attempt = 0.0
	Attacks.clear_in_flight(self)
	if player != null and is_instance_valid(player):
		# Out of the world now rather than at the end of the frame.
		player.remove_from_group("player")
		player.queue_free()
	room.restore()
	_new_player()
	floor_reset.emit()

func leave() -> void:
	exit_requested.emit()
