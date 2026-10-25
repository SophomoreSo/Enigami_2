class_name FreeTalk
extends RefCounted

## A character talking free: in a bubble over whoever is speaking, while the
## player goes on playing. Nothing holds the player, a line moves on by itself
## once it has had time to be read, and what is said is never a fixed path
## through a tree. Every line is a rule — a row in `rules`, see data/db/README.md
## — with the event it answers, the criteria the facts must meet for it
## (`Facts`), and the changes it makes to them once it has been said.
##
## An event gets the rule, of those answering it, with the most criteria that
## all hold: the most specific thing there is to say. A tie goes to the one
## written first, and a rule that is `once` is only in the running until it
## has been said.
##
## That is also how a conversation is picked up again, and nothing else is. A
## line cut off — the player walked out of earshot, something else cut in —
## was never said: it counts for nothing, changes nothing, and comes up again
## the next time it is the best answer. A line that was said is spent if it is
## `once`, so the next press finds the first thing not yet said.
##
## One of these per `Npc`, which hands it presses, the player coming and
## going, and time. The moments the rest of the game announces reach it
## through one ear for all of them (`_on_cue`), so a moment that two characters
## hear is still counted once. Nothing here is drawn: `SpeechBubble` shows it.

## The events the game raises itself. data/db/schema.sql declares the same
## three, and a rule may answer them like any other.
const TALK := "talk"
const NEAR := "near"
const LEAVE := "leave"

## Letters a line reveals per second, unless it sets its own `speed`.
const REVEAL_RATE := 45.0
## How long a line stays up once it is all out, unless it sets its own `hold`:
## a beat, and a little longer for every letter in it, and never so short
## that a word or two flashes past unread.
const READ_BEAT := 0.8
const READ_RATE := 22.0
const READ_LEAST := 1.6

## A line has started, and is coming out.
signal started(rule_id: String)

## Whose rules these are. Their lines' facts are named after it.
var character_id: String = ""
## rule id -> the rule as `Dialogue` read it, `criteria` and `changes` under it.
var rules: Dictionary = {}
## The rule being said, or "" while they are quiet.
var line_id: String = ""
## How many letters of it are out so far.
var revealed: float = 0.0
## Seconds it has been all the way out.
var held: float = 0.0
## Whether the player opened this with a press. Talk they asked for is talk
## they can walk out on; a remark the character made unprompted is not theirs
## to interrupt, and goes on either way.
var asked: bool = false
## Whether the moments the game announces reach this one: the owner says so
## every frame — in earshot, and not held in a conversation in the box.
var listening: bool = false

## event -> the rules answering it, in the order they are tried.
var _answers: Dictionary = {}
## Whether the line being said has been all the way out, and so counted.
var _said: bool = false

## event -> {"cue", "match"}, and cue -> the events it can be, the one that
## matches more of it first. Read once; see `reload`.
static var _events: Dictionary = {}
static var _cues: Dictionary = {}
static var _events_read: bool = false
## Every one of these still alive, weakly: the ear's list of who to tell.
static var _ears: Array = []

## `def` is a character as `Dialogue.character` reads one; left out, it is
## read for `id`.
func _init(id: String, def: Dictionary = {}) -> void:
	if def.is_empty():
		def = Dialogue.character(id)
	character_id = String(def.get("id", id))
	rules = def.get("rules", {})
	for rid in rules:
		var event := String((rules[rid] as Dictionary).get("listens", ""))
		if event == "":
			continue
		if not _answers.has(event):
			_answers[event] = []
		(_answers[event] as Array).append(rid)
	for event in _answers:
		_answers[event] = _by_specificity(_answers[event])
	_ears.append(weakref(self))
	_listen()

## The rule `event` would get said right now, or "" when there is none: the
## first, most criteria first, that is not spent and whose criteria all hold.
func pick(event: String) -> String:
	for id in _answers.get(event, []):
		var rule: Dictionary = rules[id]
		if int(rule.get("once", 0)) != 0 and Facts.value(Facts.line(character_id, id)) > 0:
			continue
		if Facts.hold(rule.get("criteria", [])):
			return id
	return ""

