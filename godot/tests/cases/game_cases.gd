class_name GameCases
extends RefCounted

# Integration tests for core/game.gd: the full state machine wiring
# board + piece + bag + score, driven by scripted inputs and injected time.
# Ported from tests/cases/gameCases.bs.


static func run_all() -> Array:
	return [
		{"name": "game: creates with a spawned piece and a 3-piece preview", "collector": case_create()},
		{"name": "game: gravity pulls the piece down on level-1 cadence", "collector": case_gravity()},
		{"name": "game: horizontal movement stops at the walls", "collector": case_shift()},
		{"name": "game: soft drop moves down and scores 1 per cell", "collector": case_soft_drop()},
		{"name": "game: hard drop locks instantly and scores 2 per cell", "collector": case_hard_drop()},
		{"name": "game: SRS wall kick rotates a piece off the wall", "collector": case_srs_wall_kick()},
		{"name": "game: lock delay holds for 500 ms after grounding", "collector": case_lock_delay()},
		{"name": "game: lock delay resets are capped at 15", "collector": case_lock_reset_cap()},
		{"name": "game: quad clear plus level-up in one flow", "collector": case_quad_clear_level_up()},
		{"name": "game: blocked spawn ends the game", "collector": case_game_over()},
		{"name": "game: pause and resume preserve the whole state", "collector": case_pause_resume()},
		{"name": "game: hold stashes once per piece and swaps back", "collector": case_hold()},
		{"name": "game: ghost piece projects the hard-drop landing", "collector": case_ghost()},
		{"name": "game: preview queue matches the pieces actually dealt", "collector": case_next_queue_chain()},
		{"name": "game: seeded full game reproduces the exact final score", "collector": case_seeded_full_game()},
		{"name": "game: combo chain builds, pays and resets on a dry lock", "collector": case_combo_chain()},
		{"name": "game: back-to-back quads pay 1200 and survive a dry lock", "collector": case_back_to_back()}
	]


# Fills row y from column from_x to to_x inclusive with a settled block.
static func prefill_row(board_state: Dictionary, y: int, from_x: int, to_x: int) -> Dictionary:
	var cells := []
	for x in range(from_x, to_x + 1):
		cells.append({"x": x, "y": y})
	return Board.with_cells(board_state, cells, 1)


static func case_combo_chain() -> Dictionary:
	var c := TestAssert.new_collector()
	var s := Game.create(1)
	# First clear: horizontal I into the 4-cell gap of the bottom row.
	# 20 cells of hard drop (x2 = 40) + single (100), combo 0 pays nothing.
	s["board"] = prefill_row(s["board"], 21, 0, 5)
	s["active"] = {"piece_type": "I", "rotation": 0, "x": 6, "y": 0}
	s = Game.hard_drop(s)
	TestAssert.equal(c, s["score"]["score"], 140, "first clear: 40 drop + 100, no combo bonus")

	# Second consecutive clear: combo 1 pays 50 x 1 x level.
	s["board"] = prefill_row(s["board"], 21, 0, 5)
	s["active"] = {"piece_type": "I", "rotation": 0, "x": 6, "y": 0}
	s = Game.hard_drop(s)
	TestAssert.equal(c, s["score"]["score"], 330, "second clear adds 40 + 100 + 50 combo")
	TestAssert.has_event(c, s["events"], "combo", "combo event emitted from combo 1")

	# Dry lock resets the chain.
	s["active"] = {"piece_type": "O", "rotation": 0, "x": 4, "y": 0}
	s = Game.hard_drop(s)
	TestAssert.equal(c, s["combo"], -1, "dry lock resets combo")

	# Next clear starts over at combo 0: no bonus, no combo event.
	s["board"] = prefill_row(s["board"], 21, 0, 5)
	s["active"] = {"piece_type": "I", "rotation": 0, "x": 6, "y": 0}
	s = Game.hard_drop(s)
	TestAssert.equal(c, s["combo"], 0, "chain restarts at 0")
	var has_combo := false
	for event in s["events"]:
		if event["kind"] == "combo":
			has_combo = true
	TestAssert.is_false(c, has_combo, "combo 0 emits no combo event")
	return c


