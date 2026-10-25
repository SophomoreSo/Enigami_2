extends Node2D
## Free talk: every line a rule that an event gets when the facts are right.
## Of the rules an event could get, the one with the most criteria that all
## hold is said, a tie goes to the one written first, and a `once` rule is
## spent once it has been said. A line counts, and makes its changes, only once
## it is all the way out, which is what makes a conversation walked out on pick
## up where it was cut off — the way the architect does in the video this is
## after. Nothing holds the player, lines move on by themselves, and the
## moments the game announces are events a free talker in earshot answers,
## counted once however many hear them. What is remembered is kept with the
## profile or for a visit, and what the game counts is read off the profile.
##
## No renderer needed: nothing here draws.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[FREE] PASS ", what)
	else:
		fails += 1
		push_error("FREE FAIL: " + what)

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## A press the way a player makes one: a synthetic press only reads as
## just-pressed on the physics frame after it.
func press(action: String = "interact") -> void:
	Input.action_press(action)
	await phys(2)
	Input.action_release(action)
	await phys(1)

## A real dash: the key, and the dash it starts run out.
func dash(p: Player) -> void:
	await until(func() -> bool: return p.can_dash(), 300)
	await press("dash")
	await until(func() -> bool: return not p.is_dashing(), 200)

## Waits, a physics frame at a time, until `ok` holds or `most` frames pass.
func until(ok: Callable, most: int = 900) -> bool:
	var n := 0
	while not ok.call() and n < most:
		await get_tree().physics_frame
		n += 1
	return ok.call()

## A rule as `Dialogue` reads one, quick to say: all its letters out at once
## and gone the moment they are.
func rule(id: String, listens: String, extra: Dictionary = {}) -> Dictionary:
	var r := {"id": id, "text": "Line %s." % id, "speed": 100000, "hold": 0.0,
		"criteria": [], "changes": []}
	if listens != "":
		r["listens"] = listens
	r.merge(extra, true)
	return r

func crit(fact: String, op: String, value: int) -> Dictionary:
	return {"fact": fact, "op": op, "value": value}

## A free talker over rules written here rather than in the database.
func talker(rules: Array) -> FreeTalk:
	var by_id := {}
	for r in rules:
		by_id[r["id"]] = r
	return FreeTalk.new("TEST", {"id": "TEST", "rules": by_id})

## Steps `t` until it is quiet, a sixtieth of a second at a time, and lists
## what it said on the way.
func run_out(t: FreeTalk, most: int = 600) -> Array:
	var said: Array = []
	var n := 0
	while t.is_talking() and n < most:
		if said.is_empty() or said[-1] != t.line_id:
			said.append(t.line_id)
		t.step(1.0 / 60.0)
		n += 1
	return said

