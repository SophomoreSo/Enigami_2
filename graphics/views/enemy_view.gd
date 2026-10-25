class_name EnemyView
extends ActorView

## A monster: the atlas character its kind wears, plus the read-outs layered
## over it — a ring for a modifier, a second for an elite, a health strip, the
## "!" that says it has just seen you, and the dot after it that says it still
## has. One the player is in wears a ring of its
## own with the time left on it, and — once it has taken it — their weapon. A
## kind that carries a rifle (`Style.monster_gun`) holds it pointed at what it
## is aiming at, and it flashes at the muzzle when it fires.
##
## The rings and the bar are drawn about the body, which stands up from its
## feet (`ActorView.middle`), and a flyer's are lifted with it.

## The "!" over a monster that has just noticed somebody (`Enemy.alert`), in
## pixels of the art: `#` the mark, `o` the dark round it that keeps it read
## against anything behind.
const ALERT_ART := [
	"ooo",
	"o#o",
	"o#o",
	"o#o",
	"ooo",
	"o#o",
	"ooo",
]
## How fast a monster has to be going to read as walking; a flyer drifts, so
## more for one.
const WALKING := 12.0
const DRIFTING := 24.0

var enemy: Enemy
var _phase: int = 1
## The player's weapon in a possessed monster's hands, held the way the player
## holds it (`PlayerView`): built the first time it is taken.
var _held: Sprite2D = null
var _held_art: String = ""
## The rifle, for a kind that carries one.
var _rifle: Rifle = null

func _configure() -> void:
	enemy = actor as Enemy
	art = Style.monster_art(enemy.kind)
	tint = Style.monster_tint(enemy.kind)
	if Style.monster_gun(enemy.kind):
		_rifle = Rifle.new()
		_rifle.z_index = 1
		add_child(_rifle)
		Cues.fired.connect(_on_cue)

func _animate() -> void:
	if enemy.phase != _phase:
		_phase = enemy.phase
		tint = Style.BOSS_PHASE2_TINT
	var pace := enemy.velocity.length()
	if pace > (DRIFTING if enemy.ai() == "flyer" else WALKING):
		play("walk", clampf(pace / 110.0, 0.7, 1.8))
	else:
		play("idle")
	_update_held()
	if _rifle != null:
		_rifle.aim = _rifle_aim()
		_rifle.position = middle() + Vector2(enemy.side() * enemy.size * 0.2, enemy.size * 0.25)

## Where the rifle points: where the player in it is aiming, at what it is
## after, or the way it faces.
func _rifle_aim() -> Vector2:
	if enemy.piloted():
		return enemy.pilot.aim
	if enemy.aggro and enemy.target != null and is_instance_valid(enemy.target):
		return (enemy.target.global_position - enemy.global_position).normalized()
	return enemy.facing

## A shot off this monster: the attack goes out from where it stands.
func _on_cue(cue: StringName, d: Dictionary) -> void:
	if cue != &"attack" or _rifle == null or enemy == null or not is_instance_valid(enemy):
		return
	if (d.get("pos", Vector2.INF) as Vector2).distance_to(enemy.global_position) < 1.0:
		_rifle.flash = Rifle.FLASH

## The player's weapon, while the player in this monster has taken it — or the
## rock, once it has picked it up.
func _update_held() -> void:
	var armed := enemy.piloted() and enemy.pilot.weapon_hands() == enemy
	if not armed:
		if _held != null:
			_held.visible = false
		return
	if _held == null:
		_held = Sprite2D.new()
		_held.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_held.centered = false
		_held.scale = Vector2.ONE * Sprites.PIXEL_SCALE
		_held.z_index = 1
		add_child(_held)
	var weapon := enemy.pilot.weapon_id
	var art_id := Style.weapon_art(weapon)
	if _held_art != art_id:
		_held_art = art_id
		var tex := Sprites.texture(art_id)
		_held.texture = tex
		if tex != null:
			var grip := Style.weapon_grip(weapon, PlayerView.WEAPON_GRIP)
			_held.offset = Vector2(-tex.region.size.x * 0.5, -tex.region.size.y * grip)
	var aim: Vector2 = enemy.pilot.aim
	_held.visible = true
	_held.position = middle() + aim * (enemy.size * 0.6 + PlayerView.WEAPON_HAND * 0.5)
	_held.rotation = 0.0 if Style.weapon_upright(weapon) else aim.angle() + PI * 0.5

