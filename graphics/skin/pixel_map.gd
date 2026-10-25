class_name PixelMap
extends RefCounted

## A colour for every pixel of a skin, and what a frame painted in those
## colours means.
##
## The idea is aarthificial's (https://gist.github.com/aarthificial/a77bf477c6bfa51507ffc1e8f18c5635,
## MIT): a character is drawn once — the *skin* — and its animation frames are
## painted not in colours but in the colours of a *map*, an image the skin's
## size where every opaque pixel has a colour of its own. A pixel of a frame
## painted in the map's colour at (x, y) means "the skin's pixel at (x, y)". So
## the frames say where each pixel of the skin goes, and the skin says what it
## looks like; change the skin and every frame changes with it.
##
## `encode` turns a painted frame into what the shader reads: red and green
## carry the column and row, alpha says a pixel is drawn. Unity did that on
## import; here the strips are encoded as they are loaded, which for a few
## dozen tiny frames costs nothing and needs no editor plugin. `resolve` is the
## same lookup on the CPU, for a portrait drawn without a material and for
## tests. `generate` makes a map for a skin that has none yet — see
## `graphics/skin/pixel_map_tool.gd`.

## Map colour, as `Color.to_rgba32()` → where it is in the skin, as Vector2i.
var lookup: Dictionary = {}
var size: Vector2i = Vector2i.ZERO
## Opaque pixels of the last frame `encode` was given that matched no map
## colour, and so were dropped. Anything but zero means a frame was painted in
## the wrong palette.
var strays: int = 0

## Keeps it distinct from black-with-alpha in a Dictionary key.
static func key_of(c: Color) -> int:
	return c.to_rgba32()

static func from_image(map: Image) -> PixelMap:
	var m := PixelMap.new()
	m.size = map.get_size()
	for y in m.size.y:
		for x in m.size.x:
			var c := map.get_pixel(x, y)
			if c.a8 == 255:
				m.lookup[key_of(c)] = Vector2i(x, y)
	return m

## A painted frame → a lookup frame: red = x, green = y, blue 0, alpha 255 for
## a pixel the map knows; clear otherwise. A skin is at most 256 pixels a side.
func encode(painted: Image) -> Image:
	var out := Image.create(painted.get_width(), painted.get_height(), false, Image.FORMAT_RGBA8)
	strays = 0
	for y in painted.get_height():
		for x in painted.get_width():
			var c := painted.get_pixel(x, y)
			if c.a8 < 255:
				continue
			var at = lookup.get(key_of(c))
			if at == null:
				strays += 1
				continue
			out.set_pixel(x, y, Color8(at.x, at.y, 0, 255))
	return out

## What the shader draws for a lookup frame over this skin, pixel for pixel.
static func resolve(frame: Image, skin: Image) -> Image:
	var out := Image.create(frame.get_width(), frame.get_height(), false, Image.FORMAT_RGBA8)
	for y in frame.get_height():
		for x in frame.get_width():
			var at := frame.get_pixel(x, y)
			if at.a8 == 0:
				continue
			var sx := mini(at.r8, skin.get_width() - 1)
			var sy := mini(at.g8, skin.get_height() - 1)
			var c := skin.get_pixel(sx, sy)
			c.a *= at.a
			out.set_pixel(x, y, c)
	return out

## A map for a skin: one colour per opaque pixel, no two alike, and neighbours
## far apart on the wheel so a painter can tell them by eye. Deterministic, so
## the same skin always gets the same map — though a map, once frames are
## painted in it, is kept as a file and never remade.
static func generate(skin: Image) -> Image:
	var out := Image.create(skin.get_width(), skin.get_height(), false, Image.FORMAT_RGBA8)
	var used := {}
	var i := 0
	for y in skin.get_height():
		for x in skin.get_width():
			if skin.get_pixel(x, y).a8 < 255:
				continue
			var c := _distinct(i, used)
			used[key_of(c)] = true
			out.set_pixel(x, y, c)
			i += 1
	return out

## The i-th colour of a golden-angle walk round the hue wheel, stepping through
## three bands of brightness and two of saturation so that near neighbours
## differ in more than hue; nudged if it has somehow been used.
static func _distinct(i: int, used: Dictionary) -> Color:
	var h := fmod(i * 0.381966, 1.0)
	var s := 0.85 if i % 2 == 0 else 0.6
	var v: float = [0.95, 0.7, 0.5][(i >> 1) % 3]
	var c := Color.from_hsv(h, s, v)
	var guard := 0
	while used.has(key_of(c)) and guard < 1000:
		c = Color.from_hsv(fmod(h + 0.013 * (guard + 1), 1.0), s, v)
		guard += 1
	c.a = 1.0
	return c
