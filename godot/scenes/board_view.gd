class_name BoardView
extends Control

# Renders the playfield with immediate-mode drawing.
#
# The Roku version (components/BoardView.bs) pools 200 Rectangle nodes because
# SceneGraph has no immediate mode. Godot does, so this is a single Control
# that redraws in _draw() — fewer nodes, less bookkeeping, and the geometry can
# be recomputed for any viewport size, which is what FR03 needs.

const COLS := 10
const ROWS := 20

# Preserved from the Roku design space (46 px cell, 2 px gap); only the ratio
# matters here, since the pitch is derived from the available rect.
const GAP_RATIO := 2.0 / 48.0

var board_colors: Array = []
var ghost_cells: Array = []

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
