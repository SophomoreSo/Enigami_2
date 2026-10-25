class_name Lighting
extends Node

## The light the picture is shown in: the passes the world is drawn through
## once it has been drawn, after aarthificial's deferred lights ("Deferred
## Lights - Pixel Renderer Devlog #1",
## https://www.youtube.com/watch?v=R6vQ9VmMz2w). Nothing in the world is lit
## as it is drawn. The world is drawn first, unlit, into a g-buffer of two
## textures — its colours, and the way every pixel of it faces — and the
## light is worked out afterwards, once for the whole picture, a lamp at a
## time:
##
##   colours   the world as it always was drawn: the `PixelCamera`'s own
##             buffer, which this is handed.
##   normals   the same world drawn a second time, for how it faces.
##   shadows   for each lamp that throws them, where its light does not
##             reach.
##   light     the picture that is shown: the colours times the light there
##             is with no lamp lit, and then every lamp added to it — a mesh
##             over what it can reach, reading the first two under each of
##             its pixels and leaving out what the third marks.
##
## A light is the property of whatever gives it — a lantern, a fire, a strip
## of neon — given it as a `Shine`, of one of Blender's four types: a point, a
## sun, a spot or an area. A `Lamp` is a light of the older kind, a node put
## where the light is, which the fight still lights with. What throws a
## shadow is a `ShadowCaster`. All of them are asked for here every frame the
## way the velocity buffer asks what is moving. All of it is on the pixel
## camera's grid, a pixel of every buffer to a pixel of the picture, so light
## falls in the same pixels the world is drawn in.
##
## Where the video's renderer does what a canvas cannot, the same picture is
## reached another way:
##
##   * It fills both textures of the g-buffer in one pass. A canvas item draws
##     into one target, so the normals are a second viewport over the same
##     world. Most of what is drawn says nothing in it and is flat: lit alike
##     from anywhere. What faces some way says so — a sprite through its
##     shader, which works the normals out from its own edge
##     (`lighting.gdshaderinc`), and anything drawn in code by drawing them:
##     a twin of itself on NORMAL_LAYER, which only that viewport sees,
##     painted in `faces`'s colours (`RoomView` does its rock's this way).
##   * It marks shadows in the stencil buffer. A canvas cannot, so they are
##     marked in pictures of their own, a colour of one to a lamp
##     (`shadow.gdshader`). There are MASKS of those and three colours in
##     each, which is how many lamps can throw shadows at once.
##
## And a body stands on the floor the lights are on, seen a little from the
## front: it is lit across its face as the rock is, by the way its edge
## faces, and it throws a patch of shadow on the floor from its feet, away
## from the light — FEET_LEAN of the way the light is off it, never further
## than FEET_REACH — darkest at its feet and fading out. The patch darkens
## whatever is there but a body, by FEET_DARK, marked in the light's colour
## of a mask by how dark it is (`figure_shadow.gdshader`); where a body
## stands is one more picture the lights read (`bodies.gdshader`), so no
## body is darkened by a shadow on the floor under it. A sun throws it the
## way the sun travels. A body's own light inside it throws none.
##
## And one thing the video's picture has no place for: what gives its own
## light. A bolt in a dark room is not dark. Whatever wears `glow()` is left
## as it was drawn, by the lamps and by the dark alike.
## And what is seen out past a room — the sky through its arches — which is
## lit by nothing in the room and dimmed by nothing in it: a room marks it
## (a look's `room`), and only a light out there with it
## (`Shine.out_there`) lights it.
##
## With no lamp on the screen and the room as light as it ever was there is
## nothing to work out, and nothing is: the camera shows the colours as they
## were drawn, and the world is drawn once. So a screen nobody has lit costs
## what it did before any of this.
##
## Glass is worked out after all of this, in the picture it comes to, by a pass
## of its own (`Glazing`): what is seen through glass is seen lit, and what a
## mirror shows is shown lit.
##
## And a lit one little more, as long as the back of the picture stays out of
## the normals: a room's tile field is most of what a frame costs to draw, it
## is flat, and the normals start out flat — so what is on BACKDROP_LAYER is
## drawn into the colours and not a second time for nothing.
##
## Float buffers, as the velocity buffer's are, and for its reasons: only the
## compatibility renderer keeps what is drawn into one as it was drawn.

