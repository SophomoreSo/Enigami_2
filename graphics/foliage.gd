class_name Foliage
extends Node2D

## A patch of plants on a floor — grass, flowers, a bush — swaying in the wind
## and bending where something moves through it. It is the foliage of
## aarthificial's PixelGraphics package ("Interactive Foliage Shaders for
## Unity", https://www.youtube.com/watch?v=ecYWvfMoRIM), in its pixel-art form.
##
## A patch is a picture and a mask. The picture is the plants, drawn here once,
## pixel by pixel, out of the kind's numbers and its colours, standing on the
## picture's bottom edge, which is the floor. The mask is the package's
## displacement mask, a second picture the same size saying how far each pixel
## may move — nothing at the ground, all of it at the tip; R for a push, G for
## the wind. `foliage.gdshader` draws every pixel of the picture from the one a
## whole number of pixels away that the velocity buffer and the wind ask for,
## weighed by the mask. So nothing is moved here once it has grown, and a room
## of foliage costs nothing a frame but the shader.
##
## Round the plants is a clear margin for them to lean into, as wide as the
## furthest a push and the wind together move a tip: the package's pixel-art
## shaders want a sprite's mesh bigger than its art for the same reason.
##
## Grass and flowers sway the way the package's grass shader has them: back and
## forth along the ground, and lower at the tip the further they lean. A bush
## sways the way its foliage shader does, any way at all: its crown moves as a
## whole and most at the top of its middle, over a base that does not — its
## mask is the demo bush's.
##
## A kind of foliage is a row of `foliage` in the content database and its
## numbers are the ones below; `of` makes a patch of a kind, and `growths` says
## what a room grows of each ("Foliage" in data/db/README.md). What a kind looks
## like is `Style.FOLIAGE_LOOK`. Nothing here is a rule.

## The world units to a pixel of the picture: one pixel of the buffer the
## pixel camera draws the world into.
const S := PixelCamera.SCALE
const SHADER := preload("res://graphics/assets/shaders/foliage.gdshader")
## How a blade's mask rises up its length: its height over the tallest's, to
## this power, so the root stays put and the bend is in the top.
const CURVE := 1.4
## How much of a push and of the wind a bush's crown takes as a whole; the top
## of it takes the rest. The demo bush's mask is 0.64 under a bright patch.
const CROWN := 0.6
## The rows of a bush over the floor its mask rises through, from nothing at
## the ground to CROWN: the base it stands on, which does not move.
const ROOTED := 3
## How many pixels apart the swell of a patch of blades rises and falls.
const SWELL := 5
## How many pixels in from each end of a patch of blades it thins to its
## shortest, so a patch is a tuft and not a hedge.
const TAPER := 4.0

## --- what the kind is --------------------------------------------------------
## The numbers a kind of foliage is, as its row of `foliage` has them; made by
## hand, a patch is grass.
var kind: String = "grass"
## What is drawn: `blades` of grass, `flowers` on stems, or a `bush`.
var form: String = "blades"
## Which way it gives: `along` the ground, lower as it leans; or `any` way.
var sway: String = "along"
## The shortest and the tallest plant, in pixels of the picture.
var shortest: int = 3
var tallest: int = 8
## The share of a patch's columns a plant stands in.
var density: float = 0.85
## How far a full push moves a tip, and how far the wind sways one, in pixels.
var push: float = 5.0
var wind: float = 1.5
## Its colours: the kind's look.
var look: Dictionary = Style.foliage_look("grass")

## --- the patch -----------------------------------------------------------------
## How many pixels of floor it stands on, from this node's position rightward.
var span: int = 0
## The clear pixels round the plants for them to lean into.
var margin: int = 0
## The plants, and how far each pixel of them may move. The floor is the
## bottom edge of both.
var picture: Image
var mask: Image

var _texture: ImageTexture
## A bush's crown: the height of its top above the floor, and the column
## across the patch its middle stands at.
var _top := 0
var _middle := 0.0

## --- the table ---------------------------------------------------------------

## Every kind of foliage in the table, by id.
static func kinds() -> PackedStringArray:
	var out := PackedStringArray()
	for r in Db.rows("SELECT id FROM foliage ORDER BY id"):
		out.append(String(r["id"]))
	return out

## A kind as the table has it — its row of `foliage` — or {} for no such kind.
static func source(id: String) -> Dictionary:
	var found := Db.records("foliage", "id = ?", [id])
	return found[0] if not found.is_empty() else {}

