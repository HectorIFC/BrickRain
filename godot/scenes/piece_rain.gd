class_name PieceRain
extends Control

# Slow, translucent tetrominoes drifting down behind the dashboard content.
#
# The dashboard was a static list with nothing moving on it. This gives the
# screen some life without competing with it: the pieces are dim, slow and
# strictly decorative, and the node ignores the mouse so it can never intercept
# a click meant for the ranking or the buttons.
#
# Shapes and colours come from the game itself (Piece.cells_for,
# GameTheme.cell_colors), so the decoration cannot drift from the palette the
# player sees while playing.

const COUNT := 16
const CELL := 30.0
const GAP := 3.0
const MIN_SPEED := 22.0
const MAX_SPEED := 55.0
const MIN_SPIN := -0.5
const MAX_SPIN := 0.5
const ALPHA := 0.17

var _drops: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fixed seed: the backdrop looks the same on every visit, which reads as
	# designed rather than random noise.
	_rng.seed = 20260813
	resized.connect(_reseed)
	_reseed()


func _reseed() -> void:
	_drops.clear()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var types := Piece.types()
	for i in range(COUNT):
		_drops.append({
			"type": types[_rng.randi_range(0, types.size() - 1)],
			"x": _rng.randf_range(0.0, size.x),
			# Spread the starting heights so they do not arrive in a wave.
			"y": _rng.randf_range(-size.y, size.y),
			"speed": _rng.randf_range(MIN_SPEED, MAX_SPEED),
			"angle": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(MIN_SPIN, MAX_SPIN),
		})


func _process(delta: float) -> void:
	if _drops.is_empty():
		return
	var span := CELL * 4.0
	for drop in _drops:
		drop["y"] += drop["speed"] * delta
		drop["angle"] += drop["spin"] * delta
		if drop["y"] > size.y + span:
			# Wrap to just above the top and pick a fresh column, so the same
			# piece does not fall down the same line forever.
			drop["y"] = -span
			drop["x"] = _rng.randf_range(0.0, size.x)
	queue_redraw()


func _draw() -> void:
	var palette := GameTheme.cell_colors()
	for drop in _drops:
		var cells := Piece.cells_for(drop["type"], 0)
		if cells.is_empty():
			continue
		var color: Color = palette[Piece.type_index(drop["type"])]
		color.a = ALPHA
		# Rotate about the piece's own centre rather than its corner.
		var pitch := CELL + GAP
		var centre := Vector2(2.0, 1.0) * pitch * 0.5
		draw_set_transform(Vector2(drop["x"], drop["y"]), drop["angle"], Vector2.ONE)
		for cell in cells:
			var at := Vector2(int(cell["x"]) * pitch, int(cell["y"]) * pitch) - centre
			draw_rect(Rect2(at, Vector2(CELL, CELL)), color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
