class_name SkinnedCharacter
extends RefCounted

## A character drawn the map way — see `PixelMap` for the idea. It is a folder
## under `graphics/assets/sprites/<base>/`:
##
##   <base>.skin.png    what the pixels look like: the character, once, in one
##                      frame. Reskinning is editing this file and nothing else.
##   <base>.map.png     a colour of its own for every skin pixel. Made once by
##                      `pixel_map_tool.gd` and then kept: the frames are
##                      painted in it.
##   <base>.<anim>.png  one strip per animation, frames the map's size side by
##                      side, each pixel painted in the map colour of the skin
##                      pixel it stands for.
##
## The strips are encoded as they load (`PixelMap.encode`) into what
## `skin_sprite.gdshader` reads, so `frames` only draw right on a sprite wearing
## `material()`; `resolved()` is the same frames in real colours, for anything
## that draws without one. `Sprites` loads one of these per character, once.
##
## A folder with no skin and no map is a character painted straight
## (`painted`): the same strips, `<base>.<anim>.png`, but in their own colours,
## a row of square frames each, their side the strip's height. That is what a
## sprite sheet made outside the game is — the heroes', generated frame by
## frame (graphics/assets/sprites/HEROES.md). It is drawn as it is, wears the
## status shader an atlas character wears, and cannot be reskinned.
##
## Either kind may be drawn for the four facings a body on a floor seen from
## above has (`Actor.facing_name`): a strip `<base>.<anim>.<face>.png` for
## `face` in `down`, `up` and `side` loads as the animation `<anim>_<face>`,
## and the view shows the one the body faces, the side mirrored for left
## (`ActorView.play`). A strip with no facing, `<base>.<anim>.png`, is drawn
## side on and shows for every facing, mirrored the way the body last turned —
## the atlas's characters are all drawn that way.

const SHADER_PATH := "res://graphics/assets/shaders/skin_sprite.gdshader"
const SPRITES_DIR := "res://graphics/assets/sprites/"

## How each animation plays. A strip the folder does not have is simply not an
## animation of this character; `ActorView.play` falls back to idle. `run` is
## the older name of a walk, which the player's own art and the atlas use;
## the view takes either for the other (`ActorView.ALIAS`).
const ANIMS := {
	"idle": {"fps": 5.0, "loop": true},
	"walk": {"fps": 10.0, "loop": true},
	"run": {"fps": 12.0, "loop": true},
	"hit": {"fps": 8.0, "loop": false},
	"dash": {"fps": 20.0, "loop": false},
	"cast": {"fps": 10.0, "loop": false},
	"sit": {"fps": 1.0, "loop": true},
}

## The facings a strip may be drawn for, as its file names them.
const FACES := [Actor.FACE_DOWN, Actor.FACE_UP, Actor.FACE_SIDE]

var base: String
var dir: String
## Whether the strips are in their own colours, with no skin and no map.
var painted: bool = false
var map: PixelMap
var frame_size: Vector2i
## The skin as drawn, and as every material samples it. `reskin` writes into
## this one texture, so a sprite already wearing it changes with it.
var skin: ImageTexture
var skin_image: Image
## Lookup frames: red and green name a skin pixel. Drawn through `material()`.
var frames: SpriteFrames
## Where the drawn pixels sit in the first idle frame — what `Sprites.art_rect`
## reports, so the feet are put on the floor and a portrait is cropped to the
## body.
var art_rect: Rect2
## Painted pixels that matched no map colour, per animation. Anything but zero
## is a strip painted off-palette; the pixels were dropped.
var strays: Dictionary = {}

var _lookup: Dictionary = {}   ## anim -> Array of lookup Images
var _resolved: SpriteFrames

static func folder_of(base_name: String) -> String:
	return SPRITES_DIR.path_join(base_name) + "/"

static func exists(base_name: String) -> bool:
	if base_name == "":
		return false
	var folder := folder_of(base_name)
	if ResourceLoader.exists(folder + "%s.map.png" % base_name, "Texture2D"):
		return true
	for suffix in _suffixes("idle"):
		if ResourceLoader.exists(folder + "%s.%s.png" % [base_name, suffix], "Texture2D"):
			return true
	return false

