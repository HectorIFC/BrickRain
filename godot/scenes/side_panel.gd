class_name SidePanel
extends PanelContainer

# Score readout, hold slot and next-piece queue.
#
# Mirrors components/SidePanel.bs, but the arrangement is driven by the parent:
# Game lays this out as a column beside the well in landscape and as a strip
# above it in portrait, which is what FR03 needs. Flipping BoxContainer.vertical
# is all that takes.
#
# Each stat is a small caption over a large value rather than one two-line
# label: the number is what the player glances at mid-game, so it carries the
# display face at roughly twice the caption's size.

const PREVIEW_COUNT := 3

var _nickname_label: Label
var _score_value: Label
var _level_value: Label
var _lines_value: Label
var _hold_preview: PiecePreview
var _next_previews: Array[PiecePreview] = []
var _root: BoxContainer
var _stats_box: BoxContainer
var _slots_box: BoxContainer


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = GameTheme.panel_color()
	style.set_content_margin_all(16)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	add_theme_stylebox_override("panel", style)
	_build()


func _build() -> void:
	_root = _make_box(true, 16)
	add_child(_root)

	_nickname_label = UiStyle.make_label(
		"", UiStyle.SIZE_STAT_LABEL, GameTheme.accent_color()
	)
	_root.add_child(_nickname_label)

	_stats_box = _make_box(true, 12)
	_root.add_child(_stats_box)
	_score_value = _add_stat("SCORE", "0")
	_level_value = _add_stat("LEVEL", "1")
	_lines_value = _add_stat("LINES", "0")

	# The slot row stays horizontal in both orientations. Stacking four previews
	# vertically makes the panel taller than a short landscape viewport, which
	# pushes the well off the bottom of the screen.
	_slots_box = _make_box(false, 12)
	_root.add_child(_slots_box)
	_slots_box.add_child(_make_slot_label("HOLD"))
	_hold_preview = _make_preview()
	_slots_box.add_child(_hold_preview)
	_slots_box.add_child(_make_slot_label("NEXT"))
	for _i in range(PREVIEW_COUNT):
		var preview := _make_preview()
		_slots_box.add_child(preview)
		_next_previews.append(preview)


# Caption above value; returns the value label so callers can update it.
func _add_stat(caption: String, initial: String) -> Label:
	var group := _make_box(true, 0)
	group.add_child(_make_slot_label(caption))
	var value := UiStyle.make_label(initial, UiStyle.SIZE_STAT_VALUE, GameTheme.text_color())
	group.add_child(value)
	_stats_box.add_child(group)
	return value


func _make_slot_label(text: String) -> Label:
	return UiStyle.make_label(text, UiStyle.SIZE_SLOT_LABEL, GameTheme.text_color())


func _make_box(vertical: bool, separation: int) -> BoxContainer:
	var box := BoxContainer.new()
	box.vertical = vertical
	box.add_theme_constant_override("separation", separation)
	return box


func _make_preview() -> PiecePreview:
	var preview := PiecePreview.new()
	preview.custom_minimum_size = Vector2(96, 72)
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


# The score rolls up to its new value instead of snapping, which gives the
# panel a pulse of life on every lock. It only ever climbs mid-game, so a
# lower value (a restart) snaps down instead of rolling backwards.
var _shown_score := 0.0
var _score_tween: Tween


func set_stats(score: int, level: int, lines: int) -> void:
	_level_value.text = str(level)
	_lines_value.text = str(lines)
	if _score_tween != null and _score_tween.is_valid():
		_score_tween.kill()
	if score <= int(_shown_score):
		_shown_score = float(score)
		_score_value.text = str(score)
		return
	_score_tween = create_tween()
	_score_tween.tween_method(_roll_score, _shown_score, float(score), 0.3)


func _roll_score(value: float) -> void:
	_shown_score = value
	_score_value.text = str(int(value))


func set_hold(piece_type: String) -> void:
	var changed := _hold_preview.piece_type != piece_type
	_hold_preview.piece_type = piece_type
	# A quick scale pulse acknowledges the stash without demanding attention.
	if changed and piece_type != "":
		_hold_preview.pivot_offset = _hold_preview.size * 0.5
		_hold_preview.scale = Vector2(1.18, 1.18)
		var tween := create_tween()
		tween.tween_property(_hold_preview, "scale", Vector2.ONE, 0.18) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func set_next(types: Array) -> void:
	for i in range(_next_previews.size()):
		_next_previews[i].piece_type = str(types[i]) if i < types.size() else ""
