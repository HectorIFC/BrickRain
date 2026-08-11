class_name GameScreen
extends Control

# Imperative shell around the pure game state machine. Every action and every
# frame produces a fresh game state (with an events list); this scene reflects
# that state into the board and side panel and plays the matching sounds.
#
# Mirrors components/GameScreen.bs. The pure core is untouched — this layer
# only injects time and input and renders what comes back.

signal game_finished(result: Dictionary)
signal quit_requested
# Asks the router to start a fresh run. This screen deliberately does NOT restart
# itself: the record to beat comes from the leaderboard, which only main.gd owns,
# so a self-restart would replay with a stale record and score every subsequent
# run as a new one.
signal restart_requested

# Delay before new_record.ogg, so it does not overlap game_over.ogg.
const RECORD_SOUND_DELAY_S := 0.9

var _state: Dictionary = {}
var _last_level := -1
var _player_nickname := ""
var _record_score := 0
var _pending_record := false
var _running := false
var _accum_ms := 0.0
var _portrait := true
# A rewarded continue is offered at most once per game, so the run still ends.
var _continue_used := false

# A stack this many rows tall (of 20 visible) switches the music to its tense
# variant — pitched up with the low-pass closed in, not a second track.
const TENSE_STACK_ROWS := 14

var _root_box: BoxContainer
var _board_view: BoardView
var _side_panel: SidePanel
var _button_bar: BoxContainer
var _mute_button: Button
var _input: InputRouter
var _audio: GameAudio
var _pause_overlay: MenuOverlay
var _game_over_overlay: MenuOverlay


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	resized.connect(_apply_layout)
	_apply_layout()


func _build() -> void:
	var background := ColorRect.new()
	background.color = GameTheme.background_color()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	_root_box = BoxContainer.new()
	_root_box.add_theme_constant_override("separation", 12)
	margin.add_child(_root_box)

	_side_panel = SidePanel.new()
	_root_box.add_child(_side_panel)

	_board_view = BoardView.new()
	_board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_box.add_child(_board_view)

	_button_bar = BoxContainer.new()
	_button_bar.add_theme_constant_override("separation", 10)
	_root_box.add_child(_button_bar)
	_button_bar.add_child(_make_touch_button("HOLD", "hold"))
	_button_bar.add_child(_make_touch_button("II", "pause"))
	_mute_button = UiStyle.make_button("", UiStyle.SIZE_TOUCH_BUTTON)
	_mute_button.custom_minimum_size = Vector2(190, 96)
	_mute_button.focus_mode = Control.FOCUS_NONE
	_mute_button.pressed.connect(_on_mute_pressed)
	_button_bar.add_child(_mute_button)
	_refresh_mute_button()

	_input = InputRouter.new()
	_input.action.connect(_on_action)
	# Stays inert until start_game, so keys typed on the nickname or dashboard
	# screens cannot reach the game.
	_input.set_enabled(false)
	add_child(_input)

	_audio = GameAudio.new()
	add_child(_audio)

	_pause_overlay = MenuOverlay.new()
	_pause_overlay.visible = false
	_pause_overlay.selection.connect(_on_pause_selection)
	add_child(_pause_overlay)

	_game_over_overlay = MenuOverlay.new()
	_game_over_overlay.visible = false
	_game_over_overlay.selection.connect(_on_game_over_selection)
	add_child(_game_over_overlay)

	Ads.reward_granted.connect(_on_reward_granted)
	Ads.reward_failed.connect(_on_reward_failed)


# On-screen controls for touch: hold has no natural gesture, and pause needs to
# stay reachable without a keyboard.
func _make_touch_button(text: String, action_name: String) -> Button:
	var button := UiStyle.make_button(text, UiStyle.SIZE_TOUCH_BUTTON)
	button.custom_minimum_size = Vector2(130, 96)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_action.bind(action_name))
	return button


# FR03: portrait stacks panel / well / controls; landscape puts them side by
# side. The well itself always centres inside whatever rect it is given.
func _apply_layout() -> void:
	_portrait = size.y >= size.x
	if _root_box == null:
		return
	_root_box.vertical = _portrait
	_button_bar.vertical = not _portrait
	_side_panel.set_portrait(_portrait)


# Current orientation, for tests and for callers that need to mirror it.
func is_portrait() -> bool:
	return _portrait


# The well rect actually in use, so tests can assert it stays inside the view.
func board_metrics() -> Dictionary:
	return _board_view.well_metrics()


# --- lifecycle ---


