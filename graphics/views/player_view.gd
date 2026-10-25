class_name PlayerView
extends ActorView

## The player: the character, the weapon they are pointing, the ghost a dash
## leaves behind, the charge bar over their head, and the rings that report
## guard and dash recovery. With the player's hands in a monster the body is
## left standing, dimmed, with a thread out to where they are — and empty-
## handed, once the monster has taken the weapon. Empty-handed too with the
## rock in hand and the rock thrown (`Player.weapon_hands`).

## The weapon is a separate tile so it can swing to the aim direction while the
## body keeps walking. Every weapon tile in the atlas points up.
const WEAPON_GRIP := 0.82  ## share of the tile that hangs past the hand
const WEAPON_HAND := 10.0  ## how far out of the body the hand holds it

const TRAIL_LIFE := 0.22
const CHARGE_COLOR := Color(0.78, 0.68, 1.0)
const PARRY_COLOR := Color(1, 0.95, 0.6)
const DASH_COLOR := Color(0.7, 0.9, 1.0)

## The charge read-out rides above the head: clear of the ring at its widest,
## and high enough that the body never grows into it — CHARGE_BAR_OVER over
## the top of the art, whatever height the hero's art stands (`head_y`).
## CHARGE_BAR_Y is what that comes to over the player's own art, for whoever
## needs the number with no view to ask (`SpeechBubble.PLAYER_HEAD`).
const CHARGE_BAR := Vector2(40.0, 5.0)
const CHARGE_BAR_OVER := 13.0
const CHARGE_BAR_Y := -66.0

## How fast the body has to be going to read as walking rather than shuffling
## to a stop.
const WALKING := 12.0

var player: Player
var weapon_sprite: Sprite2D
var _weapon_art: String = ""
var _trail: Array = []
var _spark: float = 0.0

func _configure() -> void:
	player = actor as Player
	# The hero played as, in their own sprites where they have them; and the
	# next one picked on a bench, the moment they are.
	art = Style.hero_play_art(GameState.hero)
	GameState.hero_changed.connect(_on_hero)

func _on_hero(id: String) -> void:
	rewear(Style.hero_play_art(id))

## How far over the feet the top of the art stands, and a little: where the
## charge bar rides, and what is said over the head hangs from.
func head_y() -> float:
	if sprite == null:
		return CHARGE_BAR_Y
	return top_y() - CHARGE_BAR_OVER

func _build_sprite() -> void:
	super._build_sprite()
	weapon_sprite = Sprite2D.new()
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.centered = false
	weapon_sprite.scale = Vector2.ONE * Sprites.PIXEL_SCALE
	weapon_sprite.z_index = 1
	add_child(weapon_sprite)
	caster.figures.append(weapon_sprite)

## What the body is doing, as a strip: a pose a story holds it in first, then
## the recoil of a blow, the bench's seat, a dash, a walk at the pace it
## walks, and the idle. A hero's folder has each in the four facings; the
## atlas's characters have the three (`ActorView.play`), and a dash out of
## those is the run, quickened.
func _animate() -> void:
	_show_fall()
	if player.forced_anim != "" and has_anim(player.forced_anim):
		# A pose a story's line holds them in, over whatever the body is doing.
		play(player.forced_anim)
	elif player.falling():
		play("hit", 1.0, 0)
	elif flash > 0.55:
		# The recoil pose, held for the front of the flash.
		play("hit", 1.0, 0)
	elif player.seated():
		# On a bench's seat.
		if has_anim("sit"):
			play("sit")
		else:
			play("idle", 1.0, 0)
	elif player.is_dashing():
		if has_anim("dash"):
			play("dash")
		else:
			play("walk", 2.2)
	elif player.velocity.length() > WALKING:
		play("walk", clampf(player.velocity.length() / Player.RUN_SPEED, 0.65, 1.6))
	else:
		play("idle")
	_update_weapon()

## The drop into a pit (`Player.fell`): for the first half of the fall the
## sprite is drawn over the pit, shrinking into it; for the second it comes
## back up on the body, where it was stood again.
func _show_fall() -> void:
	if not player.falling():
		if sprite.scale != Vector2.ONE * Sprites.PIXEL_SCALE:
			sprite.scale = Vector2.ONE * Sprites.PIXEL_SCALE
			sprite.position.x = 0.0
		return
	var t := 1.0 - player.fell / Player.FALL_TIME
	var s := Sprites.PIXEL_SCALE
	if t < 0.5:
		var into := to_local(player.fell_at)
		sprite.position = Vector2(into.x, _stand_y + into.y)
		sprite.scale = Vector2.ONE * s * (1.0 - t * 1.6)
	else:
		sprite.position.x = 0.0
		sprite.scale = Vector2.ONE * s * clampf((t - 0.5) * 2.0, 0.2, 1.0)

