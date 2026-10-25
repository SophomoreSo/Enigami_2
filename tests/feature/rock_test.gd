extends Node
## The rock (`Weapons.is_thrown`): one stone, thrown with its graph in it.
##
## It starts in the body's hand. The flow its graph sends throws the rock
## itself — out of the hand, which is empty after it — and until it is picked
## back up the weapon casts nothing, charges nothing, and says so when it is
## reached for. It comes down and lies where it lands (`LooseRock`), and the
## hand that threw it picks it up by walking over it — once it has settled,
## and not from across the room. A volley off it is the rock and copies of it,
## and so is a lap that comes round after it has gone: the copies strike and
## are gone, and only ever one rock lies on the floor. Off the rock, a flow
## that is not a bolt does not throw it.
##
## The player's hands in a monster pick it up as the body does, and throw it
## from there; stepping out, the monster lets go of it where it stands, and so
## it does dying with it. A monster with its own mind never picks it up. Taking
## the weapon out of the body's hands takes the rock with it.
##
## A kit handed out again — the hideout does it whenever a graph changes —
## leaves a rock lying on the floor out of the hand. One without the rock in it
## leaves the one lying there to lie, and a kit that carries the rock again,
## fresh off the rack, takes it away: there is only the one. In a raid a
## rock left in a room is in that room when the player comes back for it,
## landed or still on its way down when they left, and a raid put down with the
## rock on a floor is picked back up without it.
##
## Headless: nothing here is looked at, only where things are.

var fails := 0
var cues: Array = []
var bot: ComputerHands

