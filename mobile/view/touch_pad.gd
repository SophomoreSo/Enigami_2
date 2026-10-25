class_name TouchPad
extends Control

## The console the game draws on the glass: a thumbstick under the left thumb,
## and under the right a stick that charges and casts the weapon's graph, one
## that swings it plain, and the keys that take no direction.
##
## Laid out the way a phone MOBA is, because that is the scheme this game's
## controls actually fit:
##
##   * **The left thumb is a stick, and there is nothing there until it moves.**
##     The left of the screen is empty; a thumb put down anywhere in it and
##     dragged grows the stick where it landed, and lifting takes it away again.
##     A thumb that only touches grows nothing. So it is never somewhere to
##     reach for and never in the way of the fight. It has to be dragged a
##     long way before it does anything, and its ring is the line between the
##     two things it can then do. Inside the ring, three quarters of the way
##     out (`STICK_RUN`), it walks — any of the eight ways and every way
##     between, the way the thumb points. Dragged far out of the ring it means
##     it: it sprints that way (`STICK_SPRINT`) — as far past the ring again as
##     the ring is from its middle, the knob following the thumb out and
##     standing clear of the ring by then, so a sprint is nothing a thumb does
##     by leaning. Each step is all or nothing, so none starts under a thumb
##     that only drifted; and each is marked where it is — the walk on the
##     ring, the sprint on the line the knob has to get out to — and lights
##     (`_draw_reach`).
##   * **The cast button is a stick too.** Press it and the graph begins to
##     charge; drag and the charge aims; let go and it casts, where you were
##     pointing, with everything the hold paid for. The game's own
##     hold-to-charge is what a phone MOBA already asks a thumb to do — press,
##     drag, release — so the two are the same gesture and nothing had to be
##     invented. The weapon key is the same stick without the charge: the same
##     graph, cast as it is for as long as the thumb is down.
##     A press with no drag in it goes the way the left stick is pushing, or
##     the way the player faces. A drag aims it, measured from where the thumb
##     came down rather than from the button's middle, and how far it is
##     dragged is how far the attack goes: a bolt's range, a lunge, a throw
##     (`Player.aim_reach`). Let go, the cast keeps that aim until it has gone
##     off, whatever the left thumb does meanwhile.
##   * **HIT is USE when there is something to use.** The weapon's button turns
##     into the interact key while the player stands by an NPC, a station or
##     an exit (`use_near`, which the shell sets). A thumb already down keeps
##     what it pressed until it lifts, so walking into range mid-swing does
##     not turn a swing into a press. One button fewer under the right thumb,
##     and the two are never wanted in the same place: you do not hit what
##     you are talking to.
##   * **In a conversation the whole screen is the page, and it is not drawn.**
##     A tap anywhere is interact, as F is at a desk: it brings the line coming
##     in out whole, or, with the line out, goes on to the next. A button to
##     find for every line is the wrong thing to ask of a thumb that is reading.
##     The answers are not the console's: the box puts each on a plate of its
##     own, tapped to give it, and while they are up the glass is the box's —
##     a tap anywhere else gives nothing (`DialogueBox`).
##   * **Everything else is a key.** Dash and the three screens take no
##     direction, so they are buttons and nothing more — and so is the
##     key that puts the next weapon in hand, which stands beside the screens
##     for as long as more than one weapon is carried, and the one that steps
##     out of a monster, beside that, for as long as the player is in one.
##
## Drawn rather than built, in UiKit's pixel look — `PixelDraw`, Silkscreen at
## its own size, whole blocks — so a phone is playing the same game a desk is.
## The sticks are round because a stick is round; `PixelDraw.disc` and `ring`
## rasterise a circle on the grid rather than drawing a smooth one.
##
## What a press does to the game is not decided here. A control says which
## actions it is holding and `Touch` (`mobile/input/touch.gd`) sends them, so this file
## knows nothing about charging and the player knows nothing about thumbs.
##
## **Where the controls sit is the whole design.** It is written out once, in
## the 1280x720 the game is laid out in, and checked against the HUD rather than
## guessed at: the HUD owns the top-left corner down to y=112 and the band along
## the bottom from y=592, so the hand sits between them.
##
## The screen is that size or bigger. `expand` stretch gives a display longer
## than 16:9 more width and a squarer one more height, and a thumb reaches no
## further on a longer phone, so nothing is scaled: each control keeps its
## distance from the corner it belongs to (`pin`, and `area`). The hand stays
## under the right thumb at the bottom-right, the three screens in the top-right
## corner, and the stick's zone down the left edge to the HUD's band, however
## far away the other side of the screen has gone.
## `tests/mobile/touch_pad_test` holds it all there, at 16:9 and off it.
##
## **The buttons are twice the size they were first drawn at**, their words and
## edges with them: on a phone's glass a cast button was smaller than the thumb
## pressing it. Doubled, the hand fills the room the HUD leaves it — CAST just
## under the three screens, DASH just over HIT, which sits where the thumb
## rests — so the gaps between them are about the least the test allows, and
## moving one means checking its neighbours. The movement stick kept its size:
## it is not a button, and is only ever drawn under a thumb that is already
## moving it.

## What a control is.
##
##   KEY   a button. Pressed while a thumb is on it, and nothing more.
##   MOVE  the movement stick. It has a zone rather than a place: it is drawn
##         nowhere until a thumb lands somewhere in that zone and drags, grows
##         where it landed, and is gone again the moment the thumb lifts.
##   AIM   a button that is also a stick. It holds its action the whole time and
##         the drag off it is where the cast goes.
enum Kind { KEY, MOVE, AIM }

