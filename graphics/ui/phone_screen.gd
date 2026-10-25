class_name PhoneScreen
extends Control

## The phone (`Phone`) on the screen: a handset that slides up from the
## bottom on its key and down again, over a veil, with a home screen of apps
## on it the way a phone has — a status bar along its top with the time, a
## grid of icons, and a bar along its bottom that goes home from any app.
##
## The apps. GALLERY is the photos it has taken, one a tile, and each on a
## page of its own with the way to throw it away. CAMERA shows what the
## phone sees — the world behind it, as the pixel camera draws it — and takes
## a photo of the screen with the phone out of the way (`snap`). ALARM is set
## for so many minutes, counts down, and rings; set, the phone can be put down
## on the floor for its ringing to be walked away from (`put_down_requested`),
## and the page says so while it lies there. SETTINGS is the volumes, the
## language and the video, the rows the pause menu has, on rows narrow enough
## for a phone. KIT, MAP and FOES are the pages of the screen over the world,
## and open it on theirs (`app_opened`); the keys those pages open on do the
## same from here, and the phone's own key, or ESC, puts it away (`closed`).
##
## Drawn in UiKit's pixel look like every other screen, the icons bitmaps
## (`PixelDraw.icon`). A thumb works it as a pointer does: everything on it is
## a button. What the shell does with it is `app/game.gd`.

signal closed()
signal app_opened(id: String)
signal put_down_requested()

const W := 360.0
const H := 640.0
const BEZEL := 10.0
const STATUS_H := 28.0
const HOME_BAR_H := 28.0
## How long the slide up, and down, takes.
const SLIDE := 0.28
const VEIL := Color(0.02, 0.03, 0.05, 0.55)
const BODY := Color(0.07, 0.08, 0.1)
const EDGE := Color(0.3, 0.34, 0.4)
const GLASS := Color(0.04, 0.05, 0.08)
const INK := Color(0.9, 0.94, 1.0)
const DIM := Color(0.55, 0.62, 0.7)
const ICON_ZOOM := 2
## The home screen's pages, and the apps' own.
const HOME := "home"
const GALLERY := "gallery"
const PHOTO := "photo"
const CAMERA := "camera"
const ALARM := "alarm"
const SETTINGS := "settings"
## An alarm is set in steps of these, in seconds, from this.
const ALARM_START := 60.0
const ALARM_STEPS := [-60.0, -10.0, 10.0, 60.0]

## The apps on the home screen, in order: each its id — a page here, or a page
## of the screen over the world (`ScreenTabs`) — the key its name is under,
## its colour and its icon.
const APPS := [
	{"id": GALLERY, "name": "hud.phone.app.gallery", "color": Color(0.95, 0.62, 0.35), "icon": [
		"############", "#..........#", "#.##.......#", "#.##.......#", "#..........#", "#......#...#",
		"#.....###..#", "#..#.#####.#", "#.###.######", "#.##########", "############", "............"]},
	{"id": CAMERA, "name": "hud.phone.app.camera", "color": Color(0.5, 0.6, 0.7), "icon": [
		"............", "...####.....", "############", "#..........#", "#...####...#", "#..#....#..#",
		"#..#....#..#", "#..#....#..#", "#...####...#", "#..........#", "############", "............"]},
	{"id": ALARM, "name": "hud.phone.app.alarm", "color": Color(0.95, 0.45, 0.45), "icon": [
		".##......##.", "#..######..#", "..#......#..", ".#........#.", "#....#.....#", "#....#.....#",
		"#....###...#", "#..........#", ".#........#.", "..#......#..", "...######...", "..#......#.."]},
	{"id": SETTINGS, "name": "hud.phone.app.settings", "color": Color(0.6, 0.66, 0.74), "icon": [
		"....####....", "..#.####.#..", ".##########.", "..###..###..", "####....####", "####....####",
		"####....####", "####....####", "..###..###..", ".##########.", "..#.####.#..", "....####...."]},
	{"id": ScreenTabs.GRAPH, "name": "hud.tabs.graph", "color": Color(0.45, 0.85, 1.0), "icon": [
		"###.........", "#.#.........", "###.........", "..#.........", "..#...###...", "..#...#.#...",
		"..#####.#...", "........#...", "....###.#...", "....#.#.#...", "....###.#...", "....#####..."]},
	{"id": ScreenTabs.MAP, "name": "hud.tabs.map", "color": Color(0.45, 0.95, 0.7), "icon": [
		"............", ".####.####..", "#....#....#.", "#.##.#..#.#.", "#..#.#.#..#.", "#..#.#.#..#.",
		"#.#..#..#.#.", "#.#..#..#.#.", "#....#....#.", ".####.####..", "............", "............"]},
	{"id": ScreenTabs.DEX, "name": "hud.tabs.dex", "color": Color(0.85, 0.55, 0.95), "icon": [
		"....####....", "..########..", ".##########.", "###.####.###", "###.####.###", "############",
		"############", ".#.#.##.#.#.", ".##########.", "..#.#..#.#..", "..########..", "............"]},
]

