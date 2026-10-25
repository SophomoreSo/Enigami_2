class_name Raid
extends World

## Runs one deployment: a connected map of rooms laid by hand (`RaidMap`), the
## few round the player stood up where the floor puts them so a doorway is
## walked through and the picture follows (`rooms`, `_update_window`), and the
## two ways a raid can end.
##
## Nothing here draws. `graphics/views/raid_view.gd` attaches itself to this
## node and builds the camera, the HUD and the assembly overlay from the state
## and signals below.

signal finished(result: String, payload: Dictionary)
## The assembly overlay opened or closed. The raid keeps running either way.
signal editing_changed(on: bool)
## The map opened or closed. The raid keeps running either way, as above.
signal reading_map_changed(on: bool)
## The monster dictionary opened or closed, the same way again.
signal reading_dex_changed(on: bool)
## The perks' page opened or closed, the screen's fourth. The same again.
signal reading_perks_changed(on: bool)
## The phone came up over the raid, or went away (`Phone`). The same again.
signal on_phone_changed(on: bool)
## The bench's screen came up over the raid — who to play as — or went away.
signal choosing_changed(on: bool)
## The player is in another room: through a doorway, or by a cut.
signal room_changed(room: Room)
## The player was put down somewhere else: the picture cuts to them.
signal cut()

var map: RaidMap
## The room the player stands in.
var room: Room = null
## The rooms stood up right now, by coordinate: the one the player is in and
## the ones beside it with a doorway between, at most three, each where the
## floor puts it (`Room.origin_of`). The rest of the floor is its records.
var rooms: Dictionary = {}
## Monsters after the player in rooms that are not stood up: each one's record
## on its way along the floor, a room at a time (`_update_hunters`).
var hunters: Array = []
var player: Player
var reading_map: bool = false
var reading_dex: bool = false
var reading_perks: bool = false
## Whether the phone is up over the raid, holding the player still as a page
## of the screen does; what is on it is the shell's (`PhoneScreen`).
var on_phone: bool = false
## Whether the bench's screen is up over the raid (`HeroSelect`), the player
## sat under it; the shell puts it up and says so here.
var choosing: bool = false
var ended: bool = false
## What stands between the player and the exit they are standing in — a toll,
## a seal — or "" when nothing does, or they are not in one. An exit that will
## take them is the room's `extract_offered`, and the HUD writes the line for
## that one itself, since the line names the key that extracts.
var prompt: String = ""
## 0 → 1 while an extraction is being held.
var extract_ratio: float = 0.0

func _ready() -> void:
	# What stands on the floor is drawn in the order it stands down it: the
	# rooms' things and the player, who stands beside the rooms here.
	y_sort_enabled = true
	Arena.register(self)
	Cues.emit_cue(&"music_start")
	map = RaidMap.new()
	map.lay(GameState.raid_seed if GameState.raid_seed != 0 else randi())
	# A run put down with MAIN MENU: the map above is the same floor, laid from
	# the same rows, and this writes back what the run had made of it.
	var parked: Dictionary = GameState.raid_progress if GameState.has_parked_raid() else {}
	if not parked.is_empty():
		map.restore(parked)
		# And the phone as the run had it: its alarm, and where it was lying.
		if parked.has("phone"):
			Phone.restore(parked["phone"])
		_restore_hunters(parked.get("hunters", []))
	# After the restore, so a run that is being walked back into finds the drop
	# in the room the map says it is in rather than in whatever the save last
	# wrote there. Collecting it clears it from both at once, so this can never
	# put a kit back that has already been picked up.
	_place_lost_kit()

	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	# The whole kit: every weapon carried and the raid's own copy of the graph
	# on each, with the one that was in hand in hand.
	var graphs: Array = []
	for w in GameState.raid_weapons:
		graphs.append(GameState.raid_graphs[w])
	# And the empty hand's, the raid's copy of it too.
	player.hand_board = GameState.raid_graphs.get(Weapons.HAND, GameState.weapon_board(Weapons.HAND))
	player.setup_kit(GameState.raid_weapons, graphs, GameState.raid_hand)
	# A run put down with the rock lying in one of its rooms is walked back into
	# without it: it is still lying there.
	for w in _rocks_left_lying():
		player.let_go(w)
	# The profile is told which weapon is in hand as it changes: assembly opens
	# that one's graph, and a raid put down is picked back up holding it. The
	# empty hand leaves it on the weapon last in hand, which has a graph to open.
	player.weapon_switched.connect(func(_weapon: String) -> void:
		if not player.empty_handed():
			GameState.raid_hand = player.hand)
	player.died.connect(_on_player_died)
	add_child(player)

	if parked.is_empty():
		_start_in(map.entry)
		return
	# Back into the room it was left in, standing where it was left standing —
	# if that is in the room: a save from before rooms stood apart puts them
	# where the room starts a player instead.
	var coord := _parked_coord(parked)
	_start_in(coord)
	var at: Array = parked.get("pos", [])
	if at.size() == 2:
		var pos := Vector2(float(at[0]), float(at[1]))
		if coord_at(pos) == coord:
			player.global_position = pos
			player.velocity = Vector2.ZERO
	_update_window()
	player.health = clampf(float(parked.get("health", player.health)), 1.0, player.max_health)
	# The shuriken that were in hand: any stuck in the room it was put down in
	# were left behind with it, as walking out of a room leaves them.
	var stock: Dictionary = parked.get("stock", {})
	for w in stock:
		if player.stock.has(String(w)):
			player.stock[String(w)] = clampi(int(stock[w]), 0, Weapons.stack_of(String(w)))

