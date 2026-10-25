extends Node
## What STUN, and what INVERT makes of the part before it, do once a hit lands:
## the enemy struck is healed, cleansed of every burn, chill and stun it was
## carrying, stood still where it is; the one struck is hauled back the way the
## attack came.
##
## Driven through `Attacks.resolve_hit`, which is the one door every attack form
## goes through, against dummies and real monsters, the way impact_test is —
## and a real player, for a stun that lands on them. What INVERT puts on the
## payload in the first place is invert_test's; the two are held together by
## boards whose casts are landed on a body.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[INVERT_HIT] PASS ", what)
	else:
		fails += 1
		push_error("INVERT_HIT FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

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

## A dummy that stands still and takes damage, at `at`.
func dummy(at: Vector2, team: int = 1) -> Actor:
	var a := Actor.new()
	a.team = team
	a.max_health = 500.0
	add_child(a)
	a.global_position = at
	return a

## A live monster of `kind`, wired the way the sandbox wires one.
func monster(kind: String, at: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup(kind, 1, "")
	e.collision_layer = 4
	e.collision_mask = 1
	add_child(e)
	e.global_position = at
	e._patrol_dir = 1
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

## A hit of `damage` carrying nothing else, to build the others on.
func hit(damage: float = 1.0) -> Payload:
	var p := Payload.new()
	p.damage = damage
	return p

## What a cast of a board with `ids` in a line fires — the first on the root,
## the way a weapon's own part is — as the sword's owner would land it. The
## board is as long as the line, so its last part stands against the way out.
func cast_of(ids: Array) -> Payload:
	var b := SkillBoard.new(ids.size(), 5, "test")
	b.set_root(String(ids[0]))
	var x := 1
	for id in ids.slice(1):
		b.place(String(id), Vector2i(x, 2), 0)
		x += 1
	var sim := SkillRunner.new(b)
	sim.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	var outs: Array = sim.simulate()["outputs"]
	return Weapons.finalize("SWORD", outs[0]) if outs.size() > 0 else null

## Rooms for the live-monster checks, kept well apart so one test's push
## cannot reach the next test's monster.
var _plot := 0

func _ready() -> void:
	# Arena.register wants a node to hang loose visuals and Deferred nodes off.
	Arena.register(self)
	await frames(2)
	await _heal()
	await _cleanse()
	await _stun_rule()
	await _stunned_monster()
	await _blocked()
	await _from_the_board()
	await _hook()
	await _stunned_player()
	print("[INVERT_HIT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- heal -------------------------------------------------------------------

func _heal() -> void:
	var a := dummy(Vector2(0, -2000))
	await frames(1)
	a.health = 400.0
	var given: Array = []
	a.healed.connect(func(_who: Actor, amount: float) -> void: given.append(amount))
	var p := hit(10.0)
	p.heal = 8.0
	Attacks.resolve_hit(p, a, a.global_position, Vector2.ZERO, null, null, 0)
	check(is_equal_approx(a.health, 398.0),
		"a healing hit lands its damage, then gives back its heal (%.0f of 400)" % a.health)
	check(given == [8.0], "and says how much it gave back (%s)" % str(given))
	a.health = a.max_health
	given.clear()
	p.damage = 2.0
	Attacks.resolve_hit(p, a, a.global_position, Vector2.ZERO, null, null, 0)
	check(is_equal_approx(a.health, a.max_health) and given == [2.0],
		"never past the most it has: back what the hit took, and no more (%.0f, gave %s)" % [a.health, str(given)])
	a.queue_free()

	var b := dummy(Vector2(300, -2000))
	await frames(1)
	b.health = 5.0
	var raised: Array = []
	b.healed.connect(func(_who: Actor, amount: float) -> void: raised.append(amount))
	p.damage = 10.0
	Attacks.resolve_hit(p, b, b.global_position, Vector2.ZERO, null, null, 0)
	check(b.dead and raised.is_empty(), "a blow that kills stays a kill: the dead are not healed")

## --- cleanse ----------------------------------------------------------------

func _cleanse() -> void:
	var a := dummy(Vector2(600, -2000))
	await frames(1)
	a.burn_time = 2.0
	a.burn_dps = 3.0
	a.chill_time = 2.0
	a.stun_time = 0.6
	var p := hit()
	p.cleanse = true
	Attacks.resolve_hit(p, a, a.global_position, Vector2.ZERO, null, null, 0)
	check(a.burn_time <= 0.0 and a.burn_dps == 0.0 and a.chill_time <= 0.0 and not a.stunned(),
		"a cleansing hit ends every burn, chill and stun on the enemy struck")
	check(is_equal_approx(a.stun_guard, Actor.STUN_GUARD),
		"and a stun it ends is over like any other, so the guard after one starts (%.1f)" % a.stun_guard)
	a.queue_free()

	# What the hit itself brings is not the cleanse's to end. It goes on once
	# the cleanse has been through: the old burn is over and this one is the
	# hit's own, as hard as the hit and no harder.
	var b := dummy(Vector2(700, -2000))
	await frames(1)
	b.burn_time = 1.0
	b.burn_dps = 50.0
	b.chill_time = 2.0
	var lit := hit(10.0)
	lit.cleanse = true
	lit.elements.append("FIRE")
	var washed: Array = []
	var seen := func(name: StringName, _d: Dictionary) -> void:
		if name == &"cleanse":
			washed.append(name)
	Cues.fired.connect(seen)
	Attacks.resolve_hit(lit, b, b.global_position, Vector2.ZERO, null, null, 0)
	check(b.chill_time <= 0.0, "a cleansing hit that burns still ends the chill the enemy was carrying")
	check(is_equal_approx(b.burn_time, 2.5) and is_equal_approx(b.burn_dps, 10.0 * 0.22),
		"and the burn it brings itself stays on, the hit's own (%.1fs at %.1f)" % [b.burn_time, b.burn_dps])
	check(washed.size() == 1, "saying so once, for what it ended (%d)" % washed.size())
	b.queue_free()

	# With nothing on the enemy to end, a cleanse says nothing — and what the
	# hit brings stays all the same.
	var c := dummy(Vector2(800, -2000))
	await frames(1)
	washed.clear()
	lit.elements.append("ICE")
	lit.stun = 0.5
	Attacks.resolve_hit(lit, c, c.global_position, Vector2.ZERO, null, null, 0)
	check(c.burn_time > 0.0 and c.chill_time > 0.0 and c.stunned(),
		"on an enemy carrying nothing, the burn, chill and stun the hit brings all stay")
	check(washed.is_empty(), "and nothing is said of a cleanse that ended nothing (%d)" % washed.size())
	# Struck again while it stands stunned: that stun is one it was carrying,
	# so it ends, and the guard after it keeps this hit's own from taking.
	Attacks.resolve_hit(lit, c, c.global_position, Vector2.ZERO, null, null, 0)
	check(not c.stunned() and is_equal_approx(c.stun_guard, Actor.STUN_GUARD),
		"struck again, the stun it was carrying ends, and the guard keeps the next from taking")
	check(c.burn_time > 0.0 and c.chill_time > 0.0, "while the burn and the chill are this hit's again")
	Cues.fired.disconnect(seen)
	c.queue_free()

## --- stun -------------------------------------------------------------------

func _stun_rule() -> void:
	var a := dummy(Vector2(900, -2000))
	await frames(1)
	var p := hit()
	p.stun = 0.5
	Attacks.resolve_hit(p, a, a.global_position, Vector2.ZERO, null, null, 0)
	check(a.stunned() and is_equal_approx(a.stun_time, 0.5), "a STUN hit stuns for its seconds (%.2f)" % a.stun_time)
	check(not a.stun(5.0) and a.stun_time <= 0.5, "another landing on it does not stretch it (%.2f)" % a.stun_time)
	a._process_status(0.6)
	check(not a.stunned() and is_equal_approx(a.stun_guard, Actor.STUN_GUARD), "it wears off, and the guard starts")
	check(not a.stun(0.5), "while the guard is up a fresh stun does not take, so stuns cannot hold one for good")
	a._process_status(Actor.STUN_GUARD + 0.01)
	check(a.stun(0.5), "and once it is down, one does again")
	a.queue_free()

## A CRAWLER on a floor beside something to hunt: stunned, it neither moves,
## casts nor touches; come round, it does all three again. It is stunned
## before its quarry is within reach, so nothing it did before can land in the
## window.
func _stunned_monster() -> void:
	_plot += 1
	var at := Vector2(0, float(_plot) * 4000.0)
	var quarry := dummy(at + Vector2(400, 0), 0)
	quarry.add_to_group("player")
	var m := monster("CRAWLER", at)
	await frames(1)
	m.global_position = at
	m.max_health = 9999.0
	m.health = 9999.0
	await phys(2)
	check(m.stun(1.0), "a monster can be stunned")
	quarry.global_position = m.global_position + Vector2(10, 0)
	var hp0 := quarry.health
	var clock0: float = m.runner._elapsed
	await phys(6)
	check(m.target == quarry and m.aggro, "(the crawler has its quarry in sight, and within reach)")
	var x0 := m.global_position.x
	await phys(18)
	check(absf(m.global_position.x - x0) < 1.0,
		"stunned, it stands where it is (%.1fpx)" % absf(m.global_position.x - x0))
	check(is_equal_approx(quarry.health, hp0), "and neither touches nor strikes what it was hunting (%.1f lost)" % (hp0 - quarry.health))
	check(not m.runner.active and is_equal_approx(m.runner._elapsed, clock0),
		"and its board waits with it: nothing on its way lands while it stands there")
	check(await until(func() -> bool: return not m.stunned(), 240), "it comes round")
	check(await until(func() -> bool: return quarry.health < hp0, 240),
		"and goes back to hurting what it hunts (%.1f lost)" % (hp0 - quarry.health))
	quarry.remove_from_group("player")
	quarry.queue_free()
	m.queue_free()
	await frames(2)

## --- what does not land brings nothing --------------------------------------

func _blocked() -> void:
	var a := dummy(Vector2(1200, -2000))
	await frames(1)
	a.health = 400.0
	a.chill_time = 2.0
	a.invuln = 1.0
	var p := hit(10.0)
	p.heal = 8.0
	p.cleanse = true
	p.stun = 0.5
	Attacks.resolve_hit(p, a, a.global_position, Vector2.ZERO, null, null, 0)
	check(is_equal_approx(a.health, 400.0) and a.chill_time > 0.0 and not a.stunned(),
		"a hit that does not land brings nothing with it: no heal, no cleanse, no stun")
	a.queue_free()

## --- from the board to the body --------------------------------------------------

## What invert_test finds on a cast and what the checks above do with a payload,
## held together: real boards, cast and landed on an enemy already burning,
## chilled or stunned. Only the part straight before INVERT is turned round, so
## whatever else the board carries still lands and stays.
func _from_the_board() -> void:
	var twice := cast_of(["SLASH", "FIRE", "FIRE", "INVERT"])
	var a := dummy(Vector2(1500, -2000))
	await frames(1)
	a.chill_time = 2.0
	Attacks.resolve_hit(twice, a, a.global_position, Vector2.ZERO, null, null, 0)
	check(a.chill_time <= 0.0 and a.burn_time > 0.0,
		"FIRE, FIRE, INVERT landed: the chill it was carrying ends, and it burns from the first FIRE (%.1fs)" % a.burn_time)
	a.queue_free()

	var mixed := cast_of(["SLASH", "STUN", "ICE", "INVERT"])
	var b := dummy(Vector2(1600, -2000))
	await frames(1)
	b.burn_time = 2.0
	b.burn_dps = 3.0
	Attacks.resolve_hit(mixed, b, b.global_position, Vector2.ZERO, null, null, 0)
	check(b.burn_time <= 0.0 and b.chill_time <= 0.0 and b.stunned(),
		"STUN, ICE, INVERT landed: its burn ends, no chill comes, and it stands stunned by the STUN")
	b.queue_free()

	var calm := cast_of(["SLASH", "STUN", "INVERT"])
	var c := dummy(Vector2(1700, -2000))
	await frames(1)
	c.stun_time = 0.6
	c.burn_time = 2.0
	c.burn_dps = 3.0
	Attacks.resolve_hit(calm, c, c.global_position, Vector2.ZERO, null, null, 0)
	check(not c.stunned() and c.burn_time <= 0.0,
		"STUN, INVERT landed: a stunned, burning enemy comes round and is put out")
	c.queue_free()

	var mend := cast_of(["SLASH", "DAMAGE", "INVERT"])
	var bare := cast_of(["SLASH"])
	var d := dummy(Vector2(1800, -2000))
	await frames(1)
	d.health = 400.0
	Attacks.resolve_hit(mend, d, d.global_position, Vector2.ZERO, null, null, 0)
	check(is_equal_approx(mend.damage, bare.damage) and is_equal_approx(d.health, 400.0 - bare.damage + mend.heal),
		"DAMAGE, INVERT landed: the blow a bare board lands, and DAMAGE's share given back (%.1f of 400)" % d.health)
	d.queue_free()

## --- hook --------------------------------------------------------------------

## How far a `kind` travels in x over half a second after `p` strikes it, the
## attack going right — resolved `short` of the middle of it, the way a bolt's
## hit is: where the bolt is, not where the body is.
func knock_travel(kind: String, p: Payload, short: float = 0.0) -> float:
	_plot += 1
	var at := Vector2(0, float(_plot) * 4000.0)
	var m := monster(kind, at)
	await frames(2)
	m.global_position = at
	m.max_health = 9999.0
	m.health = 9999.0
	var x0: float = m.global_position.x
	Attacks.resolve_hit(p, m, m.global_position - Vector2(short, 0.0), Vector2.RIGHT, null, null, 0)
	await phys(30)
	var moved: float = m.global_position.x - x0
	m.queue_free()
	return moved

func _hook() -> void:
	var plain := hit()
	var reel := hit()
	reel.hook = 1
	var hauled: float = await knock_travel("DUMMY", reel)
	check(hauled < -20.0, "a dummy struck by a hit going right that hooks is hauled %.0fpx left, back the way it came" % -hauled)
	for kind in ["DUMMY", "CRAWLER", "LOBBER"]:
		var back: float = await knock_travel(kind, reel) - await knock_travel(kind, plain)
		check(back < -40.0, "a %s hooked travels %.0fpx back from where a plain hit sends it" % [kind, -back])

## --- a stunned player ----------------------------------------------------------

func _stunned_player() -> void:
	var pl := Player.new()
	pl.collision_layer = 2
	pl.collision_mask = 1
	add_child(pl)
	await frames(2)
	check(not pl.controls_locked(), "(a player nothing holds)")
	var p := hit()
	p.stun = 0.4
	Attacks.resolve_hit(p, pl, pl.global_position, Vector2.ZERO, null, null, 1)
	await frames(2)
	check(pl.stunned() and pl.controls_locked() and pl.input.held(),
		"a stunned player's hands come off their line, as they do in a conversation")
	check(await until(func() -> bool: return not pl.stunned(), 240), "they come round")
	await frames(2)
	check(not pl.controls_locked(), "and the hands go back on the moment they do")
	pl.queue_free()