## The world's picture, for the camera's viewfinder: the shell hands it over
## before the phone comes up (`PixelCamera.picture`).
var picture: Texture2D = null
## Whether the phone can be put down where the player stands: in a raid and in
## the hideout, which have a floor; the shell says.
var can_put_down: bool = false
## The page that is up.
var page: String = HOME

var _veil: ColorRect
var _handset: Control
var _hx: PixelDraw
var _status: Control
var _sx: PixelDraw
var _pages: MarginContainer
var _home_bar: Button
var _tween: Tween = null
var _closing := false
var _snapping := false
var _t := 0.0
## The alarm being chosen, in seconds, before it is set.
var _pick: float = ALARM_START
var _count: Label = null
var _note: Label = null
var _flash: ColorRect = null
var _flash_left := 0.0
## The home screen's tiles, by app id, for a test to press.
var _tiles: Dictionary = {}
## The photos' tiles, by path, for the same.
var _thumbs: Dictionary = {}
var _textures: Dictionary = {}

func _ready() -> void:
	UiKit.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_veil = ColorRect.new()
	_veil.color = VEIL
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_veil)
	_handset = Control.new()
	_handset.size = Vector2(W, H)
	_handset.mouse_filter = Control.MOUSE_FILTER_STOP
	_hx = PixelDraw.new(_handset)
	_handset.draw.connect(_paint_handset)
	add_child(_handset)
	_status = Control.new()
	_status.position = Vector2(BEZEL, BEZEL)
	_status.size = Vector2(W - BEZEL * 2.0, STATUS_H)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sx = PixelDraw.new(_status)
	_status.draw.connect(_paint_status)
	_handset.add_child(_status)
	_pages = MarginContainer.new()
	_pages.position = Vector2(BEZEL, BEZEL + STATUS_H)
	_pages.size = Vector2(W - BEZEL * 2.0, H - BEZEL * 2.0 - STATUS_H - HOME_BAR_H)
	for side in ["left", "right", "top", "bottom"]:
		_pages.add_theme_constant_override("margin_" + side, 8)
	_handset.add_child(_pages)
	_home_bar = Button.new()
	_home_bar.flat = true
	_home_bar.focus_mode = Control.FOCUS_NONE
	_home_bar.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_home_bar.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_home_bar.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_home_bar.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_home_bar.position = Vector2(BEZEL, H - BEZEL - HOME_BAR_H)
	_home_bar.size = Vector2(W - BEZEL * 2.0, HOME_BAR_H)
	_home_bar.pressed.connect(func() -> void:
		if page != HOME:
			Audio.play("ui", 0.9)
			show_page(HOME))
	_handset.add_child(_home_bar)
	Phone.changed.connect(_on_phone_changed)
	Loc.language_changed.connect(func(_lang: String) -> void:
		if visible:
			show_page(page))

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_veil.size = size
	_t += delta
	_handset.position.x = roundf((size.x - W) * 0.5)
	if _tween == null or not _tween.is_valid():
		_handset.position.y = _rest() if visible and not _closing else size.y
	_status.queue_redraw()
	if _count != null and is_instance_valid(_count):
		_count.text = _alarm_words()
		_count.modulate.a = 0.55 + 0.45 * absf(sin(_t * 6.0)) if Phone.ringing > 0.0 else 1.0
	if _flash != null and is_instance_valid(_flash):
		_flash_left = maxf(_flash_left - delta * 3.0, 0.0)
		_flash.color.a = _flash_left