## Puts a previous death's drop into the room it was left in. The map is that
## same map — the deployment reused the seed that built
## it — so the room is there, in the same place, with the same way in. What is
## written is the room's own record, which is what `Room.build` reads its
## contents out of.
##
## A drop from another map is left where it is rather than moved here: it
## belongs to a floor the player can still go back to, and dragging it onto
## this one would quietly turn a recovery run into a free delivery.
func _place_lost_kit() -> void:
	var kit: Dictionary = GameState.lost_kit
	if kit.is_empty() or int(kit.get("seed", 0)) != map.seed_base:
		return
	var c: Array = kit.get("room", [])
	if c.size() != 2:
		return
	var coord := Vector2i(int(c[0]), int(c[1]))
	if not map.has_room(coord):
		return
	(map.get_record(coord) as Dictionary)["lost_kit"] = kit.duplicate(true)

## The thrown weapons lying in this map's rooms, by the records the rooms keep:
## the rock, if a run put down left it on a floor somewhere.
func _rocks_left_lying() -> Array:
	var out: Array = []
	for c in map.rooms:
		for r in (map.rooms[c] as Dictionary).get("rocks", []):
			out.append(String((r as Dictionary).get("weapon", "")))
	return out

func _parked_coord(parked: Dictionary) -> Vector2i:
	var c: Array = parked.get("room", [])
	if c.size() != 2:
		return map.entry
	var coord := Vector2i(int(c[0]), int(c[1]))
	return coord if map.has_room(coord) else map.entry

## The run, written down where it stands, for `GameState.park_raid`. The rooms
## stood up are the ones whose records are out of date — what is still
## standing in each and where it has got to is in the room, not in the map — so
## they are written back first, exactly as taking a room down writes it back.
func park() -> Dictionary:
	for c in rooms:
		(rooms[c] as Room).save_state()
	var saved := map.to_save()
	saved["room"] = [room.coord.x, room.coord.y] if room != null else [map.entry.x, map.entry.y]
	var at := player.global_position
	saved["pos"] = [at.x, at.y]
	saved["health"] = player.health
	saved["stock"] = player.stock.duplicate()
	saved["phone"] = Phone.to_save()
	saved["hunters"] = _hunters_to_save()
	return saved

func _process(delta: float) -> void:
	if ended:
		return
	map.advance(delta)
	# The phone's clock runs on the raid's: an alarm set in here rings in here.
	Phone.tick(delta, _phone_here())
	_update_window()
	_sort_tenants()
	_update_hunters(delta)
	_update_prompt()

