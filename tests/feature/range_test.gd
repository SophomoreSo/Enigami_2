extends Node2D
## A bolt carries a certain distance and then fades. What that distance is comes
## off the payload, so the weapon that threw it decides, SPEED extends it, and a
## monster is given whatever its own attack range needs.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[RNG] PASS ", what)
	else:
		fails += 1
		push_error("RNG FAIL: " + what)

## Fires one bolt into empty space and reports how far it got before it went.
## Stepped by hand at a fixed frame time, so the answer is the rule and not the
## machine's frame rate.
func flight(p: Payload) -> float:
	var proj := Projectile.new()
	proj.setup(p, Vector2(0, 0), Vector2.RIGHT, 0, null, null)
	add_child(proj)
	proj.set_process(false)
	var dt := 1.0 / 60.0
	var flew := 0.0
	for i in 1200:
		proj._process(dt)
		if proj.is_queued_for_deletion():
			break
		flew = proj.global_position.x
	if not proj.is_queued_for_deletion():
		proj.queue_free()
	return flew

## A bolt off `weapon` through `n` of `part`, on a board exactly as long as the
## chain, so its last part is against the way out.
func bolt(weapon: String, part: String = "", n: int = 0) -> Payload:
	var b := SkillBoard.new(n + 1, 5, "rng")
	b.set_root("PROJECTILE")
	var x := 1
	for i in n:
		b.place(part, Vector2i(x, 2), 0)
		x += 1
	var r := SkillRunner.new(b)
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload(weapon)
	return Weapons.finalize(weapon, (r.simulate()["outputs"][0] as Payload).clone())

func _ready() -> void:
	Arena.register(self)

	# The rule itself: it goes its range and stops, whatever it is flying over.
	for want: float in [200.0, 640.0, 1100.0]:
		var p := Payload.new()
		p.form = "PROJECTILE"
		p.range_px = want
		var flew := flight(p)
		check(flew >= want - 40.0 and flew <= want + 40.0,
			"a bolt given %.0f px of range fades at %.0f" % [want, flew])

	# Speed is not range: the same reach, arrived at sooner.
	var slow := Payload.new()
	slow.form = "PROJECTILE"
	slow.range_px = 500.0
	slow.speed = 0.5
	var fast := Payload.new()
	fast.form = "PROJECTILE"
	fast.range_px = 500.0
	fast.speed = 3.0
	check(absf(flight(slow) - flight(fast)) < 60.0,
		"two bolts of the same range end in the same place however fast they fly (%.0f, %.0f)"
			% [flight(slow), flight(fast)])

	# What each weapon reaches. The gun is the long one and the sword the short
	# one, and even the gun cannot cover a whole room.
	var gun := bolt("GUN").range_px
	var rock := bolt("ROCK").range_px
	var sword := bolt("SWORD").range_px
	check(gun > rock and rock > sword,
		"gun %.0f > rock %.0f > sword %.0f" % [gun, rock, sword])
	check(gun < float(Room.W * Room.CELL),
		"and the longest of them stops short of a room's width (%.0f of %d)"
			% [gun, Room.W * Room.CELL])
	# A swing reaches 54px before SIZE touches it, so the shortest bolt in the
	# game still has to be worth firing from further off than a blade.
	check(sword > 54.0 * 2.0,
		"while the shortest is still a ranged attack — %.0f px, against a swing's 54"
			% sword)

	# SPEED says it carries a bolt further, so it has to.
	var one := bolt("GUN", "SPEED", 1).range_px
	var two := bolt("GUN", "SPEED", 2).range_px
	check(one > gun and two > one,
		"SPEED extends the reach and stacks (%.0f, %.0f, %.0f)" % [gun, one, two])

	# RANGE is the part for it, so it has to be the better answer — and it has
	# to be the only thing it changes.
	check("RANGE" in Components.loot_pool(),
		"the part is in the loot pool, so it drops, forges and shows in the palette")
	var r1 := bolt("GUN", "RANGE", 1)
	var r2 := bolt("GUN", "RANGE", 2)
	check(r1.range_px > gun and r2.range_px > r1.range_px,
		"RANGE extends the reach and stacks (%.0f, %.0f, %.0f)"
			% [gun, r1.range_px, r2.range_px])
	check(r1.range_px > one,
		"one RANGE beats one SPEED at the thing it is for (%.0f against %.0f)"
			% [r1.range_px, one])
	var plain := bolt("GUN")
	check(is_equal_approx(r1.speed, plain.speed) and is_equal_approx(r1.damage, plain.damage)
			and is_equal_approx(r1.size, plain.size),
		"and buys reach with nothing else: same speed, damage and size")

	# A bolt that was given the reach actually flies it.
	var flown := flight(r1)
	check(absf(flown - r1.range_px) < 40.0,
		"a RANGE bolt flies the %.0f px it was given (%.0f)" % [r1.range_px, flown])

	# It is a stat part like the others: one cell, and it costs cycle time.
	check(int(Components.get_def("RANGE")["cells"]) == 1,
		"it takes one cell, like the stats it sits with")
	check(float(Components.get_def("RANGE")["heat"]) > 0.0,
		"and carries heat, so the reach is paid for on the cooldown")

	# It does nothing to a flow with no bolt in it, which is what it says.
	var mb := SkillBoard.new(2, 5, "melee")
	mb.set_root("SLASH")
	mb.place("RANGE", Vector2i(1, 2), 0)
	var mr := SkillRunner.new(mb)
	mr.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	var mp: Payload = mr.simulate()["outputs"][0]
	check(mp.form == "SLASH" and is_equal_approx(mp.damage, 12.0),
		"a melee flow is left alone by it")

	# A monster's shot must outreach the monster: one that fires from further
	# away than its bolt carries could never hit anything at all.
	for id in Monsters.DEFS:
		var e := Enemy.new()
		e.setup(String(id), 1, "")
		add_child(e)
		var reach: float = (e.runner.base_payload_provider.call() as Payload).range_px
		var shoots: float = float((Monsters.DEFS[id] as Dictionary)["attack_range"])
		check(reach >= shoots,
			"%s shoots from %.0f and its bolt carries %.0f" % [id, shoots, reach])
		e.queue_free()
	await get_tree().process_frame

	print("[RNG] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
