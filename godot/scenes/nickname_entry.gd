class_name NicknameEntry
extends Control

# Nickname prompt.
#
# Replaces components/NicknameDialog.bs. The Roku build ships a custom
# on-screen keyboard only because brs-engine lacks StandardKeyboardDialog;
# that constraint does not apply here, so this is a LineEdit plus the platform
# virtual keyboard on touch devices.
#
# Validation is Leaderboard.validate_nickname, unchanged — the same rules the
# Roku channel enforces.
#
# Under Facebook's Zero Permissions model the SDK no longer exposes the
# player's name, which is exactly why this prompt is required rather than
# optional.

signal submitted(nickname: String)

var _edit: LineEdit
var _error: Label
var _submit: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = GameTheme.background_color()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)

	var title := Label.new()
	title.text = "BRICKRAIN"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", GameTheme.accent_color())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var prompt := Label.new()
	prompt.text = "Enter your nickname"
	prompt.add_theme_font_size_override("font_size", 20)
	prompt.add_theme_color_override("font_color", GameTheme.text_color())
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(prompt)

	_edit = LineEdit.new()
	_edit.custom_minimum_size = Vector2(320, 56)
	_edit.max_length = 12
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit.add_theme_font_size_override("font_size", 24)
	_edit.text_submitted.connect(_on_text_submitted)
	_edit.text_changed.connect(_on_text_changed)
	column.add_child(_edit)

	_error = Label.new()
	_error.add_theme_font_size_override("font_size", 16)
	_error.add_theme_color_override("font_color", Color("F06060"))
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error.custom_minimum_size = Vector2(320, 22)
	column.add_child(_error)

	_submit = Button.new()
	_submit.text = "Play"
	_submit.add_theme_font_size_override("font_size", 24)
	_submit.custom_minimum_size = Vector2(320, 56)
	_submit.pressed.connect(_on_submit_pressed)
	column.add_child(_submit)


func prefill(nickname: String) -> void:
	_edit.text = nickname
	_refresh_validity()


func focus_input() -> void:
	_edit.grab_focus()
	# Touch platforms need the software keyboard raised explicitly.
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(_edit.text, Rect2i(), DisplayServer.KEYBOARD_TYPE_DEFAULT, 12)


func _on_text_changed(_new_text: String) -> void:
	_refresh_validity()


# Shows the rejection reason only once something has been typed, so the prompt
# does not open already complaining.
func _refresh_validity() -> void:
	var check := Leaderboard.validate_nickname(_edit.text)
	var valid := bool(check["valid"])
	_submit.disabled = not valid
	_error.text = "" if valid or _edit.text.is_empty() else str(check["reason"])


func _on_text_submitted(_text: String) -> void:
	_on_submit_pressed()


func _on_submit_pressed() -> void:
	var check := Leaderboard.validate_nickname(_edit.text)
	if not bool(check["valid"]):
		_error.text = str(check["reason"])
		return
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	submitted.emit(str(check["value"]))