# Drops a vertical I into the empty right column of a 4-row stack.
static func drop_quad(s: Dictionary) -> Dictionary:
	var board_state: Dictionary = s["board"]
	for y in range(18, 22):
		board_state = prefill_row(board_state, y, 0, 8)
	s["board"] = board_state
	s["active"] = {"piece_type": "I", "rotation": 0, "x": 3, "y": 0}
	s = Game.rotate_cw(s)
	for _i in range(4):
		s = Game.move_right(s)
	return Game.hard_drop(s)


static func case_back_to_back() -> Dictionary:
	var c := TestAssert.new_collector()
	var s := Game.create(1)

	# First quad: not armed yet, 36 drop + 800.
	s["score"] = {"score": 0, "lines": 0, "level": 1}
	s = drop_quad(s)
	TestAssert.equal(c, s["score"]["score"], 836, "first quad pays 800")

	# Second quad back to back: 36 drop + 1200 + 50 (combo 1).
	s["score"] = {"score": 0, "lines": 0, "level": 1}
	s = drop_quad(s)
	TestAssert.equal(c, s["score"]["score"], 1286, "b2b quad pays 1200 plus combo 1")

	# A dry lock breaks the combo but NOT the back-to-back arming.
	s["active"] = {"piece_type": "O", "rotation": 0, "x": 4, "y": 0}
	s = Game.hard_drop(s)
	s["score"] = {"score": 0, "lines": 0, "level": 1}
	s = drop_quad(s)
	TestAssert.equal(c, s["score"]["score"], 1236, "b2b survives a dry lock; combo restarted at 0")

	# An easier clear breaks back-to-back: the next quad is back to 800.
	s["board"] = prefill_row(s["board"], 21, 0, 5)
	s["active"] = {"piece_type": "I", "rotation": 0, "x": 6, "y": 0}
	s = Game.hard_drop(s)
	s["score"] = {"score": 0, "lines": 0, "level": 1}
	s = drop_quad(s)
	# Combo kept climbing through the single clear: this is its 3rd link
	# (combo 2), so the bonus is 100 while the quad is back to plain 800.
	TestAssert.equal(c, s["score"]["score"], 936, "single clear disarms b2b (36 + 800 + 100 combo)")
	return c


# --- helpers ---


static func filled_cell_count(board_state: Dictionary) -> int:
	var total := 0
	for value in board_state["grid"]:
		if int(value) != 0:
			total += 1
	return total


# Builds a playing state with a known active piece on an empty board.
static func state_with_piece(piece_type: String, x: int, y: int) -> Dictionary:
	var s := Game.create(1)
	s["active"] = {"piece_type": piece_type, "rotation": 0, "x": x, "y": y}
	return s


# Deterministic scripted game: a tiny greedy bot drives every piece, in
# spawn orientation, to the column that minimizes holes and stack height
# (favoring clears). It clears lines along the way but cannot rotate, so
# S/Z hole buildup eventually tops the game out — a full playthrough.
static func play_scripted_game(seed: int) -> Dictionary:
	var s := Game.create(seed)
	var pieces := 0
	while s["status"] == "playing" and pieces < 400:
		pieces += 1
		var target_x := choose_column(s)
		var shifts := target_x - int(s["active"]["x"])
		for _i in range(abs(shifts)):
			if shifts < 0:
				s = Game.move_left(s)
			else:
				s = Game.move_right(s)
		s = Game.hard_drop(s)
	return {"state": s, "pieces": pieces}


static func choose_column(s: Dictionary) -> int:
	var best_cost := 999999
	var best_x := int(s["active"]["x"])
	for x in range(-2, int(s["board"]["width"])):
		var cost := placement_cost(s, x)
		if cost < best_cost:
			best_cost = cost
			best_x = x
	return best_x


# Cost of hard-dropping the active piece (spawn rotation) at column x:
# simulates the landing on a copy of the board via the pure board API.
static func placement_cost(s: Dictionary, x: int) -> int:
	var shape := Piece.cells_for(s["active"]["piece_type"], 0)
	var board_state: Dictionary = s["board"]
	var dy := 0
	while true:
		var cells := []
		for cell in shape:
			cells.append({"x": x + int(cell["x"]), "y": dy + 1 + int(cell["y"])})
		if not Board.can_place(board_state, cells):
			break
		dy += 1
	var landed := []
	for cell in shape:
		landed.append({"x": x + int(cell["x"]), "y": dy + int(cell["y"])})
	if not Board.can_place(board_state, landed):
		return 999999
	var b := Board.with_cells(board_state, landed, 1)
	var cleared := Board.full_rows(b)
	b = Board.clear_rows(b, cleared)
	var holes := 0
	var heights := 0
	for column in range(10):
		var covered := false
		for y in range(int(b["height"])):
			if Board.cell_at(b, column, y) != 0:
				if not covered:
					covered = true
					heights += int(b["height"]) - y
			elif covered:
				holes += 1
	return holes * 40 + heights - cleared.size() * 500


