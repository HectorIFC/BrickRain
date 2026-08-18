extends Node

# Autoload. The single place that talks to the Facebook Instant Games SDK.
#
# Everything goes through window.BrickRainFB, the callback-based shim defined in
# web/index.html; promises are chained there rather than across
# JavaScriptBridge. This node's job is to marshal arguments, keep callback
# objects alive, and hand results back as signals.
#
# Off platform — in the editor, or on a plain web server — every call resolves
# to a defined "unavailable" result instead of failing. Nothing else in the
# codebase branches on the environment; callers just get an answer.
#
# API surface targeted: Instant Games SDK v8.0 under Network Enabled Zero
# Permissions. Player name and photo are NOT available under that model, which
# is why the game asks for a nickname itself. Player id still is.

signal data_loaded(ok: bool, data: Dictionary, code: String)
signal data_saved(ok: bool, code: String)
signal rewarded_loaded(ok: bool, code: String)
signal rewarded_shown(ok: bool, code: String)
signal score_submitted(ok: bool, code: String)
signal shared(ok: bool, code: String)
signal leaderboard_shown(ok: bool, code: String)

# JavaScriptBridge callbacks must stay referenced for as long as JS might call
# them; a local would be collected and the callback would fire into freed
# memory.
var _cb_get_data: JavaScriptObject
var _cb_set_data: JavaScriptObject
var _cb_load_ad: JavaScriptObject
var _cb_show_ad: JavaScriptObject
var _cb_submit_score: JavaScriptObject
var _cb_share: JavaScriptObject
var _cb_show_leaderboard: JavaScriptObject

var _shim: JavaScriptObject = null


func _ready() -> void:
	if not _is_web():
		return
	_shim = JavaScriptBridge.get_interface("BrickRainFB")
	if _shim == null:
		push_warning("BrickRainFB shim missing; running with platform features disabled")
		return
	_cb_get_data = JavaScriptBridge.create_callback(_on_get_data)
	_cb_set_data = JavaScriptBridge.create_callback(_on_set_data)
	_cb_load_ad = JavaScriptBridge.create_callback(_on_load_ad)
	_cb_show_ad = JavaScriptBridge.create_callback(_on_show_ad)
	_cb_submit_score = JavaScriptBridge.create_callback(_on_submit_score)
	_cb_share = JavaScriptBridge.create_callback(_on_share)
	_cb_show_leaderboard = JavaScriptBridge.create_callback(_on_leaderboard_shown)


func _is_web() -> bool:
	return OS.has_feature("web")


# True only when the SDK loaded AND initializeAsync resolved.
func is_available() -> bool:
	if _shim == null:
		return false
	return bool(_shim.isAvailable())


func is_started() -> bool:
	if _shim == null:
		return false
	return bool(_shim.isStarted())


func player_id() -> String:
	if _shim == null:
		return ""
	return str(_shim.getPlayerId())


# --- cloud save (FR05) ---


# Emits data_loaded. Off platform this still emits, with ok=false, so callers
# can fall through to local storage without special-casing.
func load_data(keys: Array) -> void:
	if _shim == null:
		data_loaded.emit(false, {}, "UNAVAILABLE")
		return
	_shim.getPlayerData(JSON.stringify(keys), _cb_get_data)


func save_data(data: Dictionary) -> void:
	if _shim == null:
		data_saved.emit(false, "UNAVAILABLE")
		return
	_shim.setPlayerData(JSON.stringify(data), _cb_set_data)


# --- rewarded video (FR04) ---


func load_rewarded(placement_id: String) -> void:
	if _shim == null:
		rewarded_loaded.emit(false, "UNAVAILABLE")
		return
	_shim.loadRewarded(placement_id, _cb_load_ad)


func is_rewarded_ready() -> bool:
	if _shim == null:
		return false
	return bool(_shim.isRewardedReady())


# Emits rewarded_shown(true) ONLY when the video completed. A dismissed ad
# emits ok=false, so the reward is never granted for a skipped view.
func show_rewarded() -> void:
	if _shim == null:
		rewarded_shown.emit(false, "UNAVAILABLE")
		return
	_shim.showRewarded(_cb_show_ad)


# --- social leaderboard ---


func submit_score(leaderboard_name: String, score: int) -> void:
	if _shim == null:
		score_submitted.emit(false, "UNAVAILABLE")
		return
	_shim.submitScore(leaderboard_name, score, _cb_submit_score)


# --- sharing ---


# image_base64 must be a data URI; Facebook renders it in the share card.
# The data blob rides along and is handed to a session launched from the share
# via getEntryPointData, so it is capped at the documented 1000 characters.
func share(image_base64: String, text: String, data: Dictionary = {}) -> void:
	if _shim == null:
		shared.emit(false, "UNAVAILABLE")
		return
	var encoded_data := JSON.stringify(data)
	if encoded_data.length() > 1000:
		push_warning("share data over the 1000-character limit; sending it empty")
		data = {}
	_shim.share(JSON.stringify({"image": image_base64, "text": text, "data": data}), _cb_share)


# Opens Facebook's native leaderboard overlay, which renders the names and
# photos Zero Permissions keeps away from the game itself.
func show_leaderboard(leaderboard_name: String) -> void:
	if _shim == null:
		leaderboard_shown.emit(false, "UNAVAILABLE")
		return
	_shim.showLeaderboard(leaderboard_name, _cb_show_leaderboard)


# --- callback plumbing ---


# Every shim callback delivers one JSON string; this normalises it so a
# malformed or missing payload can never crash a caller.
func _parse(args: Array) -> Dictionary:
	if args.is_empty():
		return {"ok": false, "code": "NO_PAYLOAD"}
	var parsed = JSON.parse_string(str(args[0]))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "code": "BAD_PAYLOAD"}
	return parsed


func _code(result: Dictionary) -> String:
	return str(result.get("code", ""))


func _on_get_data(args: Array) -> void:
	var result := _parse(args)
	var data = result.get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		data = {}
	data_loaded.emit(bool(result.get("ok", false)), data, _code(result))


func _on_set_data(args: Array) -> void:
	var result := _parse(args)
	data_saved.emit(bool(result.get("ok", false)), _code(result))


func _on_load_ad(args: Array) -> void:
	var result := _parse(args)
	rewarded_loaded.emit(bool(result.get("ok", false)), _code(result))


func _on_show_ad(args: Array) -> void:
	var result := _parse(args)
	rewarded_shown.emit(bool(result.get("ok", false)), _code(result))


func _on_submit_score(args: Array) -> void:
	var result := _parse(args)
	score_submitted.emit(bool(result.get("ok", false)), _code(result))


func _on_share(args: Array) -> void:
	var result := _parse(args)
	shared.emit(bool(result.get("ok", false)), _code(result))


func _on_leaderboard_shown(args: Array) -> void:
	var result := _parse(args)
	leaderboard_shown.emit(bool(result.get("ok", false)), _code(result))