## Which controls are on the screen. The shell picks it — `Game._touch_face` —
## since which of these the player is standing in is the shell's question and
## not the picture's.
##
##   PLAY    somebody has the controls: everything.
##   TALK    a conversation or a scene has them: the page, which is the whole
##           of the screen.
##   SCREEN  a screen has them — the map, a station's panel. Only the keys that
##           close it again, or a phone would have no way out of a window it
##           opened.
##   CLEAR   the assembly board has them, and the whole glass with them.
##           Nothing: the board is touched itself and has its own CLOSE, right
##           where KIT, MAP and MENU would stand over it. The pad stays up, so
##           what the board calls a control is still its word on the glass. A
##           station's panel in the hideout is the same: a page nearly the
##           width of the screen, with its own ways out, under where the three
##           keys would stand.
enum Face { NONE, PLAY, TALK, SCREEN, CLEAR }

## Every control: what it presses, where it sits in the 1280x720 design, which
## corner of the screen it keeps to, and which faces it appears on.
##
## A `pin` is that corner, as how much of the screen's room past the design the
## control moves by, across and down: (1, 1) rides with the bottom-right corner
## and (1, 0) with the top-right. The stick's zone keeps the top-left and has a
## `grow` instead, so it runs down to the HUD's band however tall the screen is.
##
## A round control carries `at` and `radius`; the three screens carry a `rect`
## instead, because they are labelled plates rather than things a thumb rests
## on, and looking different is how they say so. A `throw` stick is one whose
## release is a cast: it keeps the aim it was let go with until that cast has
## gone off.
const CONTROLS := [
	# The stick. It has no place of its own — only a `zone` a thumb may summon
	# it anywhere inside, which is the whole left of the screen under the
	# health bars. That is the point of it: the hand goes
	# where it likes and the stick comes to the hand.
	{"kind": Kind.MOVE, "radius": 78.0, "knob": 30.0,
		"zone": Rect2(0, 120, 456, 472), "grow": Vector2(0, 1), "faces": [Face.PLAY]},
	# The cast stick, above the hand. Press to charge, drag to aim, let go to
	# cast.
	{"kind": Kind.AIM, "action": "cast_skill", "throw": true,
		"at": Vector2(1052, 184), "pin": Vector2(1, 1), "radius": 64.0,
		"faces": [Face.PLAY]},
	# The hand. DASH takes no direction; the weapon does, so it is a stick —
	# and it is the USE key too, `alt`, wherever there is something to use.
	# HIT is the biggest and sits where the thumb rests.
	{"kind": Kind.KEY, "action": "dash", "at": Vector2(1188, 324), "pin": Vector2(1, 1),
		"radius": 68.0, "faces": [Face.PLAY]},
	{"kind": Kind.AIM, "action": "attack", "alt": "interact", "at": Vector2(1164, 496),
		"pin": Vector2(1, 1), "radius": 92.0, "faces": [Face.PLAY]},
	# The page, in a conversation: the whole of the screen, invisible. A `zone`
	# on a key is a tap area, drawn nowhere and never moved. A tap is interact:
	# the line coming in out whole, or the next one. It lies over the HUD's
	# corner and its band, which no other control may: the HUD has stepped
	# aside for the conversation (`Hud.talking`).
	{"kind": Kind.KEY, "action": "interact", "zone": Rect2(0, 0, 1280, 720),
		"grow": Vector2(1, 1), "faces": [Face.TALK]},
	# Out of the monster the player is in, under the weapon key: a plate as
	# well, and only there while the player is in one (`possess`). Not beside
	# the screens: the strip between them and the HUD is left for a player to
	# put buttons in.
	{"kind": Kind.KEY, "action": "step_out", "rect": Rect2(696, 128, 128, 88),
		"pin": Vector2(1, 0), "faces": [Face.PLAY], "possess": true},
	# The next weapon in hand, beside the screens: a plate like theirs, since it
	# takes no direction and is not a thing a thumb rests on, and only there
	# while more than one weapon is carried (`kit`).
	{"kind": Kind.KEY, "action": "weapon_next", "rect": Rect2(696, 24, 128, 88),
		"pin": Vector2(1, 0), "faces": [Face.PLAY], "kit": true},
	# Magic on and off, under the screens: a plate, since it takes no direction,
	# and out of the way of the hand, since a press of it changes the world.
	{"kind": Kind.KEY, "action": "magic_toggle", "rect": Rect2(840, 128, 128, 88),
		"pin": Vector2(1, 0), "faces": [Face.PLAY]},
	# The phone, under it: a plate like the screens', since it is one more
	# thing that comes up over the world — and under rather than beside,
	# since beside is where the cast stick's thumb lands.
	{"kind": Kind.KEY, "action": "open_phone", "rect": Rect2(840, 232, 128, 88),
		"pin": Vector2(1, 0), "faces": [Face.PLAY]},
	# The screens, in the far corner where nothing is reached for by accident.
	{"kind": Kind.KEY, "action": "open_editor", "rect": Rect2(840, 24, 128, 88),
		"pin": Vector2(1, 0), "faces": [Face.PLAY, Face.SCREEN]},
	{"kind": Kind.KEY, "action": "open_map", "rect": Rect2(984, 24, 128, 88),
		"pin": Vector2(1, 0), "faces": [Face.PLAY, Face.SCREEN]},
	{"kind": Kind.KEY, "action": "pause", "rect": Rect2(1128, 24, 128, 88),
		"pin": Vector2(1, 0), "faces": [Face.PLAY, Face.SCREEN]},
]

## The 1280x720 the controls are written out in. See `area`.
const DESIGN := Vector2(1280, 720)

## How far a thumb rides out from the cast button before the cast has a
## direction of its own, and how far out the knob is drawn. Generous, because a
## short throw makes a fine aim impossible — the ring is drawn over whatever is
## beside it, which costs nothing for the moment it is up. Doubled with the
## buttons: the throw is measured from a button's middle, and half the button's
## radius is what lets a thumb that lands off-centre still tap rather than aim.
const AIM_DEAD := 32.0
const AIM_REACH := 184.0
const AIM_KNOB := 44.0

## How long a throw let go of waits for its cast to start before giving up on
## it — the rules take the release in a physics tick that can come after this
## frame, and a cast the weapon refuses never starts — and the longest it is
## held at all.
const THROW_START_WAIT := 0.25
const THROW_HOLD_MAX := 5.0

