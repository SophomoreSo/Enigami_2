class_name DragonTest
extends World

## A proving ground for a chain of lunges, after the room in Katana ZERO where
## the Dragon tries out his dash: a building of halls with guards posted apart
## in every one, each dropped by a single cut, and all of them within one
## charged cast of the board this screen hands the player.
##
## Nothing is at stake. Parts are free, health does not run out, and a cleared
## floor is set again a moment later. The building is `DragonTower`; what the
## screen looks like is `graphics/views/dragon_test_view.gd`.

signal exit_requested()
signal editing_changed(on: bool)
## The graph changed under the screen, so anything cached about it is stale.
signal board_changed()
## The last guard fell. `one_cast` says whether a single cast took all of them.
signal cleared(one_cast: bool)
## Every guard is back at their post and the player is back at the door.
signal floor_reset()

const WEAPON := "SWORD"
## Seconds between the last guard falling and the floor being set again.
const RESET_DELAY := 2.4

var room: DragonTower
var player: Player
## The board the player is handed here: `dragon_board`, on the sword.
var board: SkillBoard
## The editor's pool: unused, because parts are unlimited here as on the bench.
var inventory: Dictionary = {}
var total_guards: int = 0
var guards_left: int = 0
## Guards cut down since the last skill went out, and the most any one cast has
## taken since the screen opened.
var cast_kills: int = 0
var best_cast: int = 0
## Attacks in the cast now running — what the charge that paid for it bought.
var cast_chain: int = 0
## Counts down while a cleared floor waits to be set again.
var reset_in: float = 0.0
## Seconds since the screen opened.
var elapsed: float = 0.0

## Whether kills are being counted for a cast: set when a cycle starts.
var _counting: bool = false
var _chain_cache: Dictionary = {}

## The board this room is built around, `dragon` in the content database
## (`data/db/boards/dragon_test.sql`): SWIFT STRIKE on the root, an ON HIT whose
## branch walks two OVERCLOCKs back round into it, and AUTO-AIM on the way
## out. Every lap the cast has life for is one more lunge at the nearest guard
## still standing.
static func dragon_board() -> SkillBoard:
	return Boards.build("dragon", Loc.t("hud.dragon.board"))

func _ready() -> void:
	Arena.register(self)
	Cues.emit_cue(&"music_start")
	# The bodies are drawn in the order of their feet down the floor.
	y_sort_enabled = true

	room = DragonTower.new()
	add_child(room)
	var guards := room.guard_records()
	total_guards = guards.size()
	guards_left = total_guards
	room.build(Vector2i.ZERO, {"kind": "entry", "danger": 1, "region": 0, "variant": 0,
		"enemies": guards, "loot": []}, {}, 0)
	room.enemy_killed.connect(_on_guard_down)

	board = dragon_board()
	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	player.room = room
	player.global_position = room.spawn_point()
	player.setup(WEAPON, board)
	player.max_health = 9999.0
	player.health = 9999.0
	# The cycle starting is the hook, not the attack going out: a lunge resolves
	# its first kill inside the call that fires it, so a count opened on the
	# attack would already be a kill behind by the time it was zeroed.
	player.runner.cycle_started.connect(_begin_cast)

func _process(delta: float) -> void:
	elapsed += delta
	if reset_in > 0.0:
		reset_in -= delta
		if reset_in <= 0.0:
			reset_floor()

func _begin_cast() -> void:
	_counting = true
	cast_kills = 0
	# The charge is spent by now and back at zero, so what this cast is worth is
	# read off the life it actually started with.
	cast_chain = chain_length(player.runner.ttl_bonus)

func _on_guard_down(_kind: String, _pos: Vector2) -> void:
	guards_left = maxi(guards_left - 1, 0)
	if _counting:
		cast_kills += 1
		best_cast = maxi(best_cast, cast_kills)
	if guards_left == 0:
		reset_in = RESET_DELAY
		cleared.emit(cast_kills >= total_guards)

## Stands every guard back at their post and the player back at the door with
## full meters, and calls off anything still in flight, so every attempt starts
## the way the first one did.
func reset_floor() -> void:
	reset_in = 0.0
	Attacks.clear_in_flight(self)
	for c in room.get_children():
		if c is Enemy:
			# Out of the target list now rather than at the end of the frame, so
			# nothing still swinging this frame can find a guard on its way out.
			c.remove_from_group("actors")
			c.queue_free()
	var guards := room.guard_records()
	room.data["enemies"] = guards
	for e in guards:
		room._spawn_enemy(e)
	total_guards = guards.size()
	guards_left = total_guards
	cast_kills = 0
	_counting = false
	player.global_position = room.spawn_point()
	player.velocity = Vector2.ZERO
	player.mana = player.max_mana
	player.stamina = player.max_stamina
	player.charge = 0.0
	floor_reset.emit()

## Attacks one cast of the graph would land at `bonus` charge if every one
## connects: the cast itself and each ON HIT follow-up hung off it.
func chain_length(bonus: int) -> int:
	var key := bonus
	if not _chain_cache.has(key):
		var sim := SkillRunner.new(player.runner.board)
		sim.base_payload_provider = func() -> Payload: return Weapons.base_payload(WEAPON)
		sim.forms_only = player.runner.forms_only
		sim.ttl_bonus = bonus
		var walk := sim.simulate()
		var follow := 0
		var link = (walk["triggers"] as Dictionary).get("ON_HIT", null)
		while link != null:
			follow += 1
			link = link.on_hit
		_chain_cache[key] = 0 if (walk["outputs"] as Array).is_empty() else 1 + follow
	return int(_chain_cache[key])

## The least charge whose chain reaches every guard on the floor, or -1 when no
## charge the player can hold does.
func charge_to_clear() -> int:
	for bonus in int(player.charge_cap()) + 1:
		if chain_length(bonus) >= total_guards:
			return bonus
	return -1

func set_editing(on: bool) -> void:
	if editing == on:
		return
	editing = on
	player.input_locked = on
	editing_changed.emit(on)

func on_board_changed() -> void:
	player.rebuild_runner()
	_chain_cache.clear()
	board_changed.emit()

func leave() -> void:
	exit_requested.emit()
