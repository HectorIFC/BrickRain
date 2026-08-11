class_name PiecePreview
extends Control

# Draws a single tetromino centred in its rect, used for the hold slot and the
# next-piece queue. An empty piece_type draws just the empty slot backdrop.

const GAP_RATIO := 2.0 / 48.0

var piece_type := "":
	set(value):
		if piece_type != value:
			piece_type = value
			queue_redraw()

var slot_color: Color = GameTheme.panel_color()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), slot_color)
	if piece_type == "":
		return

	var cells := Piece.cells_for(piece_type, 0)
	if cells.is_empty():
		return

	# Tight bounds, so a 4-wide I and a 2-wide O both fill the slot evenly.
	var min_x := 99
	var max_x := -99
	var min_y := 99
	var max_y := -99
	for cell in cells:
		min_x = mini(min_x, int(cell["x"]))
		max_x = maxi(max_x, int(cell["x"]))
		min_y = mini(min_y, int(cell["y"]))
		max_y = maxi(max_y, int(cell["y"]))
	var span_x := max_x - min_x + 1
	var span_y := max_y - min_y + 1

	var inset := size * 0.15
	var avail := size - inset * 2.0
	var pitch := minf(avail.x / float(span_x), avail.y / float(span_y))
	var gap := pitch * GAP_RATIO
	var cell_size := pitch - gap
	var block := Vector2(span_x * pitch - gap, span_y * pitch - gap)
	var origin := ((size - block) * 0.5).floor()

	var color: Color = GameTheme.cell_colors()[Piece.type_index(piece_type)]
	for cell in cells:
		var px := (int(cell["x"]) - min_x) * pitch
		var py := (int(cell["y"]) - min_y) * pitch
		draw_rect(Rect2(origin + Vector2(px, py), Vector2(cell_size, cell_size)), color)
