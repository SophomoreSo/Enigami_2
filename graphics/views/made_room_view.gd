class_name MadeRoomView
extends RoomView

## A room made in the map creator (`MadeRoom`), drawn from above: its walls
## and floor as any room's (`RoomView`), and what was put about it
## (`MadeRoom.dressing`) made of the game's own things. Grass, flowers and a
## bush are patches of foliage (`Foliage`) that lean where somebody walks; a
## lantern, a fire, glowing caps and fireflies stand where they were put and
## give the light their kind of shining thing gives (`Shine`, the `lights`
## rows); a fern stands where it was put. A spotlight hangs high over its cell,
## lights the floor under it in the foot of its cone and nowhere else, and what
## stands in that light throws its shadow on the floor away from it
## (`OverheadShadows`). Nothing is rolled: a made room has
## what was put in it, and none of the grass a raid's rooms are grown with.
##
## The walls' kinds — stone, earth, bark, planks, leaves, glass — are all the
## atlas's stone for now; a tileset of the game's own for each is to come
## (PLAN.md, step 15). The magic stone goes and comes back with magic: the
## tiles are laid again when it does (`ground_changed`).

## What is put about the room, by the mark that lays each: the foliage, by
## the kind of patch it grows; the lights, by the row of `lights` each gives;
## and the fern, which only stands there.
const FOLIAGE := {"g": "grass", "f": "flowers", "b": "bush"}
const LIGHTS := {"L": "lantern", "B": "lightbulb", "F": "fire", "H": "fireplace", "m": "mushrooms", "*": "fireflies",
	"S": "spotlight"}
const FERN := "n"
## A spotlight's mark, and how high over the middle of its cell it hangs, in
## world units: over everyone's head, which is what its shadows are cast from.
const SPOTLIGHT := "S"
const SPOTLIGHT_HANG := 120.0
## The cone of light under it, as faint as it is where it leaves the bulb and
## where it meets the floor.
const SPOTLIGHT_HAZE := Vector2(0.2, 0.03)

var made: MadeRoom
## The props standing about the room, in the order they were put down.
var props: Array = []
## The shadows the spotlights cast, in a room that has any.
var shadows: OverheadShadows = null

## Something put about the floor that is not a plant: a lantern, a fire,
## glowing caps, fireflies, a fern — a small picture of it at its cell, which
## sorts among the bodies by where it stands, and the light it gives.
class Prop extends Node2D:
	var mark: String = ""
	var salt: int = 0
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		if mark == "F" or mark == "*":
			queue_redraw()

	func _draw() -> void:
		MadeRoomView.paint_prop(self, mark, Vector2.ZERO, float(PixelCamera.SCALE), _t, salt)

## `mark`'s picture, standing with its feet at `foot` on `c`, a pixel of the
## buffer `px` across, `t` seconds in and `salt` telling one from the next:
## as a room draws it moving, and as the creator's table draws it still
## (`MapTiles.paint_prop_still`).
static func paint_prop(c: CanvasItem, mark: String, foot: Vector2, px: float, t: float, salt: int) -> void:
	var box := func(x: int, y: int, w: int, h: int, col: Color) -> void:
		c.draw_rect(Rect2(foot + Vector2(x, -y - h) * px, Vector2(w, h) * px), col)
	match mark:
		"S":
			paint_spotlight(c, foot + Vector2(0.0, -Room.CELL * 0.5 * px / float(PixelCamera.SCALE)), px)
		"L", "B":
			# A lantern on a post: the post, the paper, and the flame in it.
			box.call(-1, 0, 2, 10, Color(0.30, 0.22, 0.14))
			box.call(-3, 10, 6, 7, Color(0.95, 0.80, 0.45))
			box.call(-2, 12, 4, 3, Color(1.0, 0.95, 0.75))
			box.call(-4, 17, 8, 1, Color(0.25, 0.18, 0.12))
		"F", "H":
			# A ring of stones, and the flames over them, never still.
			box.call(-6, 0, 12, 2, Color(0.35, 0.33, 0.32))
			var lick := Lamp.flicker(t, salt)
			var high := int(4.0 + lick * 5.0)
			box.call(-3, 1, 6, high, Color(1.0, 0.55, 0.2))
			box.call(-1, 2, 2, maxi(high - 2, 1), Color(1.0, 0.9, 0.5))
		"m":
			# Glowing caps, three of them.
			for k in 3:
				box.call(-5 + k * 4, 0, 1, 2, Color(0.75, 0.75, 0.7))
				box.call(-6 + k * 4, 2, 3, 2, Color(0.36, 0.96, 0.9))
		"*":
			# Fireflies, drifting about over the floor.
			for k in 4:
				var a := t * (0.6 + float(k) * 0.2) + float(salt + k)
				var at := Vector2(cos(a) * 10.0, -8.0 - sin(a * 1.3) * 6.0)
				var on := 0.4 + 0.6 * maxf(sin(t * 2.0 + float(k) * 1.7), 0.0)
				c.draw_rect(Rect2(foot + (at / px).floor() * px, Vector2.ONE * px), Color(0.82, 1.0, 0.45, on))
		"n":
			# A fern: fronds fanning out from the root.
			for k in 5:
				var way := Vector2.from_angle(-PI * 0.5 + (float(k) - 2.0) * 0.45)
				c.draw_line(foot, foot + way * 14.0, Color(0.24, 0.52, 0.26), px)
				c.draw_line(foot + way * 14.0, foot + way * 14.0 + Vector2(0, -3.0), Color(0.36, 0.68, 0.34), px)

