class_name LeaderboardCases
extends RefCounted

# Unit tests for core/leaderboard.gd (identity, ranking, persistence).
# Ported from tests/cases/leaderboardCases.bs.


static func run_all() -> Array:
	return [
		{"name": "leaderboard: nickname validation rules", "collector": case_nickname_validation()},
		{"name": "leaderboard: date formatting is dd/mm/yyyy", "collector": case_date_format()},
		{"name": "leaderboard: add_entry records every game (duplicates allowed)", "collector": case_add_entry()},
		{"name": "leaderboard: ranking sorts by score then earliest date", "collector": case_ranking()},
		{"name": "leaderboard: top_score returns the rank-1 score", "collector": case_top_score()},
		{"name": "leaderboard: capacity is capped at 50 entries", "collector": case_cap()},
		{"name": "leaderboard: JSON round trip preserves entries", "collector": case_round_trip()},
		{"name": "leaderboard: malformed JSON degrades to empty", "collector": case_bad_json()},
		{"name": "leaderboard: malformed nickname/date is rejected", "collector": case_rejects_malformed()}
	]


static func case_nickname_validation() -> Dictionary:
	var c := TestAssert.new_collector()
	var ok := Leaderboard.validate_nickname("  Hector7  ")
	TestAssert.is_true(c, ok["valid"], "alphanumeric nickname is valid")
	TestAssert.equal(c, ok["value"], "Hector7", "nickname is trimmed")
	TestAssert.is_false(c, Leaderboard.validate_nickname("a")["valid"], "1 char is too short")
	TestAssert.is_true(c, Leaderboard.validate_nickname("ab")["valid"], "2 chars is the minimum")
	TestAssert.is_true(c, Leaderboard.validate_nickname("abcdefghijkl")["valid"], "12 chars is the maximum")
	TestAssert.is_false(c, Leaderboard.validate_nickname("abcdefghijklm")["valid"], "13 chars is too long")
	TestAssert.is_false(c, Leaderboard.validate_nickname("hec tor")["valid"], "spaces are rejected")
	TestAssert.is_false(c, Leaderboard.validate_nickname("hector!")["valid"], "symbols are rejected")
	TestAssert.is_false(c, Leaderboard.validate_nickname("    ")["valid"], "blank input is rejected")
	return c


static func case_date_format() -> Dictionary:
	var c := TestAssert.new_collector()
	TestAssert.equal(c, Leaderboard.format_date(5, 3, 2026), "05/03/2026", "single digits are zero padded")
	TestAssert.equal(c, Leaderboard.format_date(25, 12, 2026), "25/12/2026", "double digits unchanged")
	TestAssert.equal(c, Leaderboard.date_key("05/03/2026"), 20260305, "date key is yyyymmdd")
	TestAssert.is_true(
		c,
		Leaderboard.date_key("31/12/2025") < Leaderboard.date_key("01/01/2026"),
		"keys order across years"
	)
	return c


static func case_add_entry() -> Dictionary:
	var c := TestAssert.new_collector()
	var lb := Leaderboard.create()
	# Every game is its own entry; the same nickname may appear N times.
	lb = Leaderboard.add_entry(lb, "Hector", 100, "13/06/2026")
	lb = Leaderboard.add_entry(lb, "Mario", 98, "13/06/2026")
	lb = Leaderboard.add_entry(lb, "Hector", 95, "13/06/2026")
	TestAssert.equal(c, lb["entries"].size(), 3, "every game adds an entry")
	TestAssert.equal(c, lb["entries"][0]["nickname"], "Hector", "rank 1 nickname")
	TestAssert.equal(c, lb["entries"][0]["score"], 100, "rank 1 score")
	TestAssert.equal(c, lb["entries"][1]["nickname"], "Mario", "rank 2 by score")
	TestAssert.equal(c, lb["entries"][2]["nickname"], "Hector", "same nickname appears again")
	TestAssert.equal(c, lb["entries"][2]["score"], 95, "the lower game is kept as its own entry")
	# Casing is preserved as entered; no dedup or normalization.
	lb = Leaderboard.add_entry(lb, "HECTOR", 120, "14/06/2026")
	TestAssert.equal(c, lb["entries"].size(), 4, "a fourth game adds a fourth entry")
	TestAssert.equal(c, lb["entries"][0]["nickname"], "HECTOR", "new top entry, casing preserved")
	TestAssert.equal(c, lb["entries"][0]["score"], 120, "new top score")
	return c


static func case_ranking() -> Dictionary:
	var c := TestAssert.new_collector()
	var lb := Leaderboard.create()
	lb = Leaderboard.add_entry(lb, "Carol", 300, "05/06/2026")
	lb = Leaderboard.add_entry(lb, "Alice", 500, "06/06/2026")
	lb = Leaderboard.add_entry(lb, "Bob", 300, "01/06/2026")
	TestAssert.equal(c, lb["entries"][0]["nickname"], "Alice", "highest score first")
	TestAssert.equal(c, lb["entries"][1]["nickname"], "Bob", "tie broken by earliest date")
	TestAssert.equal(c, lb["entries"][2]["nickname"], "Carol", "later tie date ranks below")
	return c