## A button's edge, and the size its word is written at: twice the PIXEL and
## the face's own size, like the buttons. The face is clean at any multiple of
## its size, so the words are as sharp as the menus' are.
const EDGE_W := PixelDraw.PX * 2
const LABEL_SIZE := PixelDraw.SIZE * 2

## How far the movement stick must be pushed before it points anywhere: past
## this a weapon nobody is aiming goes the way the stick does (`aim`). It
## moves nobody — that is STICK_RUN and STICK_SPRINT, below.
const STICK_DEAD := 0.22


## How far a thumb has to move from where it landed before the movement stick
## comes out under it. A thumb that only touches the glass grows nothing and
## moves nobody: the stick is for going somewhere, and a ring flashing up under
## every tap on the left of the screen was a stick nobody had asked for. About a
## phone's own touch slop, so the tremor of a thumb coming down is not a drag;
## and short of STICK_DEAD's reach, so the stick is always on the screen before
## it moves anybody.
const STICK_OUT := 12.0

## How far the movement stick has to be dragged before it does anything, as a
## share of the way to its ring — and the ring is the line between the two
## things it can do.
##
## Inside the ring, three quarters of the way out, it walks: the player's
## ordinary walk, whole from the moment it starts, the way the thumb points,
## and nothing short of it, so it never starts under a thumb that has only
## just come down. Dragged far out of the ring — as far past it again as the
## ring is from its middle, by when the whole knob is outside it and clear of
## it — it means it: it sprints that way. Nothing nearer is: a walk leant on a
## little harder is still a walk.
##
## That is where the glass has the room. Where it has not, the sprint is as far
## out as a thumb can get — see `gate`.
const STICK_RUN := 0.75
const STICK_SPRINT := 2.0
## As far as the stick follows a thumb: half a radius past the sprint. The
## thumb may go on further, and the stick is still its; the knob stops here.
const STICK_FAR := 2.5
## How near the edge of the glass a sprint is ever asked for. A thumb cannot be
## asked for the last of the glass, so the line it has to reach is never
## nearer the edge than this.
const STICK_EDGE := 24.0
## How much nearer than a threshold a thumb may come back before what it
## reached there is let go of, so one resting on the line does not flicker
## between a walk and a sprint.
const STICK_SLACK := 0.06
## How much of the ring each of its marks covers, either side of dead ahead —
## and how much of a turn the line out past it covers, which out there is a
## little wider than the knob, so the line still shows round a knob that has
## reached it.
const STICK_MARK := deg_to_rad(40.0)
const STICK_LINE := deg_to_rad(15.0)

## How far outside its edge a control still answers.
const SLOP := 4.0

## The mouse, as a finger. A desk has one pointer and no index to tell it by.
const MOUSE := -1

const FILL := Color(0.05, 0.06, 0.09, 0.55)
const FILL_HELD := Color(0.16, 0.34, 0.44, 0.82)
## The stick's knob once it has been dragged far enough to do something.
const FILL_REACHED := Color(0.3, 0.62, 0.74, 0.92)
const EDGE := Color(0.45, 0.85, 1.0, 0.38)
const EDGE_HELD := Color(0.6, 0.95, 1.0, 0.95)
const INK := Color(0.74, 0.84, 0.95, 0.8)
const INK_HELD := Color(1, 1, 1, 1)
## A button that cannot do anything right now, quieted: still there and still
## pressing, it just says so beforehand. The arrangement screen draws a button
## it will not accept this way; nothing on the pad itself is like that today.
const EDGE_OFF := Color(0.85, 0.42, 0.44, 0.34)
const INK_OFF := Color(0.82, 0.5, 0.52, 0.55)
## The ring a skill aims in, and the pips that walk out to the knob.
const AIM_EDGE := Color(0.55, 0.92, 1.0, 0.5)

## Which controls are up. Set by the shell every frame; changing it lets go of
## everything, so a key that was being held when the screen changed does not
## stay down behind the screen that replaced it.
## Whether USE would do something where the player stands. Set by the shell
## every frame, like `face`; a control with an `alt` presses that instead of
## its action while this holds, and says so on its face.
var use_near: bool = false
## How many weapons the player is carrying. Set by the shell every frame, like
## `face`: the key that puts the next one in hand is on the glass only while
## there is a next one.
var kit: int = 1
## Whether the player's hands are in a monster. Set by the shell every frame:
## the key that steps out of it is on the glass only while they are.
var possessing: bool = false
## The controls whose `alt` a thumb is holding down, by index: what a thumb
## pressed is what it lets go of, whatever the ground under it does meanwhile.
var _alt_held: Dictionary = {}
var face: int = Face.NONE:
	set(value):
		if value == face:
			return
		face = value
		_let_go()

