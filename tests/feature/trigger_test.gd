extends Node2D
## A trigger's follow-ups have to play out as separate attacks over time.
## Spawned inline, every link of a chain ran inside the frame of the hit that
## caused it, each reading the attacker's position from before the current
## attack had moved them — so chained dash-slashes computed the same start and
## the same destination and stacked into one dash that hit several times.
##
## The scene is built by hand rather than driving a raid: an auto dash-slash
## seeks the nearest target, so the count is only meaningful when exactly one
## target exists and nothing else is in flight.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[TRIG] PASS ", what)
	else:
		fails += 1
		push_error("TRIG FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func link(next: Payload) -> Payload:
	var p := Payload.new()
	p.form = "DASHSLASH"
	p.auto_aim = 1
	p.damage = 4.0
	p.on_hit = next
	return p

func _ready() -> void:
	Arena.register(self)
	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	p.position = Vector2(500, 320)
	add_child(p)

	var dummy := Enemy.new()
	dummy.setup("DUMMY", 1, "")
	dummy.collision_layer = 4
	dummy.collision_mask = 1
	add_child(dummy)
	dummy.global_position = Vector2(620, 385)

	await get_tree().physics_frame
	await get_tree().physics_frame
	# Hit-stop from any earlier frame would stretch the window this measures in.
	TimeCtl.clear()
	await frames(2)

	var chain := link(link(link(null)))
	var known: Array = []
	var at_frame: Array = []
	var starts: Array = []
	Attacks.spawn(chain, {"attacker": p, "room": null, "team": 0,
		"aim": Vector2.RIGHT, "origin": p.global_position})
	for i in 120:
		await get_tree().process_frame
		for c in get_children():
			if c is DashSlash and not known.has(c):
				known.append(c)
				at_frame.append(i)
				starts.append(c.from)
	print("[TRIG] %d dashes, on frames %s" % [known.size(), str(at_frame)])

	check(known.size() == 3, "the whole chain runs (%d of 3 dashes)" % known.size())
	var same_frame := 0
	for i in range(1, at_frame.size()):
		if int(at_frame[i]) == int(at_frame[i - 1]):
			same_frame += 1
	check(same_frame == 0,
		"no link fires in the same frame as the one before it (%d did)" % same_frame)
	var stacked := 0
	for i in range(1, starts.size()):
		if (starts[i] as Vector2).distance_to(starts[i - 1]) < 1.0:
			stacked += 1
	check(stacked == 0,
		"and each link starts where the last one ended (%d started on top)" % stacked)

	print("[TRIG] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