# --- cases ---


static func case_create() -> Dictionary:
	var c := TestAssert.new_collector()
	var s := Game.create(1)
	TestAssert.equal(c, s["status"], "playing", "game starts playing")
	TestAssert.is_true(c, s["active"] != null, "a piece is spawned")
	TestAssert.equal(c, s["active"]["y"], 0, "piece spawns at the top")
	TestAssert.equal(c, s["score"]["score"], 0, "score starts at 0")
	TestAssert.equal(c, Game.next_types(s).size(), 3, "preview shows 3 pieces")
	TestAssert.equal(c, filled_cell_count(s["board"]), 0, "board starts empty")
	return c


static func case_gravity() -> Dictionary:
	var c := TestAssert.new_collector()
	var s := Game.create(1)
	s = Game.advance(s, 999)
	TestAssert.equal(c, s["active"]["y"], 0, "999 ms is not enough at level 1")
	s = Game.advance(s, 1)
	TestAssert.equal(c, s["active"]["y"], 1, "piece falls after 1000 ms accumulated")
	s = Game.advance(s, 3000)
	TestAssert.equal(c, s["active"]["y"], 4, "large deltas apply multiple gravity steps")
	return c


static func case_shift() -> Dictionary:
	var c := TestAssert.new_collector()
	var s := state_with_piece("T", 3, 5)
	var moved := Game.move_left(s)
	TestAssert.equal(c, moved["active"]["x"], 2, "left shift moves one column")
	TestAssert.has_event(c, moved["events"], "move", "successful shift emits move")
	for _i in range(10):
		moved = Game.move_left(moved)
	TestAssert.equal(c, moved["active"]["x"], 0, "T stops with its leftmost cell at the wall")
	var blocked := Game.move_left(moved)
	TestAssert.equal(c, blocked["events"].size(), 0, "blocked shift emits nothing")
	for _i in range(20):
		moved = Game.move_right(moved)
	TestAssert.equal(c, moved["active"]["x"], 7, "T stops with its rightmost cell at the wall")
	return c


static func case_soft_drop() -> Dictionary:
	var c := TestAssert.new_collector()
	var s := state_with_piece("T", 3, 5)
	var dropped := Game.soft_drop(s)
	TestAssert.equal(c, dropped["active"]["y"], 6, "soft drop moves one row down")
	TestAssert.equal(c, dropped["score"]["score"], 1, "soft drop scores 1 per cell")
	TestAssert.has_event(c, dropped["events"], "move", "soft drop emits move")
	return c


static func case_hard_drop() -> Dictionary:
	var c := TestAssert.new_collector()
	var s := state_with_piece("T", 3, 0)
	var ghost := Game.ghost_cells(s)
	var start_cells := Game.active_cells(s)
	var distance := int(ghost[0]["y"]) - int(start_cells[0]["y"])
	var dropped := Game.hard_drop(s)
	TestAssert.equal(c, dropped["score"]["score"], distance * 2, "hard drop scores 2 per cell")
	TestAssert.has_event(c, dropped["events"], "hardDrop", "hard drop event emitted")
	TestAssert.has_event(c, dropped["events"], "lock", "piece locked without clearing")
	TestAssert.equal(c, filled_cell_count(dropped["board"]), 4, "piece written to the board")
	for cell in ghost:
		TestAssert.is_true(
			c,
			Board.cell_at(dropped["board"], int(cell["x"]), int(cell["y"])) != 0,
			"landed on the ghost projection"
		)
	TestAssert.equal(c, dropped["active"]["y"], 0, "next piece spawned at the top")
	return c