## --- the rooms stood up ----------------------------------------------------
## Only the rooms round the player are ever live: the one they are in, and
## the one beside it through a doorway once they are near the seam. Each
## stands where the floor puts it, so the way through a doorway is walked —
## the body, a bolt, a monster at the player's heels all cross the seam as
## they would cross the room — and the picture follows. A room left behind is
## written back into its record and taken down; a monster that was in it and
## had walked through the doorway is the other room's by then (`_hand_over`).
## A doorway may be in any of the four walls.

## How near the seam with the room beside the player comes before that room
## is stood up — half a screen, so it is there before the screen reaches it —
## and how far from the seam they go before it is taken down again: further,
## so a player at a doorway does not have the room beyond built and torn down
## with every step. Across, by the room's width; up and down the floor, by its
## depth, which is little more than half its width — measured by the width,
## every point of a room is within LOAD_NEAR of both the seam above it and the
## one below, and both rooms would stand all the time.
const LOAD_NEAR := Room.W * Room.CELL * 0.5
const UNLOAD_FAR := Room.W * Room.CELL * 1.5
const LOAD_NEAR_DOWN := Room.H * Room.CELL * 0.5
const UNLOAD_FAR_DOWN := Room.H * Room.CELL * 1.5

## Which room on the floor the world point `gp` is in.
static func coord_at(gp: Vector2) -> Vector2i:
	return Vector2i(floori(gp.x / float(Room.W * Room.CELL)), floori(gp.y / float(Room.H * Room.CELL)))

## The raid's first room: stood up, with the player on its spawn point.
func _start_in(coord: Vector2i) -> void:
	var r := _load_room(coord)
	_settle(r)
	player.global_position = r.to_global(r.spawn_point())
	player.velocity = Vector2.ZERO

## The player is in `r` now: it is a room they have been in, for the map.
func _settle(r: Room) -> void:
	room = r
	player.room = r
	r.data["visited"] = true
	room_changed.emit(r)

## The air swept for a cut: a thrown weapon still flying comes down where it
## is, to be the room's it is over, and everything else — bolts, arcs, lunges,
## bursts, the follow-ups waiting — is gone. After the rooms left behind have
## been written back, so a rock brought down in one of them is written with it.
func _sweep_air() -> void:
	var w := Attacks.container()
	if w != null and is_instance_valid(w):
		for c in w.get_children():
			if c is Projectile and not c.is_queued_for_deletion() \
					and ((c as Projectile).is_rock() or (c as Projectile).sticks != ""):
				(c as Projectile).drop_now()
	Attacks.clear_in_flight(self)

## Stands up the rooms the player is near and takes down the ones they have
## left behind: the room they are in, always; a room beside it through a
## doorway, on any side, once they are within LOAD_NEAR of the seam, kept
## until they are UNLOAD_FAR from it — LOAD_NEAR_DOWN and UNLOAD_FAR_DOWN for
## a seam above or below; and nothing else.
func _update_window() -> void:
	if player == null or not is_instance_valid(player):
		return
	var here := coord_at(player.global_position)
	if not map.has_room(here):
		here = room.coord if room != null and is_instance_valid(room) else map.entry
	if not rooms.has(here):
		_load_room(here)
	if room != rooms[here]:
		_settle(rooms[here])
	var keep: Array[Vector2i] = [here]
	var ways: Dictionary = map.doors_for(here)
	for dir: int in [Components.W, Components.E, Components.N, Components.S]:
		if not ways.has(dir):
			continue
		var beside: Vector2i = here + RaidMap.dir_delta(dir)
		if not map.has_room(beside):
			continue
		var origin := Room.origin_of(here)
		var away := 0.0
		match dir:
			Components.W: away = absf(player.global_position.x - origin.x)
			Components.E: away = absf(player.global_position.x - (origin.x + float(Room.W * Room.CELL)))
			Components.N: away = absf(player.global_position.y - origin.y)
			Components.S: away = absf(player.global_position.y - (origin.y + float(Room.H * Room.CELL)))
		var down := dir == Components.N or dir == Components.S
		if rooms.has(beside):
			if away <= (UNLOAD_FAR_DOWN if down else UNLOAD_FAR):
				keep.append(beside)
		elif away <= (LOAD_NEAR_DOWN if down else LOAD_NEAR):
			_load_room(beside)
			keep.append(beside)
	for c in rooms.keys():
		if not keep.has(c):
			_unload_room(c)