func _ready() -> void:
	GameState.reset_profile()
	Arena.register(self)
	_tables()
	_facts()
	_picking()
	_running()
	_the_ear()
	await _in_the_world()
	print("[FREE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the tables ------------------------------------------------------------------
func _tables() -> void:
	for table in ["facts", "events", "rules", "criteria", "changes"]:
		check(Db.has_table(table), "there is a %s table" % table)

	# What the game counts, the profile has to be able to say.
	var told := GameState.facts()
	var game: Array = []
	for r in Db.rows("SELECT id FROM facts WHERE scope = 'game' ORDER BY id"):
		game.append(String(r["id"]))
	var unknown := game.filter(func(id: String) -> bool: return not told.has(id))
	check(not game.is_empty() and unknown.is_empty(),
		"every fact the schema says the game counts is one GameState.facts() gives (not: %s)" % str(unknown))

	# Every moment the schema names is a cue feature/ sends, carrying what the
	# event asks of it — or the event would simply never happen.
	var sent := _cue_lines()
	var missing: Array = []
	for id in FreeTalk.events():
		var e: Dictionary = FreeTalk.events()[id]
		var cue := String(e["cue"])
		if cue == "":
			continue
		var carries := false
		for line in sent.get(cue, []):
			var all := true
			for key in e["match"]:
				var want = e["match"][key]
				all = all and String(line).contains('"%s"' % key)
				if want is String:
					all = all and String(line).contains('"%s"' % want)
			carries = carries or all
		if not carries:
			missing.append("%s (%s %s)" % [id, cue, JSON.stringify(e["match"])])
	check(missing.is_empty(), "every event on a cue is a cue feature/ sends, carrying what it matches (not: %s)"
		% ", ".join(missing))
	for id in [FreeTalk.TALK, FreeTalk.NEAR, FreeTalk.LEAVE]:
		check(FreeTalk.events().has(id), "the schema declares %s, which the game raises by name" % id)

	var apprentice := Dialogue.character("APPRENTICE")
	check(not apprentice.has("start") and not (apprentice.get("rules", {}) as Dictionary).is_empty(),
		"the apprentice has no conversation in the box, and talks free (%d rules)" % (apprentice.get("rules", {}) as Dictionary).size())
	check(Dialogue.problems("APPRENTICE").is_empty(),
		"and their rules read clean %s" % str(Dialogue.problems("APPRENTICE")))
	var hello: Dictionary = apprentice["rules"].get("hello", {})
	check(String(hello.get("voice", "")) == "mid" and int(hello.get("speed", 0)) == 45
			and String(hello.get("speaker", "")) == "npc",
		"a rule takes the character's line_ defaults the way a line in the box does (%s)" % str(hello))
	var reply: Dictionary = apprentice["rules"].get("intro_reply", {})
	check(String(reply.get("speaker", "")) == "player" and String(reply.get("voice", "")) == "high",
		"and keeps what it sets itself")
	var parry: Dictionary = apprentice["rules"].get("teach_parry", {})
	check((parry.get("criteria", []) as Array).size() == 3 and String(parry["criteria"][2].get("fact", "")) == "parry",
		"a rule carries its criteria, in the order they were written")
	check(Facts.scope("APPRENTICE.intro") == "save" and Facts.scope("dash") == "save"
			and Facts.scope("apprentice_waved") == "visit" and Facts.scope("raids") == "game",
		"every rule and every event is a fact of its own, kept with the profile")

	# The checker, in front of free talk written wrong.
	var broken := {"id": "X", "rules": {
		"a": rule("a", "talk", {"next": "gone"}),
		"b": rule("b", ""),
		"c": rule("c", "talk", {"triggers": "nobody_answers"}),
		"d": rule("d", "talk", {"text": ""}),
	}}
	var found := Dialogue.problems_in(broken)
	var has := func(want: String) -> bool:
		return found.any(func(p) -> bool: return String(p).contains(want))
	check(has.call("a -> gone"), "a next that names no rule is caught")
	check(has.call("b answers nothing"), "a rule nothing reaches is caught")
	check(has.call("raises nobody_answers"), "an event raised that none of theirs answers is caught")
	check(has.call("d has no text"), "a rule with nothing to say is caught")
	check(Dialogue.problems_in({"id": "X", "rules": {"a": rule("a", "talk")}}).is_empty(),
		"a character with free talk and no box has nothing wrong with them")

## Every `Cues.at(&"…"` and `Cues.emit_cue(&"…"` line in feature/, by cue.
func _cue_lines() -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string('Cues\\.(?:at|emit_cue)\\(&"([a-z_]+)"')
	var dirs: Array = ["res://feature"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if file.get_extension() != "gd":
				continue
			for line in FileAccess.get_file_as_string(dir.path_join(file)).split("\n"):
				var m := re.search(line)
				if m != null:
					if not out.has(m.get_string(1)):
						out[m.get_string(1)] = []
					out[m.get_string(1)].append(line)
	return out

## --- what is known ------------------------------------------------------------------
func _facts() -> void:
	check(Facts.value("apprentice_taught") == 0, "a fact nobody has set is 0")
	Facts.put("apprentice_taught", 1)
	check(Facts.value("apprentice_taught") == 1 and int(GameState.memory.get("apprentice_taught", 0)) == 1,
		"a save fact is kept in the profile's memory")
	GameState.save_game()
	GameState.memory = {}
	GameState.load_game()
	check(Facts.value("apprentice_taught") == 1, "and comes back with the profile")
	Facts.put("apprentice_taught", 0)

	Facts.put("apprentice_waved", 1)
	check(Facts.value("apprentice_waved") == 1 and not GameState.memory.has("apprentice_waved"),
		"a visit fact is kept, and not with the profile")
	var elsewhere := Node.new()
	add_child(elsewhere)
	Arena.register(elsewhere)
	check(Facts.value("apprentice_waved") == 0, "and is forgotten in the next world the player is in")
	Arena.register(self)
	elsewhere.queue_free()

	GameState.records["raids"] = 3
	check(Facts.value("raids") == 3, "a game fact is read off the profile")
	GameState.lost_kit = {"seed": 1, "room": [0, 0], "pos": [0, 0]}
	check(Facts.value("kit_waiting") == 1, "kit_waiting is whether a kit is lying in a raid")
	GameState.lost_kit = {}
	check(Facts.value("kit_waiting") == 0, "and goes back to 0 once it is not")
	Facts.put("raids", 99)
	check(Facts.value("raids") == 3, "and a line cannot change what the game counts")
	GameState.records["raids"] = 0

	Facts.put("test_n", 4)
	var ops := {"=": [4, 5], "<>": [5, 4], "<": [5, 4], "<=": [4, 3], ">": [3, 4], ">=": [4, 5]}
	var right := true
	for op in ops:
		right = right and Facts.hold([crit("test_n", op, ops[op][0])]) and not Facts.hold([crit("test_n", op, ops[op][1])])
	check(right, "every comparison a criterion can make means what it says")
	check(Facts.hold([]), "and no criteria at all always hold")
	check(not Facts.hold([crit("test_n", ">=", 1), crit("test_n", "=", 0)]), "criteria hold only all together")
	Facts.change([{"fact": "test_n", "op": "add", "value": -1}, {"fact": "test_m", "op": "set", "value": 7}])
	check(Facts.value("test_n") == 3 and Facts.value("test_m") == 7, "a change adds, or sets")

	# A slot nobody has started is not written for a line said in the sandbox.
	var path := GameState.slot_path(GameState.slot)
	GameState.delete_slot(GameState.slot)
	Facts.keep()
	check(not FileAccess.file_exists(path), "memory is not written into a slot that was never started")
	GameState.reset_profile()
	Facts.keep()
	check(FileAccess.file_exists(path), "and is into one that was")

## --- which rule an event gets ---------------------------------------------------
func _picking() -> void:
	var t := talker([
		rule("plain", "poke"),
		rule("one", "poke", {"criteria": [crit("test_x", ">=", 1)]}),
		rule("two", "poke", {"criteria": [crit("test_x", ">=", 1), crit("test_y", "=", 0)]}),
		rule("tie_a", "poke", {"criteria": [crit("test_z", "=", 0)]}),
		rule("tie_b", "poke", {"criteria": [crit("test_z", "=", 0)]}),
		rule("spent", "prod", {"once": 1}),
		rule("again", "prod"),
	])
	Facts.put("test_x", 1)
	Facts.put("test_y", 0)
	check(t.pick("poke") == "two", "the rule with the most criteria that all hold is the one (%s)" % t.pick("poke"))
	Facts.put("test_y", 1)
	check(t.pick("poke") == "one", "and when it does not hold, the next most specific (%s)" % t.pick("poke"))
	Facts.put("test_x", 0)
	check(t.pick("poke") == "tie_a", "a tie goes to the one written first (%s)" % t.pick("poke"))
	Facts.put("test_z", 1)
	check(t.pick("poke") == "plain", "and a rule asking nothing is the last resort (%s)" % t.pick("poke"))
	check(t.pick("nothing") == "" and not t.would_answer("nothing"), "an event nobody answers gets nothing")

	check(t.pick("prod") == "spent", "a once rule is in the running")
	t.answer("prod")
	run_out(t)
	check(Facts.value(Facts.line("TEST", "spent")) == 1, "a line said counts, under <CHARACTER>.<line>")
	check(t.pick("prod") == "again", "until it has been said once (%s)" % t.pick("prod"))

## --- saying it --------------------------------------------------------------------------
func _running() -> void:
	var t := talker([
		rule("open", "start", {"text": "Hello there.", "speed": 60, "hold": 0.5,
			"changes": [{"fact": "test_opened", "op": "add", "value": 1}], "next": "reply"}),
		rule("reply", "", {"speaker": "player", "triggers": "after"}),
		rule("close", "after"),
		rule("butt_in", "rude"),
	])
	var started: Array = []
	t.started.connect(func(id: String) -> void: started.append(id))
	check(t.hear("start") and t.line_id == "open" and started == ["open"], "an event that gets a rule starts it")
	check(Facts.value("start") == 1, "and counts itself: an event is a fact too")
	check(t.asked == false, "talk nobody asked for is not the player's to walk out on")
	t.step(0.1)
	check(t.visible_text() == "Hello " and not t.line_finished(), "the line types out (%s)" % t.visible_text())
	check(Facts.value("test_opened") == 0 and Facts.value(Facts.line("TEST", "open")) == 0,
		"and has changed nothing while it is still coming")
	t.cut()
	check(not t.is_talking() and Facts.value(Facts.line("TEST", "open")) == 0 and Facts.value("test_opened") == 0,
		"a line cut off was never said: it counts for nothing and changes nothing")

	t.hear("start")
	t.step(1.0)
	t.step(0.01)
	check(t.line_finished() and Facts.value(Facts.line("TEST", "open")) == 1 and Facts.value("test_opened") == 1,
		"all the way out, it has been said: it counts, and makes its changes")
	t.step(0.3)
	check(t.line_id == "open", "and it stays up to be read (%.2fs of %.2fs)" % [t.held, t.hold_time()])
	t.step(0.3)
	check(t.line_id == "reply" and t.speaker() == "player", "then its next follows, whoever says it")
	var said := run_out(t)
	check(said == ["reply", "close"] and Facts.value("after") == 1,
		"and a line that triggers an event is followed by whatever answers it (%s)" % str(said))

	t.hear("start")
	t.step(0.05)
	t.press()
	check(t.line_finished() and t.line_id == "open", "a press brings the rest of the line out at once")
	t.press()
	check(t.line_id == "reply", "and the next press moves on without waiting (%s)" % t.line_id)
	t.cut()

	t.hear("start")
	t.step(0.05)
	check(not t.hear("nothing") and t.line_id == "open", "an event nobody answers leaves the line alone")
	check(t.hear("rude") and t.line_id == "butt_in", "one that is answered cuts in")
	run_out(t)
	check(Facts.value(Facts.line("TEST", "open")) == 2, "and what it cut off went unsaid")

	# Left to itself — no `hold` of its own — a line stays up for its reading.
	var quick := talker([rule("en", "x", {"text": "Where were we? Right, footwork."}),
		rule("ko", "y", {"text": "어디까지 했더라? 맞다, 몸놀림."})])
	quick.rules["en"].erase("hold")
	quick.rules["ko"].erase("hold")
	quick.answer("x")
	var english := quick.hold_time()
	quick.answer("y")
	var korean := quick.hold_time()
	check(english >= FreeTalk.READ_LEAST and absf(english - korean) < 0.6,
		"a line stays up as long as it takes to read, Hangul counted by the syllable (%.2fs, %.2fs)" % [english, korean])
	quick.cut()

## --- the ear -------------------------------------------------------------------------
func _the_ear() -> void:
	var a := talker([rule("saw_it", "winded")])
	var b := talker([rule("saw_it", "winded"), rule("saw_kill", "kill"), rule("saw_blow", "strike")])
	var before := Facts.value("winded")
	Cues.emit_cue(&"refused", {"kind": "stamina"})
	check(Facts.value("winded") == before and not a.is_talking(),
		"a moment nobody is listening for is neither heard nor counted")
	a.listening = true
	b.listening = true
	Cues.emit_cue(&"refused", {"kind": "thrown"})
	check(not a.is_talking(), "a cue that does not carry what the event asks is not that event")
	Cues.emit_cue(&"refused", {"kind": "stamina"})
	check(Facts.value("winded") == before + 1, "a moment two talkers hear is counted once")
	check(a.line_id == "saw_it" and b.line_id == "saw_it", "and each of them answers it")
	a.cut()
	b.cut()
	var strikes := Facts.value("strike")
	Cues.emit_cue(&"hit", {"target_team": 1, "killed": true})
	check(b.line_id == "saw_kill" and Facts.value("strike") == strikes + 1,
		"a moment that is two events is both, and the one that asks more of it is answered (%s)" % b.line_id)
	b.cut()
	Cues.emit_cue(&"hit", {"target_team": 1, "killed": false})
	check(b.line_id == "saw_blow", "and the other when it does not match (%s)" % b.line_id)
	a.listening = false
	b.listening = false
	b.cut()

## --- a free talker in a room with the player ---------------------------------
func _in_the_world() -> void:
	GameState.reset_profile()
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = Vector2(1100, 380)
	add_child(p)
	var n := Npc.new()
	n.setup("APPRENTICE")
	n.collision_layer = 0
	n.collision_mask = 1
	n.position = Vector2(-300, 380)
	add_child(n)
	var sage := Npc.new()
	sage.setup("SAGE")
	check(n.mode == Npc.Mode.FREE and sage.mode == Npc.Mode.FREEZE,
		"someone with no conversation in the box talks free when pressed; the Tinker opens his box")
	sage.free()
	await phys(30)
	var talk := n.free_talk

	check(not n.in_earshot and not talk.is_talking() and not n.answers_press(),
		"from across the room: nothing heard, nothing to press")
	p.global_position = Vector2(-60, 380)
	await phys(2)
	check(n.in_earshot and talk.line_id == "hello" and not talk.asked,
		"coming into earshot, they call out, unasked (%s)" % talk.line_id)
	await until(func() -> bool: return not talk.is_talking())

	# Talk the player starts.
	p.global_position = Vector2(-260, 380)
	await phys(2)
	check(n.in_range and n.answers_press(), "up close, a press would get an answer")
	await press()
	check(talk.line_id == "intro" and talk.asked, "a press opens with the line for a first meeting (%s)" % talk.line_id)
	check(not p.controls_locked(), "and nothing holds the player while they talk")
	var stood := p.global_position.x
	Input.action_press("move_right")
	await phys(12)
	Input.action_release("move_right")
	check(p.global_position.x - stood > 20.0 and talk.is_talking(),
		"walking about mid-line is allowed, and they go on (moved %.0f)" % (p.global_position.x - stood))
	check(await until(func() -> bool: return talk.line_id == "intro_reply"), "a line moves on by itself once it is read")
	check(talk.speaker() == "player" and n.free_speaker() == p, "and the player can have a line of their own")
	check(await until(func() -> bool: return talk.line_id == "teach_dash"),
		"which leads into the first lesson (%s)" % talk.line_id)

	# Walking out on it.
	await phys(3)
	check(not talk.line_finished(), "caught halfway through the lesson")
	p.global_position = Vector2(400, 380)
	await phys(2)
	check(talk.line_id == "wait" and not talk.asked, "walking out of earshot cuts them off, and they say so (%s)" % talk.line_id)
	check(Facts.value(Facts.line("APPRENTICE", "teach_dash")) == 0, "and the lesson they were cut off in was never said")
	await until(func() -> bool: return not talk.is_talking())

	# Picking it back up.
	p.global_position = Vector2(-260, 380)
	await phys(2)
	check(talk.line_id == "back", "coming back, they notice (%s)" % talk.line_id)
	await until(func() -> bool: return not talk.is_talking())
	await press()
	check(talk.line_id == "resume", "and a press picks up where it was cut off, not at the start (%s)" % talk.line_id)
	check(await until(func() -> bool: return talk.line_id == "teach_dash"), "the same lesson again")
	await until(func() -> bool: return not talk.is_talking())
	check(Facts.value(Facts.line("APPRENTICE", "teach_dash")) == 1, "said all the way through this time")

	# What they see the player do: a real dash.
	var dashes := Facts.value("dash")
	await dash(p)
	check(Facts.value("dash") == dashes + 1, "a dash in front of them is noticed, once")
	check(talk.line_id == "nice_dash", "and praised (%s)" % talk.line_id)
	check(await until(func() -> bool: return talk.line_id == "teach_strike"), "and the lesson moves on to the next")
	await until(func() -> bool: return not talk.is_talking())

	# Out of earshot, nothing is noticed.
	p.global_position = Vector2(700, 380)
	await phys(2)
	var blows := Facts.value("strike")
	Cues.at(&"hit", p.global_position, {"target_team": 1, "killed": false})
	check(Facts.value("strike") == blows and not talk.is_talking(), "a blow struck out of earshot goes unseen")

	# A conversation in the box hushes them.
	p.global_position = Vector2(-260, 380)
	await phys(2)
	await until(func() -> bool: return not talk.is_talking())
	p.talk_locked = true
	await phys(1)
	Cues.at(&"hit", p.global_position, {"target_team": 1, "killed": false})
	check(Facts.value("strike") == blows and not talk.is_talking(),
		"while the player is held in a conversation in the box, free talk holds its tongue")
	p.talk_locked = false
	await phys(1)
	Cues.at(&"hit", p.global_position, {"target_team": 1, "killed": false})
	check(talk.line_id == "nice_strike", "and hears again the moment it is over (%s)" % talk.line_id)
	talk.cut()

	# Everything taught and said: nothing left to say, and so no prompt.
	Facts.put("apprentice_taught", 1)
	GameState.records["raids"] = 1
	await press()
	check(talk.line_id == "bye_for_now", "once it has all been taught, they say goodbye (%s)" % talk.line_id)
	await until(func() -> bool: return not talk.is_talking())
	check(not n.answers_press() and n.in_range, "and with nothing left to say, a press gets nothing: no prompt")
	var talks := Facts.value("talk")
	await press()
	check(not talk.is_talking() and Facts.value("talk") == talks, "and a press anyway is not even counted")

	# Two in reach: the nearer hears the press.
	var box := Npc.new()
	box.setup("SAGE")
	box.collision_layer = 0
	box.collision_mask = 1
	box.position = Vector2(-200, 380)
	add_child(box)
	Facts.put("apprentice_taught", 0)
	p.global_position = Vector2(-240, 380)
	await phys(3)
	await press()
	check(box.is_talking() and not talk.is_talking(), "two in reach: the nearer one hears the press")
	check(p.controls_locked() and not talk.listening, "and while the box holds the player, the other listens to nothing")
	box.end_conversation()
	box.queue_free()
	await phys(2)
	GameState.records["raids"] = 0