## Finger (or MOUSE) -> the index into CONTROLS it is resting on.
var _down: Dictionary = {}
## Where the thumb that summoned the movement stick landed, where the ring is
## drawn, and how far it is pushed: a unit long at the ring, and as much as
## STICK_FAR out of it. All meaningless while no thumb is on it: see
## `stick_showing`.
##
## The two places are usually the same one and are not always: a thumb landing
## within a radius of the edge of the zone would draw a ring half off the screen
## or over the health bars, so the ring slides in to fit. **The push is measured
## from where the thumb landed either way**, or a stick summoned in the corner
## would read as shoved the moment it appeared, and the player would walk off
## without having asked to.
var _stick_from: Vector2 = Vector2.ZERO
var _stick_at: Vector2 = Vector2.ZERO
var _stick: Vector2 = Vector2.ZERO
## Whether the thumb on the stick has dragged far enough to bring it out. Until
## it has, nothing is drawn and nothing is pushed: see STICK_OUT.
var _stick_out: bool = false
## The cast or weapon stick being aimed, where the thumb on it came down, and
## how far it has dragged from there. Measured from the landing rather than the
## button's middle: a button this big is rarely hit in the middle, and a tap off
## to one side of it is still a tap, not a throw that way.
var _aim_from: int = -1
var _aim_start: Vector2 = Vector2.ZERO
var _aim_off: Vector2 = Vector2.ZERO
## A cast thrown and let go: the aim it was let go with, and how long ago. The
## thumb that aims it is the thumb that casts it, so the stick would drop back
## to the left thumb's aim in the very moment of the cast — and while a cast's
## first attack goes off at once, everything the board does after that plays
## out in real time: a second branch, one held back by a longer walk. It is
## held up until the cast has gone off (`Player.casting`) — see `_keep_throw`.
var _held_throw: Dictionary = {}
## Fingers that were down when the face changed under them, until they lift.
## What a thumb was doing belonged to the face it did it on. The one that tapped
## the last line of a conversation away is still down as the conversation ends,
## and the one that pressed USE is still down as it opens; dragged, either would
## otherwise take whatever the new face has under it — HIT, or the page, where
## it would turn past the first line unread.
var _spent: Dictionary = {}
## Every finger on the glass now, on a control or not: what a change of face
## spends. A thumb resting between the buttons is as down as one on them, and
## the page a conversation brings up is the whole screen — it would be under it.
var _touching: Dictionary = {}
## Whoever is being played, read once a frame rather than once per control:
## the pad asks questions of them while it draws, and walking the tree for
## each would be a walk a frame apiece.
var _player: Player = null
## Whether this machine has ever reported a finger. The system turns a touch
## into a mouse click as well as reporting the touch, and answering both would
## press every control twice; once there are fingers the mouse is one of them.
var _fingers: bool = false
var _px := PixelDraw.new(self)

func _ready() -> void:
	# Kept running while the tree is stopped, so the pad can take itself off the
	# screen — and let go of what it was holding — when the game pauses.
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.fill_screen(self)
	# Answered in `_input`, which sees a press whether or not a Control under
	# the cursor would have: nothing here is a button in the GUI's sense.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

## Handed back on the way out: a pad freed while it was up would leave the mouse
## in its drawer and an action pressed, with nothing left to release either.
func _exit_tree() -> void:
	if visible:
		visible = false
		Touch.set_up(false)

func _process(delta: float) -> void:
	UiKit.sync_screen(self)
	var up: bool = Touch.wanted() and face != Face.NONE and not get_tree().paused
	if up != visible:
		visible = up
		if not up:
			# Every thumb lifted by the game rather than by its owner: what each
			# was doing ends here — a stick pushed, a key held — and a lift the
			# pad cannot see while it is away is not waited for.
			_let_go()
			_spent.clear()
			_touching.clear()
		# `Touch` puts the mouse away while the pad has the screen and lets go
		# of every key when it leaves. Told here because this is the only thing
		# that knows whether the pad is on the screen.
		Touch.set_up(up)
	if not up:
		return
	_player = _find_player()
	_drive()
	_keep_throw(delta)
	Touch.aim(aim())
	queue_redraw()

## --- what the sticks say ----------------------------------------------------

## The movement stick, as the four actions the game reads movement through,
## which it reads together as one way on the floor (`Hands`, `Input.get_vector`).
##
## The walk is all or nothing: once the stick has been dragged past STICK_RUN
## the four keys are held as the way the thumb points — each as much of the
## way as lies along it, so the four together are that way, whole — and not
## at all short of it. Far out of the ring (STICK_SPRINT, as far as `gate`
## says) it sprints, which is one more key held with the walk's.
func _drive() -> void:
	var walking := _past("move", _stick.length(), STICK_RUN)
	var way := _stick.normalized() if walking > 0.0 else Vector2.ZERO
	_lean("move_right", maxf(way.x, 0.0))
	_lean("move_left", maxf(-way.x, 0.0))
	_lean("move_down", maxf(way.y, 0.0))
	_lean("move_up", maxf(-way.y, 0.0))
	_lean("sprint", _past("sprint", _stick.length(), gate(_stick)) if walking > 0.0 else 0.0)

## How far the stick has to be dragged toward `way` before it sprints, as a
## share of the way to its ring.
##
## STICK_SPRINT, wherever the glass has that much room past where the thumb
## landed the way it is going. It does not always: a thumb put down near the
## left edge has nowhere to drag left to, and one low on the screen has little
## below it. Asked for the whole distance there, it could never sprint that
## way. So there the line is as far out as a thumb can still get — STICK_EDGE
## short of the edge of the glass that way — and never nearer than the ring
## itself, so a sprint is always further out than a walk. A thumb nearer the
## edge than that has not the room for one that way, and has to land again.
func gate(way: Vector2) -> float:
	if way == Vector2.ZERO:
		return STICK_SPRINT
	var screen := _screen()
	var d := way.normalized()
	# How far the thumb can go that way before it is at an edge.
	var room := INF
	if d.x > 0.001:
		room = minf(room, (screen.x - _stick_from.x) / d.x)
	elif d.x < -0.001:
		room = minf(room, _stick_from.x / -d.x)
	if d.y > 0.001:
		room = minf(room, (screen.y - _stick_from.y) / d.y)
	elif d.y < -0.001:
		room = minf(room, _stick_from.y / -d.y)
	return clampf((room - STICK_EDGE) / float(CONTROLS[0]["radius"]), 1.0, STICK_SPRINT)

## Holds `action` as hard as `amount`, 0 to 1, and lets go of it at nothing.
func _lean(action: String, amount: float) -> void:
	if amount <= 0.0:
		Touch.release(action)
		return
	Touch.press(action, clampf(amount, 0.0, 1.0))

