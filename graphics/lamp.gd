class_name Lamp
extends Node2D

## A light, somewhere in the world: where it is, what colour, how bright, and
## how far it reaches. It draws nothing itself. Whatever is lighting the
## picture (`Lighting`) asks which lamps there are every frame and draws each
## as the video's point light is drawn — a mesh over everything it can reach,
## adding to what the world has drawn there (`light.gdshader`) — so a lamp is
## put wherever the thing that shines is: a child of a bolt's view rides the
## bolt, and one hung on a cord swings with it.
##
## It is only ever a picture. Nothing in `feature/` knows a lamp is lit, and a
## room is as light to the rules with every one of them out.

## The group every lamp in the tree is in, which is how it is found.
const GROUP := &"lamps"

## Its colour, and how bright it is at its brightest: the video's tint and
## base intensity. At 1 a white lamp shows what is right under it twice as
## bright as the room alone would.
var color := Color.WHITE
var energy := 1.0
## How far it reaches, in world units. Its light is nothing there, and
## nothing past it is ever drawn.
var radius := 96.0
## The share of that it is at its brightest over, and how fast it dims from
## there out to its reach: 1 a straight line down, 2 easing into nothing.
var inner := 0.0
var falloff := 2.0
## Half the angle it opens to, in radians, about the way the node points —
## along its own x. From PI up it shines all round, and which way it points
## is nothing. And the share of that angle it fades toward its edge over.
var spread := PI
var soft := 0.5
## How much of its light the air in front of the picture catches, the video's
## volumetric intensity: what makes a lamp show where there is nothing behind
## it to light.
var volume := 0.0
## Whether what stands in its light throws a shadow (`ShadowCaster`). Only so
## many lamps on the screen can at once (`Lighting.SHADOWS`): the widest and
## brightest are served first, and one left over shines through what it would
## have been stopped by.
var shadows := true

## A lamp of `colour` reaching `reach` world units, `bright` at its brightest.
static func of(colour: Color, reach: float, bright: float = 1.0) -> Lamp:
	var lamp := Lamp.new()
	lamp.color = colour
	lamp.radius = reach
	lamp.energy = bright
	return lamp

## How a flame burns `t` seconds into the world's time, about 0.78 and as much
## as 0.22 either way, three waves that never line up — `salt` sets one flame
## apart from the next.
static func flicker(t: float, salt: int) -> float:
	var s := float(salt) * 2.3
	return 0.78 + 0.12 * sin(t * 7.1 + s) + 0.07 * sin(t * 12.7 + s * 1.7) + 0.03 * sin(t * 23.0 + s * 0.6)

func _enter_tree() -> void:
	add_to_group(GROUP)

## Its light as a `Shine`, the way every other is drawn: a point's, or a
## spot's for one that does not shine all round, pointing along its own x.
var _shine: Shine = null

func as_shine() -> Shine:
	if _shine == null:
		_shine = Shine.new()
		_shine.id = "lamp"
	var inside := clampf(inner, 0.0, 0.999)
	_shine.type = Shine.Type.POINT if spread >= PI else Shine.Type.SPOT
	_shine.color = Color(color.r, color.g, color.b)
	_shine.power = energy * color.a
	_shine.radius = radius * inside
	_shine.reach = radius * (1.0 - inside)
	_shine.falloff = falloff
	_shine.direction = 0.0
	_shine.spot_size = rad_to_deg(spread) * 2.0
	_shine.spot_blend = soft
	_shine.volume = volume
	_shine.shadows = shadows
	return _shine

## Whether it is giving any light at all.
func lit() -> bool:
	return is_visible_in_tree() and energy > 0.0 and radius > 0.0 and color.a > 0.0

## The way it points, in the world.
func aim() -> Vector2:
	return Vector2.RIGHT.rotated(global_rotation)
