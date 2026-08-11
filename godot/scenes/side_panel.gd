class_name SidePanel
extends PanelContainer

# Score readout, hold slot and next-piece queue.
#
# Mirrors components/SidePanel.bs, but the arrangement is driven by the parent:
# Game lays this out as a column beside the well in landscape and as a strip
# above it in portrait, which is what FR03 needs. Flipping BoxContainer.vertical
# is all that takes.

const PREVIEW_COUNT := 3

var _nickname_label: Label
var _score_label: Label
var _level_label: Label
var _lines_label: Label
var _hold_preview: PiecePreview
var _next_previews: Array[PiecePreview] = []
var _root: BoxContainer
var _stats_box: BoxContainer
var _slots_box: BoxContainer


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = GameTheme.panel_color()
	style.set_content_margin_all(12)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style)
	_build()


func _build() -> void:
	_root = _make_box(true, 12)
	add_child(_root)

	_nickname_label = _make_label("", 22, GameTheme.accent_color())
	_root.add_child(_nickname_label)

	_stats_box = _make_box(true, 6)
	_root.add_child(_stats_box)
	_score_label = _make_label("SCORE\n0", 20, GameTheme.text_color())
	_level_label = _make_label("LEVEL\n1", 20, GameTheme.text_color())
	_lines_label = _make_label("LINES\n0", 20, GameTheme.text_color())
	_stats_box.add_child(_score_label)
	_stats_box.add_child(_level_label)
	_stats_box.add_child(_lines_label)

	# The slot row stays horizontal in both orientations. Stacking four previews
	# vertically makes the panel taller than a short landscape viewport, which
	# pushes the well off the bottom of the screen.
	_slots_box = _make_box(false, 8)
	_root.add_child(_slots_box)
	_slots_box.add_child(_make_label("HOLD", 16, GameTheme.text_color()))
	_hold_preview = _make_preview()
	_slots_box.add_child(_hold_preview)
	_slots_box.add_child(_make_label("NEXT", 16, GameTheme.text_color()))
	for _i in range(PREVIEW_COUNT):
		var preview := _make_preview()
		_slots_box.add_child(preview)
		_next_previews.append(preview)


func _make_box(vertical: bool, separation: int) -> BoxContainer:
	var box := BoxContainer.new()
	box.vertical = vertical
	box.add_theme_constant_override("separation", separation)
	return box


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_preview() -> PiecePreview:
	var preview := PiecePreview.new()
	preview.custom_minimum_size = Vector2(60, 44)
	return preview


# Landscape lays everything out as a tall column; portrait flattens it into a
# wide strip so the well keeps as much vertical space as possible.
func set_portrait(portrait: bool) -> void:
	if _root == null:
		return
	_root.vertical = not portrait
	_stats_box.vertical = not portrait
	_nickname_label.visible = not portrait


func set_nickname(value: String) -> void:
	_nickname_label.text = value


func set_stats(score: int, level: int, lines: int) -> void:
	_score_label.text = "SCORE\n" + str(score)
	_level_label.text = "LEVEL\n" + str(level)
	_lines_label.text = "LINES\n" + str(lines)


func set_hold(piece_type: String) -> void:
	_hold_preview.piece_type = piece_type


func set_next(types: Array) -> void:
	for i in range(_next_previews.size()):
		_next_previews[i].piece_type = str(types[i]) if i < types.size() else ""