## Where the player is pointing, as a stick: the cast being aimed if one is —
## or one thrown and let go whose cast has not gone off yet — the movement stick
## if it is pushed, and the way they are facing otherwise. A throw is pushed as far as the thumb dragged (`throw_reach`),
## which the game reads as how far the attack goes; everything else asks for
## all of it.
##
## A pointer is the one control a phone cannot offer — there is nothing on the
## glass until a finger lands, and where it lands is where it is going. So the
## pad aims the way a gamepad does, through the same right stick, which the game
## already understood — how hard the stick is pushed included (`Player.aim_reach`).
##
## The cast being aimed wins, which is the whole of the scheme: a thumb can run
## right and throw a cast up and to the left in the same moment. Facing is the
## last resort, so a tap with no throw in it still goes somewhere the player
## meant — forwards, where they are walking.
func aim() -> Vector2:
	if _aim_from >= 0 and _aim_off.length() >= AIM_DEAD:
		return _aim_off.normalized() * Player.push_for(throw_reach())
	if not _held_throw.is_empty():
		return _held_throw["aim"]
	if _stick.length() >= STICK_DEAD:
		return _stick.normalized()
	return _facing()

## All of a push that has got past `threshold`, and none of one that has not.
## One already holding `action` goes on holding it a little short of that
## (STICK_SLACK); the walk is held while any of its four keys is.
func _past(action: String, amount: float, threshold: float) -> float:
	var holding := Touch.holding(action)
	if action == "move":
		for key in ["move_left", "move_right", "move_up", "move_down"]:
			holding = holding or Touch.holding(key)
	var need := threshold - (STICK_SLACK if holding else 0.0)
	return 1.0 if amount >= need else 0.0

## How far the thumb on the stick being aimed has dragged, as how far the
## attack should go: nothing at the edge of the dead zone, all of it at the ring.
func throw_reach() -> float:
	return clampf(inverse_lerp(AIM_DEAD, AIM_REACH, _aim_off.length()), 0.0, 1.0)

## Lets a thrown cast's aim go the moment it has gone off — once the rules
## have been seen casting it and have stopped — or once another stick is taken
## up (`_take`).
func _keep_throw(delta: float) -> void:
	if _held_throw.is_empty():
		return
	var t := float(_held_throw["t"]) + delta
	_held_throw["t"] = t
	var going := _player != null and _player.casting()
	if going:
		_held_throw["started"] = true
	var started := bool(_held_throw["started"])
	if (started and not going) or (not started and t > THROW_START_WAIT) or t > THROW_HOLD_MAX:
		_held_throw = {}


## The way the player faces on the floor, as the stick would say it.
func _facing() -> Vector2:
	return Vector2.RIGHT if _player == null else _player.facing

func _find_player() -> Player:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player:
			return p as Player
	return null

## --- fingers ----------------------------------------------------------------

## Handled here rather than in `_gui_input` for two reasons: the GUI hands one
## pointer to one Control, and the pad needs two thumbs at once; and a press
## that lands on a control is marked handled so it reaches nothing behind it.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		_saw_a_finger(touch.index)
		# Coming down or lifting, a touch ends whatever the finger was before
		# it: a spent thumb is spent until this — see `_spent`.
		_spent.erase(touch.index)
		if touch.pressed:
			_touching[touch.index] = true
		else:
			_touching.erase(touch.index)
		_finger(touch.index, touch.position, touch.pressed)
		return
	var drag := event as InputEventScreenDrag
	if drag != null:
		_saw_a_finger(drag.index)
		if not _spent.has(drag.index):
			_finger(drag.index, drag.position, true)
		return
	if _fingers:
		return          # the mouse under a finger is that finger again
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		_finger(MOUSE, click.position, click.pressed)
		return
	var moved := event as InputEventMouseMotion
	if moved != null and _down.has(MOUSE):
		_finger(MOUSE, moved.position, true)

## The first finger this machine has ever reported.
##
## The system turns a touch into a click as well, and hands over the click
## first, so the first finger of all lands on its control twice: once as itself
## and once as a mouse that is not there. The phantom would then never lift —
## every mouse event after this one is ignored — and a control something is
## still holding is one the finger that really lifted cannot let go of.
##
## So the control is handed over rather than let go of. Releasing it and pressing
## it again would be a release inside the same frame as the press, and on a
## skill stick a release is a cast.
func _saw_a_finger(index: int) -> void:
	if _fingers:
		return
	_fingers = true
	if _down.has(MOUSE):
		_down[index] = _down[MOUSE]
		_down.erase(MOUSE)

## One finger: where it is now, and whether it is still down.
func _finger(index: int, at: Vector2, pressed: bool) -> void:
	var was: int = _down.get(index, -1)
	# A stick keeps the finger that started it, however far out it is dragged —
	# that is what makes it a stick rather than a button you slid off. So does
	# a zone, which has no edge anybody can see to slide off: a thumb on the
	# page is on it wherever it wanders. A key lets go the moment the thumb
	# leaves it, and may take the next key along.
	if pressed and was >= 0 and _keeps(was):
		if _is_stick(was):
			_drag(was, at)
		get_viewport().set_input_as_handled()
		return
	var now: int = _under(at) if pressed else -1
	if now == was:
		if now >= 0:
			get_viewport().set_input_as_handled()
		return
	if now < 0:
		_down.erase(index)
	else:
		_down[index] = now
	# Let go first, then take: a second thumb already on what is being left
	# keeps it down, and what is being taken up is never released by this one.
	if was >= 0:
		_drop(was)
	if now >= 0:
		_take(now, at)
	if now >= 0 or was >= 0:
		get_viewport().set_input_as_handled()

func _is_stick(i: int) -> bool:
	return int(CONTROLS[i]["kind"]) != Kind.KEY

## Whether a thumb on `i` keeps it until it lifts, however far it drags.
func _keeps(i: int) -> bool:
	return _is_stick(i) or CONTROLS[i].has("zone")


