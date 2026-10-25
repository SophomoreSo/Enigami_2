extends Node
## Magic off (`Magic`): a switch the world has, never saved. Off, every graph
## is cast as its forms alone — the weapon's own attack with nothing the other
## parts do to it, no follow-ups, the board's clock at its base — the player's
## and the monsters' alike; a hold charges nothing; and the map creator's magic
## stone is neither ground nor solid, and is again the moment magic is back.
##
## Headless: nothing here is looked at. The grey is the picture's, and is not
## here.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[MAGIC] PASS ", what)
	else:
		fails += 1
		push_error("MAGIC FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## `ids` in a line, the first on the root the way a weapon's own part is, on a
## board exactly as long: the last of them against the way out.
func board_of(ids: Array) -> SkillBoard:
	var b := SkillBoard.new(ids.size(), 5, "test")
	b.set_root(String(ids[0]))
	for i in range(1, ids.size()):
		b.place(String(ids[i]), Vector2i(i, 2), 0)
	return b

func runner_on(b: SkillBoard, forms_only: bool = false) -> SkillRunner:
	var r := SkillRunner.new(b)
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	r.forms_only = forms_only
	return r

func first_out(r: SkillRunner) -> Payload:
	var outs: Array = r.simulate()["outputs"]
	return outs[0] as Payload if not outs.is_empty() else null

func _ready() -> void:
	await frames(2)
	_the_switch()
	_forms_alone()
	await _the_player()
	await _the_monster()
	await _the_stone()
	Magic.set_on(true)
	print("[MAGIC] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## On to begin with; a toggle turns it off and says so once, in a signal and a
## cue; setting what it already is says nothing.
func _the_switch() -> void:
	check(Magic.on, "the game starts in magic")
	var heard: Array = []
	var cued: Array = []
	var on_changed := func(on: bool) -> void: heard.append(on)
	var on_cue := func(cue: StringName, d: Dictionary) -> void:
		if cue == &"magic":
			cued.append(bool(d.get("on", true)))
	Magic.changed.connect(on_changed)
	Cues.fired.connect(on_cue)
	Magic.toggle()
	check(not Magic.on and heard == [false] and cued == [false],
		"a toggle turns it off, and says so once: a signal and a cue")
	Magic.set_on(false)
	check(heard.size() == 1 and cued.size() == 1, "set to what it already is, it says nothing")
	Magic.toggle()
	check(Magic.on and heard == [false, true] and cued == [false, true], "and a toggle turns it back on")
	Magic.changed.disconnect(on_changed)
	Cues.fired.disconnect(on_cue)

## With forms alone, a graph fires its form with the weapon's own numbers and
## nothing else's: no DAMAGE, no FIRE, no follow-up off a trigger, no OVERCLOCK
## on the clock. A form after the root still makes the flow that form.
func _forms_alone() -> void:
	var base := Weapons.base_payload("SWORD")
	var full := first_out(runner_on(board_of(["DASHSLASH", "DAMAGE", "FIRE"])))
	var bare := first_out(runner_on(board_of(["DASHSLASH", "DAMAGE", "FIRE"]), true))
	check(full != null and full.damage > base.damage and full.elements.has("FIRE"),
		"in magic the graph's parts work on the flow (%.1f, %s)" % [full.damage if full != null else -1.0, str(full.elements if full != null else [])])
	check(bare != null and bare.form == "DASHSLASH" and is_equal_approx(bare.damage, base.damage)
			and bare.elements.is_empty(),
		"with forms alone the same graph fires the weapon's own attack, untouched (%.1f, %s)"
			% [bare.damage if bare != null else -1.0, str(bare.elements if bare != null else [])])
	var punch := first_out(runner_on(board_of(["DASHSLASH", "BRIDGE", "HEADBUTT"]), true))
	check(punch != null and punch.form == "HEADBUTT", "a form after the root still makes the flow that form")

	# A ring off an ON HIT: a follow-up a lap in magic, and none with forms alone.
	var lp := SkillBoard.new(7, 5, "loop")
	lp.set_root("BRIDGE", Vector2i(3, 2))
	lp.place("BRIDGE", Vector2i(4, 2), 0)
	lp.place("ON_HIT", Vector2i(5, 2), 0)
	lp.place("SLASH", Vector2i(6, 2), 0)
	lp.place("BRIDGE", Vector2i(5, 3), 2)
	lp.place("BRIDGE", Vector2i(4, 3), 3)
	var ring := runner_on(lp)
	ring.ttl_bonus = 32
	var with := (ring.simulate()["triggers"] as Dictionary).has("ON_HIT")
	ring.forms_only = true
	var without := (ring.simulate()["triggers"] as Dictionary).has("ON_HIT")
	check(with and not without, "a trigger's branch is not walked: no follow-ups with forms alone")

	# OVERCLOCK runs the clock up in magic, and not with forms alone.
	var oc := runner_on(board_of(["DASHSLASH", "OVERCLOCK", "OVERCLOCK", "BRIDGE"]))
	var quick := float(oc.simulate()["cycle_seconds"])
	oc.forms_only = true
	var plain := float(oc.simulate()["cycle_seconds"])
	check(plain > quick, "OVERCLOCK does nothing to the clock with forms alone (%.4f, %.4f in magic)" % [plain, quick])
	oc.forms_only = false
	check(is_equal_approx(float(oc.simulate()["cycle_seconds"]), quick),
		"and the walk is worked out again when magic is back")

## The player's graphs follow the switch, and a hold charges nothing while it
## is off.
func _the_player() -> void:
	var p := Player.new()
	add_child(p)
	await frames(2)
	p.setup_kit(["SWORD"], [board_of(["DASHSLASH", "DAMAGE"])])
	check(not p.runner.forms_only and p.can_charge(), "in magic the player's graph is cast whole, and charges")
	Magic.set_on(false)
	check(p.runner.forms_only, "magic off, the graph in hand is cast as its forms alone")
	check(not p.can_charge(), "and a hold charges nothing")
	p.charge = 0.0
	p.mana = p.max_mana
	p._update_charge(0.1, true)
	check(is_zero_approx(p.charge) and is_equal_approx(p.mana, p.max_mana),
		"so holding builds no charge and spends no mana (%.2f, %.0f)" % [p.charge, p.mana])
	Magic.set_on(true)
	check(not p.runner.forms_only and p.can_charge(), "back on, the graph is whole again and charges")
	p._update_charge(0.1, true)
	check(p.charge > 0.0, "and a hold builds (%.2f)" % p.charge)
	p.queue_free()
	await frames(1)

## A monster's board follows it too: the Bomber's blow is a punch that neither
## burns nor reaches round while magic is off.
func _the_monster() -> void:
	var e := Enemy.new()
	e.setup("BOMBER", 1, "")
	add_child(e)
	await frames(2)
	var full := first_out(e.runner)
	check(not e.runner.forms_only and full != null and full.near > 0 and full.spread != null
			and full.elements.has("FIRE"),
		"in magic the Bomber's blow burns and reaches round")
	Magic.set_on(false)
	await frames(2)
	var bare := first_out(e.runner)
	check(e.runner.forms_only and bare != null and bare.form == "HEADBUTT" and bare.near == 0
			and bare.spread == null and bare.elements.is_empty(),
		"magic off, it is a punch and nothing more")
	Magic.set_on(true)
	await frames(2)
	check(not e.runner.forms_only, "and whole again when magic is back")
	e.queue_free()
	await frames(1)

## Magic stone in a made room: ground while magic is on, and nothing while it is
## off — not ground, not solid, the rock built again without it and the picture
## told — and ground again the moment it is back. A thing laid beside it stands
## on its own cell.
func _the_stone() -> void:
	var r := MadeRoom.new()
	r.plan = PackedStringArray([
		"########",
		"#.T....#",
		"#.~~...#",
		"#......#",
		"#P.....#",
		"########",
	])
	add_child(r)
	r.stand()
	await frames(1)
	check(MadeRoom.is_ground(MadeRoom.MAGIC) and r.is_solid(2, 2) and r.is_solid(3, 2) and not r.is_solid(4, 2),
		"magic stone is ground while magic is on")
	var shapes_on := r.body.get_child_count()
	var heard := [0]
	r.ground_changed.connect(func() -> void: heard[0] += 1)
	Magic.set_on(false)
	check(not MadeRoom.is_ground(MadeRoom.MAGIC) and not r.is_solid(2, 2) and not r.is_solid(3, 2)
			and r.is_solid(0, 2) and r.is_solid(2, 5),
		"off, the stone is gone: not ground, not solid, the rock round it as it was")
	check(heard[0] == 1 and r.body.get_child_count() < shapes_on,
		"the rock is built again without it (%d shapes, %d with it), and the picture is told" % [r.body.get_child_count(), shapes_on])
	Magic.set_on(true)
	check(r.is_solid(2, 2) and heard[0] == 2 and r.body.get_child_count() == shapes_on,
		"and back on, it stands again")
	var box: Dictionary = r.record().get("box", {})
	var at: Array = box.get("pos", [0, 0])
	# Laid on row 1, it stands on row 1, whatever the stone beside it does.
	check(is_equal_approx(float(at[1]), r.cell_center(2, 1).y),
		"a box laid beside it stands on its own cell (row %.1f)" % (float(at[1]) / Room.CELL))
	r.queue_free()
	await frames(1)
