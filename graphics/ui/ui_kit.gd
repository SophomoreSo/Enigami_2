class_name UiKit
extends RefCounted

## Small helpers so every screen shares one look without a theme resource file.

const BG := Color(0.055, 0.06, 0.08)
const PANEL := Color(0.09, 0.10, 0.13)
const LINE := Color(0.28, 0.38, 0.48)
const TEXT := Color(0.86, 0.9, 0.96)
const DIM := Color(0.55, 0.62, 0.70)
const ACCENT := Color(0.45, 0.85, 1.0)
const GOOD := Color(0.45, 0.95, 0.7)
const WARN := Color(0.98, 0.72, 0.38)
const BAD := Color(0.95, 0.45, 0.45)

## What a window lays over the game behind it: still there, too dark to read as
## anything but the place the window closes back onto. The pause menu and the
## hideout's station panels lie on it. The assembly screen keeps a lighter veil
## of its own, since a raid behind it goes on and has to stay readable.
const SHADE := Color(0, 0, 0, 0.72)

## A full-screen sheet of SHADE, to go under a window. It takes the clicks that
## miss the window, so nothing behind is pressed through it.
static func shade() -> ColorRect:
	var r := ColorRect.new()
	r.color = SHADE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r

## A pixel look for the same kit, opted into per call with `pixel`. Text is
## Silkscreen at a multiple of its native 8px, borders are square and a whole
## number of PIXELs wide, and nothing is antialiased, so a screen built this way
## reads as the same pixel art as the title and the world. Everything uses it
## now: the menus — the title's settings and the pause menu, which are the same
## rows twice — the hideout's panels, and the screens that draw themselves
## rather than being built out of Controls, which is the assembly screen, the
## bench readout and the raid HUD (see `PixelDraw`).
const PIXEL_FONT := preload("res://graphics/assets/fonts/Silkscreen-Regular.ttf")
const PIXEL := 2
const PIXEL_TEXT := 16

## How many screen pixels one pixel of the language being played covers at
## PIXEL_TEXT: PIXEL for Latin in Silkscreen, 1 for Hangul in 둥근모꼴, whose
## 16px body is already the size Latin capitals are drawn at.
##
## A screen can only be held to whole blocks this big — which is why the pixel
## tests ask before checking, and check nothing finer than the text on them.
## Borrowed glyphs are on no grid at all, so they answer 0. Here rather than on
## `Loc`, which knows a language's face and nothing of the kit it is set in.
static func pixel_grid() -> int:
	if Loc.borrows_glyphs():
		return 0
	@warning_ignore("integer_division")
	return maxi(1, PIXEL_TEXT / Loc.face_size())

## --- mobile mode --------------------------------------------------------------
## Every menu has two layouts, and mobile mode (`Touch.wanted`) is what picks.
##
## A desk's is dense — a row is a line of text and a button the size of its
## word — because a pointer lands on a pixel. On a phone the 720 the game is
## laid out in is about 65mm of glass, so that same row is under 3mm of it and
## its words stand under a millimetre: a thing a thumb covers twice over, read
## at arm's length. So in mobile mode the kit builds the same rows at a thumb's
## size. Nothing to press stands under THUMB, a menu's words are written at
## THUMB_TEXT, a border is twice as thick, and a page runs most of the width of
## the screen. It is what the console already does with its own buttons
## (`TouchPad`), carried to the menus.
##
## What is on a page may differ too, and that is each screen's to say: the
## rebinding list has nothing to bind on a phone, a conversation's answers are
## plates to press, the assembly board's parts come a category at a time.
##
## A screen built of Controls is built again when the mode is thrown, the way it
## is when the language changes; one that draws itself asks every frame.
static func mobile() -> bool:
	return Touch.wanted()

