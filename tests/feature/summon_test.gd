extends Node2D
## SUMMON MODIFIER: what an attack calls up beside itself as it goes off.
## SUMMON PET calls a pet that follows its summoner, one to a summoner, and
## goes with them; with OFFENSIVE it goes for the nearest enemy near them and
## strikes it; with KAMIKAZE it flies at that enemy and blows itself up against
## it, and is gone. SUMMON BOLT, whose place KAMIKAZE took, is retired.
## ANTI-GRAVITY takes the weight off a bolt: a lobbed one flies straight.
##
## Headless: nothing here is looked at.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SUMMON] PASS ", what)
	else:
		fails += 1
		push_error("SUMMON FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func dummy(at: Vector2, team: int) -> Actor:
	var a := Actor.new()
	a.team = team
	a.max_health = 500.0
	add_child(a)
	a.global_position = at
	return a

func pets() -> Array:
	return get_tree().get_nodes_in_group("pets").filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())

func cast(p: Payload, by: Actor, aim: Vector2 = Vector2.RIGHT) -> void:
	Attacks.spawn(p, {"attacker": by, "room": null, "team": by.team, "aim": aim, "origin": by.global_position})

func _ready() -> void:
	Arena.register(self)
	await frames(2)
	_the_parts()
	await _the_pet()
	await _weightless()
	await _offensive()
	await _kamikaze()
	print("[SUMMON] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## The parts in the SUMMON MODIFIER block, with numbers of their own, that put
## their counts on a flow.
func _the_parts() -> void:
	for id in ["SUMMON_PET", "OFFENSIVE", "KAMIKAZE"]:
		var def := Components.get_def(id)
		check(not def.is_empty() and String(def["cat"]) == Components.CAT_SUMMON_BEHAVIOR and Components.code_of(id) >= 43,
			"%s is a summon part with a number of its own" % id)
	check(Components.is_retired("SUMMON_PROJECTILE") and not Components.exists("SUMMON_PROJECTILE")
			and Components.code_of("SUMMON_PROJECTILE") == 42,
		"SUMMON BOLT is retired, and keeps its number")
	check(Components.categories().has(Components.CAT_SUMMON_BEHAVIOR)
			and not Components.categories().has("pet_behavior"),
		"the block is SUMMON MODIFIER, and PET BEHAVIOR is gone")
	var b := SkillBoard.new(4, 5, "s")
	b.set_root("PROJECTILE")
	b.place("KAMIKAZE", Vector2i(1, 2), 0)
	b.place("KAMIKAZE", Vector2i(2, 2), 0)
	b.place("SUMMON_PET", Vector2i(3, 2), 0)
	var r := SkillRunner.new(b)
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload("GUN")
	var outs: Array = r.simulate()["outputs"]
	var p: Payload = outs[0] if not outs.is_empty() else null
	check(p != null and p.pet_kamikaze == 2 and p.summon_pet == 1 and p.form == "PROJECTILE",
		"a flow through them carries them, stacked, on top of its form")

## ANTI-GRAVITY: a lobbed bolt flies without its arc.
func _weightless() -> void:
	check(String(Components.get_def("ANTI_GRAVITY").get("cat", "")) == Components.CAT_PROJECTILE_BEHAVIOR
			and Components.code_of("ANTI_GRAVITY") == 44,
		"ANTI-GRAVITY is a projectile behavior, with a number of its own")
	var me := dummy(Vector2(0, 1200), 0)
	var lob := Payload.new()
	lob.form = "PROJECTILE"
	lob.damage = 1.0
	var ctx := {"attacker": me, "room": null, "team": 0, "aim": Vector2.RIGHT,
		"origin": me.global_position, "lobbed": true}
	Attacks.spawn(lob, ctx)
	var light := lob.clone()
	light.anti_gravity = 1
	Attacks.spawn(light, ctx)
	var shots := get_children().filter(func(c: Node) -> bool: return c is Projectile and not c.is_queued_for_deletion())
	check(shots.size() == 2 and (shots[0] as Projectile).gravity > 0.0 and is_zero_approx((shots[1] as Projectile).gravity),
		"a lobbed bolt arcs, and with ANTI-GRAVITY it flies straight (%s)"
			% str(shots.map(func(s: Projectile) -> float: return s.gravity)))
	Attacks.clear_in_flight(self)
	me.queue_free()
	await frames(2)

## By the clock: a headless run goes through frames far faster than a second a
## sixtieth at a time.
func seconds(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()

## OFFENSIVE: a pet summoned with it goes for the nearest enemy near its
## summoner and strikes it with the flow, over and over; one without it never
## does; and a later cast tells a pet already there what it does.
func _offensive() -> void:
	check(String(Components.get_def("OFFENSIVE").get("cat", "")) == Components.CAT_SUMMON_BEHAVIOR
			and Components.code_of("OFFENSIVE") == 45,
		"OFFENSIVE is a summon part, with a number of its own")
	var me := dummy(Vector2(0, 2400), 0)
	var foe := dummy(Vector2(120, 2400), 1)
	var far_foe := dummy(Vector2(900, 2400), 1)
	var calm := Payload.new()
	calm.damage = 5.0
	calm.summon_pet = 1
	cast(calm, me)
	var hp := foe.health
	await seconds(1.5)
	check(is_equal_approx(foe.health, hp), "a pet without OFFENSIVE leaves the enemy near it alone")
	var angry := calm.clone()
	angry.pet_offensive = 1
	cast(angry, me)
	var pet: Pet = Pet.of(me, get_tree())
	check(pets().size() == 1 and pet != null and pet.offensive == 1,
		"a later cast with OFFENSIVE tells the pet already there, and calls no other")
	# Long enough for the dart there and back to count for little against the
	# wait between strikes, so one OFFENSIVE and two can be told apart.
	await seconds(4.0)
	var took := hp - foe.health
	check(took >= 5.0 - 0.01, "it goes for the enemy near its summoner and strikes it (%.0f)" % took)
	check(took >= 10.0 - 0.01, "over and over (%.0f in four seconds)" % took)
	check(is_equal_approx(far_foe.health, far_foe.max_health), "and leaves one far from its summoner alone")
	# Two of them strike twice as often.
	var fiercer := angry.clone()
	fiercer.pet_offensive = 2
	cast(fiercer, me)
	var before := foe.health
	await seconds(4.0)
	var faster := before - foe.health
	check(faster > took, "each one stacked strikes more often (%.0f against %.0f)" % [faster, took])
	me.queue_free()
	foe.queue_free()
	far_foe.queue_free()
	await frames(3)

## A pet that follows its summoner: one to a summoner, gone with them.
func _the_pet() -> void:
	var me := dummy(Vector2(400, 0), 0)
	var p := Payload.new()
	p.summon_pet = 1
	cast(p, me)
	check(pets().size() == 1, "a flow with SUMMON PET calls a pet (%d)" % pets().size())
	if pets().is_empty():
		return
	var pet: Pet = pets()[0]
	check(pet.summoner == me, "for whoever cast it")
	cast(p, me)
	check(pets().size() == 1, "and only one: a second cast calls no other (%d)" % pets().size())
	me.global_position = Vector2(900, 200)
	# By the clock, not by frames: a headless run goes through frames far faster
	# than a second a sixtieth at a time.
	var t := 0.0
	while t < 2.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	check(pet.global_position.distance_to(pet.home()) < 12.0,
		"it follows its summoner, over their shoulder (%.0f off)" % pet.global_position.distance_to(pet.home()))
	me.queue_free()
	await frames(3)
	check(pets().is_empty(), "and goes when its summoner does")

## KAMIKAZE: a pet summoned with it flies at the nearest enemy near its
## summoner and blows itself up against it — the flow bursting on everything
## round it, once — and is gone, until the next cast calls another. Two of them
## burst wider than one.
func _kamikaze() -> void:
	check(String(Components.get_def("KAMIKAZE").get("cat", "")) == Components.CAT_SUMMON_BEHAVIOR
			and Components.code_of("KAMIKAZE") == 46,
		"KAMIKAZE is a summon part, with a number of its own")
	var me := dummy(Vector2(0, 3600), 0)
	var foe := dummy(Vector2(120, 3600), 1)
	var beside := dummy(Vector2(150, 3600), 1)
	var far_foe := dummy(Vector2(900, 3600), 1)
	var bomb := Payload.new()
	bomb.damage = 7.0
	bomb.summon_pet = 1
	bomb.pet_kamikaze = 1
	cast(bomb, me)
	var pet: Pet = Pet.of(me, get_tree())
	check(pet != null and pet.kamikaze == 1, "a pet summoned with it is a kamikaze one")
	await seconds(1.5)
	var took := foe.max_health - foe.health
	check(took > 0.0 and beside.health < beside.max_health,
		"it blows itself up against the enemy near its summoner, and the one beside it takes the blast too (%.0f, %.0f)"
			% [took, beside.max_health - beside.health])
	check(not is_instance_valid(pet) or pet.is_queued_for_deletion(), "and the pet is gone")
	check(Pet.of(me, get_tree()) == null and is_equal_approx(far_foe.health, far_foe.max_health),
		"leaving no pet, and the enemy far from its summoner alone")
	await seconds(1.0)
	check(is_equal_approx(foe.max_health - foe.health, took), "it blows up once (%.0f)" % (foe.max_health - foe.health))
	cast(bomb, me)
	check(Pet.of(me, get_tree()) != null, "and the next cast calls another")
	me.queue_free()
	foe.queue_free()
	beside.queue_free()
	far_foe.queue_free()
	await frames(3)
	# Wider for each one stacked: an enemy past one KAMIKAZE's blast, and inside
	# two's.
	var who := dummy(Vector2(0, 4800), 0)
	var between := (Attacks.NEAR_RADIUS + Attacks.NEAR_RADIUS * (1.0 + Attacks.NEAR_WIDER)) * 0.5
	for n in [1, 2]:
		var out := dummy(Vector2(between, 4800), 1)
		out.global_position.x += out.hurt_radius
		var p := Payload.new()
		p.damage = 3.0
		p.pet_kamikaze = n
		Attacks.kamikaze(p, Vector2(0, 4800), 0, who, null)
		await seconds(0.6)
		var hit := out.health < out.max_health
		check(hit == (n == 2), "%d KAMIKAZE%s: %s %.0f off" % [n, "" if n == 1 else "s",
			"reaches the enemy" if n == 2 else "falls short of the enemy", between + out.hurt_radius])
		out.queue_free()
		await frames(2)
	who.queue_free()
	await frames(3)
