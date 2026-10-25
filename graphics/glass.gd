class_name Glass
extends Node2D

## Glass, somewhere in the world: panes of it, each a rectangle, all of one
## kind. CLEAR glass shows what is behind it, a little tinted. A MIRROR shows
## what is in front of it, turned over across the face where it meets the air:
## under a floor of it, whatever stands on the floor, upside down; beside a
## wall of it, whatever stands beside the wall, turned round. A BACK_MIRROR
## faces the eye, hung behind what it shows — on the back wall — and shows
## whatever stands in front of it, `shift` off from where it stands: a mirror
## hung a little out of true, since one hung true would show each thing right
## behind the thing itself, where nobody could see it.
##
## It draws nothing into the picture itself. What it shows is worked out
## afterwards, once for the whole picture, by the pixel camera's glazing
## (`Glazing`), and what is drawn here goes into the glazing's marks and
## nowhere else (`Glazing.LAYER`): which pixels are glass, of which kind, and
## for a mirror, the way from each to what it shows (`glass.gdshader`). How a
## pane looks round its edge — a frame, the light along it — is for whatever
## put it there to draw, the way a tileset draws a glass block's frame. Put it
## in front of what it should show through and behind what should stand in
## front of it: whatever is drawn over a pane afterwards is in front of it,
## and is neither seen through it nor shown in it.
##
## Like a lamp it is only ever a picture. Nothing in `feature/` knows the
## glass is there.
##
## A mirror pane says where the faces are that it shows the world across: for
## each way — up, down, left, right — how far past its own edge that way the
## face lies, in pixels of the buffer, or NONE for no face that way. A pixel of
## the pane shows the world across the nearest of them, so a pane in the
## middle of a block of mirror shows what is in front of whichever face of the
## block is nearest it. A back mirror shows the whole picture across nothing:
## what is in front of it is whatever is drawn over it, wherever that is.

## The group every pane of glass in the tree is in, which is how the glazing
## finds it.
const GROUP := &"glass"
enum Kind { CLEAR, MIRROR, BACK_MIRROR }
## No face that way.
const NONE := -1.0

var kind: Kind = Kind.CLEAR
## For a back mirror: how far off what stands in front of it it shows it, in
## pixels of the buffer, across and down.
var shift: Vector2i = Glazing.BACK_SHIFT
## Every pane: [the rectangle it covers in this node's space, its faces].
var _panes: Array = []
var _bounds := Rect2()

## Glass of `of_kind`, with no pane in it yet.
static func of(of_kind: Kind) -> Glass:
	var glass := Glass.new()
	glass.kind = of_kind
	return glass

func _enter_tree() -> void:
	add_to_group(GROUP)

func _ready() -> void:
	visibility_layer = Glazing.LAYER
	material = Glazing.wear(kind)

## A pane over `rect`, in this node's space and world units, on whole pixels of
## the buffer. For a mirror, `faces` is how far past each of its edges — up,
## down, left, right — the face it shows the world across lies, in pixels of
## the buffer; NONE where there is none.
func pane(rect: Rect2, faces: Vector4 = Vector4(NONE, NONE, NONE, NONE)) -> void:
	_bounds = rect if _panes.is_empty() else _bounds.merge(rect)
	_panes.append([rect, faces])
	queue_redraw()

## Every pane gone.
func clear() -> void:
	_panes.clear()
	_bounds = Rect2()
	queue_redraw()

func panes() -> int:
	return _panes.size()

## What its panes cover, in the world.
func covers() -> Rect2:
	return get_global_transform() * _bounds

## Every pane as a quad whose UV is the pixel of the pane, from its top-left,
## and whose colour is its faces: up and left as they are, down and right
## measured from the pane's first row and column — so the shader needs nothing
## but the pixel it is on to know how far it is from each. A back mirror's
## colour is instead the way from each of its pixels to what it shows there:
## its shift, turned round.
func _draw() -> void:
	var px := float(Glazing.S)
	for p: Array in _panes:
		var r: Rect2 = p[0]
		var f: Vector4 = p[1]
		var w := r.size.x / px
		var h := r.size.y / px
		var faces := Color(f.x, f.y + h - 1.0 if f.y >= 0.0 else NONE, f.z, f.w + w - 1.0 if f.w >= 0.0 else NONE)
		if kind == Kind.BACK_MIRROR:
			faces = Color(-shift.x, -shift.y, 0.0, 0.0)
		draw_primitive(
			PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([faces, faces, faces, faces]),
			PackedVector2Array([Vector2.ZERO, Vector2(w, 0.0), Vector2(w, h), Vector2(0.0, h)]))
