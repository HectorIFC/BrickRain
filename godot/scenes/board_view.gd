class_name BoardView
extends Control

# Renders the playfield with immediate-mode drawing.
#
# The Roku version (components/BoardView.bs) pools 200 Rectangle nodes because
# SceneGraph has no immediate mode. Godot does, so this is a single Control
# that redraws in _draw() - fewer nodes, less bookkeeping, and the geometry can
# be recomputed for any viewport size, which is what FR03 needs.

const COLS := 10
const ROWS := 20

# Preserved from the Roku design space (46 px cell, 2 px gap); only the ratio
# matters here, since the pitch is derived from the available rect.
const GAP_RATIO := 2.0 / 48.0

var board_colors: Array = []
var ghost_cells: Array = []

# Impact shake, driven by GameScreen. Applied as a draw transform so the well
# trembles while the surrounding layout (panel, buttons) stays put.
var shake_offset := Vector2.ZERO:
	set(value):
		shake_offset = value
		queue_redraw()

# The active piece is drawn separately from the settled board so its position
# can be interpolated: it glides to the new cell in under 50 ms instead of
# teleporting. Longer than that and, with DAS repeating every 50 ms, the drawn
# position would lie about where the piece really is.
const SMOOTH_TIME := 0.035
const POP_TIME := 0.04

var _active := {}                    # cells_rel, grid_pos, hidden, color_index
var _active_visible := false
var _active_current := Vector2.ZERO  # smoothed position, in grid units
var _active_target := Vector2.ZERO
var _pop_t := -1.0


# `data` empty hides the piece. snap=true lands instantly (spawn, hard drop);
# pop=true plays the 40 ms scale pop that stands in for rotation tweening -
# genuinely rotating the drawing would be wrong, since SRS kicks translate too.
func set_active(data: Dictionary) -> void:
	if data.is_empty():
		_active_visible = false
		queue_redraw()
		return
	_active = data
	_active_target = data["grid_pos"]
	if data.get("snap", false) or not _active_visible:
		_active_current = _active_target
	if data.get("pop", false):
		_pop_t = 0.0
	_active_visible = true
	queue_redraw()


# Driven each frame by GameScreen rather than a local _process: the game
# screen provably processes in every build, and a single clock also keeps
# the smoothing, the fx overlay and the shake advancing in one order.
func tick(delta: float) -> void:
	var busy := false
	if _active_visible and _active_current != _active_target:
		var k := 1.0 - exp(-delta / SMOOTH_TIME)
		_active_current = _active_current.lerp(_active_target, k)
		if _active_current.distance_to(_active_target) < 0.01:
			_active_current = _active_target
		busy = true
	if _pop_t >= 0.0:
		_pop_t += delta
		if _pop_t > POP_TIME:
			_pop_t = -1.0
		busy = true
	if busy:
		queue_redraw()

var _palette: Array[Color] = GameTheme.cell_colors()
var _empty_color: Color = GameTheme.empty_cell_color()
var _grid_color: Color = GameTheme.grid_line_color()


func _ready() -> void:
	resized.connect(queue_redraw)


# Adopts the flattened visible board plus the ghost projection and repaints.
func set_board(colors: Array, ghosts: Array) -> void:
	board_colors = colors
	ghost_cells = ghosts
	queue_redraw()


# Applies the current level theme (empty-cell + grid colors) so the backdrop
# updates immediately on level-up.
func set_level_theme(level_theme: Dictionary) -> void:
	if level_theme.has("empty"):
		_empty_color = level_theme["empty"]
	if level_theme.has("grid"):
		_grid_color = level_theme["grid"]
	queue_redraw()


# Well geometry for the current control size: the largest 10x20 grid that fits,
# centred. Returned so the caller can align other elements to the same pitch.
func well_metrics() -> Dictionary:
	var pitch := minf(size.x / float(COLS), size.y / float(ROWS))
	var gap := pitch * GAP_RATIO
	var cell := pitch - gap
	var well := Vector2(COLS * pitch - gap, ROWS * pitch - gap)
	var origin := ((size - well) * 0.5).floor()
	return {"pitch": pitch, "cell": cell, "gap": gap, "well": well, "origin": origin}


func _draw() -> void:
	var m := well_metrics()
	var origin: Vector2 = m["origin"]
	var pitch: float = m["pitch"]
	var cell: float = m["cell"]

	if shake_offset != Vector2.ZERO:
		draw_set_transform(shake_offset, 0.0, Vector2.ONE)

	# Grid backdrop: one rect behind the cells, so the gaps read as grid lines.
	draw_rect(Rect2(origin, m["well"]), _grid_color)

	for row in range(ROWS):
		for col in range(COLS):
			var index := 0
			var flat := row * COLS + col
			if flat < board_colors.size():
				index = int(board_colors[flat])
			var color := _empty_color
			if index > 0 and index < _palette.size():
				color = _palette[index]
			draw_rect(
				Rect2(origin + Vector2(col * pitch, row * pitch), Vector2(cell, cell)),
				color
			)

	for ghost in ghost_cells:
		var gx := int(ghost["x"])
		var gy := int(ghost["y"])
		if gx < 0 or gx >= COLS or gy < 0 or gy >= ROWS:
			continue
		draw_rect(
			Rect2(origin + Vector2(gx * pitch, gy * pitch), Vector2(cell, cell)),
			GameTheme.ghost_color()
		)

	if _active_visible and not _active.is_empty():
		var hidden := int(_active["hidden"])
		var color: Color = _palette[clampi(int(_active["color_index"]), 0, _palette.size() - 1)]
		# Rotation pop: cells shrink toward the piece centre and spring back.
		var s := 1.0
		if _pop_t >= 0.0:
			s = lerpf(0.90, 1.0, _pop_t / POP_TIME)
		var cells_rel: Array = _active["cells_rel"]
		var centre := Vector2.ZERO
		for rel in cells_rel:
			centre += Vector2(float(rel["x"]) + 0.5, float(rel["y"]) + 0.5)
		centre /= float(cells_rel.size())
		for rel in cells_rel:
			var gx_f := _active_current.x + float(rel["x"])
			var gy_f := _active_current.y + float(rel["y"]) - float(hidden)
			if gy_f < -0.01:
				continue
			var local := Vector2(float(rel["x"]) + 0.5, float(rel["y"]) + 0.5)
			var scaled := centre + (local - centre) * s
			var at := origin + Vector2(
				(_active_current.x + scaled.x - 0.5) * pitch,
				(_active_current.y + scaled.y - 0.5 - float(hidden)) * pitch
			)
			draw_rect(Rect2(at, Vector2(cell * s, cell * s)), color)
