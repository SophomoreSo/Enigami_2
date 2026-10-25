extends Node
## HEADBUTT, PUNCH to a player: the one form with no weapon in it. A fist
## thrown a short way along the aim from where the attacker stands, into the
## first enemy in the way and no further, weighed by no weapon's multipliers — and a graph whose every attack is one
## goes off whether its weapon is in hand or not: the rock lying elsewhere,
## every shuriken thrown, the hands in a monster that has not taken the weapon.
##
## Headless: nothing here is looked at, only where things are and what they
## took.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[HEADBUTT] PASS ", what)
	else:
		fails += 1
		push_error("HEADBUTT FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## A dummy that stands still and takes damage, at `at`, on `team`.
func dummy(at: Vector2, team: int = 1) -> Actor:
	var a := Actor.new()
	a.team = team
	a.max_health = 500.0
	add_child(a)
	a.global_position = at
	return a

## `ids` in a line, the first on the root the way a weapon's own part is, on a
## board exactly as long: the last of them against the way out.
func board_of(ids: Array) -> SkillBoard:
	var b := SkillBoard.new(ids.size(), 5, "test")
	b.set_root(String(ids[0]))
	for i in range(1, ids.size()):
		b.place(String(ids[i]), Vector2i(i, 2), 0)
	return b

## A headbutt of `damage` and `pierce`, out of the spawner as any attack is.
func butt(attacker: Actor, damage: float, pierce: int = 0) -> Payload:
	var p := Payload.new()
	p.form = "HEADBUTT"
	p.damage = damage
	p.pierce = pierce
	Attacks.spawn(p, {"attacker": attacker, "room": null, "team": attacker.team,
		"aim": Vector2.RIGHT, "origin": attacker.global_position})
	return p

func _ready() -> void:
	# Arena.register wants a node to hang the attacks and Deferred nodes off.
	Arena.register(self)
	await frames(2)
	_the_part()
	await _the_punch()
	_unweighed()
	await _without_the_weapon()
	print("[HEADBUTT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## A form like the others: a part that makes a flow a headbutt, placed after a
## weapon's own part as any form is.
func _the_part() -> void:
	var def := Components.get_def("HEADBUTT")
	check(not def.is_empty() and String(def["cat"]) == Components.CAT_FORM and String(def["tag"]) == "melee",
		"HEADBUTT is a form, and a melee one (%s)" % str(def.get("cat", "")))
	check(Components.code_of("HEADBUTT") >= 0, "with a number of its own, so a board with one on it can be shared")
	var runner := SkillRunner.new(board_of(["DASHSLASH", "HEADBUTT"]))
	runner.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	var outs: Array = runner.simulate()["outputs"]
	check(outs.size() == 1 and (outs[0] as Payload).form == "HEADBUTT",
		"after the sword's own part it makes the flow a headbutt (%d out)" % outs.size())
	check(not Weapons.needs_weapon("HEADBUTT") and Weapons.needs_weapon("PROJECTILE")
			and Weapons.needs_weapon("SLASH") and Weapons.needs_weapon("DASHSLASH"),
		"and it is the one form that needs no weapon")

## The fist thrown down the aim that stops against the first enemy it meets:
## that one takes the hit and the one behind it does not, and the attacker does
## not move. With nothing in the way the fist goes its whole reach and the body
## still stays where it was; PIERCE carries the fist on into the next.
func _the_punch() -> void:
	var me := dummy(Vector2(0, 0), 0)
	var first := dummy(Vector2(36, 0))
	var behind := dummy(Vector2(70, 0))
	var hp_first := first.health
	var hp_behind := behind.health
	var p := butt(me, 10.0)
	await frames(2)
	check(is_equal_approx(hp_first - first.health, p.damage),
		"the first enemy in the way takes the hit (%.1f)" % (hp_first - first.health))
	check(is_equal_approx(behind.health, hp_behind), "and the one behind it does not")
	check(me.global_position == Vector2(0, 0),
		"and the attacker stays where it stood (%s)" % str(me.global_position))

	var alone := dummy(Vector2(0, 600), 0)
	var out_of_reach := dummy(Vector2(Attacks.HEADBUTT_REACH + alone.hurt_radius * 2.0 + 10.0, 600))
	var hp_out := out_of_reach.health
	butt(alone, 10.0)
	await frames(2)
	check(alone.global_position == Vector2(0, 600),
		"with nothing in reach the attacker still does not move (%s)" % str(alone.global_position))
	check(is_equal_approx(out_of_reach.health, hp_out),
		"and an enemy past the fist's reach is not hit")

	var through := dummy(Vector2(0, 1200), 0)
	var one := dummy(Vector2(36, 1200))
	var two := dummy(Vector2(56, 1200))
	var hp_one := one.health
	var hp_two := two.health
	butt(through, 10.0, 1)
	await frames(2)
	check(hp_one > one.health and hp_two > two.health, "PIERCE carries it on into the next one")

## The head strikes, not the weapon: none of a weapon's multipliers weigh it.
func _unweighed() -> void:
	var off: Array = []
	for w in Weapons.DEFS:
		var p := Payload.new()
		p.form = "HEADBUTT"
		p.damage = 10.0
		var out := Weapons.finalize(String(w), p)
		if not is_equal_approx(out.damage, 10.0):
			off.append("%s %.2f" % [w, out.damage])
	check(off.is_empty(), "no weapon's multipliers weigh a headbutt (%s)" % ", ".join(off))

## A graph whose every attack is a headbutt goes off whether its weapon is in
## hand or not, and any other graph is held to the weapon as it always was. The
## graph is asked again once it is edited.
func _without_the_weapon() -> void:
	var p := Player.new()
	add_child(p)
	await frames(2)

	# The rock: thrown, and lying somewhere else.
	var rock := board_of(["PROJECTILE", "BRIDGE"])
	p.setup_kit(["ROCK"], [rock])
	check(p.holds("ROCK") and p.can_cast(), "the rock in hand casts")
	p.let_go("ROCK")
	check(not p.can_cast() and not p.bare_handed(), "out of hand, a graph that throws it does not")
	rock.erase_at(Vector2i(1, 2))
	rock.place("HEADBUTT", Vector2i(1, 2), 0)
	p.rebuild_runner()
	check(p.bare_handed() and p.can_cast(),
		"but edited into a headbutt, the same graph goes off with the rock still away")
	p.take_back("ROCK", p)
	check(p.can_cast(), "and goes off with it back in hand as well")

	# The shuriken: every one of them thrown.
	p.setup_kit(["SHURIKEN"], [board_of(["PROJECTILE", "HEADBUTT"])])
	p.stock["SHURIKEN"] = 0
	check(p.can_cast(), "a stack with none left headbutts all the same")
	p.setup_kit(["SHURIKEN"], [board_of(["PROJECTILE", "BRIDGE"])])
	p.stock["SHURIKEN"] = 0
	check(not p.can_cast(), "where a graph that throws them waits for one back")

	# The hands in a monster that has not taken the weapon. Set and asked in the
	# same frame: a possession with no time on it ends at the player's next one.
	var m := Enemy.new()
	m.setup("CRAWLER", 1, "")
	add_child(m)
	await frames(2)
	p.setup_kit(["SWORD"], [board_of(["DASHSLASH", "HEADBUTT"])])
	p.possessing = m
	p.vessel_armed = false
	check(p.vessel() == m and p.can_cast(),
		"a monster the hands are in, holding no weapon, headbutts with the graph")
	p.setup_kit(["SWORD"], [board_of(["DASHSLASH", "BRIDGE"])])
	check(not p.can_cast(), "where any other graph leaves it its own attack until it takes the weapon")
	p.possessing = null
	await frames(2)
