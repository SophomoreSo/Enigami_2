class_name Shine
extends Resource

## The light something gives — a lantern, a fire, a lightbulb, a strip of neon
## — as a property of whatever gives it, and not a thing in the world of its
## own. A shining thing is given its light (`give`) and goes on being what it
## was: the light is where the thing is, swings when it swings, and goes out
## when it is hidden or freed. Whatever is lighting the picture (`Lighting`)
## asks every shining thing for its light each frame, and adds each to the
## picture a pass at a time (`light.gdshader`).
##
## Its type is one of Blender's lights:
##
##   POINT  light every way from a point: as bright as it gets over `radius`,
##          the size of what gives it, and dimming to nothing `reach` past it.
##   SUN    the same light over everything, from one way and no distance at
##          all: `direction` is the way it travels, and a surface is lit as
##          far as it faces back up it. Its shadows are thrown all one way.
##   SPOT   a point's light in a cone `spot_size` wide, pointing `direction`,
##          fading toward the cone's edge over `spot_blend` of it.
##   AREA   light from the whole of a shape — a rectangle or an ellipse,
##          `size.x` across the way it shines and `size.y` along it — dimming
##          to nothing `reach` from its edge, and leaving it `spread` wide
##          about `direction`: 180 its face alone, 360 all round.
##
## A kind of shining thing is a row of `lights` in the content database, which
## every thing of that kind gives (`of`): what there is to tune is there. What
## one thing does with its own light from moment to moment — a sign that
## stutters, a lamp brighter for somebody at its station — is its `level`;
## where on the thing the light is, its `position`.

enum Type { POINT, SUN, SPOT, AREA }
enum Shape { RECTANGLE, ELLIPSE }

## Every shining thing is in this group, and keeps its lights under this name.
const GROUP := &"shining"
const META := &"shine"
const TYPES := {"point": Type.POINT, "sun": Type.SUN, "spot": Type.SPOT, "area": Type.AREA}

## Which kind of shining thing this is the light of: its row of `lights`.
@export var id := ""
@export var type := Type.POINT
@export var color := Color.WHITE
## How bright: 1 shows what it lights twice as bright as the room's own light
## alone would.
@export_range(0.0, 16.0, 0.05, "or_greater") var power := 1.0
## POINT, SPOT: how big what gives it is, in world units.
@export_range(0.0, 256.0, 1.0, "or_greater") var radius := 0.0
## POINT, SPOT, AREA: how far it goes past that, in world units.
@export_range(1.0, 2048.0, 1.0, "or_greater") var reach := 160.0
## How it dims over its reach: 1 in a straight line, 2 easing into nothing.
@export_range(0.1, 8.0, 0.05) var falloff := 2.0
## SUN, SPOT, AREA: the way it shines, in degrees off the thing's own way
## across: 0 right, 90 down, 270 up.
@export_range(-360.0, 360.0, 1.0) var direction := 90.0
## SPOT: how wide its cone is, in degrees, and the share of it it fades to
## its edge over.
@export_range(1.0, 360.0, 1.0) var spot_size := 45.0
@export_range(0.0, 1.0, 0.01) var spot_blend := 0.15
## AREA: the shape, and how big: across the way it shines, and along it, in
## world units.
@export var shape := Shape.RECTANGLE
@export var size := Vector2(32.0, 4.0)
## AREA: how wide the light leaves the shape, in degrees.
@export_range(1.0, 360.0, 1.0) var spread := 180.0
## How much of it the air in front of the picture catches: what shows a light
## where there is nothing behind it to light.
@export_range(0.0, 4.0, 0.01, "or_greater") var volume := 0.0
## Whether what stands in it throws a shadow.
@export var shadows := true
## How much it wavers, the way a flame does: 0 steady.
@export_range(0.0, 1.0, 0.01) var flicker := 0.0
## Where it is on the thing that gives it, from the thing's own origin, in
## world units.
@export var position := Vector2.ZERO

