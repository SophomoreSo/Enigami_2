extends Node
## The parts that act at the moment a hit lands, rather than on the way to it:
## PUSH (KNOCKBACK) throws the enemy struck on the way the attack was going and
## PULL drags it toward whoever struck it, NEAR reaches round the enemy struck
## with what the parts after it do — a NEAR and a PULL gathering the room onto
## it, as GRAVITY did before it was retired — SHATTER
## punishes an enemy frost has already slowed, and MANA DRAIN pays the caster
## back for connecting.
##
## Driven through `Attacks.resolve_hit`, which is the one door every attack form
## goes through — so what is checked here holds for a bolt, an arc, a burst and
## a lunge alike.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[IMPACT] PASS ", what)
	else:
		fails += 1
		push_error("IMPACT FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Until every burst in the air has opened all the way and gone, at whatever
## pace the frames come: a burst's hits land as its edge passes them.
func bursts_done() -> void:
	for i in 1000:
		var open := false
		for c in get_children():
			if c is AreaBurst:
				open = true
		if not open:
			return
		await frames(1)

## A dummy that stands still and takes damage, at `at`.
func dummy(at: Vector2) -> Actor:
	var a := Actor.new()
	a.team = 1
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
	# A patroller picks its heading with a coin toss in `_ready`, and the two
	# halves of `pull_travel` only subtract cleanly if both walked the same way.
	e._patrol_dir = 1
	return e

## Rooms for the live-monster checks, kept well apart so one test's pull field
## cannot reach the next test's monster.
var _plot := 0

## How far a `kind` walks in x over half a second while `p` lands 60px to its
## left. Run with and without a NEAR and a PULL, the difference is the drag
## alone — which keeps a Lobber's patrol, which happens whatever is hitting it,
## out of it.
func pull_travel(kind: String, p: Payload) -> float:
	_plot += 1
	var at := Vector2(0, float(_plot) * 4000.0)
	var hit := dummy(at)
	var m := monster(kind, at + Vector2(60, 0))
	await frames(2)
	m.global_position = at + Vector2(60, 0)
	var x0: float = m.global_position.x
	Attacks.resolve_hit(p, hit, hit.global_position, Vector2.RIGHT, null, null, 0)
	for i in 30:
		await get_tree().physics_frame
	var moved: float = m.global_position.x - x0
	hit.queue_free()
	m.queue_free()
	return moved

## How far a `kind` travels in x over half a second after `p` strikes it, the
## attack going right. Run with and without KNOCKBACK, the difference is the
## throw alone.
func knock_travel(kind: String, p: Payload) -> float:
	_plot += 1
	var at := Vector2(0, float(_plot) * 4000.0)
	var m := monster(kind, at)
	await frames(2)
	m.global_position = at
	# One cut must not kill it: a monster freed mid-flight has nowhere left to be.
	m.max_health = 9999.0
	m.health = 9999.0
	var x0: float = m.global_position.x
	Attacks.resolve_hit(p, m, m.global_position, Vector2.RIGHT, null, null, 0)
	for i in 30:
		await get_tree().physics_frame
	var moved: float = m.global_position.x - x0
	m.queue_free()
	return moved

## How far to the right of whoever struck it a `kind` stands a second after `p`
## strikes it from `far` to their right, the attack going right.
func pulled_to(kind: String, p: Payload, far: float) -> float:
	_plot += 1
	var at := Vector2(0, float(_plot) * 4000.0)
	var by := dummy(at)
	by.team = 0
	var m := monster(kind, at + Vector2(far, 0))
	await frames(2)
	m.global_position = at + Vector2(far, 0)
	m.max_health = 9999.0
	m.health = 9999.0
	Attacks.resolve_hit(p, m, m.global_position, Vector2.RIGHT, by, null, 0)
	for i in 60:
		await get_tree().physics_frame
	var ended: float = m.global_position.x - by.global_position.x
	by.queue_free()
	m.queue_free()
	return ended

## A board with `ids` in a line — the first on the root, the way a weapon's own
## part is — on a board exactly as long, so the last of them is against the way
## out; run through the runner so the payload under test is the one the rules
## actually build, not one hand-set here.
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

func _ready() -> void:
	# Arena.register wants a node to hang loose visuals and Deferred nodes off.
	Arena.register(self)
	await frames(2)

	# --- the parts reach the payload at all ---------------------------------
	var plain := payload_of(["SLASH"])
	check(plain != null and not plain.near and not plain.knockback and not plain.shatter
			and not plain.mana_drain,
		"a board without them carries none of them")
	var loaded := payload_of(["SLASH", "SHATTER", "MANA_DRAIN"])
	check(loaded != null and loaded.shatter and loaded.mana_drain,
		"a board with both carries both")
	# The preview is a line out of `localization/`, so what to look for in it is
	# asked for rather than spelled out here.
	var says := Attacks.summary(loaded)
	check(says.contains(Loc.t("editor.payload.shatter", [Attacks.shatter_mul(1)]))
		and says.contains(Loc.t("editor.payload.mana_drain", [Attacks.MANA_PER_HIT])),
		"and the workbench preview says so (%s)" % says)

	# --- SHATTER ------------------------------------------------------------
	var cold := dummy(Vector2(400, 0))
	cold.chill_time = 2.0
	var warm := dummy(Vector2(800, 0))
	var shatter := payload_of(["SLASH", "SHATTER"])
	var before_cold := cold.health
	var before_warm := warm.health
	Attacks.resolve_hit(shatter, cold, cold.global_position, Vector2.RIGHT, null, null, 0)
	Attacks.resolve_hit(shatter, warm, warm.global_position, Vector2.RIGHT, null, null, 0)
	var on_chilled := before_cold - cold.health
	var on_warm := before_warm - warm.health
	check(is_equal_approx(on_chilled, on_warm * Attacks.shatter_mul(1)),
		"SHATTER hits a chilled enemy x%.1f as hard (%.1f against %.1f)"
			% [Attacks.shatter_mul(1), on_chilled, on_warm])
	check(cold.chill_time <= 0.0, "and breaks the frost: the enemy thaws")
	var before_thawed := cold.health
	Attacks.resolve_hit(shatter, cold, cold.global_position, Vector2.RIGHT, null, null, 0)
	check(is_equal_approx(before_thawed - cold.health, on_warm), "so the next hit has nothing to shatter")
	# Without the part, being chilled changes nothing.
	var chilled_again := dummy(Vector2(1200, 0))
	chilled_again.chill_time = 2.0
	var before_plain := chilled_again.health
	Attacks.resolve_hit(plain, chilled_again, chilled_again.global_position, Vector2.RIGHT, null, null, 0)
	check(is_equal_approx(before_plain - chilled_again.health, on_warm),
		"a board without SHATTER hits a chilled enemy no harder")

	# ICE and SHATTER on the same attack: the frost this hit applies is not the
	# frost it shatters, or one part would be doing both halves of the pair.
	var fresh := dummy(Vector2(1600, 0))
	var iced := payload_of(["SLASH", "ICE", "SHATTER"])
	var before_fresh := fresh.health
	Attacks.resolve_hit(iced, fresh, fresh.global_position, Vector2.RIGHT, null, null, 0)
	var first := before_fresh - fresh.health
	check(fresh.chill_time > 0.0, "ICE chills on the first hit")
	check(is_equal_approx(first, iced.damage),
		"which the same hit does not then shatter (%.1f)" % first)
	var before_second := fresh.health
	Attacks.resolve_hit(iced, fresh, fresh.global_position, Vector2.RIGHT, null, null, 0)
	check(is_equal_approx(before_second - fresh.health, iced.damage * Attacks.shatter_mul(1)),
		"but the second hit lands on a chilled enemy and does")
	check(fresh.chill_time <= 0.0, "and thaws it, the chill that hit brought included")

	# --- NEAR and PULL: the room gathered onto the enemy struck --------------
	# GRAVITY's work, done by the two of them: every enemy round the one struck
	# dragged in to it, the further ones harder, so they arrive together, and
	# nothing past the NEAR's reach.
	var impact := Vector2(0, 0)
	var struck := dummy(impact + Vector2(20, 0))
	var near := dummy(impact + Vector2(60, 0))
	var far := dummy(impact + Vector2(Attacks.NEAR_RADIUS - 10.0, 0))
	var outside := dummy(impact + Vector2(Attacks.NEAR_RADIUS + 80.0, 0))
	var gather := payload_of(["SLASH", "NEAR", "PULL"])
	Attacks.resolve_hit(gather, struck, struck.global_position, Vector2.RIGHT, null, null, 0)
	await bursts_done()
	check(near.shove.x < 0.0 and far.shove.x < 0.0,
		"a NEAR and a PULL drag every other enemy round the one struck onto it (%.0f, %.0f)" % [near.shove.x, far.shove.x])
	check(outside.shove.is_zero_approx(),
		"but nothing past the NEAR's reach (%.0f)" % Attacks.near_radius(gather))
	check(absf(far.shove.x) > absf(near.shove.x),
		"the further one is dragged harder, so they arrive together (%.0f vs %.0f)"
			% [absf(far.shove.x), absf(near.shove.x)])
	# Without the part the struck enemy is knocked away, as it always was.
	var shoved := dummy(Vector2(0, 400))
	Attacks.resolve_hit(plain, shoved, shoved.global_position, Vector2.RIGHT, null, null, 0)
	check(shoved.shove.x > 0.0, "an ordinary hit knocks its target back")

	# --- and it has to move a real monster ----------------------------------
	# The dummies above are inert: nothing writes their velocity but the hit.
	# Every real monster assigns its own velocity each physics frame — a turret
	# writes zero into it, a patroller writes its patrol speed — so a pull that
	# only sets velocity was wiped before it moved anything, which is how
	# GRAVITY once came to pass every check above and do nothing in the game.
	# These run the monsters for half a second and look at where they ended up.
	for kind in ["DUMMY", "CRAWLER", "LOBBER", "DRIFTER"]:
		var travelled: float = await pull_travel(kind, gather) - await pull_travel(kind, plain)
		check(travelled < -20.0,
			"a %s 60px from a hit with a NEAR and a PULL is dragged %.0fpx towards it" % [kind, -travelled])

	# --- KNOCKBACK ----------------------------------------------------------
	var knock := payload_of(["SLASH", "KNOCKBACK"])
	check(knock != null and knock.knockback
			and Attacks.summary(knock).contains(Loc.t("editor.payload.knockback")),
		"a board with KNOCKBACK carries it, and the workbench preview says so (%s)" % Attacks.summary(knock))
	# Whichever way the attack was going — up and to the left here, which
	# nothing in an ordinary hit favours — the enemy struck is thrown on that
	# way, by exactly KNOCKBACK_FORCE more than the same hit without the part.
	var way := Vector2(-3.0, -1.0).normalized()
	var nudged := dummy(Vector2(0, 2400))
	var thrown := dummy(Vector2(400, 2400))
	Attacks.resolve_hit(plain, nudged, nudged.global_position, way, null, null, 0)
	Attacks.resolve_hit(knock, thrown, thrown.global_position, way, null, null, 0)
	var extra := thrown.shove - nudged.shove
	check(extra.is_equal_approx(way * Attacks.KNOCKBACK_FORCE),
		"KNOCKBACK throws the enemy struck %.0f harder, the way the attack was going (%s)"
			% [Attacks.KNOCKBACK_FORCE, str(extra)])
	# And it has to move a monster that writes its own velocity every frame, far
	# enough to see: three cells is a throw, not a flinch.
	for kind in ["DUMMY", "CRAWLER", "LOBBER", "DRIFTER"]:
		var flew: float = await knock_travel(kind, knock) - await knock_travel(kind, plain)
		check(flew > 3.0 * Room.CELL,
			"a %s struck with KNOCKBACK is thrown %.0fpx further" % [kind, flew])

	# --- PULL -----------------------------------------------------------------
	var pull_in := payload_of(["SLASH", "PULL"])
	check(pull_in != null and pull_in.hook == 1 and not pull_in.knockback
			and Attacks.summary(pull_in).contains(Loc.t("editor.payload.hook")),
		"a board with PULL carries it, and the workbench preview says so (%s)" % Attacks.summary(pull_in))
	# From afar, whichever way the attack was going, the enemy struck is dragged
	# toward whoever struck it, as hard as PUSH would throw it away.
	var shooter := dummy(Vector2(0, 3200))
	shooter.team = 0
	var reeled := dummy(Vector2(-300, 3000))
	Attacks.resolve_hit(pull_in, reeled, reeled.global_position, way, shooter, null, 0)
	var toward := (shooter.global_position - reeled.global_position).normalized()
	check(reeled.shove.normalized().is_equal_approx(toward)
			and is_equal_approx(reeled.shove.length(), Attacks.hit_shove(pull_in) + Attacks.KNOCKBACK_FORCE),
		"PULL drags the enemy struck toward whoever struck it, as hard as PUSH throws (%s)" % str(reeled.shove))
	# From close by, no harder than lands it just short of them.
	var close_by := dummy(Vector2(60, 3200))
	Attacks.resolve_hit(pull_in, close_by, close_by.global_position, Vector2.RIGHT, shooter, null, 0)
	var just := sqrt(2.0 * Actor.SHOVE_DECAY * (60.0 - Attacks.HOOK_SHORT))
	check(close_by.shove.x < 0.0 and is_equal_approx(close_by.shove.length(), just),
		"from close by, no harder than carries it to just short of them (%.0f, %.0f)" % [close_by.shove.length(), just])
	shooter.queue_free()
	reeled.queue_free()
	close_by.queue_free()
	# A monster that writes its own velocity every frame ends up nearer whoever
	# struck it, from close by and from afar, and never past them.
	for off: float in [60.0, 300.0]:
		var ended: float = await pulled_to("DUMMY", pull_in, off)
		check(ended > 0.0 and ended < off - 20.0,
			"a DUMMY pulled from %.0fpx off ends %.0fpx off: nearer, and not past" % [off, ended])

	# --- MANA DRAIN ---------------------------------------------------------
	var caster := Player.new()
	add_child(caster)
	await frames(2)
	caster.global_position = Vector2(0, 900)
	caster.mana = 20.0
	var victim := dummy(Vector2(200, 900))
	var drain := payload_of(["SLASH", "MANA_DRAIN"])
	Attacks.resolve_hit(drain, victim, victim.global_position, Vector2.RIGHT, caster, null, 0)
	check(is_equal_approx(caster.mana, 20.0 + Attacks.MANA_PER_HIT),
		"MANA DRAIN pays the caster back %.0f a hit (%.1f)" % [Attacks.MANA_PER_HIT, caster.mana])
	# Every connection pays: that is what makes it worth a board that lands often.
	Attacks.resolve_hit(drain, victim, victim.global_position, Vector2.RIGHT, caster, null, 0)
	check(is_equal_approx(caster.mana, 20.0 + Attacks.MANA_PER_HIT * 2.0),
		"and again on the next one (%.1f)" % caster.mana)
	# It never overfills.
	caster.mana = Player.MAX_MANA - 1.0
	Attacks.resolve_hit(drain, victim, victim.global_position, Vector2.RIGHT, caster, null, 0)
	check(is_equal_approx(caster.mana, Player.MAX_MANA),
		"and stops at a full bar (%.1f)" % caster.mana)
	# A board without it takes nothing back.
	caster.mana = 30.0
	Attacks.resolve_hit(plain, victim, victim.global_position, Vector2.RIGHT, caster, null, 0)
	check(is_equal_approx(caster.mana, 30.0), "a board without MANA DRAIN gives nothing back")
	# A monster carrying the part has no mana to fill, and must not error.
	var monster := dummy(Vector2(600, 900))
	Attacks.resolve_hit(drain, victim, victim.global_position, Vector2.RIGHT, monster, null, 1)
	check(true, "an attacker with no mana of its own drains harmlessly")

	# --- HEALTH DRAIN -------------------------------------------------------
	caster.max_health = 100.0
	caster.health = 50.0
	var leech := payload_of(["SLASH", "HEALTH_DRAIN"])
	var before := victim.health
	Attacks.resolve_hit(leech, victim, victim.global_position, Vector2.RIGHT, caster, null, 0)
	var dealt := before - victim.health
	check(dealt > 0.0 and is_equal_approx(caster.health, 50.0 + dealt * Attacks.HEALTH_DRAIN_SHARE),
		"HEALTH DRAIN gives the caster back a fifth of what the hit dealt (%.1f of %.1f)" % [caster.health - 50.0, dealt])
	caster.health = caster.max_health
	Attacks.resolve_hit(leech, victim, victim.global_position, Vector2.RIGHT, caster, null, 0)
	check(is_equal_approx(caster.health, caster.max_health), "and never past a full bar (%.1f)" % caster.health)
	check(Attacks.summary(leech).contains(Loc.t("editor.payload.health_drain", [20])),
		"and the preview says how much (%s)" % Attacks.summary(leech))

	# --- NEAR ---------------------------------------------------------------
	# The attack stays what it was, and lands on the enemy struck whole; what
	# the parts after the NEAR do reaches the enemies round it as well — their
	# effects, not the blow. Laid out well clear of everything above, which is
	# still standing and would be in the reach.
	var round_it := payload_of(["SLASH", "NEAR", "FIRE", "STUN"])
	check(round_it != null and round_it.form == "SLASH" and round_it.near == 1 and round_it.spread != null
			and round_it.has_element("FIRE") and round_it.stun > 0.0
			and round_it.spread.has_element("FIRE") and round_it.spread.stun > 0.0
			and is_zero_approx(round_it.spread.damage)
			and Attacks.summary(round_it).contains(Loc.t("editor.payload.near", [""]).strip_edges()),
		"a board with NEAR keeps its attack, and carries what comes after it apart, which the preview says (%s)"
			% (Attacks.summary(round_it) if round_it != null else "nothing"))
	var centre := dummy(Vector2(3000, 3000))
	var by_it := dummy(Vector2(3040, 3000))
	var past := dummy(Vector2(3000.0 + Attacks.near_radius(round_it) * 2.0, 3000))
	var hp_centre := centre.health
	var hp_by := by_it.health
	var hp_past := past.health
	Attacks.resolve_hit(round_it, centre, centre.global_position, Vector2.RIGHT, null, null, 0)
	await bursts_done()
	check(is_equal_approx(hp_centre - centre.health, round_it.damage),
		"the enemy struck takes the whole hit once, and nothing more from the reach (%.1f of %.1f)"
			% [hp_centre - centre.health, round_it.damage])
	check(is_equal_approx(hp_by, by_it.health) and by_it.burn_time > 0.0 and by_it.stunned()
			and is_equal_approx(by_it.burn_dps, centre.burn_dps),
		"the one beside it is not struck, but burnt as hard as the enemy struck and stunned (%.1f lost, %.2f burn)"
			% [hp_by - by_it.health, by_it.burn_dps])
	check(is_equal_approx(hp_past, past.health) and past.burn_time <= 0.0, "and nothing past the reach is touched")
	# A DAMAGE after it hurts the ones round the enemy struck by as much as it
	# adds; what came before the NEAR stays on the enemy struck.
	var hurt_round := payload_of(["SLASH", "FIRE", "NEAR", "DAMAGE"])
	var struck2 := dummy(Vector2(3000, 3400))
	var by2 := dummy(Vector2(3040, 3400))
	var hp_by2 := by2.health
	Attacks.resolve_hit(hurt_round, struck2, struck2.global_position, Vector2.RIGHT, null, null, 0)
	await bursts_done()
	check(hurt_round.spread != null and is_equal_approx(hp_by2 - by2.health, hurt_round.spread.damage)
			and hurt_round.spread.damage > 0.0 and by2.burn_time <= 0.0 and struck2.burn_time > 0.0,
		"a DAMAGE after it hurts the ones round it by its own (%.1f), and a FIRE before it burns the enemy struck alone"
			% (hp_by2 - by2.health))
	var alone := dummy(Vector2(3000, 3600))
	var near_alone := dummy(Vector2(3040, 3600))
	var hp_near_alone := near_alone.health
	Attacks.resolve_hit(plain, alone, alone.global_position, Vector2.RIGHT, null, null, 0)
	await bursts_done()
	check(is_equal_approx(hp_near_alone, near_alone.health), "a board without NEAR hits only what it strikes")
	# What reaches round is the parts after it, not what the hit sets off: the
	# hit's own ON HIT goes off once, and the reach neither reaches on nor takes
	# a monster over.
	var armed := round_it.clone()
	armed.on_hit = Payload.new()
	armed.on_kill = Payload.new()
	armed.possess = 5.0
	armed.spread.possess = 5.0
	var host := dummy(Vector2(3000, 3800))
	Attacks.resolve_hit(armed, host, host.global_position, Vector2.RIGHT, null, null, 0)
	var opened: AreaBurst = null
	for c in get_children():
		if c is AreaBurst:
			opened = c
	check(opened != null and opened.position == host.global_position
			and opened.payload.near == 0 and opened.payload.spread == null and opened.payload.touch >= 0.0
			and opened.payload.on_hit == null and opened.payload.on_kill == null and opened.payload.possess == 0.0
			and is_zero_approx(opened.payload.damage),
		"the reach opens on the enemy struck with what came after the NEAR, but not another NEAR, its triggers or its POSSESS")
	await bursts_done()
	# Every one stacked reaches further.
	var wider := payload_of(["SLASH", "NEAR", "NEAR", "FIRE"])
	check(wider != null and wider.near == 2 and is_equal_approx(Attacks.near_radius(wider),
			Attacks.near_radius(round_it) * (1.0 + Attacks.NEAR_WIDER)),
		"a second NEAR reaches further (%.0f against %.0f)"
			% [Attacks.near_radius(wider) if wider != null else 0.0, Attacks.near_radius(round_it)])
	# With no form there is no blow and nobody struck, and the NEAR is the
	# attack: what comes after it touches everything round where the flow is
	# cast — the Hopper's, the Arbiter's second form's, a trigger's branch with
	# one on it. Its touches reach on no further: of the two caught in it, the
	# nearer would take the farther one's as well.
	var bare := Payload.new()
	bare.near = 1
	bare.spread = Payload.new()
	bare.spread.damage = 5.0
	check(bare.is_productive(), "a flow with no form but a NEAR does something as it leaves the board")
	var ringed := dummy(Vector2(3030, 4200))
	var ringed_far := dummy(Vector2(3060, 4200))
	var hp_ringed := ringed.health
	var hp_ringed_far := ringed_far.health
	Attacks.spawn(bare, {"attacker": null, "room": null, "team": 0, "aim": Vector2.RIGHT,
		"origin": Vector2(3000, 4200)})
	await bursts_done()
	check(is_equal_approx(hp_ringed - ringed.health, bare.spread.damage)
			and is_equal_approx(hp_ringed_far - ringed_far.health, bare.spread.damage),
		"and touches everything round where it is cast, each once, with what came after it (%.1f and %.1f of %.1f)"
			% [hp_ringed - ringed.health, hp_ringed_far - ringed_far.health, bare.spread.damage])

	# --- both of them together -----------------------------------------------
	var all_cold := dummy(Vector2(0, 1400))
	all_cold.chill_time = 2.0
	caster.mana = 0.0
	var before_all := all_cold.health
	Attacks.resolve_hit(loaded, all_cold, all_cold.global_position, Vector2.RIGHT, caster, null, 0)
	check(is_equal_approx(before_all - all_cold.health, loaded.damage * Attacks.shatter_mul(1)),
		"one hit can shatter and drain at once — damage")
	check(is_equal_approx(caster.mana, Attacks.MANA_PER_HIT), "— and drain")

	print("[IMPACT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
