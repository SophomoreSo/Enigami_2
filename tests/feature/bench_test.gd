extends Node2D
## A bench to sit on: pressing interact beside one walks the body over to its
## seat — a walk, not a step to it, which a push the other way takes back — and
## sits it down there, and it stays sat until it is asked to do anything else —
## a step, a dash — or interact is pressed again, or a blow gets through; a way
## held all along the walk does not stand it up until it is pushed again. Out of
## reach a press sits nobody down. A map made in the map creator puts one down
## in the cell it was laid in, and the hideout stands one on its floor between
## its stations, which the shell is told a press would use. The rules alone:
## the bench's picture and the body's sitting pose are the views'.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[BENCH] PASS ", what)
	else:
		fails += 1
		push_error("BENCH FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func press() -> void:
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await phys(2)

func until(cond: Callable, limit: int = 240) -> bool:
	for i in limit:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())

func _ready() -> void:
	GameState.reset_profile()
	await _made()
	await _hideout()
	print("[BENCH] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## A map twenty cells by twelve, walled round, with a bench laid on its floor
## in column 9 of row 6.
func _made() -> void:
	var made := MadeRoom.new()
	var plan := PackedStringArray()
	for y in 12:
		plan.append(MadeRoom.ROCK.repeat(20) if y == 0 or y == 11 else MadeRoom.ROCK + ".".repeat(18) + MadeRoom.ROCK)
	plan[6] = MadeRoom.ROCK + ".".repeat(8) + MadeRoom.BENCH + ".".repeat(9) + MadeRoom.ROCK
	made.plan = plan
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	add_child(p)
	made.player = p
	add_child(made)
	made.stand()
	p.room = made
	check(made.benches.size() == 1, "a map puts a bench down wherever one was laid (%d)" % made.benches.size())
	if made.benches.is_empty():
		made.free()
		p.free()
		return
	var b: Bench = made.benches[0]
	check(b.position == made.cell_center(9, 6) and b.player == p,
		"in the cell it was laid in, the middle of it, for whoever plays the map (%s)" % b.position)
	var hands := ComputerHands.new()
	p.input.add(hands)

	# Out of reach, a press sits nobody down.
	p.global_position = b.global_position + Vector2(Bench.RANGE + 30.0, 0.0)
	p.velocity = Vector2.ZERO
	await phys(3)
	await press()
	check(not p.seated() and not b.offered(), "out of its reach, interact sits nobody down")

	# In reach, a press walks the body over to the seat, and it sits down there.
	p.global_position = b.global_position + Vector2(-Bench.RANGE + 6.0, 0.0)
	p.velocity = Vector2.ZERO
	await phys(3)
	check(b.offered() and made.bench_offered(), "beside it, a press would sit the body down")
	var from := p.global_position
	await press()
	check(not p.seated() and b._approach != null and not b.offered(),
		"interact walks the body over to the seat, rather than sitting it down where it stands")
	var stride := 0.0
	var was := p.global_position
	for i in 120:
		if p.seated():
			break
		await phys(1)
		stride = maxf(stride, p.global_position.distance_to(was))
		was = p.global_position
	check(p.seated() and p.seat == b and b.taken() and p.global_position.distance_to(b.global_position) <= WalkTo.THERE + 0.01,
		"and sits it down there, over its middle (%s, the bench at %s)" % [str(p.global_position), str(b.global_position)])
	check(stride <= Player.RUN_SPEED / 60.0 + 0.5 and from.distance_to(b.global_position) > 20.0,
		"walked, not put there: never more than a run's step a frame (%.1f px at most, over %.0f px)"
			% [stride, from.distance_to(b.global_position)])
	var sat_at := p.global_position
	await phys(60)
	check(p.seated() and p.global_position.is_equal_approx(sat_at) and not b.offered(),
		"and it stays sat, and still, with nothing to sit down on again")

	# Anything asked of the body stands it up, and goes ahead.
	hands.move = Vector2.RIGHT
	await phys(3)
	check(not p.seated() and p.global_position.x > b.global_position.x, "a step stands it up, and is taken")
	hands.move = Vector2.ZERO
	await phys(10)
	# Further from the seat than WalkTo.THERE, so the press walks the last step.
	p.global_position = b.global_position + Vector2(4.0, 0.0)
	p.velocity = Vector2.ZERO
	await phys(4)
	await press()
	for i in 60:
		if p.seated():
			break
		await phys(1)
	check(p.seated(), "sat down again, after the step over")
	await press()
	check(not p.seated() and not b.taken(), "and interact again stands it up")

	# A push the other way on the walk takes the body back, and nothing sits.
	p.global_position = b.global_position + Vector2(-Bench.RANGE + 6.0, 0.0)
	p.velocity = Vector2.ZERO
	await phys(4)
	await press()
	await phys(2)
	hands.move = Vector2.LEFT
	await phys(10)
	hands.move = Vector2.ZERO
	await phys(40)
	check(not p.seated() and b._approach == null, "a push the other way on the walk takes the body back, and it does not sit")

	# A way held all along the walk does not stand it up once sat, until it is
	# let go of and pushed again.
	p.global_position = b.global_position + Vector2(-Bench.RANGE + 6.0, 0.0)
	p.velocity = Vector2.ZERO
	await phys(4)
	hands.move = Vector2.RIGHT
	await press()
	await until(p.seated, 120)
	await phys(20)
	check(p.seated() and p.global_position.distance_to(b.global_position) <= WalkTo.THERE + 0.01,
		"run up to it with the way still held, and it stays sat, and still, for as long as that is held")
	hands.move = Vector2.ZERO
	await phys(3)
	hands.move = Vector2.RIGHT
	await phys(3)
	hands.move = Vector2.ZERO
	check(not p.seated(), "and pushed again, it stands up")
	await phys(10)
	# Sat from a step up and down the floor as well as across: a bench has no
	# side to be sat from.
	p.global_position = b.global_position + Vector2(0.0, Bench.RANGE - 6.0)
	p.velocity = Vector2.ZERO
	await phys(4)
	await press()
	check(await until(p.seated, 120), "walked up to from down the floor, it is sat on the same")
	await phys(4)
	await until(func() -> bool: return p.can_dash(), 240)
	hands.move = Vector2.RIGHT
	hands.dash()
	await phys(3)
	check(not p.seated() and p.is_dashing(), "a dash stands it up, and dashes")
	hands.move = Vector2.ZERO
	await until(func() -> bool: return not p.is_dashing(), 240)
	p.global_position = b.global_position
	p.velocity = Vector2.ZERO
	await phys(4)
	await press()
	await until(p.seated, 60)
	var sat := p.seated()
	p.apply_damage(5.0, [], null, true)
	check(sat and not p.seated(), "and a blow that gets through stands it up")
	await press()
	await until(p.seated, 60)
	p.room = null
	check(not p.seated(), "out of the room, off its bench")
	p.queue_free()
	made.queue_free()
	await phys(2)

## The hideout's bench, on the floor between the stations.
func _hideout() -> void:
	var h := HideoutWorld.new()
	add_child(h)
	await frames(4)
	var room := h.room
	check(room.benches.size() == 1, "the hideout stands a bench (%d)" % room.benches.size())
	if room.benches.is_empty():
		h.free()
		return
	var b: Bench = room.benches[0]
	var laid := room.cells_marked(MadeRoom.BENCH)
	check(laid.size() == 1 and b.position == room.cell_center(laid[0].x, laid[0].y) and b.player == h.player
			and room.is_floor_at(b.global_position),
		"where the plan lays it, on the floor, for the player in it (%s)" % b.position)
	var far := true
	for id in h.stations:
		far = far and (h.stations[id] as Station).global_position.distance_to(b.global_position) > Station.RANGE + Bench.RANGE
	check(far, "out of every station's reach, so a press is one or the other")
	h.player.global_position = b.global_position + Vector2(10.0, 0.0)
	h.player.velocity = Vector2.ZERO
	await phys(10)
	check(h.use_nearby(), "beside it, the shell is told a press would use something")
	await press()
	check(await until(h.player.seated, 120) and h.open_panel == "", "and a press sits the body down on it, and opens nothing else")
	h.free()