## The world units to a pixel of every buffer: the pixel camera's.
const S := PixelCamera.SCALE
## What is drawn on this render layer is drawn into the normals and nowhere
## else: the twin of something drawn in code, saying how it faces.
const NORMAL_LAYER := 1 << 18
## What is drawn on this render layer, and no other, is the back of the
## picture: flat, behind everything that faces any way or gives any light,
## and a great deal of it — a room's tile field, a look's painted depths. It
## is drawn into the colours and left out of the normals.
const BACKDROP_LAYER := 1 << 17
## How many times over a normal is written, so that a colour drawn into the
## same buffer is nothing beside it. `lighting.gdshaderinc` has the same
## number.
const RELIEF := 256.0
## The pictures shadows are marked in, and the lamps to each: one a colour.
const MASKS := 4
const PER_MASK := 3
## How many lamps can throw shadows at once.
const SHADOWS := MASKS * PER_MASK
## What a lamp's colour of a mask is marked with where its light does not
## reach at all: more than the shadows bodies throw out of a round light's
## plane, marked by how dark they are, ever add up to.
## `lighting.gdshaderinc` has the same number.
const SOLID := 64.0
## The patch of shadow a body leaves on the floor: FEET_DEPTH down from its
## feet, leaning away from the light FEET_LEAN of the way the light is off it
## but never more than FEET_REACH, in world units — and under a sun, half of
## FEET_REACH the way the sun travels; FEET_DARK at the feet and a third of
## that at its far end.
const FEET_DEPTH := 6.0
const FEET_LEAN := 0.9
const FEET_REACH := 40.0
const FEET_DARK := 0.6
## How far past a lamp's own reach an edge's shadow is thrown, in reaches:
## far enough that the strip's far end is never inside the lamp's square.
const THROW := 64.0
## How near a lamp a surface has to be, in world units, before the way it
## faces starts to count for less: right under one, the way to it is any way.
const CLOSE := 12.0

const LIGHT := preload("res://graphics/assets/shaders/light.gdshader")
const AMBIENT := preload("res://graphics/assets/shaders/ambient.gdshader")
const SHADOW := preload("res://graphics/assets/shaders/shadow.gdshader")
const FIGURE_SHADOW := preload("res://graphics/assets/shaders/figure_shadow.gdshader")
const BODIES := preload("res://graphics/assets/shaders/bodies.gdshader")
const GLOW := preload("res://graphics/assets/shaders/glow.gdshader")

## The lightings up, newest last. A screen swap brings the new one up before
## the old one goes; the newest is the one the global names.
static var _up: Array[Lighting] = []
static var _glow: ShaderMaterial = null

## The light there is with no lamp lit, the video's global light: every
## colour the world draws is shown times this. White is the room as it was
## always drawn; anything darker, and the lamps are what it is seen by.
var ambient := Color.WHITE
## The world position of every buffer's first pixel, and their size in
## pixels: what the pixel camera is drawing.
var origin := Vector2.ZERO
var size := Vector2i.ZERO
## The world's colours: the pixel camera's own buffer, handed over before
## this is put in the tree.
var colour: SubViewport
## How many lights reach the screen this frame — shining things' and lamps'
## alike — and how many of them throw shadows.
var lamps_lit := 0
var lamps_shadowed := 0
## The world's clock, in seconds, for what flickers.
var _t := 0.0

var _normals: SubViewport
var _masks: Array[SubViewport] = []
var _bodies: SubViewport
var _lit: SubViewport
var _all: ShaderMaterial
var _beams: Array[Beam] = []
var _shades: Array[Shade] = []
var _casts: Array[Cast] = []
var _figures: Figures
var _working := false