## A thumb has landed on `i`.
func _take(i: int, at: Vector2) -> void:
	var c: Dictionary = CONTROLS[i]
	match int(c["kind"]):
		Kind.MOVE:
			# Where the stick will grow, once the thumb drags — see STICK_OUT.
			# The ring slides in where it must to stay on the screen; what the
			# thumb is asking for is measured from the thumb regardless — see
			# `_stick_from`.
			var r: float = c["radius"]
			var zone := area(c, _screen())
			_stick_from = at
			_stick_at = Vector2(
				clampf(at.x, zone.position.x + r, zone.end.x - r),
				clampf(at.y, zone.position.y + r, zone.end.y - r))
			_stick = Vector2.ZERO
			_stick_out = false
			return          # a stick makes no click; a thumb resting is not a press
		Kind.AIM:
			if uses(c):
				# A key for as long as it is held: no aim, no throw.
				_alt_held[i] = true
				Touch.press(String(c["alt"]))
				Audio.play("ui")
				return
			Touch.press(String(c["action"]))
			_aim_from = i
			_aim_start = at
			_aim_off = Vector2.ZERO
			# A new aim is a new question: a throw still being held for a cast
			# that has not gone off yet gives way to it.
			_held_throw = {}
		_:
			Touch.press(String(c["action"]))
	Audio.play("ui")

## The thumb on `i` has gone. Called after the finger has been taken out of
## `_down`, so what is left there is what is still being held.
func _drop(i: int) -> void:
	var c: Dictionary = CONTROLS[i]
	match int(c["kind"]):
		Kind.MOVE:
			_stick = Vector2.ZERO
			_stick_at = Vector2.ZERO
			_stick_from = Vector2.ZERO
			_stick_out = false
			_drive()
		Kind.AIM:
			if _alt_held.has(i):
				_alt_held.erase(i)
				_let_go_of(String(c["alt"]))
				return
			# A cast thrown somewhere keeps being aimed there after the thumb
			# lifts, until the cast the lift asked for has gone off.
			if _aim_from == i and bool(c.get("throw", false)) and _aim_off.length() >= AIM_DEAD:
				_held_throw = {"aim": aim(), "t": 0.0, "started": false}
			_let_go_of(String(c["action"]))
			if _aim_from == i:
				_aim_from = -1
				_aim_off = Vector2.ZERO
		_:
			_let_go_of(String(c["action"]))

## The thumb on `i` has moved to `at`.
func _drag(i: int, at: Vector2) -> void:
	var c: Dictionary = CONTROLS[i]
	if int(c["kind"]) == Kind.MOVE:
		var off := at - _stick_from
		# Out once the thumb has gone somewhere, and pushed from then on only,
		# so the stick is on the screen before it moves anybody.
		_stick_out = _stick_out or off.length() >= STICK_OUT
		if _stick_out:
			# A unit long at the ring, and on out of it as far as STICK_FAR:
			# going far out of the ring is what a sprint is.
			_stick = (off / float(c["radius"])).limit_length(STICK_FAR)
	elif not _alt_held.has(i):
		_aim_from = i
		_aim_off = at - _aim_start

## Lets go of `action` unless some other finger is still holding it: two
## thumbs can be down at once, and HIT's USE and the page both press interact.
func _let_go_of(action: String) -> void:
	for f in _down:
		if _pressing(f) == action:
			return
	Touch.release(action)

## What the thumb `f` is holding down: its control's action, or the `alt` it
## pressed instead.
func _pressing(f: int) -> String:
	var i := int(_down[f])
	var c: Dictionary = CONTROLS[i]
	return String(c.get("alt", "")) if _alt_held.has(i) else String(c.get("action", ""))

## The control under `at`, or -1. Only what is on the face that is up answers: a
## thumb where HIT sits during a conversation presses nothing. The stick is
## asked last, so its zone never takes a press meant for a button inside it.
func _under(at: Vector2) -> int:
	var screen := _screen()
	var arranged := layout()
	var stick := -1
	for i in CONTROLS.size():
		var c: Dictionary = placed(CONTROLS[i], arranged)
		if not shown(c):
			continue
		if c.has("zone"):
			# A zone is asked last, so it never takes a press meant for a button in it.
			if area(c, screen).has_point(at):
				stick = i
		elif c.has("rect"):
			if area(c, screen).grow(SLOP).has_point(at):
				return i
		elif at.distance_to(middle(c, screen)) <= float(c["radius"]) + SLOP:
			return i
	return stick

func _let_go() -> void:
	# The thumbs down now are done with until they lift — see `_spent` — on a
	# control or not. Not the mouse: what it drags is only ever what it is
	# holding, and once it is holding nothing its drag is nobody's.
	for f in _touching:
		_spent[f] = true
	_down.clear()
	_stick = Vector2.ZERO
	_stick_at = Vector2.ZERO
	_stick_from = Vector2.ZERO
	_stick_out = false
	_aim_from = -1
	_aim_start = Vector2.ZERO
	_aim_off = Vector2.ZERO
	_held_throw = {}
	_alt_held.clear()
	Touch.release_all()

## --- the picture ------------------------------------------------------------

## Whether the movement stick is on the screen at all: a thumb is on it, and has
## dragged since it landed. There is nothing drawn where it waits, because it
## does not wait anywhere — see `_draw_stick`.
func stick_showing() -> bool:
	if not _stick_out:
		return false
	for f in _down.values():
		if int(CONTROLS[int(f)]["kind"]) == Kind.MOVE:
			return true
	return false

## Whether `c` is on the screen: on the face that is up — and, for the key
## that changes weapon, with another weapon to change to, and for the one that
## steps out of a monster, with the player in one.
func shown(c: Dictionary) -> bool:
	if bool(c.get("kit", false)) and kit < 2:
		return false
	if bool(c.get("possess", false)) and not possessing:
		return false
	return (c["faces"] as Array).has(face)

## The room a screen of `screen` has past the design, in whole PIXELs, so what
## moves by it stays on the grid everything here is drawn to.
static func spare(screen: Vector2) -> Vector2:
	return ((screen - DESIGN).max(Vector2.ZERO) / PixelDraw.PX).floor() * PixelDraw.PX

