extends Node

## The mouse pointer the game draws for itself.
##
## The pointer is drawn here rather than shipped. Every asset in this game that
## is not the sprite atlas or a font is built at boot — the sounds are
## synthesised next door in `audio/`, and the rooms, the effects and the whole
## UI are drawn from primitives — and a cursor is a picture eleven pixels
## across, so it is a table of characters and a handful of lines instead of a
## file to keep in step with the rest.
##
## How fast it moves is the game's, and only while the game is doing the
## pointing. That distinction is the whole of the design, and it was learned the
## hard way: the game used to move the *system* pointer to serve the setting,
## and on macOS that cannot be made to behave.
##
##   * Moving the pointer works — a move lands where it is sent, to the pixel,
##     on a 2x screen, and seven hundred moves in a row land there too.
##   * But the call that does it unhooks the pointer from the mouse underneath
##     and swallows what the hand does for a moment afterwards. The hand keeps
##     going, the two drift apart, and when the system puts them back together
##     the pointer arrives wherever the mouse had got to. On a fast zigzag that
##     is somewhere across the screen.
##   * Keeping the pointer on the window, which is the other way to stop them
##     drifting apart, unhooks it outright: the pointer stops following the
##     mouse at all and only moves when something moves it.
##
## So the system pointer is never moved, never held, and never argued with.
## While the player has the controls the game hides it and keeps a pointer of
## its own, `point`, which it moves at whatever speed the setting asks for and
## draws the crosshair at. Let go of the controls for a menu or a map, and the
## system pointer comes straight back into sight, at its own speed, for the
## buttons — as the system's own arrow, wherever the hand has taken it. The
## crosshair is for aiming, so it is only ever on the screens the player aims
## on: the battleground and the hideout floor.
##
## And when it is the computer that has the controls — the game holding the
## player through a conversation or a stun, walking them over to talk, or
## something playing them in their place (`ComputerHands`) — both are on the
## screen at once. The crosshair stays, and is the computer's: it rests where it
## was, or goes where the computer leads it (`lead`), and the mouse does not
## move it. The system pointer is shown beside it as the system's own arrow,
## free to go wherever the hand takes it and moving nothing in the game: the
## person watching still has a mouse. A window over all that — the pause menu —
## is the system's like any other, and with it put away the crosshair is back
## where the computer had it, for as long as the computer still has the
## controls.
##
## Hidden rather than taken. Taking the mouse is how a game usually gets its
## movement, and it is not as hands-off as it sounds: for as long as Godot has
## it, it parks the system pointer in the middle of the window, so every menu
## opened with the pointer there — and putting it back under the crosshair on
## the way out was one more move. Hidden, the pointer goes on following the
## hand and nothing here tells it where to be. The price is that at any speed
## but 1.0 it and the crosshair part company: a menu opens with the arrow
## wherever the hand took it, not where the crosshair was, and in a window
## nothing stops the hidden pointer leaving it, where a click lands on whatever
## is outside. At 1.0 the crosshair is the hidden pointer, and they never part.
##
## Which means the setting is aim speed. Menus are the system's and stay 1:1.

## The pointer, one character per art pixel: `#` is the bright body, `.` is
## nothing. The dark edge around it is not drawn here — it is worked out from
## the body, so the shape is the only thing there is to keep right.
##
## A crosshair rather than an arrow: the mouse's whole job in a raid is to say
## where an attack goes, and the gap in the middle leaves what is being aimed at
## visible instead of sitting an arrowhead on top of it.
const ART := [
	".....#.....",
	".....#.....",
	".....#.....",
	"...........",
	"...........",
	"###..#..###",
	"...........",
	"...........",
	".....#.....",
	".....#.....",
	".....#.....",
]
## Screen pixels to an art pixel. The UI is drawn at two, and a pointer at one
## would be the only thing on screen at a finer grain than everything else.
const SCALE := 2
const INK := Color(0.96, 0.99, 1.0)
const EDGE := Color(0.05, 0.07, 0.1)

## Where the setting is kept: its own file, beside the language and the key
## bindings and for the same reason. How fast a mouse should move is a property
## of the desk it is sitting on, not of the profile being played on it.
const PATH := "user://enigami_pointer.json"