## A rifle in pixels of the world's picture, the stock at the hand and the
## barrel along `aim`, turned over when it points left so it is never held
## upside down.
class Rifle extends Node2D:
	## `#` the steel, `=` the light along the top of the barrel, `w` the stock.
	const ART := [
		"....=========",
		"wwww#########",
		"wwww..#......",
		"ww...........",
	]
	const STEEL := Color(0.22, 0.23, 0.28)
	const SHINE := Color(0.55, 0.58, 0.66)
	const STOCK := Color(0.42, 0.27, 0.16)
	const MUZZLE := Color(1.0, 0.86, 0.45)
	## How long a muzzle flash stays up.
	const FLASH := 0.07

	var aim: Vector2 = Vector2.RIGHT
	var flash: float = 0.0

	func _process(delta: float) -> void:
		flash = maxf(0.0, flash - delta)
		queue_redraw()

	func _draw() -> void:
		var px := float(Sprites.PIXEL_SCALE)
		var flip := -1.0 if aim.x < 0.0 else 1.0
		draw_set_transform(Vector2.ZERO, aim.angle(), Vector2(1.0, flip))
		var rows := ART.size()
		for y in rows:
			var row := String(ART[y])
			for x in row.length():
				var ch := row[x]
				if ch == ".":
					continue
				var col := SHINE if ch == "=" else (STOCK if ch == "w" else STEEL)
				draw_rect(Rect2(Vector2(x - 2, y - 1.5) * px, Vector2.ONE * px), col)
		if flash > 0.0:
			var tip := Vector2(String(ART[1]).length() - 2, -0.5) * px
			draw_rect(Rect2(tip, Vector2(3, 2) * px), MUZZLE)
			draw_rect(Rect2(tip + Vector2(px, -px), Vector2(px, 4.0 * px)), Color(MUZZLE, 0.7))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The wind-up before a lunge has to read before the lunge lands.
func status_flash() -> float:
	if enemy.telegraph <= 0.0:
		return flash
	return maxf(flash, clampf(enemy.telegraph / Enemy.LUNGE_WIND, 0.0, 1.0) * 0.75)

func _draw() -> void:
	if not _started:
		return
	var s := enemy.size
	var mid := middle()
	var over := top_y()
	if enemy.modifier != "":
		draw_arc(mid, s + 6.0, 0, TAU, 24, Style.modifier_color(enemy.modifier), 2.0)
	if enemy.def.get("elite", false) or enemy.def.get("boss", false):
		draw_arc(mid, s + 10.0, 0, TAU, 28, Style.ELITE_RING, 2.0)

	draw_health_bar(s * 2.4, over - 12.0)
	if enemy.piloted():
		# The player is in it: a ring, and round it the time left, running out
		# the way a dash's recovery fills.
		var p := enemy.pilot
		draw_arc(mid, s + 8.0, 0, TAU, 28, Color(Style.POSSESS_COLOR, 0.35), 2.0)
		var left := clampf(p.possess_left / maxf(p.possess_for, 0.01), 0.0, 1.0)
		draw_arc(mid, s + 8.0, -PI * 0.5, -PI * 0.5 + TAU * left, 28, Style.POSSESS_COLOR, 2.0)
	elif enemy.alert > 0.0:
		_draw_alert(Vector2(0, over - 16.0))
	elif enemy.aggro:
		draw_circle(Vector2(0, over - 20.0), 2.5, Style.AGGRO_DOT)

## The "!", standing on `foot`: where the dot that follows it hangs.
func _draw_alert(foot: Vector2) -> void:
	var px := float(Sprites.PIXEL_SCALE)
	var rows := ALERT_ART.size()
	var left := foot + Vector2(-String(ALERT_ART[0]).length() * 0.5, -rows) * px
	for y in rows:
		var row := String(ALERT_ART[y])
		for x in row.length():
			var col := Style.ALERT_MARK if row[x] == "#" else Style.ALERT_EDGE
			draw_rect(Rect2(left + Vector2(x, y) * px, Vector2.ONE * px), col)
