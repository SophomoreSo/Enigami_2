extends Node
## The rune (`Weapons.is_rune`): a rock with a charge stored in it. The attack
## button throws it, and the throw carries the stored charge for nothing; the
## cast button never throws it and never charges it. Thrown, it is spent:
## picked back up, the attack button still throws it, but bare — its graph cast
## not at all — until a hold of the cast button with it in hand has poured the
## player's own mana into it to the full, and it is lit again. What is in it is
## kept with the profile.
##
## Played in the hideout with the computer's hands, the way the rock's test is.
## Headless: nothing here is looked at.

var fails := 0
var cues: Array = []
var bot: ComputerHands

func check(ok: bool, what: String) -> void:
	if ok:
		print("[RUNE] PASS ", what)
	else:
		fails += 1
		push_error("RUNE FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()

func until(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while t < secs:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return bool(cond.call())

func heard(cue: StringName, kind: String = "") -> int:
	var n := 0
	for c in cues:
		if c[0] == cue and (kind == "" or String((c[1] as Dictionary).get("kind", "")) == kind):
			n += 1
	return n

func rocks() -> Array:
	return get_tree().get_nodes_in_group("loose_rocks").filter(
		func(r: Node) -> bool: return not r.is_queued_for_deletion())

func bolts(world: Node) -> Array:
	return world.get_children().filter(
		func(c: Node) -> bool: return c is Projectile and not c.is_queued_for_deletion())

func _ready() -> void:
	GameState.reset_profile()
	for n in range(1, GameState.SAVE_SLOTS + 1):
		GameState.delete_slot(n)
	Cues.fired.connect(func(cue: StringName, d: Dictionary) -> void: cues.append([cue, d]))
	_the_weapon()
	await _played()
	_kept()
	GameState.reset_profile()
	print("[RUNE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## A thrown weapon like the rock, with a charge in it, that every profile has.
func _the_weapon() -> void:
	check(Weapons.is_rune("RUNE") and Weapons.is_thrown("RUNE") and not Weapons.is_rune("ROCK"),
		"the rune is thrown as the rock is, and the rock is no rune")
	check(Weapons.root_part("RUNE") == "PROJECTILE" and Weapons.make_board("RUNE").has_root(),
		"its graph is a PROJECTILE at the root, as a new profile gets it")
	check(GameState.owned_weapons.has("RUNE") and GameState.HANDED_OUT.has("RUNE"),
		"a new profile has one, and an old one is handed it")
	check(is_equal_approx(GameState.rune.mana, Rune.START) and not GameState.rune.spent,
		"it starts lit, with one full charge in it (%.1f)" % GameState.rune.mana)

func _played() -> void:
	var h := HideoutWorld.new()
	add_child(h)
	await frames(4)
	var p := h.player
	# A DAMAGE on its graph, so a throw with the skill and one without it can be
	# told apart.
	var graph := SkillBoard.new(7, 5, "rune")
	graph.set_root("PROJECTILE", Vector2i(5, 2))
	graph.place("DAMAGE", Vector2i(6, 2), 0)
	p.setup_kit(["RUNE"], [graph])
	p.global_position.x = 400.0
	await frames(3)
	bot = ComputerHands.new()
	p.input.add(bot)
	bot.point_at(p.global_position + Vector2(260.0, -120.0))
	check(p.holds("RUNE") and p.can_cast() and not p.can_charge(),
		"in hand and lit it casts, and the cast button does not charge it")
	check(p.rune_charge() == int(p.charge_cap()), "a full rune is a full charge (%d)" % p.rune_charge())

	# The cast button never throws it.
	var mana_was := p.mana
	cues.clear()
	bot.cast = true
	await wait(0.6)
	bot.cast = false
	await frames(3)
	check(bolts(h).is_empty() and p.holds("RUNE") and heard(&"attack") == 0,
		"held and let go, the cast button throws nothing")
	check(is_zero_approx(p.charge) and not GameState.rune.spent and is_equal_approx(p.mana, mana_was),
		"and charges nothing, spends nothing of the rune or the player")

	# The attack button throws it, charged, and it is spent.
	cues.clear()
	bot.attack = true
	await frames(3)
	bot.attack = false
	await frames(2)
	var flying := bolts(h)
	check(flying.size() >= 1 and (flying[0] as Projectile).thrown == "RUNE" and not p.holds("RUNE"),
		"the attack button throws the rune itself (%d bolts)" % flying.size())
	var lit_damage := (flying[0] as Projectile).payload.damage if not flying.is_empty() else 0.0
	check(p.runner._cycle_life >= p.runner.pass_cost + int(p.charge_cap()),
		"carrying the charge stored in it (a life of %d)" % p.runner._cycle_life)
	check(GameState.rune.spent and is_zero_approx(GameState.rune.mana) and heard(&"rune_spent") == 1,
		"and thrown, it is spent")
	check(is_equal_approx(p.mana, mana_was), "the player paid nothing for the charge (%.0f)" % p.mana)

	# Picked back up, it is still spent: a dead stone.
	var landed := await until(func() -> bool:
		var all := rocks()
		return all.size() == 1 and (all[0] as LooseRock).resting, 6.0)
	check(landed, "it comes down and lies still")
	if landed:
		var r: LooseRock = rocks()[0]
		p.global_position = r.global_position
		p.velocity = Vector2.ZERO
		await until(func() -> bool: return p.holds("RUNE"), 2.0)
	check(p.holds("RUNE") and p.rune_spent_in_hand() and not p.can_cast() and not p.can_charge(),
		"picked back up, it is still spent: its graph casts nothing, and it charges nothing")
	cues.clear()
	bot.attack = true
	await frames(3)
	bot.attack = false
	await frames(2)
	var bare := bolts(h)
	check(bare.size() == 1 and (bare[0] as Projectile).thrown == "RUNE" and not p.holds("RUNE"),
		"the attack button still throws it, the stone itself (%d bolts)" % bare.size())
	if bare.size() == 1:
		var dmg := (bare[0] as Projectile).payload.damage
		check(dmg < lit_damage and is_equal_approx(dmg, Weapons.finalize("RUNE", _bare_payload()).damage),
			"but bare: the rune's own numbers, nothing its graph builds in (%.1f, %.1f lit)" % [dmg, lit_damage])
	check(heard(&"refused") == 0 and GameState.rune.spent and is_zero_approx(GameState.rune.mana),
		"it goes with no warning, and stays spent")
	# Fetched again, to fill.
	landed = await until(func() -> bool:
		var all := rocks()
		return all.size() == 1 and (all[0] as LooseRock).resting, 6.0)
	if landed:
		var r2: LooseRock = rocks()[0]
		p.global_position = r2.global_position
		p.velocity = Vector2.ZERO
		await until(func() -> bool: return p.holds("RUNE"), 2.0)
	check(p.holds("RUNE"), "and is picked up again")

	# A hold short of full: it keeps what was poured, and stays spent.
	p.mana = 20.0
	bot.cast = true
	await wait(0.8)
	bot.cast = false
	await frames(2)
	check(p.mana < 1.0 and absf(GameState.rune.mana - 20.0) < 1.5 and GameState.rune.spent,
		"a hold pours the player's mana in as far as it goes, and short of full it stays spent (%.1f in it)" % GameState.rune.mana)

	# A hold with mana enough fills it, and it is lit again — and that hold
	# throws nothing.
	p.mana = p.max_mana
	cues.clear()
	bot.cast = true
	var lit := await until(func() -> bool: return not GameState.rune.spent, 3.0)
	bot.cast = false
	await frames(3)
	check(lit and is_equal_approx(GameState.rune.mana, p.rune_full()) and heard(&"rune_lit") == 1,
		"held long enough, it is filled and lit again (%.1f)" % GameState.rune.mana)
	check(bolts(h).is_empty() and p.holds("RUNE") and p.can_cast(),
		"the hold that filled it throws nothing, and it casts again")
	check(absf((p.max_mana - p.mana) - (p.rune_full() - 20.0)) < 3.0,
		"for the mana poured into it (%.0f of the player's)" % (p.max_mana - p.mana))
	h.queue_free()
	await frames(2)

## What a bare throw of the rune carries: its own numbers, as a bolt.
func _bare_payload() -> Payload:
	var p := Weapons.base_payload("RUNE")
	p.form = "PROJECTILE"
	return p

## What is in it, and whether it is spent, goes with the profile.
func _kept() -> void:
	GameState.rune.mana = 12.0
	GameState.rune.spent = true
	GameState.save_game()
	GameState.rune.mana = 0.0
	GameState.rune.spent = false
	GameState.load_slot(GameState.slot)
	check(is_equal_approx(GameState.rune.mana, 12.0) and GameState.rune.spent,
		"what is in the rune comes back with the profile (%.0f, spent %s)" % [GameState.rune.mana, GameState.rune.spent])