## The least a thing to press stands, in mobile mode: a little over 7mm on a
## phone, which is what the phones' own guidelines ask of a button.
const THUMB := 80.0
## What a menu's words are written at in mobile mode: twice PIXEL_TEXT, which is
## the next size up either face draws cleanly at.
const THUMB_TEXT := PIXEL_TEXT * 2
## How wide a page runs in mobile mode, and how far it keeps from the screen's
## edges where the screen is narrower than that.
const THUMB_PAGE := 1040.0
const THUMB_EDGE := 16.0
## How far a thumb may move and still be pressing rather than dragging: about a
## phone's own touch slop, and what the console's stick waits for before it
## comes out (`TouchPad.STICK_OUT`).
const TOUCH_SLOP := 12.0

## The least height of a thing to press: THUMB in mobile mode, and nothing of
## the kit's at a desk, where a row is as tall as its word.
static func thumb() -> float:
	return THUMB if mobile() else 0.0

## The size a menu's words are written at: `size` at a desk, THUMB_TEXT in
## mobile mode.
static func text(size: int = PIXEL_TEXT) -> int:
	return THUMB_TEXT if mobile() else size

## The size of the way back in a page's top corner — the arrow beside its
## heading: a word's worth at a desk, a square a thumb can find in mobile mode.
static func corner_button() -> Vector2:
	return Vector2(THUMB + 16.0, THUMB) if mobile() else Vector2(44, 34)

static func style(bg: Color, border: Color, width: int = 1, radius: int = 3,
		pixel: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	var thick := pixel and mobile()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width * PIXEL * (2 if thick else 1) if pixel else width)
	s.set_corner_radius_all(0 if pixel else radius)
	s.anti_aliasing = not pixel
	s.content_margin_left = 20 if thick else 10
	s.content_margin_right = 20 if thick else 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

static func button(words: String, accent: Color = ACCENT, pixel: bool = false) -> Button:
	var b := Button.new()
	b.text = words
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", style(PANEL, Color(accent.r, accent.g, accent.b, 0.5), 1, 3, pixel))
	b.add_theme_stylebox_override("hover", style(Color(accent.r, accent.g, accent.b, 0.22), accent, 1, 3, pixel))
	b.add_theme_stylebox_override("pressed", style(Color(accent.r, accent.g, accent.b, 0.35), accent, 1, 3, pixel))
	b.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), accent, 1, 3, pixel))
	b.add_theme_stylebox_override("disabled", style(Color(0.1, 0.1, 0.12), Color(0.25, 0.27, 0.3), 1, 3, pixel))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.42, 0.46))
	if pixel:
		b.add_theme_font_override("font", PIXEL_FONT)
	b.add_theme_font_size_override("font_size", Loc.text_size(words, PIXEL_TEXT) if pixel else 13)
	if pixel and mobile():
		_thumb_sized(b, words)
	return b

## A pixel button at a thumb's size: THUMB tall, its word at THUMB_TEXT. And it
## passes a press on to whatever holds it, which is what lets a list of these be
## dragged up and down by a thumb that lands on one — a button that kept the
## press would be a list that only scrolls from its gaps.
static func _thumb_sized(b: BaseButton, words: String = "") -> void:
	b.custom_minimum_size = Vector2(0, THUMB)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	if words != "":
		b.add_theme_font_size_override("font_size", Loc.text_size(words, THUMB_TEXT))

## A button layered over a running game. It never takes keyboard focus, so the
## keys the player is playing with keep reaching the game after they click one:
## a focusable button swallows SPACE as "press me again" and TAB as "move to
## the next button", which costs the player a jump or the assembly screen.
## Menus use `button` — there, keyboard and gamepad navigation is the point.
static func overlay_button(words: String, accent: Color = ACCENT, pixel: bool = false) -> Button:
	var b := button(words, accent, pixel)
	b.focus_mode = Control.FOCUS_NONE
	return b