func start_game(nickname: String, record_score: int) -> void:
	_player_nickname = nickname
	_record_score = record_score
	_pending_record = false
	_last_level = -1
	_accum_ms = 0.0
	_continue_used = false
	_state = Game.create()
	_pause_overlay.visible = false
	_game_over_overlay.visible = false
	_running = true
	_input.set_enabled(true)
	# Warm an ad now so the continue offer is instant at game over, which is
	# the only place it is shown.
	Ads.preload_ad()
	# First call reaches here from the dashboard Play button, i.e. from a real
	# user gesture, which is what the browser autoplay policy requires.
	Music.set_tense(false)
	Music.play()
	_render()


func _process(delta: float) -> void:
	if not _running or _state.is_empty() or _state["status"] != "playing":
		return
	# Accumulate fractional milliseconds so slow frames never lose gravity time.
	_accum_ms += delta * 1000.0
	var whole_ms := int(_accum_ms)
	if whole_ms <= 0:
		return
	_accum_ms -= float(whole_ms)
	_perform(Game.advance(_state, whole_ms))


# --- input ---


func _on_action(name: String) -> void:
	if _state.is_empty():
		return
	if name == "pause":
		if _state["status"] == "playing":
			_open_pause()
		elif _state["status"] == "paused":
			_resume_game()
		return
	if _state["status"] != "playing":
		return

	match name:
		"move_left":
			_perform(Game.move_left(_state))
		"move_right":
			_perform(Game.move_right(_state))
		"soft_drop":
			_perform(Game.soft_drop(_state))
		"hard_drop":
			_perform(Game.hard_drop(_state))
		"rotate_cw":
			_perform(Game.rotate_cw(_state))
		"rotate_ccw":
			_perform(Game.rotate_ccw(_state))
		"hold":
			_perform(Game.hold_swap(_state))


# --- state application ---


# Adopts a new game state, plays its sounds, repaints and reacts to game over.
func _perform(new_state: Dictionary) -> void:
	_state = new_state
	_audio.play_events(new_state["events"])
	_render()
	if new_state["status"] == "gameOver":
		_on_game_over()


func _render() -> void:
	# Push a new well theme only when the level actually changes.
	var level := int(_state["score"]["level"])
	if level != _last_level:
		_board_view.set_level_theme(GameTheme.board_theme_for_level(level))
		_last_level = level
	_board_view.set_board(_build_board_colors(_state), _build_ghost_cells(_state))
	_side_panel.set_nickname(_player_nickname)
	_side_panel.set_stats(int(_state["score"]["score"]), level, int(_state["score"]["lines"]))
	_side_panel.set_hold(str(_state["hold"]))
	_side_panel.set_next(Game.next_types(_state, 3))
	Music.set_tense(_stack_rows(_state) >= TENSE_STACK_ROWS)


# How many rows tall the settled stack is. Board.stack_in_hidden_rows() exists
# but only trips once the well has already overflowed, which is far too late to
# be useful as a tension cue. Computed here in the shell: it is a presentation
# decision, not a game rule, so it stays out of the core.
func _stack_rows(state: Dictionary) -> int:
	var board: Dictionary = state["board"]
	var width := int(board["width"])
	var height := int(board["height"])
	var grid: Array = board["grid"]
	for y in range(int(board["hidden_rows"]), height):
		for x in range(width):
			if int(grid[y * width + x]) != 0:
				return height - y
	return 0


func _on_mute_pressed() -> void:
	Music.toggle_muted()
	_refresh_mute_button()


func _refresh_mute_button() -> void:
	_mute_button.text = "MUTED" if Music.is_muted() else "SOUND"


# Flattens the visible board plus the active piece into a row-major color-index
# array for BoardView (hidden spawn rows are dropped).
func _build_board_colors(state: Dictionary) -> Array:
	var board: Dictionary = state["board"]
	var hidden := int(board["hidden_rows"])
	var cols := int(board["width"])
	var vis_rows := int(board["height"]) - hidden
	var grid: Array = board["grid"]
	var flat := []
	for v in range(vis_rows):
		for col in range(cols):
			flat.append(grid[(v + hidden) * cols + col])
	if state["active"] != null:
		var index := Piece.type_index(state["active"]["piece_type"])
		for cell in Game.active_cells(state):
			var v := int(cell["y"]) - hidden
			var x := int(cell["x"])
			if v >= 0 and v < vis_rows and x >= 0 and x < cols:
				flat[v * cols + x] = index
	return flat


