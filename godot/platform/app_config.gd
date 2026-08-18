class_name AppConfig
extends RefCounted

# Reads app_config.json, which carries the Facebook dashboard values.
#
# Ad placement ids are configuration, not code: they differ per app, they are
# created after the app exists, and baking them into a script would mean a
# rebuild to change one. An unset placement id is a supported state - the
# rewarded-ad offer is simply not shown.

const CONFIG_PATH := "res://app_config.json"

static var _cache: Dictionary = {}
static var _loaded := false


static func _config() -> Dictionary:
	if _loaded:
		return _cache
	_loaded = true
	_cache = {}
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("missing " + CONFIG_PATH + "; platform features will stay disabled")
		return _cache
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return _cache
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("malformed " + CONFIG_PATH + "; ignoring")
		return _cache
	_cache = parsed
	return _cache


static func rewarded_placement_id() -> String:
	return str(_config().get("rewarded_placement_id", ""))


static func leaderboard_name() -> String:
	return str(_config().get("leaderboard_name", "brickrain_high_scores"))