## A patch of kind `id`, not grown yet: its row's numbers, and its look. A kind
## that is not in the table is said loudly, and the patch is grass.
static func of(id: String) -> Foliage:
	var f := Foliage.new()
	var row := source(id)
	if row.is_empty():
		push_error("Foliage: no kind of foliage called '%s' in %s" % [id, Db.PATH])
		return f
	f.kind = id
	f.form = String(row["form"])
	f.sway = String(row["sway"])
	f.shortest = int(row["shortest"])
	f.tallest = int(row["tallest"])
	f.density = float(row["density"])
	f.push = float(row["push"])
	f.wind = float(row["wind"])
	f.look = Style.foliage_look(id)
	return f

## What a room grows: the rows of `growths`, each the kind (`foliage`), how
## many patches (`fewest` to `most`) and how long each is in cells (`shortest`
## to `longest`), in the order they were written — which is the order they are
## drawn in.
static func growths() -> Array:
	return Db.records("growths", "", [], "rowid")

## --- growing -------------------------------------------------------------------

## Grows the patch `pixels` of floor wide, out of `roll` — the same roll grows
## the same plants — and hands the picture and its mask to the shader.
func grow(pixels: int, roll: int) -> void:
	span = maxi(1, pixels)
	margin = int(ceil(push + wind)) + 1
	var w := span + margin * 2
	var h := tallest + margin
	picture = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	mask = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = roll
	match form:
		"flowers":
			_flowers(rng)
		"bush":
			_bush(rng)
		_:
			_blades(rng)
	_weigh()
	_texture = ImageTexture.create_from_image(picture)
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("mask", ImageTexture.create_from_image(mask))
	m.set_shader_parameter("any_way", sway == "any")
	m.set_shader_parameter("push", push)
	m.set_shader_parameter("wind", wind)
	m.set_shader_parameter("tall", float(maxi(tallest, 1)))
	m.set_shader_parameter("reach", float(margin))
	m.set_shader_parameter("pixel", float(S))
	material = m
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

## A pixel of a plant: `c` pixels along the patch from its left end, `k`
## pixels up from the floor — the first row of the plant is k = 1.
func _put(c: int, k: int, color: Color) -> void:
	var x := margin + c
	var y := picture.get_height() - k
	if x >= 0 and y >= 0 and x < picture.get_width() and y < picture.get_height():
		picture.set_pixel(x, y, color)

func _colour(key: String) -> Color:
	return look.get(key, Style.foliage_look("grass").get(key, Color.WHITE))

## Blades of grass: one in a column, as often as `density` says, as tall as a
## swell rolling along the patch says, thinning to the shortest at the ends.
## Each is dark at the root and light at the tip, and the tallest lean a pixel
## at the top.
func _blades(rng: RandomNumberGenerator) -> void:
	var dark := _colour("dark")
	var mid := _colour("mid")
	var light := _colour("light")
	var swell := _swell(rng)
	for c in span:
		if rng.randf() >= density:
			continue
		var ends := clampf(minf(float(c) + 0.5, float(span - c) - 0.5) / TAPER, 0.0, 1.0)
		var t := clampf(swell[c] + rng.randf_range(-0.2, 0.2), 0.0, 1.0) * ends
		var h := int(round(lerpf(float(shortest), float(tallest), t)))
		var lean := rng.randi_range(-1, 1) if h >= 4 else 0
		var turn := h - int(ceil(float(h) / 3.0))
		var body := dark if rng.randf() < 0.4 else mid
		for k in range(1, h + 1):
			var col := body
			if k == 1:
				col = dark
			elif (k == h and h >= 3) or (k == h - 1 and h >= 6):
				col = light
			_put(c + (lean if k > turn else 0), k, col)

