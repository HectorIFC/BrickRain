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
	_dashboard.friends_ranking_requested.connect(
		func(): FBBridge.show_leaderboard(AppConfig.leaderboard_name())
	)
	add_child(_dashboard)

	_game = GameScreen.new()
	_game.game_finished.connect(_on_game_finished)
	_game.quit_requested.connect(_show_dashboard)
	_game.restart_requested.connect(_start_run)
	add_child(_game)

	# A known nickname skips straight to the dashboard on a returning visit.
	if _nickname == "":
		_show_nickname_entry()
	else:
		_show_dashboard()

	# FR05: local storage answers immediately so the dashboard is never blank;
	# the cloud copy merges in when it arrives. Off platform this emits
	# ok=false straight away and nothing changes.
	FBBridge.data_loaded.connect(_on_cloud_data_loaded)
	FBBridge.load_data([Storage.CLOUD_KEY])


func _on_cloud_data_loaded(ok: bool, data: Dictionary, _code: String) -> void:
	if not ok or not data.has(Storage.CLOUD_KEY):
		return
	var cloud := Leaderboard.deserialize(str(data[Storage.CLOUD_KEY]))
	if cloud["entries"].is_empty():
		return
	_leaderboard = Storage.merge_leaderboards(_leaderboard, cloud)
	Storage.save_leaderboard(_leaderboard)
	if _dashboard.visible:
		_dashboard.refresh(_leaderboard, _nickname)


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
	_dashboard.refresh(_leaderboard, _nickname)
	# The dashboard is where a session starts and returns, so the music belongs
	# here too. Music._start() is a no-op while already playing, so entering a
	# game carries the same track over instead of restarting it.
	Music.play()


func _on_nickname_submitted(nickname: String) -> void:
	_nickname = nickname
	Storage.save_nickname(nickname)
	_show_dashboard()


func _on_play_requested() -> void:
	_start_run()


# The single entry point for starting a run, whether from the dashboard or from
# a Restart / Play Again inside the game. The record to beat is recomputed from
# the leaderboard every time: it is the pre-game #1, not a personal best, and
# not a value cached when the screen was first opened.
func _start_run() -> void:
	_show_only(_game)
	_game.start_game(_nickname, Leaderboard.top_score(_leaderboard))


# Every finished game is recorded as its own entry, so the same nickname can
# appear many times - the model the Roku channel uses.
func _on_game_finished(result: Dictionary) -> void:
	_leaderboard = Leaderboard.add_entry(
		_leaderboard,
		str(result["nickname"]),
		int(result["score"]),
		Storage.today_text(),
		int(result["level"])
	)
	Storage.save_leaderboard(_leaderboard)

	# Two leaderboards, deliberately. The dashboard above keeps every game as
	# its own row (the Roku model); Facebook's social leaderboard keeps one
	# best score per player and renders the names and photos that Zero
	# Permissions no longer exposes to the game itself.
	FBBridge.save_data({Storage.CLOUD_KEY: Leaderboard.serialize(_leaderboard)})
	FBBridge.submit_score(AppConfig.leaderboard_name(), int(result["score"]))