## A graph's cooldown, drawn over its card and shared by every screen that
## lists slots so they cannot drift apart.
##
## `progress` runs 0 → 1 as the skill recovers. The grey sheet covers what is
## left of the wait and its upper edge is the clock hand: it starts at the top
## of the card and slides to the bottom, leaving the card clear when it lands.
## `flash` fades 1 → 0 just after it lands and brightens the card's edge, so a
## skill coming back announces itself to a player who is watching the fight
## rather than the bar.
static func draw_cooldown(c: CanvasItem, rect: Rect2, progress: float, flash: float,
		border: Color) -> void:
	var p := clampf(progress, 0.0, 1.0)
	if p < 1.0:
		var top := rect.position.y + rect.size.y * p
		c.draw_rect(Rect2(rect.position.x, top, rect.size.x, rect.end.y - top),
			Color(0.55, 0.58, 0.65, 0.55))
		# A lit edge on the sheet, so the slide reads even on a short cooldown.
		c.draw_line(Vector2(rect.position.x, top), Vector2(rect.end.x, top),
			Color(0.85, 0.9, 1.0, 0.75), 1.0)
	var f := clampf(flash, 0.0, 1.0)
	c.draw_rect(rect, border.lerp(Color(1, 1, 1), f * 0.85), false, 1.5 + 2.5 * f)

static func label(words: String, size: int = 13, color: Color = TEXT, pixel: bool = false) -> Label:
	var l := Label.new()
	l.text = words
	l.add_theme_color_override("font_color", color)
	if pixel:
		# Silkscreen only draws clean at multiples of its native 8px, and a
		# language writing in a face of its own only at multiples of that.
		l.add_theme_font_override("font", PIXEL_FONT)
		size = Loc.text_size(words, maxi(PIXEL_TEXT, snappedi(size, 8)))
	l.add_theme_font_size_override("font_size", size)
	return l

static func panel(color: Color = PANEL, border: Color = Color(0.22, 0.3, 0.38),
		pixel: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(color, border, 1, 3, pixel))
	if pixel and mobile():
		pass_presses(p)
	return p

