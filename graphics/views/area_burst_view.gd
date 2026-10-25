class_name AreaBurstView
extends Node2D

## An expanding ring, drawn where the damage actually is: the edge passes a
## target on the frame it hits it.
##
## And a flash: a lamp at its middle, brightest as it goes off and gone with
## the ring, reaching past it.

## How far the flash reaches, against the blast's own radius; how bright it
## is as it goes off; and how much of it hangs in the air.
const FLASH_REACH := 2.2
const FLASH := 2.4
const FLASH_AIR := 0.12

var blast: AreaBurst
var lamp: Lamp

func _ready() -> void:
	blast = get_parent() as AreaBurst
	material = Lighting.glow()
	lamp = Lamp.new()
	lamp.volume = FLASH_AIR
	lamp.energy = 0.0
	add_child(lamp)

func _process(_delta: float) -> void:
	if blast != null and is_instance_valid(blast):
		lamp.color = Style.element_color(blast.payload)
		lamp.radius = blast.radius * FLASH_REACH
		lamp.energy = FLASH * clampf(blast.life / blast.max_life, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	if blast == null or not is_instance_valid(blast):
		return
	var t := 1.0 - blast.life / blast.max_life
	var c := Style.element_color(blast.payload)
	c.a = (1.0 - t) * 0.8
	draw_circle(Vector2.ZERO, blast.radius * t, Color(c.r, c.g, c.b, c.a * 0.25))
	draw_arc(Vector2.ZERO, blast.radius * t, 0, TAU, 36, c, 3.0)
