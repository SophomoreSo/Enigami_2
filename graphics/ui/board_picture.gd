class_name BoardPicture
extends SkillEditor

## A board drawn the way the assembly screen draws one — each part in its
## colours with its icon, the wiring lit where the flow runs, faults marked and
## the way out bobbing — and nothing else: no parts to pick from, no top, no
## hand, nothing a press does. The monster dictionary shows a monster's skill
## this way (`MonsterDex`), so a skill reads as the graph it is, one the player
## could build — and, as on the assembly screen, a part under the pointer says
## what it is and does on a card hung off it. The page it stands on says where
## the pointer is (`point_at`), since nothing here takes input.
##
## It is the assembly screen with its drawing kept and its layout and its input
## taken away: `fit` is all the layout there is, the rect the board and its
## frame stand in, in the screen's own coordinates. Its cells are as big as fit
## there, an odd number of PIXELs as the assembly screen's are.

## Where the board and its frame stand.
var fit := Rect2()
## Where it stood when its wiring was last worked out: the outline is kept in
## the screen's coordinates, and goes stale when the board moves.
var _fit_laid := Rect2()

func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE

## The board to draw: nothing to spend, nothing running it.
func show_board(b: SkillBoard) -> void:
	configure(b, {}, true, null)

## The pointer is at `pos`, in the screen's coordinates: the part under it is
## the one the card is about, or none, off the board.
func point_at(pos: Vector2) -> void:
	_clear_hover()
	_mouse_pos = pos
	var b := current_board()
	if b == null or not visible:
		return
	var rel := pos - board_origin()
	if rel.x < 0.0 or rel.y < 0.0:
		return
	var c := Vector2i(int(rel.x / cell_size()), int(rel.y / cell_size()))
	if b.in_bounds(c):
		_hover_cell = c

func _grid() -> Vector2:
	var b := current_board()
	return Vector2(b.width, b.height) if b != null else Vector2(7, 5)

func cell_size() -> float:
	if _drawing:
		return _drawn_cell
	var g := _grid()
	return maxf(_odd_down(minf((fit.size.x - 20.0) / g.x, (fit.size.y - 20.0) / g.y)), float(PX))

func board_origin() -> Vector2:
	if _drawing:
		return _drawn_origin
	var across := _grid() * cell_size() + Vector2(20, 20)
	return _px.snap(fit.position + (fit.size - across) * 0.5) + Vector2(10, 10)

func _board_frame() -> Rect2:
	return Rect2(board_origin() - Vector2(10, 10), _grid() * cell_size() + Vector2(20, 20))

## The way out bobs its whole way: there are no parts beside it to come short of.
func _way_out_bob(_room: float) -> float:
	return super._way_out_bob(float(PX * (WAY_OUT_BOB + 2)))

func _draw() -> void:
	if current_board() == null or fit.size.x <= 0.0 or fit.size.y <= 0.0:
		return
	_drawing = false
	_drawn_cell = cell_size()
	_drawn_origin = board_origin()
	_drawing = true
	if fit != _fit_laid:
		_fit_laid = fit
		_sim_dirty = true
	_draw_board()
	# What the part under the pointer is and does, on the assembly screen's card.
	_draw_hint(get_viewport_rect().size)
	_drawing = false

## Nothing is pressed here, and no key is taken from the page it stands on.
func _gui_input(_event: InputEvent) -> void:
	pass

func _input(_event: InputEvent) -> void:
	pass