## The world rect the rooms stood up cover: as far as the picture may show.
func live_rect() -> Rect2:
	var out := Rect2()
	for c in rooms:
		var r: Room = rooms[c]
		if not is_instance_valid(r):
			continue
		out = r.bounds() if out.size == Vector2.ZERO else out.merge(r.bounds())
	return out

## The room stood up that the world point `gp` is in, or null.
func _room_owning(gp: Vector2) -> Room:
	var r: Room = rooms.get(coord_at(gp), null)
	return r if r != null and is_instance_valid(r) else null

## Stands up the room at `coord`, where the floor puts it: its map, with the
## floor's record of it — what is in it, what the run has made of it, and the
## ways out it has here. A map gone from under the floor is a plain room of
## rock rather than no room at all. It and any room already up beside it know
## each other, so queries cross the seam between them.
func _load_room(coord: Vector2i) -> Room:
	var rec: Dictionary = map.get_record(coord)
	var r: Room = Maps.load_room(String(rec.get("map", "")))
	if r == null:
		r = Room.new()
	r.player = player
	r.position = Room.origin_of(coord)
	add_child(r)
	r.build(coord, rec, map.doors_for(coord), map.seed_base)
	r.pickup_collected.connect(_on_pickup)
	r.lost_kit_collected.connect(_on_lost_kit)
	r.box_opened.connect(_on_box_opened)
	r.spot_dug.connect(_on_spot_dug)
	r.extraction_progress.connect(_on_extract_progress)
	r.extraction_done.connect(_on_extract_done)
	# The phone, if it was put down in here, lying where it was left.
	if Phone.lies_in("raid", coord):
		PhoneProp.lay(r, player, Phone.placed_pos())
	for c in r.get_children():
		if c is Enemy:
			c.room = r
			_meet(c)
	rooms[coord] = r
	for dir: int in [Components.W, Components.E, Components.N, Components.S]:
		var other: Vector2i = coord + RaidMap.dir_delta(dir)
		if rooms.has(other) and is_instance_valid(rooms[other]):
			r.neighbours[dir] = rooms[other]
			(rooms[other] as Room).neighbours[RaidMap.opposite(dir)] = r
	return r

## Takes the room at `coord` down. Whatever of its stands in a room still up
## is that room's now; the rest is written back into its record, so walking
## back in finds the room that was left rather than a fresh one. A bolt that
## was flying in it goes on in whichever room it is over, or is gone.
func _unload_room(coord: Vector2i) -> void:
	var r: Room = rooms.get(coord, null)
	rooms.erase(coord)
	if r == null or not is_instance_valid(r):
		return
	_hand_over(r, true)
	_send_hunters(r)
	r.save_state()
	for dir in r.neighbours:
		var n = r.neighbours[dir]
		if n != null and is_instance_valid(n):
			(n as Room).neighbours.erase(RaidMap.opposite(int(dir)))
	r.neighbours.clear()
	var w := Attacks.container()
	if w != null and is_instance_valid(w):
		for c in w.get_children():
			if c is Projectile and c.room == r:
				var over := _room_owning((c as Projectile).global_position)
				if over != null:
					c.room = over
				else:
					c.queue_free()
	# Nothing in it gets another turn. A monster's board is mid-cycle when the
	# room goes, and a node that has been freed still runs out the frame it
	# was freed in.
	r.process_mode = Node.PROCESS_MODE_DISABLED
	r.queue_free()
	if room == r:
		room = null

## Every room stood up hands over what of its has walked into another.
func _sort_tenants() -> void:
	for c in rooms.keys():
		var r: Room = rooms[c]
		if is_instance_valid(r):
			_hand_over(r, false)

## What of room `r` stands in another room that is up is moved to that room —
## its child, with its record among that room's, so it is written down where
## it stands. A monster, always; and when `all`, as the room goes, the rock
## and the shuriken lying over the seam too.
func _hand_over(r: Room, all: bool) -> void:
	var moving: Array = []
	for c in r.get_children():
		if not (c is Node2D) or c.is_queued_for_deletion():
			continue
		if not (c is Enemy or (all and (c is LooseRock or c is StuckShuriken))):
			continue
		if r.owns((c as Node2D).global_position):
			continue
		var into := _room_owning((c as Node2D).global_position)
		if into != null and into != r:
			moving.append([c, into])
	for pair in moving:
		var c: Node2D = pair[0]
		var into: Room = pair[1]
		if c is Enemy:
			_move_record(c, r, into)
		c.reparent(into)
		if "room" in c:
			c.set("room", into)

