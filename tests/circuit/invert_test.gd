extends Node
## INVERT: the part that turns the part straight before it inside out, by that
## part's rows of `inversions`. DAMAGE's damage becomes a heal of the enemy
## struck, a burn, a chill or a stun a cleanse of it, KNOCKBACK's throw a pull
## and PULL's pull a throw, and SIZE, SPEED and RANGE make the
## attack as much less as they would have made it more. A part with no opposite
## is left as it was.
##
## Driven through the runner on real boards, so what is checked is what a cast
## really carries, and that only the one part before INVERT is turned round:
## what it took back is exactly what that part added, nothing more. What the
## new fields do once the hit lands is invert_hit_test's. And what the schema
## promises to refuse is tried against a scratch copy of it.
##
## No renderer needed: nothing here draws. The refusals print an `SQL error`
## line each from the extension, which is the point of them.

const SRC := "res://data/db"
const SCRATCH := "user://invert_test.db"

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[INVERT] PASS ", what)
	else:
		fails += 1
		push_error("INVERT FAIL: " + what)

func _ready() -> void:
	_rows()
	_flips()
	_nothing_to_flip()
	_branch()
	_refusals()
	print("[INVERT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- helpers ----------------------------------------------------------------

## A board with `ids` in a line — the first on the root, the way a weapon's own
## part is — and the payload a cast of it fires. The board is as long as the
## line, so its last part stands against the way out.
func payload_of(ids: Array) -> Payload:
	var b := SkillBoard.new(ids.size(), 5, "test")
	b.set_root(String(ids[0]))
	var x := 1
	for id in ids.slice(1):
		b.place(String(id), Vector2i(x, 2), 0)
		x += 1
	return _fired(b)

func _run(b: SkillBoard) -> Dictionary:
	var sim := SkillRunner.new(b)
	sim.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	return sim.simulate()

func _fired(b: SkillBoard) -> Payload:
	var outs: Array = _run(b)["outputs"]
	return outs[0] if outs.size() > 0 else null

## The fields `a` and `b` disagree on — every field a part could touch, but
## heat, which every part adds to, the count of the parts it has been through,
## and the trigger payloads, which are not the flow's own.
func differ(a: Payload, b: Payload) -> Array:
	var out: Array = []
	if a == null or b == null:
		return ["(no payload)"]
	for prop in a.get_property_list():
		if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var name := String(prop["name"])
		if name in ["heat", "stacks", "on_hit", "on_kill", "on_parry"]:
			continue
		if str(a.get(name)) != str(b.get(name)):
			out.append(name)
	return out

## The value of the row among `rows` doing `op` to `field`, or -1.
func _value(rows: Array, op: String, field: StringName) -> float:
	for e in rows:
		if String(e["op"]) == op and e["field"] == field:
			return float(e["value"])
	return -1.0

## Within a thousandth of `want`: the opposites are written to four places.
func _near(got: float, want: float) -> bool:
	return absf(got - want) <= absf(want) * 0.001

## --- the rows -----------------------------------------------------------------

func _rows() -> void:
	check(Db.has_table("inversions"), "there is a table of opposites")
	var faults := Components.faults()
	check(faults.is_empty(), "every row fits what reads it%s" % ("" if faults.is_empty() else " — " + "; ".join(faults)))
	var turns := Components.effects_of("INVERT")
	check(turns.size() == 1 and String(turns[0]["op"]) == "invert" and turns[0]["field"] == &"",
		"INVERT's one effect is to invert, naming no field (%s)" % str(turns))
	check(Components.inversions_of("INVERT").is_empty() and not Components.acts_on_entry("INVERT"),
		"and it has no opposite of its own, and acts on nothing as it is entered")
	var stun := Components.effects_of("STUN")
	check(stun.size() == 1 and stun[0]["field"] == &"stun" and float(stun[0]["value"]) > 0.0,
		"STUN stuns for the seconds its row gives (%s)" % str(stun))
	for id in ["INVERT", "STUN"]:
		check(id in Components.loot_pool(), "%s drops, sells and is spent like any other part" % id)
	var turned: Array = []
	var hollow: Array = []
	for id in Components.ids():
		if Components.inversions_of(id).is_empty():
			continue
		turned.append(id)
		if Components.effects_of(id).is_empty():
			hollow.append(id)
	check(hollow.is_empty(), "every part with an opposite does something for it to turn round (%s)" % str(hollow))
	for id in ["DAMAGE", "FIRE", "ICE", "STUN", "KNOCKBACK", "PULL", "SIZE", "SPEED", "RANGE"]:
		check(id in turned, "%s has an opposite" % id)
	# Each number is its effect's turned round.
	var heal := _value(Components.inversions_of("DAMAGE"), "add", &"heal")
	check(heal > 0.0 and is_equal_approx(heal, _value(Components.effects_of("DAMAGE"), "add", &"damage")),
		"DAMAGE's heal is as much as it adds to the damage (%.1f)" % heal)
	var off: Array = []
	for id in turned:
		for e in Components.inversions_of(id):
			if String(e["op"]) != "multiply":
				continue
			var by := _value(Components.effects_of(id), "multiply", e["field"])
			if absf(float(e["value"]) * by - 1.0) > 0.001:
				off.append("%s %s x%s against x%s" % [id, e["field"], str(e["value"]), str(by)])
	check(off.is_empty(), "every multiply turned round is one over its effect's (%s)" % ", ".join(off))

## --- what INVERT makes of the part before it -----------------------------------

func _flips() -> void:
	var plain := payload_of(["SLASH"])
	check(plain != null and plain.heal == 0.0 and not plain.cleanse and plain.stun == 0.0
			and not plain.hook,
		"a board without them carries none of them")
	if plain == null:
		return

	var hurt := payload_of(["SLASH", "DAMAGE"])
	var heal := payload_of(["SLASH", "DAMAGE", "INVERT"])
	check(hurt.damage > plain.damage, "(DAMAGE adds to the damage: %.0f over %.0f)" % [hurt.damage, plain.damage])
	check(is_equal_approx(heal.damage, plain.damage)
			and is_equal_approx(heal.heal, _value(Components.effects_of("DAMAGE"), "add", &"damage")),
		"DAMAGE then INVERT: what DAMAGE did comes off (%.0f) and what it adds heals the enemy struck instead (%.0f)"
			% [heal.damage, heal.heal])
	check(heal.stack("DAMAGE") == 0, "and, turned round, it no longer counts as a DAMAGE stacked")
	check(differ(heal, plain) == ["heal"], "and nothing else about the attack is touched (%s)" % str(differ(heal, plain)))
	var after := payload_of(["SLASH", "DAMAGE", "INVERT", "DAMAGE"])
	check(is_equal_approx(after.damage, hurt.damage) and is_equal_approx(after.heal, heal.heal),
		"a part after INVERT does what it always does (%.0f damage, %.0f heal)" % [after.damage, after.heal])

	for id in ["FIRE", "ICE"]:
		var calm := payload_of(["SLASH", id, "INVERT"])
		check(calm.cleanse and not calm.elements.has(id) and differ(calm, plain) == ["cleanse"],
			"%s then INVERT: no %s, a cleanse instead (%s)" % [id, id.to_lower(), str(differ(calm, plain))])
	var stunning := payload_of(["SLASH", "STUN"])
	check(is_equal_approx(stunning.stun, _value(Components.effects_of("STUN"), "add", &"stun")),
		"STUN carries its seconds to the hit (%.1f)" % stunning.stun)
	var woken := payload_of(["SLASH", "STUN", "INVERT"])
	check(woken.stun == 0.0 and woken.cleanse and differ(woken, plain) == ["cleanse"],
		"STUN then INVERT: no stun, a cleanse instead (%s)" % str(differ(woken, plain)))
	var twice := payload_of(["SLASH", "FIRE", "FIRE", "INVERT"])
	check(Array(twice.elements) == ["FIRE"] and twice.cleanse,
		"FIRE, FIRE, INVERT: only the second is turned round, and it added nothing, so the burn stays (%s)"
			% str(twice.elements))
	var mixed := payload_of(["SLASH", "ICE", "FIRE", "INVERT"])
	check(Array(mixed.elements) == ["ICE"] and mixed.cleanse,
		"ICE, FIRE, INVERT: the FIRE goes and the ICE stays (%s)" % str(mixed.elements))

	var reel := payload_of(["SLASH", "KNOCKBACK", "INVERT"])
	check(reel.hook and not reel.knockback and differ(reel, plain) == ["hook"],
		"PUSH then INVERT: no throw, a pull instead (%s)" % str(differ(reel, plain)))
	var pulled := payload_of(["SLASH", "PULL"])
	check(pulled.hook == reel.hook and differ(pulled, plain) == ["hook"],
		"PULL is what an INVERT makes of PUSH (%s)" % str(differ(pulled, plain)))
	var thrown := payload_of(["SLASH", "PULL", "INVERT"])
	check(thrown.knockback and not thrown.hook and differ(thrown, plain) == ["knockback"],
		"PULL then INVERT: no pull, a throw instead (%s)" % str(differ(thrown, plain)))

	var grow := _value(Components.effects_of("SIZE"), "multiply", &"size")
	var small := payload_of(["SLASH", "SIZE", "INVERT"])
	check(_near(small.size, plain.size / grow) and differ(small, plain) == ["size"],
		"SIZE then INVERT: the attack is as much smaller as SIZE makes it bigger (%.3f)" % small.size)
	var quick := _value(Components.effects_of("SPEED"), "multiply", &"speed")
	var reach := _value(Components.effects_of("SPEED"), "multiply", &"range_px")
	var slow := payload_of(["SLASH", "SPEED", "INVERT"])
	check(_near(slow.speed, plain.speed / quick) and _near(slow.range_px, plain.range_px / reach)
			and differ(slow, plain) == ["speed", "range_px"],
		"SPEED then INVERT: slower and shorter by as much (%.3f, %.0f)" % [slow.speed, slow.range_px])
	var far := _value(Components.effects_of("RANGE"), "multiply", &"range_px")
	var short := payload_of(["SLASH", "RANGE", "INVERT"])
	check(_near(short.range_px, plain.range_px / far) and _near(short.lunge, plain.lunge / far)
			and differ(short, plain) == ["range_px", "lunge"],
		"RANGE then INVERT: shorter by as much, and the lunge with it (%.0f, %s)"
			% [short.range_px, str(differ(short, plain))])

## --- and where there is nothing to turn round ------------------------------------

func _nothing_to_flip() -> void:
	var plain := payload_of(["SLASH"])
	var first := payload_of(["SLASH", "INVERT"])
	check(differ(first, plain).is_empty(),
		"INVERT straight after the root does nothing: a form has no opposite (%s)" % str(differ(first, plain)))
	var hurt := payload_of(["SLASH", "DAMAGE"])
	var hit := payload_of(["SLASH", "DAMAGE", "ON_HIT", "INVERT"])
	check(differ(hit, hurt).is_empty(),
		"nor after ON HIT, though a DAMAGE stands before that: only the part straight before counts (%s)"
			% str(differ(hit, hurt)))
	var once := payload_of(["SLASH", "DAMAGE", "INVERT"])
	var again := payload_of(["SLASH", "DAMAGE", "INVERT", "INVERT"])
	check(differ(again, once).is_empty(), "nor after another INVERT, which has no opposite (%s)" % str(differ(again, once)))
	for id in ["PIERCE", "HOMING", "SHATTER", "MANA_DRAIN", "HEALTH_DRAIN", "WATER", "DUPLICATE"]:
		var with := payload_of(["SLASH", id])
		var turned := payload_of(["SLASH", id, "INVERT"])
		check(differ(turned, with).is_empty(), "nor after %s, which has none (%s)" % [id, str(differ(turned, with))])

## --- on a trigger's branch ---------------------------------------------------------

## ON HIT's branch is a flow of its own, and an INVERT on it turns round the
## part before it there just the same.
func _branch() -> void:
	# The cast runs on along the middle to the way out; the branch, a row
	# below, is turned up into the last of it to leave the same way.
	var b := SkillBoard.new(5, 5, "test")
	b.set_root("SLASH")
	b.place("ON_HIT", Vector2i(1, 2), 0)
	b.place("BRIDGE", Vector2i(2, 2), 0)
	b.place("BRIDGE", Vector2i(3, 2), 0)
	b.place("BRIDGE", Vector2i(4, 2), 0)
	b.place("PROJECTILE", Vector2i(1, 3), 0)
	b.place("DAMAGE", Vector2i(2, 3), 0)
	b.place("INVERT", Vector2i(3, 3), 0)
	b.place("BRIDGE", Vector2i(4, 3), 3)
	var run := _run(b)
	var outs: Array = run["outputs"]
	var follow = (run["triggers"] as Dictionary).get("ON_HIT", null)
	check(outs.size() == 1 and follow is Payload, "the cast fires, carrying its ON HIT branch (%s)" % str(run["triggers"]))
	if follow is Payload and outs.size() == 1:
		var main: Payload = outs[0]
		check((follow as Payload).form == "PROJECTILE" and is_equal_approx((follow as Payload).damage, main.damage)
				and is_equal_approx((follow as Payload).heal, _value(Components.inversions_of("DAMAGE"), "add", &"heal")),
			"and on it, DAMAGE then INVERT heals as it does on the main flow (%.0f damage, %.0f heal)"
				% [(follow as Payload).damage, (follow as Payload).heal])

## --- what the schema refuses -----------------------------------------------------
## The build runs with foreign keys on and these same constraints, so what is
## refused here is refused there.

func _refusals() -> void:
	var db = _scratch()
	if db == null:
		check(false, "a scratch copy of the schema can be made to try it against")
		return
	var cat := "INSERT INTO categories (id) VALUES ('stat')"
	var code := "INSERT INTO codes (code, id) VALUES (0, 'BOOST'), (1, 'TURN')"
	var parts := "INSERT INTO parts (id, name, category, heat, description) VALUES ('BOOST', 'BOOST', 'stat', 0.3, 'Adds.'), ('TURN', 'TURN', 'stat', 0.4, 'Turns.')"
	var effect := "INSERT INTO effects (part_id, position, field, op, value) VALUES ('BOOST', 0, 'damage', 'add', 8)"
	var turn := "INSERT INTO effects (part_id, position, field, op, value) VALUES ('TURN', 0, NULL, 'invert', NULL)"
	var opposite := "INSERT INTO inversions (part_id, position, field, op, value) VALUES ('BOOST', 0, 'heal', 'add', 8)"
	check(_accepted(db, [cat, code, parts, effect, turn, opposite]),
		"a part, its opposite, and a part that inverts are accepted (%s)" % db.error_message)
	check(not _accepted(db, [cat, code, parts, turn.replace("NULL, 'invert', NULL", "'damage', 'invert', NULL")]),
		"an invert that names a field is refused")
	check(not _accepted(db, [cat, code, parts, turn.replace("'invert', NULL", "'invert', 1")]),
		"an invert with an amount is refused")
	check(not _accepted(db, [cat, code, parts, opposite.replace("'heal', 'add'", "NULL, 'add'")]),
		"an opposite that changes no field is refused")
	for op in ["dilate", "guard", "invert"]:
		check(not _accepted(db, [cat, code, parts, opposite.replace("'add', 8", "'%s', 8" % op)]),
			"an opposite that does %s is refused: an opposite changes a field" % op)
	check(not _accepted(db, [cat, code, parts, opposite.replace("'add', 8", "'toggle', 8")]),
		"an opposite toggled with a value is refused")
	check(not _accepted(db, [cat, code, parts, opposite.replace("'BOOST', 0", "'NOWHERE', 0")]),
		"an opposite for a part that is not there is refused")
	db.close_db()
	DirAccess.remove_absolute(SCRATCH)

## A fresh database with the real schema in it, foreign keys on, or null.
func _scratch():
	if not ClassDB.class_exists("SQLite"):
		return null
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)
	var db = ClassDB.instantiate("SQLite")
	db.path = SCRATCH
	db.foreign_keys = true
	db.verbosity_level = 0
	if not db.open_db():
		push_error("INVERT: could not open %s: %s" % [SCRATCH, db.error_message])
		return null
	var schema := FileAccess.get_file_as_string(SRC.path_join("schema.sql"))
	if schema == "" or not db.query(schema):
		push_error("INVERT: the schema did not run: %s" % db.error_message)
		return null
	return db

## Whether `statements` go in and commit, the way build.sh commits them. What
## went in is taken out again afterwards, so every try starts from nothing.
func _accepted(db, statements: Array) -> bool:
	var ok: bool = db.query("BEGIN")
	for s in statements:
		ok = ok and db.query(s)
	ok = ok and db.query("COMMIT")
	if not ok:
		db.query("ROLLBACK")
		return false
	db.query("DELETE FROM parts")
	db.query("DELETE FROM codes")
	db.query("DELETE FROM categories")
	return true