## The file names an animation's strips go by: the one for every facing, and
## one for each facing — `idle`, `idle.down`, `idle.up`, `idle.side` — paired
## with the animation each loads as.
static func _suffixes(anim: String) -> PackedStringArray:
	var out := PackedStringArray([anim])
	for face: String in FACES:
		out.append("%s.%s" % [anim, face])
	return out

## The animation the strip `<base>.<suffix>.png` loads as: `idle` for `idle`,
## `idle_down` for `idle.down`.
static func _anim_of(suffix: String) -> String:
	return suffix.replace(".", "_")

## The first strip of `anim` there is, in any facing, or null.
func _first_strip(anim: String) -> Image:
	for suffix in _suffixes(anim):
		var img := _image(dir + "%s.%s.png" % [base, suffix])
		if img != null:
			return img
	return null

## Whether the frames hold `anim` in any facing.
func _has(anim: String) -> bool:
	for suffix in _suffixes(anim):
		if frames.has_animation(_anim_of(suffix)):
			return true
	return false

## The lookup frames `art_rect` is read off: the idle's, in whichever facing
## there is one.
func _idle_looks() -> Array:
	for suffix in _suffixes("idle"):
		if _lookup.has(_anim_of(suffix)):
			return _lookup[_anim_of(suffix)]
	return []

static func load_character(base_name: String) -> SkinnedCharacter:
	var c := SkinnedCharacter.new()
	c.base = base_name
	c.dir = folder_of(base_name)
	c.skin_image = _image(c.dir + "%s.skin.png" % base_name)
	var map_image := _image(c.dir + "%s.map.png" % base_name)
	if c.skin_image == null and map_image == null:
		return _load_painted(c)
	if c.skin_image == null or map_image == null:
		push_error("SkinnedCharacter: '%s' needs a skin and a map in %s" % [base_name, c.dir])
		return null
	if map_image.get_size() != c.skin_image.get_size():
		push_error("SkinnedCharacter: '%s': the map is %s but the skin is %s"
			% [base_name, map_image.get_size(), c.skin_image.get_size()])
		return null
	c.map = PixelMap.from_image(map_image)
	c.frame_size = c.map.size
	c.skin = ImageTexture.create_from_image(c.skin_image)
	c.frames = SpriteFrames.new()
	c.frames.remove_animation("default")
	for anim: String in ANIMS:
		for suffix in _suffixes(anim):
			c._load_strip(suffix)
	if not c._has("idle"):
		push_error("SkinnedCharacter: '%s' has no idle strip" % base_name)
		return null
	var used: Rect2i = (c._idle_looks()[0] as Image).get_used_rect()
	c.art_rect = Rect2(used) if used.size.x > 0 and used.size.y > 0 else Rect2(Vector2.ZERO, Vector2(c.frame_size))
	return c

## A character painted straight: its strips as they are, the frames square and
## the idle strip's height a side. Nothing is encoded, and nothing resolved.
static func _load_painted(c: SkinnedCharacter) -> SkinnedCharacter:
	c.painted = true
	var idle := c._first_strip("idle")
	if idle == null:
		push_error("SkinnedCharacter: '%s' has no idle strip in %s" % [c.base, c.dir])
		return null
	c.frame_size = Vector2i(idle.get_height(), idle.get_height())
	c.frames = SpriteFrames.new()
	c.frames.remove_animation("default")
	for anim: String in ANIMS:
		for suffix in _suffixes(anim):
			c._load_painted_strip(suffix)
	if not c._has("idle"):
		push_error("SkinnedCharacter: '%s' has no idle strip" % c.base)
		return null
	var used: Rect2i = (c._idle_looks()[0] as Image).get_used_rect()
	c.art_rect = Rect2(used) if used.size.x > 0 and used.size.y > 0 else Rect2(Vector2.ZERO, Vector2(c.frame_size))
	return c