## What the slider spans. Below the bottom the pointer is slower than the hand
## moving it, which is what a fine aim wants; above the top it crosses the
## screen faster than the eye follows it back.
const MIN_SENS := 0.4
const MAX_SENS := 2.5
const STEP := 0.1

## 1.0 keeps the pointer exactly where the system's own, hidden, has got to.
var sensitivity: float = 1.0

## Where the game is pointing, on the screen it is drawn at: 1280x720, or wider
## or taller on a display of another shape. While the system pointer is doing
## the pointing this is simply where that is; while the player's hand is doing
## it, this is what the mouse has been moving; and while the computer is, it is
## where the computer has led it, whatever the mouse does.
var point: Vector2 = Vector2.ZERO

## Where the grid the picture is drawn on starts, in screen pixels.
##
## The world is drawn through a `PixelCamera`, which lays its buffer over the
## screen slid by whatever the real camera had left over — so the grid the
## picture sits on is not anchored at the screen's corner. It moves with the
## camera, and it starts on an odd screen pixel about half the time. The camera
## hands its slide over here every frame; zero is what is left when no camera is
## up, and it is what the menus want, which are drawn on the screen's own grid.
var pixel_origin: Vector2 = Vector2.ZERO

## Kept so the picture outlives nothing: handed to the window and held here, it
## goes when this node goes, which is before the renderer that owns it does.
var _tex: ImageTexture = null
## What the window's own pointer is wearing: the crosshair while somebody is
## aiming, and null — the system's own arrow — the rest of the time.
var _worn: Texture2D = null
var _hidden: bool = false
var _crosshair: TextureRect = null
## Who was doing the pointing last frame, to see it change hands.
var _who: int = Who.SYSTEM
## Where the computer has the pointer, for as long as it has the controls: kept
## through a window that covers them — the pause menu — so the crosshair can go
## back to it. `_has_led` is whether there is such a place to go back to.
var _led: Vector2 = Vector2.ZERO
var _has_led: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_saved()
	_tex = texture()
	_build_crosshair()

## Dresses the window's own pointer: `tex` for its arrow, or null for the
## system's. Every Control in the game uses the arrow shape — nothing here asks
## for a hand or a beam — so the arrow is the whole cursor.
##
## It used to wear the crosshair from boot, so every menu in the game pointed
## with one. The crosshair is for aiming, and a menu is buttons.
func _wear(tex: Texture2D) -> void:
	_worn = tex
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, hotspot())

## Give the pointer back on the way out. A texture still held by the window
## when the renderer shuts down is reported as a leak, which is a real one: the
## game is quitting, but nothing should be left holding the door.
func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	_worn = null
	_tex = null

## --- whose pointer it is ----------------------------------------------------
## Who is doing the pointing.
##
##   SYSTEM    nobody is aiming: a menu, a map, the assembly overlay, the pause
##             menu, the title. The system's own arrow, for the buttons.
##   HAND      the player has the controls: a raid, the bench, the hideout
##             floor. The system pointer is hidden, and the crosshair goes
##             where the mouse takes it.
##   COMPUTER  the computer has them (`Player.taken_over`): the game is holding
##             the player or walking them, or something is playing them in
##             their place. The crosshair is the computer's, and the system
##             pointer is shown beside it and moves nothing.
enum Who { SYSTEM, HAND, COMPUTER }

## Every screen that takes the keys away hands the pointer back to the system
## on the same frame, because the same thing decides both — and a screen over a
## player the computer has is still a screen. With more than one player on the
## floor, a hand on any of them is a hand on the pointer.
func who() -> int:
	if get_tree() == null or get_tree().paused:
		return Who.SYSTEM
	var taken := false
	for p in get_tree().get_nodes_in_group("player"):
		if not p.has_method("controls_locked"):
			continue
		if p.has_method("taken_over") and p.taken_over():
			taken = true
		elif not p.controls_locked():
			return Who.HAND
	return Who.COMPUTER if taken else Who.SYSTEM

