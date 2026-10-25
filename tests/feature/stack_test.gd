extends Node
## Stacking: every part a flow passes does its work again, so a board with
## three of one is worth more than a board with one — up to the part's
## `stack_limit`, past which it costs its heat and does nothing.
##
## What each stack is worth is checked where it lands: on the payload the
## runner builds, at the hit (`Attacks.resolve_hit`), and on a bolt in the air —
## SPEED at its limit flying at laser speed, PIERCE passing through one enemy
## each, and HOMING finding its way round a wall, better the more of it there is.
##
## The numbers are read off the parts' own rows and the rules' own constants
## rather than written out here, so what is held is the rule and not today's
## balance.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[STACK] PASS ", what)
	else:
		fails += 1
		push_error("STACK FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Frames until `cond` holds, or `secs` of game time: whether it did. Counted in
## seconds, since a bolt flies by the clock and a headless frame is not a
## sixtieth of one.
func until(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while t < secs:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return bool(cond.call())

## A dummy that stands still and takes damage, at `at`.
func dummy(at: Vector2) -> Actor:
	var a := Actor.new()
	a.team = 1
	a.max_health = 100000.0
	add_child(a)
	a.global_position = at
	return a

## A board with `ids` in a line, the first on the root, run through the runner.
func payload_of(ids: Array, weapon: String = "SWORD") -> Payload:
	var long := 0
	for id in ids:
		long += int(Components.get_def(String(id)).get("cells", 1))
	var b := SkillBoard.new(long, 5, "test")
	b.set_root(String(ids[0]))
	var x := int(Components.get_def(String(ids[0])).get("cells", 1))
	for id in ids.slice(1):
		b.place(String(id), Vector2i(x, 2), 0)
		x += int(Components.get_def(String(id)).get("cells", 1))
	var sim := SkillRunner.new(b)
	sim.base_payload_provider = func() -> Payload: return Weapons.base_payload(weapon)
	var outs: Array = sim.simulate()["outputs"]
	return outs[0] if outs.size() > 0 else null

## `root` followed by `n` of `id`.
func stacked(root: String, id: String, n: int) -> Payload:
	var ids: Array = [root]
	for i in n:
		ids.append(id)
	return payload_of(ids)

## A bolt off `weapon` with `n` of `id` after it.
func stacked_on(weapon: String, id: String, n: int) -> Payload:
	var ids: Array = ["PROJECTILE"]
	for i in n:
		ids.append(id)
	return payload_of(ids, weapon)

func _ready() -> void:
	Arena.register(self)
	await frames(2)
	_limits()
	_payloads()
	await _hits()
	await _bolts()
	_lunges()
	await _homing()
	print("[STACK] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the limit is a column, and the runner keeps to it -------------------------
func _limits() -> void:
	var want := {}
	for r in Db.rows("SELECT id, stack_limit FROM parts"):
		want[String(r["id"])] = int(r["stack_limit"]) if r.get("stack_limit", null) != null else 0
	var off: Array = []
	for id in Components.ids():
		if Components.limit_of(id) != int(want.get(id, 0)):
			off.append(id)
	check(off.is_empty(), "a part's limit is its stack_limit in the table (%s)" % str(off))
	for id in ["SIZE", "SPEED", "RANGE"]:
		check(Components.limit_of(id) > 0, "%s has a limit (%d)" % [id, Components.limit_of(id)])
	check(Components.limit_of("DAMAGE") == 0, "DAMAGE has none")

	var cap := Components.limit_of("SIZE")
	var at_cap := stacked("SLASH", "SIZE", cap)
	var past := stacked("SLASH", "SIZE", cap + 2)
	var under := stacked("SLASH", "SIZE", cap - 1)
	check(at_cap.size > under.size, "SIZE grows the attack up to its limit (%.2f, then %.2f)" % [under.size, at_cap.size])
	check(is_equal_approx(past.size, at_cap.size) and past.stack("SIZE") == cap,
		"and no further: %d of them are worth %d (%.2f)" % [cap + 2, cap, past.size])
	check(past.heat > at_cap.heat, "though the ones past the limit still cost their heat")
	check(at_cap.at_limit("SIZE") and not under.at_limit("SIZE"), "a flow knows when it has reached a part's limit")
	var range_cap := Components.limit_of("RANGE")
	check(is_equal_approx(stacked("PROJECTILE", "RANGE", range_cap + 3).range_px,
			stacked("PROJECTILE", "RANGE", range_cap).range_px),
		"RANGE stops at the most range there is")
	var longest := Weapons.finalize("GUN", stacked_on("GUN", "RANGE", range_cap)).range_px
	check(longest > float(Room.W * Room.CELL),
		"which carries the gun's bolt further than a room is wide (%.0f px)" % longest)
	# An INVERT after a part past its limit has nothing to turn round.
	var ids: Array = ["SLASH"]
	for i in cap + 1:
		ids.append("SIZE")
	ids.append("INVERT")
	check(is_equal_approx(payload_of(ids).size, at_cap.size),
		"an INVERT after a part past its limit turns nothing round")

## --- every one stacked counts ----------------------------------------------------
func _payloads() -> void:
	# DAMAGE: its row's `value` for the first, and `per_stack` more for each
	# one after it.
	var rule: Dictionary = {}
	for e: Dictionary in Components.effects_of("DAMAGE"):
		if e["field"] == &"damage" and String(e["op"]) == "add":
			rule = e
	var add := float(rule.get("value", 0.0))
	var more := float(rule.get("per_stack", 0.0))
	check(add > 0.0 and more > 0.0, "DAMAGE's add grows with the stack (%.0f, and %.0f more for each one before)" % [add, more])
	var none := payload_of(["SLASH"])
	var one := stacked("SLASH", "DAMAGE", 1)
	var two := stacked("SLASH", "DAMAGE", 2)
	var three := stacked("SLASH", "DAMAGE", 3)
	check(is_equal_approx(one.damage, none.damage + add), "one DAMAGE adds what it always did (%.0f)" % (one.damage - none.damage))
	check(is_equal_approx(two.damage - one.damage, add + more) and is_equal_approx(three.damage - two.damage, add + more * 2.0),
		"and each one stacked adds more than the last (%.0f, %.0f, %.0f)" % [one.damage, two.damage, three.damage])
	var healed := payload_of(["SLASH", "DAMAGE", "DAMAGE", "INVERT", "DAMAGE"])
	check(is_equal_approx(healed.damage, two.damage),
		"a DAMAGE turned round by an INVERT does not count towards the next one's (%.0f)" % healed.damage)
	# The row is held to what it can grow: a number, by an add or a multiply.
	var shape := Payload.new()
	var grows = Components._effect({"op": "add", "field": "pierce", "value": 1, "per_stack": 2.0}, shape)
	check(grows is Dictionary and typeof(grows["per_stack"]) == TYPE_INT, "a whole number grows by whole numbers")
	for bad in [
			{"op": "set", "field": "cleanse", "value": 1, "per_stack": 1.0},
			{"op": "set", "field": "stun", "value": 1, "per_stack": 1.0},
			{"op": "add", "field": "pierce", "value": 1, "per_stack": 0.5}]:
		check(Components._effect(bad, shape) is String, "and a row that cannot grow that way is turned away (%s %s)" % [bad["op"], bad["field"]])
	for row in [["PIERCE", "pierce"], ["HOMING", "homing"], ["NEAR", "near"], ["KNOCKBACK", "knockback"], ["PULL", "hook"],
			["MANA_DRAIN", "mana_drain"], ["HEALTH_DRAIN", "health_drain"], ["SHATTER", "shatter"]]:
		var p := stacked("PROJECTILE", row[0], 3)
		check(int(p.get(row[1])) == 3, "three %s are three (%s)" % [row[0], str(p.get(row[1]))])
	var stun1 := stacked("SLASH", "STUN", 1)
	var stun3 := stacked("SLASH", "STUN", 3)
	check(is_equal_approx(stun3.stun, stun1.stun * 3.0), "three STUN hold three times as long (%.1fs)" % stun3.stun)
	var push := payload_of(["SLASH", "KNOCKBACK", "KNOCKBACK", "INVERT"])
	check(push.knockback == 1 and push.hook == 1, "PUSH, PUSH, INVERT: one still throws and one pulls")
	# And the preview says how many, where the stack has no number of its own.
	var says := Attacks.summary(stacked("PROJECTILE", "HOMING", 3))
	check(says.contains(Loc.t("editor.payload.stacked", [Loc.t("editor.payload.homing"), 3])),
		"the preview says how many are stacked (%s)" % says)
	check(not Attacks.summary(stacked("PROJECTILE", "HOMING", 1)).contains(
			Loc.t("editor.payload.stacked", [Loc.t("editor.payload.homing"), 1])),
		"and says nothing of one")

## --- at the hit ----------------------------------------------------------------
func _hits() -> void:
	var plain := payload_of(["SLASH"])

	# SHATTER: harder for every one stacked, and the frost breaks.
	var dealt: Array = []
	for n: int in [1, 3]:
		var cold := dummy(Vector2(400.0 * n, 0))
		cold.chill_time = 2.0
		var p := stacked("SLASH", "SHATTER", n)
		var hp := cold.health
		Attacks.resolve_hit(p, cold, cold.global_position, Vector2.RIGHT, null, null, 0)
		dealt.append(hp - cold.health)
		check(is_equal_approx(hp - cold.health, p.damage * Attacks.shatter_mul(n)) and cold.chill_time <= 0.0,
			"%d SHATTER break the frost for x%.1f, and the enemy thaws" % [n, Attacks.shatter_mul(n)])
	check(dealt[1] > dealt[0] * 2.0, "three are tremendous beside one (%.0f against %.0f)" % [dealt[1], dealt[0]])

	# KNOCKBACK and its opposite.
	var nudged := dummy(Vector2(0, 2000))
	Attacks.resolve_hit(plain, nudged, nudged.global_position, Vector2.RIGHT, null, null, 0)
	for n: int in [1, 3]:
		var thrown := dummy(Vector2(400.0 * n, 2000))
		Attacks.resolve_hit(stacked("SLASH", "KNOCKBACK", n), thrown, thrown.global_position, Vector2.RIGHT, null, null, 0)
		check((thrown.shove - nudged.shove).is_equal_approx(Vector2.RIGHT * Attacks.KNOCKBACK_FORCE * float(n)),
			"%d KNOCKBACK throw %d times as hard" % [n, n])

	# PULL: the drag on an enemy struck far from whoever struck it.
	var drags: Array = []
	for n: int in [1, 3]:
		var by := dummy(Vector2(0, 4000.0 + 2000.0 * n))
		by.team = 0
		var reeled := dummy(by.global_position + Vector2(1400, 0))
		Attacks.resolve_hit(stacked("SLASH", "PULL", n), reeled, reeled.global_position, Vector2.RIGHT, by, null, 0)
		drags.append(-reeled.shove.x)
	check(drags[0] > 0.0 and drags[1] > drags[0] * 1.5,
		"three PULLs drag far harder than one (%.0f against %.0f)" % [drags[1], drags[0]])
	check(Attacks.near_radius(stacked("SLASH", "NEAR", 3)) > Attacks.near_radius(stacked("SLASH", "NEAR", 1)),
		"and three NEARs reach further than one")

	# MANA DRAIN.
	var caster := Player.new()
	add_child(caster)
	await frames(2)
	caster.global_position = Vector2(0, 12000)
	caster.mana = 0.0
	var victim := dummy(Vector2(200, 12000))
	Attacks.resolve_hit(stacked("SLASH", "MANA_DRAIN", 3), victim, victim.global_position, Vector2.RIGHT, caster, null, 0)
	check(is_equal_approx(caster.mana, Attacks.MANA_PER_HIT * 3.0), "three MANA DRAIN drain three times the mana (%.0f)" % caster.mana)

	# HEALTH DRAIN.
	caster.max_health = 1000.0
	caster.health = 1.0
	var before := victim.health
	Attacks.resolve_hit(stacked("SLASH", "HEALTH_DRAIN", 3), victim, victim.global_position, Vector2.RIGHT, caster, null, 0)
	var drained := before - victim.health
	check(drained > 0.0 and is_equal_approx(caster.health - 1.0, drained * Attacks.HEALTH_DRAIN_SHARE * 3.0),
		"three HEALTH DRAIN heal three times as much (%.1f of %.1f dealt)" % [caster.health - 1.0, drained])
	caster.queue_free()

## --- a bolt in the air -----------------------------------------------------------
func bolt(p: Payload, at: Vector2, dir: Vector2, room = null) -> Projectile:
	var n := Projectile.new()
	n.setup(p, at, dir, 0, null, room)
	add_child(n)
	return n

func _bolts() -> void:
	# SPEED: quicker each one, and at the limit, a laser.
	var cap := Components.limit_of("SPEED")
	var under := bolt(stacked("PROJECTILE", "SPEED", cap - 1), Vector2(0, 20000), Vector2.RIGHT)
	var laser := bolt(stacked("PROJECTILE", "SPEED", cap), Vector2(0, 20400), Vector2.RIGHT)
	var one := bolt(stacked("PROJECTILE", "SPEED", 1), Vector2(0, 20800), Vector2.RIGHT)
	check(under.velocity.length() > one.velocity.length(), "SPEED stacked is a quicker bolt")
	check(is_equal_approx(laser.velocity.length(), Projectile.LASER_SPEED) and laser.velocity.length() > under.velocity.length() * 2.0,
		"and at its limit the bolt flies at laser speed (%.0f against %.0f px/s)" % [laser.velocity.length(), under.velocity.length()])
	for b in [under, laser, one]:
		b.queue_free()
	# Laser speed is a step for every weapon: the quickest bolt there is short
	# of the limit is a gun's, and it is nowhere near.
	var quickest := 0.0
	for w in Weapons.ids():
		var p := Weapons.finalize(w, stacked_on(w, "SPEED", cap - 1))
		quickest = maxf(quickest, 420.0 * p.speed)
	check(Projectile.LASER_SPEED > quickest * 2.0,
		"whatever the weapon: the quickest bolt one SPEED short of it does %.0f px/s" % quickest)

	# A laser still lands on what is in its way, rather than stepping over it —
	# out to the end of its range, which at this pace is less than one frame's
	# flight on a slow machine: it flies what range it has and no less.
	var beam := stacked("PROJECTILE", "SPEED", cap)
	var struck := dummy(Vector2(beam.range_px * 0.9, 21200))
	var hp := struck.health
	bolt(beam, Vector2(0, 21200), Vector2.RIGHT)
	check(await until(func() -> bool: return struck.health < hp, 0.5),
		"a bolt at laser speed still hits what it flies into, at the far end of its range (%.0f px)" % (beam.range_px * 0.9))
	# And no more: on a line of its own, something just past the range is safe.
	var beyond := dummy(Vector2(beam.range_px * 1.1, 21600))
	var past := bolt(beam, Vector2(0, 21600), Vector2.RIGHT)
	await until(func() -> bool: return not is_instance_valid(past), 1.0)
	check(is_equal_approx(beyond.health, beyond.max_health), "and fades where its range ends, short of what stands past it")

	# PIERCE: one each.
	for n: int in [0, 1, 2]:
		var y: float = 22000.0 + 400.0 * float(n)
		var row: Array = []
		for i in 4:
			row.append(dummy(Vector2(100.0 + 60.0 * i, y)))
		var p := stacked("PROJECTILE", "PIERCE", n)
		p.range_px = 2000.0
		var shot := bolt(p, Vector2(0, y), Vector2.RIGHT)
		await until(func() -> bool: return not is_instance_valid(shot), 3.0)
		var hit := 0
		for a: Actor in row:
			if a.health < a.max_health:
				hit += 1
		check(hit == n + 1, "%d PIERCE pass through %d: %d enemies in a row are struck" % [n, n, hit])

## --- RANGE carries a lunge -----------------------------------------------------
## SWIFT STRIKE's lunge goes RANGE's own multiple further for each one stacked,
## up to the part's limit, and one an INVERT turns round goes shorter.
func _lunges() -> void:
	var by := 0.0
	for e in Components.effects_of("RANGE"):
		if e["field"] == &"lunge" and e["op"] == "multiply":
			by = float(e["value"])
	check(by > 1.0, "RANGE carries a lunge further (x%s)" % str(by))
	var cap := Components.limit_of("RANGE")
	var caster := Actor.new()
	add_child(caster)
	var far: Array = []
	for n in cap + 2:
		far.append(lunge_of(caster, stacked("DASHSLASH", "RANGE", n)))
	check(float(far[0]) > 0.0 and is_equal_approx(float(far[0]),
			Attacks.DASH_SLASH_REACH * Weapons.base_payload("SWORD").size),
		"a bare SWIFT STRIKE lunges its own reach (%.0f px)" % float(far[0]))
	check(is_equal_approx(float(far[1]), float(far[0]) * by),
		"one RANGE carries it x%s as far (%.0f px)" % [str(by), float(far[1])])
	check(is_equal_approx(float(far[cap]), float(far[0]) * pow(by, cap))
			and is_equal_approx(float(far[cap + 1]), float(far[cap])),
		"each one stacked as far again, up to the limit and no further (%s)" % str(far))
	var turned := lunge_of(caster, payload_of(["DASHSLASH", "RANGE", "INVERT"]))
	check(turned < float(far[0]) and absf(turned * by - float(far[0])) < 0.5,
		"and one an INVERT turns round lunges that much shorter (%.0f px)" % turned)
	caster.queue_free()

## How far `p`, off the sword, carries `caster` down the aim with nothing in the
## way: a lunge lands as it is cast.
func lunge_of(caster: Actor, p: Payload) -> float:
	caster.global_position = Vector2.ZERO
	Attacks.spawn(Weapons.finalize("SWORD", p), {"attacker": caster, "aim": Vector2.RIGHT,
		"origin": caster.global_position, "team": 0})
	var out := -1.0
	for c in get_children():
		if c is DashSlash and not c.is_queued_for_deletion():
			out = (c as DashSlash).from.distance_to((c as DashSlash).to)
			remove_child(c)
			c.queue_free()
	return out

## --- HOMING finds the way round ---------------------------------------------------
## A flat room with a wall standing in the middle of it, open over the top: the
## bolt starts on one side at the foot of the wall and its target stands on the
## other. Whether it got there is whether the target was struck.
func walled_room(at: Vector2) -> Room:
	var r := Room.new()
	add_child(r)
	r.position = at
	r.build(Vector2i.ZERO, {"kind": "entry", "danger": 1, "region": 0, "variant": 3,
		"flat": true, "enemies": [], "loot": []}, {}, 20260920)
	for y in range(8, Room.H - 1):
		r._set_cell(20, y, 1)
	return r

## A bolt with `level` HOMING fired along the foot of the wall at a target on
## the far side: whether it struck, and how much of the pace it left at it
## still had when it did.
func homing_run(level: int, room: Room) -> Dictionary:
	var floor_y := float((Room.H - 3) * Room.CELL)
	var target := dummy(room.global_position + Vector2(24.5 * Room.CELL, floor_y))
	var p := stacked("PROJECTILE", "HOMING", level)
	p.range_px = 4000.0
	var shot := bolt(p, room.global_position + Vector2(14.5 * Room.CELL, floor_y), Vector2.RIGHT, room)
	var left_at := shot.velocity.length()
	var hp := target.health
	var pace := [left_at]
	await until(func() -> bool:
		if is_instance_valid(shot):
			pace[0] = shot.velocity.length()
		return target.health < hp or not is_instance_valid(shot), 12.0)
	var got := target.health < hp
	target.queue_free()
	await frames(2)
	return {"struck": got, "pace": float(pace[0]) / left_at}

## A bolt at a gun's pace with one HOMING, fired to the right in the open, at a
## target `dist` away and `degrees` off its aim: whether it struck before its
## range was spent.
func open_run(dist: float, degrees: float, at: Vector2) -> bool:
	var target := dummy(at + Vector2.RIGHT.rotated(deg_to_rad(degrees)) * dist)
	var p := Weapons.finalize("GUN", stacked_on("GUN", "HOMING", 1))
	var shot := bolt(p, at, Vector2.RIGHT)
	var hp := target.health
	await until(func() -> bool: return target.health < hp or not is_instance_valid(shot), 6.0)
	var got := target.health < hp
	target.queue_free()
	await frames(2)
	return got

func _homing() -> void:
	# In the open first: a turn costs a bolt its pace, which is what lets it
	# tighten onto something beside it rather than circle it, and it gets the
	# pace back once it is flying straight. A quick bolt with one HOMING is the
	# hard case — the one that circles if it keeps its pace, and that stalled
	# with its target behind it when it never got any back.
	check(await open_run(144.0, 90.0, Vector2(0, 30000)), "a quick bolt with one HOMING turns onto a target square to its side")
	check(await open_run(72.0, 150.0, Vector2(0, 32000)), "and comes right round for one behind it")

	# With PIERCE it goes on to the next enemy: the one it has just been
	# through is the nearest thing to it, and not what it is after any more.
	var first := dummy(Vector2(150, 34000))
	var second := dummy(Vector2(330, 34140))
	var chaser := payload_of(["PROJECTILE", "HOMING", "HOMING", "PIERCE"])
	chaser.range_px = 2000.0
	var shot := bolt(chaser, Vector2(0, 34000), Vector2.RIGHT)
	await until(func() -> bool: return not is_instance_valid(shot), 8.0)
	check(first.health < first.max_health and second.health < second.max_health,
		"a homing bolt with PIERCE goes through the first enemy and on after the next")
	first.queue_free()
	second.queue_free()
	await frames(2)

	var room := walled_room(Vector2(0, 40000))
	var floor_y := float((Room.H - 3) * Room.CELL)
	var a := room.global_position + Vector2(14.5 * Room.CELL, floor_y)
	var b := room.global_position + Vector2(24.5 * Room.CELL, floor_y)
	check(not room.has_line_of_sight(a, b) and not room.clear_between(a, b, Projectile.CLEARANCE),
		"(the wall stands between the two)")
	var way := room.path_between(a, b)
	var top := INF
	for pt in way:
		top = minf(top, pt.y - room.global_position.y)
	check(way.size() > 2 and top < 8.0 * Room.CELL and way[way.size() - 1].is_equal_approx(b),
		"the room knows the way round: over the top of the wall, and down to the target (%d points)" % way.size())
	var clear := true
	for pt in way:
		clear = clear and not room.is_solid_at(pt)
	check(clear, "through open cells only")
	check(room.path_between(a, room.global_position + Vector2(20.5 * Room.CELL, floor_y)).is_empty(),
		"and there is no way into the rock")
	# A line that only just misses a corner is not a clear one: the wall's top
	# corner, from a cell below and beside it to the cell over it.
	var corner_from := room.global_position + Vector2(19.4 * Room.CELL, 9.0 * Room.CELL)
	var corner_to := room.global_position + Vector2(20.5 * Room.CELL, 7.5 * Room.CELL)
	check(not room.clear_between(corner_from, corner_to, Projectile.CLEARANCE),
		"a line that clips the wall's corner is not clear for a bolt")
	check(room.clear_between(a, room.global_position + Vector2(19.5 * Room.CELL, floor_y), Projectile.CLEARANCE),
		"and one along open floor is")

	check(not (await homing_run(0, room))["struck"], "a bolt without HOMING flies into the wall")
	var best: Dictionary = await homing_run(4, room)
	check(best["struck"], "a bolt with HOMING stacked goes over the wall and strikes what is behind it")
	check(float(best["pace"]) > 0.8, "and arrives at the pace it left at, not at a crawl (%.0f%%)" % (float(best["pace"]) * 100.0))
	var got: Array = []
	for level: int in [1, 2, 3, 4]:
		got.append(bool((await homing_run(level, room))["struck"]))
	var worse_after_better := false
	for i in range(1, got.size()):
		worse_after_better = worse_after_better or (got[i - 1] and not got[i])
	check(not worse_after_better, "and more HOMING never does worse on the same path (%s)" % str(got))