## What something that gives its own light wears (`glow.gdshader`): one
## material for all of it. The lamps leave it as it was drawn, and so does
## the dark.
static func glow() -> ShaderMaterial:
	if _glow == null:
		_glow = ShaderMaterial.new()
		_glow.shader = GLOW
	return _glow

## The colour that says a surface faces `way` across the picture — up is
## Vector2.UP — for something drawn in code to paint its twin on NORMAL_LAYER
## in. `counts` is how much the way it faces matters: 1 an edge lit only from
## its own side, 0 a face that takes any light alike.
static func faces(way: Vector2, counts: float = 1.0) -> Color:
	var n := way.normalized() * clampf(counts, 0.0, 1.0) * RELIEF
	return Color(n.x, n.y, 0.0, 1.0)

func _enter_tree() -> void:
	_up.append(self)

func _exit_tree() -> void:
	_up.erase(self)
	if _up.is_empty():
		# Nothing is being lit any more, so no shader is drawing normals.
		RenderingServer.global_shader_parameter_set(&"normals_size", Vector2.ZERO)

func _ready() -> void:
	# In the order they are drawn each frame, after the colours: how the world
	# faces, where each lamp does not reach, and the picture they come to.
	_normals = _viewport(true)
	_normals.world_2d = get_viewport().world_2d
	_normals.snap_2d_transforms_to_pixel = true
	# The back of the picture is flat, and the glass is the glazing's.
	_normals.canvas_cull_mask = 0xFFFFFFFF & ~(BACKDROP_LAYER | Glazing.LAYER)
	for i in MASKS:
		# Float, so a mark says how dark as well as where (SOLID).
		var mask := _viewport(true)
		# Nothing but black where no shadow is, whatever the project clears to.
		mask.transparent_bg = true
		_masks.append(mask)
		for k in PER_MASK:
			var channel := Vector3(float(k == 0), float(k == 1), float(k == 2))
			var shade := Shade.new()
			shade.clip_contents = true
			shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shade.visible = false
			var m := ShaderMaterial.new()
			m.shader = SHADOW
			m.set_shader_parameter("channel", channel * SOLID)
			shade.material = m
			mask.add_child(shade)
			_shades.append(shade)
			var cast := Cast.new()
			cast.visible = false
			cast.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var cm := ShaderMaterial.new()
			cm.shader = FIGURE_SHADOW
			cm.set_shader_parameter("channel", channel)
			cast.material = cm
			mask.add_child(cast)
			_casts.append(cast)
	_bodies = _viewport(true)
	_bodies.transparent_bg = true
	_figures = Figures.new()
	_figures.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var fm := ShaderMaterial.new()
	fm.shader = BODIES
	_figures.material = fm
	_bodies.add_child(_figures)
	_lit = _viewport(false)
	# The light there is with no lamp lit, under every lamp: on a layer of its
	# own so it covers the picture wherever the camera is.
	var under := CanvasLayer.new()
	under.layer = -1
	_lit.add_child(under)
	var all := ColorRect.new()
	all.set_anchors_preset(Control.PRESET_FULL_RECT)
	all.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_all = ShaderMaterial.new()
	_all.shader = AMBIENT
	_all.set_shader_parameter("base", colour.get_texture())
	_all.set_shader_parameter("normals", _normals.get_texture())
	all.material = _all
	under.add_child(all)

func _viewport(float_buffer: bool) -> SubViewport:
	var v := SubViewport.new()
	v.disable_3d = true
	v.use_hdr_2d = float_buffer
	v.size = Vector2i.ONE
	v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(v)
	return v

## The picture to show: the world lit, or with nothing to light it, the
## world's colours as they were drawn.
func picture() -> Texture2D:
	return _lit.get_texture() if _working else colour.get_texture()