## The strip `<base>.<suffix>.png`, painted straight, as the animation the
## suffix names (`_anim_of`), at the rate of the motion it is a facing of.
func _load_painted_strip(suffix: String) -> void:
	var strip := _image(dir + "%s.%s.png" % [base, suffix])
	if strip == null:
		return
	if strip.get_height() != frame_size.y or strip.get_width() % frame_size.x != 0:
		push_error("SkinnedCharacter: '%s.%s' is %s, not a row of %s frames"
			% [base, suffix, strip.get_size(), frame_size])
		return
	var anim := _anim_of(suffix)
	var motion := suffix.get_slice(".", 0)
	@warning_ignore("integer_division")
	var count := strip.get_width() / frame_size.x
	var looks: Array = []
	frames.add_animation(anim)
	frames.set_animation_speed(anim, float(ANIMS[motion]["fps"]))
	frames.set_animation_loop(anim, bool(ANIMS[motion]["loop"]))
	for i in count:
		var frame := strip.get_region(Rect2i(i * frame_size.x, 0, frame_size.x, frame_size.y))
		looks.append(frame)
		frames.add_frame(anim, ImageTexture.create_from_image(frame))
	_lookup[anim] = looks
	strays[anim] = 0

## An imported texture's pixels, RGBA8. Null if there is no such file.
static func _image(path: String) -> Image:
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img

## The strip `<base>.<suffix>.png`, painted in the map's colours, as the
## animation the suffix names (`_anim_of`), at the rate of the motion it is a
## facing of.
func _load_strip(suffix: String) -> void:
	var strip := _image(dir + "%s.%s.png" % [base, suffix])
	if strip == null:
		return
	if strip.get_height() != frame_size.y or strip.get_width() % frame_size.x != 0:
		push_error("SkinnedCharacter: '%s.%s' is %s, not a row of %s frames"
			% [base, suffix, strip.get_size(), frame_size])
		return
	var anim := _anim_of(suffix)
	var motion := suffix.get_slice(".", 0)
	@warning_ignore("integer_division")
	var count := strip.get_width() / frame_size.x
	var looks: Array = []
	var dropped := 0
	frames.add_animation(anim)
	frames.set_animation_speed(anim, float(ANIMS[motion]["fps"]))
	frames.set_animation_loop(anim, bool(ANIMS[motion]["loop"]))
	for i in count:
		var painted := strip.get_region(Rect2i(i * frame_size.x, 0, frame_size.x, frame_size.y))
		var look := map.encode(painted)
		dropped += map.strays
		looks.append(look)
		frames.add_frame(anim, ImageTexture.create_from_image(look))
	_lookup[anim] = looks
	strays[anim] = dropped
	if dropped > 0:
		push_warning("SkinnedCharacter: '%s.%s' has %d pixels painted in no map colour" % [base, suffix, dropped])

## A material for a sprite showing `frames`: the skin shader, sampling this
## character's skin. One per sprite, since the status uniforms are per actor.
func material() -> ShaderMaterial:
	if painted:
		return Sprites.status_material()
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_PATH)
	m.set_shader_parameter("skin", skin)
	return m

## The same animations in real colours, resolved on the CPU: for a portrait or
## anything else drawn without the material. Built on first use, and again
## after a reskin.
func resolved() -> SpriteFrames:
	if painted:
		return frames
	if _resolved != null:
		return _resolved
	_resolved = SpriteFrames.new()
	_resolved.remove_animation("default")
	for anim: String in _lookup:
		_resolved.add_animation(anim)
		_resolved.set_animation_speed(anim, frames.get_animation_speed(anim))
		_resolved.set_animation_loop(anim, frames.get_animation_loop(anim))
		for look: Image in _lookup[anim]:
			_resolved.add_frame(anim, ImageTexture.create_from_image(PixelMap.resolve(look, skin_image)))
	return _resolved

## Swaps the skin under every frame at once — every sprite already wearing a
## material of this character changes on its next draw. The new skin has to be
## the old one's size, since the frames name its pixels by position.
func reskin(image: Image) -> bool:
	if painted:
		push_error("SkinnedCharacter: '%s' is painted straight, and has no skin to swap" % base)
		return false
	if image == null or image.get_size() != skin_image.get_size():
		push_error("SkinnedCharacter: a skin for '%s' is %s, not %s" % [base, str(image.get_size()) if image else "nothing", skin_image.get_size()])
		return false
	skin_image = image.duplicate()
	skin_image.convert(Image.FORMAT_RGBA8)
	skin.update(skin_image)
	_resolved = null
	return true

## The lookup images of an animation, for tests that want to see what was encoded.
func lookup_frames(anim: String) -> Array:
	return _lookup.get(anim, [])