static func case_srs_wall_kick() -> Dictionary:
	var c := TestAssert.new_collector()
	var s := state_with_piece("T", 3, 5)
	s = Game.rotate_cw(s)
	TestAssert.equal(c, s["active"]["rotation"], 1, "free rotation succeeds in place")
	for _i in range(10):
		s = Game.move_left(s)
	TestAssert.equal(c, s["active"]["x"], -1, "state-1 T hugs the left wall at x=-1")
	var kicked := Game.rotate_cw(s)
	TestAssert.equal(c, kicked["active"]["rotation"], 2, "rotation against the wall succeeds")
	TestAssert.equal(c, kicked["active"]["x"], 0, "wall kick pushed the piece right")
	TestAssert.has_event(c, kicked["events"], "rotate", "kick still emits rotate")
	return c


static func case_lock_delay() -> Dictionary:
	var c := TestAssert.new_collector()
	var s := Game.create(1)
	s = Game.advance(s, 25000)
	TestAssert.equal(c, filled_cell_count(s["board"]), 0, "grounded piece does not lock instantly")
	s = Game.advance(s, 499)
	TestAssert.equal(c, filled_cell_count(s["board"]), 0, "still floating at 499 ms")
	s = Game.advance(s, 1)
	TestAssert.equal(c, filled_cell_count(s["board"]), 4, "locks when the 500 ms delay expires")
	TestAssert.equal(c, s["active"]["y"], 0, "next piece spawned")
	return c


static func case_lock_reset_cap() -> Dictionary:
	var c := TestAssert.new_collector()
	var s := Game.create(1)
	s = Game.advance(s, 25000)
	# 15 successful moves, each resetting the lock timer before it expires.
	for i in range(1, 16):
		if i % 2 == 1:
			s = Game.move_left(s)
		else:
			s = Game.move_right(s)
		s = Game.advance(s, 400)
		TestAssert.equal(c, filled_cell_count(s["board"]), 0, "reset " + str(i) + " keeps the piece alive")
	TestAssert.equal(c, s["lock_resets"], 15, "reset budget exhausted")
	# The 16th move succeeds but no longer resets the timer.
	s = Game.move_right(s)
	s = Game.advance(s, 400)
	TestAssert.equal(c, filled_cell_count(s["board"]), 4, "piece locks once resets are capped")
	return c


static func case_quad_clear_level_up() -> Dictionary:
	var c := TestAssert.new_collector()
	var s := Game.create(1)
	# Stack: bottom 4 rows filled except the rightmost column.
	var board_state: Dictionary = s["board"]
	for y in range(18, 22):
		var cells := []
		for x in range(9):
			cells.append({"x": x, "y": y})
		board_state = Board.with_cells(board_state, cells, 1)
	s["board"] = board_state
	s["score"] = {"score": 0, "lines": 6, "level": 1}
	s["active"] = {"piece_type": "I", "rotation": 0, "x": 3, "y": 0}
	# Vertical I into the right column: rotate, slide right, hard drop.
	s = Game.rotate_cw(s)
	for _i in range(4):
		s = Game.move_right(s)
	s = Game.hard_drop(s)
	TestAssert.has_event(c, s["events"], "lineClear", "quad clear detected")
	TestAssert.has_event(c, s["events"], "levelUp", "level-up emitted in the same flow")
	TestAssert.equal(c, s["score"]["lines"], 10, "6 + 4 cleared lines")
	TestAssert.equal(c, s["score"]["level"], 2, "level 2 reached exactly at 10 lines")
	# 18 cells of hard drop (x2) + quad at level 1 (800).
	TestAssert.equal(c, s["score"]["score"], 836, "score = 36 drop + 800 quad")
	TestAssert.equal(c, filled_cell_count(s["board"]), 0, "stack fully cleared")
	return c


static func case_game_over() -> Dictionary:
	var c := TestAssert.new_collector()
	var s := Game.create(2)
	var last_events := []
	for _i in range(100):
		if s["status"] != "playing":
			break
		s = Game.hard_drop(s)
		last_events = s["events"]
	TestAssert.equal(c, s["status"], "gameOver", "stacking without clearing tops out")
	TestAssert.is_true(c, s["active"] == null, "no active piece after game over")
	TestAssert.has_event(c, last_events, "gameOver", "game over event emitted")
	# Inputs are ignored after the game ends.
	var after := Game.hard_drop(s)
	TestAssert.equal(c, after["status"], "gameOver", "hard drop ignored after game over")
	TestAssert.equal(c, after["events"].size(), 0, "no events after game over")
	return c


