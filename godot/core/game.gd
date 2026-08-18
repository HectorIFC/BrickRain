class_name Game
extends RefCounted

# Game state machine: spawn -> fall -> lock -> clear -> spawn / game over.
# Pure module: time is injected via advance(delta_ms), input arrives as
# function calls, results come back as a new state Dictionary whose `events`
# array tells the UI layer what happened (for sounds and rendering).
#
# Event kinds emitted: move, rotate, hardDrop, lock, lineClear, levelUp,
# hold, pause, resume, gameOver. These strings are deliberately identical to
# the BrightScript implementation so both shells speak one event vocabulary.
#
# Translated from source/logic/game.bs. Keep both implementations in step.


static func lock_delay_ms() -> int:
	return 500


static func max_lock_resets() -> int:
	return 15


static func preview_count() -> int:
	return 3


# Creates a new game with the first piece already spawned.
# Pass a positive seed for a fully deterministic game.
static func create(seed: int = -1) -> Dictionary:
	var state := {
		"board": Board.create(),
		"bag": Bag.create(seed),
		"score": Score.create(),
		"active": null,
		"hold": "",
		"can_hold": true,
		"status": "playing",
		"gravity_accum_ms": 0,
		"lock_timer_ms": 0,
		"lock_resets": 0,
		"combo": -1,
		"b2b_armed": false,
		"events": []
	}
	return spawn_next(state)


# Advances game time. Gravity pulls the piece down while airborne; once
# grounded the 500 ms lock delay runs and finally locks the piece.
static func advance(state: Dictionary, delta_ms: int) -> Dictionary:
	if state["status"] != "playing" or state["active"] == null:
		return clone_state(state)
	var s := clone_state(state)
	if is_grounded(s):
		s["gravity_accum_ms"] = 0
		s["lock_timer_ms"] = int(s["lock_timer_ms"]) + delta_ms
		if int(s["lock_timer_ms"]) >= lock_delay_ms():
			s = lock_active(s)
	else:
		s["lock_timer_ms"] = 0
		s["gravity_accum_ms"] = int(s["gravity_accum_ms"]) + delta_ms
		var interval := Score.gravity_ms(int(s["score"]["level"]))
		while int(s["gravity_accum_ms"]) >= interval:
			s["gravity_accum_ms"] = int(s["gravity_accum_ms"]) - interval
			if can_move_to(s, int(s["active"]["x"]), int(s["active"]["y"]) + 1, int(s["active"]["rotation"])):
				s["active"]["y"] = int(s["active"]["y"]) + 1
			else:
				break
	return s


static func move_left(state: Dictionary) -> Dictionary:
	return shift(state, -1)


static func move_right(state: Dictionary) -> Dictionary:
	return shift(state, 1)


# Soft drop: one cell down, +1 point per cell, driven by player input.
static func soft_drop(state: Dictionary) -> Dictionary:
	if state["status"] != "playing" or state["active"] == null:
		return clone_state(state)
	var s := clone_state(state)
	if can_move_to(s, int(s["active"]["x"]), int(s["active"]["y"]) + 1, int(s["active"]["rotation"])):
		s["active"]["y"] = int(s["active"]["y"]) + 1
		s["score"] = Score.add_drop_points(s["score"], 1, 1)
		s["events"].append({"kind": "move"})
	return s


# Hard drop: instant fall (+2 points per cell) and immediate lock.
static func hard_drop(state: Dictionary) -> Dictionary:
	if state["status"] != "playing" or state["active"] == null:
		return clone_state(state)
	var s := clone_state(state)
	var distance := 0
	while can_move_to(s, int(s["active"]["x"]), int(s["active"]["y"]) + 1, int(s["active"]["rotation"])):
		s["active"]["y"] = int(s["active"]["y"]) + 1
		distance += 1
	s["score"] = Score.add_drop_points(s["score"], distance, 2)
	s["events"].append({"kind": "hardDrop"})
	return lock_active(s)


static func rotate_cw(state: Dictionary) -> Dictionary:
	return rotate(state, 1)


static func rotate_ccw(state: Dictionary) -> Dictionary:
	return rotate(state, -1)


