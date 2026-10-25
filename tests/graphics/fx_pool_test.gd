extends Node2D
## The loose visuals `Fx` spawns — sparks, rings, floating words — come from
## pools: a burst is lent to the screen running, plays itself out and goes back,
## the next burst is the same nodes again rather than new ones, none of them is
## ever a child of the screen, and a screen that goes takes back at once
## whatever it still had out.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[FXPOOL] PASS ", what)
	else:
		fails += 1
		push_error("FXPOOL FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()

func world() -> Node2D:
	var w := Node2D.new()
	add_child(w)
	Arena.register(w)
	return w

func _ready() -> void:
	var sparks: Pool = Fx.sparks
	var w := world()
	await frames(2)
	var base_out := sparks.out_count()

	for i in 20:
		Fx.burst(Vector2(100 + i * 10, 200), Color.WHITE, 6, 150.0)
	check(sparks.out_count() == base_out + 20, "twenty bursts are twenty sparks out (%d)" % sparks.out_count())
	check(w.get_child_count() == 0, "and not one of them is a child of the screen")
	await frames(2)
	await wait(0.6)
	check(sparks.out_count() == base_out, "played out, every one is back (%d out)" % sparks.out_count())
	var waiting := sparks.idle_count()
	check(waiting >= 20, "and waiting to be lent again (%d)" % waiting)

	var one := sparks.borrow(w)
	var holder := one.get_parent()
	sparks.give_back(one)
	var made := holder.get_child_count()
	for i in 20:
		Fx.burst(Vector2(100 + i * 10, 200), Color.RED, 6, 150.0)
	check(holder.get_child_count() == made and sparks.idle_count() == waiting - 20,
		"the next twenty are the same nodes again, none made (%d held, %d waiting)" % [holder.get_child_count(), sparks.idle_count()])
	check(holder.is_inside_tree() and not w.is_ancestor_of(holder), "held under the root, past the screen")

	# Rings and words the same way.
	Fx.ring(Vector2(300, 300), Color.WHITE, 40.0)
	Fx.damage_number(Vector2(300, 260), 12.0)
	Fx.text(Vector2(300, 240), "PARRY")
	check(Fx.rings.out_count() == 1 and Fx.words.out_count() == 2, "a ring and two words, out")
	await wait(1.0)
	check(Fx.rings.out_count() == 0 and Fx.words.out_count() == 0, "and back once they have faded and drifted off")

	# The screen going takes back what it had out, mid-flight.
	for i in 10:
		Fx.burst(Vector2(200, 200), Color.WHITE, 6, 150.0)
	await frames(2)
	var lent := sparks.out_count()
	check(lent >= 10, "ten more out (%d)" % lent)
	w.queue_free()
	await frames(2)
	check(sparks.out_count() == 0, "the screen goes, and everything it had out is back at once (%d out)" % sparks.out_count())
	check(holder.get_child_count() == made, "none lost with it")

	# What a pool keeps waiting is bounded; a big fight does not leave a big pool.
	var w2 := world()
	for i in 100:
		Fx.burst(Vector2(200, 200), Color.WHITE, 2, 50.0)
	await wait(0.6)
	await frames(2)
	check(sparks.out_count() == 0 and sparks.idle_count() == sparks.keep,
		"a hundred played out leave %d waiting, as many as it keeps" % sparks.idle_count())
	w2.queue_free()

	print("[FXPOOL] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
