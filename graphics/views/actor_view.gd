class_name ActorView
extends Node2D

## The body of an actor: an animated sprite cut from the shared atlas or read
## from a hero's folder, the status colours washed over it, and the numbers
## that float off it when it is hit. Subclasses choose the character and the
## animation; everything else is the same for the player and for every
## monster.
##
## The actor is where its feet are (`Actor`), so the sprite is stood up from
## the node: its drawn feet on the origin, the body rising up the screen from
## there. That is what lets the world sort bodies by their feet, a body walking
## behind a pillar and in front of it as it goes. A character with a strip for
## each of the four facings shows the one the body faces (`Actor.facing_name`),
## the side one mirrored for left; a character drawn side on, as the atlas's
## are, shows that and is mirrored the way the body last turned.
##
## And how a body stands to the light (`Lighting`): the sprite's shader says
## which way its edge faces, the body throws a shadow the size of itself, what
## is drawn round it to be read — a ring, a bar of health — is its own light,
## and one on fire lights the room.

## The light of a body on fire: how far it reaches in world units, how bright
## it is, and how much of it hangs in the air.
const BURN_REACH := 130.0
const BURN_LIGHT := 1.6
const BURN_AIR := 0.08

## One animation's name for another's, where art names them differently: the
## atlas's characters run, a hero's walk.
const ALIAS := {"walk": "run", "run": "walk"}

## Which character this actor wears. Subclasses set it in `_configure`.
var art: String = Style.PLAYER_ART
## A permanent multiply over the sprite — a boss phase, a reskinned monster.
var tint: Color = Color.WHITE

var actor: Actor
var sprite: AnimatedSprite2D
## Blows the silhouette out to white on a hit, then fades.
var flash: float = 0.0

## The shadow the body throws: a box the size of it, and its sprite.
var caster: ShadowCaster
## The light of it burning, once it has.
var fire: Lamp

var _mat: ShaderMaterial
var _started: bool = false
## The size of the body the sprite was last stood on (`_stand_sprite`).
var _stood_on: Vector2 = Vector2.ZERO
## Where the sprite stands with its feet on the floor (`_stand_sprite`); a
## body off the floor (`Actor.height`) is drawn up from there.
var _stand_y: float = 0.0
## Whether the strip showing is one drawn for a side, and so mirrored for the
## left; a strip drawn facing up or down the screen is never mirrored.
var _sided: bool = true

func _ready() -> void:
	actor = get_parent() as Actor
	# What a view draws itself is what is read off the body, not the body: lit
	# by nothing but itself.
	material = Lighting.glow()
	if actor != null:
		actor.damaged.connect(_on_damaged)
		actor.healed.connect(_on_healed)

## Runs once, on the first frame — by which time the actor has finished its own
## `_ready` and its collider and identity are settled.
func _ensure() -> bool:
	if _started:
		return actor != null and is_instance_valid(actor)
	if actor == null or not is_instance_valid(actor):
		return false
	_started = true
	_configure()
	_build_sprite()
	return true

## Subclass hook: pick `art` and `tint` from the actor.
func _configure() -> void:
	pass

## Subclass hook: called every frame to choose the animation.
func _animate() -> void:
	play("idle")

func _build_sprite() -> void:
	var s := Sprites.PIXEL_SCALE
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.frames_for(art)
	sprite.animation = "idle"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(s, s)
	caster = ShadowCaster.new()
	# The body stands up from its feet: the box is over the origin, not round it.
	caster.box(Rect2(-0.5, -1.0, 1.0, 1.0))
	add_child(caster)
	_stand_sprite()
	_mat = Sprites.material_for(art)
	sprite.material = _mat
	add_child(sprite)
	sprite.play("idle")
	caster.figures.append(sprite)
	caster.standing = actor

## Dresses the view in another character's art where it stands — the hero
## picked on a bench, while the body is in a world — its feet put back on the
## body's and its idle playing.
func rewear(new_art: String) -> void:
	if new_art == art:
		return
	art = new_art
	if sprite == null:
		return
	sprite.sprite_frames = Sprites.frames_for(art)
	_mat = Sprites.material_for(art)
	sprite.material = _mat
	_stand_sprite()
	sprite.play("idle")

