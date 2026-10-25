extends Node
## The perks (perks/rules, `Perks`): bought with gold a step at a time, kept
## with the profile, and what they add reaching the player's own numbers
## through `GameState.boost` — which the rules ask without naming them.
##
## Headless: nothing here is looked at. The profile it buys into is wiped again
## at the end, so no test after this one walks in with perks bought.

## The stats a perk may raise, and that the rules ask `GameState.boost` for.
const STATS := ["max_health", "max_stamina", "max_mana", "max_charge", "move_speed", "charge_speed",
	"cast_speed", "gold"]

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[PERKS] PASS ", what)
	else:
		fails += 1
		push_error("PERKS FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	GameState.reset_profile()
	_the_table()
	_buying()
	await _the_player()
	_gold()
	await _toggled()
	_kept()
	# Nothing bought is left behind for whatever runs next.
	GameState.reset_profile()
	print("[PERKS] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Every perk is read, raises a stat the rules ask for, and has steps from the
## first with nothing missed, each dearer than the one before.
func _the_table() -> void:
	var ids := Perks.ids()
	check(ids.size() >= 6, "the perks are read, %d of them" % ids.size())
	var wrong: Array = []
	for id: String in ids:
		var def := Perks.get_def(id)
		if not STATS.has(String(def["stat"])) or float(def["per_step"]) <= 0.0:
			wrong.append("%s raises %s" % [id, def["stat"]])
		var costs: Array = def["costs"]
		if costs.is_empty():
			wrong.append("%s has no steps" % id)
		for i in range(1, costs.size()):
			if int(costs[i]) <= int(costs[i - 1]):
				wrong.append("%s step %d is no dearer than the one before" % [id, i + 1])
		if Perks.name_for(id) == "" or Perks.desc_for(id) == "":
			wrong.append("%s has no words" % id)
	check(wrong.is_empty(), "each raises a stat the rules ask for, a step dearer each time (%s)" % ", ".join(wrong))
	var gaps: Array = []
	var seen := {}
	for row in Db.rows("SELECT perk_id, step FROM perk_steps ORDER BY perk_id, step"):
		var perk := String(row["perk_id"])
		seen[perk] = int(seen.get(perk, 0)) + 1
		if int(row["step"]) != int(seen[perk]):
			gaps.append("%s step %d" % [perk, int(row["step"])])
	check(gaps.is_empty(), "and its steps run from the first with none missed (%s)" % ", ".join(gaps))

## Bought a step at a time, for the gold the next one costs, and never past the
## last of them; with not enough gold, nothing.
func _buying() -> void:
	var nothing := true
	for stat in STATS:
		nothing = nothing and is_zero_approx(GameState.boost(stat))
	for perk: String in Perks.ids():
		nothing = nothing and Perks.owned(perk) == 0
	check(nothing, "a new profile has bought nothing, and nothing is added")

	var id := "TOUGHNESS"
	var costs: Array = Perks.get_def(id)["costs"]
	GameState.scrap = int(costs[0]) - 1
	check(not Perks.can_buy(id) and not Perks.buy(id) and GameState.scrap == int(costs[0]) - 1
			and Perks.owned(id) == 0,
		"one gold short, the first step is not bought and nothing is spent")
	GameState.scrap = 100000
	check(Perks.buy(id) and Perks.owned(id) == 1 and GameState.scrap == 100000 - int(costs[0]),
		"with the gold, the first step is bought for what it costs (%d left)" % GameState.scrap)
	check(Perks.next_cost(id) == int(costs[1]), "and the next one is priced at the second step's cost")
	while Perks.can_buy(id):
		Perks.buy(id)
	var left := GameState.scrap
	check(Perks.owned(id) == costs.size() and Perks.next_cost(id) == -1 and not Perks.buy(id)
			and GameState.scrap == left,
		"every step bought, there is no next one to buy (%d of %d)" % [Perks.owned(id), costs.size()])
	check(not Perks.can_buy("NO_SUCH_PERK") and not Perks.buy("NO_SUCH_PERK"),
		"and a perk the game does not have is never bought")
	var per := float(Perks.get_def(id)["per_step"])
	check(is_equal_approx(GameState.boost("max_health"), per * costs.size()),
		"what it adds is its step's worth for every step (%.0f)" % GameState.boost("max_health"))

## The player's own numbers take what is bought — when the body comes up, and
## again the moment a step is bought with it standing there.
func _the_player() -> void:
	var p := Player.new()
	add_child(p)
	await frames(2)
	p.setup_kit(["SWORD"], [Weapons.make_board("SWORD")])
	check(is_equal_approx(p.max_health, GameState.max_health()) and is_equal_approx(p.health, p.max_health),
		"the body comes up with the health the perks add to, and full (%.0f)" % p.max_health)

	var stamina_was := p.max_stamina
	var mana_was := p.max_mana
	Perks.buy("ENDURANCE")
	Perks.buy("FOCUS")
	check(is_equal_approx(p.max_stamina, stamina_was + float(Perks.get_def("ENDURANCE")["per_step"]))
			and is_equal_approx(p.stamina, p.max_stamina),
		"a step of ENDURANCE bought raises the bar of the body standing there, and fills it (%.0f)" % p.max_stamina)
	check(is_equal_approx(p.max_mana, mana_was + float(Perks.get_def("FOCUS")["per_step"]))
			and is_equal_approx(p.mana, p.max_mana),
		"and one of FOCUS its mana (%.0f)" % p.max_mana)

	Perks.buy("SWIFTNESS")
	check(is_equal_approx(p._pace_mul, 1.0 + float(Perks.get_def("SWIFTNESS")["per_step"])),
		"SWIFTNESS quickens its run (x%.2f)" % p._pace_mul)
	var wait_was := p.runner.cooldown_mul
	Perks.buy("QUICK_HANDS")
	check(p.runner.cooldown_mul < wait_was
			and is_equal_approx(p.runner.cooldown_mul,
				Player.CAST_COOLDOWN_MUL * (1.0 - float(Perks.get_def("QUICK_HANDS")["per_step"]))),
		"and QUICK HANDS shortens the wait between its casts (%.2f from %.2f)" % [p.runner.cooldown_mul, wait_was])

	# A hold, a tenth of a second of it, on a graph free to be charged.
	var built := func() -> float:
		p.charge = 0.0
		p.mana = p.max_mana
		p._update_charge(0.1, true)
		return p.charge
	var slow: float = built.call()
	Perks.buy("QUICK_CHARGE")
	var fast: float = built.call()
	var quicker := 1.0 + float(Perks.get_def("QUICK_CHARGE")["per_step"])
	check(slow > 0.0 and is_equal_approx(fast, slow * quicker),
		"QUICK CHARGE builds a hold that much faster (%.2f from %.2f)" % [fast, slow])
	check(is_equal_approx(p.max_mana - p.mana, fast * Player.MANA_PER_TTL),
		"and spends the same mana for every bit of it")

	var cap_was := p.charge_cap()
	Perks.buy("DEEP_CHARGE")
	check(is_equal_approx(p.charge_cap(), cap_was + float(Perks.get_def("DEEP_CHARGE")["per_step"])),
		"DEEP CHARGE lets a hold go further (%.0f from %.0f)" % [p.charge_cap(), cap_was])
	p.charge = 0.0
	p.mana = p.max_mana
	for i in 200:
		p._update_charge(0.05, true)
	check(is_equal_approx(p.charge, p.charge_cap()) and p.charge > cap_was
			and is_equal_approx(p.charge_ratio(), 1.0),
		"and a long hold fills up to it, past where it used to stop (%.1f)" % p.charge)
	p.queue_free()
	await frames(1)

## Gold found in a raid comes to what SCAVENGER adds to it.
func _gold() -> void:
	check(GameState.gold_found(100) == 100, "with no SCAVENGER, gold found is what it was")
	Perks.buy("SCAVENGER")
	var more := float(Perks.get_def("SCAVENGER")["per_step"])
	check(GameState.gold_found(100) == roundi(100.0 * (1.0 + more)),
		"with a step of it, that much more (%d of 100)" % GameState.gold_found(100))

## On the bench perks are toggled, not bought: every step of one or none, for
## nothing, and what the profile bought is left as it was — and counts again
## once the bench is left.
func _toggled() -> void:
	var p := Player.new()
	add_child(p)
	await frames(2)
	var bought := GameState.perks.duplicate()
	var gold := GameState.scrap
	var health_bought := p.max_health
	Perks.set_trial(true)
	var nothing := true
	for stat in STATS:
		nothing = nothing and is_zero_approx(GameState.boost(stat))
	check(nothing and Perks.active("TOUGHNESS") == 0,
		"on the bench every perk starts off, whatever the profile bought")
	check(p.max_health < health_bought, "and the body there goes without them (%.0f)" % p.max_health)
	check(not Perks.can_buy("SWIFTNESS") and not Perks.buy("SWIFTNESS"), "nothing is bought there")

	check(Perks.toggle("DEEP_CHARGE") and Perks.is_on("DEEP_CHARGE")
			and Perks.active("DEEP_CHARGE") == Perks.steps("DEEP_CHARGE"),
		"a press turns a perk on, every step of it")
	var deep := float(Perks.get_def("DEEP_CHARGE")["per_step"]) * Perks.steps("DEEP_CHARGE")
	check(is_equal_approx(GameState.boost("max_charge"), deep)
			and is_equal_approx(p.charge_cap(), Player.MAX_CHARGE_TTL + deep),
		"and the body standing there has all of it at once (%.0f)" % p.charge_cap())
	check(GameState.scrap == gold and GameState.perks == bought,
		"for nothing: no gold goes, and the profile's steps are as they were")
	check(Perks.toggle("DEEP_CHARGE") and not Perks.is_on("DEEP_CHARGE")
			and is_zero_approx(GameState.boost("max_charge")),
		"and another turns it off again")

	Perks.toggle("TOUGHNESS")
	Perks.set_trial(false)
	check(Perks.active("TOUGHNESS") == Perks.owned("TOUGHNESS")
			and is_equal_approx(p.max_health, health_bought),
		"off the bench the profile's own steps count again (%.0f)" % p.max_health)
	check(not Perks.toggle("TOUGHNESS"), "and nothing is toggled there")
	Perks.set_trial(true)
	check(Perks.is_on("TOUGHNESS"), "back on the bench, it is as it was left")
	Perks.toggle("TOUGHNESS")
	Perks.set_trial(false)
	p.queue_free()
	await frames(1)

## What is bought is the profile's: read back with it, and gone with it.
func _kept() -> void:
	var bought := GameState.perks.duplicate()
	GameState.load_slot(GameState.slot)
	check(GameState.perks == bought and not bought.is_empty(),
		"the steps bought come back with the profile (%s)" % str(GameState.perks))
	GameState.reset_profile()
	var nothing := true
	for stat in STATS:
		nothing = nothing and is_zero_approx(GameState.boost(stat))
	check(GameState.perks.is_empty() and nothing, "and a profile started over has bought nothing")
