extends Node2D
## The player's input line (`InputProvider`): the hands at the head of it, a
## hold that takes them off, an act any stop may raise and a shut gate anywhere
## drops, the rank that keeps a hold before whatever steers — and a walk that
## takes the body somewhere, gives it back to a push the other way, walks over a
## push held from before, and walks a body nobody may move.
##
## And whose the body is while all that goes on: the player's, or the
## computer's — the game holding it or walking it, or `ComputerHands` playing it
## in the player's place, which drop what the player's hands say, are stopped by
## the same holds, and point with the game's own pointer.
##
## The floor is seen from above: nothing falls, so the body needs no ground
## under it, and a way is a vector on the floor.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[INPUT] PASS ", what)
	else:
		fails += 1
		push_error("INPUT FAIL: " + what)

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func until(cond: Callable, limit: int = 240) -> bool:
	for i in limit:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())

func solid(centre: Vector2, size: Vector2) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = centre
	b.add_child(cs)
	add_child(b)

## Somewhere further down the line that presses dash for the body, `times`
## physics frames running — the devlog's own case for a gate.
class Presser extends InputMiddleware:
	var times := 0
	func _init() -> void:
		rank = STEER
	func process(s: InputState) -> InputState:
		if times > 0 and Engine.is_in_physics_frame():
			times -= 1
			s.dash_pressed = true
		return s

## Something that drives the body right, whatever the hands say.
class Pusher extends InputMiddleware:
	func _init() -> void:
		rank = STEER
	func process(s: InputState) -> InputState:
		s.move = Vector2.RIGHT
		return s

## Lets the body come to a stop, with every key up.
func settle(p: Player) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "dash"]:
		Input.action_release(a)
	await until(func() -> bool: return not p.is_dashing() and p.velocity.length() < 1.0)
	await phys(2)

