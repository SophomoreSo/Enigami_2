class_name ProjectileView
extends Node2D

## A bolt: a lit core, and the streak of where it has just been. The trail is
## sampled here rather than stored on the bolt — it is a picture of the path,
## not a fact about it.
##
## The bolt is a point on the floor, and a lobbed one is up off it by its
## `height` (`Projectile.lob`): the bolt is drawn lifted by that, and a shadow
## is drawn on the floor under it, shrinking as it goes up, so an arc reads as
## an arc on a floor seen from above. The trail is sampled where the bolt was
## drawn, so it arcs too.
##
## One sample a frame is a row of beads once a bolt covers more ground in a
## frame than a bead is wide, so where two samples stand apart the gap between
## them is drawn in (`streaks`): a quick bolt trails a line, and a slow one,
## whose beads already touch, is drawn as it always was.
##
## A bolt at laser speed — SPEED stacked to its limit, `Projectile.LASER_SPEED`
## — is all gap, a room crossed in a handful of frames, and is drawn as what it
## is: a beam from the muzzle to the bolt, bright and wide at the bolt and
## thinning back the way it came. The beam is its trail, so it has no beads.
##
## A bolt that is a thrown weapon — the rock — is drawn as the rock, turning
## over as it flies, with its trail faint behind it (`_draw_thrown`). A shuriken
## is drawn the same way, spinning far faster, an eighth of a turn at a time.
##
## A bolt is its own light, and a lamp: it lights the room it flies through in
## its own colour, and whatever it passes throws a shadow that swings round as
## it goes by. The rock is a rock, lit like one, and is a lamp only with
## something built into it to burn.

const TRAIL_LEN := 8
## The beam behind a bolt at laser speed: how solid it is at its far end and at
## the bolt, and how wide against the bolt's own radius at each.
const BEAM_ALPHA_TAIL := 0.25
const BEAM_ALPHA_HEAD := 0.85
const BEAM_WIDTH_TAIL := 0.6
const BEAM_WIDTH_HEAD := 1.8

## How fast a thrown rock turns over, in radians a second, and how solid a copy
## of it is drawn; and the colour of the dust it trails with nothing built
## into it to colour it.
const TUMBLE := 14.0
const SPIN := 40.0
const GHOST_ALPHA := 0.45
const DUST := Color(0.78, 0.75, 0.68)
## The light a bolt throws: how far it reaches in world units, how bright it
## is, and how much of it hangs in the air.
const LIGHT_REACH := 150.0
const LIGHT := 1.8
const LIGHT_AIR := 0.1
## The shadow under a lobbed bolt: how dark on the floor, and how far up a
## bolt has to be for it to have shrunk to nothing.
const SHADOW := Color(0, 0, 0, 0.35)
const SHADOW_GONE := 160.0

var bolt: Projectile
var color: Color = Style.NEUTRAL_ATTACK
## Whether this bolt is at laser speed, and so drawn as a beam.
var beam: bool = false
## Where the bolt was drawn, in the world: its floor position lifted by its
## height, so a thrown stone's trail arcs with it.
var _trail: Array[Vector2] = []
## How far a thrown rock has turned over.
var _spin: float = 0.0
## The light it throws, or null for a rock with nothing built into it.
var lamp: Lamp

func _ready() -> void:
	bolt = get_parent() as Projectile
	if bolt == null:
		return
	beam = bolt.payload != null and bolt.payload.at_limit("SPEED")
	# Where it was fired from, so a beam starts at the muzzle and not one
	# frame's flight out from it. The oldest sample of a trail is drawn clear,
	# so on any other bolt this shows nothing.
	_trail.append(_drawn_at())

## Where the bolt is drawn in the world: lifted off its floor position.
func _drawn_at() -> Vector2:
	return bolt.global_position + Vector2(0.0, -bolt.height)

## The lift, in the view's own coordinates.
func _lift() -> Vector2:
	return Vector2(0.0, -bolt.height)

func _process(delta: float) -> void:
	if bolt == null or not is_instance_valid(bolt):
		return
	color = Style.element_color(bolt.payload)
	_shine()
	if bolt.thrown != "":
		_spin += delta * TUMBLE * (1.0 if bolt.velocity.x >= 0.0 else -1.0)
	elif bolt.sticks != "":
		_spin += delta * SPIN * (1.0 if bolt.velocity.x >= 0.0 else -1.0)
	_trail.append(_drawn_at())
	if _trail.size() > TRAIL_LEN:
		_trail.pop_front()
	if lamp != null:
		lamp.position = _lift()
	queue_redraw()