# SRS rotation: tries each wall-kick offset until one fits.
# Kick tables use +y = up, so dy is SUBTRACTED on this y-down grid.
static func rotate(state: Dictionary, direction: int) -> Dictionary:
	if state["status"] != "playing" or state["active"] == null:
		return clone_state(state)
	var s := clone_state(state)
	var from_rot := int(s["active"]["rotation"])
	var to_rot := (((from_rot + direction) % 4) + 4) % 4
	var kicks := Piece.kick_table(s["active"]["piece_type"], from_rot, to_rot)
	var was_grounded := is_grounded(s)
	for kick in kicks:
		var kicked_x := int(s["active"]["x"]) + int(kick["x"])
		var kicked_y := int(s["active"]["y"]) - int(kick["y"])
		if can_move_to(s, kicked_x, kicked_y, to_rot):
			s["active"]["x"] = kicked_x
			s["active"]["y"] = kicked_y
			s["active"]["rotation"] = to_rot
			apply_lock_reset(s, was_grounded)
			s["events"].append({"kind": "rotate"})
			return s
	return s


# Hold: stashes the active piece; once per piece (resets when one locks).
static func hold_swap(state: Dictionary) -> Dictionary:
	if state["status"] != "playing" or state["active"] == null or not bool(state["can_hold"]):
		return clone_state(state)
	var s := clone_state(state)
	var stashed_type: String = s["active"]["piece_type"]
	var incoming_type: String
	if s["hold"] == "":
		var dealt := Bag.deal(Bag.ensure_queue(s["bag"], preview_count() + 1))
		s["bag"] = dealt["bag"]
		incoming_type = dealt["piece_type"]
	else:
		incoming_type = s["hold"]
	s["hold"] = stashed_type
	s["can_hold"] = false
	s["lock_timer_ms"] = 0
	s["lock_resets"] = 0
	s["gravity_accum_ms"] = 0
	s["events"].append({"kind": "hold"})
	return place_at_spawn(s, incoming_type)


static func pause(state: Dictionary) -> Dictionary:
	var s := clone_state(state)
	if s["status"] == "playing":
		s["status"] = "paused"
		s["events"].append({"kind": "pause"})
	return s


static func resume(state: Dictionary) -> Dictionary:
	var s := clone_state(state)
	if s["status"] == "paused":
		s["status"] = "playing"
		s["events"].append({"kind": "resume"})
	return s


# Absolute board cells occupied by the active piece.
static func active_cells(state: Dictionary) -> Array:
	if state["active"] == null:
		return []
	return absolute_cells(state["active"])


# Where the active piece would land on a hard drop (for the ghost piece).
static func ghost_cells(state: Dictionary) -> Array:
	if state["active"] == null:
		return []
	var active: Dictionary = state["active"]
	var ghost_y := int(active["y"])
	while can_move_to(state, int(active["x"]), ghost_y + 1, int(active["rotation"])):
		ghost_y += 1
	return absolute_cells({
		"piece_type": active["piece_type"],
		"rotation": active["rotation"],
		"x": active["x"],
		"y": ghost_y
	})


# Upcoming piece types (the visible "next" queue).
static func next_types(state: Dictionary, count: int = 3) -> Array:
	var filled := Bag.ensure_queue(state["bag"], count)
	var upcoming := []
	for i in range(count):
		upcoming.append(filled["queue"][i])
	return upcoming


# --- internals ---


static func shift(state: Dictionary, dx: int) -> Dictionary:
	if state["status"] != "playing" or state["active"] == null:
		return clone_state(state)
	var s := clone_state(state)
	if can_move_to(s, int(s["active"]["x"]) + dx, int(s["active"]["y"]), int(s["active"]["rotation"])):
		var was_grounded := is_grounded(s)
		s["active"]["x"] = int(s["active"]["x"]) + dx
		apply_lock_reset(s, was_grounded)
		s["events"].append({"kind": "move"})
	return s


static func is_grounded(state: Dictionary) -> bool:
	if state["active"] == null:
		return false
	var active: Dictionary = state["active"]
	return not can_move_to(state, int(active["x"]), int(active["y"]) + 1, int(active["rotation"]))


static func can_move_to(state: Dictionary, x: int, y: int, rotation: int) -> bool:
	var cells := absolute_cells({
		"piece_type": state["active"]["piece_type"],
		"rotation": rotation,
		"x": x,
		"y": y
	})
	return Board.can_place(state["board"], cells)


