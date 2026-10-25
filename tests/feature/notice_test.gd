extends Node
## A monster only notices what is in front of it. Behind its back the player is
## not seen, so it neither hunts nor attacks; in front of it, within its range
## and in its sight, they are. Once it has noticed it turns to keep them in
## front, so walking round it does not shake it off — range or a wall does. A
## blow in the back turns it round, an idle monster looks over its shoulder
## every few seconds, and a boss is never crept up on. Noticing somebody is
## shown (`Enemy.alert`), and waited out for ALERT_TIME before the first blow.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[NOTICE] PASS ", what)
	else:
		fails += 1
		push_error("NOTICE FAIL: " + what)

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Physics frames until `cond` holds, or `limit` of them: whether it did.
func until(cond: Callable, limit: int = 240) -> bool:
	for i in limit:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())

## A dummy that stands still and takes damage, at `at`, for a monster to hunt.
func quarry_at(at: Vector2) -> Actor:
	var a := Actor.new()
	a.team = 0
	a.max_health = 5000.0
	add_child(a)
	a.global_position = at
	a.add_to_group("player")
	return a

## A live monster of `kind`, wired the way the sandbox wires one.
func monster(kind: String, at: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup(kind, 1, "")
	e.collision_layer = 4
	e.collision_mask = 1
	add_child(e)
	e.global_position = at
	e.max_health = 9999.0
	e.health = 9999.0
	return e

## A slab of floor centred on `centre`.
func solid(centre: Vector2, size: Vector2) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = centre
	b.add_child(cs)
	add_child(b)

## Stands `m` still looking `dir` along the floor, and keeps it from glancing
## round by itself.
func look(m: Enemy, dir: int) -> void:
	m.velocity = Vector2.ZERO
	m.face(Vector2(dir, 0))
	m._glance = 999.0

func _ready() -> void:
	seed(20261003)
	await _crawler()
	await _boss()
	print("[NOTICE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _crawler() -> void:
	var q := quarry_at(Vector2(-3000, 0))
	var m := monster("CRAWLER", Vector2.ZERO)
	await phys(2)

	# Behind its back, well inside the range it would see them at.
	look(m, 1)
	q.global_position = m.global_position + Vector2(-200, 0)
	var hp := q.health
	var x0 := m.global_position.x
	await phys(40)
	check(not m.aggro, "a monster facing away does not notice the player behind it")
	check(not m.runner.active and is_equal_approx(q.health, hp), "so it does not attack them")
	check(absf(m.global_position.x - x0) < 1.0 and m.side() == 1, "or come after them")

	# In front of it, the same distance away.
	q.global_position = m.global_position + Vector2(200, 0)
	check(await until(func() -> bool: return m.aggro, 30), "in front of it, they are noticed")
	check(await until(func() -> bool: return m.global_position.x > x0 + 20.0, 120), "and hunted")

	# Noticed is noticed: stepping round behind it does not shake it off.
	q.global_position = m.global_position + Vector2(-200, 0)
	await phys(10)
	check(m.aggro and m.side() == -1, "once noticed, stepping behind it only makes it turn round")

	# Out of its range it loses them, and has to notice them all over again.
	q.global_position = m.global_position + Vector2(-3000, 0)
	check(await until(func() -> bool: return not m.aggro, 30), "out of its range, it loses them")
	# Not at once: it goes on to where it last saw them for a while first
	# (`Enemy.PURSUE_TIME`), and that turns it the way they went.
	check(m.hunting(), "and goes on to where it last saw them")
	check(await until(func() -> bool: return not m.hunting() and m.velocity.length() < 1.0, 900),
		"(and, its pursuit over, comes to a stop)")
	look(m, 1)
	q.global_position = m.global_position + Vector2(-200, 0)
	await phys(40)
	check(not m.aggro, "and coming back behind it is not noticed again")

	# Right up against its back is being stood on, not crept up on.
	q.global_position = m.global_position + Vector2(-Enemy.BLIND_MARGIN + 2.0, 0)
	check(await until(func() -> bool: return m.aggro, 30), "standing right on it is noticed from either side")
	check(m.alert > 0.0 and not m.runner.active,
		"noticing them, it shows it, and does not attack yet (%.2fs to go)" % m.alert)
	var noticed := Time.get_ticks_msec()
	check(await until(func() -> bool: return m.runner.active, 120), "and attacks after")
	var waited := float(Time.get_ticks_msec() - noticed) / 1000.0
	check(waited >= Enemy.ALERT_TIME - 0.05, "no sooner than ALERT_TIME after it noticed (%.2fs)" % waited)

	# A blow in the back.
	q.global_position = m.global_position + Vector2(-3000, 0)
	await until(func() -> bool: return not m.hunting() and m.velocity.length() < 1.0, 900)
	look(m, 1)
	q.global_position = m.global_position + Vector2(-200, 0)
	await phys(10)
	check(not m.aggro, "(unnoticed behind it again)")
	m.apply_damage(1.0, [], q)
	check(await until(func() -> bool: return m.aggro and m.side() == -1, 30), "a blow in the back turns it round, and it sees them")

	# Left alone, it looks over its shoulder by itself.
	q.global_position = m.global_position + Vector2(-3000, 0)
	await until(func() -> bool: return not m.hunting() and m.velocity.length() < 1.0, 900)
	look(m, 1)
	q.global_position = m.global_position + Vector2(-200, 0)
	m._glance = 0.2
	check(await until(func() -> bool: return m.aggro, 120), "an idle monster glances behind it after a while, and notices then")

	m.queue_free()
	q.remove_from_group("player")
	q.queue_free()
	await phys(2)

func _boss() -> void:
	var at := Vector2(0, 6000)
	var q := quarry_at(at + Vector2(-3000, 0))
	var m := monster("ARBITER", at)
	await phys(2)
	look(m, 1)
	q.global_position = m.global_position + Vector2(-300, 0)
	check(await until(func() -> bool: return m.aggro, 30), "a boss is never crept up on")
	m.queue_free()
	q.queue_free()