## Lets a press on `c` go on to whatever holds it. A box keeps the presses that
## land on it, which is right at a desk and wrong for a list under a thumb: a
## page is dragged by whatever the thumb happens to be on, and a box in the way
## is a stretch of the page that will not move. In mobile mode the kit's own
## boxes pass theirs on; anything else that sits in a page's rows says so here.
static func pass_presses(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_PASS

static func title(words: String, size: int = 22, pixel: bool = false) -> Label:
	return label(words, size, Color(0.9, 0.95, 1.0), pixel)

## A Control parented to a CanvasLayer does not inherit the viewport rect, so
## full-screen screens have to be sized explicitly (and kept in sync on resize).
static func fill_screen(c: Control) -> void:
	# Top-left anchors, explicit size: full-rect anchors refuse a direct resize.
	c.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	c.position = Vector2.ZERO
	c.size = c.get_viewport_rect().size

static func sync_screen(c: Control) -> void:
	var want := c.get_viewport_rect().size
	if c.size != want:
		c.size = want

## A panel that fits the screen with its page pinned at both ends: a head, a
## foot, and between them the rows — the one part of it that scrolls.
##
## Every menu here is that shape: a title, a list, and the way out of it. Built
## as one column inside a scroll, which is what they all were, a list long
## enough to need a bar takes the title off the top of the screen and the way
## out off the bottom, and nothing on the screen says either is there. Pinning
## the ends is also what keeps a menu that grows — two new rebindable actions
## were enough, once — from pushing its own ABANDON RAID button out of the
## viewport.
class ScreenFrame extends PanelContainer:
	var content_width := 668.0
	## How much of the screen the frame leaves alone: it hangs no higher than
	## `top_margin` and stops `bottom_margin` short of the bottom. Between those
	## it is as tall as what it holds, and no taller — a short page sits in the
	## middle of the screen rather than filling it.
	var top_margin := 40.0
	var bottom_margin := 28.0
	## Whether the page was built for a thumb (`UiKit.mobile`), which is a page
	## that takes the screen: THUMB_PAGE wide where the screen has it, and all of
	## the height but THUMB_EDGE at either end, since its rows are THUMB tall and
	## a phone is not. Set when the frame is made and kept: what is in it was
	## built at one size or the other, and a page is built again when the mode
	## changes rather than stretched.
	var thumb := false
	## Whether the frame hangs in the screen's top-left corner rather than in its
	## middle, `top_margin` in from both edges: a page the screen behind it is to
	## be watched past. A thumb's page takes the screen, and has no corner to
	## hang in.
	var corner := false
	## The three boxes a page is made of, ready to fill the moment the frame is
	## made. `head` and `foot` are pinned; `rows` is what scrolls between them.
	var head: VBoxContainer
	var rows: VBoxContainer
	var foot: VBoxContainer
	## The scroll `rows` sits in, for anything that needs to drive it.
	var body: ScrollContainer

	func _init() -> void:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		add_child(v)
		head = _box()
		v.add_child(head)
		rows = _box()
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body = ScrollContainer.new()
		body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# So a row reached by keyboard or gamepad is scrolled to rather than
		# focused somewhere off the top of the box.
		body.follow_focus = true
		body.add_child(rows)
		UiKit.pixel_scroll(body)
		v.add_child(body)
		foot = _box()
		v.add_child(foot)

	func _box() -> VBoxContainer:
		var b := VBoxContainer.new()
		b.add_theme_constant_override("separation", 8)
		return b

	func _ready() -> void:
		# Top-left anchors, explicit size: full-rect anchors refuse a direct
		# resize, and a Control under a CanvasLayer inherits no rect to fill.
		set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_fit()

	func _process(_delta: float) -> void:
		_fit()

	func _fit() -> void:
		var vp := get_viewport_rect().size
		var top := UiKit.THUMB_EDGE if thumb else top_margin
		var bottom := UiKit.THUMB_EDGE if thumb else bottom_margin
		var wide := minf(UiKit.THUMB_PAGE, vp.x - UiKit.THUMB_EDGE * 2.0) if thumb else content_width
		var room := maxf(vp.y - top - bottom, 160.0)
		size = Vector2(wide, minf(_wanted_height(), room))
		# Whole pixels, or the pixel face lands between two of them.
		position = Vector2(floorf((vp.x - size.x) * 0.5),
			maxf(floorf((vp.y - size.y) * 0.5), top))
		if corner and not thumb:
			position = Vector2(top, top)

	## How tall the frame would be with nothing scrolled, so a page the screen
	## has room for is shown whole and only a longer one grows a bar. A
	## ScrollContainer asks for no height of its own — that is what makes it a
	## scroll — so the rows in it are measured and counted back in.
	func _wanted_height() -> float:
		return get_combined_minimum_size().y \
			+ rows.get_combined_minimum_size().y - body.get_combined_minimum_size().y

## A frame in the middle of the screen, `width` wide, with its `head`, `rows`
## and `foot` waiting to be filled. In mobile mode a pixel one is a page for a
## thumb instead — see `ScreenFrame.thumb` — whatever width and margins a desk
## gives it.
static func screen_frame(width: float, top: float, bottom: float,
		pixel: bool = false) -> ScreenFrame:
	var f := ScreenFrame.new()
	f.content_width = width
	f.top_margin = top
	f.bottom_margin = bottom
	f.thumb = pixel and mobile()
	f.add_theme_stylebox_override("panel",
		style(PANEL, Color(0.22, 0.3, 0.38), 1, 3, pixel))
	return f

## Marks a button as the answer already in force: unpressable, because it is
## what is already set, but lit rather than greyed — a button greyed the way an
## unavailable one is greyed reads as the one you cannot have rather than the
## one you have.
static func mark_chosen(b: Button) -> void:
	b.disabled = true
	b.add_theme_color_override("font_disabled_color", ACCENT)

## How wide the name of a setting is given, so every row on a page lines its
## answers up in the same column. Wide enough for the longest of them in the
## pixel face, which runs up to twice as wide as the one the menus used to be
## written in.
const SETTING_LABEL_W := 160.0

## That column in the mode the page is built in: twice as wide for a thumb's
## page, where the names are written twice the size.
static func setting_label_w() -> float:
	return SETTING_LABEL_W * (2.0 if mobile() else 1.0)

## A setting's name, in the column every row on the page keeps: the size a
## menu's words are written at in the mode it is built in, and that mode's
## width.
static func setting_label(name: String) -> Label:
	var l := label(name, text(PIXEL_TEXT), TEXT, true)
	l.custom_minimum_size = Vector2(setting_label_w(), 0)
	return l

## A setting answered by picking one of a few words: the name, then a button
## each, with the answer in force accented and unpressable. It is the shape the
## language row has always had, made once here because the title's settings and
## the pause menu both carry these rows and a setting that looked like two
## different things in the two screens would read as two settings.
##
## No tick and no box: a disabled accented button says which answer is in force
## without a second widget to theme, and every answer stays a thing you can
## reach with a gamepad.
##
## In mobile mode the answers share the rest of the row between them, so each is
## as much of it as a thumb can be given.
class ChoiceRow extends HBoxContainer:
	## Called with the index picked. Set through `UiKit.choice_row`.
	var on_pick: Callable
	var _name := ""
	var _options: PackedStringArray = PackedStringArray()
	var _picked := 0

	func setup(caption: String, options: PackedStringArray, picked: int, cb: Callable) -> void:
		_name = caption
		_options = options
		_picked = picked
		on_pick = cb
		add_theme_constant_override("separation", 8)
		_build(false)

	## What the row is showing. Set it to follow a setting changed somewhere
	## else; picking a button calls this on the way through.
	func show_picked(i: int) -> void:
		if i == _picked:
			return
		_picked = i
		# The button just pressed is about to be freed by its own press, and the
		# one that takes its place is disabled and cannot hold focus. So the
		# keyboard is handed to the next answer along rather than dropped on the
		# floor — otherwise one press ends gamepad navigation of the page.
		_build(_holds_focus())

	func _holds_focus() -> bool:
		if not is_inside_tree():
			return false
		var focused: Control = get_viewport().gui_get_focus_owner()
		return focused != null and is_ancestor_of(focused)

	func _build(refocus: bool) -> void:
		for c in get_children():
			remove_child(c)
			c.queue_free()
		add_child(UiKit.setting_label(_name))
		var first: Button = null
		for i in _options.size():
			var in_force: bool = i == _picked
			var b := UiKit.button(_options[i], UiKit.ACCENT if in_force else UiKit.DIM, true)
			if UiKit.mobile():
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if in_force:
				UiKit.mark_chosen(b)
			b.pressed.connect(func() -> void:
				Audio.play("ui")
				show_picked(i)
				if on_pick.is_valid():
					on_pick.call(i))
			add_child(b)
			if first == null and not in_force:
				first = b
		if refocus and first != null:
			first.grab_focus()

## A `ChoiceRow`, set up. `picked` is the index of the answer in force and
## `on_pick` is handed the index of the one pressed.
static func choice_row(name: String, options: PackedStringArray, picked: int,
		on_pick: Callable) -> ChoiceRow:
	var r := ChoiceRow.new()
	r.setup(name, options, picked, on_pick)
	return r

## A setting that is either on or off, thrown rather than picked from two words:
## a track with its corners notched, lit in the accent while it is on, and a
## square knob that slides to the end it was thrown to. Drawn a whole number of
## PIXELs at a time, like everything else in the pixel look, with a bar in the
## empty end while it is on and a ring while it is off, so the colour is not the
## only thing saying which.
##
## A BaseButton in toggle mode, so a click, a finger, `ui_accept` and a gamepad
## all throw it the same way, and `toggled` says which way it went.
##
## In mobile mode it is drawn twice the size, a block being two PIXELs, and the
## thing a thumb lands on is THUMB tall with the track in the middle of it.
class Switch extends BaseButton:
	## The track and the knob, in PIXELs. The knob sits two in from the edge of
	## the track's inside, and crosses the rest of it.
	const TRACK := Vector2i(32, 16)
	const KNOB := 10
	## Seconds for the knob to cross.
	const SLIDE := 0.08
	## Where the knob is drawn: 0 at the off end, 1 at the on end.
	var _at := 0.0
	## How many PIXELs a block of it is drawn at: 1, or 2 built for a thumb.
	var _unit := 1

	func _init() -> void:
		toggle_mode = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(TRACK) * UiKit.PIXEL
		if UiKit.mobile():
			_unit = 2
			custom_minimum_size = Vector2(TRACK.x * UiKit.PIXEL * _unit,
				maxf(TRACK.y * UiKit.PIXEL * _unit, UiKit.THUMB))
			mouse_filter = Control.MOUSE_FILTER_PASS
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		set_process(false)
		toggled.connect(func(_on: bool) -> void: set_process(true))

	## The track where it is drawn, in this control's own space: all of it at a
	## desk, and in the middle of the taller thing a thumb is given.
	func track_rect() -> Rect2:
		var s := Vector2(TRACK) * UiKit.PIXEL * _unit
		return Rect2(Vector2(0.0, floorf((size.y - s.y) * 0.5 / UiKit.PIXEL) * UiKit.PIXEL), s)

	## Thrown to `on` at once, the knob already there and nobody told: for
	## showing a setting as it stands rather than changing it.
	func show_on(on: bool) -> void:
		set_pressed_no_signal(on)
		_at = 1.0 if on else 0.0
		set_process(false)
		queue_redraw()

	func _process(delta: float) -> void:
		var want := 1.0 if button_pressed else 0.0
		_at = move_toward(_at, want, delta / SLIDE)
		if _at == want:
			set_process(false)
		queue_redraw()

	func _draw() -> void:
		var p := float(UiKit.PIXEL * _unit)
		draw_set_transform(track_rect().position)
		var on := button_pressed
		var lit := has_focus() or is_hovered()
		var w := float(TRACK.x)
		var h := float(TRACK.y)
		var fill := Color(0.19, 0.33, 0.41) if on else UiKit.BG
		var edge := UiKit.ACCENT if on else UiKit.LINE
		if lit:
			edge = Color.WHITE if on else UiKit.DIM
		draw_rect(Rect2(Vector2(p, p), Vector2(w - 2.0, h - 2.0) * p), fill)
		# The edge, stopping a PIXEL short of each corner, and a PIXEL set in at
		# each corner to carry it round: the notch is what makes it a track
		# rather than a box.
		draw_rect(Rect2(Vector2(p, 0.0), Vector2(w - 2.0, 1.0) * p), edge)
		draw_rect(Rect2(Vector2(p, (h - 1.0) * p), Vector2(w - 2.0, 1.0) * p), edge)
		draw_rect(Rect2(Vector2(0.0, p), Vector2(1.0, h - 2.0) * p), edge)
		draw_rect(Rect2(Vector2((w - 1.0) * p, p), Vector2(1.0, h - 2.0) * p), edge)
		for c in [Vector2(1, 1), Vector2(w - 2.0, 1), Vector2(1, h - 2.0), Vector2(w - 2.0, h - 2.0)]:
			draw_rect(Rect2(c * p, Vector2(p, p)), edge)
		# The bar or the ring, in the middle of the end the knob is not in.
		var mid := (h - 6.0) * 0.5
		if on:
			draw_rect(Rect2(Vector2(7.0, mid) * p, Vector2(1.0, 6.0) * p), Color.WHITE)
		else:
			var ring := Rect2(Vector2(w - 10.0, mid) * p, Vector2(4.0, 6.0) * p)
			draw_rect(ring, UiKit.DIM)
			draw_rect(ring.grow(-p), fill)
		# The knob, on whole PIXELs, with a PIXEL of dark round it so it stands
		# off the lit track.
		var travel := w - 6.0 - KNOB
		var knob := Rect2(Vector2(3.0 + roundf(_at * travel), (h - KNOB) * 0.5) * p,
			Vector2(KNOB, KNOB) * p)
		draw_rect(knob.grow(p), UiKit.BG)
		draw_rect(knob, (Color.WHITE if lit else UiKit.TEXT) if on else UiKit.DIM)
		# Where the keyboard is, a PIXEL-wide ring a PIXEL clear of the track.
		if has_focus():
			var r := Rect2(Vector2(-2.0, -2.0) * p, Vector2(w + 4.0, h + 4.0) * p)
			draw_rect(Rect2(r.position, Vector2(r.size.x, p)), UiKit.ACCENT)
			draw_rect(Rect2(Vector2(r.position.x, r.end.y - p), Vector2(r.size.x, p)), UiKit.ACCENT)
			draw_rect(Rect2(r.position, Vector2(p, r.size.y)), UiKit.ACCENT)
			draw_rect(Rect2(Vector2(r.end.x - p, r.position.y), Vector2(p, r.size.y)), UiKit.ACCENT)

## A `Switch`, showing `on`. `on_toggle` is handed which way it is thrown.
static func switch(on: bool, on_toggle: Callable) -> Switch:
	var s := Switch.new()
	s.show_on(on)
	s.toggled.connect(on_toggle)
	return s

## Room, and a rule across a page. Neither is a thing to press, so neither
## keeps a press that lands on it: under a thumb it goes to the page, which is
## dragged by it.
static func spacer(h: int = 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func hline(pixel: bool = false) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.25, 0.32, 0.4, 0.7)
	r.custom_minimum_size = Vector2(0, PIXEL * (2 if pixel and mobile() else 1) if pixel else 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## A slider in the pixel look: a flat track whose filled part is the accent, and
## a square knob in place of the theme's round one. In mobile mode the track and
## the knob are twice the size and the slider stands THUMB tall — a press
## anywhere along it carries the knob there, so the whole row is what a thumb
## lands on, and the knob only has to be seen.
static func pixel_slider(s: Slider) -> void:
	var k := 2 if mobile() else 1
	s.add_theme_stylebox_override("slider", _pixel_box(LINE, PIXEL * k))
	s.add_theme_stylebox_override("grabber_area", _pixel_box(ACCENT, PIXEL * k))
	s.add_theme_stylebox_override("grabber_area_highlight", _pixel_box(ACCENT, PIXEL * k))
	s.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), ACCENT, 1, 0, true))
	s.add_theme_icon_override("grabber", _pixel_knob(TEXT, k))
	s.add_theme_icon_override("grabber_highlight", _pixel_knob(Color.WHITE, k))
	s.add_theme_icon_override("grabber_disabled", _pixel_knob(DIM, k))
	if mobile():
		s.custom_minimum_size.y = maxf(s.custom_minimum_size.y, THUMB)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL

