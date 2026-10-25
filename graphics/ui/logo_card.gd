class_name LogoCard
extends Control

## What the game opens on, on every machine: one of the studio's logos, picked
## at random from the pool each time the game starts and held on white for a
## moment. Then the logo goes into the white, and the white into the title
## underneath — two steps rather than one, because faded together the black
## logo would ghost over the title, and the logo's own box of white would fade
## as a second sheet over the first and show as a lighter patch.
##
## The white is in front of it too. The engine boots onto it
## (`application/boot_splash/bg_color`), and an iPhone's launch screen is white
## with nothing on it — `graphics/assets/launch_paper.png` on PAPER, in the iOS
## export preset — since a launch screen cannot be picked: iOS shows one picture
## before a line of the game has run, baked into the app when it is exported and
## kept by the system after that. From the moment the game is opened to the
## logo, it is one sheet of white.
##
## The pool is every PNG in POOL, so a logo dropped there is one more the game
## may open on. A press of anything — a tap, a click, a key — goes straight to
## the fade, and nothing pressed while the card is up reaches the title under it.

## Where the logos are. Every PNG here is one the game may open on.
const POOL := "res://graphics/assets/logos/"
## What the card is, edge to edge — and the boot and the launch screen in front
## of it, which `tests/graphics/logo_card_test` holds to the same colour.
const PAPER := Color.WHITE
## How much brighter a logo is drawn than its file. The logos were saved on an
## off-white a shade under white, grainy the way a scan is, which on white would
## show as a faint warm box. Drawn this much brighter, all of that comes out
## white — every edge of them included — and their black, which no brightening
## lifts, stays as black as it was. The test holds every logo in the pool to it.
const LIFT := 1.0 / 0.965
## How long the logo is held, how long it takes to go into its paper, and how
## long the paper then takes to go into the title: about a second in all, half
## what it was, each step halved so the card goes the way it did, only sooner.
const HOLD := 0.7
const LOGO_OUT := 0.15
const FADE := 0.2
## The most of the screen a logo may take, across and down.
const FIT := Vector2(0.7, 0.6)

## The logo on the card: one from the pool, unless whoever made the card chose.
var logo: Texture2D = null
## Seconds since it came up. Past HOLD the logo is going; past HOLD + LOGO_OUT
## the paper is; past all three the card is gone.
var _t: float = 0.0

## Whether `shell` opens on the card: the game as launched — the main scene —
## on any machine. A game built inside a test goes straight to work, as it
## always has, with no card swallowing what the test presses.
static func wanted(shell: Node) -> bool:
	return shell.is_inside_tree() and shell.get_tree().current_scene == shell

## Every logo in the pool, by path. Listed through the resource loader rather
## than the file system, which in an exported game holds the imported copies
## and not the PNGs.
static func pool() -> PackedStringArray:
	var out := PackedStringArray()
	for f in ResourceLoader.list_directory(POOL):
		if f.get_extension().to_lower() == "png":
			out.append(POOL + f)
	return out

## One logo from the pool, by `rng`, or "" when the pool is empty.
static func pick(rng: RandomNumberGenerator) -> String:
	var all := pool()
	if all.is_empty():
		return ""
	return all[rng.randi_range(0, all.size() - 1)]

func _ready() -> void:
	UiKit.fill_screen(self)
	# Over the title, which is built under it in the same frame, and taking every
	# pointer that lands on it.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# A drawing, not pixel art: it is scaled smoothly to the screen.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if logo == null:
		# Its own generator, so the card never draws from the numbers the game
		# is using.
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var path := pick(rng)
		if path != "":
			logo = load(path) as Texture2D
	if logo == null:
		queue_free()   # nothing in the pool: the game opens on its title

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	_t += delta
	if _t >= HOLD + LOGO_OUT + FADE:
		queue_free()
		return
	queue_redraw()

## Whether the card is still holding the logo, rather than going.
func holding() -> bool:
	return _t < HOLD

## How much of the logo is on the paper: all of it while it is held, none once
## it has gone into it.
func logo_alpha() -> float:
	return 1.0 - clampf((_t - HOLD) / LOGO_OUT, 0.0, 1.0)

## How much of the paper is over the title: all of it until the logo has gone.
func paper_alpha() -> float:
	return 1.0 - clampf((_t - HOLD - LOGO_OUT) / FADE, 0.0, 1.0)

## Everything pressed while it is up is the card's own: a press goes straight to
## the fade, and neither the press nor its letting go reaches the title.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton
			or event is InputEventScreenTouch or event is InputEventJoypadButton
			or event is InputEventAction):
		return
	get_viewport().set_input_as_handled()
	if event.is_pressed() and not event.is_echo():
		_t = maxf(_t, HOLD)

## One layer going at a time: the logo over white that is all there, then the
## white by itself.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(PAPER, paper_alpha()))
	var a := logo_alpha()
	if logo == null or a <= 0.0:
		return
	var fit := minf(size.x * FIT.x / float(logo.get_width()), size.y * FIT.y / float(logo.get_height()))
	var drawn := logo.get_size() * fit
	draw_texture_rect(logo, Rect2(((size - drawn) * 0.5).round(), drawn), false, Color(LIFT, LIFT, LIFT, a))