## Monster `e`'s record out of room `from`'s list and into room `into`'s.
func _move_record(e: Enemy, from: Room, into: Room) -> void:
	if not e.has_meta("record"):
		return
	var rec: Dictionary = e.get_meta("record")
	(from.data.get("enemies", []) as Array).erase(rec)
	if not into.data.has("enemies"):
		into.data["enemies"] = []
	(into.data["enemies"] as Array).append(rec)

## Whether a monster is one that could wander the floor after the player at
## all. A boss holds its arena, and one that went after could be met anywhere
## on the map. Something that does not walk does not follow either.
func _can_wander(e: Enemy) -> bool:
	return not bool(e.def.get("boss", false)) and e.ai() != "turret" and not e.piloted()

## --- the hunt, out of sight ---------------------------------------------------
## A monster after the player when its room goes is not simulated on its way:
## its record leaves the room and travels the floor a room at a time, each hop
## taking what the monster's own pace would take across one, re-aimed at
## wherever the player is as it goes. When the room it comes to is stood up,
## it is stood up in it, in from the way it came by, and after them. One that
## has gone HUNT_HOPS rooms without catching up gives the hunt up and waits in
## the room it got to, as any monster in a room not stood up does.

## How many rooms a hunter follows through before it gives up, and the least
## and most one hop takes, in seconds: a Crawler crosses a room in eight, and
## nothing that hunts is slower than a hop of fifteen or quicker than four.
const HUNT_HOPS := 6
const HOP_LEAST := 4.0
const HOP_MOST := 15.0

## Whether `e` is one to carry on after the player once its room goes: after
## them now, and something that goes anywhere at all.
func _keeps_hunting(e: Enemy) -> bool:
	return not e.dead and e.hunting() and e.moves() and _can_wander(e)

## Room `r` is going: each monster in it after the player sets off along the
## floor after them, its record out of the room's.
func _send_hunters(r: Room) -> void:
	for c in r.get_children():
		if not (c is Enemy) or not _keeps_hunting(c) or not c.has_meta("record"):
			continue
		var e := c as Enemy
		var rec: Dictionary = e.get_meta("record")
		rec["hp"] = e.health
		var hop := _next_hop(r.coord, _player_coord())
		if hop.is_empty():
			continue
		(r.data.get("enemies", []) as Array).erase(rec)
		hunters.append({"rec": rec, "at": r.coord, "to": hop[0], "dir": int(hop[1]),
			"left": _hop_time(rec), "hops": 0})
		Cues.at(&"travel", e.global_position)

## The room the player is in.
func _player_coord() -> Vector2i:
	if room != null and is_instance_valid(room):
		return room.coord
	return coord_at(player.global_position) if player != null else map.entry

## How long a hunter with record `rec` takes to cross one room, by its kind's
## pace.
func _hop_time(rec: Dictionary) -> float:
	var def := Monsters.get_def(String(rec.get("kind", "")))
	var pace := maxf(float(def.get("speed", 0.0)), 1.0)
	if String(rec.get("mod", "")) == "swift":
		pace *= 1.5
	return clampf(float(Room.W * Room.CELL) / pace, HOP_LEAST, HOP_MOST)

## The first step of the shortest way over the floor from `from` to `goal`:
## `[coord, dir]` for the room it leads into and the way out it takes, or
## nothing with no way, or nowhere to go.
func _next_hop(from: Vector2i, goal: Vector2i) -> Array:
	if from == goal:
		return []
	var first: Dictionary = {}
	var seen: Dictionary = {from: true}
	var queue: Array = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for dir in map.doors_for(c):
			var n: Vector2i = c + RaidMap.dir_delta(int(dir))
			if seen.has(n):
				continue
			seen[n] = true
			first[n] = first[c] if first.has(c) else [n, int(dir)]
			if n == goal:
				return first[n]
			queue.append(n)
	return []

