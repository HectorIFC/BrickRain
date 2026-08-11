class_name GameTheme
extends RefCounted
# Named GameTheme rather than Theme because Godot already has a built-in
# Theme resource class; the file stays theme.gd to mirror source/theme.bs.

# Presentation constants: the tetromino color palette (matching
# tools/generate_artwork.py) and the board geometry. Pure data, kept out of the
# logic modules so they stay render agnostic.
#
# Translated from source/theme.bs. The Roku version expresses colors as
# "0xRRGGBBAA" strings for SceneGraph; here they are Color values, but the
# palette is byte-identical.
#
# Geometry is expressed as a cell size in pixels; unlike the Roku build (fixed
# 1920x1080 landscape) the Godot layout is responsive, so scene code derives
# the actual cell size from the available viewport and uses these only for
# aspect ratios and proportions.


# Cell colors indexed by piece type index: 0 = empty cell, 1..7 in the
# canonical order I, O, T, S, Z, J, L.
static func cell_colors() -> Array[Color]:
	return [
		Color("141228"),
		Color("00F0F0"),
		Color("F0F000"),
		Color("A000F0"),
		Color("00F000"),
		Color("F00000"),
		Color("3C78FF"),
		Color("F0A000")
	]


static func empty_cell_color() -> Color:
	return Color("141228")


static func ghost_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.25)


static func grid_line_color() -> Color:
	return Color("242246")


static func background_color() -> Color:
	return Color("080A22")


static func panel_color() -> Color:
	return Color("10122E")


static func text_color() -> Color:
	return Color("F5F5FA")


static func accent_color() -> Color:
	return Color("00F0F0")


static func cols() -> int:
	return 10


static func visible_rows() -> int:
	return 20


# Reference cell size and gap; the ratio between them is what the responsive
# layout preserves.
static func cell_size() -> int:
	return 46


static func cell_gap() -> int:
	return 2


# Level-based well theme: the empty-cell and grid colors cycle through a small
# palette as the player levels up, giving a visible mood shift without changing
# the canonical piece colors (which carry piece identity). Piece colors stay
# fixed; only the backdrop tints.
static func board_theme_for_level(level: int) -> Dictionary:
	var themes := [
		{"empty": Color("141228"), "grid": Color("242246")},
		{"empty": Color("1A1030"), "grid": Color("322052")},
		{"empty": Color("0E1E26"), "grid": Color("1C3A46")},
		{"empty": Color("241018"), "grid": Color("44202E")},
		{"empty": Color("101F14"), "grid": Color("1E3A26")},
		{"empty": Color("201A0E"), "grid": Color("40341C")}
	]
	var index := (level - 1) % themes.size()
	if index < 0:
		index = 0
	return themes[index]