func _ready() -> void:
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = Vector2(300, 360)
	add_child(p)
	await settle(p)

	# --- the hands, at the head of the line ---------------------------------------
	var from := p.global_position.x
	Input.action_press("move_right")
	await phys(12)
	check(p.global_position.x - from > 20.0,
		"the hands walk the body, with nothing on the line after them (%.0f)" % (p.global_position.x - from))
	check(not p.controls_locked(), "and nothing holds it")
	await settle(p)

	# Eight ways: two keys together walk a diagonal, no faster than one.
	var at := p.global_position
	Input.action_press("move_right")
	Input.action_press("move_up")
	await phys(12)
	var went := p.global_position - at
	check(went.x > 10.0 and went.y < -10.0 and absf(went.x + went.y) < 2.0,
		"right and up together walk the diagonal between them (%s)" % str(went))
	check(absf(p.velocity.length() - Player.RUN_SPEED) < 1.0,
		"no faster than walking one way (%.0f)" % p.velocity.length())
	check(p.facing.is_equal_approx(Vector2(1, -1).normalized()) and p.facing_name() == Actor.FACE_SIDE,
		"the body faces the way it walks, and a diagonal reads as its side (%s, %s)" % [str(p.facing), p.facing_name()])
	await settle(p)
	Input.action_press("move_down")
	await phys(6)
	check(p.facing_name() == Actor.FACE_DOWN and p.side() == 1,
		"walking down faces down, and keeps the side it last had (%s, %d)" % [p.facing_name(), p.side()])
	await settle(p)

	# --- a hold -----------------------------------------------------------------------
	var off := HandsOff.new()
	p.input.add(off)
	check(p.controls_locked(), "a hold on the line holds the player, whoever put it there")
	from = p.global_position.x
	Input.action_press("move_right")
	Input.action_press("dash")
	await phys(12)
	check(absf(p.global_position.x - from) < 1.0 and not p.is_dashing(),
		"with the hands off, walking and dashing do nothing (moved %.1f)" % (p.global_position.x - from))
	Input.action_release("dash")
	p.input.remove(off)
	await phys(12)
	check(not p.controls_locked() and p.global_position.x - from > 20.0,
		"taken off, the key still held walks again (%.0f)" % (p.global_position.x - from))
	await settle(p)

	# The two the game has always had are holds on the same line.
	p.talk_locked = true
	check(p.controls_locked() and p.input.held(), "talk_locked is a hold on the line")
	p.talk_locked = false
	p.input_locked = true
	check(p.controls_locked(), "and so is input_locked")
	p.input_locked = false
	check(not p.controls_locked() and not p.input.held(), "and off again, nothing is left on it")

	# --- an act any stop may raise, and a gate that drops it ------------------------------
	var presser := Presser.new()
	p.input.add(presser)
	presser.times = 1
	await phys(2)
	check(p.is_dashing(),
		"something further down the line presses dash, and the body dashes (%s)" % p.state_name())
	await settle(p)
	await until(func() -> bool: return p.can_dash())
	p.input.add(off)
	presser.times = 1
	at = p.global_position
	await phys(6)
	check(presser.times == 0 and not p.is_dashing() and p.global_position.distance_to(at) < 1.0,
		"a hold up the line shuts the gate on it, though it stands before the press")
	p.input.remove(off)
	p.input.remove(presser)

	# --- rank -------------------------------------------------------------------------
	var pusher := Pusher.new()
	p.input.add(pusher)
	p.input.add(off)
	from = p.global_position.x
	await phys(12)
	check(p.global_position.x - from > 20.0 and p.controls_locked(),
		"a hold that joins after something that steers still stands before it: the body is driven, the hands are off (%.0f)"
			% (p.global_position.x - from))
	p.input.remove(pusher)
	p.input.remove(off)
	await settle(p)

	# --- a walk -------------------------------------------------------------------------
	at = p.global_position
	var w := WalkTo.new(at + Vector2(120.0, 40.0), Vector2.LEFT)
	p.input.add(w)
	check(await until(func() -> bool: return w.done) and w.arrived and not w.refused,
		"a walk gets there")
	await settle(p)
	check(p.global_position.distance_to(w.to) <= WalkTo.THERE + 1.0,
		"and stops on the spot rather than sliding past it (%.1f off)" % p.global_position.distance_to(w.to))
	check(p.facing.is_equal_approx(Vector2.LEFT) and p.side() == -1,
		"turned the way it was asked to face, though it walked the other way")
	check(not p.input.has(w), "and done, it has left the line by itself")

	# A dash pressed on the way does nothing: the walk shuts that gate.
	w = WalkTo.new(p.global_position + Vector2(-160.0, 0.0))
	p.input.add(w)
	await phys(4)
	Input.action_press("dash")
	await phys(6)
	check(not p.is_dashing() and not w.done,
		"a dash pressed mid-walk does not dash, and the walk goes on")
	Input.action_release("dash")
	await until(func() -> bool: return w.done)
	await settle(p)

	# --- refused ------------------------------------------------------------------------
	from = p.global_position.x
	w = WalkTo.new(p.global_position + Vector2(160.0, 0.0), Vector2.LEFT)
	p.input.add(w)
	await phys(8)
	check(p.global_position.x > from + 2.0 and not w.done, "a walk under way")
	Input.action_press("move_left")
	await phys(2)
	check(w.refused and w.done and not w.arrived, "a push the other way takes the body back")
	var x := p.global_position.x
	await phys(12)
	check(p.global_position.x < x - 10.0, "and goes where it was pushed (%.0f)" % (p.global_position.x - x))
	await settle(p)

	# --- a push held from before -----------------------------------------------------------
	Input.action_press("move_left")
	await phys(6)
	from = p.global_position.x
	w = WalkTo.new(p.global_position + Vector2(220.0, 0.0))
	p.input.add(w)
	await phys(30)
	check(not w.refused and p.global_position.x > from + 10.0,
		"a push already held when the walk began does not refuse it: walked over (%.0f)" % (p.global_position.x - from))
	Input.action_release("move_left")
	await phys(3)
	check(not w.done, "letting go of it is nothing either")
	Input.action_press("move_left")
	await phys(2)
	check(w.refused, "but pushed again once it was let go of, it does")
	await settle(p)

	# --- a body nobody may move ---------------------------------------------------------------
	p.talk_locked = true
	w = WalkTo.new(p.global_position + Vector2(90.0, 0.0), Vector2.LEFT)
	p.input.add(w)
	Input.action_press("move_left")
	Input.action_press("dash")
	var reached := await until(func() -> bool: return w.done)
	Input.action_release("dash")
	Input.action_release("move_left")
	check(reached and w.arrived and p.global_position.distance_to(w.to) <= WalkTo.THERE + 2.0,
		"held in a conversation, the walk still takes the body there: it stands after the hold (%.1f off)"
			% p.global_position.distance_to(w.to))
	check(not w.refused, "and the hands, held, cannot refuse it")
	await phys(2)
	check(p.side() == -1 and p.controls_locked(), "turned as asked, and still held")
	p.talk_locked = false
	await settle(p)

	# --- something in the way -------------------------------------------------------------------
	solid(Vector2(p.global_position.x + 70.0, p.global_position.y), Vector2(20.0, 120.0))
	await phys(2)
	w = WalkTo.new(p.global_position + Vector2(240.0, 0.0), Vector2.LEFT)
	p.input.add(w)
	check(await until(func() -> bool: return w.done) and w.arrived,
		"a wall in the way: the walk stops getting closer, and calls that there")
	check(w.to.x - p.global_position.x > 150.0,
		"short of the spot (%.0f short)" % (w.to.x - p.global_position.x))
	await settle(p)

	# --- whose the body is ------------------------------------------------------------------------
	# The player's, or the computer's: the game holding it or walking it, or
	# something playing it in the player's place. A screen that has the keys is
	# neither — the player put the body aside for that themselves.
	check(not p.taken_over(), "with the player's own hands on it, the body is not taken over")
	p.talk_locked = true
	check(p.taken_over(), "held in a conversation, it is the computer's")
	p.input_locked = true
	check(not p.taken_over(), "but not under a screen that has the keys, which is the player's own doing")
	p.talk_locked = false
	check(not p.taken_over(), "nor under a screen alone")
	p.input_locked = false
	check(p.stun(0.2), "(a stun takes)")
	await phys(3)
	check(p.taken_over(), "stunned, it is the computer's")
	await until(func() -> bool: return not p.stunned())
	await phys(3)
	check(not p.taken_over(), "and the player's again the moment it comes round")
	w = WalkTo.new(p.global_position + Vector2(-100.0, 0.0))
	p.input.add(w)
	check(p.taken_over(), "walked somewhere, it is the computer's for the walk")
	await until(func() -> bool: return w.done)
	await phys(2)
	check(not p.taken_over(), "and given back on getting there")
	await settle(p)

	# --- the computer's hands ---------------------------------------------------------------------
	var bot := ComputerHands.new()
	p.input.add(bot)
	check(p.taken_over() and not p.controls_locked(),
		"the computer's hands on the line take the body over, and hold nothing")
	from = p.global_position.x
	Input.action_press("move_right")
	Input.action_press("attack")
	Input.action_press("dash")
	await phys(12)
	var said := p.input.state()
	check(absf(p.global_position.x - from) < 1.0 and not p.is_dashing() and not said.attack,
		"what the player's hands say is dropped: walking, dashing and attacking do nothing (moved %.1f)"
			% (p.global_position.x - from))
	Input.action_release("attack")
	Input.action_release("dash")
	bot.move = Vector2.LEFT
	bot.attack = true
	await phys(12)
	said = p.input.state()
	check(p.global_position.x < from - 20.0 and said.attack,
		"and the body does what the computer says, the other way and attacking (%.0f)" % (p.global_position.x - from))
	bot.move = Vector2.ZERO
	bot.attack = false
	await settle(p)
	await until(func() -> bool: return p.can_dash())

	# What happens, as against what lasts: raised once, and read once by each
	# kind of frame.
	bot.dash()
	await phys(2)
	check(p.is_dashing(), "told to dash, the body dashes (%s)" % p.state_name())
	await settle(p)
	await until(func() -> bool: return p.can_dash())
	await phys(6)
	check(not p.is_dashing(), "once: the press is not carried into the frames after it")
	bot.cast = true
	await phys(3)
	check(p.input.state().cast, "the cast button held is held")
	bot.cast = false
	var releases := 0
	for i in 5:
		await get_tree().process_frame
		if p.input.state().cast_released:
			releases += 1
	check(releases == 1, "and letting go of it is one release, in the frame it happens (%d)" % releases)

	# The computer plays by the player's rules: a hold stops its hands too.
	p.talk_locked = true
	bot.move = Vector2.RIGHT
	bot.dash()
	from = p.global_position.x
	await phys(12)
	check(absf(p.global_position.x - from) < 1.0 and not p.is_dashing(),
		"a hold further down the line stops the computer's hands as it stops the player's (moved %.1f)"
			% (p.global_position.x - from))
	p.talk_locked = false
	bot.move = Vector2.ZERO
	await settle(p)

	# It points with the game's own pointer, which it leads, and the body aims
	# where that is. Nothing here draws the world through a camera, so a place in
	# the world and a place on the screen are the same numbers.
	var target := p.global_position + Vector2(200.0, -120.0)
	bot.point_at(target)
	await phys(3)
	check(Pointer.computer_is_pointing(), "while it plays, the computer is the one pointing")
	check(Pointer.point.is_equal_approx(target),
		"with the game's own pointer, led to where it points (%s, asked %s)" % [str(Pointer.point), str(target)])
	check(p.aim.is_equal_approx((target - p.global_position).normalized()),
		"which the body aims at (%s)" % str(p.aim))
	var off_screen := Vector2(5000.0, p.global_position.y)
	bot.point_at(off_screen)
	await phys(3)
	var edge := get_viewport().get_visible_rect().size.x - 1.0
	check(is_equal_approx(Pointer.point.x, edge) and is_equal_approx(p.aim_point.x, edge),
		"a place off the screen is pointed at from the screen's edge, as a hand would have to (%s)" % str(Pointer.point))
	p.input.remove(bot)
	await phys(3)
	check(not p.taken_over() and not Pointer.computer_is_pointing(),
		"taken off the line, the body and the pointer are the player's again")

	print("[INPUT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
