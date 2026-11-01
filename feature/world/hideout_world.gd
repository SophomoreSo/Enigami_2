class_name HideoutWorld
extends World

## Between raids, as a place rather than a screen: a hall, seen from above.
## The player stands on its floor and walks to what they want: the rack to
## pick the weapons they will carry, the counter to spend scrap, the perks, the
## gate to go. Each is a `Station` — walk up, press interact, and that
## station's panel opens over the room.
##
## The hall is laid by hand, the way every made room is (`MadeRoom`): a floor
## plan of walls and open floor, with where the player comes in and where the
## bench stands marked on it, and a dressing of lanterns along the walls.
## Nothing in it is rolled, so the stations stand where the plan puts them,
## every time.
##
## The kit is up to three weapons (`GameState.carried`), and the player in the
## room is holding it: the keys that change weapon in a raid change it here,
## and the one in hand is the one whose graph TAB opens.
##
## The weapon's graph is not a station. TAB opens it from anywhere on the floor,
## the key that opens assembly in a raid, and the rack's BUILD opens it too. A
## workbench used to stand between the rack and the counter for it, which was a
## walk to reach what a key already reached.
##
## The panels are the ones the old screen was made of, built one at a time
## instead of three at once; `graphics/ui/hideout.gd` still owns what is in
## them. What changed is how they are reached.
##
## Nothing here draws. `graphics/views/hideout_world_view.gd` builds the camera,
## the signs over the stations and the panels they open; what stands at each
## station is `graphics/views/station_view.gd`'s.

signal deploy_requested(weapon: String)
signal title_requested()
## A station was used: "weapons", "shop" or "perks". The view opens the panel;
## the rules do not know there is one.
signal station_used(id: String)
## The weapon's graph was asked for — by the key that opens assembly in a raid,
## or off the rack's BUILD. The editor belongs to `app/game.gd`, so this only
## passes the ask on.
signal edit_requested()
## The map was asked for, by the key that reads it in a raid. The hideout has no
## floor plan of a raid's; the screen it is a page of is still `app/game.gd`'s
## to put up.
signal map_requested()
## The panel over the room opened or closed. The room keeps standing either way.
signal panel_changed(id: String)

## The hall, as a floor plan: the size of any room, walled round, with two
## pillars to walk round, the player's start (`MadeRoom.START`) by the west
## wall, and the bench (`MadeRoom.BENCH`) on the open floor between the
## stations — far enough from each that no spot is in reach of a station's
## press and the bench's at once; the bench answers the key itself. And three
## birds (`MadeRoom.BIRD`) pecking on the floor in the hall's far corner,
## which fly as the player comes near and are back the next time the hall is.
const PLAN: PackedStringArray = [
	"########################################",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"#...........##............##...........#",
	"#...........##............##...........#",
	"#...P..................................#",
	"#......................................#",
	"#............._........................#",
	"#......................................#",
	"#......................................#",
	"#...........................v.v........#",
	"#............................v.........#",
	"#......................................#",
	"#......................................#",
	"#......................................#",
	"########################################",
]
## What is put about it: lanterns along the walls (`MadeRoomView.LIGHTS`), and
## a spotlight hung over the open floor below the pillars.
const DRESSING: PackedStringArray = [
	"........................................",
	"...L.........L............L.........L...",
	"........................................",
	"........................................",
	"........................................",
	"........................................",
	"........................................",
	"........................................",
	"........................................",
	"........................................",
	"........................................",
	"........................................",
	"........................................",
	"........................................",
	"....................S...................",
	"........................................",
	"........................................",
	"........................................",
	"........................................",
	"...L................................L...",
	"........................................",
	"........................................",
]
## Where each station stands, in cells of the plan. Along the far wall, left to
## right in the order you would use them — pick a weapon, buy what its graph
## still needs, buy yourself a step of a perk (perks/, whose page the view
## opens) — and the gate in the east wall, to leave by.
const STATION_CELLS := {
	"weapons": Vector2i(7, 4),
	"shop": Vector2i(20, 4),
	"perks": Vector2i(28, 4),
	"gate": Vector2i(37, 11),
}

var room: MadeRoom
var player: Player
## id -> Station, in `STATION_CELLS` order.
var stations: Dictionary = {}
## Which panel is open over the room, or "" for none. While one is open the
## player is held still: they are reading, not walking.
var open_panel: String = ""
## `editing`, from `World`, is whether the workbench's editor is up over the
## room, opened on the assembly key or off the rack's BUILD. `app/game.gd` owns
## the editor and says so here, the way a raid and the sandbox are told theirs;
## the player is held under it just as under a panel. Opened by key from the
## floor it used to hold nobody, so the player walked the room behind it and
## the game kept the mouse for their aim.
## The weapon in hand: the one the rack was left on, or the player has switched
## to since. The editor opens its graph, and the gate walks out holding it — with
## the rest of the kit beside it.
var weapon_id: String = ""