static func case_pause_resume() -> Dictionary:
	var c := TestAssert.new_collector()
	var s := Game.create(1)
	s = Game.advance(s, 2000)
	var y_before = s["active"]["y"]
	var score_before = s["score"]["score"]
	var paused := Game.pause(s)
	TestAssert.equal(c, paused["status"], "paused", "pause switches status")
	TestAssert.has_event(c, paused["events"], "pause", "pause event emitted")
	paused = Game.advance(paused, 10000)
	TestAssert.equal(c, paused["active"]["y"], y_before, "time stands still while paused")
	paused = Game.move_left(paused)
	TestAssert.equal(c, paused["active"]["x"], s["active"]["x"], "input ignored while paused")
	var resumed := Game.resume(paused)
	TestAssert.equal(c, resumed["status"], "playing", "resume restores play")
	TestAssert.equal(c, resumed["active"]["y"], y_before, "piece position preserved")
	TestAssert.equal(c, resumed["score"]["score"], score_before, "score preserved")
	return c


static func case_hold() -> Dictionary:
	var c := TestAssert.new_collector()
	var s := Game.create(9)
	var first_type = s["active"]["piece_type"]
	var expected_incoming = Game.next_types(s, 1)[0]
	var held := Game.hold_swap(s)
	TestAssert.equal(c, held["hold"], first_type, "active piece stashed")
	TestAssert.equal(c, held["active"]["piece_type"], expected_incoming, "next piece took its place")
	TestAssert.is_false(c, held["can_hold"], "hold consumed for this piece")
	TestAssert.has_event(c, held["events"], "hold", "hold event emitted")
	var again := Game.hold_swap(held)
	TestAssert.equal(c, again["active"]["piece_type"], expected_incoming, "second hold is a no-op")
	TestAssert.equal(c, again["events"].size(), 0, "no event for the refused hold")
	# Locking re-arms hold, and swapping returns the stashed piece.
	var locked := Game.hard_drop(held)
	TestAssert.is_true(c, locked["can_hold"], "hold available again after lock")
	var swapped := Game.hold_swap(locked)
	TestAssert.equal(c, swapped["active"]["piece_type"], first_type, "stashed piece comes back")
	return c


static func case_ghost() -> Dictionary:
	var c := TestAssert.new_collector()
	var s := state_with_piece("L", 3, 2)
	var ghost := Game.ghost_cells(s)
	TestAssert.equal(c, ghost.size(), 4, "ghost has 4 cells")
	TestAssert.is_true(c, Board.can_place(s["board"], ghost), "ghost rests on a free spot")
	var below := []
	for cell in ghost:
		below.append({"x": cell["x"], "y": int(cell["y"]) + 1})
	TestAssert.is_false(c, Board.can_place(s["board"], below), "ghost cannot fall further")
	var active := Game.active_cells(s)
	for i in range(4):
		TestAssert.equal(c, ghost[i]["x"], active[i]["x"], "ghost keeps the piece columns")
	return c


static func case_next_queue_chain() -> Dictionary:
	var c := TestAssert.new_collector()
	var s := Game.create(3)
	var expected := Game.next_types(s, 3)
	for i in range(3):
		s = Game.hard_drop(s)
		TestAssert.equal(
			c,
			s["active"]["piece_type"],
			expected[i],
			"drop " + str(i + 1) + " spawns preview piece " + str(i + 1)
		)
	return c


static func case_seeded_full_game() -> Dictionary:
	var c := TestAssert.new_collector()
	var first := play_scripted_game(23)
	var second := play_scripted_game(23)
	TestAssert.equal(c, first["state"]["status"], "gameOver", "scripted game reaches game over")
	TestAssert.equal(
		c, second["state"]["score"]["score"], first["state"]["score"]["score"], "same seed, same final score"
	)
	TestAssert.equal(
		c, second["state"]["score"]["lines"], first["state"]["score"]["lines"], "same seed, same line count"
	)
	TestAssert.equal(c, second["pieces"], first["pieces"], "same seed, same piece count")
	# Golden values pin the exact outcome of seed 23 with this bot. They are
	# asserted identically in tests/cases/gameCases.bs — if these two ever
	# disagree, the Roku and Godot cores have drifted apart.
	TestAssert.equal(c, first["state"]["score"]["score"], 1538, "golden final score")
	TestAssert.equal(c, first["state"]["score"]["lines"], 5, "golden line count")
	TestAssert.equal(c, first["pieces"], 38, "golden piece count")
	return c
