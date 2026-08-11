class_name UiStyle
extends RefCounted

# Typography for the web UI: sizes, colors and the display font.
#
# This is deliberately NOT part of core/theme.gd. That file mirrors
# source/theme.bs one-for-one and holds the *game* palette, which both
# implementations must agree on. UI typography is web-only — putting it there
# would create exactly the drift CONTRIBUTING.md warns about.
#
# Sizes are in the 1080x1920 design space. The project stretches with
# canvas_items/expand, so they scale proportionally on any viewport; what
# matters is the ratio to the 1080 width, not the pixel value on your monitor.
#
# TitanOne is used only for display text. It is a heavy rounded display face —
# excellent for the wordmark, score and buttons, poor for the small leaderboard
# rows and validation messages, which stay on the default font.

const DISPLAY_FONT_PATH := "res://assets/fonts/TitanOne-Regular.ttf"

const SIZE_WORDMARK := 120
const SIZE_WORDMARK_SMALL := 84
const SIZE_OVERLAY_TITLE := 80
const SIZE_PROMPT := 36
const SIZE_INPUT := 44
const SIZE_BUTTON := 44
const SIZE_BUTTON_SMALL := 34
const SIZE_OVERLAY_DETAIL := 40
const SIZE_STAT_LABEL := 30
const SIZE_STAT_VALUE := 60
const SIZE_SLOT_LABEL := 28
const SIZE_ROW := 32
const SIZE_ERROR := 30
const SIZE_TOUCH_BUTTON := 34

static var _display_font: FontFile = null


static func display_font() -> FontFile:
	if _display_font == null:
		_display_font = load(DISPLAY_FONT_PATH)
	return _display_font


# Heavy display face. Buttons carry hover/pressed/disabled colors too, otherwise
# the default theme colors leak through on interaction and the text changes hue
# mid-click.
static func apply_display(control: Control, size: int, color: Color) -> void:
	control.add_theme_font_override("font", display_font())
	control.add_theme_font_size_override("font_size", size)
	_apply_colors(control, color)


static func apply_body(control: Control, size: int, color: Color) -> void:
	control.add_theme_font_size_override("font_size", size)
	_apply_colors(control, color)


static func _apply_colors(control: Control, color: Color) -> void:
	control.add_theme_color_override("font_color", color)
	if control is Button:
		control.add_theme_color_override("font_hover_color", color.lightened(0.25))
		control.add_theme_color_override("font_pressed_color", color.lightened(0.4))
		control.add_theme_color_override("font_focus_color", color)
		control.add_theme_color_override("font_disabled_color", Color(color, 0.35))


static func make_label(text: String, size: int, color: Color, display: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if display:
		apply_display(label, size, color)
	else:
		apply_body(label, size, color)
	return label


static func make_button(text: String, size: int = SIZE_BUTTON) -> Button:
	var button := Button.new()
	button.text = text
	apply_display(button, size, GameTheme.text_color())
	return button


# The wordmark: one Label per letter, colored from the tetromino palette, the
# same trick tools/generate_artwork.py uses for the splash. Index 0 of the
# palette is the empty-cell color, so letters cycle through 1..7.
static func make_wordmark(text: String, size: int = SIZE_WORDMARK) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	var palette := GameTheme.cell_colors()
	for i in range(text.length()):
		var letter := UiStyle.make_label(text[i], size, palette[(i % 7) + 1])
		box.add_child(letter)
	return box
