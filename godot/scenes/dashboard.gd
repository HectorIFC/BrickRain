class_name Dashboard
extends Control

# Leaderboard dashboard: the record to beat, the ranked entry list and the
# entry point into a game.
#
# Replaces components/LeaderboardScreen.bs. The per-game entry model is
# unchanged - one row per playthrough, so the same nickname can appear several
# times.

signal play_requested
signal change_nickname_requested
signal friends_ranking_requested

# Widest the content is allowed to get. Chosen to fit the narrowest design
# space (1080) with the screen margins still applied.
const CONTENT_MAX_WIDTH := 960

var _player_label: Label
var _record_label: Label
var _runs_value: Label
var _best_value: Label
var _level_value: Label
var _mute_button: Button
var _list: VBoxContainer
var _empty_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = GameTheme.background_color()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Added before the content so it draws behind everything. It ignores the
	# mouse, so it cannot steal clicks from the list or the buttons.
	var rain := PieceRain.new()
	rain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rain)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	# Cap the content width and centre it. Without this the rows stretch to the
	# full viewport, which on a wide screen leaves the nickname pinned far left
	# and the date and score far right with a dead gap between them.
	# 960 still fits the narrowest possible design space (1080) inside the
	# margins above, so portrait never overflows.
	column.custom_minimum_size = Vector2(CONTENT_MAX_WIDTH, 0)
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Shrink-centre vertically too. Stretching left a tall void in the middle
	# with the header pinned to the top and the buttons to the bottom; grouped
	# in the centre the screen reads as one block whether there are 2 runs or
	# 50 (the list scrolls once it outgrows its cap).
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	margin.add_child(column)

	column.add_child(UiStyle.make_wordmark("BRICKRAIN", UiStyle.SIZE_WORDMARK_SMALL))

	# Without this the current nickname is invisible here - the only names on
	# screen are historical leaderboard rows, which keep the name used at the
	# time, so changing it looks like it did nothing.
	_player_label = UiStyle.make_label("", UiStyle.SIZE_STAT_LABEL, GameTheme.accent_color())
	column.add_child(_player_label)

	_record_label = UiStyle.make_label("", UiStyle.SIZE_STAT_LABEL, GameTheme.text_color())
	column.add_child(_record_label)

	# Three numbers the player has earned, read straight off the history: how
	# much they have played, their best score and how deep they have got. No
	# new storage, and it gives the middle of the screen something to say.
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 48)
	column.add_child(stats)
	_runs_value = _add_stat(stats, "RUNS")
	_best_value = _add_stat(stats, "BEST")
	_level_value = _add_stat(stats, "LEVEL")

	# On Facebook every player is on their own device, so this list is the
	# player's own history - one row per run - not a ranking of people. The
	# social ranking is Facebook's native leaderboard, opened by the button
	# below. On the shared-TV Roku build the equivalent list IS a household
	# ranking, which is why the model itself stays unchanged.
	column.add_child(UiStyle.make_label(
		"Your best runs", UiStyle.SIZE_STAT_LABEL, GameTheme.text_color()
	))

	# The list scrolls once it passes this height; below it the column simply
	# gets shorter, which is what keeps a two-run history compact.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 0)
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	_empty_label = UiStyle.make_label(
		"No games yet. Play one!", UiStyle.SIZE_ROW, GameTheme.text_color(), false
	)
	column.add_child(_empty_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)

	var play := UiStyle.make_button("Play")
	play.custom_minimum_size = Vector2(340, 96)
	play.pressed.connect(func(): play_requested.emit())
	buttons.add_child(play)

	var change := UiStyle.make_button("Nickname", UiStyle.SIZE_BUTTON_SMALL)
	change.custom_minimum_size = Vector2(300, 96)
	change.pressed.connect(func(): change_nickname_requested.emit())
	buttons.add_child(change)

	_mute_button = UiStyle.make_button("", UiStyle.SIZE_BUTTON_SMALL)
	_mute_button.custom_minimum_size = Vector2(240, 96)
	_mute_button.pressed.connect(_on_mute_pressed)
	buttons.add_child(_mute_button)
	_refresh_mute_button()

	# The real ranking between players: Facebook's native leaderboard, which
	# renders friends' names and photos via the platform overlay. Hidden off
	# platform - same rule as the ad offer and the share button, so no button
	# is ever shown that would silently do nothing.
	if FBBridge.is_available():
		var ranking := UiStyle.make_button("Friends Ranking", UiStyle.SIZE_BUTTON_SMALL)
		ranking.custom_minimum_size = Vector2(340, 96)
		ranking.pressed.connect(func(): friends_ranking_requested.emit())
		buttons.add_child(ranking)