## A smooth roll from 0 to 1 and back along the patch, a knot every SWELL pixels.
func _swell(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var knots := PackedFloat32Array()
	@warning_ignore("integer_division")
	for i in span / SWELL + 2:
		knots.append(rng.randf())
	var out := PackedFloat32Array()
	out.resize(span)
	for c in span:
		var f := float(c) / float(SWELL)
		var i := int(f)
		var t := f - float(i)
		out[c] = lerpf(knots[i], knots[i + 1], t * t * (3.0 - 2.0 * t))
	return out

## Flowers: a stem as often as `density` says, with room left between them for
## a head of four petals round a heart, and now and then a leaf.
func _flowers(rng: RandomNumberGenerator) -> void:
	var stem := _colour("stem")
	var leaf := _colour("light")
	var heart := _colour("heart")
	var petals: Array = look.get("petals", [heart])
	var c := 1
	while c < span - 1:
		if rng.randf() >= density:
			c += 1
			continue
		# The head's middle, a pixel under the top petal: the flower is `top` tall.
		var top := rng.randi_range(maxi(shortest, 3), maxi(tallest, 3))
		var h := top - 1
		var petal: Color = petals[rng.randi() % petals.size()]
		for k in range(1, h):
			_put(c, k, stem)
		if h >= 4:
			_put(c + (1 if rng.randf() < 0.5 else -1), rng.randi_range(2, h - 2), leaf)
		_put(c, h, heart)
		_put(c - 1, h, petal)
		_put(c + 1, h, petal)
		_put(c, top, petal)
		_put(c, h - 1, petal)
		c += 4

## A bush: a mound of overlapping discs across the patch, highest in the
## middle and down to the floor at its ends, filled to the floor beneath, lit
## from above on the left and in shadow at its foot. No stems show: a crown on
## bare stems, this small, stands on them like legs and reads as something
## that walks.
func _bush(rng: RandomNumberGenerator) -> void:
	var dark := _colour("dark")
	var mid := _colour("mid")
	var light := _colour("light")
	_top = rng.randi_range(shortest, tallest)
	_middle = float(span - 1) * 0.5
	var crown := {}
	@warning_ignore("integer_division")
	var n := rng.randi_range(3, 4) + span / 12
	for i in n:
		var along := (float(i) + 0.5) / float(n)
		var r := rng.randf_range(float(_top) * 0.32, float(_top) * 0.46)
		var cx := lerpf(r - 0.5, float(span) - r - 0.5, along) + rng.randf_range(-1.0, 1.0)
		# The middle discs stand tallest; those at the ends sit on the floor.
		var rise := 1.0 - absf(along - 0.5) * 2.0
		var cy := lerpf(r, float(_top) - r + 0.5, rise)
		for c in span:
			for k in range(1, _top + 1):
				if Vector2(float(c) - cx, float(k) - cy).length() <= r:
					crown[Vector2i(c, k)] = true
	# Down to the floor under every column the crown covers.
	for p: Vector2i in crown.keys():
		for k in range(1, p.y):
			crown[Vector2i(p.x, k)] = true
	for p: Vector2i in crown:
		var col := mid
		if not crown.has(p + Vector2i(0, 1)) or not crown.has(p + Vector2i(-1, 1)):
			col = light
		elif p.y <= 2 or (not crown.has(p + Vector2i(1, 0)) and p.y <= 4):
			col = dark
		elif rng.randf() < 0.14:
			col = dark if rng.randf() < 0.55 else light
		_put(p.x, p.y, col)

## The mask: for blades and flowers, the height above the floor over the
## tallest plant's, to CURVE, the same all along the patch — a push leans a
## whole row of pixels the same way, a staircase from the root. For a bush, a
## base rising to CROWN over its first ROOTED rows under a crown that moves as
## a whole and most at the top of its middle. R and G alike: the wind moves
## what a push does.
func _weigh() -> void:
	var h := mask.get_height()
	for y in h:
		var k := h - y
		for x in mask.get_width():
			var m := 0.0
			if form == "bush":
				m = _crown_weight(x - margin, k)
			else:
				m = pow(clampf(float(k - 1) / float(maxi(tallest - 1, 1)), 0.0, 1.0), CURVE)
			mask.set_pixel(x, y, Color(m, m, 0.0, 1.0))

func _crown_weight(c: int, k: int) -> float:
	if k < ROOTED:
		return CROWN * float(k - 1) / float(ROOTED - 1)
	var reach := Vector2(maxf(float(span) * 0.3, 1.0), maxf(float(_top) * 0.4, 1.0))
	var off := Vector2(float(c) - _middle, float(k - _top)) / reach
	return CROWN + (1.0 - CROWN) * exp(-off.length_squared())

## --- the picture ---------------------------------------------------------------

## The picture, standing on this node's position: its bottom edge on the floor,
## its margin out to either side and above.
func _draw() -> void:
	if _texture == null:
		return
	var size := Vector2(picture.get_size())
	draw_texture_rect(_texture, Rect2(Vector2(-margin, -size.y) * S, size * S), false)

## Every pixel of a plant, as (column along the patch, height above the floor),
## for asking where the plants are without drawing them.
func plant_pixels() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if picture == null:
		return out
	var h := picture.get_height()
	for y in h:
		for x in picture.get_width():
			if picture.get_pixel(x, y).a > 0.0:
				out.append(Vector2i(x - margin, h - y))
	return out
