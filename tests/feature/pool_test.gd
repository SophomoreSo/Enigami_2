extends Node2D
## Pooling (`Pool`): a thing is made once and lent again and again; it is out
## shown and running, and waits hidden and still; a borrower lets go of it and
## it plays itself out before it goes back; a screen that goes away takes back
## at once whatever it had out, which lives on past it; the pool keeps no more
## waiting than it says; what is out pauses with the game; and two pools of
## the same thing are two.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[POOL] PASS ", what)
	else:
		fails += 1
		push_error("POOL FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Something to lend: it counts the frames it runs, and how often it was lent.
## Let go of, it runs `fade` more frames and hands itself back.
class Blip extends Node2D:
	var pool: Pool = null
	var lent_times := 0
	var ran := 0
	var fade := -1

	func _lent() -> void:
		lent_times += 1
		ran = 0
		fade = -1

	func _disposed() -> void:
		fade = 5

	func _process(_delta: float) -> void:
		ran += 1
		if fade > 0:
			fade -= 1
			if fade == 0:
				pool.give_back(self)

## The same, with nothing to finish: let go of, it goes straight back.
class Plain extends Node2D:
	pass

func scope() -> Node2D:
	var s := Node2D.new()
	add_child(s)
	return s

func _ready() -> void:
	var pool := Pool.new(Blip, 3)
	var here := scope()

	# Made once, lent again.
	var a := pool.borrow(here) as Blip
	await frames(3)
	check(a != null and pool.out_count() == 1 and pool.idle_count() == 0, "borrowing makes one, and it is out")
	check(a.get_parent() != here and a.is_inside_tree(), "it lives where the pool keeps it, not in the scope it is lent to")
	check(a.visible and a.ran > 0 and a.pool == pool, "out, it is shown and running, and knows its pool")
	pool.give_back(a)
	var ran_then := a.ran
	await frames(3)
	check(not a.visible and a.ran == ran_then and pool.idle_count() == 1 and pool.out_count() == 0,
		"handed back, it waits hidden and still")
	var b := pool.borrow(here) as Blip
	check(b == a and b.lent_times == 2 and b.visible, "the next borrower gets the same one back, made new again")

	# Let go of, it plays itself out first.
	pool.dispose(b)
	check(pool.is_out(b), "let go of, a thing with somewhere to go is still out")
	await frames(8)
	check(not pool.is_out(b) and not b.visible, "and goes back by itself once it has got there")
	var plain_pool := Pool.new(Plain, 4)
	var p := plain_pool.borrow(here)
	plain_pool.dispose(p)
	check(not plain_pool.is_out(p) and plain_pool.idle_count() == 1, "one with nowhere to go goes back the moment it is let go of")

	# A screen that goes takes back what it had out — which goes on existing.
	var there := scope()
	var lent_there: Array = []
	for i in 3:
		lent_there.append(pool.borrow(there))
	var lent_here := pool.borrow(here)
	await frames(2)
	check(pool.out_count() == 4, "four out, three to one screen and one to another")
	there.queue_free()
	await frames(2)
	var all_back := true
	var all_alive := true
	for t in lent_there:
		all_back = all_back and not pool.is_out(t)
		all_alive = all_alive and is_instance_valid(t)
	check(all_back and all_alive, "the screen they were lent to goes, and they are all back at once, none lost with it")
	check(pool.is_out(lent_here), "while what another screen borrowed is still out")

	# No more waiting than it keeps.
	var many: Array = []
	for i in 6:
		many.append(pool.borrow(here))
	for t in many:
		pool.give_back(t)
	pool.give_back(lent_here)
	await frames(2)
	check(pool.idle_count() == 3, "handed back past what it keeps, the rest are let go of (%d waiting)" % pool.idle_count())
	var freed := 0
	for t in many:
		if not is_instance_valid(t):
			freed += 1
	check(freed >= 3, "and really gone (%d freed)" % freed)

	# What is out pauses with the game.
	var c := pool.borrow(here) as Blip
	await frames(3)
	get_tree().paused = true
	var held := c.ran
	await frames(5)
	var paused_ran := c.ran
	get_tree().paused = false
	await frames(3)
	check(paused_ran == held and c.ran > held, "what is out stops while the game is paused, and goes on after")
	pool.give_back(c)

	# A screen that comes back and borrows again is watched again.
	var again := scope()
	var first := pool.borrow(again)
	remove_child(again)
	await frames(1)
	check(not pool.is_out(first), "a screen leaving the tree, not even freed, takes back what it had")
	add_child(again)
	var second := pool.borrow(again)
	remove_child(again)
	await frames(1)
	check(not pool.is_out(second), "and when it comes back and borrows again, it does again")
	again.free()

	# Two pools of one thing are two.
	var other := Pool.new(Blip, 3)
	var mine := pool.borrow(here)
	var theirs := other.borrow(here)
	check(mine != theirs and pool.is_out(mine) and not pool.is_out(theirs) and other.is_out(theirs),
		"two pools of the same thing lend their own")
	pool.give_back(mine)
	other.give_back(theirs)

	print("[POOL] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