## A spotlight hanging over `under` on the floor of `c`, a pixel of the buffer
## `px` across: the cord up out of sight, the shade and the bulb, and the cone
## of light falling from it to the sides of the ellipse it lights
## (`lights`' `spotlight` row). `hang` and `wide`, in world units, draw it
## hung lower and its cone narrower, as the creator's palette does to fit it in
## a cell; left out, it is as it hangs in a room.
static func paint_spotlight(c: CanvasItem, under: Vector2, px: float, hang: float = SPOTLIGHT_HANG,
		wide: float = -1.0) -> void:
	var k := px / float(PixelCamera.SCALE)
	var bulb := under + Vector2(0.0, -hang * k)
	var row := Shine.source("spotlight")
	if wide < 0.0:
		wide = float(row.get("size_x", 300.0)) * 0.5
	wide *= k
	var warm := Color.html(String(row.get("color", "#ffd9a0")))
	c.draw_polygon(PackedVector2Array([bulb + Vector2(-2.5, 1.0) * px, bulb + Vector2(2.5, 1.0) * px,
		under + Vector2(wide, 0.0), under + Vector2(-wide, 0.0)]),
		PackedColorArray([Color(warm, SPOTLIGHT_HAZE.x), Color(warm, SPOTLIGHT_HAZE.x),
			Color(warm, SPOTLIGHT_HAZE.y), Color(warm, SPOTLIGHT_HAZE.y)]))
	c.draw_line(bulb + Vector2(0.0, -6.0) * px, bulb + Vector2(0.0, -6.0) * px + Vector2(0.0, -minf(260.0, hang) * k),
		Color(0.08, 0.08, 0.1), px)
	c.draw_colored_polygon(PackedVector2Array([bulb + Vector2(-5, 0) * px, bulb + Vector2(5, 0) * px,
		bulb + Vector2(2.5, -6) * px, bulb + Vector2(-2.5, -6) * px]), Color(0.16, 0.17, 0.2))
	c.draw_rect(Rect2(bulb + Vector2(-2, 0) * px, Vector2(4, 2) * px), warm.lightened(0.5))

func _ready() -> void:
	super._ready()
	made = room as MadeRoom
	# The magic stone went, or came back: the tiles and the shadows' edges
	# are laid again.
	if made != null:
		made.ground_changed.connect(_on_reshaped)

func _on_built() -> void:
	super._on_built()
	_dress()

## A made room grows nothing of its own: what grows in it was put there.
func _grow_foliage() -> void:
	for p in plants:
		if is_instance_valid(p):
			p.queue_free()
	plants.clear()

## What was put about the room, cell by cell: a run of one kind of foliage
## along a row is one patch, and everything else stands in its cell.
func _dress() -> void:
	for p in props:
		if is_instance_valid(p):
			p.queue_free()
	props.clear()
	if shadows != null and is_instance_valid(shadows):
		shadows.queue_free()
	shadows = null
	if made == null:
		return
	for y in made.rows:
		var x := 0
		while x < made.cols:
			var mark := made.dressing_at(x, y)
			if FOLIAGE.has(mark):
				var run := 1
				while made.dressing_at(x + run, y) == mark:
					run += 1
				_plant(String(FOLIAGE[mark]), Vector2i(x, y), run, hash(Vector2i(x, y)))
				x += run
				continue
			if LIGHTS.has(mark) or mark == FERN:
				var prop := Prop.new()
				prop.mark = mark
				prop.salt = x * 31 + y
				prop.position = made.cell_center(x, y) + Vector2(0.0, Room.CELL * 0.5)
				prop.visibility_layer = PixelCamera.WORLD_LAYER
				if mark == SPOTLIGHT:
					# It hangs over everyone's head, and what it draws is light
					# and the dark of its own fitting: nothing lights it.
					prop.z_index = 1
					prop.material = Lighting.glow()
				add_child(prop)
				props.append(prop)
				if mark == SPOTLIGHT:
					# Its light lands on the middle of its cell, under it.
					Shine.give(prop, String(LIGHTS[mark]), Vector2(0.0, -Room.CELL * 0.5))
					_cast_from(prop)
				elif LIGHTS.has(mark):
					Shine.give(prop, String(LIGHTS[mark]), Vector2(0.0, -8.0))
			x += 1

## The shadows `spotlight` casts, cast with the rest: on the floor, over it and
## under everything standing, as cracks and stains are.
func _cast_from(spotlight: Prop) -> void:
	if shadows == null:
		shadows = OverheadShadows.new()
		shadows.visibility_layer = PixelCamera.WORLD_LAYER
		shadows.z_index = -1
		add_child(shadows)
	shadows.lamps.append(spotlight)
