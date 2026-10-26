class_name Sandbox
extends World

## A room where nothing is at stake. Parts are unlimited, each weapon's graph
## is a copy of the profile's, and the weapons can be swapped back to back so
## the differences between them are something you see rather than read: a
## kit's worth is carried here — every weapon while a kit holds them all, and
## otherwise the one the bench is on and the next ones round — and the keys
## that change weapon in a raid change it at the bench.
##
## The bench's own buttons are `graphics/ui/sandbox_panel.gd`, in a drawer built
## by the view that attaches itself to this node, beside the raid's own HUD.

signal exit_requested()
signal editing_changed(on: bool)
## The dragon test was asked for: a building of guards to try a chain of lunges on.
signal dragon_test_requested()
## The ghost test was asked for: a diamond to steal by possessing its guards.
signal ghost_test_requested()
## The lighting test was asked for: a light of each kind to walk through.
signal lighting_test_requested()
## A sample skill was put on its weapon (`load_sample`).
signal sample_loaded(id: String)

const MONSTER_BUTTONS := ["CRAWLER", "SENTRY", "LOBBER", "HOPPER", "DRIFTER", "BOMBER", "WARDEN", "ARBITER"]
## The column the apprentice stands in: by the left wall, out of the way.
const APPRENTICE_CELL := 5

var room: Room
var player: Player
## Someone on the bench to talk to.
var npc: Npc
## The Tinker's apprentice, who talks free — in a bubble, while the player goes
## on trying things in front of them — and watches what they try.
var apprentice: Npc
## weapon id -> the graph tried here: a copy of the profile's, so nothing done
## on the bench reaches the hideout.
var graphs: Dictionary = {}
var weapon_index: int = 0
var inventory: Dictionary = {}
## Whether a drawer is out — the bench tools, or the sample skills. The player
## is held still while one is, the way they are while assembling: its buttons
## are pressed with the mouse they would otherwise be aiming with.
var tools_open: bool = false
## Which drawers are out, by name: either can be out without the other, and the
## player is free only once both are in.
var _drawers_out: Dictionary = {}
var _dps_window: Array = []   ## [time, damage] pairs over the last few seconds
var _dps: float = 0.0

func _ready() -> void:
	y_sort_enabled = true
	Arena.register(self)
	Cues.emit_cue(&"music_start")

	room = Room.new()
	add_child(room)
	var record := {"kind": "entry", "danger": 1, "region": 0, "variant": 7, "enemies": [], "loot": [], "flat": true}
	room.build(Vector2i.ZERO, record, {}, 12345)

	# Copies only: nothing here touches the hideout. The empty hand's as well.
	graphs.clear()
	for w in Weapons.ids() + [Weapons.HAND]:
		graphs[w] = GameState.weapon_board(String(w)).duplicate_board()

	player = Player.new()
	player.hand_board = graphs[Weapons.HAND]
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	player.room = room
	player.global_position = room.spawn_point()
	# Drawn with a key rather than the bench's own button, the weapon in hand is
	# still the one the bench is on. The empty hand leaves the bench on the one
	# it was on.
	player.weapon_switched.connect(func(weapon: String) -> void:
		if weapon != "":
			weapon_index = maxi(Weapons.ids().find(weapon), 0))
	_apply_weapon()

	spawn_dummy()
	spawn_npc()
	spawn_apprentice()

## Puts the bench's weapons on the player, with the one the bench is on in
## hand: all of them, as a kit, while a kit can hold them all — and otherwise
## a kit's worth, the one the bench is on and the next ones round, so the
## bench's swap walks the kit along the rack.
func _apply_weapon() -> void:
	var ids := Weapons.ids()
	weapon_index = weapon_index % ids.size()
	var kit: Array = []
	var boards: Array = []
	var in_hand := weapon_index
	if ids.size() <= Player.MAX_WEAPONS:
		kit = ids
	else:
		in_hand = 0
		for k in Player.MAX_WEAPONS:
			kit.append(ids[(weapon_index + k) % ids.size()])
	for w in kit:
		boards.append(graphs[String(w)])
	player.setup_kit(kit, boards, in_hand)
	player.max_health = 9999.0
	player.health = 9999.0

## The graph on the weapon in hand: what the assembly board over the bench edits.
func board() -> SkillBoard:
	return graphs[current_weapon()]

func cycle_weapon() -> void:
	weapon_index += 1
	_apply_weapon()
	Cues.emit_cue(&"ui", {"kind": "weapon"})

