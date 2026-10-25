class_name Hands
extends InputMiddleware

## The player's own hands, at the head of their line: the keys, a gamepad, the
## console on the glass and the pointer, read through `Input` and `Pointer` the
## way the player always read them. It is the only thing on the line that knows
## a person is holding anything. Put something else at the head of a line and
## the same body walks for that instead — `ComputerHands` is that, for a demo or
## a test that plays the character.
##
## The console needs nothing here: a thumb on it presses the same actions a key
## does, and leans on the right stick to aim (`Touch`).

## The key of each slot, first to last (`Player.SLOTS`): the three a weapon is
## carried in, and then the empty hand's (`Player.EMPTY_HAND`).
const SLOT_ACTIONS: Array[StringName] = [&"weapon_1", &"weapon_2", &"weapon_3", &"weapon_4"]

func process(s: InputState) -> InputState:
	# The four move actions as one way on the floor, no longer than 1: a stick
	# gives every way between them and how far it is pushed, four keys give
	# the eight ways a pair of them can make. The dead zone is the input
	# map's.
	s.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	s.sprint = Input.is_action_pressed("sprint")
	s.attack = Input.is_action_pressed("attack")
	s.cast = Input.is_action_pressed("cast_skill")
	# Edges, as the frame being asked in sees them: the physics frame's when the
	# body asks while it moves, the drawn frame's when it asks while it is drawn.
	s.dash_pressed = Input.is_action_just_pressed("dash")
	s.cast_released = Input.is_action_just_released("cast_skill")
	# Another weapon in hand: a slot's own key, or one step along — the wheel,
	# which is a button that is down and up again inside one frame, a pad's
	# button, the console's key.
	for slot in SLOT_ACTIONS.size():
		if Input.is_action_just_pressed(SLOT_ACTIONS[slot]):
			s.weapon_slot = slot
	s.weapon_step = int(Input.is_action_just_pressed("weapon_next")) \
		- int(Input.is_action_just_pressed("weapon_prev"))
	s.use_pressed = Input.is_action_just_pressed("interact")
	s.step_out_pressed = Input.is_action_just_pressed("step_out")
	if body != null:
		_aim(s)
	return s

## The right stick while it is pushed past its dead zone, a gamepad's or the
## console's; the pointer the rest of the time.
func _aim(s: InputState) -> void:
	s.aiming = true
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > Player.STICK_DEAD:
		s.aim_by_stick = true
		s.aim = stick.normalized()
		s.aim_reach = Player.reach_of(stick.length())
		s.aim_point = body.global_position + s.aim * Player.STICK_AIM_REACH
		return
	s.aim_reach = 1.0
	# `Pointer` rather than the viewport: while the player has the controls the
	# game is doing the pointing, at whatever speed the setting asks for. It
	# answers the system's own pointer the rest of the time, and at 1.0 the two
	# are the same thing.
	var at := Pointer.world_point(body)
	var m := at - body.global_position
	s.aim = m.normalized() if m.length() > 4.0 else Vector2.ZERO
	s.aim_point = at
