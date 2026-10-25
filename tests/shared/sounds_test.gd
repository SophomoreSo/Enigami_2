extends Node
## The sound bank as the content database lists it (`sounds`): a row a sound,
## each with a path under res://audio/sfx/, a prompt, and a flag that is Y or
## N; every sound the bank knows is a row, and every sound a line of dialogue
## names is one of them; nothing plays but a sound flagged in use with a file
## at its path, so one flagged with no file there is silent, and known.
## Headless.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SOUNDS] PASS ", what)
	else:
		fails += 1
		push_error("SOUNDS FAIL: " + what)

func _ready() -> void:
	check(Db.available() and Db.has_table("sounds"), "there is a table of sounds")
	check(Db.meta("schema_version") == str(Db.SCHEMA_VERSION),
		"the database is at the schema the code reads (file says %s, code says %d)"
			% [Db.meta("schema_version"), Db.SCHEMA_VERSION])
	var rows := Db.rows("SELECT * FROM sounds ORDER BY id")
	var listed := {}
	var odd: Array = []
	for row in rows:
		var id := String(row["id"])
		listed[id] = true
		if not Audio.has(id):
			odd.append("%s: the bank does not know it" % id)
		if String(row["path"]) != "res://audio/sfx/%s.wav" % id:
			odd.append("%s: path %s" % [id, row["path"]])
		if String(row["description"]).strip_edges().length() < 20:
			odd.append("%s: no prompt to speak of" % id)
		if not String(row["use_flag"]) in ["Y", "N"]:
			odd.append("%s: flag %s" % [id, row["use_flag"]])
	check(not rows.is_empty() and odd.is_empty(),
		"every row is a sound the bank knows, with its path under audio/sfx, a prompt and a flag (%s)" % str(odd))
	var unlisted: Array = []
	for id in Audio._known.keys():
		if not listed.has(id):
			unlisted.append(id)
	check(unlisted.is_empty(), "and every sound the bank knows is a row (%s)" % str(unlisted))
	var named: Array = []
	for t in ["nodes", "rules"]:
		for row in Db.rows("SELECT DISTINCT sfx FROM %s WHERE sfx IS NOT NULL" % t):
			if not listed.has(String(row["sfx"])):
				named.append(String(row["sfx"]))
	check(named.is_empty(), "every sound a line names is in the bank (%s)" % str(named))
	# Only a sound in use with a file at its path plays; one flagged with no
	# file is silent, and known.
	var flagged := 0
	var playing := 0
	for row in rows:
		var id := String(row["id"])
		var on := String(row["use_flag"]) == "Y"
		var there := ResourceLoader.exists(String(row["path"]))
		if on:
			flagged += 1
		if Audio.plays(id):
			playing += 1
		if Audio.plays(id) != (on and there):
			odd.append("%s plays %s, flagged %s, file %s" % [id, Audio.plays(id), on, there])
		if on and not there:
			check(Audio.has(id) and not Audio.plays(id), "%s is flagged in use with no file at its path: silent, and known" % id)
	check(odd.is_empty(), "a sound plays when, and only when, it is in use with a file at its path (%s)" % str(odd))
	print("[SOUNDS] %d of %d flagged in use, %d playing" % [flagged, rows.size(), playing])
	print("[SOUNDS] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
