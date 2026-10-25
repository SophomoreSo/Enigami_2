class_name LooseRockView
extends Node2D

## The rock, lying where it came down (`LooseRock`), drawn so it is found again:
## the rock itself, and over it a small mark in the weapon's own colour that
## bobs and breathes. It is the one weapon that can be left behind in a room,
## and it says where it is from across the room — quietly, since it is not the
## kit a death left (`LostKitView`), which is meant to be seen from the door.
##
## Still coming down it is drawn up off the floor by its height, a shadow on
## the floor under it, turning over as it hops, a quarter at a time, the way it
## flew; lying still it lies the right way up.
##
## One that is still the throw as it comes down (`LooseRock.strikes`) is drawn
## as the throw was in the air (`ProjectileView._draw_thrown`): its faint trail,
## and — with something built into it — its glow round it and the light it
## throws, until it strikes what it comes down onto or meets the floor.

const TUMBLE := 14.0
## How far over the rock the mark stands, and how far it bobs: whole pixels of
## the world's picture, which is drawn at half the screen's.
const MARK_LIFT := 18.0
const MARK_BOB := 2.0
## The mark, a pixel of the picture a letter.
const MARK := [
	"##...##",
	".##.##.",
	"..###..",
	"...#...",
]

var rock: LooseRock
var _t: float = 0.0
var _spin: float = 0.0
## Where it was drawn, while it is still the throw.
var _trail: Array[Vector2] = []
## The light it throws while it is still a throw with something built into it.
var lamp: Lamp

func _ready() -> void:
	rock = get_parent() as LooseRock

func _lift() -> Vector2:
	return Vector2(0.0, -rock.height)

func _process(delta: float) -> void:
	if rock == null or not is_instance_valid(rock):
		return
	_t += delta
	if rock.resting:
		_spin = 0.0
	elif rock.velocity.length() > 20.0:
		_spin += delta * TUMBLE * (1.0 if rock.velocity.x >= 0.0 else -1.0)
	if rock.strikes != null:
		_trail.append(rock.global_position + _lift())
		if _trail.size() > ProjectileView.TRAIL_LEN:
			_trail.pop_front()
	else:
		_trail.clear()
	_shine()
	queue_redraw()

## The light it throws as it comes down, as it threw it in the air: in the
## colour of what its throw built into it, and only with something built in to
## burn.
func _shine() -> void:
	var lit := _built()
	if lamp == null:
		if not lit:
			return
		lamp = Lamp.of(Style.element_color(rock.strikes), ProjectileView.LIGHT_REACH)
		lamp.volume = ProjectileView.LIGHT_AIR
		add_child(lamp)
	lamp.visible = lit
	if lit:
		lamp.position = _lift()
		lamp.color = Style.element_color(rock.strikes)
		lamp.energy = ProjectileView.LIGHT

## Whether it is still a throw with something built into it — what glows.
func _built() -> bool:
	return rock.strikes != null and not rock.strikes.elements.is_empty()

func _draw() -> void:
	if rock == null or not is_instance_valid(rock):
		return
	var at := _lift()
	if rock.height > 0.0:
		var shrink := 1.0 - clampf(rock.height / ProjectileView.SHADOW_GONE, 0.0, 0.8)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, LooseRock.RADIUS * 0.9 * shrink, ProjectileView.SHADOW)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Still the throw: its trail behind it, and its glow round it.
	if rock.strikes != null:
		var built := _built()
		var tint := Style.element_color(rock.strikes) if built else ProjectileView.DUST
		var r := 5.0 * rock.strikes.size
		for i in _trail.size():
			var c := tint
			var along := float(i) / float(maxi(_trail.size(), 1))
			# As the bolt's own trail was (`ProjectileView._bead_alpha`,
			# `_bead_radius`), so the hand-over from one to the other shows no seam.
			c.a = along * 0.4 * 0.6
			draw_circle(to_local(_trail[i]), r * (0.3 + along * 0.7) * 0.6, c)
		if built:
			draw_circle(at, r * 1.6, Color(tint.r, tint.g, tint.b, 0.3))
	var tex := Sprites.texture(Style.weapon_art(rock.weapon))
	if tex != null:
		var turn := roundf(_spin / (PI * 0.5)) * PI * 0.5
		draw_set_transform(at, turn, Vector2.ONE * Sprites.PIXEL_SCALE)
		draw_texture(tex, -(tex.get_size() * 0.5).floor())
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if rock.resting:
		_draw_mark()

## A chevron pointing down at the rock, in the weapon's colour, bobbing a pixel
## at a time and breathing.
func _draw_mark() -> void:
	var c := Style.weapon_color(rock.weapon)
	c.a = 0.75 + 0.25 * sin(_t * 3.0)
	var px := Sprites.PIXEL_SCALE
	var bob := roundf(sin(_t * 2.4) * MARK_BOB) * px
	var top := -LooseRock.RADIUS - MARK_LIFT + bob
	var left := -floorf(float(String(MARK[0]).length()) * 0.5) * px
	for y in MARK.size():
		var row := String(MARK[y])
		for x in row.length():
			if row[x] == "#":
				draw_rect(Rect2(left + x * px, top + y * px, px, px), c)
