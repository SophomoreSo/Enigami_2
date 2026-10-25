class_name BoardCode
extends RefCounted

## A board written out as a short code, so a build can be shared: pasted into a
## message, read down a phone, printed under a screenshot.
##
##     BoardCode.encode(board)   ->  "hBw4kTq2Nr8dGxMPvL5cJ"
##     BoardCode.decode(code)    ->  {"board": SkillBoard, "error": "", "args": []}
##
## **Case matters.** The alphabet is the digits, the capitals and the small
## letters — 61 characters, which carries a board in a little over half the
## length ten digits would. The one character left out is `0`, and it is left
## out for two reasons: 61 is prime, which is what makes the check character
## below catch everything it catches, and the pixel face draws `0` and `O` with
## exactly the same pixels. With no zero in the alphabet, a round character is
## always the letter.
##
## The face has no small letters either — it draws them as capitals — so a code
## on screen would not show its own case. That is why a code leaves the game by
## COPY and comes back by PASTE, and is never put on screen to be read off; what
## matters here is that `hBw4k` and `HBW4K` are two different boards, whatever
## they look like.
##
## Nothing goes between the characters — no dashes, no spaces. A code is shown
## and copied as one unbroken run, which keeps it exactly as long as it has to
## be, makes it a single word to a double-click in a chat window, and means the
## code COPY puts on the clipboard is character for character the one PASTE
## reads back off it.
##
## A code carries the circuit and only the circuit. Not the skill's name, which
## travels in the message beside it. Not the grid either, as a *rule*: a board
## pasted onto a workbench keeps that workbench's grid, and the size written
## into the code is there so a refusal can say which board the build was laid
## out for (see `SkillBoard.adopt`). Its author's root goes into it like any
## other part, marked as the root, and is left behind on the way in: the board
## it lands on has a weapon's own part, and that moves to where it stood.
##
## Pure data, like the board it reads. Nothing here draws.

const VERSION := 3

## No `0`, and in this order for good: a character's place in this string is its
## value, so reordering it would change every code ever written down.
const ALPHABET := "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

## --- the format -------------------------------------------------------------
##
## A bit stream, packed five characters to every twenty-nine bits, then one
## check character:
##
##     version   3 bits
##     width-1   4 bits          1..16 cells across
##     height-1  4 bits
##     parts     7 bits          up to 127 of them
##     root      7 bits          which of the parts is the root, counted in
##                               reading order — as many as there are parts
##                               when none of them is
##     then each part, in reading order:
##       cell    as many bits as width x height needs — 6 on a 7x5, 7 on an 11x9
##       part    6 bits, its number in the content database's `codes`
##       facing  2 bits
##
## Parts go in reading order rather than the order they were placed, so one
## board is always one code however it was built up, and two players comparing
## codes by eye are comparing boards.
##
## Version 1, written while a root could not move, has no root field: its root
## is whatever stands at `SkillBoard.ROOT`, which is where every root stood
## then. One from before the OUTPUT was retired is put where its flow used to
## end, the way a save from then is (`SkillBoard.slide_onto_way_out`).
## Versions 1 and 2 were both written while SWIFT STRIKE and EXPLODE covered
## two cells each, and each of those is moved on into the cell it let its flow
## out of, the way a save's is (`SkillBoard.shrink_two_cell_parts`). Version 3
## is laid out exactly as version 2, every part a cell. Codes are written in
## version 3, and all three read.
const VER_BITS := 3
const SIDE_BITS := 4
const COUNT_BITS := 7
const ID_BITS := 6
const ROT_BITS := 2

## Twenty-nine bits to five characters: 2^29 fits inside 61^5 with two per cent
## of the room to spare, and puts a whole number of bits against a whole number
## of characters — so every five characters *are* a word of the board, and five
## that come to more than WORD_MAX are a mistyped character rather than a board
## nobody can build. The five are not marked off in the code itself; they do
## not need to be, because a code's length says where each one starts.
const WORD_BITS := 29
const WORD_CHARS := 5
const WORD_MAX := (1 << WORD_BITS) - 1

