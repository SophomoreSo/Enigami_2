class_name GeneratorView
extends Node2D

## A generator (`Generator`): a squat steel box on the floor with a vent in
## its front, a yellow-and-black stripe round its foot and a lamp on its top.
## Running, it hums — it shivers a pixel now and then — and the lamp blinks
## green and gives a little light of its own (`Shine`, "generator"). Struck,
## it flashes; crashed, it is scorched dark, its lamp out, and smoke curls up
## off it until the place is set again. The crash itself is the cue's
## (`generator_crash`).
##
## Drawn in pixels of the buffer the world is drawn into (`paint`).

const S := PixelCamera.SCALE
## Its size, in pixels of the buffer: as wide, its front this tall, and its top
## this deep up the screen behind the front.
const WIDE := 12
const FRONT := 9
const TOP := 4
const STEEL := Color(0.40, 0.45, 0.50)
const STEEL_LIT := Color(0.62, 0.68, 0.73)
const STEEL_DARK := Color(0.22, 0.25, 0.30)
const EDGE := Color(0.06, 0.07, 0.09)
const VENT := Color(0.10, 0.11, 0.14)
const STRIPE := Color(0.96, 0.78, 0.18)
const LAMP_ON := Color(0.45, 1.0, 0.55)
const LAMP_DIM := Color(0.20, 0.45, 0.25)
const LAMP_OUT := Color(0.30, 0.07, 0.07)
const SCORCH := Color(0.16, 0.14, 0.13)
const SMOKE := Color(0.45, 0.45, 0.48)
const FLASH := Color(1.0, 1.0, 1.0)
## How long a blow's flash lasts, in seconds.
const FLASH_TIME := 0.08

var generator: Generator
var _t := 0.0
var _flash := 0.0
var _salt := 0

func _ready() -> void:
	generator = get_parent() as Generator
	_salt = absi(generator.get_instance_id()) % 97
	generator.damaged.connect(func(_a: Actor, _amount: float) -> void: _flash = FLASH_TIME)
	generator.crashed.connect(func(_g: Generator) -> void: Shine.put_out(self))
	generator.restored.connect(func(_g: Generator) -> void: _light())
	_light()

func _light() -> void:
	Shine.put_out(self)
	Shine.give(self, "generator")

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()

func _draw() -> void:
	var running := generator != null and is_instance_valid(generator) and generator.running()
	# A hum: a pixel's shiver now and then while it runs.
	var shiver := 1.0 if running and fmod(_t * 23.0 + _salt, 7.0) < 0.6 else 0.0
	paint(self, Vector2(shiver * S, 0.0), float(S), running, _t + _salt, _flash > 0.0)

## The generator, standing on `foot` — the middle of the floor under its front
## — a pixel of the buffer `px` across: running or crashed, `t` seconds into
## its hum, and `struck` for a blow's flash.
static func paint(c: CanvasItem, foot: Vector2, px: float, running: bool, t: float, struck: bool) -> void:
	@warning_ignore("integer_division")
	var left := -WIDE / 2
	var box := func(x: int, y: int, w: int, h: int, col: Color) -> void:
		c.draw_rect(Rect2(foot + Vector2(x, -y - h) * px, Vector2(w, h) * px), col)
	var body := STEEL if running else SCORCH
	var lit := STEEL_LIT if running else STEEL_DARK
	if struck:
		body = FLASH
		lit = FLASH
	# Its shadow on the floor, and the outline round the whole of it.
	box.call(left, -1, WIDE + 1, 1, Color(0.0, 0.0, 0.0, 0.35))
	box.call(left - 1, 0, WIDE + 2, FRONT + TOP + 1, EDGE)
	# The front: steel, darker at its sides, the stripe round its foot and a
	# vent of slots across it.
	box.call(left, 0, WIDE, FRONT, body)
	box.call(left, 0, 1, FRONT, STEEL_DARK)
	box.call(left + WIDE - 1, 0, 1, FRONT, STEEL_DARK)
	for k in WIDE:
		box.call(left + k, 0, 1, 2, STRIPE if ((k >> 1) & 1) == 0 and running else VENT)
	for k in 3:
		box.call(left + 2, 3 + k * 2, WIDE - 4, 1, VENT)
	# The top, lit, and the lamp on it: blinking green while it runs, out once
	# it is crashed.
	box.call(left, FRONT, WIDE, TOP, lit)
	box.call(left + 1, FRONT + TOP - 1, WIDE - 2, 1, STEEL_DARK)
	var lamp := LAMP_OUT
	if running:
		lamp = LAMP_ON if fmod(t, 1.0) < 0.8 else LAMP_DIM
	box.call(left + WIDE - 4, FRONT + 1, 2, 2, lamp)
	if not running:
		# A dent in its front, and smoke curling up off it.
		box.call(left + 3, 4, 3, 2, EDGE)
		for k in 3:
			var rise := fmod(t * 0.8 + float(k) / 3.0, 1.0)
			var drift := int(round(sin(t * 2.0 + float(k) * 2.1) * 2.0))
			var col := Color(SMOKE, 0.55 * (1.0 - rise))
			box.call(drift - 1 + k, FRONT + TOP + 1 + int(rise * 12.0), 2, 2, col)
