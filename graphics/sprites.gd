extends Node

## Every character, by name, as `SpriteFrames` — from one of two places.
##
## Most are sliced from the CC0 "16x16 DungeonTileset II" atlas by 0x72. The
## pack ships one 512x512 PNG plus a list of tile rects (`DungeonAtlasFrames`),
## so the whole sprite set costs two files and no build step: every frame is an
## `AtlasTexture` window onto the same texture. Tile names follow
## `<base>_<idle|run|hit>_anim_f<n>`, except for a handful of monsters that
## ship a single unnamed loop as `<base>_anim_f<n>`.
##
## The rest are this game's own, drawn the map way: a folder per character
## under `graphics/assets/sprites/`, holding a skin, a map and painted strips —
## see `SkinnedCharacter` and `PixelMap`. Their frames name skin pixels rather
## than colours, so a sprite showing them wears `material_for(base)`, and
## anything drawing them without a material asks for `resolved_frames`.
##
## Callers never need to know which kind a name is: `has_character`,
## `frames_for`, `frame_size`, `art_rect` and `material_for` answer for both.
## See `graphics/assets/sprites/CREDITS.md`.
##
## And a tile the pack has none of is drawn in code (`Style.DRAWN_TILES`) —
## the rock is one — and handed out by `texture` like any of the atlas's.

const ATLAS_PATH := "res://graphics/assets/sprites/dungeon_atlas.png"
const SHADER_PATH := "res://graphics/assets/shaders/actor_sprite.gdshader"

const IDLE_FPS := 6.0
const RUN_FPS := 11.0
const MAX_FRAMES := 16  ## no animation in the pack is longer than this

## Every sprite is drawn at the same whole-number magnification. The room grid
## is 32px and the viewport is 1:1, so 16px art has to be blown up to read at
## all; keeping one integer factor for every character means one apparent pixel
## size across the cast and no shimmer from half-pixels. It also preserves the
## pack's own size relationships, which already track this game's hitboxes:
## the Warden's ogre towers over the Lobber's shaman, and the Arbiter over both.
const PIXEL_SCALE := 2.0

## Which atlas character stands for the player, each monster and each weapon is
## a look rather than a fact about the atlas, so it lives in `Style`.

var _atlas: Texture2D
var _atlas_image: Image
var _shader: Shader
var _rects: Dictionary = {}      ## tile name -> Rect2
var _textures: Dictionary = {}   ## tile name -> AtlasTexture
var _frames: Dictionary = {}     ## base -> SpriteFrames
var _art: Dictionary = {}        ## base -> opaque Rect2 within its tile
var _skinned: Dictionary = {}    ## base -> SkinnedCharacter, or null once looked for and missing

func _ready() -> void:
	_atlas = load(ATLAS_PATH)
	_atlas_image = _atlas.get_image()
	_shader = load(SHADER_PATH)
	for line in DungeonAtlasFrames.TILE_LIST.split("\n", false):
		var parts := line.strip_edges().split(" ", false)
		if parts.size() < 5:
			continue
		_rects[parts[0]] = Rect2(
			float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4]))

func has_tile(tile: String) -> bool:
	return _rects.has(tile)

## A character drawn the map way, loaded on first ask; null for an atlas
## character or a name nothing answers to.
func skinned(base: String) -> SkinnedCharacter:
	if _skinned.has(base):
		return _skinned[base]
	var c: SkinnedCharacter = SkinnedCharacter.load_character(base) if SkinnedCharacter.exists(base) else null
	_skinned[base] = c
	return c

## Whether `base` names a character at all, of either kind.
func has_character(base: String) -> bool:
	if base == "":
		return false
	return skinned(base) != null or has_tile("%s_idle_anim_f0" % base) or has_tile("%s_anim_f0" % base)

func texture(tile: String) -> AtlasTexture:
	if _textures.has(tile):
		return _textures[tile]
	if not _rects.has(tile):
		return _drawn(tile)
	var t := AtlasTexture.new()
	t.atlas = _atlas
	t.region = _rects[tile]
	# Without this a scaled AtlasTexture bleeds in its neighbours on the sheet.
	t.filter_clip = true
	_textures[tile] = t
	return t