## What the header's fields leave room for. A maxed Workbench grows an 11x9, so
## there is somewhere to keep growing.
const MAX_SIDE := 16
const MAX_PARTS := 127

## Every part's number in a code is its row in `codes`, in the content
## database (`data/db/parts/parts.sql`, via `Components.code_of`). That list is
## only ever added to: a code written today has to mean the same board next
## year, so a part keeps its number for good — a retired one included, as WIRE,
## BEND and OUTPUT have, and a renamed one hands it to its new id, as AREA did
## to EXPLODE. ID_BITS leaves room for 64; `tests/circuit/code_test.tscn` holds
## every number already given out to its part, and fails a part with none.

## The last character makes the whole code weigh nothing: every character is
## multiplied by its place in the line and the total comes to zero, counted
## modulo the size of the alphabet.
##
## That size being **prime** is the whole trick. One character wrong shifts the
## total by its weight times the difference, and neither can be zero, so it can
## never land back on zero. Two characters next to each other swapped shift it
## by the difference of their weights times the difference of the characters,
## and no two neighbours share a weight. So **every single wrong character and
## every pair of neighbours swapped is caught** — which are the two mistakes a
## person actually makes copying a code down — where a hash of the same one
## character length would let one error in sixty-one through.
const CHECK_MOD := 61

## Both ways a mistyped code shows up before it means anything, said the once:
## the check character failing and five characters no board could have written
## are the same news to the player.
##
## These are the names of the refusals, not the lines: what one actually says
## is in `localization/<lang>/editor.json` under `code_error`, and the editor
## a code is pasted into spells it (`SkillEditor.code_error_text`), so a code
## pasted wrong is complained about in the language it was pasted in — and the
## circuit names no word, in any language.
const MISTYPED := "mistyped"
const TRUNCATED := "truncated"
const IMPOSSIBLE := "impossible"
const HAS_ZERO := "has_zero"
const EMPTY := "empty"
const LENGTH := "length"
const WRONG_VERSION := "version"
const UNKNOWN_PART := "unknown_part"
## Every refusal `decode` can return, for the test that holds each to a line.
const REFUSALS := [MISTYPED, TRUNCATED, IMPOSSIBLE, HAS_ZERO, EMPTY, LENGTH,
	WRONG_VERSION, UNKNOWN_PART]

## --- writing ----------------------------------------------------------------

## `board` as a code, exactly as it is shown and shared. Empty when the board
## cannot be put into one: bigger than the format's ceiling, or carrying a part
## that has no number in `codes` yet.
static func encode(board: SkillBoard) -> String:
	if board == null or board.cells.size() > MAX_PARTS:
		return ""
	if board.width < 1 or board.width > MAX_SIDE or board.height < 1 or board.height > MAX_SIDE:
		return ""
	var bits: Array[int] = []
	_put(bits, VERSION, VER_BITS)
	_put(bits, board.width - 1, SIDE_BITS)
	_put(bits, board.height - 1, SIDE_BITS)
	_put(bits, board.cells.size(), COUNT_BITS)
	var order := reading_order(board)
	_put(bits, order.find(board.root) if board.has_root() else order.size(), COUNT_BITS)
	var cell_bits := _cell_bits(board.width, board.height)
	for origin in order:
		var entry: Dictionary = board.cells[origin]
		var n := Components.code_of(String(entry["id"]))
		if n < 0:
			return ""
		_put(bits, origin.y * board.width + origin.x, cell_bits)
		_put(bits, n, ID_BITS)
		_put(bits, int(entry["rot"]) % 4, ROT_BITS)
	var body := ""
	for i in range(0, bits.size(), WORD_BITS):
		var word := 0
		for k in WORD_BITS:
			word = (word << 1) | (bits[i + k] if i + k < bits.size() else 0)
		body += _word_to_chars(word)
	return body + _check_char(body)

## The origins of `board`'s parts, left to right and top to bottom.
static func reading_order(board: SkillBoard) -> Array:
	var origins: Array = board.cells.keys()
	var w := board.width
	origins.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y * w + a.x < b.y * w + b.x)
	return origins

## --- reading ----------------------------------------------------------------

