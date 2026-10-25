extends Node2D
## A thrown stone's throw goes off where the stone stops (`Attacks.land`): a
## rock with a NEAR on it thrown at a wall touches whoever stands by the wall,
## one that runs out of speed in the air and falls touches whoever stands where
## it comes down, an ON HIT on it goes off from the point, and one spent on an
## enemy it struck lands harmless — a throw goes off once.
##
## In a made room with walls, with dummies for the throw to find. Headless:
## nothing here is looked at.

var fails := 0
var cues: Array = []

func check(ok: bool, what: String) -> void:
	if ok:
		print("[STONE] PASS ", what)
	else:
		fails += 1
		push_error("STONE FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func seconds(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()

func heard(cue: StringName) -> int:
	var n := 0
	for c in cues:
		if c == cue:
			n += 1
	return n

## `ids` in a line, the first on the root, on a board exactly as long; the
## flow it fires, as the rock's.
func flow(ids: Array) -> Payload:
	var b := SkillBoard.new(ids.size(), 5, "test")
	b.set_root(String(ids[0]))
	for i in range(1, ids.size()):
		b.place(String(ids[i]), Vector2i(i, 2), 0)
	var r := SkillRunner.new(b)
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload("ROCK")
	var outs: Array = r.simulate()["outputs"]
	return Weapons.finalize("ROCK", outs[0] as Payload) if not outs.is_empty() else null

func dummy(at: Vector2, team: int = 1) -> Actor:
	var a := Actor.new()
	a.team = team
	a.max_health = 500.0
	add_child(a)
	a.global_position = at
	return a

## The rock thrown from `from` along `aim` by `by`, in `room`.
func throw(p: Payload, from: Vector2, aim: Vector2, by: Actor, room: Room) -> void:
	# As the player throws it (`Player._on_fired`): lobbed, as the rock is.
	Attacks.spawn(p, {"attacker": by, "room": room, "team": by.team, "aim": aim, "origin": from,
		"lobbed": Weapons.uses_lobbed_shots("ROCK"), "thrown": "ROCK", "thrower": null})

func rocks() -> Array:
	return get_tree().get_nodes_in_group("loose_rocks").filter(func(r: Node) -> bool: return not r.is_queued_for_deletion())

func _ready() -> void:
	Arena.register(self)
	Cues.fired.connect(func(cue: StringName, _d: Dictionary) -> void: cues.append(cue))
	# A room fourteen cells across and six down, walled all round: the throw
	# goes from its left end to its right wall.
	var room := MadeRoom.new()
	room.plan = PackedStringArray([
		"##############",
		"#............#",
		"#............#",
		"#............#",
		"#............#",
		"##############",
	])
	add_child(room)
	room.stand()
	await frames(2)
	await _at_the_wall(room)
	await _on_the_ground(room)
	await _a_trigger(room)
	await _spent_first(room)
	print("[STONE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Thrown at the wall with a NEAR and a DAMAGE on it: whoever stands by the
## wall is touched where it stops, and the stone drops there, a plain rock.
func _at_the_wall(room: Room) -> void:
	var me := dummy(Vector2(80, 112), 0)
	var by_wall := dummy(Vector2(390, 112))
	var far := dummy(Vector2(200, 112))
	var p := flow(["PROJECTILE", "NEAR", "DAMAGE"])
	check(p != null and p.near > 0 and p.spread != null and p.spread.damage > 0.0,
		"a rock with NEAR, DAMAGE carries a touch of %.0f" % (p.spread.damage if p != null and p.spread != null else -1.0))
	p.range_px = 2000.0
	# Weightless, so it flies level and only the wall stops it — thrown over
	# the one in the way.
	p.anti_gravity = 1
	me.global_position.y = 50.0
	var hp_wall := by_wall.health
	var hp_far := far.health
	cues.clear()
	throw(p, me.global_position, Vector2.RIGHT, me, room)
	await seconds(1.0)
	check(heard(&"stone_cast") == 1, "the throw goes off where it meets the wall (%d)" % heard(&"stone_cast"))
	check(hp_wall - by_wall.health > 0.0, "and whoever stands by the wall is touched (%.0f)" % (hp_wall - by_wall.health))
	check(is_equal_approx(far.health, hp_far), "while one far from it is not")
	check(rocks().size() == 1 and (rocks()[0] as LooseRock).strikes == null, "and the stone lies there, a plain rock")
	for r in rocks():
		r.queue_free()
	me.queue_free()
	by_wall.queue_free()
	far.queue_free()
	await frames(2)

## Lobbed, it flies its arc out to where it was aimed — as far as its range,
## aimed nowhere nearer — and comes down on the floor there, where the throw
## goes off.
func _on_the_ground(room: Room) -> void:
	var me := dummy(Vector2(80, 50), 0)
	var p := flow(["PROJECTILE", "NEAR", "DAMAGE"])
	# A range it would run out of in a few cells, were it a flat shot's to run out of.
	p.range_px = 60.0
	cues.clear()
	throw(p, me.global_position, Vector2.RIGHT, me, room)
	# Where its arc comes down: as far as its range, with nowhere nearer
	# aimed at (`Attacks._projectile`).
	var bolt: Projectile = null
	for c in get_children():
		if c is Projectile and not c.is_queued_for_deletion():
			bolt = c
	check(bolt != null and bolt.lobbed() and bolt.gravity >= Projectile.THROW_GRAVITY - 0.01,
		"it leaves lobbed, under the world's pull (%.0f)" % (bolt.gravity if bolt != null else 0.0))
	var lands_x := me.global_position.x + p.range_px
	var below := dummy(Vector2(lands_x, 118))
	var hp := below.health
	await seconds(1.5)
	check(heard(&"stone_cast") == 1, "lobbed, the throw goes off where it comes down (%d)" % heard(&"stone_cast"))
	check(hp - below.health > 0.0, "touching whoever stands there (%.0f)" % (hp - below.health))
	for r in rocks():
		r.queue_free()
	me.queue_free()
	below.queue_free()
	await frames(2)

## An ON HIT on the throw goes off from where the stone stops: a swing there.
func _a_trigger(room: Room) -> void:
	var me := dummy(Vector2(80, 50), 0)
	var p := flow(["PROJECTILE"])
	p.range_px = 2000.0
	# Lobbed, it comes down on the floor short of the wall: that is where it stops.
	p.on_hit = Payload.new()
	p.on_hit.form = "SLASH"
	p.on_hit.damage = 3.0
	# Counted in a box: a lambda takes a copy of a plain number.
	var swings := [0]
	var count := func(cue: StringName, _d: Dictionary) -> void:
		if cue == &"melee_arc":
			swings[0] += 1
	Cues.fired.connect(count)
	throw(p, me.global_position, Vector2.RIGHT, me, room)
	await seconds(1.5)
	Cues.fired.disconnect(count)
	check(swings[0] == 1, "an ON HIT on the throw goes off where the stone stops (%d swings)" % swings[0])
	for r in rocks():
		r.queue_free()
	me.queue_free()
	await frames(2)

## One that struck an enemy on the way is spent: it lands harmless.
func _spent_first(room: Room) -> void:
	var me := dummy(Vector2(80, 112), 0)
	var struck := dummy(Vector2(200, 112))
	var by_wall := dummy(Vector2(390, 112))
	var p := flow(["PROJECTILE", "NEAR", "DAMAGE"])
	p.range_px = 2000.0
	# Weightless, so it flies level into the enemy in its way.
	p.anti_gravity = 1
	var hp := by_wall.health
	cues.clear()
	throw(p, me.global_position, Vector2.RIGHT, me, room)
	await seconds(1.5)
	check(struck.health < struck.max_health, "it strikes the enemy in its way")
	check(heard(&"stone_cast") == 0, "and, spent on it, goes off nowhere else (%d)" % heard(&"stone_cast"))
	check(by_wall.health >= hp - 0.01 or by_wall.global_position.distance_to(struck.global_position) <= Attacks.near_radius(p),
		"so the one by the wall is left alone")
	me.queue_free()
	struck.queue_free()
	by_wall.queue_free()
	await frames(2)
