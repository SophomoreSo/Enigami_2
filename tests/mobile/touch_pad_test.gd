extends Node
## The console the game draws on the glass, and the setting that puts it there.
##
## It is laid out the way a phone MOBA is — a floating stick under the left
## thumb, a stick per skill under the right — so what is checked here is what
## that scheme has to get right.
##
## **Where the controls sit.** The HUD owns the top-left corner and the whole
## bottom of the screen, and a control standing on either covers the health bar
## or the slot cards for as long as the game is played. Every one is measured
## against those bands, against every other control, and against its own word in
## both languages — on the design's 16:9 and on the shapes a phone or a tablet
## gives the screen instead, where each has to keep its distance from its own
## corner.
##
## **What a thumb does.** Against a real raid, with a real player carrying real
## slots: the stick does nothing until it has been dragged most of the way to
## its ring, where it walks them the way the thumb points, any of the eight
## ways; dragged far out of the ring it sprints them, and the line the knob
## had to get out to lights to say so; a thumb with no room to drag that far is asked for as
## far as the glass goes; a stick keeps the finger that started it however far
## it is dragged; a skill button arms its slot, charges while it is held, aims
## where it is thrown and casts on release; a slot the player is not carrying is
## not on the pad at all.
##
## **What it costs the rest of the game.** While the pad is up the mouse is in a
## drawer, because the system turns every touch into a click and `attack` is
## bound to one. The bindings still read and still save while they are in there.

const GameScript := preload("res://app/game.gd")

## The two bands the HUD keeps, out of `graphics/ui/hud.gd`: the bars and the
## weapon down the top-left corner, and the slot cards across the bottom.
const HUD_BARS := Rect2(24, 24, 264, 88)
const HUD_CARDS := Rect2(0, 592, 1280, 128)

## The shapes of screen the layout is checked on: the design, phones longer
## than 16:9 — the one it was reported on is about 20.5:9, and some go past
## 21:9 — and a 4:3 tablet. `expand` stretch keeps the height at 720 on the
## first kind and the width at 1280 on the second.
const SHAPES := [Vector2(1280, 720), Vector2(1642, 720), Vector2(1728, 720), Vector2(1280, 960)]

var fails := 0
var game: Node
var pad: TouchPad
var raid: Raid
var player: Player
var was_mode: int

