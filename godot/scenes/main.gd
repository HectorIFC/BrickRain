extends Control

# Screen router: nickname entry -> dashboard -> game -> dashboard.
#
# Replaces components/MainScene.bs. Owns the leaderboard state and is the only
# place that persists it, keeping every other scene free of storage concerns.

var _leaderboard: Dictionary = {}
var _nickname := ""

var _nickname_entry: NicknameEntry
var _dashboard: Dashboard
var _game: GameScreen


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_leaderboard = Storage.load_leaderboard()
	_nickname = Storage.load_nickname()

	_nickname_entry = NicknameEntry.new()
	_nickname_entry.submitted.connect(_on_nickname_submitted)
	add_child(_nickname_entry)

	_dashboard = Dashboard.new()
	_dashboard.play_requested.connect(_on_play_requested)
	_dashboard.change_nickname_requested.connect(_show_nickname_entry)
	add_child(_dashboard)

	_game = GameScreen.new()
	_game.game_finished.connect(_on_game_finished)
	_game.quit_requested.connect(_show_dashboard)
	add_child(_game)

	# A known nickname skips straight to the dashboard on a returning visit.
	if _nickname == "":
		_show_nickname_entry()
	else:
		_show_dashboard()


func _show_only(screen: Control) -> void:
	_nickname_entry.visible = screen == _nickname_entry
	_dashboard.visible = screen == _dashboard
	_game.visible = screen == _game
	_game.set_process(screen == _game)


func _show_nickname_entry() -> void:
	_show_only(_nickname_entry)
	_nickname_entry.prefill(_nickname)
	_nickname_entry.focus_input()


func _show_dashboard() -> void:
	_show_only(_dashboard)
	_dashboard.refresh(_leaderboard)


func _on_nickname_submitted(nickname: String) -> void:
	_nickname = nickname
	Storage.save_nickname(nickname)
	_show_dashboard()


func _on_play_requested() -> void:
	_show_only(_game)
	# The record to beat is the pre-game leaderboard #1, not a personal best.
	_game.start_game(_nickname, Leaderboard.top_score(_leaderboard))


# Every finished game is recorded as its own entry, so the same nickname can
# appear many times — the model the Roku channel uses.
func _on_game_finished(result: Dictionary) -> void:
	_leaderboard = Leaderboard.add_entry(
		_leaderboard,
		str(result["nickname"]),
		int(result["score"]),
		Storage.today_text()
	)
	Storage.save_leaderboard(_leaderboard)
