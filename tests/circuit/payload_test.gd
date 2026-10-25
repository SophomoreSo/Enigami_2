extends Node
## The payload's fields are its schema (`Payload.fields()`, read off the
## declarations), and three things have to keep up with them: `clone`, which
## copies every one by hand; the words the workbench preview says of each
## (`Attacks.WORDS`, or `WORDLESS` for one said elsewhere or not at all); and
## the runner's list of the fields no effects row may touch (`Components.KEPT`).
## A field added to the payload and forgotten in any of them fails here, rather
## than being quietly lost at the first hop of a flow or left unsaid.
##
## Headless; no renderer needed.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[PAYLOAD] PASS ", what)
	else:
		fails += 1
		push_error("PAYLOAD FAIL: " + what)

func _ready() -> void:
	_the_fields()
	_clone()
	_words()
	_kept()
	print("[PAYLOAD] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Something distinct from the default for a field holding `now`, salted with
## `i` so no two fields share one.
static func _other(now: Variant, i: int) -> Variant:
	match typeof(now):
		TYPE_FLOAT:
			return 3.25 + float(i)
		TYPE_INT:
			return 7 + i
		TYPE_BOOL:
			return not now
		TYPE_STRING:
			return "X%d" % i
		TYPE_VECTOR2:
			return Vector2(i, -i)
		TYPE_ARRAY:
			return ["A%d" % i, "B%d" % i]
		TYPE_DICTIONARY:
			return {"k%d" % i: i}
		TYPE_OBJECT, TYPE_NIL:
			var inner := Payload.new()
			inner.damage = 100.0 + float(i)
			return inner
	return null

func _the_fields() -> void:
	var names := Payload.fields()
	check(names.size() >= 30 and names.has(&"damage") and names.has(&"on_parry") and names.has(&"spread"),
		"the schema is read off the declarations, %d fields from damage to the triggers" % names.size())
	# Every declared var, and nothing else: a constant or a static is no field.
	check(not names.has(&"BASE_RANGE") and not names.has(&"_fields") and not names.has(&"SHARED"),
		"and holds only the fields a flow carries")

## Every field set to something else, cloned, and every one found in the copy:
## values alike, lists and tables copied rather than shared, `spread` a copy,
## the triggers the same objects.
func _clone() -> void:
	var a := Payload.new()
	var i := 0
	for f in Payload.fields():
		var other = _other(a.get(f), i)
		if other == null:
			check(false, "%s holds something this test cannot make another of (%s)" % [f, type_string(typeof(a.get(f)))])
			continue
		a.set(f, other)
		i += 1
	var b := a.clone()
	var lost: Array = []
	var shared: Array = []
	for f in Payload.fields():
		var mine = a.get(f)
		var theirs = b.get(f)
		if mine is Payload:
			if Payload.SHARED.has(f):
				if theirs != mine:
					lost.append("%s (a trigger, not shared)" % f)
			elif theirs == mine:
				shared.append(f)
			elif theirs == null or not is_equal_approx((theirs as Payload).damage, (mine as Payload).damage):
				lost.append(f)
			continue
		if mine != theirs:
			lost.append(f)
		elif (mine is Array or mine is Dictionary) and is_same(mine, theirs):
			shared.append(f)
	check(lost.is_empty(), "clone copies every field (lost: %s)" % str(lost))
	check(shared.is_empty(), "and copies a list, a table and a NEAR's spread rather than sharing them (shared: %s)" % str(shared))
	# Changing the copy's list leaves the original's alone.
	b.elements.append("Z")
	check(not a.elements.has("Z"), "so a copy's elements are its own")

## Every field has a word in the preview or is on the list of those said
## elsewhere or not at all, and none is on both.
func _words() -> void:
	var worded: Array = []
	for row: Array in Attacks.WORDS:
		worded.append(row[0])
	var unsaid: Array = []
	var twice: Array = []
	var stray: Array = []
	for f in Payload.fields():
		var said := worded.has(f)
		var listed: bool = Attacks.WORDLESS.has(f)
		if not said and not listed:
			unsaid.append(f)
		if said and listed:
			twice.append(f)
	for f in worded + Array(Attacks.WORDLESS):
		if not Payload.fields().has(f):
			stray.append(f)
	check(unsaid.is_empty(), "every field has a word in the preview, or is listed as said elsewhere (unsaid: %s)" % str(unsaid))
	check(twice.is_empty() and stray.is_empty(),
		"and none is on both lists or names a field there is not (twice: %s, stray: %s)" % [str(twice), str(stray)])
	# Each word is there to say, in the language being played.
	var wordless_keys: Array = []
	for f in worded:
		var key := "editor.payload.%s" % f
		if Loc.t(key) == key:
			wordless_keys.append(f)
	check(wordless_keys.is_empty(), "and each has its line in localization (missing: %s)" % str(wordless_keys))

## What the runner keeps for itself names fields there are.
func _kept() -> void:
	var gone: Array = []
	for f in Components.KEPT:
		if not Payload.fields().has(StringName(f)):
			gone.append(f)
	check(gone.is_empty(), "every field the runner keeps for itself is a field (gone: %s)" % str(gone))
