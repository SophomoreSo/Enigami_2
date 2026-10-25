class_name AimCurve
extends RefCounted

## Aim assist as one function: the way the stick points in, the way the weapon
## points out. After t3ssel8r's "Designing a Better Aim Assist for 2D Games",
## worked from its transcript.
##
## The identity is no assist at all: the weapon points exactly where the stick
## does. Snapping the stick onto a target, the way most games assist it, leaves
## directions nothing can aim at and jumps the weapon whenever the guess is
## wrong. This bends the identity instead, smoothly, so that a target takes up
## more of the stick than it does of the room. Its *virtual size* — the stick
## angles that land on it — is never less than `FLOOR` either side of its
## middle, however small or far off it is: the skill floor. A target already
## that wide is left alone.
##
## Whatever the targets, the curve:
##   * corrects nothing aimed dead at a target's middle;
##   * runs uniformly slower across a target — its slope there is the target's
##     size over its virtual size — so a stick held on it stays on it;
##   * never runs backwards and never jumps: it climbs all the way round, so
##     every direction is one some stick angle points, and the ground a target
##     takes is given back beside it, steeper — never more than about one and a
##     half times `SECANT_MAX`, which is where two targets close together
##     share the ground between them;
##   * is the identity again `MARGIN` past a target's virtual size, so a stick
##     pointed well away from everything is left alone, and nearer than that no
##     correction is ever much more than `FLOOR`. Just past a target's virtual
##     edge the curve is still easing out of that target's slowness, so the
##     aim lingers there a little: smooth, at the price of a correction a
##     fraction of a degree over the floor.
##
## Built the way the devlog suggests: values and slopes pinned at knots — each
## target's virtual edges land on its real edges, at its slope; past its pull,
## the identity at slope one — joined by cubic Hermite pieces, held monotone
## the Fritsch–Carlson way. Then blended with the identity by `strength`, for
## how much of it the player wants.
##
## Two targets in a line fill one wedge of the stick, and nothing the stick can
## do tells them apart, so where two overlap they are one target covering
## both. That one pulls only as hard as they overlap — nothing while they just
## touch, all of it `MERGE_RAMP` later — because two that are about to touch
## have already given up their pull to the gap closing between them, and the
## curve must not jump the moment they meet. So a pair a whisker apart is the
## one thing helped less than either would be alone; it is never helped wrong.

## The least a target's virtual size may be, either side of its middle.
const FLOOR := deg_to_rad(12.0)
## How far past its virtual size a target's pull reaches.
const MARGIN := deg_to_rad(30.0)
## The slowest the stick may run across a target. A tiny target far off would
## otherwise ask for a nearly flat curve, which holds the weapon still while the
## stick moves: a snap by another name.
const SENSITIVITY_MIN := 0.15
## The steepest the curve may climb on average from a target's edge to the next
## thing — the identity, or a neighbour sharing the gap. The ground between two
## targets close together is the least worth aiming at, so it is where the
## stick runs fast.
const SECANT_MAX := 2.5
## How much two targets have to overlap before the one they make pulls fully.
## About what two monsters walking past each other cover in a fifth of a
## second, so the pull comes in about as fast as a fade.
const MERGE_RAMP := deg_to_rad(4.0)
## No real target is narrower than this, or wider.
const HALF_MIN := deg_to_rad(0.25)
const HALF_MAX := deg_to_rad(80.0)
## Two knots closer than this are the same knot.
const EPS := 1e-9

## How much of the bend is used: 0 is the identity, 1 all of it.
var strength: float = 1.0

## One turn of knots: where the stick points, where the weapon points, and how
## fast it turns there. `_x` climbs strictly, and the turn closes on the first
## knot one turn up.
var _x := PackedFloat64Array()
var _y := PackedFloat64Array()
var _m := PackedFloat64Array()

## A curve around `targets`, each a Vector2: the angle to its middle and half
## the angle it fills, in radians.
static func around(targets: Array, how_much: float = 1.0) -> AimCurve:
	var c := AimCurve.new()
	c.strength = clampf(how_much, 0.0, 1.0)
	c._build(targets)
	return c

## Where the weapon points for a stick pointing at `x`, both in radians.
func at(x: float) -> float:
	if _x.is_empty() or strength <= 0.0:
		return x
	return x + strength * (_bent(x) - x)

func _bent(x: float) -> float:
	var n := _x.size()
	var turns := floorf((x - _x[0]) / TAU)
	var u := x - turns * TAU
	var k := clampi(_x.bsearch(u, false) - 1, 0, n - 1)
	var last := k == n - 1
	var x0 := _x[k]
	var y0 := _y[k]
	var m0 := _m[k]
	var x1 := _x[0] + TAU if last else _x[k + 1]
	var y1 := _y[0] + TAU if last else _y[k + 1]
	var m1 := _m[0] if last else _m[k + 1]
	var h := x1 - x0
	var t := (u - x0) / h
	var t2 := t * t
	var t3 := t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * y0 + (t3 - 2.0 * t2 + t) * h * m0 \
		+ (3.0 * t2 - 2.0 * t3) * y1 + (t3 - t2) * h * m1 + turns * TAU