## Where the handset rests: in the middle of the screen.
func _rest() -> float:
	return roundf((size.y - H) * 0.5)

## Whether it is up — on screen, and not on its way down.
func up() -> bool:
	return visible and not _closing

## Up from the bottom, on its home screen.
func open() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_closing = false
	visible = true
	UiKit.sync_screen(self)
	show_page(HOME)
	_handset.position.y = size.y
	_tween = create_tween()
	_tween.tween_property(_handset, "position:y", _rest(), SLIDE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Cues.emit_cue(&"phone", {"kind": "open"})

## Down off the bottom, and gone.
func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_handset, "position:y", size.y, SLIDE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.finished.connect(func() -> void:
		if _closing:
			visible = false
			_closing = false)
	Cues.emit_cue(&"phone", {"kind": "close"})

## Handled here rather than in `_gui_input` so the keys work whether or not
## the handset holds focus, and marked handled so the shell does not see the
## press that put the phone away and bring it straight back up.
func _input(event: InputEvent) -> void:
	if not up() or _snapping:
		return
	if event.is_action_pressed("open_phone") or event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_editor"):
		app_opened.emit(ScreenTabs.GRAPH)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_map"):
		app_opened.emit(ScreenTabs.MAP)
		get_viewport().set_input_as_handled()

## --- the handset -----------------------------------------------------------------

func _paint_handset() -> void:
	var px := float(PixelDraw.PX)
	# The body, its corners stepped off.
	_hx.rect(Rect2(px * 2.0, 0.0, W - px * 4.0, H), BODY)
	_hx.rect(Rect2(0.0, px * 2.0, W, H - px * 4.0), BODY)
	_hx.rect(Rect2(px, px, W - px * 2.0, H - px * 2.0), BODY)
	_hx.frame(Rect2(px, px, W - px * 2.0, H - px * 2.0), EDGE)
	# The glass, and the island in the top of it.
	_hx.rect(Rect2(BEZEL, BEZEL, W - BEZEL * 2.0, H - BEZEL * 2.0), GLASS)
	_hx.rect(Rect2(W * 0.5 - 40.0, BEZEL + 6.0, 80.0, 14.0), BODY)
	# The bar along the bottom that goes home.
	var lit := _home_bar.is_hovered() and page != HOME
	_hx.rect(Rect2(W * 0.5 - 50.0, H - BEZEL - 12.0, 100.0, 6.0), INK if lit else DIM)

## The time, the alarm while one is set, and the battery.
func _paint_status() -> void:
	var px := float(PixelDraw.PX)
	_sx.text(Vector2(8.0, 20.0), Time.get_time_string_from_system().substr(0, 5), INK)
	var right := _status.size.x - 8.0
	# A full battery, which is what a phone that is never charged has.
	var battery := Rect2(right - 24.0, 8.0, 22.0, 12.0)
	_sx.frame(battery, INK)
	_sx.rect(Rect2(battery.end.x, battery.position.y + px * 2.0, px, battery.size.y - px * 4.0), INK)
	_sx.rect(battery.grow(-px * 2.0), UiKit.GOOD)
	right = battery.position.x - 10.0
	if Phone.alarm_set() or Phone.ringing > 0.0:
		var words := _clock(Phone.alarm) if Phone.alarm_set() else Loc.t("hud.phone.alarm.ringing")
		var ink := UiKit.WARN if Phone.ringing > 0.0 else DIM
		right -= PixelDraw.text_width(words)
		_sx.text(Vector2(right, 20.0), words, ink)
		# A bell before it.
		right -= 16.0
		_sx.icon(Vector2(right, 8.0), ["..#..", ".###.", ".###.", "#####", "..#.."], ink)

## --- pages ------------------------------------------------------------------------

## Clears the page and puts `id`'s up.
func show_page(id: String, arg: String = "") -> void:
	page = id
	_count = null
	_note = null
	_flash = null
	_tiles.clear()
	_thumbs.clear()
	for c in _pages.get_children():
		_pages.remove_child(c)
		c.queue_free()
	match id:
		HOME:
			_build_home()
		GALLERY:
			_build_gallery()
		PHOTO:
			_build_photo(arg)
		CAMERA:
			_build_camera()
		ALARM:
			_build_alarm()
		SETTINGS:
			_build_settings()
	_handset.queue_redraw()

## What is on the phone changed — the alarm, the photos: the page that shows
## it is built again, so it shows what is so.
func _on_phone_changed() -> void:
	if not visible:
		return
	match page:
		ALARM, GALLERY:
			show_page(page)
		PHOTO:
			pass

## An app pressed: its page, or the shell's.
func _open_app(id: String) -> void:
	Audio.play("ui")
	match id:
		GALLERY, CAMERA, ALARM, SETTINGS:
			show_page(id)
		_:
			app_opened.emit(id)

## The head of an app's page: the way back to the home screen, and the name.
func _head(title: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var back := UiKit.button(Loc.t("menu.pause.arrow"), UiKit.ACCENT, true)
	back.name = "Back"
	back.custom_minimum_size = UiKit.corner_button()
	back.pressed.connect(func() -> void:
		Audio.play("ui", 0.9)
		show_page(HOME))
	h.add_child(back)
	h.add_child(UiKit.title(title, UiKit.text(16), true))
	return h

## A page: its head, and under it its body, which scrolls when it is long.
func _page(title: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(_head(title))
	v.add_child(UiKit.hline(true))
	var sc := ScrollContainer.new()
	sc.name = "Scroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiKit.pixel_scroll(sc)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	v.add_child(sc)
	_pages.add_child(v)
	return body

func _words(key: String, color: Color = DIM) -> Label:
	var l := UiKit.label(Loc.t(key), UiKit.text(16), color, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

## --- home -----------------------------------------------------------------------

func _build_home() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UiKit.spacer(8))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for app in APPS:
		var tile := _tile(app)
		_tiles[String(app["id"])] = tile
		grid.add_child(tile)
	v.add_child(grid)
	_pages.add_child(v)

## An app's tile: its icon on a plate of its colour, its name under it.
func _tile(app: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(104.0, 88.0)
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var px := PixelDraw.new(b)
	b.draw.connect(func() -> void:
		var hot := b.is_hovered()
		var col: Color = app["color"]
		var plate := Rect2((b.size.x - 48.0) * 0.5, 4.0, 48.0, 48.0)
		px.rect(plate, col.darkened(0.55 if hot else 0.7))
		px.frame(plate, col if hot else col.darkened(0.3))
		px.icon_centered(plate.get_center(), app["icon"], col.lightened(0.3 if hot else 0.0), ICON_ZOOM)
		px.text_centered(Vector2(0.0, 76.0), Loc.t(String(app["name"])), INK if hot else DIM, b.size.x))
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)
	b.pressed.connect(func() -> void: _open_app(String(app["id"])))
	return b

## --- gallery ----------------------------------------------------------------------

func _build_gallery() -> void:
	var body := _page(Loc.t("hud.phone.app.gallery"))
	var paths := Phone.photos()
	if paths.is_empty():
		body.add_child(_words("hud.phone.gallery.empty"))
		return
	body.add_child(UiKit.label(Loc.t("hud.phone.gallery.count", [paths.size()]), UiKit.text(16), DIM, true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for path in paths:
		var b := TextureButton.new()
		b.custom_minimum_size = Vector2(104.0, 58.0)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		b.texture_normal = _texture(path, true)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.pressed.connect(func() -> void:
			Audio.play("ui")
			show_page(PHOTO, path))
		_thumbs[path] = b
		grid.add_child(b)
	body.add_child(grid)

func _build_photo(path: String) -> void:
	var body := _page(path.get_file().get_basename())
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(0.0, 184.0)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.texture = _texture(path, false)
	body.add_child(pic)
	var del := UiKit.button(Loc.t("hud.phone.gallery.delete"), UiKit.BAD, true)
	del.name = "Delete"
	del.pressed.connect(func() -> void:
		Audio.play("erase")
		Phone.delete_photo(path)
		_textures.erase(path)
		show_page(GALLERY))
	body.add_child(del)

## A photo as a texture — a small one for its tile — read once and kept.
func _texture(path: String, thumb: bool) -> Texture2D:
	var key := path + ("#thumb" if thumb else "")
	if _textures.has(key):
		return _textures[key]
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	if thumb:
		img.resize(160, int(160.0 * float(img.get_height()) / maxf(float(img.get_width()), 1.0)),
			Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex

## --- camera -----------------------------------------------------------------------

func _build_camera() -> void:
	var body := _page(Loc.t("hud.phone.app.camera"))
	var finder := Control.new()
	finder.custom_minimum_size = Vector2(0.0, 184.0)
	var pic := TextureRect.new()
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.texture = picture
	pic.clip_contents = true
	finder.add_child(pic)
	var dark := ColorRect.new()
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0.0, 0.0, 0.0, 1.0 if picture == null else 0.0)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	finder.add_child(dark)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	finder.add_child(_flash)
	body.add_child(finder)
	var snap_btn := UiKit.button(Loc.t("hud.phone.camera.snap"), UiKit.ACCENT, true)
	snap_btn.name = "Snap"
	snap_btn.custom_minimum_size = Vector2(0.0, maxf(44.0, UiKit.thumb()))
	snap_btn.pressed.connect(snap)
	body.add_child(snap_btn)
	_note = UiKit.label("", UiKit.text(16), UiKit.GOOD, true)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_note)

## A photo of the screen, with the phone out of the way for the frame it is
## taken in, kept by the phone (`Phone.save_photo`).
func snap() -> void:
	if _snapping or not up():
		return
	_snapping = true
	visible = false
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	visible = true
	_snapping = false
	var path := Phone.save_photo(img)
	_flash_left = 1.0
	if page == CAMERA and _note != null and is_instance_valid(_note):
		_note.text = Loc.t("hud.phone.camera.saved") if path != "" else ""

## --- alarm --------------------------------------------------------------------------

func _build_alarm() -> void:
	var body := _page(Loc.t("hud.phone.app.alarm"))
	_count = UiKit.label(_alarm_words(), UiKit.text(32), INK, true)
	_count.name = "Count"
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(UiKit.spacer(8))
	body.add_child(_count)
	body.add_child(UiKit.spacer(8))
	if Phone.ringing > 0.0 or Phone.alarm_set():
		if not Phone.carried():
			body.add_child(_words("hud.phone.alarm.lying", UiKit.WARN))
		var stop := UiKit.button(Loc.t("hud.phone.alarm.stop"), UiKit.BAD, true)
		stop.name = "Stop"
		stop.pressed.connect(func() -> void: Phone.clear_alarm())
		body.add_child(stop)
		if Phone.alarm_set() and Phone.carried() and can_put_down:
			var down := UiKit.button(Loc.t("hud.phone.alarm.down"), UiKit.WARN, true)
			down.name = "Down"
			down.pressed.connect(func() -> void: put_down_requested.emit())
			body.add_child(down)
		return
	body.add_child(_words("hud.phone.alarm.pick"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for step in ALARM_STEPS:
		var s := float(step)
		var b := UiKit.button(("+" if s > 0.0 else "-") + _clock(absf(s)), UiKit.ACCENT, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_pick = clampf(_pick + s, Phone.ALARM_MIN, Phone.ALARM_MAX)
			if _count != null and is_instance_valid(_count):
				_count.text = _alarm_words())
		row.add_child(b)
	body.add_child(row)
	var set_btn := UiKit.button(Loc.t("hud.phone.alarm.set"), UiKit.GOOD, true)
	set_btn.name = "Set"
	set_btn.pressed.connect(func() -> void: Phone.set_alarm(_pick))
	body.add_child(set_btn)

## What the alarm's page says in big: the time being chosen, the time left,
## or that it is ringing.
func _alarm_words() -> String:
	if Phone.ringing > 0.0:
		return Loc.t("hud.phone.alarm.ringing")
	if Phone.alarm_set():
		return _clock(Phone.alarm)
	return _clock(_pick)

## `seconds` as m:ss.
static func _clock(seconds: float) -> String:
	var s := maxi(ceili(seconds), 0)
	return "%d:%02d" % [int(s / 60.0), s % 60]

## --- settings -----------------------------------------------------------------------

## The pause menu's rows, each on two lines: the name over what it sets, since
## a phone is too narrow for them side by side.
func _build_settings() -> void:
	var body := _page(Loc.t("hud.phone.app.settings"))
	body.add_child(_slider_row(Loc.t("menu.settings.music"), Audio.music_volume,
		func(val: float) -> void: Audio.set_music_volume(val)))
	body.add_child(_slider_row(Loc.t("menu.settings.sound"), Audio.sfx_volume, func(val: float) -> void:
		Audio.set_sfx_volume(val)
		Audio.play("ui")))
	var langs := PackedStringArray()
	var picked := 0
	for lang in Loc.languages():
		if String(lang) == Loc.language:
			picked = langs.size()
		langs.append(Loc.language_name(String(lang)))
	body.add_child(_choice_row(Loc.t("menu.settings.language"), langs, picked,
		func(i: int) -> void: Loc.set_language(String(Loc.languages()[i]))))
	if not OS.has_feature("mobile"):
		body.add_child(_choice_row(Loc.t("menu.video.screen"),
			PackedStringArray([Loc.t("menu.video.windowed"), Loc.t("menu.video.fullscreen")]),
			1 if Video.fullscreen else 0, func(i: int) -> void: Video.set_fullscreen(i == 1)))
	body.add_child(_choice_row(Loc.t("menu.video.shake"),
		PackedStringArray([Loc.t("menu.video.off"), Loc.t("menu.video.on")]),
		1 if Video.screen_shake else 0, func(i: int) -> void: Video.set_screen_shake(i == 1)))
	body.add_child(_choice_row(Loc.t("menu.video.icons"),
		PackedStringArray([Loc.t("menu.video.off"), Loc.t("menu.video.on")]),
		1 if Video.icon_motion else 0, func(i: int) -> void: Video.set_icon_motion(i == 1)))

func _slider_row(name_text: String, value: float, cb: Callable) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(UiKit.label(name_text, UiKit.text(16), UiKit.TEXT, true))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(0.0, 20.0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.pixel_slider(s)
	s.value_changed.connect(cb)
	v.add_child(s)
	return v

func _choice_row(name_text: String, options: PackedStringArray, picked: int, cb: Callable) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(UiKit.label(name_text, UiKit.text(16), UiKit.TEXT, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for i in options.size():
		var b := UiKit.button(options[i], UiKit.ACCENT if i == picked else UiKit.DIM, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == picked:
			UiKit.mark_chosen(b)
		b.pressed.connect(func() -> void:
			Audio.play("ui")
			cb.call(i)
			show_page(SETTINGS))
		row.add_child(b)
	v.add_child(row)
	return v