## Whether the game is doing the pointing, with its own crosshair: the player's
## hand on it, or the computer's.
func game_is_pointing() -> bool:
	return who() != Who.SYSTEM

## Whether it is the computer the crosshair answers to.
func computer_is_pointing() -> bool:
	return who() == Who.COMPUTER

func _process(_delta: float) -> void:
	var now := who()
	if now != _who:
		_change_hands(_who, now)
		_who = now
	# The crosshair while the player is aiming, and the system's arrow for every
	# window over them. Most of the time the game hides the window's pointer
	# while they aim and draws its own; the window's is on show when the
	# console is up, which never hides it. While the computer has the controls
	# the window's pointer is on show as well, and as the arrow: it is the
	# person's own pointer, there to be told apart from the crosshair.
	var wear: Texture2D = _tex if now == Who.HAND else null
	if wear != _worn:
		_wear(wear)
	# Not while the console is on the screen. A phone aims with the movement
	# keys — `TouchPad._aim` says why it can be nothing else — so there is no
	# pointer to move, and a crosshair nothing moves would sit wherever the
	# last thing to touch it left it.
	var hide := now == Who.HAND and not Touch.wanted()
	if hide != _hidden:
		_hidden = hide
		# Hidden, not taken and not confined: the system pointer goes on
		# following the hand out of sight, and is shown again wherever that
		# left it. Nothing here ever tells it where to be.
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if hide else Input.MOUSE_MODE_VISIBLE
	if now == Who.COMPUTER:
		point = _led
	elif not _hidden:
		var vp := get_viewport()
		if vp != null:
			point = vp.get_mouse_position()
	if _crosshair != null:
		# The computer's crosshair is drawn like the hand's — but not on the
		# console, where the hand's is not either: a phone has no pointer for
		# it to be told apart from.
		_crosshair.visible = _hidden or (now == Who.COMPUTER and not Touch.wanted())
		_crosshair.position = on_grid(point - hotspot())

## The pointing has changed hands, from `was` to `now`.
func _change_hands(was: int, now: int) -> void:
	match now:
		Who.COMPUTER:
			# Back out of a window that covered the computer's turn — the pause
			# menu — the pointer goes back to where the computer had it. Any
			# other way in, its turn starts from where the pointer is.
			if not (was == Who.SYSTEM and _has_led):
				_led = point
			_has_led = true
		Who.HAND:
			_has_led = false
			# The hand takes the pointer up where the hand is, the way it does
			# coming out of a menu: all through the computer's turn the system
			# pointer was in sight and going where the mouse took it.
			if was == Who.COMPUTER:
				var vp := get_viewport()
				if vp != null:
					point = on_screen(vp.get_mouse_position(), vp.get_visible_rect().size)

func _input(event: InputEvent) -> void:
	if not _hidden:
		return
	var m := event as InputEventMouseMotion
	if m == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var bounds := vp.get_visible_rect().size
	# At 1.0 the crosshair is put where the hidden pointer is rather than
	# carried by the same movement. Carried, the two part at the first edge that
	# stops the crosshair and not the pointer, and a little at every movement,
	# whose fractions of a point Godot drops.
	if is_equal_approx(sensitivity, 1.0):
		point = on_screen(m.position, bounds)
	else:
		point = carry(point, m.relative, bounds)

## Where the pointer lands after the mouse has been moved `by`: the distance the
## setting asks for, kept on the screen. Pure, so what the pointer does can be
## checked without a hand on a mouse.
func carry(from: Vector2, by: Vector2, bounds: Vector2) -> Vector2:
	return on_screen(from + by * sensitivity, bounds)

## `at`, kept on a screen `bounds` across.
func on_screen(at: Vector2, bounds: Vector2) -> Vector2:
	return Vector2(clampf(at.x, 0.0, maxf(bounds.x - 1.0, 0.0)),
		clampf(at.y, 0.0, maxf(bounds.y - 1.0, 0.0)))

