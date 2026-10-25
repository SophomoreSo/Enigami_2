class_name VelocityBuffer
extends Node

## The air the world moves through, a pixel of it for every pixel of the
## picture: how far something moving has pushed it, and how fast it is still
## going. It is aarthificial's velocity buffer, from the release of his
## PixelGraphics package ("Interactive Foliage Shaders for Unity",
## https://www.youtube.com/watch?v=ecYWvfMoRIM; the source is
## https://github.com/aarthificial/pixelgraphics), and it is what `Foliage`
## reads to bend where somebody walks through it.
##
## Every pixel is a spring. Each step it is blurred toward its four
## neighbours, so a push spreads and softens; pulled back toward rest and
## slowed; and wherever something moving covers it, its speed is set to that
## thing's. So a body walking through grass leaves a wake behind it that
## swings back past upright and settles, which is what grass does. The
## numbers are the package's: its stiffness and blur, its ceiling on a step,
## its emitters' speed eased into 0..1 and scaled by six. Its damping is the
## package's default, 3, rather than the 1 of its demo scene, which rings for
## seconds after a dash.
##
## Like the video's, the buffer belongs to the screen rather than the world.
## It covers exactly what the pixel camera draws, on the same grid, and is
## slid by whole pixels when the camera moves, so what was pushed stays where
## it was pushed. All of it runs on the graphics card, in two SubViewports that
## take turns: one steps the buffer from the other (`velocity.gdshader`), and
## the other keeps that step for the next one — the package's own blit to its
## previous texture. They are float buffers (`use_hdr_2d`, which the
## compatibility renderer gives as RGBA16F): a push is signed, and in eight
## bits a spring sticks short of rest. No other renderer will do, which is why
## project.godot asks for this one on phones too (`rendering_method.mobile`):
## the Mobile renderer's `use_hdr_2d` is ten unsigned bits a colour and two of
## alpha, so nothing is ever pushed left or up, and both it and Forward+ turn
## the colours drawn into linear light, so an emitter's speed is not what lands.
##
## What writes into it are emitters, drawn into a third viewport that nothing
## shows — the video's sprites on a layer the camera leaves out. Here they are
## drawn by asking: every body moving faster than SLOWEST as the rect it
## covers, every bolt as its ball, and every blast as the ring the video
## suggests for a shockwave, each in the colour of its speed. A body standing
## still writes nothing, and the grass it stands in rises again around it.
##
## It is handed to every shader as globals declared in project.godot — the
## buffer (`velocity_buffer`), the world rect it covers (`velocity_area`) and
## the world's clock (`velocity_time`) — the way the package sets its texture
## globally, so anything drawn can read it, foliage or not. Steps are taken
## only while this node processes, so the air stops with the game; and a step
## is as long as the game's frame, so it slows when the fight does.
##
## The `PixelCamera` makes one and feeds it its grid. Nothing here is a rule:
## it reads where bodies are and how they move, and changes nothing.

## The world units to a pixel of the buffer: the pixel camera's.
const S := PixelCamera.SCALE
## How hard a pushed pixel is pulled back to rest, per second squared: a
## spring that swings a little over once a second.
const STIFFNESS := 70.0
## How fast a pixel's motion dies, per second. A swing is down to half in half
## a second, and to a quarter in about one.
const DAMPING := 3.0
## How far toward its neighbours' average a pixel is blurred each sixtieth of a
## second. The package blurs by a share per frame; this is that share at
## sixty, taken for however long the step really is.
const BLUR := 0.5
## The longest step, in seconds, so a dropped frame cannot throw the springs.
const MAX_DT := 0.034
## A body this fast writes the most speed there is: the player's dash.
const FASTEST := 880.0
## The speed written for a body going FASTEST: the package's six.
const PUSH := 6.0
## Slower than this a body writes nothing: standing in grass is not pushing it.
const SLOWEST := 30.0
## A body with no size of its own is taken to be about the player's.
const BODY_GUESS := Vector2(20.0, 30.0)
## How wide a blast's ring is, in world units, and how hard it pushes outward
## as it leaves its centre, in the buffer's speed.
const RING := 16.0
const BLAST := 9.0

const STEP := preload("res://graphics/assets/shaders/velocity.gdshader")

## The buffers up, newest last. A screen swap brings the new one up before the
## old one goes; the newest is the one the globals name.
static var _up: Array[VelocityBuffer] = []

## The world position of the buffer's first pixel, and its size in pixels.
var origin := Vector2.ZERO
var size := Vector2i.ZERO
## The world's clock, in seconds of game time.
var time := 0.0

var _was := Vector2.ZERO
## The buffer has just been made, and its next step starts from still air.
var _fresh := true
var _emit: SubViewport
var _now: SubViewport
var _then: SubViewport
var _emitters: Emitters
var _step: ShaderMaterial

func _enter_tree() -> void:
	_up.append(self)

func _exit_tree() -> void:
	_up.erase(self)
	if _up.is_empty():
		# Nothing is stepping the air any more: a shader reading it now reads
		# nothing, rather than the last frame of a buffer that is gone.
		RenderingServer.global_shader_parameter_set(&"velocity_area", Vector4.ZERO)

func _ready() -> void:
	# After the pixel camera has fed this frame's grid in (it runs at 100).
	process_priority = 101
	# In the order they are drawn each frame: what moves, the step, the keep.
	_emit = _viewport()
	_emitters = Emitters.new()
	_emit.add_child(_emitters)
	_now = _viewport()
	_step = _full(_now)
	_then = _viewport()
	var keep := _full(_then)
	keep.set_shader_parameter("keep", true)
	keep.set_shader_parameter("trail", _now.get_texture())
	_step.set_shader_parameter("trail", _then.get_texture())
	_step.set_shader_parameter("emit", _emit.get_texture())
	_step.set_shader_parameter("stiffness", STIFFNESS)
	_step.set_shader_parameter("damping", DAMPING)