func _update_weapon() -> void:
	if weapon_sprite == null:
		return
	var blade := Style.weapon_art(player.weapon_id)
	if _weapon_art != blade:
		_weapon_art = blade
		var tex := Sprites.texture(_weapon_art)
		weapon_sprite.texture = tex
		if tex != null:
			# Pivot at the grip, so aiming rotates the blade around the hand.
			var grip := Style.weapon_grip(player.weapon_id, WEAPON_GRIP)
			weapon_sprite.offset = Vector2(-tex.region.size.x * 0.5, -tex.region.size.y * grip)
	# I-frames blink the whole rig, weapon included. A body nobody is in is
	# dimmed — through the sprite's shader, which draws it in the skin's own
	# colours and so takes no modulate — and holds nothing once the monster
	# has the weapon.
	var lit := player.invuln <= 0.0 or int(player.invuln * 24.0) % 2 == 0 or player.falling()
	tint = Style.POSSESS_BODY if player.vessel() != player else Color.WHITE
	sprite.self_modulate.a = 1.0 if lit else 0.35
	weapon_sprite.self_modulate.a = 0.0 if player.weapon_hands() != player else sprite.self_modulate.a
	# Held at the middle of the body, out the way the weapon points.
	weapon_sprite.position = middle() + player.aim * WEAPON_HAND
	weapon_sprite.rotation = 0.0 if Style.weapon_upright(player.weapon_id) else player.aim.angle() + PI * 0.5

func _process(delta: float) -> void:
	super._process(delta)
	if not _started:
		return
	_update_trail(delta)
	_charge_sparks(delta)

func _update_trail(delta: float) -> void:
	if player.is_dashing():
		_trail.append({"p": player.global_position, "t": TRAIL_LIFE})
	for t in _trail:
		t["t"] -= delta
	_trail = _trail.filter(func(t: Dictionary) -> bool: return t["t"] > 0.0)

## Charging is a thing happening to the character, not just a bar moving in the
## corner: it draws a tightening ring and pulls sparks inward, so holding the
## button reads as doing something even with the HUD out of view.
func _charge_sparks(delta: float) -> void:
	if not player.charging:
		_spark = 0.0
		return
	_spark -= delta
	if _spark > 0.0:
		return
	_spark = 0.09
	var a := randf() * TAU
	var r := 34.0 + randf() * 16.0
	Fx.burst(player.global_position + middle() + Vector2(cos(a), sin(a)) * r, CHARGE_COLOR, 1, 28.0)

func _draw() -> void:
	if not _started:
		return
	for t in _trail:
		var a: float = clampf(t["t"] / TRAIL_LIFE, 0.0, 1.0)
		draw_circle(to_local(t["p"]) + middle(), 10.0 * a, Color(0.6, 0.85, 1.0, a * 0.35))

	# The sprite is the body; these are the state read-outs drawn over it,
	# about the middle of the body.
	var mid := middle()
	if player.charge > 0.0:
		var ct := player.charge_ratio()
		draw_arc(mid, 34.0 - 10.0 * ct, 0, TAU, 28,
			Color(CHARGE_COLOR.r, CHARGE_COLOR.g, CHARGE_COLOR.b, 0.30 + 0.55 * ct), 2.0 + 2.0 * ct)
		_draw_charge_bar(ct)
	elif player.refilling:
		# Mana poured into a spent rune: the ring closes in as the rune fills.
		var rt := clampf(GameState.rune.mana / maxf(player.rune_full(), 1.0), 0.0, 1.0)
		draw_arc(mid, 34.0 - 10.0 * rt, -PI * 0.5, -PI * 0.5 + TAU * rt, 28,
			Color(Style.RUNE_GLOW, 0.4 + 0.5 * rt), 3.0)
		_draw_charge_bar(rt)
	if player.parry_time > 0.0:
		draw_arc(mid, 24.0, 0, TAU, 24, Color(PARRY_COLOR.r, PARRY_COLOR.g, PARRY_COLOR.b, 0.9), 2.5)
	var held := player.vessel()
	if held != player:
		# The thread out to the monster the player is in, so the body left
		# behind and the one being played are plainly the same player.
		draw_line(mid, to_local(held.global_position), Color(Style.POSSESS_COLOR, 0.35), 2.0)
	var recovery := player.dash_recovery()
	if recovery < 1.0:
		# Just under the feet.
		draw_arc(Vector2(0, 7.0), 6.0, -PI * 0.5, -PI * 0.5 + TAU * recovery, 16,
			Color(DASH_COLOR.r, DASH_COLOR.g, DASH_COLOR.b, 0.7), 2.0)

## How much of a charge there is, over the head of whoever is paying for it.
## Holding the cast button is a decision taken in the middle of a fight, with
## the eye on the character and something usually walking towards them — so
## the progress is drawn where the eye already is rather than in the corner of
## the screen. The ring says a charge is happening; this says how far it has
## got.
func _draw_charge_bar(ct: float) -> void:
	var bar := Rect2(-CHARGE_BAR.x * 0.5, head_y(), CHARGE_BAR.x, CHARGE_BAR.y)
	draw_rect(bar, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ct, bar.size.y)), CHARGE_COLOR)
	draw_rect(bar, Color(0.5, 0.6, 0.7, 0.8), false, 1.0)