## Reads a code back into a board.
##
## Returns `{"board": SkillBoard, "error": "", "args": []}`, or a null board and
## the id of what is wrong with the code — one of the refusals above — with the
## numbers its line takes in `args`. The sheet spells it, in the language being
## played; the circuit only says which.
static func decode(code: String) -> Dictionary:
	# A 0 is the one slip the alphabet itself can explain, and it is worth saying
	# before anything else: dropped silently it shortens the code, and the
	# complaint that comes back is then about the length instead of the zero.
	if code.contains("0"):
		return _fail(HAS_ZERO)
	var c := clean(code)
	if c.is_empty():
		return _fail(EMPTY)
	# Words of five and the check character: any other length is not a code at
	# all, and saying so beats failing later on with something about the board.
	if c.length() % WORD_CHARS != 1:
		return _fail(LENGTH, [c.length()])
	if not _checks_out(c):
		return _fail(MISTYPED)

	var bits: Array[int] = []
	for i in range(0, c.length() - 1, WORD_CHARS):
		var word := _chars_to_word(c.substr(i, WORD_CHARS))
		if word > WORD_MAX:
			return _fail(MISTYPED)
		for k in range(WORD_BITS - 1, -1, -1):
			bits.append((word >> k) & 1)

	var r := Reader.new(bits)
	var ver := r.take(VER_BITS)
	var w := r.take(SIDE_BITS) + 1
	var h := r.take(SIDE_BITS) + 1
	var count := r.take(COUNT_BITS)
	if not r.ok:
		return _fail(TRUNCATED)
	if ver < 1 or ver > VERSION:
		return _fail(WRONG_VERSION, [ver, VERSION])
	var root_index := r.take(COUNT_BITS) if ver >= 2 else -1
	if not r.ok:
		return _fail(TRUNCATED)

	var board := SkillBoard.new(w, h, name_for(c))
	# From version 2 on a code says which part its root is, and a board with
	# none has none.
	if ver >= 2:
		board.root = Vector2i(-1, -1)
	var outputs: Array = []
	var cell_bits := _cell_bits(w, h)
	for i in count:
		var pos := r.take(cell_bits)
		var part := r.take(ID_BITS)
		var rot := r.take(ROT_BITS)
		if not r.ok:
			return _fail(TRUNCATED)
		# A number keeps the id it was given, and a part since renamed reads as
		# what it is called now — SWIFT STRIKE+ as SWIFT STRIKE.
		var id := Components.current_id(Components.part_for_code(part))
		if id == "":
			return _fail(UNKNOWN_PART)
		if pos >= w * h:
			return _fail(IMPOSSIBLE)
		@warning_ignore("integer_division")
		var origin := Vector2i(pos % w, int(pos / w))
		# A code written before a part was retired still reads, with the part
		# left out and its cell left empty, as a save does: see
		# `SkillBoard.deserialize`.
		if Components.is_retired(id):
			if id == "OUTPUT":
				outputs.append(origin)
			continue
		if i == root_index:
			board.root = origin
		# `place` refuses an overlap and a footprint off the edge, so a code
		# that says either is turned away here. The one thing it allows is a
		# part dropped on an origin already taken, which is the editor's replace
		# — in a code it is two parts in one cell, so the cell is checked clear
		# first and the board a code names is exact.
		if board.origin_at(origin) != null:
			return _fail(IMPOSSIBLE)
		if not board.place(id, origin, rot):
			return _fail(IMPOSSIBLE)
	# Everything past the last part is padding out the last word, and padding is
	# zeros — characters stuck on the end show up as something else.
	if not r.rest_is_padding():
		return _fail(MISTYPED)
	if ver < 3:
		board.shrink_two_cell_parts()
	board.slide_onto_way_out(outputs)
	return {"board": board, "error": "", "args": []}

## Whether `code` reads back as a board at all. The board itself is thrown away,
## so anything about to use one should call `decode` and keep what it returns.
static func is_valid(code: String) -> bool:
	return String(decode(code)["error"]) == ""

## --- the code as text -------------------------------------------------------