func _viewport() -> SubViewport:
	var v := SubViewport.new()
	v.disable_3d = true
	v.use_hdr_2d = true
	v.transparent_bg = true
	v.size = Vector2i.ONE
	v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(v)
	return v

## A rect over the whole of `v`, drawn with the step shader and nothing blended.
func _full(v: SubViewport) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = STEP
	var r := ColorRect.new()
	r.material = m
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_child(r)
	v.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	return m

## The buffer covers `texels` pixels from `at`, the world position of its
## first: what the pixel camera is drawing, on its grid. Called by the camera
## every frame it follows.
func follow(at: Vector2, texels: Vector2i) -> void:
	origin = at
	if texels != size:
		# A new size is a new buffer, with nothing on it to slide.
		size = texels
		_was = at
		_fresh = true
		for v: SubViewport in [_emit, _now, _then]:
			v.size = size
	_emit.canvas_transform = Transform2D(0.0, Vector2.ONE / S, 0.0, -origin / S)

## The buffer as a texture: R and G how far each pixel has been pushed, B and
## A how fast it moves. Its pixel (0, 0) is at `origin`.
func texture() -> Texture2D:
	return _now.get_texture()

## The world rect the buffer covers.
func area() -> Rect2:
	return Rect2(origin, Vector2(size) * S)

func _process(delta: float) -> void:
	if size.x <= 0 or size.y <= 0:
		return
	var dt := minf(delta, MAX_DT)
	time += delta
	_step.set_shader_parameter("shift", Vector2i(((origin - _was) / S).round()))
	_was = origin
	_step.set_shader_parameter("fresh", _fresh)
	_fresh = false
	_step.set_shader_parameter("dt", dt)
	_step.set_shader_parameter("blur", 1.0 - pow(1.0 - BLUR, dt * 60.0))
	_emitters.queue_redraw()
	for v: SubViewport in [_emit, _now, _then]:
		v.render_target_update_mode = SubViewport.UPDATE_ONCE
	if not _up.is_empty() and _up.back() == self:
		RenderingServer.global_shader_parameter_set(&"velocity_buffer", _now.get_texture())
		var a := area()
		RenderingServer.global_shader_parameter_set(&"velocity_area",
			Vector4(a.position.x, a.position.y, a.size.x, a.size.y))
		RenderingServer.global_shader_parameter_set(&"velocity_time", time)

## The speed a thing moving at `vel` writes: its direction, its speed eased
## into 0..1 against FASTEST the way the package's emitters ease it, and
## PUSH at the top. Nothing for one slower than SLOWEST.
static func push_of(vel: Vector2) -> Vector2:
	var speed := vel.length()
	if speed < SLOWEST:
		return Vector2.ZERO
	var t := clampf(speed / FASTEST, 0.0, 1.0)
	return vel / speed * (1.0 - (1.0 - t) * (1.0 - t)) * PUSH

## What moves through the air this frame, drawn in the colour of its speed —
## R and G, A where anything is — on a canvas nothing shows. It asks rather
## than being told: the bodies in the `actors` group, and the bolts and blasts
## in the world the arena holds.
class Emitters extends Node2D:
	func _draw() -> void:
		for a in get_tree().get_nodes_in_group("actors"):
			if not (a is CharacterBody2D) or not is_instance_valid(a) or a.is_queued_for_deletion():
				continue
			var p := VelocityBuffer.push_of((a as CharacterBody2D).velocity)
			if p == Vector2.ZERO:
				continue
			var size = a.get("body_size")
			if not (size is Vector2):
				size = VelocityBuffer.BODY_GUESS
			var at := (a as Node2D).global_position
			draw_rect(Rect2(at - (size as Vector2) * 0.5, size), Color(p.x, p.y, 0.0, 1.0))
		var w := Arena.current()
		if w == null:
			return
		for n in w.get_children():
			if n is Projectile:
				var bolt := n as Projectile
				var p := VelocityBuffer.push_of(bolt.velocity)
				if p != Vector2.ZERO:
					var r := maxf(bolt.radius, float(VelocityBuffer.S))
					draw_rect(Rect2(bolt.global_position - Vector2.ONE * r, Vector2.ONE * r * 2.0),
						Color(p.x, p.y, 0.0, 1.0))
			elif n is AreaBurst:
				var blast := n as AreaBurst
				var t := 1.0 - blast.life / blast.max_life
				_ring(blast.global_position, blast.radius * t, VelocityBuffer.BLAST * (1.0 - t))

	## A ring of radius `r` round `at`, pushing outward: squares RING wide all
	## round it, each in the colour of the way out from the centre where it
	## sits. Nothing until the ring has left its centre, where every way out is
	## the same pixel and the last square drawn would push it its own way.
	func _ring(at: Vector2, r: float, strength: float) -> void:
		var w := VelocityBuffer.RING
		if r < w * 0.5:
			return
		var n := maxi(8, int(ceil(TAU * r / (w * 0.5))))
		for i in n:
			var out := Vector2.from_angle(TAU * float(i) / float(n))
			draw_rect(Rect2(at + out * r - Vector2.ONE * w * 0.5, Vector2.ONE * w),
				Color(out.x * strength, out.y * strength, 0.0, 1.0))