## Each hunter's clock runs down; one whose hop is up comes into the room it
## was crossing to — stood up in it if the room is, in from the way it came
## by and after the player, or else on to the next room toward them, or, out
## of hops or ways, at rest there.
func _update_hunters(delta: float) -> void:
	if hunters.is_empty():
		return
	var done: Array = []
	for h in hunters:
		h["left"] = float(h["left"]) - delta
		if float(h["left"]) > 0.0:
			continue
		var to: Vector2i = h["to"]
		var rec: Dictionary = h["rec"]
		var came_by := RaidMap.opposite(int(h["dir"]))
		if rooms.has(to) and is_instance_valid(rooms[to]):
			var r: Room = rooms[to]
			var at := map.arrival(to, came_by)
			rec["pos"] = [at.x, at.y]
			var e := r.arrive(rec)
			_meet(e)
			e.hunt(player)
			Cues.at(&"travel", e.global_position)
			done.append(h)
			continue
		h["at"] = to
		h["hops"] = int(h["hops"]) + 1
		var hop := _next_hop(to, _player_coord()) if int(h["hops"]) < HUNT_HOPS else []
		if hop.is_empty():
			# At rest in the room it got to, in from the way it came by, until
			# the room is next stood up.
			var at := map.arrival(to, came_by)
			rec["pos"] = [at.x, at.y]
			var into: Dictionary = map.get_record(to)
			var arrivals: Array = into.get("arrivals", [])
			arrivals.append(rec)
			into["arrivals"] = arrivals
			done.append(h)
			continue
		h["to"] = hop[0]
		h["dir"] = int(hop[1])
		h["left"] = _hop_time(rec)
	for h in done:
		hunters.erase(h)

## The hunters as a parked raid keeps them, and back: a `Vector2i` does not
## survive JSON, so each room is a pair.
func _hunters_to_save() -> Array:
	var out: Array = []
	for h in hunters:
		out.append({"rec": (h["rec"] as Dictionary).duplicate(true),
			"at": [(h["at"] as Vector2i).x, (h["at"] as Vector2i).y],
			"to": [(h["to"] as Vector2i).x, (h["to"] as Vector2i).y],
			"dir": int(h["dir"]), "left": float(h["left"]), "hops": int(h["hops"])})
	return out

func _restore_hunters(saved: Array) -> void:
	hunters.clear()
	for s in saved:
		var at: Array = s.get("at", [])
		var to: Array = s.get("to", [])
		if at.size() != 2 or to.size() != 2 or not (s.get("rec") is Dictionary):
			continue
		hunters.append({"rec": (s["rec"] as Dictionary).duplicate(true),
			"at": Vector2i(int(at[0]), int(at[1])), "to": Vector2i(int(to[0]), int(to[1])),
			"dir": int(s.get("dir", Components.E)), "left": float(s.get("left", HOP_LEAST)),
			"hops": int(s.get("hops", 0))})

func _update_prompt() -> void:
	if room == null or not is_instance_valid(room):
		return
	var txt := ""
	if not room.extraction.is_empty() and room.extraction_rect().has_point(room.to_local(player.global_position)) \
			and player.vessel() == player:
		# Only what is in the way. The line for an exit that is open used to be
		# written here too, and it names the key that extracts — which changed
		# its words with the console, a thing no rule should know. The HUD
		# writes that one now, off `room.extract_offered`.
		txt = room.extraction_blocked_reason()
	prompt = txt

## --- for tests and tools --------------------------------------------------------
## A cut to the room at `coord`: stood up, the player on its spawn point, the
## rooms round it as they would be. Through nothing.
func go_to(coord: Vector2i) -> void:
	if ended or not map.has_room(coord):
		return
	var r: Room = rooms[coord] if rooms.has(coord) else _load_room(coord)
	player.global_position = r.to_global(r.spawn_point())
	player.velocity = Vector2.ZERO
	_settle(r)
	_update_window()
	_sweep_air()
	cut.emit()