## Everything outside the alphabet is dropped, so a code survives being written
## out with spaces in it, wrapped over two lines, or pasted with a full stop stuck
## to the end of it. Case is kept, because case is what half the alphabet is.
##
## Unlike a code of digits, one of letters cannot be picked out of a sentence:
## the letters of "code:" are alphabet characters too. Paste the code, not the
## line it came in.
static func clean(code: String) -> String:
	var out := ""
	for i in code.length():
		if ALPHABET.find(code[i]) >= 0:
			out += code[i]
	return out

## Whether `c` is one of the characters a code is made of.
static func holds(c: String) -> bool:
	return c.length() == 1 and ALPHABET.find(c) >= 0

## What a board arrives called. A code carries no name — that travels in the
## message beside it — so this is the handle it gets instead: the code's own
## first five characters, which is enough to tell two shared boards apart and
## short enough to fit on a slot tab.
static func name_for(code: String) -> String:
	var c := clean(code)
	if c.is_empty():
		return "CODE"
	return "CODE %s" % c.substr(0, mini(WORD_CHARS, c.length()))

## The longest a code can ever be: every part the format allows, on the biggest
## grid it allows. A field collecting characters stops here, since nothing past
## it could be a code.
static func max_chars() -> int:
	var bits := VER_BITS + SIDE_BITS * 2 + COUNT_BITS * 2 \
		+ MAX_PARTS * (_cell_bits(MAX_SIDE, MAX_SIDE) + ID_BITS + ROT_BITS)
	return int(ceil(float(bits) / float(WORD_BITS))) * WORD_CHARS + 1

## --- the characters ---------------------------------------------------------

static func _word_to_chars(word: int) -> String:
	var out := ""
	var v := word
	for i in WORD_CHARS:
		out = ALPHABET[v % CHECK_MOD] + out
		v /= CHECK_MOD
	return out

static func _chars_to_word(chars: String) -> int:
	var v := 0
	for i in chars.length():
		v = v * CHECK_MOD + ALPHABET.find(chars[i])
	return v

## A character's weight is its place in the line, counted 1 to 60 and starting
## over. Never zero, so a wrong character always moves the total; never the same
## as its neighbour's, so a swapped pair always does too.
static func _weight(i: int) -> int:
	return (i % (CHECK_MOD - 1)) + 1

static func _check_char(body: String) -> String:
	var sum := 0
	for i in body.length():
		sum = (sum + _weight(i) * ALPHABET.find(body[i])) % CHECK_MOD
	var w := _weight(body.length())
	for v in CHECK_MOD:
		if (sum + w * v) % CHECK_MOD == 0:
			return ALPHABET[v]
	return ALPHABET[0]   # unreachable: w is never 0, so one v always lands

static func _checks_out(code: String) -> bool:
	var sum := 0
	for i in code.length():
		sum = (sum + _weight(i) * ALPHABET.find(code[i])) % CHECK_MOD
	return sum == 0

## --- the bits ---------------------------------------------------------------

## Bits a cell number takes on a board this size: six on a 7x5, seven on the
## 11x9 a maxed Workbench grows. Sized to the board rather than fixed, which the
## reader can do too because the board's size is read out of the code first.
static func _cell_bits(w: int, h: int) -> int:
	var n := 1
	while (1 << n) < w * h:
		n += 1
	return n

static func _put(bits: Array[int], value: int, n: int) -> void:
	for i in range(n - 1, -1, -1):
		bits.append((value >> i) & 1)

static func _fail(key: String, args: Array = []) -> Dictionary:
	return {"board": null, "error": key, "args": args}

## A cursor over the bits, which reports running off the end rather than
## returning a zero that would read as a real part in an empty corner.
class Reader extends RefCounted:
	var bits: Array[int]
	var at: int = 0
	var ok: bool = true

	func _init(b: Array[int]) -> void:
		bits = b

	func take(n: int) -> int:
		if at + n > bits.size():
			ok = false
			return 0
		var v := 0
		for i in n:
			v = (v << 1) | bits[at + i]
		at += n
		return v

	func rest_is_padding() -> bool:
		for i in range(at, bits.size()):
			if bits[i] != 0:
				return false
		return true
