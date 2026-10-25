class_name DigSpotView
extends Node2D

## Ground worth digging (`DigSpot`): a low mound of turned earth on the floor,
## lit from under with a slow glow and a glint or two so it is seen from across
## the room — it is always lit, the shovel or not. Being dug, earth flies off it
## and a bar over it fills; dug, it is a dark hole with the spoil heaped beside.
## Over it, while the player stands on it with the shovel in hand, the use key —
## the same `PixelDraw.key_cap` a treasure box and someone to talk to show —
## which digs while it is held.

## The mound stands on the floor at its position: its foot is the origin.
const FLOOR := 0.0
const W := 26.0
## Space between the top of the mound and the bottom of the key.
const PROMPT_GAP := 10.0
const EARTH := Color(0.34, 0.24, 0.15)
const EARTH_LIT := Color(0.52, 0.38, 0.22)
const EARTH_DARK := Color(0.18, 0.12, 0.08)
const HOLE := Color(0.06, 0.04, 0.03)
const GLOW := Color(1.0, 0.82, 0.38)
const BAR := Color(1.0, 0.82, 0.38)
const BAR_GROUND := Color(0.0, 0.0, 0.0, 0.6)

var spot: DigSpot
var _t: float = 0.0
## The key sits on its own layer, the way the treasure box's does: drawn at the
## screen's resolution in PixelDraw's blocks, never covered by whoever stands
## on the spot.
var _prompt_layer: CanvasLayer
var _prompt: Node2D
var _px: PixelDraw

func _ready() -> void:
	spot = get_parent() as DigSpot
	# Down on the floor, under whoever stands on it: sorted a little up the
	# floor from where it is, so a body on it is drawn over it.
	position.y = -4.0
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.layer = PixelCamera.LAYER + 1
	_prompt_layer.follow_viewport_enabled = true
	add_child(_prompt_layer)
	_prompt = Node2D.new()
	_prompt.draw.connect(_draw_prompt)
	_prompt_layer.add_child(_prompt)
	_px = PixelDraw.new(_prompt)

func _process(delta: float) -> void:
	_t += delta
	if spot != null and is_instance_valid(spot):
		_prompt.position = (global_position / PixelCamera.SCALE).round() * PixelCamera.SCALE
	queue_redraw()
	_prompt.queue_redraw()

func _draw() -> void:
	if spot == null or not is_instance_valid(spot):
		return
	var px := float(PixelCamera.SCALE)
	if spot.is_dug():
		# The hole, and the spoil thrown up beside it.
		draw_rect(Rect2(-W * 0.5 + px, FLOOR - px, W - px * 2.0, px), HOLE)
		draw_rect(Rect2(-W * 0.5 + px * 2.0, FLOOR - px * 2.0, W - px * 4.0, px), HOLE)
		draw_rect(Rect2(W * 0.5, FLOOR - px * 2.0, px * 3.0, px * 2.0), EARTH_DARK)
		draw_rect(Rect2(W * 0.5 + px, FLOOR - px * 3.0, px, px), EARTH_DARK)
		return
	var glow := GLOW
	glow.a = 0.14 + 0.08 * sin(_t * 3.0)
	draw_circle(Vector2(0.0, FLOOR - px * 2.0), 18.0, glow)
	# The mound: three rows of turned earth, narrower to the top, lit along it.
	draw_rect(Rect2(-W * 0.5, FLOOR - px, W, px), EARTH_DARK)
	draw_rect(Rect2(-W * 0.5 + px, FLOOR - px * 2.0, W - px * 2.0, px), EARTH)
	draw_rect(Rect2(-W * 0.5 + px * 3.0, FLOOR - px * 3.0, W - px * 6.0, px), EARTH)
	draw_rect(Rect2(-W * 0.5 + px * 4.0, FLOOR - px * 3.0, px * 3.0, px), EARTH_LIT)
	draw_rect(Rect2(-W * 0.5 + px * 2.0, FLOOR - px * 2.0, px * 2.0, px), EARTH_LIT)
	# A glint, now here and now there.
	var beat := int(_t * 1.6)
	if fmod(_t * 1.6, 1.0) < 0.35:
		var x := float((beat * 7) % 9 - 4) * px
		draw_rect(Rect2(x, FLOOR - px * 4.0, px, px), Color(1.0, 0.95, 0.7))
	if spot.digging:
		# Earth flying off the spade.
		for k in 4:
			var a := fmod(_t * 5.0 + float(k) * 0.25, 1.0)
			var side := -1.0 if k % 2 == 0 else 1.0
			var p := Vector2(side * (4.0 + a * 18.0), FLOOR - px * 3.0 - sin(a * PI) * 18.0)
			draw_rect(Rect2((p / px).floor() * px, Vector2.ONE * px), EARTH_LIT)

## The use key over a spot the player can dig, and while they dig, a bar that
## fills as it comes up.
func _draw_prompt() -> void:
	if spot == null or not is_instance_valid(spot) or spot.is_dug():
		return
	if spot.digging:
		var bar := Rect2(-W * 0.5, FLOOR - 3.0 * PixelCamera.SCALE - PROMPT_GAP - 8.0, W, 6.0)
		_px.bar(bar, spot.progress, BAR, BAR_GROUND, Color(0, 0, 0, 0.8))
	elif spot.offered():
		_px.key_cap(Vector2(0.0, FLOOR - 3.0 * PixelCamera.SCALE - PROMPT_GAP), Controls.short_label_for("interact"), _t)