func _ready() -> void:
	Arena.register(self)
	Cues.emit_cue(&"music_start")
	# The bodies and the room's fittings are drawn in the order of their feet
	# down the floor, as in a raid.
	y_sort_enabled = true

	# The hall, stood up out of its plan: its walls, its bench, and nothing
	# else — a made room holds what was put in it, and nothing was put in this
	# one to fight.
	room = MadeRoom.new()
	room.plan = PLAN
	room.dressing = DRESSING
	add_child(room)

	if weapon_id == "" or not GameState.owned_weapons.has(weapon_id):
		var kit := GameState.carried()
		weapon_id = kit[0] if not kit.is_empty() else "SWORD"

	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	player.room = room
	# The room is told who plays it before it stands, so the bench it stands
	# is theirs.
	room.player = player
	room.stand(20260920)
	refresh_kit()
	# Switched on the floor, with the keys a raid switches with: the weapon in
	# hand is what the rack is on now. The empty hand leaves the rack where it
	# was: there is nothing on it to carry to the gate.
	player.weapon_switched.connect(func(weapon: String) -> void:
		if weapon == "":
			return
		weapon_id = weapon
		_refresh_gate())
	# Nothing here can hurt anybody, and a player who walked in wounded should
	# not be reading their health bar while they shop. The medbay is what heals
	# between raids; this is only the hideout refusing to be a fight.
	player.max_health = GameState.max_health()
	player.health = player.max_health
	player.global_position = room.spawn_point()

	for id in STATION_CELLS:
		_build_station(String(id))
	_refresh_gate()
	GameState.kit_changed.connect(_refresh_gate)
	# The player standing in the room carries what the gate would carry, so a
	# graph built on the board has to reach them before the HUD can show it.
	GameState.kit_changed.connect(refresh_kit)
	GameState.stash_changed.connect(_refresh_gate)
	# The signs are words written once, unlike everything the view draws every
	# frame, so a language switched from the pause menu has to reach them.
	Loc.language_changed.connect(_relabel)

func _build_station(id: String) -> void:
	var c: Vector2i = STATION_CELLS[id]
	var s := Station.new()
	s.id = id
	s.player = player
	s.label = Loc.t("hideout.station.%s" % id)
	s.position = room.cell_center(c.x, c.y)
	s.used.connect(_on_station_used)
	add_child(s)
	stations[id] = s

## Every sign in the room, in the language now being played.
func _relabel(_lang: String) -> void:
	for id in stations:
		var s: Station = stations[id]
		s.label = Loc.t("hideout.station.%s" % id)
	_refresh_gate()

## The gate is shut until there is a weapon to carry through it — one the
## vault still has. It says so rather than going quiet, since "nothing happens"
## is the one thing a door must never do. A weapon always has its graph, so
## there is nothing else to be short of.
func _refresh_gate() -> void:
	var gate: Station = stations.get("gate")
	if gate == null:
		return
	var owned: bool = GameState.owned_weapons.has(weapon_id)
	gate.open = owned
	gate.closed_reason = "" if owned else Loc.t("hideout.gate.no_weapon")

## The graph the gate would carry: the one on the weapon the rack was left on.
## The profile's own board, not a copy. A raid carries a copy because a raid
## writes on it; here it is only read — to be shown on the HUD and to be
## edited, which is editing the profile and is meant to be.
func armed_board() -> SkillBoard:
	return GameState.weapon_board(weapon_id)

## Puts the kit back on the player in the room: every weapon the gate would
## carry and the graph on each, with the one the rack was left on in hand — or
## an empty hand, if that was in hand, unless `to_rack`: a weapon just picked is
## taken up.
## Nothing in here fights, but the HUD over the room reads the player rather
## than the profile, so anything that changes the kit — the rack, a graph coming
## back from the editor — comes through here afterwards.
##
## The graphs are the profile's own, not copies: see `armed_board`.
func refresh_kit(to_rack: bool = false) -> void:
	if player == null or not is_instance_valid(player):
		return
	var kit := GameState.carried()
	# The empty hand casts the profile's own graph for it, as the weapons do.
	player.hand_board = GameState.weapon_board(Weapons.HAND)
	# A weapon left out of the kit is not in hand any more: the hand goes to one
	# that is still carried.
	if not kit.has(weapon_id) and GameState.owned_weapons.has(weapon_id) and not kit.is_empty():
		weapon_id = kit[0]
	# The rack can be on a weapon the vault has lost, which is what shuts the
	# gate, and then that is all there is to show the player holding.
	if not kit.has(weapon_id):
		player.setup(weapon_id, armed_board())
		return
	var graphs: Array = []
	for w in kit:
		graphs.append(GameState.weapon_board(w))
	# An empty hand in hand stays there — a graph changed at assembly is no
	# reason to take a weapon up — unless the rack's weapon is asked for.
	var at := kit.find(weapon_id)
	if player.empty_handed() and not to_rack:
		at = player.hand
	player.setup_kit(kit, graphs, at)

