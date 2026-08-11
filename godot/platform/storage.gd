class_name Storage
extends RefCounted

# Leaderboard persistence.
#
# Replaces source/registryAdapter.bs. The payload is the exact JSON shape
# produced by Leaderboard.serialize, so the Roku registry blob and this one are
# interchangeable.
#
# This is the local (user://) half only. Phase 3 adds the Facebook branch
# (player.setDataAsync / getDataAsync) in front of it and keeps this as the
# off-platform fallback, so the game stays runnable in the editor and on a
# plain web server.

const SAVE_PATH := "user://leaderboard.json"
const NICKNAME_PATH := "user://nickname.txt"
const MUTED_PATH := "user://muted.txt"


static func load_leaderboard() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return Leaderboard.create()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("could not read " + SAVE_PATH)
		return Leaderboard.create()
	var text := file.get_as_text()
	file.close()
	# deserialize already degrades a malformed payload to an empty board.
	return Leaderboard.deserialize(text)


static func save_leaderboard(leaderboard_state: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("could not write " + SAVE_PATH)
		return
	file.store_string(Leaderboard.serialize(leaderboard_state))
	file.close()


static func load_nickname() -> String:
	if not FileAccess.file_exists(NICKNAME_PATH):
		return ""
	var file := FileAccess.open(NICKNAME_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text().strip_edges()
	file.close()
	# Never hand back a nickname the current rules would reject.
	if not bool(Leaderboard.validate_nickname(text)["valid"]):
		return ""
	return text


static func save_nickname(nickname: String) -> void:
	var file := FileAccess.open(NICKNAME_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(nickname)
	file.close()


# An Instant Games player is often somewhere public; without a remembered mute
# they close the game rather than hunt for a volume control.
static func load_muted() -> bool:
	if not FileAccess.file_exists(MUTED_PATH):
		return false
	var file := FileAccess.open(MUTED_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text().strip_edges()
	file.close()
	return text == "1"


static func save_muted(muted: bool) -> void:
	var file := FileAccess.open(MUTED_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("1" if muted else "0")
	file.close()


# Key under which the leaderboard blob lives in FBInstant player data.
const CLOUD_KEY := "leaderboard"


# Combines the local board with one restored from the cloud.
#
# This lives here rather than in core/leaderboard.gd on purpose: cloud sync is
# a web-platform concern, and the Roku channel has no equivalent. Keeping it
# out of the core is what stops the two implementations drifting apart.
#
# Entries are per-game, so the same nickname legitimately repeats; the dedup
# key is the whole row. add_entry does the sorting, capping and validation, so
# a corrupted cloud row cannot poison the ranking.
static func merge_leaderboards(local_state: Dictionary, cloud_state: Dictionary) -> Dictionary:
	var merged := local_state
	var seen := {}
	for entry in local_state["entries"]:
		seen[_entry_key(entry)] = true
	for entry in cloud_state["entries"]:
		var key := _entry_key(entry)
		if seen.has(key):
			continue
		seen[key] = true
		merged = Leaderboard.add_entry(
			merged, str(entry["nickname"]), int(entry["score"]), str(entry["date"])
		)
	return merged


static func _entry_key(entry: Dictionary) -> String:
	return "%s|%s|%s" % [str(entry["nickname"]), str(entry["score"]), str(entry["date"])]


# Today's date as the dd/mm/yyyy string the leaderboard expects.
static func today_text() -> String:
	var now := Time.get_datetime_dict_from_system()
	return Leaderboard.format_date(int(now["day"]), int(now["month"]), int(now["year"]))
