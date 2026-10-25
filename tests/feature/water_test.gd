extends Node
## WATER, the third element, and what it does to the other two. It leaves what
## it strikes wet; a wet target struck with ICE freezes solid — held where it
## stands like a stun, and chilled through, so SHATTER breaks it — and the wet
## is gone into the ice; struck with FIRE it is only dried. Water puts a burning
## target out. After a freeze another does not take for a moment, or WATER and
## ICE on one board would hold anything frozen for good.
##
## Driven through `Attacks.resolve_hit`, the one door every attack goes through.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[WATER] PASS ", what)
	else:
		fails += 1
		push_error("WATER FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Ticks `a`'s statuses on by `secs`, as its own frames would.
func age(a: Actor, secs: float) -> void:
	var step := 1.0 / 60.0
	var t := 0.0
	while t < secs:
		a._process_status(step)
		t += step

var _plot := 0

## A dummy that stands still and takes damage, somewhere of its own.
func dummy() -> Actor:
	_plot += 1
	var a := Actor.new()
	a.team = 1
	a.max_health = 5000.0
	add_child(a)
	a.global_position = Vector2(0, float(_plot) * 3000.0)
	return a

## The payload a flow through `ids` ends as, off the sword: the first is the
## root, the rest after it in a row.
func payload_of(ids: Array) -> Payload:
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
	sim.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	var outs: Array = sim.simulate()["outputs"]
	return outs[0] if outs.size() > 0 else null

func hit(p: Payload, a: Actor) -> void:
	Attacks.resolve_hit(p, a, a.global_position, Vector2.RIGHT, null, null, 0)

func _ready() -> void:
	Arena.register(self)
	await frames(2)
	var water := payload_of(["SLASH", "WATER"])
	var ice := payload_of(["SLASH", "ICE"])
	var fire := payload_of(["SLASH", "FIRE"])

	check(Components.exists("WATER") and Components.get_def("WATER")["cat"] == Components.CAT_STATES
			and water != null and water.elements.has("WATER"),
		"WATER is an element, and a flow through it carries it")

	# Wet, and frozen by the ICE after it.
	var a := dummy()
	hit(water, a)
	check(a.wet_time > 0.0 and not a.frozen(), "a WATER hit leaves it wet (%.1fs)" % a.wet_time)
	hit(ice, a)
	check(a.frozen() and a.stunned() and a.chill_time > 0.0 and a.wet_time <= 0.0,
		"ICE on it after freezes it solid: held like a stun, chilled through, and the wet gone into the ice")
	age(a, Actor.FREEZE_TIME + 0.1)
	check(not a.frozen() and not a.stunned(), "and it thaws out on its own")
	hit(water, a)
	hit(ice, a)
	check(not a.frozen() and a.chill_time > 0.0, "straight after, a freeze does not take again: it is only chilled")
	age(a, Actor.FREEZE_GUARD + 0.1)
	hit(water, a)
	hit(ice, a)
	check(a.frozen(), "and once the moment has passed, it freezes again")

	# Dry ice only chills.
	var b := dummy()
	hit(ice, b)
	check(b.chill_time > 0.0 and not b.frozen(), "ICE on something dry only chills it, as it always did")

	# WATER then ICE in one flow: a freeze in one blow.
	var c := dummy()
	hit(payload_of(["SLASH", "WATER", "ICE"]), c)
	check(c.frozen(), "WATER then ICE on one board freezes in one blow")
	var c2 := dummy()
	hit(payload_of(["SLASH", "ICE", "WATER"]), c2)
	check(not c2.frozen() and c2.wet_time > 0.0, "ICE then WATER chills, then soaks: frozen only by the next ICE")

	# FIRE dries it; WATER puts a fire out.
	var d := dummy()
	hit(water, d)
	hit(fire, d)
	check(d.wet_time <= 0.0 and d.burn_time <= 0.0, "FIRE on it wet dries it, and does not set it alight")
	hit(fire, d)
	check(d.burn_time > 0.0, "dry, FIRE burns it as it always did")
	hit(water, d)
	check(d.burn_time <= 0.0 and d.wet_time > 0.0, "and WATER on it burning puts it out, leaving it wet")

	# SHATTER breaks the ice.
	var e := dummy()
	hit(water, e)
	hit(ice, e)
	var before := e.health
	hit(payload_of(["SLASH", "SHATTER"]), e)
	var plain := dummy()
	var plain_before := plain.health
	hit(payload_of(["SLASH", "SHATTER"]), plain)
	check(not e.frozen() and (before - e.health) > (plain_before - plain.health),
		"SHATTER on it frozen breaks the ice, harder than on something that was not (%.0f, %.0f)"
			% [before - e.health, plain_before - plain.health])

	# A cleanse ends the lot.
	var f := dummy()
	hit(water, f)
	check(f.cleanse() and f.wet_time <= 0.0, "a cleanse dries it")
	hit(water, f)
	hit(ice, f)
	check(f.cleanse() and not f.frozen() and not f.stunned(), "and thaws it out of a freeze")

	# A live monster frozen stands still.
	var m := Enemy.new()
	m.setup("CRAWLER", 1, "")
	add_child(m)
	m.global_position = Vector2(0, 90000)
	await frames(2)
	hit(water, m)
	hit(ice, m)
	check(m.frozen() and m.stunned(), "a monster frozen solid is held, as a stunned one is")
	m.queue_free()

	print("[WATER] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
