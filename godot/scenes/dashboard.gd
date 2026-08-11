class_name Dashboard
extends Control

# Leaderboard dashboard: the record to beat, the ranked entry list and the
# entry point into a game.
#
# Replaces components/LeaderboardScreen.bs. The per-game entry model is
# unchanged — one row per playthrough, so the same nickname can appear several
# times.

signal play_requested
signal change_nickname_requested

var _record_label: Label
var _list: VBoxContainer
var _empty_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = GameTheme.background_color()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var title := Label.new()
	title.text = "BRICKRAIN"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", GameTheme.accent_color())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_record_label = Label.new()
	_record_label.add_theme_font_size_override("font_size", 22)
	_record_label.add_theme_color_override("font_color", GameTheme.text_color())
	_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_record_label)

	# The list scrolls: the leaderboard holds up to 50 entries.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	_empty_label = Label.new()
	_empty_label.text = "No games yet — play one."
	_empty_label.add_theme_font_size_override("font_size", 18)
	_empty_label.add_theme_color_override("font_color", GameTheme.text_color())
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_empty_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)

	var play := Button.new()
	play.text = "Play"
	play.add_theme_font_size_override("font_size", 24)
	play.custom_minimum_size = Vector2(200, 56)
	play.pressed.connect(func(): play_requested.emit())
	buttons.add_child(play)

	var change := Button.new()
	change.text = "Change Nickname"
	change.add_theme_font_size_override("font_size", 18)
	change.custom_minimum_size = Vector2(200, 56)
	change.pressed.connect(func(): change_nickname_requested.emit())
	buttons.add_child(change)


func refresh(leaderboard_state: Dictionary) -> void:
	for child in _list.get_children():
		child.queue_free()

	var entries: Array = leaderboard_state["entries"]
	_empty_label.visible = entries.is_empty()
	_record_label.text = "Record to beat: %d" % Leaderboard.top_score(leaderboard_state)

	for i in range(entries.size()):
		_list.add_child(_make_row(i + 1, entries[i]))


func _make_row(rank: int, entry: Dictionary) -> Control:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = GameTheme.panel_color()
	style.set_content_margin_all(8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	row.add_theme_stylebox_override("panel", style)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	row.add_child(box)

	box.add_child(_cell("%d." % rank, 60, HORIZONTAL_ALIGNMENT_RIGHT, GameTheme.accent_color()))
	var name_cell := _cell(str(entry["nickname"]), 0, HORIZONTAL_ALIGNMENT_LEFT, GameTheme.text_color())
	name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(name_cell)
	box.add_child(_cell(str(entry["date"]), 120, HORIZONTAL_ALIGNMENT_CENTER, GameTheme.text_color()))
	box.add_child(_cell(str(entry["score"]), 100, HORIZONTAL_ALIGNMENT_RIGHT, GameTheme.text_color()))
	return row


func _cell(text: String, min_width: int, alignment: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.custom_minimum_size = Vector2(min_width, 0)
	return label