func current_weapon() -> String:
	return String(Weapons.ids()[weapon_index % Weapons.ids().size()])

## Put down on the bench's floor, across the room from where the player
## starts.
func spawn_dummy() -> void:
	_spawn("DUMMY", 1, room.cell_center(28, 11))

## Stood on the floor, down the room from the middle. On no collision layer of
## its own, so nothing bumps into it.
func spawn_npc() -> void:
	npc = Npc.new()
	npc.setup("SAGE")
	npc.collision_layer = 0
	npc.collision_mask = 1
	npc.position = room.cell_center(20, 15)
	add_child(npc)

## Stood on the floor by the wall.
func spawn_apprentice() -> void:
	apprentice = Npc.new()
	apprentice.setup("APPRENTICE")
	apprentice.mode = Npc.Mode.FREE
	apprentice.collision_layer = 0
	apprentice.collision_mask = 1
	apprentice.position = room.cell_center(APPRENTICE_CELL, 11)
	add_child(apprentice)

func spawn_monster(kind: String) -> void:
	_spawn(kind, 2, room.cell_center(24 + randi() % 8, 6 + randi() % 4))

func _spawn(kind: String, danger: int, at: Vector2) -> void:
	var e := Enemy.new()
	e.setup(kind, danger, "")
	e.position = at
	e.room = room
	e.collision_layer = 4
	e.collision_mask = 1 | (0 if e.ai() == "flyer" else Room.PIT_BIT)
	e.damaged.connect(_on_damage)
	add_child(e)

func clear_monsters() -> void:
	for c in get_children():
		if c is Enemy:
			c.queue_free()

func leave() -> void:
	exit_requested.emit()

func open_dragon_test() -> void:
	dragon_test_requested.emit()

func open_ghost_test() -> void:
	ghost_test_requested.emit()

func open_lighting_test() -> void:
	lighting_test_requested.emit()

## The skills the bench has ready to try: the dragon test's graph, the ghost
## test's and the seeker arrow. Each is a graph, the weapon it was built for,
## and what it is called; `board` builds a fresh one, named in the language
## being played.
static func samples() -> Array:
	return [
		{"id": "dragon", "weapon": DragonTest.WEAPON, "board": DragonTest.dragon_board},
		{"id": "ghost", "weapon": GhostTest.WEAPON, "board": GhostTest.ghost_board},
		{"id": "seeker", "weapon": "GUN", "board": seeker_board},
	]

## An arrow off the gun that will not be dodged: AUTO-AIM, RANGE and SPEED to
## their limits and three HOMING, `seeker` in the content database
## (`data/db/boards/samples.sql`).
static func seeker_board() -> SkillBoard:
	return Boards.build("seeker", Loc.t("hud.sandbox.seeker"))

## Puts the sample skill `id` on its weapon here — over the bench's copy of that
## weapon's graph, never the profile's — and that weapon in hand. Whether there
## is one by that id.
func load_sample(id: String) -> bool:
	for s in samples():
		if String(s["id"]) != id:
			continue
		var weapon := String(s["weapon"])
		graphs[weapon] = (s["board"] as Callable).call()
		weapon_index = maxi(Weapons.ids().find(weapon), 0)
		_apply_weapon()
		Cues.emit_cue(&"ui", {"kind": "weapon"})
		sample_loaded.emit(id)
		return true
	return false

func _on_damage(_a: Actor, amount: float) -> void:
	_dps_window.append([float(Time.get_ticks_msec()) / 1000.0, amount])

func _process(_delta: float) -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	_dps_window = _dps_window.filter(func(e: Array) -> bool: return now - float(e[0]) <= 3.0)
	var total := 0.0
	for e in _dps_window:
		total += float(e[1])
	_dps = total / 3.0

func dps() -> float:
	return _dps

func set_editing(on: bool) -> void:
	if editing == on:
		return
	editing = on
	player.input_locked = editing or tools_open
	editing_changed.emit(on)

func set_tools_open(on: bool, drawer: String = "tools") -> void:
	if on:
		_drawers_out[drawer] = true
	else:
		_drawers_out.erase(drawer)
	tools_open = not _drawers_out.is_empty()
	player.input_locked = editing or tools_open

func on_board_changed() -> void:
	player.rebuild_runner()

## Someone on the bench in talking range, with something to say.
func use_nearby() -> bool:
	for n in [npc, apprentice]:
		if n != null and is_instance_valid(n) and (n as Npc).answers_press():
			return true
	return false
