class_name PhonePropView
extends Node2D

## The phone lying on a room's floor (`PhoneProp`): a slab of dark glass in a
## pale frame, its screen lit along the top. Ringing, it buzzes where it lies
## and rings go out of it into the room, so where the monsters are being
## called to is plain. With the player over it the interact key stands over
## it, the key cap a gate and a treasure box show (`PixelDraw.key_cap`).

const SLAB := Vector2(22.0, 6.0)
const FRAME := Color(0.78, 0.8, 0.86)
const GLASS := Color(0.06, 0.08, 0.12)
const LIT := Color(0.45, 0.85, 1.0)
const RING := Color(1.0, 0.85, 0.4)
const PROMPT_GAP := 6.0

var prop: PhoneProp
var _t := 0.0
## 0 with nobody over it, 1 with the player over it.
var _lit := 0.0
var _prompt_layer: CanvasLayer
var _prompt: Node2D
var _px: PixelDraw

func _ready() -> void:
	prop = get_parent() as PhoneProp
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
	if prop != null and is_instance_valid(prop):
		_lit = move_toward(_lit, 1.0 if prop.offered() else 0.0, delta * 6.0)
		_prompt.position = (global_position / PixelCamera.SCALE).round() * PixelCamera.SCALE
	queue_redraw()
	_prompt.queue_redraw()

func _draw() -> void:
	if prop == null or not is_instance_valid(prop):
		return
	var px := float(PixelCamera.SCALE)
	var ringing := prop.ringing()
	# Buzzing where it lies.
	var shake := Vector2(roundf(sin(_t * 60.0)) * px, 0.0) if ringing else Vector2.ZERO
	var slab := Rect2(Vector2(-SLAB.x * 0.5, -SLAB.y) + shake, SLAB)
	draw_rect(slab, FRAME)
	draw_rect(slab.grow(-px), GLASS)
	var glow := LIT
	glow.a = 0.45 + 0.55 * _lit
	if ringing:
		glow = RING
		glow.a = 0.5 + 0.5 * absf(sin(_t * 12.0))
	draw_rect(Rect2(slab.position + Vector2(px * 2.0, px), Vector2(SLAB.x - px * 4.0, px)), glow)
	if ringing:
		for k in 3:
			var phase := fmod(_t * 1.2 + float(k) / 3.0, 1.0)
			var col := RING
			col.a = (1.0 - phase) * 0.7
			draw_arc(Vector2(0.0, -SLAB.y * 0.5), 8.0 + phase * 44.0, PI, TAU, 24, col, px)

## The interact key over the phone while the player is over it.
func _draw_prompt() -> void:
	if prop == null or not is_instance_valid(prop) or not prop.offered():
		return
	_px.key_cap(Vector2(0.0, -SLAB.y - PROMPT_GAP), Controls.short_label_for("interact"), _t)
