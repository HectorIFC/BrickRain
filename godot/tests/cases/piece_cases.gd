class_name PieceCases
extends RefCounted

# Unit tests for core/piece.gd (shapes, rotation, SRS kick tables).
# Ported from tests/cases/pieceCases.bs.


static func run_all() -> Array:
	return [
		{"name": "piece: type indexes map 1..7", "collector": case_type_indexes()},
		{"name": "piece: spawn shapes are correct", "collector": case_spawn_shapes()},
		{"name": "piece: four clockwise rotations return to spawn", "collector": case_full_rotation_cycle()},
		{"name": "piece: T rotation states follow SRS", "collector": case_t_rotation_states()},
		{"name": "piece: kick tables match the SRS standard", "collector": case_kick_tables()}
	]


static func case_type_indexes() -> Dictionary:
	var c := TestAssert.new_collector()
	var all := Piece.types()
	TestAssert.equal(c, all.size(), 7, "there are 7 piece types")
	for i in range(all.size()):
		TestAssert.equal(c, Piece.type_index(all[i]), i + 1, "index of " + all[i])
	TestAssert.equal(c, Piece.type_index("X"), 0, "unknown type maps to 0")
	return c


static func case_spawn_shapes() -> Dictionary:
	var c := TestAssert.new_collector()
	var i_cells := Piece.spawn_cells("I")
	TestAssert.same_cells(
		c,
		i_cells,
		[{"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1}, {"x": 3, "y": 1}],
		"I spawns flat in box row 1"
	)
	var t_cells := Piece.spawn_cells("T")
	TestAssert.same_cells(
		c,
		t_cells,
		[{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1}],
		"T spawns pointing up"
	)
	for piece_type: String in Piece.types():
		TestAssert.equal(c, Piece.spawn_cells(piece_type).size(), 4, piece_type + " has 4 cells")
	return c


static func case_full_rotation_cycle() -> Dictionary:
	var c := TestAssert.new_collector()
	for piece_type: String in Piece.types():
		var spawn := Piece.cells_for(piece_type, 0)
		var cycled := Piece.cells_for(piece_type, 4)
		TestAssert.same_cells(c, cycled, spawn, piece_type + " returns to spawn after 4 rotations")
	return c


static func case_t_rotation_states() -> Dictionary:
	var c := TestAssert.new_collector()
	# SRS state 1 (clockwise from spawn): T points right.
	var state1 := Piece.cells_for("T", 1)
	TestAssert.same_cells(
		c,
		state1,
		[{"x": 1, "y": 0}, {"x": 1, "y": 1}, {"x": 2, "y": 1}, {"x": 1, "y": 2}],
		"T state 1 points right"
	)
	# SRS state 2: T points down.
	var state2 := Piece.cells_for("T", 2)
	TestAssert.same_cells(
		c,
		state2,
		[{"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1}, {"x": 1, "y": 2}],
		"T state 2 points down"
	)
	# SRS state 3: T points left.
	var state3 := Piece.cells_for("T", 3)
	TestAssert.same_cells(
		c,
		state3,
		[{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 1, "y": 2}],
		"T state 3 points left"
	)
	return c


static func case_kick_tables() -> Dictionary:
	var c := TestAssert.new_collector()
	# O piece never kicks.
	var o_kicks := Piece.kick_table("O", 0, 1)
	TestAssert.equal(c, o_kicks.size(), 1, "O has a single no-op kick")
	TestAssert.equal(c, o_kicks[0]["x"], 0, "O kick is (0,0)")
	# J/L/S/T/Z share the standard table: 0->1 second test is (-1, 0).
	var t_kicks := Piece.kick_table("T", 0, 1)
	TestAssert.equal(c, t_kicks.size(), 5, "JLSTZ tables have 5 tests")
	TestAssert.equal(c, t_kicks[1]["x"], -1, "JLSTZ 0>1 kick 2 dx")
	TestAssert.equal(c, t_kicks[1]["y"], 0, "JLSTZ 0>1 kick 2 dy")
	TestAssert.equal(c, t_kicks[4]["x"], -1, "JLSTZ 0>1 kick 5 dx")
	TestAssert.equal(c, t_kicks[4]["y"], -2, "JLSTZ 0>1 kick 5 dy")
	# I piece has its own table: 0->1 second test is (-2, 0).
	var i_kicks := Piece.kick_table("I", 0, 1)
	TestAssert.equal(c, i_kicks.size(), 5, "I tables have 5 tests")
	TestAssert.equal(c, i_kicks[1]["x"], -2, "I 0>1 kick 2 dx")
	TestAssert.equal(c, i_kicks[3]["x"], -2, "I 0>1 kick 4 dx")
	TestAssert.equal(c, i_kicks[3]["y"], -1, "I 0>1 kick 4 dy")
	# Reverse rotation 1->0 mirrors 0->1.
	var back_kicks := Piece.kick_table("T", 1, 0)
	TestAssert.equal(c, back_kicks[1]["x"], 1, "JLSTZ 1>0 kick 2 dx is mirrored")
	return c