## A scroll container in the pixel look: flat, square bars four PIXELs wide, and
## a square focus border in place of the theme's rounded one, which the
## container draws through an internal panel of its own. Twice as wide in mobile
## mode, where the bar is only there to be seen: a thumb moves the list by the
## list.
static func pixel_scroll(sc: ScrollContainer) -> void:
	var wide := PIXEL * (4 if mobile() else 2)
	# How far a thumb moves before the list goes with it. With none, the tremor
	# of a thumb coming down on a button is a drag, and a drag lets go of the
	# button: nothing in the list could be pressed.
	if mobile():
		sc.scroll_deadzone = int(TOUCH_SLOP)
	sc.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), ACCENT, 1, 0, true))
	for bar: ScrollBar in [sc.get_v_scroll_bar(), sc.get_h_scroll_bar()]:
		bar.add_theme_stylebox_override("scroll", _pixel_box(PANEL, wide))
		bar.add_theme_stylebox_override("scroll_focus", _pixel_box(PANEL, wide))
		bar.add_theme_stylebox_override("grabber", _pixel_box(LINE, wide))
		bar.add_theme_stylebox_override("grabber_highlight", _pixel_box(ACCENT, wide))
		bar.add_theme_stylebox_override("grabber_pressed", _pixel_box(ACCENT, wide))

## A flat, borderless, unsmoothed box. Its margins are what give a slider track
## or a scrollbar its thickness.
static func _pixel_box(bg: Color, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.anti_aliasing = false
	s.set_content_margin_all(margin)
	return s

## The slider knob: a block of `fill` inside a one-PIXEL dark border, a block
## being `k` PIXELs.
static func _pixel_knob(fill: Color, k: int = 1) -> ImageTexture:
	var p := PIXEL * k
	var img := Image.create_empty(p * 6, p * 8, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	img.fill_rect(Rect2i(p, p, p * 4, p * 6), fill)
	return ImageTexture.create_from_image(img)