func check(ok: bool, what: String) -> void:
	if ok:
		print("[TOUCH] PASS ", what)
	else:
		fails += 1
		push_error("TOUCH FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Long enough for a drag to have reached the body, whatever the machine. The
## pad reads a drag in one frame and presses in the next, and the body takes
## the press in the steps after that; a slow machine — CI's virtual display —
## fits several steps in a frame, so a count of steps alone can all go by
## before the press is in. Before saying a drag did nothing to the body.
func reach_body() -> void:
	await frames(3)
	for i in 6:
		await get_tree().physics_frame

## Steps until `done` holds, or `most` of them: for what the body does with a
## press, which comes later on a slow machine. Whether it held.
func settle(done: Callable, most: int = 90) -> bool:
	await frames(3)
	for i in most:
		if done.call():
			return true
		await get_tree().physics_frame
	return done.call()

func controls_under(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control:
			out.append(n)
		for c in n.get_children(true):
			stack.append(c)
	return out

func switch_under(root: Node) -> UiKit.Switch:
	for c in controls_under(root):
		if c is UiKit.Switch:
			return c
	return null

## A click where `at` is in the 1280x720 the game is drawn at, pressed and let
## go, sent the way the system sends one.
func click(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = on_glass(at)
	m.global_position = m.position
	Input.parse_input_event(m)
	await frames(2)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = m.position
		e.global_position = e.position
		Input.parse_input_event(e)
		await frames(2)

func button_named(root: Node, text: String) -> Button:
	for c in controls_under(root):
		if c is Button and (c as Button).text == text:
			return c
	return null

## The control that presses `id` — the action it holds, or, for a slot stick,
## the slot it arms.
func control_of(id: String) -> Dictionary:
	for c in TouchPad.CONTROLS:
		if String(c.get("action", "")) == id or String(c.get("arm", "")) == id or String(c.get("alt", "")) == id:
			return c
	return {}

## Where a control is on the screen as it is now, whatever shape the window has
## given it.
func spot(id: String) -> Vector2:
	return TouchPad.area(control_of(id), screen()).get_center()

func slopped(c: Dictionary, s: Vector2) -> Rect2:
	var r := TouchPad.area(c, s)
	return r if c.has("zone") else r.grow(TouchPad.SLOP)

func screen() -> Vector2:
	return get_viewport().get_visible_rect().size

## The HUD's band along the bottom, on a screen of `s`: it goes wherever the
## bottom does.
func hud_cards(s: Vector2) -> Rect2:
	return Rect2(0, s.y - HUD_CARDS.size.y, s.x, HUD_CARDS.size.y)

## A finger landing, moving or lifting, sent the way the system sends one so the
## pad answers through its own `_input` rather than through a back door.
##
## `at` is where it lands in the 1280x720 the game is drawn at, and is put back
## into the window's own coordinates on the way in — a finger touches glass, not
## a design, and the engine is what turns one into the other. Sending the design
## position straight in would only pass on a window that happens to be 1:1.
func touch(index: int, at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = on_glass(at)
	e.pressed = pressed
	Input.parse_input_event(e)

func drag(index: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = on_glass(at)
	Input.parse_input_event(e)

## The picture as it is on the screen now, whether or not the window is where
## anything can see it: a covered window draws nothing unless it is made to.
func drawn() -> Image:
	await get_tree().process_frame
	if DisplayServer.window_can_draw():
		await RenderingServer.frame_post_draw
	else:
		RenderingServer.force_draw(false)
	return get_viewport().get_texture().get_image()

## How something drawn on the stick stands in `img`: QUIET, REACHED (lit in the
## pad's own bright edge) or OUT (white).
enum { QUIET, REACHED, OUT }

## The brightest of what is drawn `far` from the middle of the stick, `sides`
## degrees round from `degrees` — 0 to the right, 90 straight down. Never read
## off the knob, which lights itself and goes wherever the thumb takes it.
func read(img: Image, degrees: float, sides: Array, far: Array) -> int:
	var knob: float = TouchPad.CONTROLS[0]["knob"]
	var held := pad.knob_at(float(TouchPad.CONTROLS[0]["radius"]), knob)
	var best := QUIET
	for side in sides:
		for r in far:
			var p: Vector2 = pad._stick_at + Vector2.from_angle(deg_to_rad(degrees + side)) * r
			if p.distance_to(held) < knob + PixelDraw.PX * 2:
				continue
			var at := on_glass(p)
			if not Rect2(Vector2.ZERO, Vector2(img.get_size())).has_point(at):
				continue
			var c := img.get_pixelv(Vector2i(at))
			if minf(c.r, minf(c.g, c.b)) > 0.8:
				best = OUT
			elif c.b > 0.8 and c.g > 0.75 and best == QUIET:
				best = REACHED
	return best

## How the ring's mark toward `degrees` stands: QUIET, or REACHED once the stick
## is walking that way. Read off the ring, to either side of where the knob
## gets to.
func mark(img: Image, degrees: float) -> int:
	var ring: float = TouchPad.CONTROLS[0]["radius"]
	return read(img, degrees, [-30.0, 30.0], [ring - 7.0, ring - 6.0, ring - 5.0])

## Whether the line out past the ring toward `degrees` has gone white: the one
## the knob has to get out to before it sprints. Read off the line
## itself, wherever the pad says it stands, toward its two ends — the knob
## comes up to it in the middle.
func lit(img: Image, degrees: float) -> bool:
	var line: float = float(TouchPad.CONTROLS[0]["radius"]) * pad.gate(Vector2.from_angle(deg_to_rad(degrees)))
	return read(img, degrees, [-14.0, -13.0, -12.0, 12.0, 13.0, 14.0],
		[line + 1.0, line + 2.0, line + 3.0]) == OUT

func on_glass(at: Vector2) -> Vector2:
	return get_window().get_final_transform() * at

func _ready() -> void:
	was_mode = Touch.mode
	# The buttons where the design puts them, whatever this machine's player
	# has moved them to — in force here only, and nothing kept.
	TouchPad.set_layout({}, false)
	await _layout()
	await _the_setting()
	await _into_a_raid()
	await _the_stick()
	await _the_ways()
	await _the_edge()
	await _the_skills()
	await _the_reach()
	await _the_faces()
	await _hit_is_use()
	await _the_weapon_key()
	await _another_window()
	await _the_drawer()
	Touch.set_mode(was_mode)
	print("[TOUCH] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- where the controls sit -------------------------------------------------

func _layout() -> void:
	for s: Vector2 in SHAPES:
		_placed_on(s)

	# A control too small for a thumb is one that gets missed. 44 is the
	# smallest anybody recommends, and on a phone's glass it was still smaller
	# than the thumb: the buttons are twice what they were, so twice that is the
	# floor, and the plates' height is the smallest here.
	var small: Array = []
	for c in TouchPad.CONTROLS:
		var r := TouchPad.area(c)
		if r.size.x < 88.0 or r.size.y < 88.0:
			small.append("%s %s" % [c.get("action", "move"), str(r.size)])
	check(small.is_empty(), "every control is at least 88 across (%s)" % str(small))

	var unknown: Array = []
	for c in TouchPad.CONTROLS:
		for key in ["action", "arm", "alt"]:
			var a := String(c.get(key, ""))
			if a != "" and not InputMap.has_action(a):
				unknown.append(a)
	check(unknown.is_empty(), "every control presses an action the game has (%s)" % str(unknown))
	# Movement is the stick's, and it presses all four itself — and the sprint,
	# which is the same stick dragged far out of its ring. Changing weapon is one
	# key on the glass, the next one round: a slot's own key and the one for the
	# weapon before are a desk's, where there are keys to spare.
	var missing: Array = []
	for entry in Controls.ACTIONS:
		var a := String(entry[0])
		if a.begins_with("move_") or a == "sprint":
			continue
		if a.begins_with("weapon_") and a != "weapon_next":
			continue
		if control_of(a).is_empty():
			missing.append(a)
	check(missing.is_empty(),
		"and every other action on the rebinding screen has a control (%s)" % str(missing))

	# The words, in each language. Silkscreen is proportional and Hangul is
	# drawn from a face of its own at its own size, so a word that fits in
	# English says nothing about the same word in Korean.
	var was_language := Loc.language
	for lang in Loc.languages():
		Loc.set_language(lang)
		await frames(2)
		var clipped: Array = []
		for c in TouchPad.CONTROLS:
			var label := TouchPad.label_of(c)
			if label == "":
				continue
			# At the size the console writes its words, twice the menus'.
			var room := TouchPad.area(c).size.x
			if PixelDraw.clip(label, room, TouchPad.LABEL_SIZE) != label:
				clipped.append("%s '%s' (%.0f of %.0f)" % [c.get("action", "move"), label,
					PixelDraw.text_width(label, TouchPad.LABEL_SIZE), room])
		check(clipped.is_empty(), "every word fits its control in %s (%s)" % [lang, str(clipped)])
	Loc.set_language(was_language)
	await frames(2)

## Where the controls land on a screen of `s`: every one on it, none on the HUD
## and none on another — and each its own distance from its own corner, which
## is the design's answer to a screen of another shape. A thumb reaches no
## further on a longer phone, so the hand stays as far from the bottom-right
## corner as the design puts it, the plates as far from the top-right, and the
## stick's zone keeps the left edge and runs down to the HUD's band.
func _placed_on(s: Vector2) -> void:
	var shape := "%dx%d" % [s.x, s.y]
	var screen_rect := Rect2(Vector2.ZERO, s)
	var off: Array = []
	var on_hud: Array = []
	var strayed: Array = []
	for c in TouchPad.CONTROLS:
		var r := TouchPad.area(c, s)
		var name := String(c.get("action", "move"))
		if not screen_rect.encloses(r):
			off.append(name)
		# Only what is up while the HUD is. The page in a conversation is the
		# whole screen, and lies over a HUD that has stepped aside for it.
		var beside_hud: bool = (c["faces"] as Array).has(TouchPad.Face.PLAY) \
			or (c["faces"] as Array).has(TouchPad.Face.SCREEN)
		if beside_hud and (r.intersects(HUD_BARS) or r.intersects(hud_cards(s))):
			on_hud.append(name)
		# Each axis measured from the side the control is pinned to.
		var pin := Vector2(c.get("pin", Vector2.ZERO))
		var design := TouchPad.area(c)
		var here := Vector2(s.x - r.end.x if pin.x > 0.0 else r.position.x,
			s.y - r.end.y if pin.y > 0.0 else r.position.y)
		var there := Vector2(TouchPad.DESIGN.x - design.end.x if pin.x > 0.0 else design.position.x,
			TouchPad.DESIGN.y - design.end.y if pin.y > 0.0 else design.position.y)
		if here.distance_to(there) > PixelDraw.PX * 1.5:
			strayed.append("%s %s, not %s" % [name, str(here), str(there)])
	check(off.is_empty(), "%s: every control is on the screen (off: %s)" % [shape, str(off)])
	check(on_hud.is_empty(),
		"%s: and none stands on the health bars or the slot cards (on: %s)" % [shape, str(on_hud)])
	check(strayed.is_empty(),
		"%s: and each keeps its distance from its own corner (%s)" % [shape, str(strayed)])
	var zone := TouchPad.area(TouchPad.CONTROLS[0], s)
	check(is_equal_approx(zone.end.y, hud_cards(s).position.y),
		"%s: the stick's zone runs down to the HUD's band (%.0f, the band at %.0f)"
			% [shape, zone.end.y, hud_cards(s).position.y])

	# The stick's zone is most of the lower-left of the screen, so this is the
	# check that says the right hand stays out of it.
	var overlap: Array = []
	for i in TouchPad.CONTROLS.size():
		for j in range(i + 1, TouchPad.CONTROLS.size()):
				# A zone answers only to a thumb inside it, so it gets no slop; two
			# zones may share an edge, and a press on it lands in one of them.
			var a := slopped(TouchPad.CONTROLS[i], s)
			var b := slopped(TouchPad.CONTROLS[j], s)
			# Two controls never up at once cannot be pressed at once: the page
			# in a conversation covers the hand, which is not there then.
			var together := false
			for f in TouchPad.CONTROLS[i]["faces"]:
				together = together or (TouchPad.CONTROLS[j]["faces"] as Array).has(f)
			if together and a.intersects(b):
				overlap.append("%s/%s" % [TouchPad.CONTROLS[i].get("action", "move"),
					TouchPad.CONTROLS[j].get("action", "move")])
	check(overlap.is_empty(), "%s: no two controls overlap, slop and all (%s)" % [shape, str(overlap)])

## --- the setting ------------------------------------------------------------

## It is mobile mode, a switch on the controls page, which the title's settings
## and the pause menu both hold — so putting it there puts it in both, and
## throwing it in one has to show in the other.
func _the_setting() -> void:
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(10)

	var title: TitleScreen = game.current
	title._toggle_settings()
	await frames(4)
	title._toggle_controls()
	await frames(6)
	var panel: ControlsPanel = null
	for c in controls_under(title._controls):
		if c is ControlsPanel:
			panel = c
	check(panel != null, "the controls page carries the settings panel")
	if panel == null:
		return
	var switch := switch_under(title._controls)
	check(switch != null, "it offers mobile mode as a switch")
	var named := false
	for c in controls_under(title._controls):
		if c is Label and (c as Label).text == Loc.t("controls.mobile"):
			named = true
	check(named, "under the name the row is given")
	if switch == null:
		return

	# AUTO is what a fresh install is in, and on a desk it comes to nothing. The
	# switch shows what it came to, set as the page comes on screen.
	Touch.set_mode(Touch.AUTO)
	check(Touch.wanted() == Touch.touch_device(),
		"AUTO is on exactly where the machine is one you touch (here: %s)"
			% str(Touch.touch_device()))
	title._toggle_controls()
	await frames(2)
	title._toggle_controls()
	await frames(4)
	# The page is laid out for the mode in force, so it is built again whenever
	# the mode changes — and the switch on it is a new one each time.
	switch = switch_under(title._controls)
	check(switch != null and switch.button_pressed == Touch.wanted(),
		"and the switch shows what AUTO came to (%s)" % str(Touch.wanted()))

	# Thrown by a click, the way a mouse or a thumb throws it, both ways.
	Touch.set_mode(Touch.OFF)
	await frames(3)
	switch = switch_under(title._controls)
	await click(switch.get_global_rect().get_center())
	await frames(3)
	switch = switch_under(title._controls)
	check(Touch.mode == Touch.ON and Touch.wanted() and switch != null and switch.button_pressed,
		"a click throws it on, and puts the console on (mode %d)" % Touch.mode)
	check(title._controls.visible and title._controls.thumb,
		"and the page it is on is laid out again, for a thumb, and still up")
	await click(switch.get_global_rect().get_center())
	await frames(3)
	switch = switch_under(title._controls)
	check(Touch.mode == Touch.OFF and not Touch.wanted() and switch != null and not switch.button_pressed,
		"and another throws it off again (mode %d)" % Touch.mode)
	check(title._controls.visible and not title._controls.thumb, "and the page is a desk's again")
	await click(switch.get_global_rect().get_center())
	await frames(3)
	check(Touch.mode == Touch.ON, "and on again")

	Touch.mode = Touch.OFF
	Touch.load_saved()
	check(Touch.mode == Touch.ON, "the mode is kept in a file of its own and read back")

	# The pause menu's copy was built at boot, before any of that, and has to
	# come on screen showing what is in force now rather than what was then.
	game.pause_menu.visible = true
	game._pause_controls(true)
	await frames(4)
	var paused := switch_under(game.pause_controls)
	check(paused != null and paused.button_pressed,
		"the pause menu's switch shows it on too (%s)"
			% ("none" if paused == null else str(paused.button_pressed)))
	game._pause_controls(false)
	game.pause_menu.visible = false
	title._toggle_controls()
	title._toggle_settings()
	await frames(4)

	pad = game.touch_pad
	check(pad != null, "the shell builds a pad that outlives every screen")
	check(pad != null and not pad.visible,
		"which stays off the title screen, where there is nothing to play")

## --- a raid to play with ----------------------------------------------------

## Everything below runs against a real raid: a player who really charges and
## really casts. A stick that presses the right action and changes nothing
## would pass every check written against the pad alone.
func _into_a_raid() -> void:
	game._deploy("SWORD")
	await frames(20)
	raid = game.current as Raid
	player = raid.player
	check(player != null, "a raid, with somebody in it to control")
	check(player != null and player.runner != null,
		"carrying the weapon's graph")
	await frames(4)
	check(pad.visible, "and with the console on, the pad is on the screen")

## --- the eight ways ---------------------------------------------------------

## The stick walks the way the thumb points: up, down, a diagonal, every way
## between — the four keys held as much of the way as lies along each, which
## the game reads as one way — and sprints far out whichever way that is. Up
## and down are no different from across.
func _the_ways() -> void:
	var zone := TouchPad.area(TouchPad.CONTROLS[0], screen())
	var radius: float = TouchPad.CONTROLS[0]["radius"]
	var landed := Vector2(zone.position.x + radius * 3.0, zone.position.y + radius * 3.0)
	# Out in the open, with room to walk every way.
	player.global_position = raid.room.to_global(raid.room.standing_near(raid.room.cell_center(20, 11)))
	player.velocity = Vector2.ZERO
	await frames(3)
	touch(0, landed, true)
	drag(0, landed + Vector2(0.0, radius * 0.5))
	await reach_body()
	check(pad.stick_showing() and not Input.is_action_pressed("move_down"),
		"a stick dragged half way down holds nothing")
	drag(0, landed + Vector2(0.0, radius))
	await settle(func() -> bool: return player.velocity.y > Player.RUN_SPEED * 0.9)
	check(Input.is_action_pressed("move_down") and not Input.is_action_pressed("move_left")
			and not Input.is_action_pressed("move_right"),
		"dragged down to its ring, down is held and nothing across")
	check(is_equal_approx(player.velocity.y, Player.RUN_SPEED) and absf(player.velocity.x) < 1.0,
		"and the player walks down the floor (%s)" % str(player.velocity))
	var img := await drawn()
	check(mark(img, 90.0) == REACHED and mark(img, 0.0) == QUIET,
		"with the ring's mark below lit, and not the one to the side (%d)" % mark(img, 90.0))
	check(pad.aim().is_equal_approx(Vector2.DOWN), "aiming down the stick (%s)" % str(pad.aim()))
	drag(0, landed + Vector2(0.0, -radius))
	await settle(func() -> bool: return player.velocity.y < -Player.RUN_SPEED * 0.9)
	check(Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_down"),
		"pushed up, up is held and down let go of")
	# A diagonal: both keys, as much of the way as lies along each, which the
	# game reads as the diagonal, walked no faster than any one way.
	drag(0, landed + Vector2(-radius, -radius))
	await settle(func() -> bool: return player.velocity.length() > Player.RUN_SPEED * 0.9 and player.velocity.x < 0.0)
	check(Input.is_action_pressed("move_left") and Input.is_action_pressed("move_up"),
		"pushed up and left, both are held")
	var way := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	check(way.is_equal_approx(Vector2(-1, -1).normalized()), "as the diagonal between them (%s)" % str(way))
	check(is_equal_approx(player.velocity.length(), Player.RUN_SPEED) and player.velocity.x < 0.0 and player.velocity.y < 0.0,
		"and the player walks it, no faster than any one way (%s)" % str(player.velocity))
	check(not Input.is_action_pressed("sprint"), "a diagonal inside the ring is a walk")
	# Far out on the diagonal: a sprint, that way.
	drag(0, landed + Vector2(-1, -1).normalized() * radius * (TouchPad.STICK_SPRINT + 0.1))
	await settle(func() -> bool: return is_equal_approx(player.velocity.length(), Player.SPRINT_SPEED))
	check(Input.is_action_pressed("sprint") and is_equal_approx(player.velocity.length(), Player.SPRINT_SPEED)
			and player.velocity.x < 0.0 and player.velocity.y < 0.0,
		"far out on the diagonal it sprints that way (%s)" % str(player.velocity))
	img = await drawn()
	check(lit(img, 225.0) and not lit(img, 0.0), "with the line out that way gone white, and no other")
	touch(0, landed, false)
	await settle(func() -> bool: return player.velocity.length() < 1.0)
	check(not Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_left")
			and not Input.is_action_pressed("sprint"),
		"lifting lets go of all of it")

	# Held in a conversation nothing a thumb does on the left moves anybody.
	player.talk_locked = true
	await frames(3)
	touch(0, landed, true)
	drag(0, landed + Vector2(0.0, radius))
	await reach_body()
	check(player.velocity.length() < 1.0, "in a conversation a thumb pushing on the left moves nobody")
	touch(0, landed + Vector2(0.0, radius), false)
	player.talk_locked = false
	await frames(3)

## --- the edge of the glass --------------------------------------------------

## A sprint is a long drag, and the glass is not always that long: a thumb
## that landed near the left edge has nowhere to drag left to, and one low on
## the screen has little below it. There the line is as far out as a thumb can
## still get, and never inside the ring.
func _the_edge() -> void:
	var zone := TouchPad.area(TouchPad.CONTROLS[0], screen())
	var radius: float = TouchPad.CONTROLS[0]["radius"]
	var out := TouchPad.STICK_OUT + 2.0
	player.global_position = raid.room.to_global(raid.room.standing_near(raid.room.cell_center(20, 11)))
	player.velocity = Vector2.ZERO
	await frames(3)

	# Near the left edge: room to leave the ring that way, and not for the whole
	# of the drag.
	var near := Vector2(radius * 1.6, zone.position.y + radius + 30.0)
	touch(0, near, true)
	drag(0, near + Vector2(out, 0.0))
	await frames(2)
	var left := pad.gate(Vector2.LEFT)
	check(left > 1.0 and left < TouchPad.STICK_SPRINT
			and is_equal_approx(near.x - left * radius, TouchPad.STICK_EDGE),
		"a thumb down near the left edge is asked for less of a drag that way: as far as the glass goes, short of its very edge (%.2f)" % left)
	check(is_equal_approx(pad.gate(Vector2.RIGHT), TouchPad.STICK_SPRINT)
			and is_equal_approx(pad.gate(Vector2.DOWN), TouchPad.STICK_SPRINT),
		"and for the whole of it the other way and down, where there is the room")
	drag(0, near - Vector2(radius * (left - 0.05), 0.0))
	await frames(3)
	check(not Input.is_action_pressed("sprint") and Input.get_axis("move_left", "move_right") < -0.9,
		"short of that line it walks")
	drag(0, near - Vector2(radius * (left + 0.05), 0.0))
	await frames(3)
	check(near.x - radius * (left + 0.05) > 0.0 and Input.is_action_pressed("sprint"),
		"and at it, with the thumb still on the glass, it sprints")
	var img := await drawn()
	check(lit(img, 180.0) and not lit(img, 0.0),
		"the line it reached is drawn where it was reached, and is the one lit")
	touch(0, near, false)
	await frames(2)
	check(not Input.is_action_pressed("sprint"), "lifting lets go of it")

	# Hard against the edge there is not the room to leave the ring either, and
	# the line stops at the ring all the same.
	var hard := Vector2(radius * 0.5, zone.position.y + radius + 30.0)
	touch(0, hard, true)
	drag(0, hard + Vector2(out, 0.0))
	await frames(2)
	check(is_equal_approx(pad.gate(Vector2.LEFT), 1.0),
		"hard against the edge the line is the ring itself, never inside it (%.2f)" % pad.gate(Vector2.LEFT))
	touch(0, hard, false)
	await frames(2)

	# Low in the zone, over the HUD's band: less glass below than the whole of
	# a sprint's drag.
	var low := Vector2(zone.position.x + radius * 3.0, zone.end.y - 2.0)
	touch(0, low, true)
	drag(0, low + Vector2(out, 0.0))
	await frames(2)
	var down := pad.gate(Vector2.DOWN)
	check(down > 1.0 and down < TouchPad.STICK_SPRINT,
		"a thumb down low in the zone is asked for less of a drag downward (%.2f)" % down)
	drag(0, low + Vector2(0.0, radius * (down - 0.05)))
	await reach_body()
	check(not Input.is_action_pressed("sprint") and Input.is_action_pressed("move_down"), "short of that line it walks down")
	drag(0, low + Vector2(0.0, radius * (down + 0.05)))
	await settle(func() -> bool: return Input.is_action_pressed("sprint"))
	check(low.y + radius * (down + 0.05) < screen().y and Input.is_action_pressed("sprint"),
		"and at it, with the thumb still on the glass, it sprints down")
	touch(0, low, false)
	await settle(func() -> bool: return not Input.is_action_pressed("sprint"))
	check(not Input.is_action_pressed("sprint") and not Input.is_action_pressed("move_down"), "and lets go when it lifts")

## --- the stick --------------------------------------------------------------

func _the_stick() -> void:
	var zone := TouchPad.area(TouchPad.CONTROLS[0], screen())
	var radius: float = TouchPad.CONTROLS[0]["radius"]
	# There is nothing there until a thumb lands and drags, and then it is where
	# the thumb landed.
	check(not pad.stick_showing(), "with no thumb down there is no stick on the screen")
	var landed := Vector2(zone.position.x + radius + 40.0, zone.position.y + radius + 30.0)
	touch(0, landed, true)
	await frames(2)
	check(not pad.stick_showing(), "a thumb that only touches the left of the screen grows nothing")
	# A thumb coming down is never quite still, and a tremble is not a drag.
	drag(0, landed + Vector2(TouchPad.STICK_OUT * 0.5, 0.0))
	await frames(2)
	check(not pad.stick_showing(), "nor does one that only trembles")
	check(absf(Input.get_axis("move_left", "move_right")) < 0.001, "and neither moves anybody")
	# Past the slop and still inside the dead zone: on the screen, and nobody
	# moved by it yet.
	var out := TouchPad.STICK_OUT + 2.0
	drag(0, landed + Vector2(out, 0.0))
	await frames(2)
	check(pad.stick_showing(), "a thumb that drags grows one")
	check(pad._stick_at.is_equal_approx(landed),
		"where the thumb landed, not where it was dragged to or where it was last time (%s)"
			% str(pad._stick_at))
	check(absf(Input.get_axis("move_left", "move_right")) < 0.001,
		"and it asks for nothing until it is pushed past its dead zone")

	# A long way, or nothing: short of its threshold the stick asks for nothing
	# at all, and past it — still inside the ring — for a whole walk. The ring
	# says which it is.
	drag(0, landed + Vector2(radius * 0.5, 0.0))
	await frames(2)
	var half := Input.get_axis("move_left", "move_right")
	drag(0, landed + Vector2(radius * (TouchPad.STICK_RUN - 0.05), 0.0))
	await frames(2)
	var short := Input.get_axis("move_left", "move_right")
	check(is_zero_approx(half) and is_zero_approx(short),
		"a half push asks for nothing, and nor does one just short of the threshold (%.2f, %.2f)" % [half, short])
	var img := await drawn()
	check(mark(img, 0.0) == QUIET and mark(img, 180.0) == QUIET
			and not lit(img, 0.0) and not lit(img, 180.0) and not lit(img, 90.0),
		"and nothing on the stick is lit: neither of the ring's marks, and none of the lines out past it")
	drag(0, landed + Vector2(radius * (TouchPad.STICK_RUN + 0.05), 0.0))
	await frames(2)
	var past := Input.get_axis("move_left", "move_right")
	check(is_equal_approx(past, 1.0) and not Input.is_action_pressed("sprint"),
		"dragged just past it, the stick walks — a whole walk, and no sprint (%.2f)" % past)
	img = await drawn()
	check(mark(img, 0.0) == REACHED and mark(img, 180.0) == QUIET and not lit(img, 0.0),
		"and the mark on that side of the ring lights, to say it has been reached (%d)" % mark(img, 0.0))
	drag(0, landed + Vector2(radius, 0.0))
	await settle(func() -> bool: return is_equal_approx(player.velocity.x, Player.RUN_SPEED))
	var knob: float = TouchPad.CONTROLS[0]["knob"]
	var at_ring := pad.knob_at(radius, knob) - pad._stick_at
	check(is_equal_approx(pad._stick.length(), 1.0) and not Input.is_action_pressed("sprint")
			and is_equal_approx(at_ring.length() + knob, radius),
		"at the ring it is the same walk: the knob's edge has just come to the ring, and nothing more is asked")
	var walking: float = player.velocity.x
	check(is_equal_approx(walking, Player.RUN_SPEED), "the player is really walking (%.0f)" % walking)

	# Out of the ring. The knob follows the thumb out, and that alone is still
	# a walk: it has to go far out — the whole knob outside the ring and clear
	# of it — before a side is a sprint, which is the walk's key and one more.
	drag(0, landed + Vector2(radius * (1.0 + TouchPad.STICK_SPRINT) * 0.5, 0.0))
	await frames(2)
	var past_ring := pad.knob_at(radius, knob) - pad._stick_at
	check(pad._stick.length() > 1.0 and past_ring.length() + knob > radius + 5.0,
		"dragged past the ring, the knob goes out of it with the thumb (%.0fpx out)"
			% (past_ring.length() + knob - radius))
	check(not Input.is_action_pressed("sprint") and is_equal_approx(Input.get_axis("move_left", "move_right"), 1.0),
		"and half way out to the line it is still a walk")
	drag(0, landed + Vector2(radius * (TouchPad.STICK_SPRINT - 0.05), 0.0))
	await frames(2)
	img = await drawn()
	check(not Input.is_action_pressed("sprint") and not lit(img, 0.0),
		"as it is just short of the line, which is not lit")
	drag(0, landed + Vector2(radius * (TouchPad.STICK_SPRINT + 0.05), 0.0))
	await settle(func() -> bool: return is_equal_approx(player.velocity.x, Player.SPRINT_SPEED))
	check(Input.is_action_pressed("sprint") and is_equal_approx(Input.get_axis("move_left", "move_right"), 1.0),
		"dragged out to it, it sprints: the walk's key held, and sprint with it")
	var clear := (pad.knob_at(radius, knob) - pad._stick_at).length() - knob - radius
	check(clear > 10.0, "with the whole knob out of the ring, and clear of it (%.0fpx)" % clear)
	check(player.velocity.x > walking * 1.2 and is_equal_approx(player.velocity.x, Player.SPRINT_SPEED),
		"and the player goes faster than a walk (%.0f, from %.0f)" % [player.velocity.x, walking])
	img = await drawn()
	check(lit(img, 0.0) and not lit(img, 180.0) and not lit(img, 90.0) and mark(img, 0.0) == REACHED,
		"with the line on that side gone white, and the ring's mark still lit for the walk (%d)" % mark(img, 0.0))
	# A thumb resting on the line does not flicker in and out of it.
	drag(0, landed + Vector2(radius * (TouchPad.STICK_SPRINT - 0.03), 0.0))
	await frames(2)
	check(Input.is_action_pressed("sprint"), "eased back a hair inside the line, it is still a sprint")
	drag(0, landed + Vector2(radius * (TouchPad.STICK_SPRINT - 0.12), 0.0))
	await frames(2)
	check(not Input.is_action_pressed("sprint") and is_equal_approx(Input.get_axis("move_left", "move_right"), 1.0),
		"and brought properly back inside, it is a walk again")
	drag(0, landed + Vector2(radius * 4.0, 0.0))
	await frames(2)
	var full := Input.get_axis("move_left", "move_right")
	check(is_equal_approx(pad._stick.length(), TouchPad.STICK_FAR) and Input.is_action_pressed("sprint"),
		"however far the thumb goes the stick follows only so far, and sprints (%.2f)" % pad._stick.length())
	check(is_equal_approx(full, 1.0), "which is no more of a walk than a walk (%.2f)" % full)

	# A stick keeps the finger that started it: dragged across the screen and
	# over the weapon's button, it is still the stick and HIT is not pressed.
	drag(0, spot("attack"))
	await frames(2)
	check(not Input.is_action_pressed("attack"),
		"a stick dragged over a button does not press it")
	check(Input.get_axis("move_left", "move_right") > 0.0,
		"it is still the stick being held")

	drag(0, landed - Vector2(radius, 0.0))
	await frames(2)
	check(Input.get_axis("move_left", "move_right") < -0.9,
		"pushed the other way it goes the other way (%.2f)"
			% Input.get_axis("move_left", "move_right"))

	touch(0, landed, false)
	await frames(2)
	check(absf(Input.get_axis("move_left", "move_right")) < 0.001,
		"lifting lets go of the lot")
	check(not pad.stick_showing(), "and takes the stick off the screen with it")

	# And the next thumb down is where the next stick is, wherever that is.
	var again := Vector2(zone.end.x - radius - 30.0, zone.end.y - radius - 20.0)
	touch(0, again, true)
	drag(0, again + Vector2(0.0, -out))
	await frames(2)
	check(pad.stick_showing() and pad._stick_at.is_equal_approx(again),
		"the next one grows under the next thumb, somewhere else entirely (%s)"
			% str(pad._stick_at))
	touch(0, again, false)
	await frames(2)
	check(not pad.stick_showing(), "and goes again")

	# A thumb in the very corner of the zone: the ring has to slide in to stay
	# on the screen, and the push has to go on being measured from the thumb.
	# Measured from the ring instead, a stick summoned in the corner would read
	# as shoved the moment it appeared and walk the player off on its own.
	var corner := Vector2(zone.position.x + 2.0, zone.end.y - 2.0)
	touch(0, corner, true)
	# Dragged just far enough to bring it out. The ring it grows is a radius in
	# from the corner, so measured from the ring this would read as a shove the
	# moment it appeared; measured from the thumb it is a nudge.
	drag(0, corner + Vector2(out, 0.0))
	await frames(3)
	check(pad.stick_showing(), "a thumb in the corner of the zone still grows a stick")
	check(absf(Input.get_axis("move_left", "move_right")) < 0.001
			and not Input.is_action_pressed("move_down")
			and not Input.is_action_pressed("move_up"),
		"and it asks for nothing until it is pushed (ring %s, thumb %s)"
			% [str(pad._stick_at), str(corner)])
	var ring := Rect2(pad._stick_at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	check(not ring.intersects(HUD_BARS) and not ring.intersects(hud_cards(screen()))
			and Rect2(Vector2.ZERO, screen()).encloses(ring),
		"the ring it drew is on the screen and clear of the HUD (%s)" % str(ring))
	drag(0, corner + Vector2(radius, 0.0))
	await frames(3)
	check(Input.get_axis("move_left", "move_right") > 0.9,
		"and pushing it from there still runs (%.2f)"
			% Input.get_axis("move_left", "move_right"))
	touch(0, corner, false)
	await frames(2)

## --- the cast -----------------------------------------------------------------

func _the_skills() -> void:
	# One cast stick, whatever the weapon: there are no slots to carry or not.
	check(pad.shown(control_of("cast_skill")), "the cast stick is on the pad")
	var where := spot("cast_skill")
	# A cast is let go of at once, and what the board does then plays out in
	# real time. This board's attack comes a good five frames later — by which
	# time a console that did not hold the aim would be aiming with the other
	# thumb.
	var later := one_later()
	var dry := SkillRunner.new(later).simulate()
	check(String(dry["error"]) == "" and (dry["outputs"] as Array).size() == 1,
		"the board runs clean, to one attack (%s)" % dry["error"])
	player.setup(player.weapon_id, later)
	await frames(2)

	# Press: the charge starts.
	touch(0, where, true)
	await frames(4)
	check(Input.is_action_pressed("cast_skill"), "pressing it holds the cast down")
	var charged_for := 0.0
	for i in 20:
		await get_tree().process_frame
		charged_for = maxf(charged_for, player.charge)
	check(charged_for > 0.0, "holding it charges the skill (%.1f)" % charged_for)

	# Throw: where the thumb goes is where the cast goes.
	drag(0, where + Vector2(0.0, -TouchPad.AIM_REACH))
	await frames(3)
	check(pad.aim().is_equal_approx(Vector2.UP),
		"throwing the thumb up aims up (%s)" % str(pad.aim()))
	check(player.aim.y < -0.9, "and the player is really aiming there (%s)" % str(player.aim))
	# The throw beats the stick: you can run one way and cast the other.
	var zone := TouchPad.area(TouchPad.CONTROLS[0], screen())
	var radius: float = TouchPad.CONTROLS[0]["radius"]
	var landed := zone.position + Vector2.ONE * (radius + 20.0)
	touch(1, landed, true)
	drag(1, landed + Vector2(radius * 2.0, 0.0))
	await frames(3)
	check(Input.get_axis("move_left", "move_right") > 0.9 and player.aim.y < -0.9,
		"running one way while aiming another (%s)" % str(player.aim))
	touch(1, landed, false)
	await frames(2)

	# Release: it casts, and what the hold paid for goes with it. The meter is
	# read a few frames before the thumb lifts and the hold goes on paying in
	# between, so what the cast carries is at least that and no more than the
	# ceiling.
	#
	# The thumb that aimed it is gone the moment it casts, and the board fires
	# ticks later — so the left thumb runs right as the right one lets go, and
	# the attack the cast fires is watched for where it went.
	var went: Array = []
	var watch := func() -> void: went.append(player.aim)
	player.cast_fired.connect(watch)
	touch(1, landed, true)
	drag(1, landed + Vector2(radius * 2.0, 0.0))
	await frames(1)
	var paid := player.charge
	touch(0, where + Vector2(0.0, -TouchPad.AIM_REACH), false)
	await frames(3)
	check(not Input.is_action_pressed("cast_skill"), "letting go lets go of the cast")
	check(paid > 0.0 and player.cast_charge >= paid
			and player.cast_charge <= player.charge_cap() + 0.001,
		"the cast carries what the hold paid for (%.1f, at least the %.1f on the meter)"
			% [player.cast_charge, paid])
	var waited := 0
	while player.casting() and waited < 600:
		await get_tree().process_frame
		waited += 1
	await frames(3)
	player.cast_fired.disconnect(watch)
	check(went.size() == 1 and went.all(func(a: Vector2) -> bool: return a.y < -0.9),
		"the attack the cast fires goes up, where it was thrown, though it came after the left thumb started running right (%s)"
			% str(went))
	check(pad.aim().is_equal_approx(Vector2.RIGHT),
		"and once it has gone off the aim is the left stick's again (%s)" % str(pad.aim()))
	touch(1, landed + Vector2(radius * 2.0, 0.0), false)
	await frames(2)

	# A tap with no throw in it still goes somewhere: forwards.
	player.face(Vector2.LEFT)
	await frames(2)
	check(pad.aim().is_equal_approx(Vector2.LEFT),
		"with nothing held the pad aims the way the player faces (%s)" % str(pad.aim()))

	# The weapon is the same stick without the charge.
	touch(0, spot("attack"), true)
	await frames(3)
	check(Input.is_action_pressed("attack"), "the weapon button swings the weapon")
	drag(0, spot("attack") + Vector2(TouchPad.AIM_REACH, 0.0))
	await frames(3)
	check(pad.aim().is_equal_approx(Vector2.RIGHT),
		"and throwing it aims the swing (%s)" % str(pad.aim()))
	touch(0, spot("attack"), false)
	await frames(2)
	check(not Input.is_action_pressed("attack"), "lifting stops swinging")

## --- how far ------------------------------------------------------------------

## How far a cast goes is how far its thumb drags, measured from where it came
## down — and a thumb that comes down anywhere on the button without dragging is
## a tap, which goes the way the left stick does, all the way.
func _the_reach() -> void:
	var where := spot("cast_skill")
	touch(0, where, true)
	await frames(3)
	var half := TouchPad.AIM_DEAD + (TouchPad.AIM_REACH - TouchPad.AIM_DEAD) * 0.5
	drag(0, where + Vector2(half, 0.0))
	await frames(3)
	check(absf(pad.throw_reach() - 0.5) < 0.02,
		"a thumb dragged half way to the ring asks for half the distance (%.2f)" % pad.throw_reach())
	check(absf(player.aim_reach - 0.5) < 0.02 and player.aim.x > 0.9,
		"and the player aims that way, half as far (%.2f %s)" % [player.aim_reach, str(player.aim)])
	drag(0, where + Vector2(TouchPad.AIM_REACH * 1.5, 0.0))
	await frames(3)
	check(player.aim_reach > 0.99,
		"past the ring is all of it (%.2f)" % player.aim_reach)
	drag(0, where + Vector2(TouchPad.AIM_DEAD + 2.0, 0.0))
	await frames(3)
	check(player.aim_reach < 0.05 and player.aim.x > 0.9,
		"just past the dead zone, next to nothing — but still that way (%.2f)" % player.aim_reach)
	touch(0, where + Vector2(TouchPad.AIM_DEAD + 2.0, 0.0), false)
	await _cast_done()

	# A tap off the button's middle, with the left thumb pushing right. The
	# thumb trembles as thumbs do; it does not drag.
	var zone := TouchPad.area(TouchPad.CONTROLS[0], screen())
	var radius: float = TouchPad.CONTROLS[0]["radius"]
	var landed := zone.position + Vector2.ONE * (radius + 20.0)
	touch(1, landed, true)
	drag(1, landed + Vector2(radius * 2.0, 0.0))
	await frames(2)
	var off := where + Vector2(-40.0, 24.0)
	touch(0, off, true)
	await frames(2)
	drag(0, off + Vector2(3.0, -2.0))
	await frames(3)
	check(pad.aim().is_equal_approx(Vector2.RIGHT) and player.aim.x > 0.9,
		"a thumb that lands off the button's middle and does not drag goes the way the left stick pushes (%s)"
			% str(pad.aim()))
	check(player.aim_reach > 0.99, "and all the way (%.2f)" % player.aim_reach)
	touch(0, off + Vector2(3.0, -2.0), false)
	await _cast_done()
	touch(1, landed + Vector2(radius * 2.0, 0.0), false)
	await frames(2)

## A BRIDGE on the root in the bottom corner, and the flow walks the rest of the
## board — round the bottom, up the left side and along the top — down into a
## SLASH against the way out, and leaves eighteen ticks after the cast.
func one_later() -> SkillBoard:
	var b := SkillBoard.new(7, 5, "one later")
	b.set_root("BRIDGE", Vector2i(5, 4), 2)
	b.place("SLASH", Vector2i(6, 2), 0)
	var walk: Array = []
	for x in range(4, 0, -1):
		walk.append([Vector2i(x, 4), 2])
	for y in range(4, 0, -1):
		walk.append([Vector2i(0, y), 3])
	for x in 6:
		walk.append([Vector2i(x, 0), 0])
	walk.append([Vector2i(6, 0), 1])
	walk.append([Vector2i(6, 1), 1])
	for step in walk:
		b.place("BRIDGE", step[0], step[1])
	return b

func _cast_done() -> void:
	var waited := 0
	while player.casting() and waited < 600:
		await get_tree().process_frame
		waited += 1
	await frames(3)

## --- what is on the pad, and when -------------------------------------------

func _the_faces() -> void:
	player.talk_locked = true
	await frames(3)
	check(pad.face == TouchPad.Face.TALK, "somebody talking leaves the pad its TALK face")
	var shown: Array = []
	for c in TouchPad.CONTROLS:
		if pad.shown(c):
			shown.append(String(c.get("action", "move")))
	shown.sort()
	check(shown == ["interact"],
		"which is the page and nothing else (%s)" % str(shown))
	# Asked for by face rather than by action: HIT's USE is interact as well.
	var talking := TouchPad.CONTROLS.filter(func(c: Dictionary) -> bool: return pad.shown(c))
	var page := TouchPad.area(talking[0], screen())
	check(page.is_equal_approx(Rect2(Vector2.ZERO, screen())),
		"and the page is the whole of the screen (%s)" % str(page))
	var drawn: Array = []
	for c in TouchPad.CONTROLS:
		if pad.shown(c) and (not c.has("zone") or TouchPad.label_of(c) != "" or TouchPad.movable(c)):
			drawn.append(String(c.get("action", "move")))
	check(drawn.is_empty(), "none of them with a picture, and none of them movable (%s)" % str(drawn))

	# The right: a tap is interact — the line out, or the next one — and
	# nothing else, pressed as the thumb comes down and let go as it lifts.
	touch(0, spot("attack"), true)
	await frames(2)
	check(Input.is_action_pressed("interact") and not Input.is_action_pressed("attack"),
		"a thumb where HIT is turns the page, and is not HIT")
	touch(0, spot("attack"), false)
	await frames(2)
	check(not Input.is_action_pressed("interact"), "and lifted, it has let go")
	touch(0, Vector2(700, 300), true)
	await frames(2)
	check(Input.is_action_pressed("interact") and not Input.is_action_pressed("attack"),
		"so does one on the empty right of the screen")
	drag(0, Vector2(300, 300))
	await frames(2)
	check(Input.is_action_pressed("interact") and not Input.is_action_pressed("move_up")
			and not Input.is_action_pressed("move_down"),
		"still holding it when it wanders to the left, which is the same page")
	touch(0, Vector2(300, 300), false)
	await frames(2)
	check(not Input.is_action_pressed("interact"), "and lifted, it lets go")

	# The left is the page too: where the stick grows while there is somebody to
	# play, a thumb reads. Picking an answer is not the console's — the box puts
	# each on a plate of its own (`tests/mobile/talk_touch_test`).
	touch(0, Vector2(200, 400), true)
	await frames(3)
	check(Input.is_action_pressed("interact") and not pad.stick_showing()
			and not Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_down"),
		"a thumb on the left turns the page like any other, and grows no stick")
	touch(0, Vector2(200, 400), false)
	await frames(2)
	check(not Input.is_action_pressed("interact"), "until it lifts")

	# The faces coming and going under a thumb that stays down: what it was
	# doing was the face's, and it does nothing on the next until it lifts.
	touch(0, Vector2(700, 300), true)
	await frames(2)
	player.talk_locked = false
	await frames(3)
	check(pad.face == TouchPad.Face.PLAY and not Input.is_action_pressed("interact"),
		"a thumb still down on the page as the conversation ends is let go of")
	drag(0, spot("attack"))
	await frames(2)
	check(not Input.is_action_pressed("attack"), "and its thumb, dragged over HIT, presses nothing")
	touch(0, spot("attack"), false)
	await frames(2)
	touch(0, spot("attack"), true)
	await frames(2)
	check(Input.is_action_pressed("attack"), "until it has lifted and come down again")
	touch(0, spot("attack"), false)
	await frames(2)

	player.input_locked = true
	await frames(3)
	check(pad.face == TouchPad.Face.SCREEN, "a window that has taken the controls leaves SCREEN")
	shown = []
	for c in TouchPad.CONTROLS:
		if pad.shown(c):
			shown.append(String(c.get("action", "move")))
	shown.sort()
	check(shown == ["open_editor", "open_map", "pause"],
		"which is only the keys that close it again (%s)" % str(shown))
	player.input_locked = false
	await frames(3)

	# PAUSE is answered in `_unhandled_input`, so the press has to travel the
	# tree and not merely set a flag somebody polls.
	touch(0, spot("pause"), true)
	await frames(4)
	check(game.pause_menu.visible and get_tree().paused,
		"and MENU really opens the pause menu")
	touch(0, spot("pause"), false)
	game._unpause()
	await frames(4)

## --- HIT is USE by something to use --------------------------------------------

## The weapon's button is the interact key while the player stands where
## interacting would do something — here, in a raid's exit — and the weapon's
## again a step away. A thumb already down keeps what it pressed.
func _hit_is_use() -> void:
	var room: Room = raid.room
	check(room != null and not room.extraction.is_empty(), "the room has an exit to stand in")
	if room == null or room.extraction.is_empty():
		return
	var exit_at := room.to_global(room.extraction_rect().get_center())
	var away := exit_at + Vector2(-300.0, 0.0)
	player.global_position = away
	player.velocity = Vector2.ZERO
	await frames(4)
	check(not pad.use_near and TouchPad.label_of(control_of("attack"), pad.uses(control_of("attack"))) == Controls.word_for("attack"),
		"away from anything to use the button is HIT")
	touch(0, spot("attack"), true)
	await frames(3)
	check(Input.is_action_pressed("attack") and not Input.is_action_pressed("interact"), "and swings")
	# Walked into the exit with the thumb still down: still swinging.
	player.global_position = exit_at
	await frames(4)
	check(pad.use_near, "standing in the exit, USE would do something")
	check(Input.is_action_pressed("attack") and not Input.is_action_pressed("interact"),
		"but a thumb already down keeps swinging")
	touch(0, spot("attack"), false)
	await frames(3)
	check(TouchPad.label_of(control_of("attack"), pad.uses(control_of("attack"))) == Controls.word_for("interact"),
		"lifted, the button reads USE")
	var held_before := room.extract_hold
	touch(0, spot("attack"), true)
	await frames(6)
	check(Input.is_action_pressed("interact") and not Input.is_action_pressed("attack"),
		"and a thumb on it holds USE, not the weapon")
	check(room.extract_hold > held_before, "which is really extracting (%.2f)" % room.extract_hold)
	# Walked out of the exit with the thumb still down: still holding USE.
	player.global_position = away
	await frames(4)
	check(Input.is_action_pressed("interact") and not Input.is_action_pressed("attack"),
		"walking out with the thumb down keeps holding USE")
	touch(0, spot("attack"), false)
	await frames(3)
	check(not Input.is_action_pressed("interact") and not pad.use_near, "until it lifts, and then it is HIT again")

## --- the weapon key ---------------------------------------------------------

## One key on the glass changes weapon: the next one round. It is there only
## while there is a next one — with nothing to change between it would be a
## key that did nothing — and it stands with the screens, clear of the hand.
## Every slot of the four (`Player.SLOTS`) is one round, empty or not, so one
## weapon carried is already four to change between.
func _the_weapon_key() -> void:
	var key := control_of("weapon_next")
	check(not key.is_empty() and int(key["kind"]) == TouchPad.Kind.KEY and key.has("rect"),
		"the console has a key for the next weapon, a plate like the screens'")
	if key.is_empty():
		return
	player.global_position = raid.room.to_global(raid.room.spawn_point())
	await frames(4)
	check(pad.face == TouchPad.Face.PLAY and player.weapons.size() == 1 and pad.kit == Player.SLOTS and pad.shown(key),
		"with one weapon carried it is on the glass: the empty slots are the next ones round (%d)" % pad.kit)
	var own: SkillBoard = player.runner.board
	var one := player.weapon_id
	for empty: bool in [true, true, true, false]:
		touch(0, spot("weapon_next"), true)
		await frames(2)
		touch(0, spot("weapon_next"), false)
		await frames(3)
		check(player.empty_handed() == empty and (empty or player.weapon_id == one),
			"a tap on it goes round the weapon and the empty slots (%s)" % ("empty" if player.empty_handed() else player.weapon_id))

	# A kit of three, as a raid walked into with one would have it.
	var kit := ["SWORD", "GUN", "ROCK"]
	player.setup_kit(kit, [own, Weapons.make_board("GUN"), Weapons.make_board("ROCK")], 0)
	await frames(3)
	check(pad.kit == Player.SLOTS and pad.shown(key), "with a kit, it is, the empty hand after the three")
	check(Controls.word_for("weapon_next") != "" and TouchPad.label_of(key) == Controls.word_for("weapon_next"),
		"and says what it does (%s)" % TouchPad.label_of(key))
	for want: String in ["GUN", "ROCK", "", "SWORD"]:
		touch(0, spot("weapon_next"), true)
		await frames(2)
		touch(0, spot("weapon_next"), false)
		await frames(3)
		check(player.weapon_id == want, "a tap on it puts the next weapon in hand (%s)" % player.weapon_id)
	# Not on the map's face, or a conversation's: only where the weapon is used.
	# The map is a page of the board's screen, which leaves the glass clear.
	raid.set_reading_map(true)
	await frames(3)
	check(pad.face == TouchPad.Face.CLEAR and not pad.shown(key), "it is not on the glass under the map")
	raid.set_reading_map(false)
	await frames(3)
	# The one weapon back, for everything after this.
	player.setup("SWORD", own)
	await frames(3)

	# The key out of a monster: on the glass only while the player is in one,
	# beside the weapon key, and a tap on it steps out.
	var out := control_of("step_out")
	check(not out.is_empty() and out.has("rect") and not pad.shown(out),
		"the key out of a monster is not on the glass while the player is in none")
	var prey := Enemy.new()
	prey.setup("CRAWLER", 1, "")
	prey.room = raid.room
	prey.collision_layer = 4
	prey.collision_mask = 1
	raid.room.add_child(prey)
	prey.global_position = player.global_position + Vector2(160, 0)
	prey.max_health = 99999.0
	prey.health = 99999.0
	await frames(2)
	player.possess(prey, 30.0)
	await frames(3)
	check(pad.possessing and pad.shown(out), "inside a monster, it is (%s)" % TouchPad.label_of(out))
	touch(0, spot("step_out"), true)
	await frames(2)
	touch(0, spot("step_out"), false)
	await frames(3)
	check(player.possessing == null and not pad.shown(out), "and a tap on it steps out")
	prey.queue_free()
	await frames(2)

## --- the window is not the screen -------------------------------------------

func _another_window() -> void:
	# A finger touches the window, and has to arrive on the screen the game is
	# drawn on or every control is in the wrong place on every window but a 1:1
	# one: the window scaled, and on a window of another shape than 16:9 a
	# screen of another shape too, with the hand moved into its corner. Checked
	# on a window that is only scaled, on one squarer than the design, and on one
	# the shape of a long phone — the last two are where a control is somewhere
	# the design does not write it.
	var was_size := DisplayServer.window_get_size()
	for size in [Vector2i(1600, 900), Vector2i(1000, 700), Vector2i(1480, 640)]:
		DisplayServer.window_set_size(size)
		await frames(4)
		touch(0, spot("dash"), true)
		await frames(3)
		check(Input.is_action_pressed("dash"),
			"a control is under the same thumb on a %dx%d window (at %s on a %s screen)"
				% [size.x, size.y, str(spot("dash")), str(screen())])
		touch(0, spot("dash"), false)
		await frames(2)
	DisplayServer.window_set_size(was_size)
	await frames(4)

	# Nothing left held when the console is switched off under a thumb that is
	# still on it: a key lifted by the game rather than by its owner must not
	# leave the player running into the next screen.
	touch(0, spot("attack"), true)
	await frames(2)
	check(Input.is_action_pressed("attack"), "a key held as the console is switched off")
	Touch.set_mode(Touch.OFF)
	await frames(3)
	check(not pad.visible, "turning it off takes the pad off the screen mid-raid")
	check(not Input.is_action_pressed("attack") and not Touch.holding("attack"),
		"and lets go of everything it was holding")
	check(Touch.aiming() == Vector2.ZERO, "and stops aiming")

## --- the mouse in its drawer ------------------------------------------------

func _the_drawer() -> void:
	check(not Controls.mouse_aside(), "with the pad off the screen the mouse is a mouse")
	var before := Controls.label_for("attack")
	var keyboard := Controls.short_label_for("attack")
	Touch.set_mode(Touch.ON)
	await frames(3)
	check(Controls.mouse_aside(), "the pad coming up puts the mouse away")
	var bound := false
	for e in InputMap.action_get_events("attack"):
		if e is InputEventMouseButton:
			bound = true
	check(not bound, "a click no longer attacks, so a thumb on the glass does not swing")
	check(Controls.label_for("attack") == before,
		"but the rebinding screen still shows the binding ('%s')" % Controls.label_for("attack"))
	var kept := false
	for e in Controls.events_for("attack"):
		if e is InputEventMouseButton:
			kept = true
	check(kept, "and what gets saved still carries it")

	# Everything that tells the player which control does what — the slot cards,
	# the extract prompt, the hint over an NPC — asks the same question, so the
	# console answering it is the whole of the fix.
	check(Controls.short_label_for("attack") == Controls.word_for("attack")
			and Controls.word_for("attack") != "",
		"a HUD asking what attacks is told the key on the glass ('%s')"
			% Controls.short_label_for("attack"))
	check(Controls.short_label_for("cast_skill") == Controls.word_for("cast_skill")
			and Controls.word_for("cast_skill") != "",
		"and what casts, the same way ('%s')" % Controls.short_label_for("cast_skill"))

	Touch.set_mode(Touch.OFF)
	await frames(3)
	check(not Controls.mouse_aside(), "the pad going hands the mouse straight back")
	bound = false
	for e in InputMap.action_get_events("attack"):
		if e is InputEventMouseButton:
			bound = true
	check(bound, "and a click attacks again")
	check(Controls.label_for("attack") == before,
		"with nothing about the binding changed ('%s')" % Controls.label_for("attack"))
	check(Controls.short_label_for("attack") == keyboard,
		"and a HUD is told the key again ('%s')" % Controls.short_label_for("attack"))
