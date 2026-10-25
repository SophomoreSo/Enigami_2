class_name DigSpot
extends Node2D

## Ground worth digging in a raid room: turned earth with something buried
## under it, lit so it can be found. Standing on it with the shovel in hand
## (`Weapons.digs`) and holding the use key digs it up, a little at a time;
## letting go, stepping off it or being hit starts it over.
##
## Digging is loud. Every so often while it goes on, the monsters near enough
## to hear it turn round to look (`Enemy.hear`) — and one that can see the
## player then notices them, the way it would anything in front of it.
##
## What comes up is what the room rolled for it (`Room._roll_digs`), parts and
## gold as a treasure box holds them, and the spot is a hole after. Its record
## is the room's own, shared rather than copied, so a room walked out of and
## back into has it as it was left. `graphics/views/dig_spot_view.gd` draws it.

## Dug up: `items` are the records that came out, `{"id": ...}` or
## `{"scrap": ...}`, the way a treasure box hands them over.
signal dug(spot: DigSpot, items: Array)

## How near the player has to stand: on it, give or take.
const RANGE := 24.0
## Seconds of holding the key it takes.
const HOLD := 1.0
## How far the digging is heard, and how often while it goes on.
const NOISE := 320.0
const NOISE_EVERY := 0.3

## The room's record of it: `pos`, the `loot` it was rolled with, and `dug`.
var record: Dictionary = {}
var player: Player = null
## How far it is dug, 0 to 1, while it is being dug.
var progress: float = 0.0
## Whether the player is standing on it, and whether they are digging.
var near: bool = false
var digging: bool = false
var _noise_in: float = 0.0

func setup(rec: Dictionary) -> void:
	record = rec
	var p: Array = rec.get("pos", [])
	if p.size() == 2:
		position = Vector2(float(p[0]), float(p[1]))

func _ready() -> void:
	add_to_group("dig_spots")

func is_dug() -> bool:
	return bool(record.get("dug", false))

## Whether holding the use key here would dig: not dug yet, and the player's own
## body standing on it with the shovel in hand.
func offered() -> bool:
	return near and not is_dug() and player.vessel() == player and Weapons.digs(player.weapon_id)

func _process(delta: float) -> void:
	near = player != null and is_instance_valid(player) and not player.dead \
		and player.global_position.distance_to(global_position) <= RANGE
	var holding := offered() and Input.is_action_pressed("interact") and not player.controls_locked()
	if not holding:
		if digging:
			stop()
		return
	if not digging:
		digging = true
		progress = 0.0
		_noise_in = 0.0
		player.damaged.connect(_on_hit)
	progress = minf(progress + delta / HOLD, 1.0)
	_noise_in -= delta
	if _noise_in <= 0.0:
		_noise_in = NOISE_EVERY
		_make_noise()
	if progress >= 1.0:
		_finish()

## Digging stops and starts over: the key let go, the spot stepped off, a hit.
func stop() -> void:
	digging = false
	progress = 0.0
	if player != null and is_instance_valid(player) and player.damaged.is_connected(_on_hit):
		player.damaged.disconnect(_on_hit)

func _on_hit(_a: Actor, _amount: float) -> void:
	stop()

## Every monster in earshot turns to look.
func _make_noise() -> void:
	Cues.at(&"dig", global_position, {})
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and (e as Enemy).global_position.distance_to(global_position) <= NOISE:
			(e as Enemy).hear(global_position)

func _finish() -> void:
	stop()
	progress = 1.0
	record["dug"] = true
	var loot: Array = record.get("loot", [])
	var items := TreasureBox.takeable(loot)
	for l in items:
		loot.erase(l)
	dug.emit(self, items)
	Cues.at(&"dig_done", global_position, {"count": items.size()})