## Whether there is anything to work out this frame: a lamp on the screen, or
## a room darker than it was drawn.
func working() -> bool:
	return _working

## The normals, as a texture, a pixel wider than the picture: see
## `lighting.gdshaderinc` for what a pixel of it holds.
func normals() -> Texture2D:
	return _normals.get_texture()

## The picture `mask` of the shadows, as a texture: a colour of it to a lamp.
func shadows(mask: int = 0) -> Texture2D:
	return _masks[mask].get_texture()

## Where the bodies stand, as a texture: green where one is (`bodies.gdshader`).
func bodies() -> Texture2D:
	return _bodies.get_texture()

## The world rect the buffers cover.
func area() -> Rect2:
	return Rect2(origin, Vector2(size) * S)

## The buffers cover `texels` pixels from `at`, the world position of the
## first, and `view` is how the world lies across them: what the pixel camera
## is drawing, on its grid. Called by the camera every frame it follows, once
## everything in the world has moved — so the frame's lamps are gathered here,
## and its shadows.
func follow(at: Vector2, texels: Vector2i, view: Transform2D) -> void:
	origin = at
	if texels != size:
		size = texels
		# A pixel wider than the picture, which is how a shader knows it is
		# the normals it is drawing (`lighting.gdshaderinc`). Nothing reads
		# the extra column.
		_normals.size = size + Vector2i(1, 0)
		_lit.size = size
		_bodies.size = size
		for mask in _masks:
			mask.size = size
	_t += get_process_delta_time()
	var lights := _lights()
	lamps_lit = lights.size()
	_working = not lights.is_empty() or ambient.r < 1.0 or ambient.g < 1.0 or ambient.b < 1.0
	var mode := SubViewport.UPDATE_ALWAYS if _working else SubViewport.UPDATE_DISABLED
	_normals.render_target_update_mode = mode
	_lit.render_target_update_mode = mode
	if not _working:
		lamps_shadowed = 0
		for mask in _masks:
			mask.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_bodies.render_target_update_mode = SubViewport.UPDATE_DISABLED
		# Nor anything kept of the bodies, which may be gone by the next light.
		for cast in _casts:
			cast.patches.clear()
		_figures.drawn.clear()
		return
	_normals.canvas_transform = view
	_lit.canvas_transform = view
	_bodies.canvas_transform = view
	for mask in _masks:
		mask.canvas_transform = view
	if _up.back() == self:
		RenderingServer.global_shader_parameter_set(&"normals_size", Vector2(_normals.size))
	_all.set_shader_parameter("ambient", Vector3(ambient.r, ambient.g, ambient.b))
	var casters := _casters(lights)
	_draw_bodies(casters, view)
	_draw_lights(lights, _draw_shadows(lights, casters, view))

## The lights that reach the screen this frame: every shining thing's that is
## to be seen, and every lamp's.
func _lights() -> Array[Lit]:
	var shown := area()
	var out: Array[Lit] = []
	for n in get_tree().get_nodes_in_group(Lamp.GROUP):
		var lamp := n as Lamp
		if lamp != null and lamp.lit():
			_take(out, lamp.as_shine(), lamp.get_global_transform(), shown, lamp)
	for n in get_tree().get_nodes_in_group(Shine.GROUP):
		var thing := n as CanvasItem
		if thing == null or not thing.is_visible_in_tree():
			continue
		var xf := thing.get_global_transform()
		for shine in Shine.on(thing):
			_take(out, shine as Shine, xf, shown, thing)
	return out