## How lit it is this moment, as the thing that gives it has it: 1 as its row
## says, 0 out.
var level := 1.0
## Whether what gives it is out past the room it is seen from, as a sign
## across the street is from behind the glass (a look's `room`). A light
## in the room lights the room alone; one out there lights what is out there
## as well, and the room as far as it reaches into it.
var out_there := false
## What puts its flicker out of step with every other's.
var salt := 0

## The rows of `lights` read so far, by id. The table is read once a kind.
static var _rows: Dictionary = {}

## The light the kind `kind` gives, as its row of `lights` has it: a new one
## every time, the thing's own to change. A kind that is not in the table is
## said loudly, and gives a white point's light.
static func of(kind: String) -> Shine:
	var s := Shine.new()
	s.id = kind
	var row := source(kind)
	if row.is_empty():
		push_error("Shine: no kind of light called '%s' in %s" % [kind, Db.PATH])
		return s
	s.type = TYPES.get(String(row["type"]), Type.POINT)
	s.color = Color.html(String(row["color"]))
	s.power = float(row["power"])
	s.radius = float(row["radius"])
	s.reach = float(row["reach"])
	s.falloff = float(row["falloff"])
	s.direction = float(row["direction"])
	s.spot_size = float(row["spot_size"])
	s.spot_blend = float(row["spot_blend"])
	s.shape = Shape.ELLIPSE if String(row["shape"]) == "ellipse" else Shape.RECTANGLE
	s.size = Vector2(float(row["size_x"]), float(row["size_y"]))
	s.spread = float(row["spread"])
	s.volume = float(row["volume"])
	s.shadows = int(row["shadows"]) != 0
	s.flicker = float(row["flicker"])
	s.position = Vector2(float(row["x"]), float(row["y"]))
	return s

## A kind as the table has it — its row of `lights` — or {} for no such kind.
static func source(kind: String) -> Dictionary:
	if not _rows.has(kind):
		var found := Db.records("lights", "id = ?", [kind])
		_rows[kind] = found[0] if not found.is_empty() else {}
	return _rows[kind]

## Every kind of light in the table, by id.
static func kinds() -> PackedStringArray:
	var out := PackedStringArray()
	for r in Db.rows("SELECT id FROM lights ORDER BY id"):
		out.append(String(r["id"]))
	return out

## Gives `thing` the light of the kind `kind` — or `kind` itself, a light
## already made — `at` from the thing's own origin besides wherever the row
## puts it. Answers the light, which is the thing's to change from then on. A
## thing may give more than one.
static func give(thing: CanvasItem, kind: Variant, at: Vector2 = Vector2.ZERO) -> Shine:
	var s: Shine = kind if kind is Shine else of(String(kind))
	s.position += at
	if s.salt == 0:
		s.salt = absi(hash(Vector2i(s.position)) ^ (thing.get_instance_id() & 0xffff)) % 997 + 1
	var lights: Array = thing.get_meta(META, [])
	lights.append(s)
	thing.set_meta(META, lights)
	thing.add_to_group(GROUP)
	return s

## The lights `thing` gives, in the order it was given them.
static func on(thing: Node) -> Array:
	return thing.get_meta(META, []) if thing.has_meta(META) else []

## `thing` gives no light any more.
static func put_out(thing: Node) -> void:
	if thing.has_meta(META):
		thing.remove_meta(META)
	if thing.is_in_group(GROUP):
		thing.remove_from_group(GROUP)

## How bright it is `t` seconds into the world's time: its power, as lit as
## the thing has it, wavering as far as it flickers.
func strength(t: float) -> float:
	var p := power * level
	if flicker > 0.0:
		# `Lamp.flicker` swells about 0.78 by as much as 0.22 either way.
		p *= 1.0 + flicker * (Lamp.flicker(t, salt) - 0.78) / 0.22
	return maxf(p, 0.0)