## A tile drawn in code (`Style.DRAWN_TILES`), made the first time it is asked
## for: its letters turned into pixels, and the picture held the way an atlas
## tile is, as a window onto a texture — here one the size of the window.
## Null for a name that is neither.
func _drawn(tile: String) -> AtlasTexture:
	var def: Dictionary = Style.DRAWN_TILES.get(tile, {})
	if def.is_empty():
		return null
	var rows: Array = def["rows"]
	var inks: Dictionary = def["inks"]
	var w := 0
	for r in rows:
		w = maxi(w, String(r).length())
	var img := Image.create(w, rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			if inks.has(row[x]):
				img.set_pixel(x, y, inks[row[x]])
	var t := AtlasTexture.new()
	t.atlas = ImageTexture.create_from_image(img)
	t.region = Rect2(0, 0, w, rows.size())
	t.filter_clip = true
	_textures[tile] = t
	return t

## Size of a character's tiles, including the pack's padding.
func frame_size(base: String) -> Vector2:
	var sk := skinned(base)
	if sk != null:
		return Vector2(sk.frame_size)
	for tile in ["%s_idle_anim_f0" % base, "%s_anim_f0" % base, base]:
		if _rects.has(tile):
			return _rects[tile].size
	return Vector2(16, 16)

## Where the drawn pixels actually sit inside the tile. Every character is
## padded with headroom above it — up to eight rows of a twenty-eight row tile —
## so a sprite placed by its tile would hang above its own feet.
func art_rect(base: String) -> Rect2:
	if _art.has(base):
		return _art[base]
	var sk := skinned(base)
	if sk != null:
		return sk.art_rect
	var frame := Vector2.ZERO
	for tile in ["%s_idle_anim_f0" % base, "%s_anim_f0" % base, base]:
		if _rects.has(tile):
			frame = _rects[tile].size
			var used := _atlas_image.get_region(Rect2i(_rects[tile])).get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				_art[base] = Rect2(used)
				return _art[base]
			break
	_art[base] = Rect2(Vector2.ZERO, frame if frame.x > 0.0 else Vector2(16, 16))
	return _art[base]

func _collect(prefix: String) -> Array:
	var out: Array = []
	for i in MAX_FRAMES:
		var t := texture("%s_f%d" % [prefix, i])
		if t == null:
			break
		out.append(t)
	return out

func _add_anim(sf: SpriteFrames, anim: String, textures: Array, fps: float, loop: bool) -> void:
	if textures.is_empty():
		return
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for t in textures:
		sf.add_frame(anim, t)

## Every atlas character resolves to the same three animation names, so callers
## never have to know which of the pack's two naming schemes a monster uses. A
## skinned character has whatever strips its folder holds, idle among them.
func frames_for(base: String) -> SpriteFrames:
	if _frames.has(base):
		return _frames[base]
	var sk := skinned(base)
	if sk != null:
		return sk.frames
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var idle := _collect("%s_idle_anim" % base)
	var run := _collect("%s_run_anim" % base)
	if idle.is_empty():
		idle = _collect("%s_anim" % base)
	if run.is_empty():
		run = idle
	if idle.is_empty():
		push_error("Sprites: no frames for '%s'" % base)
		idle = [texture("knight_m_idle_anim_f0")]
		run = idle
	_add_anim(sf, "idle", idle, IDLE_FPS, true)
	_add_anim(sf, "run", run, RUN_FPS, true)
	_add_anim(sf, "hit", _collect("%s_hit_anim" % base), 8.0, false)
	_frames[base] = sf
	return sf

## The material a sprite showing `frames_for(base)` should wear: for an atlas
## character the status shader, for a skinned one the skin shader sampling its
## skin. Both take the same `tint`, `flash` and `flash_color` uniforms, so an
## actor view drives either the same way. A new one per sprite, since the
## uniforms are per actor.
func material_for(base: String) -> ShaderMaterial:
	var sk := skinned(base)
	if sk != null:
		return sk.material()
	return status_material()

func status_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader
	return m

## `frames_for(base)` in real colours whatever the kind — for a portrait, or
## anything else drawn without a material. Atlas frames already are.
func resolved_frames(base: String) -> SpriteFrames:
	var sk := skinned(base)
	if sk != null:
		return sk.resolved()
	return frames_for(base)

## Swaps a skinned character's skin under every sprite wearing it, at once.
## `image` has to be the skin's size. False for an atlas character or a
## mismatched image.
func reskin(base: String, image: Image) -> bool:
	var sk := skinned(base)
	return sk != null and sk.reskin(image)