# Ghost landing cells in visible-grid coords, excluding any that coincide with
# the active piece (so the outline only shows the empty drop target).
func _build_ghost_cells(state: Dictionary) -> Array:
	if state["active"] == null:
		return []
	var hidden := int(state["board"]["hidden_rows"])
	var active := {}
	for cell in Game.active_cells(state):
		active[str(cell["x"]) + "," + str(cell["y"])] = true
	var visible := []
	for cell in Game.ghost_cells(state):
		var v := int(cell["y"]) - hidden
		if v >= 0 and not active.has(str(cell["x"]) + "," + str(cell["y"])):
			visible.append({"x": cell["x"], "y": v})
	return visible


# --- pause ---


func _open_pause() -> void:
	_perform(Game.pause(_state))
	if _state["status"] != "paused":
		return
	_input.release_all()
	_pause_overlay.configure(
		"PAUSED",
		"",
		[
			{"id": "resume", "label": "Resume"},
			{"id": "restart", "label": "Restart"},
			{"id": "quit", "label": "Dashboard"}
		]
	)
	_pause_overlay.visible = true
	_pause_overlay.focus_first()


func _resume_game() -> void:
	_pause_overlay.visible = false
	_accum_ms = 0.0
	_perform(Game.resume(_state))


func _on_pause_selection(id: String) -> void:
	match id:
		"resume":
			_resume_game()
		"restart":
			restart_requested.emit()
		"quit":
			_quit_to_dashboard()


# --- game over ---


func _on_game_over() -> void:
	_running = false
	_input.release_all()
	# Silence the music so the descending game-over cue is heard cleanly.
	Music.stop()

	var final_score := int(_state["score"]["score"])
	# _record_score is the pre-game leaderboard #1; a new record beats it.
	var is_new_record := final_score > _record_score
	var display_record := maxi(_record_score, final_score)

	if is_new_record:
		_pending_record = true
		var timer := get_tree().create_timer(RECORD_SOUND_DELAY_S)
		timer.timeout.connect(_on_record_timer)

	var detail := "Score  %d\nLines  %d\nBest   %d" % [
		final_score, int(_state["score"]["lines"]), display_record
	]
	if is_new_record:
		detail = "NEW RECORD\n" + detail

	# The continue offer only appears when an ad is actually banked, so the
	# player is never shown a button that then fails to deliver.
	var options := []
	if not _continue_used and Ads.is_offer_available():
		options.append({"id": "continue", "label": "Continue (watch ad)"})
	options.append({"id": "again", "label": "Play Again"})
	options.append({"id": "dashboard", "label": "Dashboard"})

	_game_over_overlay.configure("GAME OVER", detail, options)
	_game_over_overlay.visible = true
	_game_over_overlay.focus_first()

	game_finished.emit({
		"nickname": _player_nickname,
		"score": final_score,
		"lines": int(_state["score"]["lines"]),
		"is_new_record": is_new_record
	})


func _on_record_timer() -> void:
	if _pending_record:
		_audio.play("new_record")
		_pending_record = false


func _on_game_over_selection(id: String) -> void:
	match id:
		"continue":
			_continue_used = true
			Ads.show_ad()
		"again":
			restart_requested.emit()
		_:
			_quit_to_dashboard()


# Only a completed view reaches here; a dismissed ad goes to _on_reward_failed.
# The continue clears the well but keeps the score, level and line count, so
# the run carries on rather than restarting.
func _on_reward_granted() -> void:
	if not _game_over_overlay.visible:
		return
	var earned: Dictionary = _state["score"]
	var resumed := Game.create()
	resumed["score"] = earned
	_state = resumed
	_last_level = -1
	_accum_ms = 0.0
	_pending_record = false
	_game_over_overlay.visible = false
	_running = true
	_input.set_enabled(true)
	_render()


func _on_reward_failed(code: String) -> void:
	if not _game_over_overlay.visible:
		return
	# Dismissed or unavailable: the run stays over. Re-render the overlay
	# without the continue option so it cannot be attempted again.
	_on_game_over_overlay_refresh(code)


func _on_game_over_overlay_refresh(code: String) -> void:
	var note := "Ad not completed — no continue."
	if code == "ADS_NOT_LOADED" or code == "UNAVAILABLE":
		note = "No ad available right now."
	var final_score := int(_state["score"]["score"])
	_game_over_overlay.configure(
		"GAME OVER",
		"%s\n\nScore  %d" % [note, final_score],
		[{"id": "again", "label": "Play Again"}, {"id": "dashboard", "label": "Dashboard"}]
	)
	_game_over_overlay.focus_first()


func _quit_to_dashboard() -> void:
	_running = false
	# Cancel a pending new-record sound so it cannot fire on the dashboard
	# after a quick exit from a record-setting game over.
	_pending_record = false
	_input.set_enabled(false)
	_pause_overlay.visible = false
	_game_over_overlay.visible = false
	quit_requested.emit()