## What the bolt is to the light. A bolt is its own light, and a lamp in its
## own colour. The rock is a rock, lit by whatever lamp is near it, and a lamp
## only with something built into it to burn; a copy of it gives a copy's
## share. Asked every frame rather than once: a bolt is told it is the rock
## only after it has been put in the world (`Attacks.spawn`).
func _shine() -> void:
	var rock := bolt.thrown != ""
	var lit := not rock or (bolt.payload != null and not bolt.payload.elements.is_empty())
	material = null if rock else Lighting.glow()
	if lamp == null:
		if not lit:
			return
		lamp = Lamp.of(color, LIGHT_REACH)
		lamp.volume = LIGHT_AIR
		add_child(lamp)
	lamp.visible = lit
	lamp.color = color
	lamp.energy = LIGHT * (GHOST_ALPHA if bolt.ghost else 1.0)

## How far along the trail sample `i` is, 0 at the oldest to just short of 1 at
## the bolt, and the bead drawn there: how big, and how solid.
func _along(i: int) -> float:
	return float(i) / float(maxi(_trail.size(), 1))

func _bead_radius(i: int) -> float:
	return bolt.radius * (0.3 + _along(i) * 0.7)

func _bead_alpha(i: int) -> float:
	return _along(i) * 0.4

## The lines that join the trail up, oldest first: {from, to, width, color}.
##
## A beam is every stretch of the trail, sample to sample. Any other bolt gets
## a line only where two beads do not reach each other — from the edge of one
## to the edge of the next, so it lies over neither — as wide as the smaller
## and as solid as the bead it runs up to: the trail reads as one tail at any
## pace and at any frame rate.
func streaks() -> Array:
	var out: Array = []
	if bolt == null or not is_instance_valid(bolt):
		return out
	for i in range(1, _trail.size()):
		var from := _trail[i - 1]
		var to := _trail[i]
		var c := color
		if beam:
			var t := _along(i)
			c.a = lerpf(BEAM_ALPHA_TAIL, BEAM_ALPHA_HEAD, t)
			out.append({"from": from, "to": to, "color": c,
				"width": bolt.radius * lerpf(BEAM_WIDTH_TAIL, BEAM_WIDTH_HEAD, t)})
			continue
		var gap := from.distance_to(to)
		if gap <= _bead_radius(i - 1) + _bead_radius(i):
			continue
		var along := (to - from) / gap
		c.a = _bead_alpha(i)
		out.append({"from": from + along * _bead_radius(i - 1), "to": to - along * _bead_radius(i),
			"color": c, "width": _bead_radius(i - 1) * 2.0})
	return out

func _draw() -> void:
	if bolt == null or not is_instance_valid(bolt):
		return
	if bolt.height > 0.0:
		_draw_shadow()
	if bolt.thrown != "" or bolt.sticks != "":
		_draw_thrown()
		return
	for s: Dictionary in streaks():
		draw_line(to_local(s["from"]), to_local(s["to"]), s["color"], s["width"])
	if not beam:
		for i in _trail.size():
			var c := color
			c.a = _bead_alpha(i)
			draw_circle(to_local(_trail[i]), _bead_radius(i), c)
	draw_circle(_lift(), bolt.radius, color)
	draw_circle(_lift(), bolt.radius * 0.5, Color(1, 1, 1, 0.9))

## The shadow on the floor under a bolt up in its arc: a flat disc at its floor
## position, smaller the higher it is.
func _draw_shadow() -> void:
	var shrink := 1.0 - clampf(bolt.height / SHADOW_GONE, 0.0, 0.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, bolt.radius * 1.2 * shrink, SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The rock, thrown: the tile itself, turned over a quarter at a time as it goes
## — a picture drawn in whole pixels, turned any other way, is no longer one —
## with a faint trail behind it, in the colour of what its graph built into it
## or of dust. A copy of it is drawn see-through.
func _draw_thrown() -> void:
	var tex := Sprites.texture(Style.shuriken_art(_spin) if bolt.sticks != "" else Style.weapon_art(bolt.thrown))
	var built := bolt.payload != null and not bolt.payload.elements.is_empty()
	var a := GHOST_ALPHA if bolt.ghost else 1.0
	var tint := color if built else DUST
	for i in _trail.size():
		var c := tint
		c.a = _bead_alpha(i) * 0.6 * a
		draw_circle(to_local(_trail[i]), _bead_radius(i) * 0.6, c)
	var at := _lift()
	if built:
		draw_circle(at, bolt.radius * 1.6, Color(color.r, color.g, color.b, 0.3 * a))
	if tex == null:
		draw_circle(at, bolt.radius, Color(DUST.r, DUST.g, DUST.b, a))
		return
	# A shuriken's turn is in its two tiles; the rock's, a quarter at a time.
	var turn := 0.0 if bolt.sticks != "" else roundf(_spin / (PI * 0.5)) * PI * 0.5
	draw_set_transform(at, turn, Vector2.ONE * Sprites.PIXEL_SCALE)
	draw_texture(tex, -(tex.get_size() * 0.5).floor(), Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