func _build(targets: Array) -> void:
	var ts: Array = []
	for t: Vector2 in targets:
		ts.append(Vector3(fposmod(t.x, TAU), clampf(t.y, HALF_MIN, HALF_MAX), 1.0))
	ts = _merged(ts)
	var n := ts.size()
	# Nothing to aim at — or nothing but, all the way round: the identity.
	if n == 0 or (n == 1 and (ts[0] as Vector3).y >= PI - HALF_MIN):
		return
	# Gap k runs from target k's real edge to target k+1's, the last one round to
	# the first: half its width, and its middle, where the two sides' pulls meet.
	var half_gap := PackedFloat64Array()
	var mid := PackedFloat64Array()
	half_gap.resize(n)
	mid.resize(n)
	for k in n:
		var a: Vector3 = ts[k]
		var b: Vector3 = ts[(k + 1) % n]
		var b_at := b.x + (TAU if k == n - 1 else 0.0)
		var g := maxf(0.0, (b_at - b.y) - (a.x + a.y)) * 0.5
		half_gap[k] = g
		mid[k] = a.x + a.y + g
	# How much wider each is to the stick than to the eye: up to the floor, as
	# far as its pull allows, and no further than either half-gap beside it can
	# give back at `SECANT_MAX`.
	var give := 1.0 - 1.0 / SECANT_MAX
	var v := PackedFloat64Array()
	v.resize(n)
	for k in n:
		var t: Vector3 = ts[k]
		var want := (minf(maxf(t.y, FLOOR), t.y / SENSITIVITY_MIN) - t.y) * t.z
		var room := minf(MARGIN * (SECANT_MAX - 1.0), minf(half_gap[(k - 1 + n) % n], half_gap[k]) * give)
		v[k] = t.y + clampf(want, 0.0, room)
	var first: float = maxf((ts[0] as Vector3).x - v[0] - MARGIN, mid[n - 1] - TAU)
	_knot(first, first, 1.0)
	for k in n:
		var t: Vector3 = ts[k]
		var slope := t.y / v[k]
		_knot(t.x - v[k], t.x - t.y, slope)
		_knot(t.x + v[k], t.x + t.y, slope)
		var right := minf(t.x + v[k] + MARGIN, mid[k])
		_knot(right, right, 1.0)
		if k < n - 1:
			var left := maxf((ts[k + 1] as Vector3).x - v[k + 1] - MARGIN, mid[k])
			_knot(left, left, 1.0)
	# A last knot that has come all the way round is the first one.
	while _x.size() > 1 and _x[_x.size() - 1] >= _x[0] + TAU - EPS:
		_x.resize(_x.size() - 1)
		_y.resize(_y.size() - 1)
		_m.resize(_m.size() - 1)
	_keep_climbing()

func _knot(x: float, y: float, slope: float) -> void:
	if not _x.is_empty() and x <= _x[_x.size() - 1] + EPS:
		return
	_x.append(x)
	_y.append(y)
	_m.append(slope)

## Fritsch–Carlson: a piece whose slopes are too steep for the climb between
## its ends has them brought down until it cannot overshoot. The knots above
## are placed so that this never has anything to do; it is here so that a
## change to them can never make the curve run backwards.
func _keep_climbing() -> void:
	var n := _x.size()
	for k in n:
		var j := (k + 1) % n
		var rise := (_y[j] + (TAU if j == 0 else 0.0)) - _y[k]
		var run := (_x[j] + (TAU if j == 0 else 0.0)) - _x[k]
		var d := rise / run
		if d <= 0.0:
			_m[k] = 0.0
			_m[j] = 0.0
			continue
		var a := _m[k] / d
		var b := _m[j] / d
		var r := a * a + b * b
		if r > 9.0:
			var tau := 3.0 / sqrt(r)
			_m[k] = tau * a * d
			_m[j] = tau * b * d

## Targets whose real extents touch or overlap, as one covering both, pulling
## as hard as they overlap (see the top of this file). Each is a Vector3: its
## middle in [0, TAU), its half-size, and how hard it pulls, 0 to 1.
static func _merged(ts: Array) -> Array:
	var by_angle := func(a: Vector3, b: Vector3) -> bool: return a.x < b.x
	ts.sort_custom(by_angle)
	var again := true
	while again and ts.size() > 1:
		again = false
		var n := ts.size()
		for k in n:
			var j := (k + 1) % n
			var a: Vector3 = ts[k]
			var b: Vector3 = ts[j]
			var b_at := b.x + (TAU if j == 0 else 0.0)
			var overlap := (a.x + a.y) - (b_at - b.y)
			if overlap < 0.0:
				continue
			var lo := minf(a.x - a.y, b_at - b.y)
			var hi := maxf(a.x + a.y, b_at + b.y)
			var ramp := minf(MERGE_RAMP, 2.0 * minf(a.y, b.y))
			var pull := minf(minf(a.z, b.z), clampf(overlap / ramp, 0.0, 1.0))
			var kept: Array = []
			for i in n:
				if i != k and i != j:
					kept.append(ts[i])
			kept.append(Vector3(fposmod((lo + hi) * 0.5, TAU), minf((hi - lo) * 0.5, PI), pull))
			kept.sort_custom(by_angle)
			ts = kept
			again = true
			break
	return ts