## Whether `event` would get anything said right now. The prompt over a free
## talker's head asks it of `talk`: with nothing to say, there is no prompt.
func would_answer(event: String) -> bool:
	return pick(event) != ""

## Raises `event` here: counts it, then says whatever it gets.
func hear(event: String) -> bool:
	Facts.add(event)
	return answer(event)

## Says whatever `event` gets, for an event already counted. What was being
## said is cut off for it — and goes unsaid, and comes up again later — but
## only if the event gets something: an event nothing answers leaves what was
## being said alone.
func answer(event: String) -> bool:
	return _answer(event, event == TALK)

## One press of interact up close: brings the rest of a line out at once, moves
## on from one that is out, or — when nothing is being said — asks.
func press() -> void:
	if line_id == "":
		hear(TALK)
		return
	if not line_finished():
		revealed = float(current_line().length())
		return
	if not _said:
		_done()
	_go_on()

## Says rule `id` now, as talk the player asked for — for a conversation
## handed back to free talk by whatever had it: the box, after a question.
## Whatever was being said is cut off for it.
func say(id: String) -> void:
	if not rules.has(id):
		return
	cut()
	_say(id, true)

func step(delta: float) -> void:
	if line_id == "":
		return
	var length := current_line().length()
	if int(revealed) < length:
		revealed = minf(revealed + reveal_rate() * delta, float(length))
		return
	if not _said:
		_done()
	held += delta
	if held >= hold_time():
		_go_on()

## Stops whatever is being said. A line not all the way out was never said: it
## counts for nothing and changes nothing.
func cut() -> void:
	if line_id != "" and line_finished() and not _said:
		_done()
	_quiet()

func is_talking() -> bool:
	return line_id != ""

func current_rule() -> Dictionary:
	return rules.get(line_id, {})

func current_line() -> String:
	return String(current_rule().get("text", ""))

## The part of the current line revealed so far.
func visible_text() -> String:
	return current_line().left(int(revealed))

func line_finished() -> bool:
	return int(revealed) >= current_line().length()

## Who says the current line: "npc" or "player".
func speaker() -> String:
	return String(current_rule().get("speaker", "npc"))

## Letters per second for the current line.
func reveal_rate() -> float:
	return maxf(float(current_rule().get("speed", REVEAL_RATE)), 1.0)

## Seconds the current line stays up once it is all out.
func hold_time() -> float:
	var rule := current_rule()
	if rule.has("hold"):
		return float(rule["hold"])
	return maxf(READ_LEAST, READ_BEAT + reading(current_line()) / READ_RATE)

## How much reading `text` is, in letters. A Hangul syllable — or any other
## character that is a whole block of letters — counts as two, so the same
## line takes as long to read in Korean as in English.
static func reading(text: String) -> float:
	var n := 0.0
	for i in text.length():
		var c := text.unicode_at(i)
		if c == 32:
			continue
		n += 2.0 if c >= 0x1100 and not (c >= 0x2000 and c <= 0x206F) else 1.0
	return n

## The events the database declares, by id: `cue` and `match`, for the ones
## that are moments the game announces.
static func events() -> Dictionary:
	_read_events()
	return _events

## Forgets the events read from the database, so a rebuilt one is read again.
## `Dialogue.reload` calls this.
static func reload() -> void:
	_events_read = false

func _answer(event: String, as_asked: bool) -> bool:
	var id := pick(event)
	if id == "":
		return false
	cut()
	_say(id, as_asked)
	return true

func _say(id: String, as_asked: bool) -> void:
	line_id = id
	revealed = 0.0
	held = 0.0
	_said = false
	asked = as_asked
	started.emit(id)

