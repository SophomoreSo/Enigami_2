extends Node
## The phone as a rule (`Phone`): an alarm counts down on the clock it is
## given and rings when it runs out, for as long as a ring lasts; ringing, it
## calls every monster in earshot that goes anywhere, which comes to it and
## stands over it, and goes back to its own business when the ringing stops;
## put down on a room's floor it lies there (`PhoneProp`), is still there when
## the room is walked back into, goes with a parked raid, and is picked up
## again with interact; and its photos are files it keeps and throws away.

const PHOTOS := "user://phone_test/photos"

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[PHONE] PASS ", what)
	else:
		fails += 1
		push_error("PHONE FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Until `cond` holds, or `seconds` have gone by on the wall.
func until(cond: Callable, seconds: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > int(seconds * 1000.0):
			return false
		await get_tree().physics_frame
	return true

func _ready() -> void:
	GameState.reset_profile()
	Phone.photo_dir = PHOTOS
	_sweep()
	Phone.reset()
	seed(20261017)

	_alarm()
	await _ring_and_lure()
	await _lying()
	_photos()
	_sweep()
	Phone.reset()

	print("[PHONE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the alarm -------------------------------------------------------------------
func _alarm() -> void:
	check(Phone.carried() and not Phone.alarm_set() and Phone.ringing == 0.0, "a new phone is in the hand, with nothing set")
	Phone.set_alarm(7.0)
	check(Phone.alarm_set() and is_equal_approx(Phone.alarm, 7.0), "an alarm is set for so many seconds")
	Phone.tick(3.0, Vector2.ZERO)
	check(is_equal_approx(Phone.alarm, 4.0), "and counts down on the clock it is given (%.1f)" % Phone.alarm)
	Phone.set_alarm(1.0)
	check(is_equal_approx(Phone.alarm, Phone.ALARM_MIN), "it is set for no less than the least (%.0f)" % Phone.alarm)
	Phone.set_alarm(99999.0)
	check(is_equal_approx(Phone.alarm, Phone.ALARM_MAX), "and no more than the most (%.0f)" % Phone.alarm)
	Phone.clear_alarm()
	check(not Phone.alarm_set(), "STOP takes it off")
	var rang := [false]
	Phone.rang.connect(func() -> void: rang[0] = true, CONNECT_ONE_SHOT)
	Phone.set_alarm(10.0)
	Phone.tick(10.5, Vector2.ZERO)
	check(rang[0] and not Phone.alarm_set() and is_equal_approx(Phone.ringing, Phone.RING_TIME),
		"run out, it rings, for as long as a ring lasts (%.1f)" % Phone.ringing)
	Phone.tick(Phone.RING_TIME * 0.5, Vector2.ZERO)
	check(Phone.ringing > 0.0, "and is still ringing halfway through")
	Phone.tick(Phone.RING_TIME, Vector2.ZERO)
	check(Phone.ringing == 0.0 and not Phone.alarm_set(), "and quiet after, with nothing set")
	Phone.set_alarm(10.0)
	Phone.tick(11.0, Vector2.ZERO)
	Phone.clear_alarm()
	check(Phone.ringing == 0.0, "STOP while it rings stops it")

## --- ringing, and what comes to see ---------------------------------------------
func _ring_and_lure() -> void:
	var room := Room.new()
	add_child(room)
	room.build(Vector2i.ZERO, {"kind": "entry", "danger": 1, "region": 0, "variant": 3,
		"flat": true, "enemies": [], "loot": []}, {}, 1)
	var player := Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	player.room = room
	var floor_at := room.spawn_point()
	# The player far enough along the floor that nothing notices them; the
	# phone put down well away from them; a Crawler between, nearer the phone.
	player.global_position = floor_at + Vector2(400.0, 0.0)
	var here := floor_at + Vector2(-400.0, 10.0)
	room._spawn_enemy({"kind": "CRAWLER", "mod": "", "pos": [floor_at.x - 100.0, floor_at.y]})
	room._spawn_enemy({"kind": "SENTRY", "mod": "", "pos": [floor_at.x - 160.0, floor_at.y]})
	await phys(4)
	var crawler: Enemy = null
	var sentry: Enemy = null
	for c in room.get_children():
		if c is Enemy and (c as Enemy).kind == "CRAWLER":
			crawler = c
		elif c is Enemy and (c as Enemy).kind == "SENTRY":
			sentry = c
	check(crawler != null and sentry != null and not crawler.aggro, "a Crawler and a Sentry on the floor, with nothing in sight")
	var prop := PhoneProp.lay(room, player, here)
	Phone.put_down_at("raid", Vector2i.ZERO, here)
	check(not Phone.carried() and is_instance_valid(prop), "the phone put down on the floor")
	Phone.set_alarm(10.0)
	Phone.alarm = 0.01
	Phone.tick(0.02, prop.global_position)
	check(Phone.ringing > 0.0, "and ringing where it lies")
	check(crawler.lured() and crawler.lure_for > 0.0, "the Crawler is called to it")
	check(not sentry.lured(), "the Sentry, which holds its ground, is not")
	var start := crawler.global_position.x
	# The phone goes on ringing, ticked as the raid would tick it, while the
	# Crawler comes.
	var came := await until(func() -> bool:
		Phone.tick(1.0 / 60.0, prop.global_position)
		return absf(crawler.global_position.x - here.x) <= Enemy.LURE_STOP, 6.0)
	check(came, "and it comes to it (from %.0f to %.0f, the phone at %.0f)" % [start, crawler.global_position.x, here.x])
	var there := crawler.global_position.x
	for i in 30:
		Phone.tick(1.0 / 60.0, prop.global_position)
		await get_tree().physics_frame
	check(absf(crawler.global_position.x - there) < 20.0 and Phone.ringing > 0.0,
		"and stands over it while it rings (%.0f, was %.0f)" % [crawler.global_position.x, there])
	Phone.tick(Phone.RING_TIME, prop.global_position)
	await phys(60)
	check(Phone.ringing == 0.0 and not crawler.lured(), "the ringing over, it is no longer called")
	# One that has somebody in sight is not called away from them.
	crawler.global_position = player.global_position + Vector2(-120.0, 0.0)
	crawler.face(1)
	await phys(4)
	check(crawler.aggro, "a Crawler that has noticed the player hunts them")
	Phone.call_monsters(here)
	check(not crawler.lured(), "and is not called away from them by the phone")
	prop.queue_free()
	Phone.pick_up()
	Phone.clear_alarm()
	room.queue_free()
	player.queue_free()
	await frames(2)

## --- lying on a raid's floor -------------------------------------------------------
func _lying() -> void:
	GameState.reset_profile()
	GameState.raid_seed = 20261017
	GameState.deploy("GUN")
	var raid := Raid.new()
	add_child(raid)
	# Until the player has come down onto the floor from where the room puts
	# them: the phone is put down at their feet.
	await phys(40)
	var home := raid.room.coord
	check(raid.phone_prop() == null and Phone.carried(), "a raid starts with the phone in the hand")
	check(raid.put_phone_down(), "it can be put down where the player stands")
	var prop := raid.phone_prop()
	check(prop != null and Phone.lies_in("raid", home) and not Phone.carried(),
		"and lies on this room's floor")
	check(not raid.put_phone_down(), "it cannot be put down twice")
	await phys(30)
	check(prop.offered() and raid.room.phone_offered() and raid.use_nearby(),
		"standing over it, interact would pick it up, and the console's USE says so")
	# Next door and back: it is where it was left.
	var away := Vector2i(-1, -1)
	for dir in raid.map.doors_for(home):
		away = home + RaidMap.dir_delta(int(dir))
		break
	check(away.x >= 0, "the entry has a room next door")
	var at := prop.global_position
	raid.go_to(away)
	await frames(2)
	check(raid.phone_prop() == null, "next door there is no phone on the floor")
	var parked := raid.park()
	check(parked.has("phone") and Phone.lies_in("raid", home), "a parked raid keeps where it lies")
	raid.go_to(home)
	await phys(40)
	prop = raid.phone_prop()
	check(prop != null and prop.global_position.distance_to(at) < 2.0,
		"back in the room, it lies where it was left")
	# Picked up with interact.
	raid.player.global_position = prop.global_position
	await phys(3)
	Input.action_press("interact")
	await phys(2)
	Input.action_release("interact")
	await frames(3)
	check(Phone.carried() and raid.phone_prop() == null, "interact over it picks it up")
	# Restored from the parked record, it lies there again.
	Phone.restore(parked["phone"])
	check(not Phone.carried() and Phone.lies_in("raid", home), "restored from the record, it lies there again")
	Phone.recover()
	check(Phone.carried(), "and is back in the hand when the run is over")
	raid.queue_free()
	await frames(2)

## --- photos -----------------------------------------------------------------------
func _photos() -> void:
	check(Phone.photos().is_empty(), "no photos to start with")
	var img := Image.create(16, 9, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	var first := Phone.save_photo(img)
	check(first != "" and FileAccess.file_exists(first), "a photo is kept as a file (%s)" % first)
	var second := Phone.save_photo(img)
	check(second != "" and second != first, "and the next under a name of its own")
	check(Phone.photos().size() == 2 and Phone.photos()[0] == second, "the gallery lists them, newest first")
	Phone.delete_photo(first)
	check(Phone.photos().size() == 1 and not FileAccess.file_exists(first), "DELETE throws one away")
	check(Phone.save_photo(null) == "", "nothing is kept of no picture")

func _sweep() -> void:
	var d := DirAccess.open(PHOTOS)
	if d != null:
		for f in d.get_files():
			DirAccess.remove_absolute(PHOTOS.path_join(f))