## Where a round control's middle is on a screen of `screen`. Kept on it: the
## design's own buttons always are, but one the player put near an edge of a
## long phone could hang off a squarer screen's.
static func middle(c: Dictionary, screen: Vector2 = DESIGN) -> Vector2:
	var at := Vector2(c["at"]) + spare(screen) * Vector2(c.get("pin", Vector2.ZERO))
	var r := Vector2.ONE * float(c["radius"])
	return at.clamp(r, (screen - r).max(r))

## The square of screen a control covers on a screen of `screen`, for anything
## that has to know it does not cover something else — and for the pad, asking
## which one a thumb came down on.
static func area(c: Dictionary, screen: Vector2 = DESIGN) -> Rect2:
	var moved := spare(screen) * Vector2(c.get("pin", Vector2.ZERO))
	if c.has("rect"):
		var plate: Rect2 = c["rect"]
		var corner := (plate.position + moved).clamp(Vector2.ZERO,
			(screen - plate.size).max(Vector2.ZERO))
		return Rect2(corner, plate.size)
	if c.has("zone"):
		var zone: Rect2 = c["zone"]
		return Rect2(zone.position + moved,
			zone.size + spare(screen) * Vector2(c.get("grow", Vector2.ZERO)))
	var r: float = c["radius"]
	return Rect2(middle(c, screen) - Vector2.ONE * r, Vector2.ONE * r * 2.0)

## --- where the player has put them ------------------------------------------

## Where the player has moved the buttons to, on the screen behind SET BUTTON
## POSITIONS (`TouchLayoutEditor`): by `key_of`, a place in the design and the
## corner it keeps its distance from, as CONTROLS' own `at` and `pin` are — a
## plate's place being its top-left corner. A button nobody has moved is not in
## it, and stands where CONTROLS writes it.
##
## Kept per machine, in a file of its own like mobile mode and the bindings:
## where a thumb falls is a matter of the hand and the glass, not of the save.
const LAYOUT_PATH := "user://enigami_touch_layout.json"
static var _layout: Dictionary = {}
static var _layout_read := false

## The arrangement in force, read off the disk the first time it is asked for.
static func layout() -> Dictionary:
	if not _layout_read:
		_layout_read = true
		_layout = _read_layout()
	return _layout

## Puts `l` in force and keeps it on the disk — or, with `keep` false, only
## puts it in force: a test does that, so a desk's own arrangement is neither
## in its way nor lost to it.
static func set_layout(l: Dictionary, keep: bool = true) -> void:
	_layout = l.duplicate(true)
	_layout_read = true
	if keep:
		var out := {}
		for key in _layout:
			var e: Dictionary = _layout[key]
			out[key] = {"at": [e["at"].x, e["at"].y], "pin": [e["pin"].x, e["pin"].y]}
		var f := FileAccess.open(LAYOUT_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(out))
			f.close()

