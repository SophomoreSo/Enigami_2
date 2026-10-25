extends Node
## Free talk on screen, in the real sandbox: the bubble opens over whoever is
## talking — the apprentice, or the player — with its tail under them, stays
## on the screen when they stand by its edge, is edged a whole PIXEL wide, and
## has its words in it in every language.
##
## Needs a window: it reads the frame back. Run at 1280x720, where a design
## pixel is a screen pixel and an edge can be measured exactly.

const GameScript := preload("res://app/game.gd")

var fails := 0
var game: Node

func check(ok: bool, what: String) -> void:
	if ok:
		print("[BUBBLE] PASS ", what)
	else:
		fails += 1
		push_error("BUBBLE FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func until(ok: Callable, most: int = 1200) -> bool:
	var n := 0
	while not ok.call() and n < most:
		await get_tree().process_frame
		n += 1
	return ok.call()

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var was := Loc.language
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(8)
	for lang in ["eng", "kor"]:
		Loc.set_language(lang)
		await _talk_in(lang)
	Loc.set_language(was)
	print("[BUBBLE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## The same walk through in one language: a fresh profile, so they greet.
func _talk_in(lang: String) -> void:
	GameState.reset_profile()
	game.goto_sandbox()
	await frames(30)
	var sb: Sandbox = game.current
	var ap: Npc = sb.apprentice
	var p: Player = sb.player
	var view := Views.of(ap) as NpcView
	check(view != null and view.bubble != null, "%s: the apprentice's view carries a bubble" % lang)
	if view == null:
		return
	var bubble: SpeechBubble = view.bubble
	var talk := ap.free_talk
	check(not bubble.is_open(), "%s: shut while nobody is talking ('%s' at %s; the player at %s)"
		% [lang, talk.line_id, str(ap.global_position), str(p.global_position)])

	# Into earshot: they call out, over their own head.
	p.global_position = ap.global_position + Vector2(200, -4)
	check(await until(func() -> bool: return talk.line_id == "hello" and talk.line_finished()),
		"%s: coming into earshot, the greeting comes out" % lang)
	await frames(4)
	await _measure(bubble, ap.global_position, view.bubble.npc_head, lang, "their greeting")

	# The player's own line goes over the player.
	p.global_position = ap.global_position + Vector2(44, -4)
	await until(func() -> bool: return not talk.is_talking())
	await frames(4)
	talk.press()
	check(await until(func() -> bool: return talk.line_id == "intro_reply" and talk.line_finished()),
		"%s: a press, and the player answers" % lang)
	await frames(4)
	await _measure(bubble, p.global_position, SpeechBubble.PLAYER_HEAD, lang, "the player's line")

	# By the wall the bubble slides along to stay on screen, tail and all.
	talk.cut()
	ap.global_position.x = 40.0
	p.global_position = Vector2(ap.global_position.x + 40.0, p.global_position.y)
	await frames(4)
	talk.answer("near")
	talk.hear("lesson")
	await until(func() -> bool: return talk.is_talking() and talk.line_finished())
	await frames(4)
	await _measure(bubble, ap.global_position, view.bubble.npc_head, lang, "a line by the wall")
	talk.cut()

## Everything asked of an open bubble over `who` — a world point, the middle of
## their body — whose head is `head` above it.
func _measure(bubble: SpeechBubble, who: Vector2, head: float, lang: String, what: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var to_screen := bubble.get_global_transform_with_canvas()
	var box := to_screen * bubble.box()
	var speaker := bubble.get_canvas_transform() * who
	var top_of_head := bubble.get_canvas_transform() * (who + Vector2(0, head))
	var screen := Rect2(Vector2.ZERO, Vector2(img.get_size()))
	var talk := bubble.npc.free_talk
	check(bubble.is_open() and box.size.x > 0.0, "%s, %s: the bubble is open (%s; saying '%s', %.2fs of %.2fs held, player at %s, in earshot %s)"
		% [lang, what, str(box), talk.line_id, talk.held, talk.hold_time(),
			str(bubble.npc.free_speaker().global_position), bubble.npc.in_earshot])
	check(screen.grow(-SpeechBubble.MARGIN + 1.0).encloses(box),
		"%s, %s: all of it is on the screen (%s)" % [lang, what, str(box)])
	check(box.end.y <= top_of_head.y, "%s, %s: it stands over their head (bottom %.0f, head %.0f)"
		% [lang, what, box.end.y, top_of_head.y])

	# The tail: edge-coloured steps under the box, over the speaker.
	var tail_x := -1
	var below := int(box.end.y) + 2
	for x in range(int(box.position.x), int(box.end.x)):
		if _is(img.get_pixel(x, below), Style.DIALOGUE_EDGE):
			tail_x = x
			break
	var tail_mid := float(tail_x) + float(SpeechBubble.PX * (SpeechBubble.TAIL - 2))
	check(tail_x >= 0 and absf(tail_mid - clampf(speaker.x, box.position.x + 14.0, box.end.x - 14.0)) <= 6.0,
		"%s, %s: its tail hangs under the box, over whoever is talking (tail %.0f, speaker %.0f)"
			% [lang, what, tail_mid, speaker.x])

	# A PIXEL of edge, on whole pixels: the top two rows are the edge, the
	# third is not, and the left two columns likewise.
	var mid := int(box.get_center().x)
	var top := int(box.position.y)
	var left := int(box.position.x)
	var y := int(box.position.y + box.size.y * 0.5)
	check(_is(img.get_pixel(mid, top), Style.DIALOGUE_EDGE) and _is(img.get_pixel(mid, top + 1), Style.DIALOGUE_EDGE)
			and not _is(img.get_pixel(mid, top + 2), Style.DIALOGUE_EDGE),
		"%s, %s: the top edge is exactly a PIXEL deep" % [lang, what])
	check(_is(img.get_pixel(left, y), Style.DIALOGUE_EDGE) and _is(img.get_pixel(left + 1, y), Style.DIALOGUE_EDGE)
			and not _is(img.get_pixel(left + 2, y), Style.DIALOGUE_EDGE),
		"%s, %s: and so is the left one" % [lang, what])

	# The words, in the text colour, inside the edge.
	var ink := 0
	for py in range(top + 4, int(box.end.y) - 4):
		for px in range(left + 4, int(box.end.x) - 4):
			if _is(img.get_pixel(px, py), Style.DIALOGUE_TEXT):
				ink += 1
	check(ink > 150, "%s, %s: its words are written in it (%d pixels of ink)" % [lang, what, ink])

func _is(c: Color, want: Color) -> bool:
	return absf(c.r - want.r) < 0.04 and absf(c.g - want.g) < 0.04 and absf(c.b - want.b) < 0.04
