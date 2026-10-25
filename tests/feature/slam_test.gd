extends Node2D
## A wall slam (`Actor.SLAM_SPEED`): a body KNOCKBACK threw that meets rock
## still going hard enough cracks it — the `wall_slam` cue — and is hurt and
## stunned by it, once to a throw. Under that speed, or pushed by anything but
## KNOCKBACK, it only meets the wall; and another body is no wall.
##
## Headless: nothing here is looked at, only what the bodies took and what was
## announced.

var fails := 0
var slams: Array = []

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SLAM] PASS ", what)
	else:
		fails += 1
		push_error("SLAM FAIL: " + what)

func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## A stretch of rock: a static body on the world's layer, as a room's is.
func rock(rect: Rect2) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	shape.shape = r
	shape.position = rect.get_center()
	b.add_child(shape)
	add_child(b)
	return b

## A dummy standing on the floor at `x`, its own lane `lane` rows down so no
## two of them meet.
func dummy(x: float, lane: int) -> Enemy:
	var e := Enemy.new()
	e.setup("DUMMY", 1, "")
	add_child(e)
	e.global_position = Vector2(x, lane * 400.0 + 300.0)
	return e

func _ready() -> void:
	Arena.register(self)
	Cues.fired.connect(func(cue: StringName, d: Dictionary) -> void:
		if cue == &"wall_slam":
			slams.append(d))
	# Five lanes, each with a wall at x = 400.
	for lane in 5:
		rock(Rect2(400, lane * 400.0, 40, 400))
	await physics(2)
	await _hard()
	await _soft()
	await _not_knockback()
	await _into_a_body()
	await _the_kill()
	print("[SLAM] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Thrown hard at a wall close by: it cracks, and the one thrown is hurt and
## stunned — once, though the push goes on along the wall.
func _hard() -> void:
	var e := dummy(340.0, 0)
	await physics(2)
	var hp := e.health
	slams.clear()
	e.knockback(Vector2.RIGHT, Attacks.KNOCKBACK_FORCE + 160.0, 0)
	await physics(40)
	check(slams.size() == 1, "thrown hard into the wall, it slams once (%d)" % slams.size())
	var d: Dictionary = slams[0] if not slams.is_empty() else {}
	check(not d.is_empty() and float(d.get("force", 0.0)) >= 1.0
			and (d.get("normal", Vector2.ZERO) as Vector2).is_equal_approx(Vector2.LEFT),
		"the crack is on the wall's face, as hard as it struck (%s)" % str(d))
	var took := hp - e.health
	check(took >= Actor.SLAM_DAMAGE - 0.01, "and the one thrown is hurt by it (%.1f)" % took)
	check(e.stun_time > 0.0 or e.stun_guard > 0.0, "and stunned")
	check(e.slam_by == -1, "the throw is spent on it")
	e.queue_free()

## Thrown from far enough off that it has slowed under the speed by the time it
## meets the wall: it meets it, and nothing more.
func _soft() -> void:
	# Some 140 pixels short of the wall: far enough to slow under the speed,
	# near enough to get there.
	var e := dummy(246.0, 1)
	await physics(2)
	var hp := e.health
	slams.clear()
	e.knockback(Vector2.RIGHT, Attacks.KNOCKBACK_FORCE + 160.0, 0)
	await physics(90)
	check(e.global_position.x > 380.0, "thrown from further off it still reaches the wall (%.0f)" % e.global_position.x)
	check(slams.is_empty() and is_equal_approx(e.health, hp) and e.stun_time <= 0.0,
		"but slower than the slam asks, it only meets it")
	e.queue_free()

## As hard a push from anything but KNOCKBACK — a heavy hit's own shove, a
## PULL's drag — slams nothing.
func _not_knockback() -> void:
	var e := dummy(340.0, 2)
	await physics(2)
	var hp := e.health
	slams.clear()
	e.knockback(Vector2.RIGHT, Attacks.KNOCKBACK_FORCE + 160.0)
	await physics(40)
	check(slams.is_empty() and is_equal_approx(e.health, hp),
		"as hard a push that is not KNOCKBACK's slams nothing")
	e.queue_free()

## Thrown into another body, not the rock: no slam.
func _into_a_body() -> void:
	var e := dummy(300.0, 3)
	var other := dummy(345.0, 3)
	await physics(2)
	slams.clear()
	e.knockback(Vector2.RIGHT, Attacks.KNOCKBACK_FORCE + 160.0, 0)
	await physics(4)
	check(slams.is_empty(), "another body in the way is no wall")
	e.queue_free()
	other.queue_free()

## A slam that kills: the body goes, and the kill is counted when the player
## threw it.
func _the_kill() -> void:
	var e := dummy(340.0, 4)
	await physics(2)
	e.health = 1.0
	var kills := int(GameState.records["kills"])
	e.knockback(Vector2.RIGHT, Attacks.KNOCKBACK_FORCE + 160.0, 0)
	await physics(40)
	check(not is_instance_valid(e) or e.dead, "a slam can kill")
	check(int(GameState.records["kills"]) == kills + 1,
		"and the kill is the player's, who threw it (%d)" % int(GameState.records["kills"]))