static func case_top_score() -> Dictionary:
	var c := TestAssert.new_collector()
	var empty := Leaderboard.create()
	TestAssert.equal(c, Leaderboard.top_score(empty), 0, "empty leaderboard has top score 0")
	var lb := Leaderboard.add_entry(empty, "Bob", 300, "01/06/2026")
	TestAssert.equal(c, Leaderboard.top_score(lb), 300, "single entry is the top score")
	lb = Leaderboard.add_entry(lb, "Alice", 900, "02/06/2026")
	TestAssert.equal(c, Leaderboard.top_score(lb), 900, "top score is the rank-1 score, not insertion order")
	lb = Leaderboard.add_entry(lb, "Carol", 500, "03/06/2026")
	TestAssert.equal(c, Leaderboard.top_score(lb), 900, "a lower new entry does not change the top score")

	# Reproduces the reported bug: "new record" must compare against the
	# leaderboard #1, not a new player's (zero) personal best. With ABC at
	# 1169, a new player scoring 239 is NOT a record; 1200 is.
	var board := Leaderboard.add_entry(Leaderboard.create(), "ABC", 1169, "13/06/2026")
	var record := Leaderboard.top_score(board)
	TestAssert.is_false(c, 239 > record, "a new player below the #1 score is not a new record")
	TestAssert.is_true(c, 1200 > record, "beating the #1 score is a new record")
	return c


static func case_cap() -> Dictionary:
	var c := TestAssert.new_collector()
	var lb := Leaderboard.create()
	for i in range(1, 56):
		lb = Leaderboard.add_entry(lb, "player" + str(i), i * 10, "01/06/2026")
	TestAssert.equal(c, lb["entries"].size(), 50, "capped at 50 entries")
	TestAssert.equal(c, lb["entries"][0]["score"], 550, "best survives the cap")
	TestAssert.equal(c, lb["entries"][49]["score"], 60, "weakest kept is the 50th best")
	# The five lowest games (scores 10..50) are dropped from the bottom.
	TestAssert.is_true(c, Leaderboard.top_score(lb) == 550, "top score unaffected by the cap")
	return c


static func case_round_trip() -> Dictionary:
	var c := TestAssert.new_collector()
	var lb := Leaderboard.create()
	lb = Leaderboard.add_entry(lb, "Alice", 500, "06/06/2026")
	lb = Leaderboard.add_entry(lb, "Bob", 300, "01/06/2026")
	var json := Leaderboard.serialize(lb)
	var restored := Leaderboard.deserialize(json)
	TestAssert.equal(c, restored["entries"].size(), 2, "entry count survives")
	TestAssert.equal(c, restored["entries"][0]["nickname"], "Alice", "order survives")
	TestAssert.equal(c, restored["entries"][0]["score"], 500, "score survives")
	TestAssert.equal(c, restored["entries"][1]["date"], "01/06/2026", "date survives")
	return c


static func case_bad_json() -> Dictionary:
	var c := TestAssert.new_collector()
	TestAssert.equal(c, Leaderboard.deserialize("not json at all")["entries"].size(), 0, "garbage text yields empty")
	TestAssert.equal(c, Leaderboard.deserialize("[1,2,3]")["entries"].size(), 0, "wrong shape yields empty")
	TestAssert.equal(c, Leaderboard.deserialize("{}")["entries"].size(), 0, "missing entries yields empty")
	var mixed := '{"entries": [{"nickname": "Ok", "score": 10, "date": "01/06/2026"}, {"nickname": 5}, "junk"]}'
	var restored := Leaderboard.deserialize(mixed)
	TestAssert.equal(c, restored["entries"].size(), 1, "malformed entries are skipped")
	TestAssert.equal(c, restored["entries"][0]["nickname"], "Ok", "valid entry survives")
	return c


static func case_rejects_malformed() -> Dictionary:
	var c := TestAssert.new_collector()
	# add_entry drops invalid input instead of corrupting the ranking.
	var lb := Leaderboard.create()
	lb = Leaderboard.add_entry(lb, "Hector", 100, "13/06/2026")
	lb = Leaderboard.add_entry(lb, "Hector", 200, "2026-13-06")
	TestAssert.equal(c, lb["entries"].size(), 1, "malformed date is rejected")
	lb = Leaderboard.add_entry(lb, "x", 300, "14/06/2026")
	TestAssert.equal(c, lb["entries"].size(), 1, "too-short nickname is rejected")
	lb = Leaderboard.add_entry(lb, "  Bob  ", 90, "14/06/2026")
	TestAssert.equal(c, lb["entries"].size(), 2, "valid padded nickname is accepted")
	TestAssert.equal(c, lb["entries"][1]["nickname"], "Bob", "accepted nickname is trimmed")
	TestAssert.equal(c, Leaderboard.is_valid_date_text("32/01/2026"), false, "day out of range rejected")
	TestAssert.equal(c, Leaderboard.is_valid_date_text("01/13/2026"), false, "month out of range rejected")
	TestAssert.equal(c, Leaderboard.is_valid_date_text("14/06/2026"), true, "well-formed date accepted")

	# deserialize skips a row with a malformed date.
	var bad := '{"entries": [{"nickname": "Al", "score": 5, "date": "bad-date!!"}]}'
	TestAssert.equal(c, Leaderboard.deserialize(bad)["entries"].size(), 0, "corrupted-date row is dropped on load")
	return c
