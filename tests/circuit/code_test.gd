extends Node
## A board must survive being written down as a code and read back, and a code
## with a mistake in it must be refused rather than quietly building a different
## board. Also guards the two things that can never be reordered: the alphabet a
## code is spelled in, and the numbers parts are known by inside one — the
## `codes` table in the content database — and what a code or a save written
## while OUTPUT, WIRE, BEND and INPUT were parts, while a root could not move,
## while EXPLODE was called AREA, while SWIFT STRIKE+ or ZAP was a part of its
## own, or while SWIFT STRIKE and EXPLODE covered two cells, reads back as.

## Every number already given out, in order, as it was given. A code written
## down with any of these in it has to go on reading as the board it was, so
## this list only ever grows: a part added to the end of `codes` is added to the
## end of it too, and nothing in it ever changes.
const GIVEN := [
	"INPUT", "OUTPUT", "WIRE", "BEND",
	"PROJECTILE", "SLASH", "EXPLODE", "DASHSLASH", "DASHSLASH_AUTO",
	"FIRE", "ICE", "DAMAGE", "SIZE", "SPEED",
	"PIERCE", "DASH", "BLINK", "HOMING", "REVERSE",
	"SPLIT", "TEE", "DUPLICATE", "OVERCLOCK", "DELAY", "TIME_DILATION",
	"ON_HIT", "ON_KILL", "ON_PARRY",
	"SHATTER", "GRAVITY", "MANA_DRAIN",
	"RANGE",
	"KNOCKBACK",
	"ZAP",
	"INVERT", "STUN",
	"POSSESS",
	"AUTO_AIM",
	"HEALTH_DRAIN",
	"WATER",
	"BRIDGE",
	"HEADBUTT",
	"SUMMON_PROJECTILE", "SUMMON_PET",
	"ANTI_GRAVITY",
	"OFFENSIVE",
	"KAMIKAZE",
	"PULL",
	"NEAR",
	"HEAL",
	"BOUNCE", "RETURN", "CHAIN",
]

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[CODE] PASS ", what)
	else:
		fails += 1
		push_error("CODE FAIL: " + what)

## Two boards are the same board when the same parts face the same way in the
## same cells. Names and grids are deliberately not part of it: a code carries
## neither.
func same_parts(a: SkillBoard, b: SkillBoard) -> bool:
	if a.cells.size() != b.cells.size():
		return false
	for origin in a.cells:
		var here: Dictionary = a.cells[origin]
		var there: Dictionary = b.cells.get(origin, {})
		if there.is_empty() or String(there["id"]) != String(here["id"]) \
				or int(there["rot"]) != int(here["rot"]):
			return false
	return true

func round_trip(b: SkillBoard, what: String) -> String:
	var code := BoardCode.encode(b)
	var read := BoardCode.decode(code)
	if String(read["error"]) != "":
		check(false, "%s: encodes to something readable (%s)" % [what, read["error"]])
		return code
	var back: SkillBoard = read["board"]
	check(same_parts(b, back) and back.width == b.width and back.height == b.height
			and back.has_root() == b.has_root() and (not b.has_root() or back.root == b.root),
		"%s: %d parts on a %dx%d board come back the same, root and all, in %d characters" % [
			what, b.cells.size(), b.width, b.height, BoardCode.clean(code).length()])
	return code