func check(ok: bool, what: String) -> void:
	if ok:
		print("[ROCK] PASS ", what)
	else:
		fails += 1
		push_error("ROCK FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## By the clock: a headless run goes as fast as it likes.
func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()

## Frames until `cond` holds, or `secs` of game time: whether it did.
func until(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while t < secs:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return bool(cond.call())

func fresh() -> void:
	GameState.reset_profile()
	for n in range(1, GameState.SAVE_SLOTS + 1):
		GameState.delete_slot(n)

func rocks() -> Array:
	return get_tree().get_nodes_in_group("loose_rocks").filter(
		func(r: Node) -> bool: return not r.is_queued_for_deletion())

func bolts(world: Node) -> Array:
	return world.get_children().filter(
		func(c: Node) -> bool: return c is Projectile and not c.is_queued_for_deletion())

func heard(cue: StringName, kind: String = "") -> int:
	var n := 0
	for c in cues:
		if c[0] == cue and (kind == "" or String((c[1] as Dictionary).get("kind", "")) == kind):
			n += 1
	return n

## The player's hands round the weapon: the computer's, so nobody's mouse aims
## it, pointing away across the floor, up and over to the right.
func hands_on(p: Player) -> void:
	bot = ComputerHands.new()
	p.input.add(bot)
	# Along the floor to the right: from where the hall's player stands, up
	# and to the right is the pillar over them, which a throw strikes at once.
	bot.point_at(p.global_position + Vector2(260.0, 0.0))

## Points the hands at `at`, and waits until the body is aiming there: the body
## takes its aim at the end of a frame, after whatever the frame threw, so a
## press in the frame the hands were pointed would go where they pointed before.
func point(a: Actor, at: Vector2) -> void:
	bot.point_at(at)
	var p := a as Player if a is Player else null
	await until(func() -> bool:
		var who: Player = p if p != null else (a as Enemy).pilot
		return who != null and who.aim.dot((at - a.global_position).normalized()) > 0.99, 1.0)

## A press of attack, as a hand does it.
func throw() -> void:
	bot.attack = true
	await frames(3)
	bot.attack = false
	await frames(2)

## Until a rock is lying still somewhere: it, or null.
func landed() -> LooseRock:
	await until(func() -> bool:
		var all := rocks()
		return all.size() == 1 and (all[0] as LooseRock).resting, 6.0)
	var all := rocks()
	return all[0] if all.size() == 1 else null

## Puts `a` down on the floor over the rock, and waits for it to be there.
func stand_on(a: Actor, r: LooseRock) -> void:
	a.global_position = r.global_position
	a.velocity = Vector2.ZERO
	await frames(3)

func _ready() -> void:
	fresh()
	seed(20261004)
	Cues.fired.connect(func(cue: StringName, d: Dictionary) -> void: cues.append([cue, d]))
	await _thrown_and_fetched()
	await _volleys_and_laps()
	await _struck_with()
	await _in_a_monster()
	await _a_new_kit()
	await _left_in_a_room()
	await _put_down_and_picked_up()
	print("[ROCK] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func hideout() -> HideoutWorld:
	var h := HideoutWorld.new()
	add_child(h)
	await frames(4)
	return h

## --- one rock, thrown and fetched -----------------------------------------------
func _thrown_and_fetched() -> void:
	var h := await hideout()
	var p := h.player
	check(Weapons.is_thrown("ROCK") and not Weapons.is_thrown("SWORD") and not Weapons.is_thrown("GUN"),
		"the rock is thrown, and the sword and the gun are not")
	check(p.weapon_id == "ROCK" and p.holds("ROCK") and p.holders["ROCK"] == p and p.can_cast()
			and p.weapon_hands() == p,
		"the rock starts in the body's hand (%s)" % str(p.weapons))
	p.global_position.x = 400.0
	await frames(3)
	hands_on(p)
	await point(p, p.global_position + Vector2(260.0, 0.0))
	cues.clear()
	await throw()
	var flying := bolts(h)
	check(flying.size() == 1 and (flying[0] as Projectile).is_rock() and (flying[0] as Projectile).thrown == "ROCK"
			and (flying[0] as Projectile).thrower == p,
		"a press throws the rock itself (%d bolts)" % flying.size())
	check(not p.holds("ROCK") and not p.can_cast() and p.weapon_hands() == null,
		"and the hand is empty after it")
	check(heard(&"attack") == 1 and String((cues[0][1] as Dictionary).get("thrown", "")) == "ROCK",
		"the throw is a throw, not a shot (%s)" % str(cues.map(func(c: Array) -> StringName: return c[0])))

	# Reached for with the hand empty: nothing goes, nothing charges, and it says so.
	cues.clear()
	bot.attack = true
	await wait(0.6)
	bot.attack = false
	check(heard(&"attack") == 0 and bolts(h).size() <= 1,
		"held down with the rock gone, the button throws nothing more")
	check(heard(&"refused", "thrown") == 1,
		"and says so once for the press, not every frame of it (%d)" % heard(&"refused", "thrown"))
	bot.cast = true
	await wait(0.4)
	check(is_zero_approx(p.charge) and not p.charging, "a hold charges nothing with nothing to throw (%.1f)" % p.charge)
	bot.cast = false
	await frames(2)

	var r := await landed()
	check(r != null, "it comes down and lies still (%d rocks)" % rocks().size())
	if r == null:
		h.queue_free()
		await frames(2)
		return
	check(p.room.is_floor_at(r.global_position) and is_zero_approx(r.height),
		"on the floor: open where it lies, and down on it (%.1f up)" % r.height)
	check(r.global_position.distance_to(p.global_position) > 60.0 and not p.holds("ROCK"),
		"where it landed, away across the room, and not in the hand (%.0f px off)" % r.global_position.distance_to(p.global_position))

	cues.clear()
	await stand_on(p, r)
	check(await until(func() -> bool: return p.holds("ROCK"), 1.0) and p.holders["ROCK"] == p,
		"walked over, it is back in the body's hand")
	await frames(2)
	check(rocks().is_empty() and heard(&"rock_back") == 1, "and off the floor")
	p.global_position.x = 400.0
	await frames(3)
	await point(p, p.global_position + Vector2(260.0, 0.0))
	await throw()
	check(bolts(h).filter(func(b: Projectile) -> bool: return b.is_rock()).size() == 1 and not p.holds("ROCK"),
		"and it can be thrown again")

	# Settling: a rock dropped at the thrower's feet is not back in the hand
	# the instant it touches down.
	var near := await landed()
	if near != null:
		await stand_on(p, near)
		await stand_on(p, near)
	p.global_position.x = 300.0
	await frames(3)
	# Out of the hand, as a throw has it, and coming down at the feet.
	p.let_go("ROCK")
	check(not p.holds("ROCK"), "(out of the hand)")
	var dropped := LooseRock.drop("ROCK", p.global_position, Vector2.ZERO, p.room, p, 40.0)
	await frames(3)
	check(not p.holds("ROCK"), "one coming down on top of the hand that threw it is not caught")
	check(await until(func() -> bool: return p.holds("ROCK"), 2.0) and not is_instance_valid(dropped) or dropped.is_queued_for_deletion(),
		"but once it has settled at their feet, it is picked up")
	h.queue_free()
	await frames(3)

## --- a volley, and a lap after the rock has gone ---------------------------------
func _volleys_and_laps() -> void:
	var h := await hideout()
	var p := h.player
	p.global_position.x = 300.0
	await frames(3)
	hands_on(p)
	var volley := Payload.new()
	volley.form = "PROJECTILE"
	volley.damage = 10.0
	volley.duplicates = 3
	(p.runners[p.hand] as SkillRunner).fired.emit(volley)
	var out := bolts(h)
	var real := out.filter(func(b: Projectile) -> bool: return b.is_rock())
	var copies := out.filter(func(b: Projectile) -> bool: return b.ghost and b.thrown == "ROCK")
	check(out.size() == 3 and real.size() == 1 and copies.size() == 2,
		"a volley off the rock is the rock and two copies of it (%d, %d, %d)" % [out.size(), real.size(), copies.size()])
	check(not p.holds("ROCK"), "and the rock is out of the hand")
	var lap := Payload.new()
	lap.form = "PROJECTILE"
	lap.damage = 10.0
	(p.runners[p.hand] as SkillRunner).fired.emit(lap)
	var later := bolts(h).filter(func(b: Projectile) -> bool: return b.ghost)
	check(later.size() == 3, "a lap coming round once it has gone throws a copy of it (%d copies)" % later.size())
	await until(func() -> bool: return bolts(h).is_empty(), 6.0)
	await wait(1.0)
	check(rocks().size() == 1, "and when they have all come down, one rock lies on the floor (%d)" % rocks().size())
	h.queue_free()
	await frames(3)

## --- off the rock, a flow that is not a bolt -------------------------------------
func _struck_with() -> void:
	var h := await hideout()
	var p := h.player
	await frames(2)
	var slash := Payload.new()
	slash.form = "SLASH"
	slash.damage = 10.0
	(p.runners[p.hand] as SkillRunner).fired.emit(slash)
	await frames(2)
	check(p.holds("ROCK") and bolts(h).is_empty(), "a swing with the rock does not throw it")
	h.queue_free()
	await frames(3)

## --- the player's hands in a monster ---------------------------------------------
func dummy(h: HideoutWorld, x: float) -> Enemy:
	var e := Enemy.new()
	e.setup("DUMMY")
	e.room = h.room
	e.collision_layer = 4
	e.collision_mask = 1
	e.position = Vector2(x, h.player.global_position.y - 20.0)
	h.room.add_child(e)
	return e

func _in_a_monster() -> void:
	var h := await hideout()
	var p := h.player
	p.global_position.x = 200.0
	await frames(3)
	hands_on(p)
	await throw()
	var r := await landed()
	if r == null:
		check(false, "(a rock to work with)")
		h.queue_free()
		await frames(2)
		return
	var e := dummy(h, r.global_position.x + 200.0)
	await wait(0.4)
	check(p.possess(e, 30.0), "(the player is in the monster)")
	check(not p.can_cast(), "in a monster, the rock on the floor is not in its hand either")
	await stand_on(e, r)
	check(await until(func() -> bool: return p.holds("ROCK"), 1.0) and p.holders["ROCK"] == e
			and p.weapon_hands() == e and p.can_cast(),
		"walked over in the monster, it is in the monster's hand")
	cues.clear()
	await point(e, e.global_position + Vector2(-220.0, -120.0))
	await throw()
	var from: Vector2 = Vector2.INF
	for c in cues:
		if c[0] == &"attack":
			from = (c[1] as Dictionary).get("pos", Vector2.INF)
	var thrown := bolts(h).filter(func(b: Projectile) -> bool: return b.is_rock())
	check(thrown.size() == 1 and not p.holds("ROCK") and from.distance_to(e.global_position) < 4.0,
		"and the monster throws it, from where it stands (%s, %s)" % [str(from), str(e.global_position)])
	r = await landed()
	if r != null:
		await stand_on(e, r)
		await until(func() -> bool: return p.holds("ROCK"), 1.0)
	var at := e.global_position
	p.release()
	await frames(3)
	var let_go := rocks()
	check(not p.holds("ROCK") and let_go.size() == 1
			and (let_go[0] as LooseRock).global_position.distance_to(at) < 40.0,
		"stepping out, the monster lets go of it where it stands")
	await wait(1.0)
	check(not e.piloted() and not p.holds("ROCK") and rocks().size() == 1,
		"and a monster with its own mind leaves it lying, standing on it")
	r = rocks()[0] if not rocks().is_empty() else null
	if r != null:
		await stand_on(p, r)
	check(await until(func() -> bool: return p.holds("ROCK"), 1.0) and p.holders["ROCK"] == p,
		"the body picks it up from there")

	# Taken out of the body's hand with the weapon.
	e.release_pilot(0.0)
	e.stun_time = 0.0
	await frames(2)
	e.global_position = p.global_position + Vector2(30.0, 0.0)
	await frames(2)
	check(p.possess(e, 30.0) and p.take_weapon() and p.holders.get("ROCK") == e,
		"taking the weapon out of the body's hands takes the rock with it")
	at = e.global_position
	e.apply_damage(1e9)
	await frames(4)
	var fell := rocks()
	check(p.possessing == null and not p.holds("ROCK") and fell.size() == 1
			and (fell[0] as LooseRock).global_position.distance_to(at) < 60.0,
		"and a monster that dies holding it lets go of it where it fell")
	h.queue_free()
	await frames(3)

## --- a kit handed out again --------------------------------------------------------
func _a_new_kit() -> void:
	var h := await hideout()
	var p := h.player
	p.global_position.x = 300.0
	await frames(3)
	hands_on(p)
	await throw()
	var r := await landed()
	h.refresh_kit()
	await frames(3)
	check(not p.holds("ROCK") and rocks().size() == 1,
		"a kit handed out again with the rock on the floor leaves it on the floor, and out of the hand")
	# The sword in hand as well: the rock is still carried, and still out.
	h.set_weapon("SWORD")
	await frames(3)
	check(p.weapons.has("ROCK") and not p.holds("ROCK") and rocks().size() == 1,
		"another weapon drawn at the rack leaves the rock carried, and where it lies")
	# Left on the rack, it is no weapon of the kit's, and nobody's to pick up.
	check(h.leave_weapon("ROCK"), "(the rock left on the rack)")
	await frames(3)
	check(not p.weapons.has("ROCK") and rocks().size() == 1, "left on the rack, the one on the floor stays where it is")
	if r != null and is_instance_valid(r):
		await stand_on(p, r)
		await wait(0.5)
	check(not p.holds("ROCK") and rocks().size() == 1, "and is not picked up by a hand that does not carry it")
	h.set_weapon("ROCK")
	await frames(3)
	check(p.holds("ROCK") and rocks().is_empty() and (r == null or not is_instance_valid(r) or r.is_queued_for_deletion()),
		"carried again off the rack, it is in the hand, and the one lying there is gone: there is only the one")
	h.queue_free()
	await frames(3)

## --- a room walked out of ----------------------------------------------------------
func start_raid() -> Raid:
	var r := Raid.new()
	r.finished.connect(func(_result: String, _payload: Dictionary) -> void: r.queue_free())
	add_child(r)
	await frames(4)
	return r

## A room of the floor that is not `home` and not beside it through a doorway,
## on any of its four sides: one the player can be cut to and have `home` taken
## down behind them, since a room beside the player's is kept standing
## (`Raid.UNLOAD_FAR`).
func far_from(raid: Raid, home: Vector2i) -> Vector2i:
	for key in raid.map.rooms:
		var c: Vector2i = key
		if c != home and absi(c.x - home.x) + absi(c.y - home.y) > 1:
			return c
	return home

func _left_in_a_room() -> void:
	fresh()
	GameState.deploy(["ROCK"])
	var raid := await start_raid()
	var p := raid.player
	hands_on(p)
	var home := raid.room.coord
	await throw()
	var r := await landed()
	var far := far_from(raid, home)
	if r == null or far == home:
		check(false, "(a rock down in a room, with another room to go to)")
		raid.queue_free()
		await frames(2)
		GameState.die()
		return
	# Where it lies: the room's own spot, which is what the room writes down,
	# and the spot in the world, which is where it is found again.
	var spot := r.position
	var at := r.global_position
	raid.go_to(far)
	await frames(3)
	var kept: Array = raid.map.get_record(home).get("rocks", [])
	check(not raid.rooms.has(home), "(the room is taken down behind the player)")
	check(kept.size() == 1 and Vector2(float(kept[0]["pos"][0]), float(kept[0]["pos"][1])).distance_to(spot) < 1.0
			and rocks().is_empty(),
		"walked out on, the room writes the rock down where it lay")
	raid.go_to(home)
	await frames(4)
	var back := rocks()
	check(back.size() == 1 and (back[0] as LooseRock).global_position.distance_to(at) < 2.0 and not p.holds("ROCK"),
		"and walking back in finds it there")
	await stand_on(p, back[0])
	check(await until(func() -> bool: return p.holds("ROCK"), 1.0), "(picked back up)")
	raid.go_to(far)
	await frames(3)
	check(not raid.map.get_record(home).has("rocks"), "once picked up, the room has nothing to keep")
	raid.go_to(home)
	await frames(4)
	check(rocks().is_empty(), "and nothing is lying there next time")

	# Thrown, and the room left before it is down.
	p.global_position = raid.room.to_global(raid.room.spawn_point())
	await frames(2)
	await point(p, p.global_position + Vector2(200.0, -300.0))
	await throw()
	raid.go_to(far)
	await frames(3)
	var mid: Array = raid.map.get_record(home).get("rocks", [])
	check(mid.size() == 1, "a rock still in the air when the room is left is in the room's record too")
	raid.go_to(home)
	await frames(3)
	var down := await landed()
	check(down != null and not p.holds("ROCK"), "and comes down when the room is walked back into")
	raid.queue_free()
	await frames(3)
	GameState.die()

func _put_down_and_picked_up() -> void:
	fresh()
	GameState.deploy(["ROCK"])
	var raid := await start_raid()
	var p := raid.player
	hands_on(p)
	await throw()
	var r := await landed()
	if r == null:
		check(false, "(a rock down to put the raid down with)")
		raid.queue_free()
		await frames(2)
		GameState.die()
		return
	var at := r.global_position
	GameState.park_raid(raid.park())
	raid.queue_free()
	await frames(3)
	GameState.load_slot(GameState.slot)
	var back := await start_raid()
	var lying := rocks()
	check(not back.player.holds("ROCK") and lying.size() == 1
			and (lying[0] as LooseRock).global_position.distance_to(at) < 2.0,
		"a raid put down with the rock on the floor is picked back up with it there, and not in the hand")
	hands_on(back.player)
	await stand_on(back.player, lying[0])
	check(await until(func() -> bool: return back.player.holds("ROCK"), 1.0), "where it can be picked up")
	back.queue_free()
	await frames(3)
	GameState.die()
