class_name CutsceneActorView
extends Node2D

## One member of a cutscene's cast: their character, stood up from their feet
## on the stage's floor in whichever of its facings they face, walking or
## standing according to how fast they are actually moving — unless the beat
## running now asked for something in particular, in which case that wins.
##
## Reads `cast["sprite"]` straight off the node, the same way `NpcView` reads an
## NPC's. The rules never look at that key; they only carry it. The sprite is
## placed and its strip picked as an NPC's is (`NpcView`).

## Below this an actor is standing still as far as the picture is concerned.
const WALK_THRESHOLD := 4.0
const ALIAS := {"walk": "run", "run": "walk"}

var who: CutsceneActor
var sprite: AnimatedSprite2D
var _sided: bool = true

func _ready() -> void:
	who = get_parent() as CutsceneActor

## Built on the first frame rather than in `_ready`, by which time the cast
## member has been told who they are.
func _build_sprite() -> void:
	var art := Style.npc_art(String(who.cast.get("sprite", "")))
	var s := Sprites.PIXEL_SCALE
	var frame := Sprites.frame_size(art)
	var art_rect := Sprites.art_rect(art)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.frames_for(art)
	# A character drawn the map way needs its material to show colours at all.
	sprite.material = Sprites.material_for(art)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(s, s)
	# Stood up from the feet (`ActorView._stand_sprite`).
	sprite.position = Vector2(0, (frame.y * 0.5 - art_rect.end.y) * s)
	add_child(sprite)
	_play("idle")
	# Somebody standing in a lamp's light throws a shadow, as every body in
	# a fight does (`ShadowCaster`): the size of themselves, up from their feet.
	var caster := ShadowCaster.new()
	caster.box(Rect2(-0.5, -1.0, 1.0, 1.0))
	caster.scale = who.body_size
	caster.figures.append(sprite)
	caster.standing = who
	add_child(caster)

func _process(_delta: float) -> void:
	if who == null or not is_instance_valid(who):
		return
	if sprite == null:
		_build_sprite()
	visible = who.on_stage
	if not visible:
		return
	_play(_wanted())
	sprite.flip_h = _sided and who.side() < 0

## What should be playing: whatever an `anim` direction last asked for, or else
## the truth about whether they are walking.
func _wanted() -> String:
	if who.forced_anim != "" and _resolve(who.forced_anim) != "":
		return who.forced_anim
	return "run" if who.velocity.length() > WALK_THRESHOLD else "idle"

## The strip that shows `anim` the way they face, or "" (`NpcView._resolve`).
func _resolve(anim: String) -> String:
	var sf := sprite.sprite_frames
	if sf == null:
		return ""
	var names: Array[String] = [anim]
	if ALIAS.has(anim):
		names.append(ALIAS[anim])
	var face := who.facing_name()
	for n in names:
		if sf.has_animation("%s_%s" % [n, face]):
			return "%s_%s" % [n, face]
	for n in names:
		if sf.has_animation(n):
			return n
	return ""

func _play(anim: String) -> void:
	var found := _resolve(anim)
	if found == "":
		found = _resolve("idle")
	if found == "":
		return
	_sided = found.ends_with("_" + Actor.FACE_SIDE) or not found.contains("_")
	if sprite.animation != found or not sprite.is_playing():
		var same := String(sprite.animation).get_slice("_", 0) == found.get_slice("_", 0)
		var at := sprite.frame if same else 0
		sprite.play(found)
		if same and at < sprite.sprite_frames.get_frame_count(found):
			sprite.frame = at