func _ready() -> void:
	# --- the table of part numbers ------------------------------------------
	var numbered := Components.codes()
	var moved: Array = []
	for n in GIVEN.size():
		if Components.part_for_code(n) != GIVEN[n]:
			moved.append("%d is %s, not %s" % [n, Components.part_for_code(n), GIVEN[n]])
	check(moved.is_empty(), "no number already given out has moved (%s)" % ", ".join(moved))
	var seen: Dictionary = {}
	var unknown: Array = []
	for n in numbered:
		var id := String(numbered[n])
		seen[id] = true
		if not Components.exists(id) and not Components.is_retired(id) \
				and not Components.renamed().has(id):
			unknown.append(id)
	check(unknown.is_empty(),
		"every number in the table names a part that exists, was retired, or was made one with another (%s)"
			% str(unknown))
	var kept: Array = []
	for id in Components.retired_ids():
		if not seen.has(String(id)) or Components.exists(String(id)):
			kept.append(id)
	check(kept.is_empty(), "a retired part is gone from the game and keeps its number (%s)" % str(kept))
	var misnamed: Array = []
	var renames := Components.renamed()
	for id in renames:
		var now := String(renames[id])
		# A renamed part hands its number to its new id — unless that has a
		# number of its own, which is two parts made one: SWIFT STRIKE+ into
		# SWIFT STRIKE. Then the old id keeps its number, and reads as the new.
		var merged := Components.code_of(now) >= 0 and Components.code_of(String(id)) >= 0
		if (seen.has(String(id)) and not merged) or Components.exists(String(id)) or not Components.exists(now):
			misnamed.append(id)
	check(misnamed.is_empty(),
		"a renamed part is known only by its new id, and keeps a number only where it was made one with another (%s)"
			% str(misnamed))
	var uncoded: Array = []
	for id in Components.ids():
		if not seen.has(String(id)):
			uncoded.append(id)
	check(uncoded.is_empty(),
		"every part has a number, or no board with one on it can be shared (%s)" % str(uncoded))
	var highest := -1
	for n in numbered:
		highest = maxi(highest, int(n))
	check(highest < (1 << BoardCode.ID_BITS),
		"the table still fits %d bits (the last number is %d of %d)" % [
			BoardCode.ID_BITS, highest, (1 << BoardCode.ID_BITS) - 1])

	# --- the alphabet -------------------------------------------------------
	var alphabet: String = BoardCode.ALPHABET
	check(alphabet.length() == BoardCode.CHECK_MOD,
		"the alphabet is %d characters long (%d)" % [BoardCode.CHECK_MOD, alphabet.length()])
	# Prime, or the check character stops catching everything it claims to.
	var prime := BoardCode.CHECK_MOD > 1
	for f in range(2, BoardCode.CHECK_MOD):
		if f * f <= BoardCode.CHECK_MOD and BoardCode.CHECK_MOD % f == 0:
			prime = false
	check(prime, "and %d is prime" % BoardCode.CHECK_MOD)
	var twice: Array = []
	for i in alphabet.length():
		if alphabet.find(alphabet[i]) != i:
			twice.append(alphabet[i])
	check(twice.is_empty(), "no character appears in it twice (%s)" % str(twice))
	check(not alphabet.contains("0"),
		"and there is no 0 in it — the pixel face draws 0 and O with the same pixels")
	check(alphabet.contains("O") and alphabet.contains("o") and alphabet.contains("Z")
		and alphabet.contains("z") and alphabet.contains("9"),
		"but both cases and the other digits are all in it")
	# Five characters must hold a whole word of the board, with nothing over.
	check(pow(BoardCode.CHECK_MOD, BoardCode.WORD_CHARS) > float(BoardCode.WORD_MAX),
		"%d characters hold %d bits" % [BoardCode.WORD_CHARS, BoardCode.WORD_BITS])
	# Weights are what make a wrong character and a swapped pair both move the
	# total: never zero, and never the same as the next one along.
	var bad_weight: Array = []
	for i in 200:
		var w := BoardCode._weight(i)
		if w % BoardCode.CHECK_MOD == 0 or w == BoardCode._weight(i + 1):
			bad_weight.append(i)
	check(bad_weight.is_empty(), "every character's weight is live and unlike its neighbour's (%s)"
		% str(bad_weight))

	# --- round trips --------------------------------------------------------
	var empty := SkillBoard.new(7, 5, "nothing")
	round_trip(empty, "an empty board")

	var one := SkillBoard.new(7, 5, "one part")
	one.place("DELAY", Vector2i(0, 2), 0)
	round_trip(one, "a single part")
	var rootless := SkillBoard.new(7, 5, "no root")
	rootless.place("DELAY", Vector2i(3, 1), 0)
	round_trip(rootless, "a board with no root")

	# A real skill, and the code it is expected to make. This literal is what
	# pins the format down: it can only change when the format does, and when it
	# does, every code anyone has written down has stopped working. The gun's
	# own part is the root, as it is on every board a weapon carries, and the
	# chain runs from it to the way out.
	var skill := SkillBoard.new(7, 5, "Fire Bolt")
	skill.set_root("PROJECTILE", Vector2i(4, 2))
	skill.place("FIRE", Vector2i(5, 2), 0)
	skill.place("DAMAGE", Vector2i(6, 2), 0)
	var golden := round_trip(skill, "a three-part skill")
	print("[CODE] Fire Bolt is ", golden)
	check(golden == "HRV9zL1IE54LHBuf", "the format has not moved under existing codes")
	# The same skill as it was shared in version 2, before every part covered
	# one cell — the code this test held the format to then. Nothing on it
	# covered two, so it reads exactly as it did.
	var was_two := BoardCode.decode("CapygL1IE54LHBuM")
	check(String(was_two["error"]) == "" and same_parts(was_two["board"], skill)
			and (was_two["board"] as SkillBoard).root == skill.root,
		"a version 2 code reads as the same skill, root and all (%s)" % was_two["error"])
	# The same skill as it was shared in version 1, while its root could not
	# move and it ended on an OUTPUT — the code this test held the format to
	# then. It still reads: its root is what stood where every root stood, and
	# the build is slid along until the OUTPUT's cell is past the way out, which
	# puts it exactly where it is above.
	var was_output := BoardCode.decode("7kCUG29wtq3aDzOc")
	check(String(was_output["error"]) == "" and same_parts(was_output["board"], skill)
			and (was_output["board"] as SkillBoard).root == skill.root,
		"a version 1 code with an OUTPUT in it reads as the same skill, root and all (%s)" % was_output["error"])
	# As it was shared while INPUT was a part too, with the INPUT a cell in from
	# the edge. The INPUT's cell is left empty, and the slide takes the rest
	# along to the way out; with no part where the root stood, it has none.
	var was_input := BoardCode.decode("7kD3K2EZif3jtfN11111d")
	check(String(was_input["error"]) == "" and same_parts(was_input["board"],
			_board([["FIRE", 4, 2, 0], ["DAMAGE", 5, 2, 0], ["PROJECTILE", 6, 2, 0]]))
			and not (was_input["board"] as SkillBoard).has_root(),
		"a code written with an INPUT in it still reads, slid to the way out (%s)" % was_input["error"])
	# And as it was shared while WIRE was a part, one leading the INPUT into
	# the FIRE: both cells empty, the rest the same.
	var old := BoardCode.decode("7kDaN29S5g3bfg66lONvD")
	check(String(old["error"]) == "" and same_parts(old["board"],
			_board([["FIRE", 4, 2, 0], ["DAMAGE", 5, 2, 0], ["PROJECTILE", 6, 2, 0]])),
		"a code written with a WIRE in it too still reads the same way (%s)" % old["error"])

	# Every part in the table, turned every way, each in the first cell clear
	# for it. A retired number has no part to place, and neither has one whose
	# part goes by another id now (SWIFT STRIKE+'s): that part is placed under
	# its own number.
	var all := SkillBoard.new(11, 9, "everything")
	var turn := 0
	var placeable := 0
	var in_order: Array = numbered.keys()
	in_order.sort()
	for n in in_order:
		var id := String(numbered[n])
		if Components.is_retired(id) or Components.renamed().has(id):
			continue
		placeable += 1
		var landed := false
		for y in all.height:
			for x in all.width:
				var c := Vector2i(x, y)
				# Only ever onto clear ground: dropping a part on an origin that
				# is already taken replaces what was there, which is what the
				# editor wants and not what this is counting.
				if all.origin_at(c) == null and all.place(String(id), c, turn % 4):
					landed = true
					break
			if landed:
				break
		turn += 1
	check(all.cells.size() == placeable,
		"every part in the table fits on one board (%d of %d)" % [all.cells.size(), placeable])
	round_trip(all, "one of every part, at every rotation")

	# The biggest board the game can grow, filled: the longest code there is in
	# practice, and it has to stay inside the format's ceilings.
	var big := SkillBoard.new(11, 9, "full")
	for y in big.height:
		for x in big.width:
			big.place("DELAY", Vector2i(x, y), (x + y) % 4)
	check(big.cells.size() <= BoardCode.MAX_PARTS,
		"a full 11x9 board is inside the %d-part ceiling (%d)" % [BoardCode.MAX_PARTS, big.cells.size()])
	round_trip(big, "a full 11x9 board")

	# --- one board is one code ----------------------------------------------
	var other_order := SkillBoard.new(7, 5, "same, built backwards")
	other_order.place("DAMAGE", Vector2i(6, 2), 0)
	other_order.place("FIRE", Vector2i(5, 2), 0)
	other_order.set_root("PROJECTILE", Vector2i(4, 2))
	check(BoardCode.encode(other_order) == golden,
		"the same board built in a different order is the same code")
	var round_about := skill.duplicate_board()
	round_about.move_root(Vector2i(3, 1), 0)
	round_about.move_root(Vector2i(4, 2), 0)
	check(BoardCode.encode(round_about) == golden, "and so is one whose root went away and came back")
	var unrooted := skill.duplicate_board()
	unrooted.root = Vector2i(-1, -1)
	check(BoardCode.encode(unrooted) != golden,
		"but the same parts with none of them its root are another board")
	var renamed := skill.duplicate_board()
	renamed.skill_name = "Something Else"
	check(BoardCode.encode(renamed) == golden, "and renaming it does not change it")

	# --- how a code is written down -----------------------------------------
	var body := BoardCode.clean(golden)
	check(body == golden, "a code is one unbroken run, nothing between its characters (%s)" % golden)
	check(not golden.contains("-") and not golden.contains(" "), "no dashes and no spaces")
	check(BoardCode.is_valid("  %s %s\n%s\n" % [body.left(7), body.substr(7, 7), body.substr(14)]),
		"but it still reads back written with spaces, or wrapped over a line")
	check(BoardCode.is_valid("%s." % golden), "and with a full stop stuck to the end")
	check(BoardCode.name_for(golden) == "CODE %s" % body.substr(0, 5),
		"a board with no name arrives as its own first five characters (%s)" % BoardCode.name_for(golden))
	# Case is half the alphabet, so it cannot be folded away on the way in.
	check(not BoardCode.is_valid(body.to_upper()) or body == body.to_upper(),
		"a code shouted in capitals is not the same code")

	# --- a mistyped code is refused -----------------------------------------
	# Every single wrong character, and every adjacent pair swapped: the two
	# mistakes a person makes copying a code down, neither of which may ever
	# produce a board. Case counts as wrong — `hBw4k` and `hBW4k` are two boards.
	var alpha: String = BoardCode.ALPHABET
	var slipped: Array = []
	var tried := 0
	for i in body.length():
		for k in alpha.length():
			if alpha[k] == body[i]:
				continue
			tried += 1
			if BoardCode.is_valid(body.left(i) + alpha[k] + body.substr(i + 1)):
				slipped.append("%d:%s" % [i, alpha[k]])
	check(slipped.is_empty(), "no single wrong character reads as a board (%d tried, %s)"
		% [tried, str(slipped)])
	var swaps := 0
	var swapped := 0
	for i in body.length() - 1:
		if body[i] == body[i + 1]:
			continue
		swaps += 1
		if BoardCode.is_valid(body.left(i) + body[i + 1] + body[i] + body.substr(i + 2)):
			swapped += 1
	check(swapped == 0, "no two neighbours can swap and still read (%d tried)" % swaps)

	# --- and so is everything else ------------------------------------------
	check(not BoardCode.is_valid(""), "an empty code is refused")
	check(BoardCode.decode("").error == BoardCode.EMPTY,
		"and says there is nothing there")
	check(not BoardCode.is_valid(".....'"), "punctuation alone is refused")
	check(not BoardCode.is_valid(body + alpha[0]), "a character stuck on the end is refused")
	check(not BoardCode.is_valid(body.left(body.length() - 1)), "one missing is refused")
	check(BoardCode.decode("abcdefg").error == BoardCode.LENGTH
			and BoardCode.decode("abcdefg").args == [7],
		"a code of the wrong length says so, rather than failing on the board")
	# A 0 is not in the alphabet at all, and the one slip worth naming.
	check(BoardCode.decode(body.left(2) + "0" + body.substr(3)).error
			== BoardCode.HAS_ZERO,
		"a 0 typed where an O was meant says so")
	# Five characters over what 29 bits hold are not a word of a board, whatever
	# the check character says: "zzzzz" is 61^5 - 1, far over it.
	var over := "zzzzz" + body.substr(5)
	over = over.left(over.length() - 1)
	over += BoardCode._check_char(over)
	check(BoardCode._checks_out(over), "(a word over the ceiling still checks out)")
	check(not BoardCode.is_valid(over), "but five characters no board could have written are refused")
	# A code from a version that does not exist yet.
	var future := _with_version(7)
	check(BoardCode.decode(future).error == BoardCode.WRONG_VERSION
			and BoardCode.decode(future).args == [7, BoardCode.VERSION],
		"a code from another version says which (%s)" % str(BoardCode.decode(future).args))

	# --- a board from before the OUTPUT was retired ----------------------------
	# A save reads back the way the old codes above do: the OUTPUT left out, and
	# a build whose one OUTPUT took its flow heading east slid along until that
	# OUTPUT's cell is past the way out. The weapon's own part comes with it, so
	# a graph built before fires as it did — its SWIFT STRIKE a cell on, as
	# every board's from before every part covered one cell is (below).
	var built := _saved([["DASHSLASH", 0, 2, 0], ["FIRE", 2, 2, 0], ["OUTPUT", 3, 2, 0]])
	check(same_parts(built, _board([["DASHSLASH", 5, 2, 0], ["FIRE", 6, 2, 0]]))
			and built.root == Vector2i(5, 2) and bool(built.trace()["gets_out"]),
		"a graph saved with its OUTPUT comes back slid onto the way out, its root with it")
	var built_run := SkillRunner.new(built)
	built_run.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	check((built_run.simulate()["outputs"] as Array).size() == 1, "and fires as it did")
	# A weapon nobody had built on comes back as a new one starts.
	var bare_sword := _saved([["DASHSLASH", 0, 2, 0], ["OUTPUT", 2, 2, 0]])
	check(same_parts(bare_sword, Weapons.make_board("SWORD")) and bare_sword.root == Weapons.make_board("SWORD").root,
		"a bare sword saved then is the bare sword it would be given now")
	# One that ended on an OUTPUT fed any other way, or on two, or that would
	# not fit slid that far, stays where it was: its parts are all there, and
	# the trace says where the flow now stops.
	var below := _saved([["SLASH", 0, 2, 0], ["DELAY", 1, 2, 1], ["OUTPUT", 1, 3, 0]])
	var below_leaks: Array = below.trace()["leaks"]
	check(same_parts(below, _board([["SLASH", 0, 2, 0], ["DELAY", 1, 2, 1]])) and below_leaks.size() == 1
			and below_leaks[0]["from"] == Vector2i(1, 2) and int(below_leaks[0]["dir"]) == Components.S,
		"one fed from above stays put, and leaks where its OUTPUT stood")
	var forked := _saved([["SLASH", 0, 2, 0], ["ON_HIT", 1, 2, 0], ["OUTPUT", 2, 2, 0], ["OUTPUT", 1, 3, 0]])
	check(same_parts(forked, _board([["SLASH", 0, 2, 0], ["ON_HIT", 1, 2, 0]])),
		"one with two OUTPUTs stays put")
	var crowded := _saved([["SLASH", 0, 2, 0], ["OUTPUT", 1, 2, 0], ["FIRE", 6, 0, 0]])
	check(same_parts(crowded, _board([["SLASH", 0, 2, 0], ["FIRE", 6, 0, 0]])),
		"and so does one that would hang off the grid slid along")
	# From before WIRE, BEND and INPUT were retired: each left out and its cell
	# left empty. An OUTPUT a WIRE fed is fed by nothing now, so the build stays.
	var starter := _saved([["INPUT", 0, 2, 0], ["SLASH", 1, 2, 0], ["WIRE", 2, 2, 0], ["OUTPUT", 3, 2, 0]])
	check(same_parts(starter, _board([["SLASH", 1, 2, 0]])) and not starter.has_root(),
		"a starter board saved with its INPUT, WIRE and OUTPUT reads back as its SLASH")
	# And from before DASH, SPLIT, TEE, REVERSE, BLINK and SUMMON BOLT were: the
	# same, a cell left empty where each stood.
	check(same_parts(_saved([["SLASH", 0, 2, 0], ["DASH", 1, 2, 0], ["FIRE", 2, 2, 0],
			["SPLIT", 3, 2, 0], ["TEE", 4, 2, 0], ["REVERSE", 5, 2, 0], ["DAMAGE", 6, 2, 0],
			["BLINK", 2, 3, 0], ["SUMMON_PROJECTILE", 3, 3, 0]]),
			_board([["SLASH", 0, 2, 0], ["FIRE", 2, 2, 0], ["DAMAGE", 6, 2, 0]])),
		"a board saved with a DASH, a SPLIT, a TEE, a REVERSE, a BLINK and a SUMMON BOLT on it reads back with them left out")

	# --- a board from before AREA was renamed EXPLODE, and EXPLODE retired ----
	# The part kept its number, so a code shared under the old name still reads,
	# and now leaves it out, EXPLODE being retired; so does a save that spells it
	# either way.
	var shared := BoardCode.decode("7kBve29jhx111117")
	check(String(shared["error"]) == "" and same_parts(shared["board"], _board([])),
		"a code shared while EXPLODE was AREA still reads, with it left out (%s)" % shared["error"])
	check(same_parts(_saved([["INPUT", 0, 2, 0], ["AREA", 1, 2, 0], ["OUTPUT", 3, 2, 0]]), _board([])),
		"and a board saved with an AREA on it reads back without it")
	check(same_parts(_saved([["SLASH", 0, 2, 0], ["EXPLODE", 1, 2, 0], ["FIRE", 2, 2, 0], ["GRAVITY", 3, 2, 0]]),
			_board([["SLASH", 0, 2, 0], ["FIRE", 2, 2, 0]])),
		"as does one saved with an EXPLODE on it, or a GRAVITY")

	# --- a board from before SWIFT STRIKE+ was made SWIFT STRIKE ------------
	# It was SWIFT STRIKE with AUTO-AIM built in, in the same two cells. A save
	# spells it the old way and reads back as SWIFT STRIKE in the cell it let
	# its flow out of, as below; its number, 8, reads as SWIFT STRIKE too
	# (`BoardCode.decode`).
	check(same_parts(_saved([["DASHSLASH_AUTO", 1, 2, 0], ["FIRE", 3, 2, 0]]),
			_board([["DASHSLASH", 2, 2, 0], ["FIRE", 3, 2, 0]])),
		"a board saved with SWIFT STRIKE+ on it reads back with SWIFT STRIKE in its place")
	check(Components.current_id(Components.part_for_code(8)) == "DASHSLASH",
		"and the number SWIFT STRIKE+ had reads as SWIFT STRIKE")

	# --- a board from before ZAP was made PROJECTILE ---------------------------
	# Its beam was a bolt at laser speed, which PROJECTILE and four SPEEDs make.
	# A save that spells it reads back with a PROJECTILE in its cell, so the
	# flow through it still goes on; its number, 33, reads as PROJECTILE too.
	check(same_parts(_saved([["ZAP", 1, 2, 0], ["FIRE", 2, 2, 0]]),
			_board([["PROJECTILE", 1, 2, 0], ["FIRE", 2, 2, 0]])),
		"a board saved with ZAP on it reads back with PROJECTILE in its place")
	check(Components.current_id(Components.part_for_code(33)) == "PROJECTILE",
		"and the number ZAP had reads as PROJECTILE")

	# --- a board from before every part covered one cell ---------------------
	# SWIFT STRIKE and EXPLODE covered two cells then, and let their flow out of
	# the second. A save from then wrote no version down, and a code was version
	# 2 or older: either reads back with each of them moved on into the cell it
	# let its flow out of, so whatever it fed, it feeds still.
	var lunge := _saved([["DASHSLASH", 3, 2, 0], ["FIRE", 5, 2, 0], ["DAMAGE", 6, 2, 0]], Vector2i(3, 2))
	check(same_parts(lunge, _board([["DASHSLASH", 4, 2, 0], ["FIRE", 5, 2, 0], ["DAMAGE", 6, 2, 0]]))
			and lunge.root == Vector2i(4, 2) and bool(lunge.trace()["gets_out"]),
		"a sword built on then comes back with its SWIFT STRIKE a cell on, the root with it, and fires")
	var bare_then := _saved([["DASHSLASH", 5, 2, 0]], Vector2i(5, 2))
	check(same_parts(bare_then, Weapons.make_board("SWORD")) and bare_then.root == Weapons.make_board("SWORD").root,
		"a sword nobody had built on is the one a new profile gets now")
	# What fed one runs into the cell it left, and the break is there to mend.
	var fed := _saved([["DELAY", 2, 2, 0], ["DASHSLASH", 3, 2, 0], ["DAMAGE", 5, 2, 0], ["FIRE", 6, 2, 0]],
		Vector2i(2, 2))
	var fed_leaks: Array = fed.trace()["leaks"]
	check(same_parts(fed, _board([["DELAY", 2, 2, 0], ["DASHSLASH", 4, 2, 0], ["DAMAGE", 5, 2, 0], ["FIRE", 6, 2, 0]]))
			and fed_leaks.size() == 1 and fed_leaks[0]["from"] == Vector2i(2, 2),
		"a SWIFT STRIKE something fed moves on all the same, and what fed it leaks where it stood")
	var shared_lunge := BoardCode.decode("CapygBlgg54LHBuG")
	check(String(shared_lunge["error"]) == "" and same_parts(shared_lunge["board"], lunge)
			and (shared_lunge["board"] as SkillBoard).root == lunge.root,
		"and a code shared then reads the same way (%s)" % shared_lunge["error"])
	# A board written since says so, and reads back as it was written: a SWIFT
	# STRIKE with nothing in front of it stays where it was put.
	var since := SkillBoard.new(7, 5, "since")
	since.set_root("DASHSLASH", Vector2i(3, 2))
	since.place("FIRE", Vector2i(5, 2), 0)
	check(same_parts(SkillBoard.deserialize(since.serialize()), since)
			and same_parts(BoardCode.decode(BoardCode.encode(since))["board"], since),
		"a board saved or shared since reads back exactly as it was")

	# --- taking a board on -------------------------------------------------
	# The grid belongs to the workbench, not to the build drawn on it, and a
	# build is a chain to the way out: it comes onto a board of another size
	# with its way out on this one's, and fits if nothing then hangs off.
	var small := SkillBoard.new(7, 5, "mine")
	small.place("DELAY", Vector2i(0, 0), 0)
	var from_big := SkillBoard.new(11, 9, "theirs")
	from_big.place("SLASH", Vector2i(9, 7), 0)
	check(not small.fits(from_big), "a build off a bigger board that strays far from its way out does not fit a smaller one")
	check(not small.adopt(from_big), "so it is refused")
	check(String(small.comp_at(Vector2i(0, 0)).get("id", "")) == "DELAY",
		"and the board it was refused by is untouched")
	var inside := SkillBoard.new(11, 9, "theirs, but close to its way out")
	inside.place("SLASH", Vector2i(8, 3), 1)
	inside.place("NEAR", Vector2i(10, 4), 0)  # against the way out
	check(small.adopt(inside), "a build that fits is taken on")
	check(same_parts(small, _board([["SLASH", 4, 1, 1], ["NEAR", 6, 2, 0]])),
		"with its way out on this one's: everything four over and two up")
	check(small.width == 7 and small.height == 5 and small.skill_name == "mine",
		"on this board's own grid, under its own name")
	# And the root belongs to the weapon, not to the build: a code carries its
	# author's root, marked, and it is left behind on the way in — this weapon's
	# own part goes where it stood, handing its flow over from the same cell.
	var mine := SkillBoard.new(7, 5, "the sword's")
	mine.set_root("DASHSLASH", Vector2i(5, 2))
	var theirs := SkillBoard.new(7, 5, "the gun's")
	theirs.set_root("PROJECTILE", Vector2i(4, 2))
	theirs.place("FIRE", Vector2i(5, 2), 0)
	theirs.place("DAMAGE", Vector2i(6, 2), 0)
	check(mine.adoption_cost(theirs) == {"FIRE": 1, "DAMAGE": 1},
		"a build costs the parts that come onto the board, and its author's root is not one (%s)"
			% str(mine.adoption_cost(theirs)))
	check(mine.adopt(theirs) and String(mine.root_entry().get("id", "")) == "DASHSLASH"
			and mine.root == Vector2i(4, 2) and mine.cells.size() == 3 and bool(mine.trace()["gets_out"]),
		"taken on, this weapon's own part hands its flow over where the author's did, and it fires (%s at %s)"
			% [str(mine.root_entry()), str(mine.root)])
	# A build with no root of its own leaves this weapon's where it is.
	var rootless_build := SkillBoard.new(7, 5, "a build with no root")
	rootless_build.place("FIRE", Vector2i(5, 2), 0)
	var stays := SkillBoard.new(7, 5, "the sword again")
	stays.set_root("DASHSLASH", Vector2i(6, 2))
	check(stays.adopt(rootless_build) and stays.root == Vector2i(6, 2) and stays.cells.size() == 2
			and bool(stays.trace()["gets_out"]),
		"a build with no root leaves this weapon's where it stood (%s)" % str(stays.root))
	# The code carries the root, so all of this holds for a build pasted in.
	var pasted: SkillBoard = BoardCode.decode(BoardCode.encode(theirs))["board"]
	check(pasted.root == theirs.root and pasted.root_entry() == theirs.root_entry(),
		"a code says which part its root is")

	# --- what a pasted board costs ------------------------------------------
	var pool := {"FIRE": 1, "PROJECTILE": 1}
	var have := SkillBoard.new(7, 5, "old")
	have.set_root("DELAY")   # the weapon's own part, in neither count
	have.place("DAMAGE", Vector2i(1, 2), 0)
	var want := SkillBoard.new(7, 5, "new")
	want.set_root("DELAY")
	want.place("FIRE", Vector2i(1, 2), 0)
	want.place("PROJECTILE", Vector2i(2, 2), 0)
	want.place("ON_HIT", Vector2i(3, 2), 0)
	var missing := GameState.trade_board(have, have.adoption_cost(want), pool)
	check(int(missing.get("ON_HIT", 0)) == 1, "a board you cannot afford says what is short")
	check(int(pool.get("FIRE", 0)) == 1 and not pool.has("DAMAGE"),
		"and nothing moved — the old board's parts are still in it")
	pool["ON_HIT"] = 1
	check(GameState.trade_board(have, have.adoption_cost(want), pool).is_empty(),
		"with the last part, the trade goes through")
	check(not pool.has("FIRE") and not pool.has("PROJECTILE") and not pool.has("ON_HIT"),
		"the new board's parts came out of the pool")
	check(int(pool.get("DAMAGE", 0)) == 1, "and the old board's went back into it")
	check(GameState.trade_board(null, {}, pool).is_empty(),
		"a build with nothing on it costs nothing")

	print("[CODE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## A board as an older save holds it — [id, x, y, rot] a part, retired and
## renamed ones included, rooted where every root stood while none could move
## unless `root` says otherwise, and with no version written down — read back
## the way a save is.
func _saved(parts: Array, root := SkillBoard.ROOT) -> SkillBoard:
	var cells: Array = []
	for p in parts:
		cells.append({"id": p[0], "x": p[1], "y": p[2], "rot": p[3]})
	return SkillBoard.deserialize({"w": 7, "h": 5, "name": "saved", "root": [root.x, root.y],
		"cells": cells})

## The board one of those ought to come back as.
func _board(parts: Array) -> SkillBoard:
	var b := SkillBoard.new(7, 5, "want")
	for p in parts:
		b.place(String(p[0]), Vector2i(p[1], p[2]), p[3])
	return b

## A code claiming to be version `v`: the version is the first three bits, so it
## is the leading five characters that change, and the check character with them.
func _with_version(v: int) -> String:
	var b := SkillBoard.new(7, 5, "x")
	b.place("DELAY", Vector2i(0, 0), 0)
	var c := BoardCode.clean(BoardCode.encode(b))
	var head := BoardCode._chars_to_word(c.substr(0, BoardCode.WORD_CHARS))
	# Clear the top three bits of the first twenty-nine and write `v` into them.
	head = (head & ((1 << (BoardCode.WORD_BITS - BoardCode.VER_BITS)) - 1)) \
		| (v << (BoardCode.WORD_BITS - BoardCode.VER_BITS))
	var out := BoardCode._word_to_chars(head) \
		+ c.substr(BoardCode.WORD_CHARS, c.length() - BoardCode.WORD_CHARS - 1)
	return out + BoardCode._check_char(out)