## `shine`, given by `source`, placed at `xf`, if it reaches `shown`: where it
## is in the world, which way it shines there, how bright it is this moment,
## and the mesh it is drawn with. Where it is on the thing is in world units,
## however the thing is scaled.
func _take(out: Array[Lit], shine: Shine, xf: Transform2D, shown: Rect2, source: Node) -> void:
	var power := shine.strength(_t)
	if power <= 0.0:
		return
	var lit := Lit.new()
	lit.shine = shine
	lit.source = source
	lit.power = power
	lit.at = xf.origin + shine.position.rotated(xf.get_rotation())
	lit.aim = Vector2.from_angle(deg_to_rad(shine.direction) + xf.get_rotation())
	match shine.type:
		Shine.Type.SUN:
			# Over the whole picture, and a pixel past it.
			lit.middle = shown.get_center()
			lit.half = shown.size * 0.5 + Vector2.ONE * S
		Shine.Type.AREA:
			# The shape and its reach all round, turned to shine down its own y.
			lit.middle = lit.at
			lit.half = shine.size * 0.5 + Vector2.ONE * shine.reach
			lit.turn = lit.aim.angle() - PI * 0.5
		_:
			lit.middle = lit.at
			lit.half = Vector2.ONE * (shine.radius + shine.reach)
	var x := Vector2.from_angle(lit.turn) * lit.half.x
	var y := Vector2.from_angle(lit.turn + PI * 0.5) * lit.half.y
	var spans := x.abs() + y.abs()
	lit.bounds = Rect2(lit.middle - spans, spans * 2.0)
	if shown.intersects(lit.bounds):
		out.append(lit)

## Every caster that is to be seen, when any of `lights` throws shadows.
func _casters(lights: Array[Lit]) -> Array[ShadowCaster]:
	var casters: Array[ShadowCaster] = []
	for lit in lights:
		if not lit.shine.shadows:
			continue
		for n in get_tree().get_nodes_in_group(ShadowCaster.GROUP):
			var caster := n as ShadowCaster
			if caster != null and caster.mesh != null and caster.is_visible_in_tree():
				casters.append(caster)
		break
	return casters

## Where each body stands, for the lights to read: only while one throws
## shadows, since that is all it is read for.
func _draw_bodies(casters: Array[ShadowCaster], view: Transform2D) -> void:
	_figures.drawn.clear()
	_figures.view = view
	for caster in casters:
		if caster.body:
			_figures.drawn.append(caster)
	_figures.queue_redraw()
	_bodies.render_target_update_mode = SubViewport.UPDATE_DISABLED if _figures.drawn.is_empty() \
		else SubViewport.UPDATE_ALWAYS

## The shadows of the lights that throw them — a sun's first, then the widest
## and brightest, as far as the masks go round — each given a colour of a mask
## and what to mark there: the edges near it, and the patch every body leaves
## on the floor (`_throw`). Which colour each light got, by light: its number
## among all the masks' colours.
func _draw_shadows(lights: Array[Lit], casters: Array[ShadowCaster], view: Transform2D) -> Dictionary:
	var throwing: Array[Lit] = []
	for lit in lights:
		if lit.shine.shadows:
			throwing.append(lit)
	if throwing.size() > SHADOWS:
		throwing.sort_custom(func(a: Lit, b: Lit) -> bool: return a.weight() > b.weight())
		throwing.resize(SHADOWS)
	lamps_shadowed = throwing.size()
	var given := {}
	for i in _shades.size():
		var shade := _shades[i]
		var cast := _casts[i]
		if i >= throwing.size():
			shade.visible = false
			cast.visible = false
			# Nothing kept of bodies for a light it no longer has.
			cast.patches.clear()
			continue
		var lit := throwing[i]
		given[lit] = i
		var sun := lit.shine.type == Shine.Type.SUN
		shade.visible = true
		shade.position = lit.bounds.position
		shade.size = lit.bounds.size
		var m := shade.material as ShaderMaterial
		m.set_shader_parameter("light", lit.at)
		m.set_shader_parameter("parallel", sun)
		m.set_shader_parameter("aim", lit.aim)
		m.set_shader_parameter("reach", lit.bounds.size.length() * 2.0 if sun else lit.half.length() * THROW)
		shade.thrown.clear()
		cast.visible = true
		cast.view = view
		cast.patches.clear()
		for caster in casters:
			if not caster.covers().intersects(lit.bounds):
				continue
			if caster.body:
				if not _own(caster, lit.source):
					_throw(cast, caster, lit)
			else:
				shade.thrown.append([caster.mesh, caster.global_transform])
		shade.queue_redraw()
		cast.queue_redraw()
	for i in MASKS:
		_masks[i].render_target_update_mode = SubViewport.UPDATE_ALWAYS \
			if i * PER_MASK < throwing.size() else SubViewport.UPDATE_DISABLED
	return given

