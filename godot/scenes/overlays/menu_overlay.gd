class_name MenuOverlay
extends Control

# Modal overlay with a title, optional detail lines and a vertical option list.
#
# The Roku build has two near-identical overlay components (PauseOverlay and
# GameOverOverlay) because SceneGraph offers no cheap way to share one; here a
# single configurable overlay covers both, and Game supplies the content.
#
# Emits selection(id) with the id of the chosen option.

signal selection(id: String)

var _title: Label
var _detail: Label
var _buttons_box: VBoxContainer
var _option_ids: Array[String] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = GameTheme.panel_color()
	style.set_content_margin_all(28)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_color = GameTheme.accent_color()
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", GameTheme.accent_color())
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_detail = Label.new()
	_detail.add_theme_font_size_override("font_size", 20)
	_detail.add_theme_color_override("font_color", GameTheme.text_color())
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_detail)

	_buttons_box = VBoxContainer.new()
	_buttons_box.add_theme_constant_override("separation", 10)
	column.add_child(_buttons_box)


# options is an array of { id, label } dictionaries, shown top to bottom.
func configure(title: String, detail: String, options: Array) -> void:
	_title.text = title
	_detail.text = detail
	_detail.visible = detail != ""

	for child in _buttons_box.get_children():
		child.queue_free()
	_option_ids.clear()

	for option in options:
		var id := str(option["id"])
		var button := Button.new()
		button.text = str(option["label"])
		button.add_theme_font_size_override("font_size", 22)
		button.custom_minimum_size = Vector2(260, 52)
		button.pressed.connect(_on_pressed.bind(id))
		_buttons_box.add_child(button)
		_option_ids.append(id)


# Focuses the first option so keyboard users can act without reaching for the
# mouse; touch users just tap.
func focus_first() -> void:
	if _buttons_box.get_child_count() > 0:
		(_buttons_box.get_child(0) as Button).grab_focus()


func _on_pressed(id: String) -> void:
	selection.emit(id)