## A cut through the way out of the player's room toward `dir`: into the room
## beyond, put down where a body coming in that way is — in from the doorway.
## What walking through the doorway comes to, without the walk.
func go_through(dir: int) -> void:
	if ended or room == null or not is_instance_valid(room):
		return
	var target: Vector2i = room.coord + RaidMap.dir_delta(dir)
	if not map.has_room(target):
		return
	var r: Room = rooms[target] if rooms.has(target) else _load_room(target)
	player.global_position = r.to_global(r.entry_point(RaidMap.opposite(dir)))
	player.velocity = Vector2.ZERO
	_settle(r)
	_update_window()
	_sweep_air()
	cut.emit()

## --- events -----------------------------------------------------------------
func _on_pickup(p: Pickup) -> void:
	if p.scrap_amount > 0:
		GameState.raid_scrap += GameState.gold_found(p.scrap_amount)
	else:
		GameState.add_component(p.component_id, 1, GameState.raid_bag)

## A treasure box, opened. Everything in it goes into the run at once, like a
## pickup but all together.
func _on_box_opened(_box: TreasureBox, items: Array) -> void:
	_take_haul(items)

## Ground dug up with the shovel: what was buried goes into the run the way a
## box's does.
func _on_spot_dug(_spot: DigSpot, items: Array) -> void:
	_take_haul(items)

## Loot records, `{"id": ...}` or `{"scrap": ...}`, into the run's bag and
## purse.
func _take_haul(items: Array) -> void:
	for l in items:
		if l.has("scrap"):
			GameState.raid_scrap += GameState.gold_found(int(l["scrap"]))
		else:
			# The record can be out of a raid parked before one of its parts was renamed.
			GameState.add_component(Components.current_id(String(l["id"])), 1, GameState.raid_bag)

## The drop, picked back up. What was in it goes into the run rather than
## straight home — a recovered kit is being carried, and it still has to be
## walked out — and the rest is left to the exit.
func _on_lost_kit(_k: LostKit) -> void:
	GameState.recover_lost_kit()

func _on_extract_progress(ratio: float, _info: Dictionary) -> void:
	extract_ratio = ratio

func _on_extract_done(info: Dictionary) -> void:
	if ended:
		return
	if String(info.get("cond", "free")) == "cost":
		GameState.raid_scrap -= int(info.get("cost", 0))
	ended = true
	Cues.emit_cue(&"extract_done")
	TimeCtl.clear()
	var result := GameState.extract()
	result["exit"] = RaidMap.exit_name(info)
	finished.emit("extracted", result)

## Where the player fell is where the kit stays. The room and the spot in it go
## with the death, because they are what the next deployment needs to put it
## back on the floor — see `GameState.die`.
func _on_player_died(a: Actor) -> void:
	if ended:
		return
	ended = true
	TimeCtl.clear()
	Cues.emit_cue(&"raid_lost")
	var where: Dictionary = {}
	if room != null and is_instance_valid(room):
		var at := room.to_local(a.global_position)
		where = {"room": [room.coord.x, room.coord.y], "pos": [at.x, at.y]}
	var lost := GameState.die(where)
	finished.emit("died", lost)

## --- assembly ---------------------------------------------------------------
## Opening the workbench does not pause the raid; it only takes the controls
## away from the player, which is the whole risk of editing in the field.
func set_editing(on: bool) -> void:
	if editing == on:
		return
	# One pair of hands: the workbench takes over from the map rather than
	# standing on top of it, so closing either one gives the controls back.
	if on:
		set_reading_map(false)
		set_reading_dex(false)
		set_reading_perks(false)
		set_on_phone(false)
	editing = on
	player.input_locked = _held()
	Cues.emit_cue(&"ui", {"kind": "editor"})
	editing_changed.emit(on)

## --- the map ----------------------------------------------------------------
## Reading the map costs exactly what the workbench costs: the raid runs on, the
## clock keeps climbing and the player stands still while they look. The two are
## pages of one screen, a tab each, so the map takes over from the workbench the
## way the workbench does from the map.
func set_reading_map(on: bool) -> void:
	if reading_map == on:
		return
	if on:
		set_editing(false)
		set_reading_dex(false)
		set_reading_perks(false)
		set_on_phone(false)
	reading_map = on
	player.input_locked = _held()
	Cues.emit_cue(&"ui", {"kind": "map"})
	reading_map_changed.emit(on)