## The patch a body leaves on the floor in a light: from its feet, as wide as
## the body, FEET_DEPTH down, and carried away from the light — FEET_LEAN of
## the way the light is off the feet, never more than FEET_REACH; under a sun,
## half of FEET_REACH the way the sun travels — darkest at the feet and a third
## as dark at its far end. As far as the body is standing on the floor at all
## (`ShadowCaster.feet`).
func _throw(cast: Cast, caster: ShadowCaster, lit: Lit) -> void:
	if caster.feet <= 0.0:
		return
	var stood := caster.covers()
	var feet := Vector2(stood.get_center().x, stood.end.y)
	var half := stood.size.x * 0.5
	var away := lit.aim * FEET_REACH * 0.5
	if lit.shine.type != Shine.Type.SUN:
		away = feet - lit.at
		var far := away.length()
		away = Vector2.ZERO if far < 0.001 else away / far * minf(far * FEET_LEAN, FEET_REACH)
	var dark := FEET_DARK * caster.feet
	var near_side := PackedVector2Array([feet + Vector2(-half, 0.0), feet + Vector2(half, 0.0),
		feet + Vector2(half, FEET_DEPTH), feet + Vector2(-half, FEET_DEPTH)])
	var all := PackedVector2Array()
	for p in near_side:
		all.append(p)
		all.append(p + away)
	var shape := Geometry2D.convex_hull(all)
	if shape.size() > 1 and shape[0].distance_to(shape[shape.size() - 1]) < 0.001:
		shape.remove_at(shape.size() - 1)
	if shape.size() < 3:
		return
	var reach := maxf(away.length(), 0.001)
	var shades := PackedColorArray()
	for p in shape:
		var along := clampf((p - feet).dot(away) / (reach * reach), 0.0, 1.0)
		shades.append(Color(dark * lerpf(1.0, 1.0 / 3.0, along), 0.0, 0.0))
	cast.patches.append([shape, shades])

## Whether a light given by `source` is the body's `caster` is the shadow of:
## given by the body's own view, or by anything of it — a body on fire.
static func _own(caster: ShadowCaster, source: Node) -> bool:
	var of := caster.get_parent()
	return of != null and source != null and (of == source or of.is_ancestor_of(source))

## Every light's mesh in the picture, told what its light is like and which
## colour of which mask its shadows are in.
func _draw_lights(lights: Array[Lit], given: Dictionary) -> void:
	while _beams.size() < lights.size():
		_beams.append(_beam())
	for i in _beams.size():
		var beam := _beams[i]
		if i >= lights.size():
			beam.visible = false
			continue
		var lit := lights[i]
		var shine := lit.shine
		beam.visible = true
		beam.position = lit.middle
		beam.rotation = lit.turn
		beam.scale = lit.half
		var m := beam.material as ShaderMaterial
		var slot := int(given.get(lit, -1))
		var k := slot % PER_MASK if slot >= 0 else -1
		@warning_ignore("integer_division")
		m.set_shader_parameter("shade", _masks[maxi(slot, 0) / PER_MASK].get_texture())
		m.set_shader_parameter("channel", Vector3(float(k == 0), float(k == 1), float(k == 2)))
		m.set_shader_parameter("type", int(shine.type))
		m.set_shader_parameter("tint", Vector3(shine.color.r, shine.color.g, shine.color.b))
		m.set_shader_parameter("power", lit.power)
		m.set_shader_parameter("half_size", lit.half)
		m.set_shader_parameter("turn", Vector2.from_angle(lit.turn))
		m.set_shader_parameter("radius", shine.radius)
		m.set_shader_parameter("reach", shine.reach)
		m.set_shader_parameter("falloff", shine.falloff)
		m.set_shader_parameter("aim", lit.aim)
		m.set_shader_parameter("cone", deg_to_rad(shine.spot_size) * 0.5)
		m.set_shader_parameter("blend", clampf(shine.spot_blend, 0.0, 1.0))
		m.set_shader_parameter("shape", int(shine.shape))
		m.set_shader_parameter("extent", shine.size * 0.5)
		m.set_shader_parameter("spread", deg_to_rad(shine.spread) * 0.5)
		m.set_shader_parameter("volume", shine.volume)
		m.set_shader_parameter("close", CLOSE)
		m.set_shader_parameter("beyond", shine.out_there)

