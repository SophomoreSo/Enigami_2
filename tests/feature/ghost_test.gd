extends Node2D
## The ghost test has to be what it says: a diamond in a guarded building, a
## nook nobody can see into to wait in, and a way to the diamond through the
## guards one after another — the rock's graph putting the player's hands into
## each — that a player can actually take. The theft is done only when the
## player's own body has the diamond back in the nook, and the ground sets
## itself again after a theft, after a fall, and on R.
##
## The way through is played, not asserted: the computer's hands wait in the
## nook for the gate guard to look away, throw the rock into its back, walk it
## in as one of them, throw on into the guard that flies, fly the diamond off
## its island and hand it back from one guard to the next to the body, and
## carry it home.

var fails := 0
var screen: GhostTest
var hands: ComputerHands
var stolen := 0
var fell := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[GHOST] PASS ", what)
	else:
		fails += 1
		push_error("GHOST FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()

## Waits until `cond` holds, for at most `secs`. Whether it did.
func until(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while t < secs:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()

func guards() -> Array:
	return screen.room.get_children().filter(func(c: Node) -> bool: return c is Enemy and not c.dead)

func guard(kind: String) -> Enemy:
	for e in guards():
		if e.kind == kind:
			return e
	return null

## The guard of `kind` nearest column `col`.
func nearest(kind: String, col: int) -> Enemy:
	var best: Enemy = null
	for e in guards():
		if e.kind == kind and (best == null or absf(e.global_position.x - (col + 0.5) * Room.CELL)
				< absf(best.global_position.x - (col + 0.5) * Room.CELL)):
			best = e
	return best

func gunman_near(col: int) -> Enemy:
	return nearest("GUNMAN", col)

func crawler_near(col: int) -> Enemy:
	return nearest("CRAWLER", col)

## The Crawler in front of the gate: the nearest to the nook.
func gate_guard() -> Enemy:
	return nearest("CRAWLER", 0)

func rock() -> LooseRock:
	for c in screen.room.get_children():
		if c is LooseRock and not c.is_queued_for_deletion():
			return c
	return null

## The middle of cell (x, y) of the ground, in the world.
func cell(x: float, y: float) -> Vector2:
	return screen.room.to_global(Vector2(x + 0.5, y + 0.5) * Room.CELL)

## The computer's hands on the body there is now: a reset makes a new one.
func take_hands() -> void:
	hands = ComputerHands.new()
	screen.player.input.add(hands)

## Walks — or flies — whatever the player is in straight to `at`, sprinting.
## Whether it got there.
func walk_to(at: Vector2, secs: float = 10.0) -> bool:
	var t := 0.0
	var there := false
	hands.sprint = true
	while t < secs:
		var d := at - screen.player.vessel().global_position
		if d.length() < 6.0:
			there = true
			break
		hands.walk(d.normalized())
		await get_tree().process_frame
		t += get_process_delta_time()
	hands.walk(Vector2.ZERO)
	hands.sprint = false
	return there

## Along `points`, one after the next.
func walk_path(points: Array) -> bool:
	for at: Vector2 in points:
		if not await walk_to(at):
			return false
	return true

## One throw of the rock's graph at `at`. How long the player had left in the
## monster they threw from is kept, for saying how close it was. The body takes
## its aim at the end of a frame, so the press waits until it is aiming there.
var last_left := 0.0

func throw_at(at: Vector2) -> void:
	var p := screen.player
	last_left = p.possess_left
	hands.point_at(at)
	await until(func() -> bool:
		return p.aim.dot((at - p.vessel().global_position).normalized()) > 0.99, 1.0)
	hands.attack = true
	await frames(2)
	hands.attack = false

## The test's own camera, for a run with nothing to draw with (CI's module
## split): the ground is three screens across and the computer's hands point
## with the game's pointer, which stays on the screen — so with no camera
## following, a throw from the second screen is aimed back at the edge of the
## first. The screen's view brings the camera when there is one; this is the
## same eye, on whoever the player is in.
var eye: Camera2D = null

func _look() -> void:
	if eye == null or screen == null or screen.room == null or screen.player == null:
		return
	var width := float(screen.room.cols * Room.CELL)
	var half := get_viewport().get_visible_rect().size.x * 0.5
	eye.position = Vector2(clampf(screen.player.vessel().global_position.x, half, width - half),
		screen.room.rows * Room.CELL * 0.5)

func _process(_delta: float) -> void:
	_look()

func _ready() -> void:
	seed(20261003)
	screen = GhostTest.new()
	screen.stolen.connect(func(_s: float) -> void: stolen += 1)
	screen.fell.connect(func() -> void: fell += 1)
	add_child(screen)
	await frames(20)
	if get_viewport().get_camera_2d() == null:
		eye = Camera2D.new()
		add_child(eye)
		eye.make_current()
		_look()
	_ground()
	_board()
	await _shot_down()
	await _the_theft()
	await _whose_hands()
	await _the_body_falls()
	await _setting_it_again()
	print("[GHOST] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the ground ---------------------------------------------------------------
func _ground() -> void:
	var room := screen.room
	var rows_ok := GhostBase.LAYOUT.size() == Room.H
	for row in GhostBase.LAYOUT:
		rows_ok = rows_ok and String(row).length() == room.cols
	check(rows_ok and room.rows == Room.H, "the ground is %d rows high, every one as long" % Room.H)
	check(room.cols * Room.CELL >= 3 * Room.W * Room.CELL,
		"and three screens across (%d cells)" % room.cols)

	var posts := 0
	var facing_ok := true
	for mark in GhostBase.POSTS:
		posts += room.cells_marked(String(mark)).size()
	for e in guards():
		var rec: Dictionary = e.get_meta("record")
		var way: Array = rec["facing"]
		facing_ok = facing_ok and e.facing.is_equal_approx(Vector2(float(way[0]), float(way[1])))
	check(screen.total_guards == posts and guards().size() == posts,
		"a guard on every post (%d of %d)" % [guards().size(), posts])
	check(guards().filter(func(e: Enemy) -> bool: return e.kind == "GUNMAN").size() >= 3,
		"Gunmen among them")
	check(facing_ok, "each looking the way its post says")
	var placed := true
	for e in guards():
		placed = placed and room.is_floor_at(e.global_position) \
			and (e.height > 0.0 if e.ai() == "flyer" else is_zero_approx(e.height))
	check(placed, "every one at its post on the floor, and the one that flies up off it")

	# The nook is the one place to wait: nobody can see into it.
	var seen: Array = []
	for c in room.cells_marked(",") + room.cells_marked("P"):
		var at := room.to_global(room.stand_point(c))
		for e in guards():
			if room.has_line_of_sight(e.global_position, at):
				seen.append("%s from %s" % [c, e.kind])
	check(seen.is_empty(), "no guard can see into the nook (%s)" % str(seen))
	check(room.in_start(screen.player.global_position), "and the player starts in it")

	# Behind the gate guard, nothing else notices the body: only the gate guard
	# can give it away, and only by looking round.
	var g1 := gate_guard()
	var behind := g1.global_position + Vector2(-96.0, 0.0)
	var others: Array = []
	for e in guards():
		if e != g1 and room.has_line_of_sight(e.global_position, behind) \
				and e.global_position.distance_to(behind) <= float(e.def["aggro"]):
			others.append(e.kind)
	check(others.is_empty(), "behind the gate guard, nobody else can see the body (%s)" % str(others))

	# The diamond is out of any dash: the pit round its island is wider than a
	# dash carries a body, so only something that flies gets to it.
	var gem := screen.diamond
	var spot := Vector2i(room.to_local(gem.global_position) / Room.CELL)
	var reach := Player.DASH_SPEED * Player.DASH_TIME + Player.BODY.x
	var narrowest := INF
	for way: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var c := spot
		while not room.is_pit(c.x, c.y) and not room.is_solid(c.x, c.y):
			c += way
		var across := 0
		while room.is_pit(c.x, c.y):
			c += way
			across += 1
		narrowest = minf(narrowest, float(across * Room.CELL))
	check(narrowest > reach,
		"the diamond's island has a pit all round it %.0f px across at its narrowest, past a dash (%.0f)"
			% [narrowest, reach])
	check(gem.carrier == null and gem.global_position.distance_to(room.diamond_point()) < 1.0,
		"and lies on its island in nobody's hands")

## --- the rock's graph, and the Gunman's ------------------------------------------
func _board() -> void:
	var r := SkillRunner.new(screen.board)
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload(GhostTest.WEAPON)
	var outs: Array = r.simulate()["outputs"]
	var p: Payload = outs[0] if outs.size() == 1 else null
	check(p != null and p.form == "PROJECTILE" and is_equal_approx(p.possess, 10.0),
		"the rock's graph throws it carrying POSSESS twice, ten seconds (%s)"
			% (Attacks.summary(p) if p != null else "nothing"))
	check(screen.player.weapon_id == "ROCK" and screen.player.holds("ROCK"),
		"and the player starts with the rock in hand")
	check(is_equal_approx(screen.player.max_health, GhostTest.BODY_HEALTH),
		"the body has %.0f, whatever the profile has built" % GhostTest.BODY_HEALTH)

	var gun := gunman_near(36)
	var shot: Payload = gun.runner.simulate()["outputs"][0]
	check(shot.damage * 2.0 < GhostTest.BODY_HEALTH and shot.damage * 3.0 >= GhostTest.BODY_HEALTH,
		"a Gunman's shot (%.0f) takes three to put the body down, two after anything else" % shot.damage)
	check(not Monsters.NORMAL_POOL.has("GUNMAN") and Monsters.get_def("GUNMAN")["ai"] == "turret",
		"and a Gunman holds its post, and is never met in a raid")

## Stood in the hall in front of the Gunman watching the gate, the body takes
## three shots.
func _shot_down() -> void:
	var p := screen.player
	var gun := gunman_near(36)
	var hits := [0]
	p.damaged.connect(func(_a: Actor, _n: float) -> void: hits[0] += 1)
	p.global_position = gun.global_position + Vector2(-5.0 * Room.CELL, 0.0)
	gun.face(Vector2.LEFT)
	check(await until(func() -> bool: return fell == 1, 8.0),
		"the body stood in front of a Gunman is shot down")
	check(hits[0] == 3, "by its third shot (%d)" % hits[0])
	await wait(GhostTest.RESET_DELAY + 0.3)
	fell = 0

## --- one way through, played --------------------------------------------------
## Throws the rock from the monster the player is in, `back` px along the row
## from `target`, into it. Whether the hands went in.
func hop(target: Enemy, back: float) -> bool:
	var p := screen.player
	await walk_to(target.global_position + Vector2(back, 0.0))
	await throw_at(target.global_position)
	return await until(func() -> bool: return p.possessing == target, 1.5)

## Walks the monster the player is in over the rock where it came down.
func fetch_rock() -> bool:
	var p := screen.player
	if not await until(func() -> bool: return rock() != null and rock().resting, 2.0):
		return false
	await walk_to(rock().global_position)
	return await until(func() -> bool: return p.holds("ROCK") and p.weapon_hands() == p.vessel(), 1.0)

## And over the diamond.
func fetch_diamond() -> bool:
	var gem := screen.diamond
	var p := screen.player
	await until(func() -> bool: return gem.settled(), 2.0)
	await walk_to(gem.global_position)
	return await until(func() -> bool: return gem.carrier == p.vessel(), 1.0)

func _the_theft() -> void:
	take_hands()
	var p := screen.player
	var g1 := gate_guard()
	var g3 := crawler_near(60)
	var flyer := guard("DRIFTER")
	var gm7 := gunman_near(104)
	var gem := screen.diamond

	# Waiting in the nook for the gate guard to look the other way: along the
	# hall, its back to the yard. A glance is a quarter turn either way, so it
	# takes two to face away, and two glances do it one time in two: room for
	# twenty is room for it all but one time in a thousand.
	check(await until(func() -> bool: return g1.facing.x > 0.9, 20.0 * Enemy.GLANCE_MAX),
		"the gate guard looks away while the player waits")
	await walk_path([cell(1.5, 17), cell(1.5, 16), g1.global_position + Vector2(-96.0, 0.0)])
	check(screen.alerted() == 0, "out of the nook and up behind it, unseen")
	await throw_at(g1.global_position)
	check(await until(func() -> bool: return p.possessing == g1, 1.5),
		"the rock in its back puts the player's hands into it")

	# In through the gate as one of them, past the Gunman watching it, and into
	# the Crawler down the hall.
	check(await fetch_rock(), "the gate guard picks the rock back up")
	check(await hop(g3, -96.0), "and throws it into the Crawler at the end of the hall (%.1fs were left)" % last_left)

	# Into the vault, under the Drifter, and up into it under the Gunmen's eyes:
	# a throw that lands POSSESS hurts none of them that is left to tell.
	check(await fetch_rock(), "the Crawler picks it up")
	await walk_to(Vector2(flyer.global_position.x, g3.global_position.y))
	check(p.possessing == g3, "and walks it under the Drifter as one of them (%.1fs left)" % p.possess_left)
	await throw_at(flyer.global_position)
	check(await until(func() -> bool: return p.possessing == flyer, 1.5), "thrown up into the Drifter")

	# The rock off the floor under it, over the pit to the island for the
	# diamond, and back over to the Gunman by the pit, and into him.
	check(await fetch_rock(), "the Drifter takes the rock off the floor (%.1fs left)" % p.possess_left)
	await walk_to(gem.global_position)
	check(await until(func() -> bool: return gem.carrier == flyer, 1.0),
		"and flies over the pit to take the diamond off its island")
	await walk_to(gm7.global_position + Vector2(0.0, -96.0))
	await throw_at(gm7.global_position)
	check(await until(func() -> bool: return p.possessing == gm7, 1.5),
		"flown back over the pit and thrown into the Gunman by it (%.1fs were left)" % last_left)

	# The Gunman carries both back to the Crawler that carried the rock in,
	# still standing where the player left it, and that one back to the gate
	# guard; a guard can be taken again, since POSSESS does it no harm.
	check(await fetch_rock(), "the Gunman picks up the rock")
	check(await fetch_diamond(), "and the diamond the Drifter let go of")
	var shots := [0]
	var count_shots := func(cue: StringName, d: Dictionary) -> void:
		if cue == &"attack" and (d.get("payload") as Payload) != null and (d.get("payload") as Payload).damage >= 40.0:
			shots[0] += 1
	Cues.fired.connect(count_shots)
	check(await hop(g3, 96.0), "and carries them back to the Crawler (%.1fs were left)" % last_left)
	Cues.fired.disconnect(count_shots)
	check(shots[0] == 0, "and throwing it, the Gunman fires nothing of its own (%d shots)" % shots[0])
	check(await fetch_rock() and await fetch_diamond(), "which takes both")
	check(await hop(g1, 96.0), "and carries them up the hall into the old gate guard (%.1fs were left)"
		% last_left)
	check(is_equal_approx(g1.health, g1.max_health), "taken twice, and not a scratch on it")

	# Out of the gate to the body, and home.
	check(await fetch_rock() and await fetch_diamond(), "which takes both")
	await walk_to(p.global_position + Vector2(96.0, 0.0))
	check(p.possessing == g1 and gem.carrier == g1,
		"out of the gate and across the yard to the body (%.1fs left)" % p.possess_left)
	hands.step_out()
	check(await until(func() -> bool: return gem.settled(), 2.0),
		"stepping out lets go of it, and it lies on the floor")
	await walk_to(gem.global_position)
	check(await until(func() -> bool: return gem.carried_by_player(), 1.0), "the body picks it up")
	await walk_path([cell(1.5, 16), cell(1.5, 17), screen.room.to_global(screen.room.spawn_point())])
	check(await until(func() -> bool: return stolen == 1, 1.0) and screen.over,
		"and carried back into the nook, it is stolen (%.1fs)" % screen.best)

	await wait(GhostTest.RESET_DELAY + 0.3)
	check(not screen.over and guards().size() == screen.total_guards,
		"then the ground sets itself again (%d guards)" % guards().size())
	check(gem.carrier == null and gem.global_position.distance_to(screen.room.diamond_point()) < 1.0,
		"with the diamond back on its island")

## --- whose hands ----------------------------------------------------------------
func _whose_hands() -> void:
	var p := screen.player
	var gem := screen.diamond
	var warden := guard("WARDEN")
	var crawler := guard("CRAWLER")
	var flyer := guard("DRIFTER")

	# A throw that hurts nobody gives nothing away, even under a Gunman's nose.
	take_hands()
	var gm := gunman_near(36)
	p.possess(crawler, 5.0)
	p.take_back("ROCK", crawler)
	crawler.global_position = gm.global_position + Vector2(-4.0 * Room.CELL, 0.0)
	gm.face(Vector2.LEFT)
	await frames(4)
	await throw_at(crawler.global_position + Vector2(-200.0, -60.0))
	await wait(1.0)
	check(p.possessing == crawler and not crawler.revealed and not gm._hunts(crawler) and gm.target != crawler,
		"a throw from a guard the player is in that hurts nobody gives nothing away, in front of a Gunman")
	p.release()
	screen.reset_floor()
	await frames(4)
	p = screen.player
	crawler = gate_guard()
	warden = guard("WARDEN")
	flyer = guard("DRIFTER")

	# A monster with its own mind leaves it where it is.
	gem.place(warden.global_position)
	await wait(0.6)
	check(gem.carrier == null, "a guard with its own mind never picks the diamond up")

	# One the player is in does, and hopping on lets go of it.
	p.possess(crawler, 5.0)
	gem.place(crawler.global_position)
	check(await until(func() -> bool: return gem.carrier == crawler, 1.0), "a guard the player is in takes it")
	var was := crawler.global_position
	p.possess(flyer, 5.0)
	await frames(2)
	check(gem.carrier == null and gem.global_position.distance_to(was) < Room.CELL,
		"hopping on to the next lets go of it where the last one stood")

	# Let go of by the one that flies, it lies on the floor under it — or, over
	# the pit, it is lost down it and found again on its island.
	await until(func() -> bool: return gem.settled(), 2.0)
	gem.place(flyer.global_position)
	check(await until(func() -> bool: return gem.carrier == flyer, 1.0), "the one that flies takes it")
	var under := flyer.global_position
	p.release()
	await frames(2)
	check(gem.carrier == null and gem.global_position.distance_to(under) < 1.0 and is_zero_approx(gem.height),
		"and let go of over the floor, it lies on it under where the flyer was")
	await until(func() -> bool: return gem.settled(), 2.0)
	var over_pit := cell(106, 7)
	check(screen.room.is_pit_at(over_pit), "(a cell of the pit round the island)")
	p.possess(flyer, 5.0)
	flyer.global_position = over_pit
	gem.place(over_pit)
	check(await until(func() -> bool: return gem.carrier == flyer, 1.0), "taken up over the pit")
	p.release()
	await frames(2)
	check(gem.carrier == null and gem.global_position.distance_to(screen.room.diamond_point()) < 1.0,
		"let go of there, it goes down the pit and is found again on its island")
	screen.reset_floor()
	await frames(4)

## --- the body falls -------------------------------------------------------------
func _the_body_falls() -> void:
	var p := screen.player
	p.apply_damage(99999.0)
	await frames(2)
	check(fell == 1 and screen.over, "the body falling ends the attempt")
	await wait(GhostTest.RESET_DELAY + 0.3)
	check(is_instance_valid(screen.player) and not screen.player.dead and not screen.over
			and screen.room.in_start(screen.player.global_position),
		"and a new one is in the nook a moment later")
	check(stolen == 1, "a fall is not a theft")

## --- R --------------------------------------------------------------------------
func _setting_it_again() -> void:
	take_hands()
	var p := screen.player
	var crawler := guard("CRAWLER")
	# The rock thrown away, a guard taken, the diamond moved.
	await throw_at(p.global_position + Vector2(0, -60))
	await until(func() -> bool: return rock() != null, 2.0)
	p.possess(crawler, 5.0)
	screen.diamond.place(crawler.global_position)
	await frames(4)
	screen.reset_floor()
	await frames(4)
	var np := screen.player
	check(np != p and np.holds("ROCK") and np.vessel() == np, "R hands back a body with the rock in hand")
	check(rock() == null, "and the rock that was lying out is gone")
	check(guards().size() == screen.total_guards and screen.alerted() == 0,
		"every guard at its post, none of them after anyone")
	check(screen.diamond.carrier == null
			and screen.diamond.global_position.distance_to(screen.room.diamond_point()) < 1.0,
		"and the diamond back on its island")