# One stat: small caption over a large value, the same shape the in-game side
# panel uses, so the two screens read as one game.
func _add_stat(parent: BoxContainer, caption: String) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(box)
	var label := UiStyle.make_label(caption, UiStyle.SIZE_SLOT_LABEL, GameTheme.text_color())
	box.add_child(label)
	var value := UiStyle.make_label("0", UiStyle.SIZE_STAT_VALUE, GameTheme.accent_color())
	box.add_child(value)
	return value


func _on_mute_pressed() -> void:
	Music.toggle_muted()
	_refresh_mute_button()


func _refresh_mute_button() -> void:
	_mute_button.text = "Muted" if Music.is_muted() else "Sound"


func refresh(leaderboard_state: Dictionary, nickname: String = "") -> void:
	for child in _list.get_children():
		child.queue_free()

	var entries: Array = leaderboard_state["entries"]
	_empty_label.visible = entries.is_empty()
	_player_label.text = "Playing as %s" % nickname
	_player_label.visible = nickname != ""
	_record_label.text = "Record to beat: %d" % Leaderboard.top_score(leaderboard_state)

	var best_level := 0
	for entry in entries:
		best_level = maxi(best_level, Leaderboard.entry_level(entry))
	_runs_value.text = str(entries.size())
	_best_value.text = str(Leaderboard.top_score(leaderboard_state))
	# Runs recorded before the level field existed read as 0, so a history made
	# only of those shows a dash rather than claiming level 0.
	_level_value.text = str(best_level) if best_level >= 1 else "-"

	for i in range(entries.size()):
		_list.add_child(_make_row(i + 1, entries[i]))


func _make_row(rank: int, entry: Dictionary) -> Control:
	var row := PanelContainer.new()
	# Comfortably tappable on a phone; on desktop it just reads as roomier.
	row.custom_minimum_size = Vector2(0, 72)
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

	# Rank and score carry the display face so the numbers read at a glance;
	# date and level stay on the body font. No nickname cell: every row here is
	# the player's own run, so a name would repeat the "Playing as" label above.
	# The entry keeps its nickname in the data model (cloud merge, Roku parity);
	# only the web rendering drops it.
	box.add_child(_cell("%d." % rank, 90, HORIZONTAL_ALIGNMENT_RIGHT, GameTheme.accent_color(), true))
	var date_cell := _cell(str(entry["date"]), 0, HORIZONTAL_ALIGNMENT_LEFT, GameTheme.text_color())
	date_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(date_cell)
	# Entries saved before the level field existed carry 0 - shown as unknown,
	# not as an invented "Lv 1".
	var level := Leaderboard.entry_level(entry)
	var level_text := "Lv %d" % level if level >= 1 else ""
	box.add_child(_cell(level_text, 130, HORIZONTAL_ALIGNMENT_CENTER, GameTheme.text_color()))
	box.add_child(_cell(str(entry["score"]), 170, HORIZONTAL_ALIGNMENT_RIGHT, GameTheme.text_color(), true))
	return row


func _cell(
	text: String,
	min_width: int,
	alignment: int,
	color: Color,
	display: bool = false
) -> Label:
	var label := UiStyle.make_label(text, UiStyle.SIZE_ROW, color, display)
	label.horizontal_alignment = alignment
	label.custom_minimum_size = Vector2(min_width, 0)
	return label