func _on_station_used(s: Station) -> void:
	if open_panel != "":
		return
	if s.id == "gate":
		deploy_requested.emit(weapon_id)
		return
	open_station(s.id)

## Opens a station's panel, from a press or from a test. The player is held
## still while it is up: `Player.controls_locked` is what an NPC conversation
## uses to the same end, and reading a shop list is no different from listening.
func open_station(id: String) -> void:
	if not stations.has(id) or id == "gate":
		return
	open_panel = id
	_hold()
	station_used.emit(id)
	panel_changed.emit(id)

## Builds the open panel again, for when what is in it has changed underneath:
## a board came back from the editor with a different name, a purchase left the
## stash different. Nothing happens if no panel is open.
func refresh_panel() -> void:
	if open_panel != "":
		panel_changed.emit(open_panel)

func close_panel() -> void:
	if open_panel == "":
		return
	open_panel = ""
	_hold()
	_refresh_gate()
	panel_changed.emit("")

## The workbench's editor went up over the room, or came down again.
func set_editing(on: bool) -> void:
	editing = on
	_hold()

## Holds the player still while anything is up over the room — a panel, the
## editor — and lets them go once nothing is. They are stopped where they stand
## rather than left to slide.
func _hold() -> void:
	if player == null or not is_instance_valid(player):
		return
	var held := open_panel != "" or editing
	if held:
		player.velocity = Vector2.ZERO
	player.input_locked = held

## --- the phone ----------------------------------------------------------------
## The phone's clock runs on the hideout's: an alarm set in here rings in
## here, with nothing much to hear it. Put down, it lies on the room's floor
## (`PhoneProp`) — until the hideout is left, when it is back in the hand
## (`Phone.recover`).
func _process(delta: float) -> void:
	Phone.tick(delta, _phone_here())

## Where the phone is, for its clock: in the player's hand or on the floor.
func _phone_here() -> Variant:
	var here: Variant = null
	if Phone.carried():
		if player != null and is_instance_valid(player):
			here = player.global_position
	else:
		var prop := phone_prop()
		if prop != null:
			here = prop.global_position
	return here

## The phone lying on the floor, or null.
func phone_prop() -> PhoneProp:
	if room == null or not is_instance_valid(room):
		return null
	for c in room.get_children():
		if c is PhoneProp and not c.is_queued_for_deletion():
			return c
	return null

## The phone put down where the player stands, to be walked away from.
func put_phone_down() -> bool:
	if room == null or player == null or not is_instance_valid(player) or not Phone.carried():
		return false
	var at := player.global_position
	Phone.put_down_at("hideout", Vector2i.ZERO, at)
	PhoneProp.lay(room, player, at)
	return true

## Takes `id` in hand: the rack is left on it, and it is carried — in a free
## slot, or in the slot of the weapon that was in hand when the kit is full. A
## weapon the vault has lost can still be what the rack is on, but it is not
## carried, and it shuts the gate: that is a raid nobody can be let into.
func set_weapon(id: String) -> void:
	var was := weapon_id
	weapon_id = id
	GameState.carry(id, was)
	refresh_kit(true)
	_refresh_gate()

## Leaves `id` on the rack: out of the kit, with the hand on a weapon still
## carried. Not the last one — a raid is not walked into empty-handed. Whether
## it was left.
func leave_weapon(id: String) -> bool:
	if not GameState.leave_behind(id):
		return false
	refresh_kit()
	_refresh_gate()
	return true

## Whether the player is being held still by something on screen. The view asks
## before it lets a key through, the same way the sandbox does while assembling.
func reading() -> bool:
	return open_panel != "" or editing

## A station's panel is up: the rack's, or the counter's. See `World.paneled`.
func paneled() -> bool:
	return open_panel != ""

func leave() -> void:
	title_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if reading():
		return
	# The key that opens assembly in a raid opens it here too, over the graph
	# the gate would carry. From the floor it is the way onto the board: there
	# is no workbench to walk to.
	if event.is_action_pressed("open_editor"):
		edit_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("open_map"):
		map_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("interact"):
		return
	for id in stations:
		var s: Station = stations[id]
		if s.near and s.open:
			s.interact()
			get_viewport().set_input_as_handled()
			return

## A station open and within reach, or the bench.
func use_nearby() -> bool:
	for s in stations.values():
		if (s as Station).near and (s as Station).open:
			return true
	if room != null and is_instance_valid(room) and (room.bench_offered() or room.phone_offered()):
		return true
	return false
