extends Node2D
## Legna Dennis's sight, and what it is for: the vision key goes round the
## world as it is, the wires, and magic off for a hero with that sight, and
## turns magic off and on for one without; the screen changing puts it away.
## The wire test is what it says: a vault behind an electric gate that stops a
## body and shocks it, powered down a wire from a generator in the back room,
## and the generator beside the gate powering the back room's door instead.
## Struck, a generator crashes — no kill — and what it powered goes down with
## it, and nothing else; the vault's core reached is the attempt done; and the
## ground sets itself again.

const GameScript := preload("res://app/game.gd")

var fails := 0
var game: Node
var shocks := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[WIRE] PASS ", what)
	else:
		fails += 1
		push_error("WIRE FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	GameState.reset_profile()
	for n in range(1, GameState.SAVE_SLOTS + 1):
		GameState.delete_slot(n)
	seed(20261101)
	Cues.fired.connect(func(cue: StringName, _d: Dictionary) -> void:
		if cue == &"gate_shock":
			shocks += 1)

	_sights()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(5)
	await _the_key()
	await _the_ground()

	print("[WIRE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Who sees what, and the key going round it.
func _sights() -> void:
	check(Heroes.sight_of("legna_dennis") == "wires", "Legna Dennis sees the wires")
	var others := Array(Heroes.ids()).filter(func(id: String) -> bool: return id != "legna_dennis")
	check(not others.is_empty() and others.all(func(id: String) -> bool: return Heroes.sight_of(id) == ""),
		"and nobody else sees anything of their own (%s)" % str(others))

	Magic.set_on(true)
	Sight.set_seeing("")
	Sight.cycle("wires")
	check(Sight.seeing == "wires" and Magic.on, "her first press: the wires, in magic")
	Sight.cycle("wires")
	check(Sight.seeing == "" and not Magic.on, "her second: magic off, and the wires gone")
	Sight.cycle("wires")
	check(Sight.seeing == "" and Magic.on, "her third: the world as it is again")
	Sight.cycle("")
	check(Sight.seeing == "" and not Magic.on, "anyone else's press: magic off, and no sight")
	Sight.cycle("")
	check(Sight.seeing == "" and Magic.on, "and back on")

## The vision key in the shell, for whoever the world has the player play.
func _the_key() -> void:
	game.goto_sandbox()
	await frames(5)
	var bench: World = game.current
	check(bench.played() == GameState.hero and Heroes.sight_of(GameState.hero) == "",
		"on the bench the player is the profile's hero, who has no sight (%s)" % GameState.hero)
	game._vision_key()
	check(Sight.seeing == "" and not Magic.on, "so the key turns magic off there")
	game._vision_key()
	check(Magic.on, "and on again")

	game.goto_wire_test()
	await frames(5)
	var t: WireTest = game.current
	check(t.played() == "legna_dennis" and t.player.hero == "legna_dennis",
		"in the wire test the player is Legna Dennis, whoever the profile plays (%s)" % t.played())
	game._vision_key()
	check(Sight.seeing == "wires" and Magic.on, "and the key shows her the wires")
	game.goto_sandbox()
	await frames(5)
	check(Sight.seeing == "" and Magic.on, "leaving the screen puts the sight away")
	game.goto_wire_test()
	await frames(5)

## What is in the ground, what powers what, and getting into the vault.
func _the_ground() -> void:
	var t: WireTest = game.current
	var room := t.room
	check(room.generators.size() == 2 and room.gates.size() == 2 and room.wires.size() == 2,
		"two generators, two gates and two wires (%d, %d, %d)" % [room.generators.size(), room.gates.size(), room.wires.size()])
	if room.generators.size() != 2 or room.gates.size() != 2 or room.wires.size() != 2:
		return
	var vault: ElectricGate = room.gates[WireBase.VAULT_GATE]
	var door: ElectricGate = room.gates["2"]
	var by_vault := _nearest(room.generators, vault.world_span().get_center())
	var back_room: Generator = room.generators[0] if room.generators[1] == by_vault else room.generators[1]
	var to_vault := _wire_to(room, vault)
	var to_door := _wire_to(room, door)
	check(to_vault != null and to_vault.generator == back_room,
		"the vault gate's wire runs from the generator in the back room")
	check(to_door != null and to_door.generator == by_vault,
		"and the generator beside the vault gate powers the back room's door")
	for w: Wire in room.wires:
		var path := w.world_path()
		var gate := w.powers as ElectricGate
		check(path[0].distance_to(w.generator.global_position) < 1.0 and gate != null
				and gate.world_span().grow(1.0).has_point(path[path.size() - 1]),
			"each wire runs from its generator's feet to the edge of its gate (%s)" % str(path))
		for i in range(1, path.size()):
			var step := path[i] - path[i - 1]
			if step.x != 0.0 and step.y != 0.0:
				check(false, "a wire runs along rows and down columns only (%s)" % str(step))
	check(vault.is_up() and door.is_up() and to_vault.live() and to_door.live(), "every gate up, every wire live")
	check(Attacks.targets(0).has(by_vault) and Attacks.targets(1).has(by_vault)
			and not Attacks.quarries(0).has(by_vault), "a generator is struck by anything, and sought by nothing")

	# The vault's gate stops a body that walks into it, and shocks it back.
	var p := t.player
	var hands := ComputerHands.new()
	p.input.add(hands)
	p.global_position = room.to_global(Vector2(37.5, 11.5) * Room.CELL)
	await frames(2)
	var health := p.health
	var front := vault.world_span().position.x
	var furthest := p.global_position.x
	hands.move = Vector2.RIGHT
	for i in 90:
		await get_tree().physics_frame
		furthest = maxf(furthest, p.global_position.x)
	hands.move = Vector2.ZERO
	check(furthest < front, "the gate stops a body walking into it (%.0f, the beams at %.0f)" % [furthest, front])
	check(shocks > 0 and p.health < health, "and shocks it (%d shocks, %.0f of %.0f left)" % [shocks, p.health, health])

	# The generator by the gate, struck: it crashes, and what it powered with it.
	var kills := int(GameState.records.get("kills", 0))
	var crashed := [false]
	by_vault.crashed.connect(func(_g: Generator) -> void: crashed[0] = true)
	p.global_position = by_vault.global_position + Vector2(-30.0, 0.0)
	await frames(2)
	for i in 6:
		if not by_vault.running():
			break
		Attacks.spawn(_blow(), {"attacker": p, "room": room, "team": 0,
			"aim": Vector2.RIGHT, "origin": p.global_position})
		await frames(8)
	await frames(4)
	check(crashed[0] and not by_vault.running(), "the player's blows crash the generator by the gate")
	check(int(GameState.records.get("kills", 0)) == kills, "and crashing it is no kill")
	check(not door.is_up() and not to_door.live(), "the back room's door goes down with it, its wire dead")
	check(vault.is_up() and to_vault.live(), "and the vault's gate stays up: it was never that one's")
	check(t.crashed() == 1 and t.vault_shut(), "one of the two crashed, the vault still shut")

	# The one in the back room, crashed: the vault opens, and is walked into.
	back_room.apply_damage(Generator.HEALTH)
	await frames(4)
	check(not vault.is_up() and not to_vault.live() and not t.vault_shut(), "the back room's generator crashed: the vault's gate is down")
	var reached := [0.0]
	t.reached.connect(func(seconds: float) -> void: reached[0] = seconds)
	p.global_position = room.to_global(Vector2(37.5, 11.5) * Room.CELL)
	await frames(2)
	hands.move = Vector2.RIGHT
	for i in 60:
		await get_tree().physics_frame
	hands.move = Vector2.ZERO
	check(p.global_position.x > vault.world_span().end.x, "the doorway is open: a body walks through (%.0f)" % p.global_position.x)
	p.global_position = room.to_global(room.core().get_center())
	await frames(3)
	check(t.over and reached[0] > 0.0 and t.best > 0.0, "standing on the vault's core is the attempt done (%.1fs)" % reached[0])

	# And the ground sets itself again.
	t.reset_floor()
	await frames(4)
	check(t.crashed() == 0 and vault.is_up() and door.is_up() and to_vault.live() and to_door.live(),
		"set again: every generator running, every gate up")
	check(not t.over and t.player != p and t.player.global_position.distance_to(room.spawn_point()) < 2.0
			and t.player.hero == "legna_dennis", "and a fresh Legna Dennis where the hall is come into")
	check(Attacks.targets(0).has(by_vault), "a generator set going again is struck again")

func _blow() -> Payload:
	var b := Payload.new()
	b.damage = 12.0
	b.form = "SLASH"
	return b

func _nearest(gens: Array[Generator], at: Vector2) -> Generator:
	var best: Generator = null
	for g in gens:
		if best == null or g.global_position.distance_to(at) < best.global_position.distance_to(at):
			best = g
	return best

func _wire_to(room: WireBase, gate: ElectricGate) -> Wire:
	for w: Wire in room.wires:
		if w.powers == gate:
			return w
	return null
