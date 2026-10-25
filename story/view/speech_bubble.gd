class_name SpeechBubble
extends Node2D

## Free talk, drawn: a bubble over the head of whoever is saying the line, the
## words typing into it a letter at a time (see `FreeTalk`). It holds nobody
## and covers nothing but the air over a head, so the player goes on playing
## under it, and it has no portrait and no name: the tail points at whoever
## is talking. The emotion is in the letters, the way it is in the box —
## angry ones tremble, happy ones ripple (`Style.EMOTIONS`).
##
## It hangs on the NPC view's prompt layer, over the pixel picture and at the
## screen's resolution, for the reason the prompt and the hideout's signs do:
## these are words to read, and words drawn into the picture are blown up with
## it — Hangul twice the size of the Latin beside it. The face is the pixel one
## at its own size and the edge a PIXEL wide, like every other pixel panel.

const PX := PixelDraw.PX
const FONT := PixelDraw.FONT
const SIZE := PixelDraw.SIZE
const LINE := PixelDraw.LINE
## Inside the edge, around the words.
const PAD := Vector2(12, 8)
## The widest a row of words gets before it wraps, and the most rows there are.
## A line that needs more is a line for the box: `loc_test` fails one that does
## not fit, in any language.
const WIDTH := 280.0
const MOST_ROWS := 4
## Steps down to the tip of the tail, each a PIXEL narrower either side, and the
## air left between the tip and the head it points at. Big enough to read as a
## tail from across the room: four steps was a notch nobody saw.
const TAIL := 6
const GAP := 2.0
## Over the player, it clears the charge bar that rides there.
const PLAYER_HEAD := PlayerView.CHARGE_BAR_Y
## Kept this far inside the screen. A bubble that would cross the edge slides
## along instead, and its tail still points at the speaker.
const MARGIN := 8.0
## Seconds it takes to open out.
const OPEN_TIME := 0.08

var npc: Npc
## Where the top of the NPC's head is, above their feet's centre. The view knows
## their sprite, and says.
var npc_head: float = -32.0

var _px: PixelDraw
var _t: float = 0.0
var _open: float = 0.0
## Who the bubble is open over: "npc", "player", or "" while it is shut. A new
## speaker is a new bubble, opening over them.
var _speaker: String = ""

func _ready() -> void:
	_px = PixelDraw.new(self)

func _process(delta: float) -> void:
	_t += delta
	var talk := _talk()
	# A line with nothing in it — a beat of staging — gets no bubble.
	var saying := talk != null and talk.is_talking() and talk.current_line() != ""
	var who := talk.speaker() if saying else ""
	if who != _speaker:
		_speaker = who
		_open = 0.0
	# Opens with a snap, and is simply gone when the talking stops.
	_open = minf(_open + delta / OPEN_TIME, 1.0) if saying else 0.0
	if saying:
		# On whole pixels: a body at rest stands a hair off one, and an edge a
		# PIXEL wide drawn from there smears across a row either side of it.
		position = _anchor().round()
	queue_redraw()

## Whether a bubble is up, and its rect in this node's coordinates — for a
## test, which asks where it went rather than reading it off the screen.
func is_open() -> bool:
	return _open > 0.0

func box() -> Rect2:
	var talk := _talk()
	if talk == null or not talk.is_talking():
		return Rect2()
	return _box(_rows(talk.current_line()))

## The tip of the tail: over the speaker's head, in the world.
func _anchor() -> Vector2:
	if _speaker == "player":
		var player := npc.free_speaker()
		if player != npc:
			# Over the head of whoever is played as, which the view knows the
			# height of; the player's own art's, with no view to ask.
			var view := Views.of(player) as PlayerView
			var head := view.head_y() if view != null else PLAYER_HEAD
			return player.global_position + Vector2(0, head - GAP)
	return npc.global_position + Vector2(0, npc_head - GAP)

func _talk() -> FreeTalk:
	if npc == null or not is_instance_valid(npc):
		return null
	return npc.free_talk

## Wrapped from the whole line, not the part out so far, so a word never jumps
## to the next row halfway through coming in.
func _rows(text: String) -> PackedStringArray:
	return PixelDraw.wrap(text, WIDTH, MOST_ROWS)

## Centred over the tip, standing on its tail — and slid along to stay on the
## screen, which is where the camera has it, however far that is from here.
func _box(rows: PackedStringArray) -> Rect2:
	var widest := 0.0
	for row in rows:
		widest = maxf(widest, PixelDraw.ink_width(row))
	var size := Vector2(ceilf((widest + PAD.x * 2.0) / PX) * PX,
		float(rows.size()) * LINE + PAD.y * 2.0)
	var at := Vector2(-size.x * 0.5, -float(TAIL * PX) - size.y)
	var screen := get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	at.x = clampf(at.x, screen.position.x + MARGIN, maxf(screen.position.x + MARGIN, screen.end.x - MARGIN - size.x))
	at.y = maxf(at.y, screen.position.y + MARGIN)
	return Rect2(_px.snap(at), size)

func _draw() -> void:
	var talk := _talk()
	if _open <= 0.0 or talk == null or not talk.is_talking():
		return
	var rows := _rows(talk.current_line())
	var full := _box(rows)
	var e := 1.0 - pow(1.0 - _open, 3.0)
	if _open < 1.0:
		# Opening out from the tail, which is where the eye already is.
		var h := maxf(float(PX * 2), roundf(full.size.y * e / PX) * PX)
		var opening := Rect2(full.position.x, full.end.y - h, full.size.x, h)
		_px.rect(opening, Style.DIALOGUE_FILL)
		_px.frame(opening, Style.DIALOGUE_EDGE)
		return
	_px.rect(full, Style.DIALOGUE_FILL)
	_px.frame(full, Style.DIALOGUE_EDGE)
	_draw_tail(full)
	_draw_words(full, rows, talk)

## A stepped point under the box, a PIXEL of edge down either side, aimed at
## the speaker. The box's own edge is opened where the tail joins it.
func _draw_tail(full: Rect2) -> void:
	var inset := float((TAIL + 2) * PX)
	var tip := _px.snap(Vector2(clampf(0.0, full.position.x + inset, full.end.x - inset), full.end.y))
	for i in TAIL:
		var half := float((TAIL - i) * PX)
		var y := full.end.y - float(PX) + float(i * PX)
		_px.rect(Rect2(tip.x - half, y, half * 2.0, PX), Style.DIALOGUE_EDGE)
		if half > PX:
			_px.rect(Rect2(tip.x - half + PX, y, half * 2.0 - PX * 2, PX), Style.DIALOGUE_FILL)

## The line so far, a letter at a time, trembling, rippling or hopping as its
## emotion or its own effect asks — the same treatment the box gives its
## letters (`Style.letter_offset`).
func _draw_words(full: Rect2, rows: PackedStringArray, talk: FreeTalk) -> void:
	var motion := Style.letter_motion(talk.current_rule())
	var shown := int(talk.revealed)
	var ascent := roundf(FONT.get_ascent(SIZE))
	var pen := full.position + PAD
	var i := 0
	for row in rows:
		var x := pen.x
		for k in row.length():
			if i >= shown:
				return
			x += FONT.draw_char(get_canvas_item(), Vector2(x, pen.y + ascent) + Style.letter_offset(motion, i, _t),
				row.unicode_at(k), SIZE, Style.DIALOGUE_TEXT)
			i += 1
		i += 1   # the space the wrap swallowed
		pen.y += LINE