static func _read_layout() -> Dictionary:
	if not FileAccess.file_exists(LAYOUT_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	if not (parsed is Dictionary):
		return {}
	var out := {}
	for key in parsed:
		var e = parsed[key]
		if not (e is Dictionary and e.get("at") is Array and e.get("pin") is Array):
			continue
		var at: Array = e["at"]
		var pin: Array = e["pin"]
		if at.size() == 2 and pin.size() == 2:
			out[String(key)] = {"at": Vector2(float(at[0]), float(at[1])),
				"pin": Vector2(float(pin[0]), float(pin[1]))}
	return out

## What a control is called in an arrangement: its action.
static func key_of(c: Dictionary) -> String:
	return String(c.get("action", "move"))

## Whether the player may move `c`. Every button may; the stick's zone may not,
## being the left of the screen rather than a thing standing on it.
static func movable(c: Dictionary) -> bool:
	return not c.has("zone")

## `c` where the arrangement `l` has it, or as CONTROLS writes it if `l` does
## not mention it.
static func placed(c: Dictionary, l: Dictionary) -> Dictionary:
	var key := key_of(c)
	if not movable(c) or not l.has(key):
		return c
	var e: Dictionary = l[key]
	var out := c.duplicate()
	out["pin"] = e["pin"]
	if c.has("rect"):
		out["rect"] = Rect2(e["at"], (c["rect"] as Rect2).size)
	else:
		out["at"] = e["at"]
	return out

## The screen the pad is laid out on: the viewport, whatever shape it has.
func _screen() -> Vector2:
	return get_viewport_rect().size

## What is written on a control: the word `controls.pad` gives its action —
## the same word the HUD prints through `Controls.short_label_for`, so a key
## and everything that tells the player to press it say the same thing. The
## stick says nothing; it is a stick. With `use`, a control that has an `alt`
## says that instead — HIT reads USE.
static func label_of(c: Dictionary, use: bool = false) -> String:
	if c.has("zone"):
		return ""
	if use and c.has("alt"):
		return Controls.word_for(String(c["alt"]))
	return Controls.word_for(String(c["action"]))

## Whether a press on `c` right now would be its `alt`: something to use is in
## reach. A thumb already on it is asked `_alt_held` instead — see `_take`.
func uses(c: Dictionary) -> bool:
	return c.has("alt") and use_near

func _draw() -> void:
	var screen := _screen()
	var arranged := layout()
	for i in CONTROLS.size():
		var c: Dictionary = CONTROLS[i]
		if not shown(c):
			continue
		match int(c["kind"]):
			Kind.MOVE:
				if stick_showing():
					_draw_stick(c)
			_:
				if c.has("zone"):
					continue   # a tap area has no picture
				# What the thumb on it is holding, or what a thumb would press.
				var as_use := _alt_held.has(i) if _held(c) else uses(c)
				paint_button(_px, placed(c, arranged), screen, _held(c), true, as_use)
	# The throw is drawn last and over everything, since it reaches across
	# whatever is beside the button it came from.
	if _aim_from >= 0 and _aim_off.length() >= AIM_DEAD:
		_draw_throw(CONTROLS[_aim_from])

func _held(c: Dictionary) -> bool:
	for f in _down.values():
		if CONTROLS[int(f)] == c:
			return true
	return false

## The movement stick: the ring it swings in, and the knob inside it — drawn
## only once a thumb on it has dragged, and only where that thumb landed.
## Nothing is drawn while none is, which is the whole of the design: an empty
## left half is a left half you can see the fight through, and a stick that
## grows under the thumb is never a stick anybody has to find first.
func _draw_stick(c: Dictionary) -> void:
	var r: float = c["radius"]
	var knob: float = c["knob"]
	_px.disc(_stick_at, r, FILL)
	_px.ring(_stick_at, r, PixelDraw.PX, EDGE_HELD)
	var reached := _draw_reach(r)
	var at := knob_at(r, knob)
	_px.disc(at, knob, FILL_REACHED if reached else FILL_HELD)
	_px.ring(at, knob, PixelDraw.PX * 2, INK_HELD if reached else EDGE_HELD)

## Where the knob is, for a ring of `r` and a knob of `knob`. Inside the ring it
## is scaled, so that its edge comes to the ring just as the thumb does; from
## there it goes out with the thumb, a pixel for a pixel, its leading edge as
## far out as the thumb has got — so it comes up to a line out there
## (`_draw_reach`) just as the thumb gets as far as the line asks.
func knob_at(r: float, knob: float) -> Vector2:
	var far := _stick.length()
	if far <= 1.0:
		return _stick_at + _stick * (r - knob)
	return _stick_at + _stick / far * ((r - knob) + (far - 1.0) * r)

## What the stick can do, marked where it does it, and lit as the thumb gets
## there. Quiet until then, so the marks say where to drag.
##
## The walk is on the ring: a stretch of it each of the four ways, which
## lights once the stick is walking that way. The sprint is far out past it:
## a short line the way the thumb points, where the knob has to get out to
## (`gate`), on a dark ground of its own so it shows against whatever the fight
## is doing behind it. The line goes white once the knob has reached it. The
## knob lights with any of them. Read off what the stick is holding rather
## than worked out again, so the marks never say more than the game was told.
## Whether anything has been reached.
func _draw_reach(r: float) -> bool:
	var any := false
	for mark in [[Vector2.RIGHT, "move_right"], [Vector2.LEFT, "move_left"],
			[Vector2.UP, "move_up"], [Vector2.DOWN, "move_down"]]:
		var way: Vector2 = mark[0]
		var reached := Touch.holding(String(mark[1]))
		any = any or reached
		_px.arc(_stick_at, r - PixelDraw.PX * 2, PixelDraw.PX * 2, way.angle(), STICK_MARK,
			EDGE_HELD if reached else EDGE)
	if _stick.length() >= STICK_DEAD:
		var out := Touch.holding("sprint")
		any = any or out
		# The line's inner edge is where the knob's leading edge has to get to.
		# Its ground is a block wider all round, except over the ring, which a
		# line brought in to the ring by the edge of the glass sits on.
		var line := r * gate(_stick)
		var thick := PixelDraw.PX * (3.0 if out else 2.0)
		var ground := maxf(line - PixelDraw.PX, r)
		_px.arc(_stick_at, line + thick + PixelDraw.PX, line + thick + PixelDraw.PX - ground, _stick.angle(),
			STICK_LINE, FILL)
		_px.arc(_stick_at, line + thick, thick, _stick.angle(), STICK_LINE, INK_HELD if out else EDGE)
	return any

## A button, round or plated, with its word in the middle of it, drawn with `px`
## on a screen of `screen` — by the pad, and by the screen that arranges it.
static func paint_button(px: PixelDraw, c: Dictionary, screen: Vector2, held: bool, live: bool,
		use: bool = false) -> void:
	var ink := INK_HELD if held else (INK if live else INK_OFF)
	var edge := EDGE_HELD if held else (EDGE if live else EDGE_OFF)
	# Capitals stand 10 high at the face's own size and nothing descends, so at
	# LABEL_SIZE a baseline this far below the middle puts a word in the middle
	# of its button.
	var drop := 5.0 * float(LABEL_SIZE) / float(PixelDraw.SIZE)
	if c.has("rect"):
		var r := area(c, screen)
		px.rect(r, FILL_HELD if held else FILL)
		# EDGE_W across: a frame is one PIXEL, so the second goes inside it.
		px.frame(r, edge)
		px.frame(r.grow(-PixelDraw.PX), edge)
		px.text_centered(r.position + Vector2(0, r.size.y * 0.5 + drop),
			label_of(c, use), ink, r.size.x, LABEL_SIZE)
		return
	var at := middle(c, screen)
	var radius: float = c["radius"]
	px.disc(at, radius, FILL_HELD if held else FILL)
	px.ring(at, radius, EDGE_W, edge)
	px.text_centered(at - Vector2(radius, -drop), label_of(c, use), ink, radius * 2.0, LABEL_SIZE)


## Where a held cast is pointing, and how far it will go: the ring is as far as
## it can, and the knob sits where the thumb has it — the distance this one
## goes, as a share of that — with a few pips walking out to it. Big enough to
## read out of the corner of an eye during a fight, which is the only time it
## is ever up.
func _draw_throw(c: Dictionary) -> void:
	var at := middle(placed(c, layout()), _screen())
	var d := _aim_off.normalized()
	var out := minf(_aim_off.length(), AIM_REACH)
	_px.ring(at, AIM_REACH, EDGE_W, AIM_EDGE)
	var r := float(c["radius"])
	if out > r:
		var step := (out - r) / 4.0
		for i in 3:
			_px.disc(at + d * (r + step * float(i + 1)), 14.0, AIM_EDGE)
	var knob := at + d * out
	_px.disc(knob, AIM_KNOB, FILL_HELD)
	_px.ring(knob, AIM_KNOB, EDGE_W * 2, EDGE_HELD)
