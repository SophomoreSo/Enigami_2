extends Node2D
## The dragon test has to be what it says: guards posted apart in different
## halls, each dropped by a single cut, and all of them taken by one charged
## cast of the board the screen hands out — including the charged cast straight
## after a tap, which used to go out carrying the tap's empty chain.

var fails := 0
var screen: DragonTest

func check(ok: bool, what: String) -> void:
	if ok:
		print("[DRAGON] PASS ", what)
	else:
		fails += 1
		push_error("DRAGON FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()

func mouse(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = down
	Input.parse_input_event(e)

## Lunges and follow-ups still to land.
func in_flight() -> int:
	var n := 0
	for c in screen.get_children():
		if c is Attacks.Deferred or c is DashSlash:
			n += 1
	return n

## Waits out whatever chain is running.
func settle() -> void:
	var quiet := 0
	var guard := 0
	while quiet < 20 and guard < 3000:
		await get_tree().process_frame
		guard += 1
		quiet = quiet + 1 if in_flight() == 0 else 0

func ready_to_cast() -> void:
	var guard := 0
	while not screen.player.runner.is_ready() and guard < 900:
		await get_tree().process_frame
		guard += 1
	await frames(2)

## Presses the cast button, lets `bonus` of charge stand in for the hold, and
## lets go.
func cast_with(bonus: float) -> void:
	await ready_to_cast()
	mouse(true)
	await frames(2)
	screen.player.mana = Player.MAX_MANA
	screen.player.charge = bonus
	mouse(false)
	await frames(3)
	await settle()

func guards() -> Array:
	return screen.room.get_children().filter(func(c: Node) -> bool: return c is Enemy and not c.dead)

func _ready() -> void:
	screen = DragonTest.new()
	add_child(screen)
	await frames(8)
	var room := screen.room
	var p := screen.player

	# The building is laid out by hand, a row of cells at a time.
	# As wide as a room, and three rooms tall.
	var rows_ok := DragonTower.LAYOUT.size() == Room.H * 3
	for row in DragonTower.LAYOUT:
		rows_ok = rows_ok and String(row).length() == Room.W
	check(rows_ok and room.rows == Room.H * 3 and room.cols == Room.W,
		"the layout is %d rows of %d cells" % [Room.H * 3, Room.W])

	var posts := room.cells_marked("G")
	check(posts.size() >= 6, "a squad to cut through (%d guards)" % posts.size())
	check(screen.total_guards == posts.size() and guards().size() == posts.size(),
		"with a guard on every post (%d of %d)" % [guards().size(), posts.size()])
	var halls := {}
	var closest := INF
	for i in posts.size():
		halls[posts[i].y] = true
		for j in range(i + 1, posts.size()):
			closest = minf(closest, Vector2(posts[i]).distance_to(Vector2(posts[j])))
	check(halls.size() >= 3, "posted in different halls (%d of them)" % halls.size())
	check(closest >= 4.0, "and kept apart (the closest two are %.1f cells)" % closest)

	# Guards hold their posts: in the middle of their cells, on open floor.
	await frames(30)
	var off := 0
	for e in guards():
		var cell := Vector2i(int(e.global_position.x / Room.CELL), int(e.global_position.y / Room.CELL))
		if not posts.has(cell) or room.is_solid(cell.x, cell.y) \
				or e.global_position.distance_to(room.stand_point(cell)) > 4.0:
			off += 1
	check(off == 0, "every guard holds its post, on the floor (%d do not)" % off)

	# One cut drops one, whatever weapon it comes off.
	var hp: float = guards()[0].max_health
	for w in Weapons.ids():
		check(Weapons.base_payload(w).damage >= hp,
			"a %s cut (%.0f) is a guard's whole life (%.0f)" % [w, Weapons.base_payload(w).damage, hp])
	# One lunge from the door, uncharged: the nearest guard and nobody else.
	p.global_position = room.spawn_point()
	var nearest: Enemy = guards()[0]
	for e in guards():
		if e.global_position.distance_to(p.global_position) < nearest.global_position.distance_to(p.global_position):
			nearest = e
	var cut := Weapons.base_payload("GUN")
	cut.form = "DASHSLASH"
	cut.auto_aim = 1
	Attacks.spawn(cut, {"attacker": p, "room": room, "team": 0, "aim": Vector2.RIGHT,
		"origin": p.global_position})
	await settle()
	check(not is_instance_valid(nearest) or nearest.dead, "and a single live cut kills it")
	check(screen.guards_left == screen.total_guards - 1, "that guard and no other (%d left)" % screen.guards_left)
	screen.reset_floor()
	await frames(4)
	check(guards().size() == screen.total_guards, "resetting stands every guard back up (%d)" % guards().size())

	# The whole floor, from the door, off one real hold of the button.
	var need := screen.charge_to_clear()
	check(need >= 0, "some charge the player can hold reaches every guard (+%d)" % need)
	check(screen.chain_length(0) == 1, "while a tap is a single lunge (%d)" % screen.chain_length(0))
	await ready_to_cast()
	mouse(true)
	var held := 0.0
	while p.charge < float(need) + 1.0 and held < 6.0:
		await get_tree().process_frame
		held += get_process_delta_time()
	mouse(false)
	await frames(3)
	await settle()
	check(screen.guards_left == 0,
		"one charged cast from the door clears the floor (%d of %d left, held %.2fs)"
			% [screen.guards_left, screen.total_guards, held])
	check(screen.best_cast == screen.total_guards, "every guard fell to that one cast (%d)" % screen.best_cast)

	# It sets itself again, and a tap followed by a charge still clears it.
	await wait(DragonTest.RESET_DELAY + 0.4)
	check(guards().size() == screen.total_guards, "a cleared floor sets itself again (%d)" % guards().size())
	check(p.global_position.distance_to(room.spawn_point()) < 2.0, "with the player back at the door")
	await cast_with(0.0)
	check(screen.total_guards - screen.guards_left == 1,
		"a tap takes the nearest guard and stops (%d down)" % (screen.total_guards - screen.guards_left))
	screen.reset_floor()
	await frames(4)
	await cast_with(float(need) + 1.0)
	check(screen.guards_left == 0,
		"and the charged cast right after it clears the floor (%d left)" % screen.guards_left)

	print("[DRAGON] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
