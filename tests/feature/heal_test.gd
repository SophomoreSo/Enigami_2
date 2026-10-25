extends Node
## HEAL: a COMMON MODIFIER part that gives what the attack strikes health back
## once the blow has landed — 8 a part — and never to one the blow killed.
## INVERT after it turns it into 8 more damage.
##
## Headless: nothing here is looked at.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[HEAL] PASS ", what)
	else:
		fails += 1
		push_error("HEAL FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## `ids` in a line, the first on the root, on a board exactly as long.
func board_of(ids: Array) -> SkillBoard:
	var b := SkillBoard.new(ids.size(), 5, "test")
	b.set_root(String(ids[0]))
	for i in range(1, ids.size()):
		b.place(String(ids[i]), Vector2i(i, 2), 0)
	return b

func flow(ids: Array) -> Payload:
	var r := SkillRunner.new(board_of(ids))
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	var outs: Array = r.simulate()["outputs"]
	return outs[0] as Payload if not outs.is_empty() else null

func dummy(hp: float) -> Actor:
	var a := Actor.new()
	a.team = 1
	a.max_health = 100.0
	add_child(a)
	a.health = hp
	return a

func _ready() -> void:
	Arena.register(self)
	await frames(2)
	var def := Components.get_def("HEAL")
	check(not def.is_empty() and String(def["cat"]) == Components.CAT_BEHAVIOR and Components.code_of("HEAL") == 49,
		"HEAL is a COMMON MODIFIER part, with a number of its own")

	var one := flow(["SLASH", "HEAL"])
	var two := flow(["SLASH", "HEAL", "HEAL"])
	check(one != null and is_equal_approx(one.heal, 8.0) and two != null and is_equal_approx(two.heal, 16.0),
		"a flow through it carries a heal of 8, and 8 more for each one stacked")

	# Struck: the blow lands, and the heal after it.
	var hurt := dummy(50.0)
	var p := one.clone()
	p.damage = 5.0
	Attacks.resolve_hit(p, hurt, hurt.global_position, Vector2.RIGHT, null, null, 0)
	check(is_equal_approx(hurt.health, 50.0 - 5.0 + 8.0),
		"what it strikes takes the blow and is healed after it (%.0f from 50)" % hurt.health)

	# A blow that kills is a kill.
	var low := dummy(3.0)
	Attacks.resolve_hit(p, low, low.global_position, Vector2.RIGHT, null, null, 0)
	check(low.dead, "one the blow kills is not healed back up")

	# INVERT after it: 8 more damage, and no heal.
	var plain := flow(["SLASH"])
	var turned := flow(["SLASH", "HEAL", "INVERT"])
	check(turned != null and plain != null and is_zero_approx(turned.heal)
			and is_equal_approx(turned.damage, plain.damage + 8.0),
		"INVERT after it is 8 more damage instead (%.0f against %.0f)" % [turned.damage if turned else -1.0, plain.damage if plain else -1.0])

	print("[HEAL] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
