extends Node2D
## The SPEED part, and the thing it forced: a bolt fast enough to matter has to
## still notice what it flies into.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SPD] PASS ", what)
	else:
		fails += 1
		push_error("SPD FAIL: " + what)

## A stand-in room that is solid across one band, the thickness of the one-cell
## platforms the generator fills a room with.
class Band extends Node:
	var top: float = 400.0
	var bottom: float = 400.0 + float(Room.CELL)
	func is_solid_at(p: Vector2) -> bool:
		return p.y >= top and p.y <= bottom
	func out_of_bounds(p: Vector2) -> bool:
		return p.y > bottom + 4000.0

## A bolt through `parts` SPEEDs, on a board exactly as long as the chain, so
## its last part is against the way out.
func bolt_board(parts: int) -> SkillBoard:
	var b := SkillBoard.new(parts + 1, 5, "spd")
	b.set_root("PROJECTILE")
	var x := 1
	for i in parts:
		b.place("SPEED", Vector2i(x, 2), 0)
		x += 1
	return b

func shot(weapon: String, parts: int) -> Payload:
	var r := SkillRunner.new(bolt_board(parts))
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload(weapon)
	return Weapons.finalize(weapon, (r.simulate()["outputs"][0] as Payload).clone())

func _ready() -> void:
	Arena.register(self)
	var band := Band.new()
	add_child(band)

	check("SPEED" in Components.loot_pool(),
		"the part is in the loot pool, so it drops, forges and shows in the palette")

	# It accelerates bolts by what its row says, and stacks.
	var mul := 0.0
	for e in Components.effects_of("SPEED"):
		if String(e["op"]) == "multiply" and e["field"] == &"speed":
			mul = float(e["value"])
	check(mul > 1.0, "its row multiplies a bolt's speed (x%.2f)" % mul)
	var v0 := shot("GUN", 0).speed
	var v1 := shot("GUN", 1).speed
	var v2 := shot("GUN", 2).speed
	check(absf(v1 / v0 - mul) < 0.01,
		"one part multiplies bolt speed by %.2f (got %.2f)" % [mul, v1 / v0])
	check(absf(v2 / v0 - mul * mul) < 0.01,
		"and two stack (x%.2f)" % (v2 / v0))

	# It costs cycle time, so it is a trade rather than a free upgrade.
	var slow := SkillRunner.new(bolt_board(0))
	slow.base_payload_provider = func() -> Payload: return Weapons.base_payload("GUN")
	var fast := SkillRunner.new(bolt_board(1))
	fast.base_payload_provider = func() -> Payload: return Weapons.base_payload("GUN")
	check(float(fast.simulate()["cycle_seconds"]) > float(slow.simulate()["cycle_seconds"]),
		"and it lengthens the cycle it rides on")

	# It must not quietly buff something with no bolt in it.
	var mb := SkillBoard.new(2, 5, "melee")
	mb.set_root("SLASH")
	mb.place("SPEED", Vector2i(1, 2), 0)
	var mr := SkillRunner.new(mb)
	mr.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	var mp: Payload = mr.simulate()["outputs"][0]
	check(mp.form == "SLASH" and is_equal_approx(mp.damage, 12.0) and is_equal_approx(mp.size, 1.15),
		"a melee flow is left alone by it")

	# The point of the sub-stepping: even the fastest build has to be stopped by
	# a one-cell platform, and on a frame long enough to hide it.
	for fps: float in [60.0, 30.0, 20.0]:
		for parts in [0, 2, 3]:
			var p := shot("GUN", parts)
			var proj := Projectile.new()
			proj.setup(p, Vector2(300, 300), Vector2.DOWN, 0, null, band)
			add_child(proj)
			proj.set_process(false)   # stepped by hand, at a frame time we choose
			var dt: float = 1.0 / fps
			var through := false
			for i in 60:
				proj._process(dt)
				if proj.is_queued_for_deletion():
					break
				if proj.global_position.y > band.bottom:
					through = true
					break
			check(not through, "%.0f fps, %d SPEED (%.0f px/frame): the platform stops it"
				% [fps, parts, proj.velocity.length() * dt])
			if not proj.is_queued_for_deletion():
				proj.queue_free()
			await get_tree().process_frame

	print("[SPD] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