## The line is all the way out, so it has been said: it counts, it makes its
## changes, and the profile is written down with them.
func _done() -> void:
	_said = true
	Facts.add(Facts.line(character_id, line_id))
	Facts.change(current_rule().get("changes", []))
	Facts.keep()

## Past a line that has been read: its `next`, whatever its `triggers` gets
## said, or with neither, quiet. What follows is still the player's talk if
## the line was.
func _go_on() -> void:
	var rule := current_rule()
	var was_asked := asked
	_quiet()
	var next := String(rule.get("next", ""))
	if next != "":
		if rules.has(next):
			_say(next, was_asked)
		else:
			push_warning("FreeTalk: %s has no rule '%s'" % [character_id, next])
		return
	var event := String(rule.get("triggers", ""))
	if event != "":
		Facts.add(event)
		_answer(event, was_asked)

func _quiet() -> void:
	line_id = ""
	revealed = 0.0
	held = 0.0
	asked = false
	_said = false

## Most criteria first; among equals, the order they were written in. Kept by
## hand, since `sort_custom` does not promise to keep it.
func _by_specificity(ids: Array) -> Array:
	var keyed: Array = []
	for i in ids.size():
		keyed.append([((rules[ids[i]] as Dictionary).get("criteria", []) as Array).size(), i, ids[i]])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	return keyed.map(func(k: Array) -> String: return String(k[2]))

## --- the ear ------------------------------------------------------------------
##
## One listener on `Cues` for every free talker there is. A moment that is an
## event in the database is counted once — if anybody is listening at all, so
## a count is of moments someone saw — and each listener then answers it, or
## the more particular of the events it is, when it can be more than one.

static func _listen() -> void:
	if not Cues.fired.is_connected(_on_cue):
		Cues.fired.connect(_on_cue)

static func _on_cue(cue: StringName, data: Dictionary) -> void:
	_read_events()
	var names: Array = _cues.get(String(cue), [])
	if names.is_empty():
		return
	var ears: Array = []
	for w in _ears.duplicate():
		var ear = (w as WeakRef).get_ref()
		if ear == null:
			_ears.erase(w)
		elif ear.listening:
			ears.append(ear)
	if ears.is_empty():
		return
	var heard: Array = []
	for id in names:
		if _matches((_events[id] as Dictionary).get("match", {}), data):
			heard.append(id)
			Facts.add(id)
	for ear in ears:
		for id in heard:
			if ear._answer(id, false):
				break

## Whether a cue carries everything `match` asks of it. A number matches a
## number of the same size, whatever JSON made of it.
static func _matches(match: Dictionary, data: Dictionary) -> bool:
	for key in match:
		if not data.has(key):
			return false
		var want = match[key]
		var have = data[key]
		if (want is int or want is float) and (have is int or have is float):
			if not is_equal_approx(float(want), float(have)):
				return false
		elif str(want) != str(have):
			return false
	return true

static func _read_events() -> void:
	if _events_read:
		return
	_events_read = true
	_events.clear()
	_cues.clear()
	var order: Array = []
	for e in Db.records("events", "", [], "rowid"):
		var id := String(e["id"])
		var m = e.get("match", {})
		_events[id] = {"cue": String(e.get("cue", "")), "match": m if m is Dictionary else {}}
		order.append(id)
	for id in order:
		var cue := String(_events[id]["cue"])
		if cue == "":
			continue
		if not _cues.has(cue):
			_cues[cue] = []
		(_cues[cue] as Array).append(id)
	# The event that asks more of a cue is the more particular, and is answered
	# first: a blow that kills is `kill` before it is `strike`.
	for cue in _cues:
		var ids: Array = _cues[cue]
		var keyed: Array = []
		for i in ids.size():
			keyed.append([(_events[ids[i]]["match"] as Dictionary).size(), i, ids[i]])
		keyed.sort_custom(func(a: Array, b: Array) -> bool:
			return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
		_cues[cue] = keyed.map(func(k: Array) -> String: return String(k[2]))
