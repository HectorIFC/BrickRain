class_name Leaderboard
extends RefCounted

# Leaderboard rules: every playthrough is recorded as its own entry (the same
# nickname can appear multiple times), ranked by score descending with an
# earliest-date tie-break, capped at max_entries(), plus JSON (de)serialization
# for persistence.
# Pure module: storage I/O lives in the platform layer, never here.
#
# Translated from source/logic/leaderboard.bs. Keep both implementations in
# step. The serialized shape ({"entries":[{nickname,score,date}]}) is
# deliberately identical to the Roku registry payload.
#
# Porting note: BrightScript mid() is 1-indexed, GDScript substr() is
# 0-indexed. Every offset below is shifted by one accordingly.
#
# The level field arrived after the first releases shipped, so it is optional
# on the wire: entries persisted without it deserialize with level 0, which
# the UIs render as "unknown" rather than inventing a value.

static var _nickname_pattern: RegEx = null


static func max_entries() -> int:
	return 50


static func create() -> Dictionary:
	return {"entries": []}


static func _nickname_regex() -> RegEx:
	if _nickname_pattern == null:
		_nickname_pattern = RegEx.create_from_string("^[A-Za-z0-9]+$")
	return _nickname_pattern


# Validates and normalizes a nickname: trimmed, 2-12 chars, alphanumeric.
# Returns { valid, value, reason }.
static func validate_nickname(nickname: String) -> Dictionary:
	var trimmed := nickname.strip_edges()
	if trimmed.length() < 2 or trimmed.length() > 12:
		return {"valid": false, "value": trimmed, "reason": "Nickname must be 2 to 12 characters long"}
	if _nickname_regex().search(trimmed) == null:
		return {"valid": false, "value": trimmed, "reason": "Only letters and digits are allowed"}
	return {"valid": true, "value": trimmed, "reason": ""}


# Formats a calendar date as dd/mm/yyyy.
static func format_date(day: int, month: int, year: int) -> String:
	return pad2(day) + "/" + pad2(month) + "/" + str(year)


# Sortable integer key (yyyymmdd) for a dd/mm/yyyy date string.
static func date_key(date_text: String) -> int:
	if date_text.length() != 10:
		return 0
	var day := date_text.substr(0, 2).to_int()
	var month := date_text.substr(3, 2).to_int()
	var year := date_text.substr(6, 4).to_int()
	return year * 10000 + month * 100 + day


# Records one finished game as its own entry. Every playthrough is kept, so
# the same nickname can appear multiple times (e.g. Hector 100, Mario 98,
# Hector 95). The result is sorted (score desc, earliest date wins ties) and
# capped at max_entries(); entries beyond the cap drop from the bottom.
static func add_entry(leaderboard_state: Dictionary, nickname: String, score: int, date_text: String, level: int = 0) -> Dictionary:
	# Defensive: skip malformed input so a bad nickname/date can never corrupt
	# ranking (a malformed date would key as 0 and win tie-breaks).
	var nickname_check := validate_nickname(nickname)
	if not bool(nickname_check["valid"]):
		return leaderboard_state
	if not is_valid_date_text(date_text):
		return leaderboard_state

	var entries := []
	for entry in leaderboard_state["entries"]:
		entries.append(clone_entry(entry))
	entries.append({"nickname": nickname_check["value"], "score": score, "date": date_text, "level": level})
	return {"entries": cap_entries(sort_entries(entries))}


# True when date_text is a well-formed dd/mm/yyyy calendar date.
static func is_valid_date_text(date_text: String) -> bool:
	if date_text.length() != 10:
		return false
	if date_text.substr(2, 1) != "/" or date_text.substr(5, 1) != "/":
		return false
	var day := date_text.substr(0, 2).to_int()
	var month := date_text.substr(3, 2).to_int()
	var year := date_text.substr(6, 4).to_int()
	return day >= 1 and day <= 31 and month >= 1 and month <= 12 and year >= 1


# The top (rank 1) score on the leaderboard, or 0 when it is empty. This is
# the record to beat — entries are kept sorted by score descending, so the
# first entry holds the highest score.
static func top_score(leaderboard_state: Dictionary) -> int:
	var entries: Array = leaderboard_state["entries"]
	if entries.size() == 0:
		return 0
	return int(entries[0]["score"])


# Insertion sort: score descending, ties broken by earliest date.
# At most 50 + 1 entries ever flow through here, so O(n^2) is fine.
# (BrightScript needed a hand-rolled insert_at helper; Array.insert is the
# exact equivalent here.)
static func sort_entries(entries: Array) -> Array:
	var sorted := []
	for entry in entries:
		var inserted := false
		for i in range(sorted.size()):
			if ranks_before(entry, sorted[i]):
				sorted.insert(i, entry)
				inserted = true
				break
		if not inserted:
			sorted.append(entry)
	return sorted


static func ranks_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["score"]) != int(b["score"]):
		return int(a["score"]) > int(b["score"])
	return date_key(a["date"]) < date_key(b["date"])


static func cap_entries(entries: Array) -> Array:
	if entries.size() <= max_entries():
		return entries
	return entries.slice(0, max_entries())


static func serialize(leaderboard_state: Dictionary) -> String:
	return JSON.stringify(leaderboard_state)


# Parses serialized state, skipping malformed entries. Any invalid
# payload degrades to an empty leaderboard instead of crashing.
static func deserialize(json_text: String) -> Dictionary:
	var parsed = JSON.parse_string(json_text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return create()
	if not parsed.has("entries") or typeof(parsed["entries"]) != TYPE_ARRAY:
		return create()
	var entries := []
	for entry in parsed["entries"]:
		if is_valid_entry(entry):
			entries.append({
				"nickname": entry["nickname"],
				"score": int(entry["score"]),
				"date": entry["date"],
				"level": entry_level(entry)
			})
	return {"entries": cap_entries(sort_entries(entries))}


static func is_valid_entry(entry) -> bool:
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	if not entry.has("nickname") or typeof(entry["nickname"]) != TYPE_STRING:
		return false
	if not bool(validate_nickname(entry["nickname"])["valid"]):
		return false
	if not entry.has("score") or not is_number(entry["score"]):
		return false
	if not entry.has("date") or typeof(entry["date"]) != TYPE_STRING:
		return false
	if not is_valid_date_text(entry["date"]):
		return false
	return true


# The stored level, or 0 for entries persisted before the field existed (or
# carrying a malformed value) — "unknown", never a made-up number.
static func entry_level(entry: Dictionary) -> int:
	if entry.has("level") and is_number(entry["level"]):
		return int(entry["level"])
	return 0


static func is_number(value) -> bool:
	if value == null:
		return false
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func clone_entry(entry: Dictionary) -> Dictionary:
	return {
		"nickname": entry["nickname"],
		"score": entry["score"],
		"date": entry["date"],
		"level": entry_level(entry)
	}


static func pad2(value: int) -> String:
	if value < 10:
		return "0" + str(value)
	return str(value)