## The monster dictionary: the screen's third page, costing what the other two
## cost, and taking over from either the way they take over from each other.
func set_reading_dex(on: bool) -> void:
	if reading_dex == on:
		return
	if on:
		set_editing(false)
		set_reading_map(false)
		set_reading_perks(false)
		set_on_phone(false)
	reading_dex = on
	player.input_locked = _held()
	Cues.emit_cue(&"ui", {"kind": "map"})
	reading_dex_changed.emit(on)

## --- the perks ----------------------------------------------------------------
## The fourth page of the same screen, a tab beside the other three: what the
## player buys for themselves (perks/), which the raid knows only as a page that
## is up. It costs what the others cost — the raid runs on and the player
## stands still while they look — and takes over from any of them the same way.
func set_reading_perks(on: bool) -> void:
	if reading_perks == on:
		return
	if on:
		set_editing(false)
		set_reading_map(false)
		set_reading_dex(false)
		set_on_phone(false)
	reading_perks = on
	player.input_locked = _held()
	Cues.emit_cue(&"ui", {"kind": "perks"})
	reading_perks_changed.emit(on)

## --- the phone ----------------------------------------------------------------
## The phone up over the raid (`Phone`, `PhoneScreen`): it costs what a page
## of the screen costs — the raid runs on, the clock keeps climbing, and the
## player stands still looking at it — and it takes over from any page the way
## they take over from each other. The shell puts it up and says so here.
func set_on_phone(on: bool) -> void:
	if on_phone == on:
		return
	if on:
		set_editing(false)
		set_reading_map(false)
		set_reading_dex(false)
		set_reading_perks(false)
	on_phone = on
	player.input_locked = _held()
	on_phone_changed.emit(on)

## The bench's screen, up over the raid while the player sits (`HeroSelect`):
## it costs what the phone costs — the raid runs on, the player stays sat and
## still — and the shell puts it up and takes it down.
func set_choosing(on: bool) -> void:
	if choosing == on:
		return
	choosing = on
	player.input_locked = _held()
	choosing_changed.emit(on)

## Where the phone is, for its clock (`Phone.tick`): in the player's hand,
## lying in this room, or null for one lying in a room out of sight.
func _phone_here() -> Variant:
	var here: Variant = null
	if Phone.carried():
		if player != null and is_instance_valid(player):
			here = player.global_position
	elif room != null and is_instance_valid(room) and Phone.lies_in("raid", room.coord):
		var prop := phone_prop()
		here = prop.global_position if prop != null else room.to_global(Phone.placed_pos())
	return here

## The phone lying in the room being stood in, or null.
func phone_prop() -> PhoneProp:
	if room == null or not is_instance_valid(room):
		return null
	for c in room.get_children():
		if c is PhoneProp and not c.is_queued_for_deletion():
			return c
	return null

## The phone put down where the player stands, on this room's floor, to be
## walked away from. Nothing happens with it already lying somewhere.
func put_phone_down() -> bool:
	if ended or room == null or player == null or not Phone.carried():
		return false
	var at := player.global_position
	Phone.put_down_at("raid", room.coord, room.to_local(at), at)
	PhoneProp.lay(room, player, room.to_local(at))
	return true

## Whether a page of the screen, or the phone, is up over the raid, holding
## the player still.
func _held() -> bool:
	return editing or reading_map or reading_dex or reading_perks or on_phone or choosing

## A monster in the room just come into: met, for the monster dictionary, and
## heard from whenever its attack goes off, which is its skill seen. A room is
## the screen, so whatever is in it is in sight.
func _meet(e: Enemy) -> void:
	if not Monsters.DEX.has(e.kind):
		return
	GameState.discover_monster(e.kind)
	e.attacked.connect(func(skill: String) -> void: GameState.discover_skill(e.kind, skill))

func on_board_changed() -> void:
	player.rebuild_runner()

## An exit the player is standing in, with nothing sealing it, a shut
## treasure box within reach, ground to dig with the shovel in hand,
## or — from inside a monster — the body, with the weapon in its hands to take.
func use_nearby() -> bool:
	if player != null and player.can_take_weapon():
		return true
	return room != null and is_instance_valid(room) \
		and (room.extract_offered or room.box_offered() or room.dig_offered()
			or room.phone_offered())