func _beam() -> Beam:
	var beam := Beam.new()
	var m := ShaderMaterial.new()
	m.shader = LIGHT
	m.set_shader_parameter("base", colour.get_texture())
	m.set_shader_parameter("normals", _normals.get_texture())
	m.set_shader_parameter("bodies", _bodies.get_texture())
	beam.material = m
	_lit.add_child(beam)
	return beam

## A light, this frame: whose it is and what gives it, where it is in the
## world and which way it shines there, how bright it is, and its mesh — its
## middle, how far it is turned, half of it each way in its own frame, and
## what it covers in the world.
class Lit extends RefCounted:
	var shine: Shine
	## What gives it: the shining thing, or the lamp.
	var source: Node
	var at := Vector2.ZERO
	var aim := Vector2.DOWN
	var power := 0.0
	var middle := Vector2.ZERO
	var turn := 0.0
	var half := Vector2.ONE
	var bounds := Rect2()

	## How much it matters that it throws a shadow: a sun most, then the
	## widest and brightest.
	func weight() -> float:
		if shine.type == Shine.Type.SUN:
			return INF
		var big := shine.radius + shine.reach
		if shine.type == Shine.Type.AREA:
			big += shine.size.length() * 0.5
		return big * power

## A light's mesh: a square from -1 to 1, which the light's own size, how far
## it is turned and where it is put over everything it can reach.
class Beam extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), Color.WHITE)

## What one light's shadows are drawn by: a box over everything it reaches,
## which nothing is drawn outside of, and inside it every caster's edges,
## each where the caster is in the world. Its material is the light's own
## `shadow.gdshader`, told where the light is and which way it shines.
class Shade extends Control:
	## What throws a shadow in this light: [mesh, where in the world].
	var thrown: Array = []

	func _draw() -> void:
		var back := Transform2D(0.0, -position)
		for t in thrown:
			draw_mesh(t[0], null, back * (t[1] as Transform2D))

## What the bodies leave on the floor in one light, drawn beside its `Shade`
## in the same colour of the same mask (`figure_shadow.gdshader`): each
## body's patch, marked by how dark it is. Drawn in the world's own space.
class Cast extends Node2D:
	## How the mask's canvas lies across the world.
	var view := Transform2D.IDENTITY
	## [corners, how dark at each], a body's patch on the floor.
	var patches: Array = []

	func _draw() -> void:
		for p in patches:
			draw_polygon(p[0], p[1])

## Where the bodies stand, drawn into a picture of their own: each figure
## where the world draws it (`bodies.gdshader`).
class Figures extends Node2D:
	var view := Transform2D.IDENTITY
	## The bodies' casters.
	var drawn: Array = []

	func _draw() -> void:
		for d in drawn:
			# A body freed since it was gathered stands nowhere.
			if is_instance_valid(d):
				(d as ShadowCaster).draw_figure(self, view, Color(1.0, 1.0, 0.0, 1.0))
