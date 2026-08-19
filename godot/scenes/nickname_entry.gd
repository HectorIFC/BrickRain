class_name NicknameEntry
extends Control

# Nickname prompt.
#
# Replaces components/NicknameDialog.bs. The Roku build ships a custom
# on-screen keyboard only because brs-engine lacks StandardKeyboardDialog;
# that constraint does not apply here, so this is a LineEdit plus the platform
# virtual keyboard on touch devices.
#
# Validation is Leaderboard.validate_nickname, unchanged - the same rules the
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

	column.add_child(UiStyle.make_wordmark("BRICKRAIN"))
	column.add_child(UiStyle.make_label(
		"Enter your nickname", UiStyle.SIZE_PROMPT, GameTheme.text_color()
	))

	_edit = LineEdit.new()
	_edit.custom_minimum_size = Vector2(560, 100)
	_edit.max_length = 12
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.apply_display(_edit, UiStyle.SIZE_INPUT, GameTheme.text_color())
	_edit.text_submitted.connect(_on_text_submitted)
	_edit.text_changed.connect(_on_text_changed)
	column.add_child(_edit)

	# Body font: the rejection reason is a full sentence, and a heavy display
	# face makes it harder to read, not easier.
	_error = UiStyle.make_label("", UiStyle.SIZE_ERROR, Color("F06060"), false)
	_error.custom_minimum_size = Vector2(560, 40)
	column.add_child(_error)

	_submit = UiStyle.make_button("Play")
	_submit.custom_minimum_size = Vector2(560, 100)
	_submit.pressed.connect(_on_submit_pressed)
	column.add_child(_submit)

	FBBridge.text_input_changed.connect(_on_overlay_text)
	visibility_changed.connect(_on_visibility_changed)
	# item_rect_changed is the signal that actually fires once the container
	# has placed the field. Syncing from _ready or from focus_input alone
	# placed the overlay at (0, 0), because at that point the LineEdit has no
	# layout yet.
	_edit.item_rect_changed.connect(_sync_text_overlay)
	resized.connect(_sync_text_overlay)


func prefill(nickname: String) -> void:
	_edit.text = nickname
	_refresh_validity()


func focus_input() -> void:
	_edit.grab_focus()
	# Native touch platforms raise their keyboard from here. On the web this
	# feature does not exist (the web DisplayServer implements no virtual
	# keyboard at all), so a real HTML field is placed over the canvas instead:
	# see _sync_text_overlay. Both paths are kept because the same scene has to
	# work in the editor, on a desktop browser and on a phone.
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(_edit.text, Rect2i(), DisplayServer.KEYBOARD_TYPE_DEFAULT, 12)
	_sync_text_overlay()


# The overlay follows the LineEdit: it has to be re-placed whenever the layout
# can have moved it, which on a phone includes rotating the device.
func _sync_text_overlay() -> void:
	if not visible:
		return
	var view := get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var box := _edit.get_global_rect()
	if box.size.x <= 1.0 or box.size.y <= 1.0:
		return
	FBBridge.show_text_input(
		Rect2(box.position.x / view.x, box.position.y / view.y,
			box.size.x / view.x, box.size.y / view.y),
		_edit.text,
		_edit.max_length
	)


# Typing happens in the HTML field; the LineEdit stays the thing on screen.
func _on_overlay_text(text: String, submit: bool) -> void:
	if not visible:
		return
	if _edit.text != text:
		_edit.text = text
		_refresh_validity()
	if submit:
		_on_submit_pressed()


func _on_visibility_changed() -> void:
	if visible:
		# Deferred: on the frame the screen becomes visible the container has
		# not necessarily re-laid it out yet.
		call_deferred("_sync_text_overlay")
	else:
		FBBridge.hide_text_input()


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
	FBBridge.hide_text_input()
	submitted.emit(str(check["value"]))