static func absolute_cells(active: Dictionary) -> Array:
	var cells := []
	for cell in Piece.cells_for(active["piece_type"], int(active["rotation"])):
		cells.append({"x": int(active["x"]) + int(cell["x"]), "y": int(active["y"]) + int(cell["y"])})
	return cells


# Successful move/rotation while grounded restarts the lock delay,
# at most max_lock_resets() times per piece.
static func apply_lock_reset(s: Dictionary, was_grounded: bool) -> void:
	if was_grounded and int(s["lock_resets"]) < max_lock_resets():
		s["lock_timer_ms"] = 0
		s["lock_resets"] = int(s["lock_resets"]) + 1


# Writes the active piece into the board, scores any cleared lines and
# spawns the next piece (or ends the game when the spawn is blocked).
static func lock_active(s: Dictionary) -> Dictionary:
	var cells := absolute_cells(s["active"])
	s["board"] = Board.with_cells(s["board"], cells, Piece.type_index(s["active"]["piece_type"]))
	var rows := Board.full_rows(s["board"])
	if rows.size() > 0:
		s["board"] = Board.clear_rows(s["board"], rows)
		# Combo counts consecutive clearing locks; scoring reads the
		# PRE-clear b2b state, which is only re-armed/broken afterwards.
		s["combo"] = int(s["combo"]) + 1
		var result := Score.apply_clear(s["score"], rows.size(), bool(s["b2b_armed"]), int(s["combo"]))
		s["score"] = result["score"]
		if rows.size() == 4:
			s["b2b_armed"] = true
		else:
			s["b2b_armed"] = false
		s["events"].append({"kind": "lineClear", "lines": rows.size(), "combo": s["combo"]})
		if int(s["combo"]) >= 1:
			s["events"].append({"kind": "combo", "count": s["combo"]})
		if bool(result["leveled_up"]):
			s["events"].append({"kind": "levelUp", "level": s["score"]["level"]})
	else:
		# A dry lock breaks the combo chain but NOT back-to-back: b2b only
		# breaks on an easier clear, matching the modern guideline.
		s["combo"] = -1
		s["events"].append({"kind": "lock"})
	s["can_hold"] = true
	s["lock_timer_ms"] = 0
	s["lock_resets"] = 0
	s["gravity_accum_ms"] = 0
	return spawn_next(s)


static func spawn_next(s: Dictionary) -> Dictionary:
	s["bag"] = Bag.ensure_queue(s["bag"], preview_count() + 1)
	var dealt := Bag.deal(s["bag"])
	s["bag"] = dealt["bag"]
	return place_at_spawn(s, dealt["piece_type"])


# Places a piece at its spawn position; a blocked spawn means game over.
static func place_at_spawn(s: Dictionary, piece_type: String) -> Dictionary:
	var x := 3
	if Piece.box_size(piece_type) == 2:
		x = 4
	var candidate := {"piece_type": piece_type, "rotation": 0, "x": x, "y": 0}
	if Board.can_place(s["board"], absolute_cells(candidate)):
		s["active"] = candidate
	else:
		s["active"] = null
		s["status"] = "gameOver"
		s["events"].append({"kind": "gameOver"})
	return s


# Shallow clone with a fresh events array. Board, bag and score states are
# immutable (their modules always return new Dictionaries), so sharing the
# references is safe; only `active` is mutated internally and is copied.
static func clone_state(state: Dictionary) -> Dictionary:
	var active = null
	if state["active"] != null:
		active = {
			"piece_type": state["active"]["piece_type"],
			"rotation": state["active"]["rotation"],
			"x": state["active"]["x"],
			"y": state["active"]["y"]
		}
	return {
		"board": state["board"],
		"bag": state["bag"],
		"score": state["score"],
		"active": active,
		"hold": state["hold"],
		"can_hold": state["can_hold"],
		"status": state["status"],
		"gravity_accum_ms": state["gravity_accum_ms"],
		"lock_timer_ms": state["lock_timer_ms"],
		"lock_resets": state["lock_resets"],
		"combo": state["combo"],
		"b2b_armed": state["b2b_armed"],
		"events": []
	}