## Puts the art's feet on the body's: the frame is centred on the sprite, so
## the sprite is lifted by half the frame and let down again by however much
## padding sits under the drawn feet — usually none, but never assume it. The
## body's own size says nothing about where the sprite goes any more; it is
## kept so a body that changes size is noticed.
func _stand_sprite() -> void:
	var s := Sprites.PIXEL_SCALE
	var frame := Sprites.frame_size(art)
	_stood_on = actor.body_size
	_stand_y = (frame.y * 0.5 - Sprites.art_rect(art).end.y) * s
	sprite.position = Vector2(0, _stand_y - actor.height)
	caster.scale = _stood_on

## The middle of the body, in the view's own coordinates: half its height up
## from the feet, and up off the floor by however far the body is. Where a
## thing held is drawn, and what a status effect scatters round.
func middle() -> Vector2:
	return Vector2(0.0, -actor.body_size.y * 0.5 - actor.height)

## Where the top of the drawn art is, in the view's own coordinates: what
## rides over the head hangs from here.
func top_y() -> float:
	return -Sprites.art_rect(art).size.y * Sprites.PIXEL_SCALE - actor.height

func _process(delta: float) -> void:
	if not _ensure():
		return
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 4.0)
	if actor.body_size != _stood_on:
		_stand_sprite()
	sprite.position.y = _stand_y - actor.height
	_animate()
	sprite.flip_h = _sided and actor.side() < 0
	_update_status()
	_burn_light()
	_burn_sparks(delta)
	_stun_stars(delta)
	_wet_drips(delta)
	_frost_glints(delta)
	queue_redraw()

## Whether this actor's art has an animation of that name, in any facing. The
## atlas characters have idle, run and hit; a hero's folder has whatever strips
## it holds — see `SkinnedCharacter.ANIMS`.
func has_anim(anim: String) -> bool:
	return sprite != null and sprite.sprite_frames != null and _resolve(anim) != ""

## The name in the frames that shows `anim` the way the body faces: the strip
## drawn for that facing, or the one drawn for every facing; by the name asked
## for, or the other name for the same motion (`ALIAS`). "" for none.
func _resolve(anim: String) -> String:
	var sf := sprite.sprite_frames
	var names: Array[String] = [anim]
	if ALIAS.has(anim):
		names.append(ALIAS[anim])
	var face := actor.facing_name()
	for n in names:
		if sf.has_animation("%s_%s" % [n, face]):
			return "%s_%s" % [n, face]
	for n in names:
		if sf.has_animation(n):
			return n
	return ""

## Plays `name`, or freezes on `frame` of it when `frame` is not negative — how
## a pose is held out of a cycle for art that has no strip of its own. An
## animation that does not loop stays on its last frame once it has run, until
## something else is asked for. Art with no such animation idles.
func play(anim: String, speed: float = 1.0, frame: int = -1) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var found := _resolve(anim)
	if found == "":
		found = _resolve("idle")
	if found == "":
		return
	_sided = found.ends_with("_" + Actor.FACE_SIDE) or not found.contains("_")
	if frame >= 0:
		sprite.animation = found
		sprite.frame = mini(frame, sprite.sprite_frames.get_frame_count(found) - 1)
		sprite.pause()
		return
	sprite.speed_scale = speed
	if sprite.animation != found:
		# Another facing of the same motion goes on from the frame it was at,
		# so a body turning as it walks does not restart its stride.
		var same := String(sprite.animation).get_slice("_", 0) == found.get_slice("_", 0)
		var at := sprite.frame if same else 0
		sprite.play(found)
		if same and at < sprite.sprite_frames.get_frame_count(found):
			sprite.frame = at
		return
	if sprite.is_playing():
		return
	# Stopped on this animation: paused on a held frame, or a one-shot that has
	# run out. Only the first is started again.
	var last := sprite.sprite_frames.get_frame_count(found) - 1
	if sprite.sprite_frames.get_animation_loop(found) or sprite.frame < last:
		sprite.play(found)

## The motion the sprite is showing, without its facing: "walk" for
## "walk_down". What a test asks.
func showing() -> String:
	if sprite == null:
		return ""
	return String(sprite.animation).get_slice("_", 0)

## Chill and burn read as a multiply; a hit needs to blow the whole silhouette
## out to white, which a modulate cannot do, so the shader blends instead.
func _update_status() -> void:
	if _mat == null:
		return
	var t := tint
	if actor.wet_time > 0.0:
		t = t.lerp(Style.ELEMENT_COLOR["WATER"], 0.3)
	if actor.chill_time > 0.0:
		t = t.lerp(Color(0.45, 0.8, 1.0), 0.5)
	if actor.burn_time > 0.0:
		t = t.lerp(Color(1.0, 0.45, 0.2), 0.4)
	# Frozen is ice all over; stunned is dulled: the colour goes out of it
	# while it stands there.
	if actor.frozen():
		t = t.lerp(Style.FROZEN_TINT, 0.75)
	elif actor.stunned():
		t = t.lerp(Color(0.6, 0.6, 0.62), 0.45)
	_mat.set_shader_parameter("tint", t)
	_mat.set_shader_parameter("flash", clampf(status_flash(), 0.0, 1.0))