## `at`, moved back to the nearest corner of the grid the picture is on. The
## crosshair's art is drawn at SCALE, so landing between two of the picture's
## pixels puts every art pixel of it across two screen ones — it would be the
## only thing on screen at a finer grain than everything else, which is the one
## thing drawing it at SCALE is for.
##
## Snapping to the screen's own corner is not the same thing and is not enough:
## the picture's grid slides with the camera, and half the time it is on the odd
## screen pixels. That half passed on a desk and split blocks in CI.
func on_grid(at: Vector2) -> Vector2:
	return pixel_origin + ((at - pixel_origin) / float(SCALE)).floor() * SCALE

## Where the game is pointing, in the world `node` stands in — what
## `get_global_mouse_position` answers, asked of the game's pointer instead of
## the system's. The two are the same thing whenever the system is pointing.
func world_point(node: CanvasItem) -> Vector2:
	var vp := node.get_viewport()
	if vp == null:
		return point
	return vp.get_canvas_transform().affine_inverse() * point

## Where the person at the desk is pointing, for what is still theirs to press
## on a screen the game points on: the crosshair while their hand is what moves
## it, and the system pointer the rest of the time — which is every window, and
## any moment the computer has the crosshair.
func hand_point() -> Vector2:
	if _hidden:
		return point
	var vp := get_viewport()
	return vp.get_mouse_position() if vp != null else point

## --- led by the computer ----------------------------------------------------
## Leads the game's pointer to `at` on the screen, kept on it: what the
## computer points with while it has the controls, since the system pointer is
## nobody's to move. It is held to — through a window that covers the
## computer's turn and back out of it — until it is led somewhere else or the
## player's hand takes the pointer up. Returns where it landed.
func lead(at: Vector2) -> Vector2:
	var vp := get_viewport()
	_led = on_screen(at, vp.get_visible_rect().size) if vp != null else at
	_has_led = true
	if who() == Who.COMPUTER:
		point = _led
	return _led

## The same, to a place in the world `node` stands in — what `world_point`
## answers, the other way round. Returns where in that world it landed: the
## place asked for, unless that is off the screen.
func lead_to(node: CanvasItem, at: Vector2) -> Vector2:
	var vp := node.get_viewport()
	if vp == null:
		return at
	var onto := vp.get_canvas_transform()
	return onto.affine_inverse() * lead(onto * at)

func set_sensitivity(v: float) -> void:
	sensitivity = clampf(v, MIN_SENS, MAX_SENS)
	save()

## --- the crosshair ----------------------------------------------------------
## Drawn by the shell rather than by a screen: every screen the player has the
## controls on wants it, and none of them should have to know that.
func _build_crosshair() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_crosshair = TextureRect.new()
	_crosshair.texture = _tex
	_crosshair.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.visible = false
	layer.add_child(_crosshair)

## --- keeping the setting ----------------------------------------------------
func load_saved() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	sensitivity = clampf(float((parsed as Dictionary).get("sensitivity", 1.0)), MIN_SENS, MAX_SENS)

func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"sensitivity": sensitivity}))
	f.close()

## The pointer, drawn. One art pixel of padding all round, so the dark edge has
## somewhere to go on the arms that reach the border of the table.
func texture() -> ImageTexture:
	var w: int = ART[0].length() + 2
	var h: int = ART.size() + 2
	var img := Image.create(w * SCALE, h * SCALE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var col := _cell(x - 1, y - 1)
			if col.a > 0.0:
				_block(img, x, y, col)
	return ImageTexture.create_from_image(img)

## Dead centre, which is where a crosshair points from.
func hotspot() -> Vector2:
	return Vector2(float(ART[0].length() + 2), float(ART.size() + 2)) * SCALE * 0.5

## The colour of one art cell: the body where the table says so, the dark edge
## where it does not but a neighbour does, and nothing anywhere else.
func _cell(x: int, y: int) -> Color:
	if _body(x, y):
		return INK
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if _body(x + dx, y + dy):
				return EDGE
	return Color(0, 0, 0, 0)

func _body(x: int, y: int) -> bool:
	if y < 0 or y >= ART.size() or x < 0 or x >= ART[y].length():
		return false
	return ART[y][x] == "#"

func _block(img: Image, x: int, y: int, col: Color) -> void:
	for j in SCALE:
		for i in SCALE:
			img.set_pixel(x * SCALE + i, y * SCALE + j, col)