## What the shader's flash channel should read. Overridden where something else
## has to show through it, like a monster's wind-up.
func status_flash() -> float:
	return flash

## A body on fire is a lamp, for as long as it burns: a flame's light, never
## still, from the middle of the body.
func _burn_light() -> void:
	if actor.burn_time <= 0.0:
		if fire != null:
			fire.visible = false
		return
	if fire == null:
		fire = Lamp.of(Style.ELEMENT_COLOR["FIRE"], BURN_REACH)
		fire.volume = BURN_AIR
		add_child(fire)
	fire.position = middle()
	fire.visible = true
	fire.energy = BURN_LIGHT * Lamp.flicker(float(Time.get_ticks_msec()) / 1000.0, int(get_instance_id() % 89))

var _ember: float = 0.0

func _burn_sparks(delta: float) -> void:
	if actor.burn_time <= 0.0:
		return
	_ember -= delta
	if _ember > 0.0:
		return
	_ember = 0.08
	Fx.burst(actor.global_position + middle() + Vector2(randf_range(-6, 6), 0),
		Style.ELEMENT_COLOR["FIRE"], 1, 40.0)

var _star: float = 0.0
var _star_turn: float = 0.0

var _drip: float = 0.0

## Drops falling off whatever is wet, now and then: from low on the body, to
## the floor at its feet.
func _wet_drips(delta: float) -> void:
	if actor.wet_time <= 0.0:
		return
	_drip -= delta
	if _drip > 0.0:
		return
	_drip = 0.22
	Fx.burst(actor.global_position + Vector2(randf_range(-actor.body_size.x, actor.body_size.x) * 0.4,
		-actor.body_size.y * 0.2), Style.ELEMENT_COLOR["WATER"], 1, 12.0)

var _glint: float = 0.0

## Frost catching the light on whatever is frozen solid, anywhere on the body.
func _frost_glints(delta: float) -> void:
	if not actor.frozen():
		return
	_glint -= delta
	if _glint > 0.0:
		return
	_glint = 0.15
	var at := Vector2(randf_range(-0.5, 0.5) * actor.body_size.x, randf_range(-1.0, 0.0) * actor.body_size.y)
	Fx.burst(actor.global_position + at, Style.FROZEN_TINT, 1, 8.0)

## Stars going round over the head of whatever is stunned, one at a time. One
## frozen solid has frost on it instead (`_frost_glints`).
func _stun_stars(delta: float) -> void:
	if not actor.stunned() or actor.frozen():
		return
	_star -= delta
	if _star > 0.0:
		return
	_star = 0.09
	_star_turn += 1.9
	var over := Vector2(cos(_star_turn) * actor.body_size.x * 0.45, -actor.body_size.y - 8.0)
	Fx.burst(actor.global_position + over, Style.STUN_COLOR, 1, 18.0)

## Health given back reads with the damage numbers, green and signed, and a
## line above where they start: what an INVERT gives back lands in the same
## instant as the blow it rides on, and two numbers thrown from one spot are
## one smudge.
func _on_healed(a: Actor, amount: float) -> void:
	var line := float(PixelCamera.TEXT_SIZE * PixelCamera.SCALE)
	Fx.text(a.global_position + Vector2(0, -a.body_size.y - 6 - line), "+%d" % int(round(amount)), Style.HEAL_COLOR)

func _on_damaged(a: Actor, amount: float) -> void:
	# Damage over time never reaches here: it is not a connection, so it neither
	# flashes the sprite nor throws a number.
	flash = 1.0
	var col := Color(1, 0.95, 0.6) if a.team != 0 else Color(1, 0.5, 0.5)
	Fx.damage_number(a.global_position + Vector2(0, -a.body_size.y - 6), amount, col)

## A strip of health over a monster, hidden while it is untouched.
func draw_health_bar(width: float, y: float) -> void:
	if actor.health_ratio() >= 1.0:
		return
	draw_rect(Rect2(-width * 0.5, y, width, 3.0), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(-width * 0.5, y, width * actor.health_ratio(), 3.0), Style.HEALTH_BAR)
