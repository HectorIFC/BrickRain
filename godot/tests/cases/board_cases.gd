class_name BoardCases
extends RefCounted

# Unit tests for core/board.gd (grid, collision, line clearing).
# Ported from tests/cases/boardCases.bs.


static func run_all() -> Array:
	return [
		{"name": "board: creates an empty 10x22 grid", "collector": case_create()},
		{"name": "board: collision and bounds checks", "collector": case_can_place()},
		{"name": "board: with_cells writes without mutating the input", "collector": case_with_cells_purity()},
		{"name": "board: detects and clears a single line", "collector": case_single_clear()},
		{"name": "board: clears a quad (4 lines at once)", "collector": case_quad_clear()},
		{"name": "board: clears non-contiguous lines", "collector": case_non_contiguous_clear()},
		{"name": "board: detects stack in hidden rows", "collector": case_hidden_rows()}
	]


static func fill_row(board_state: Dictionary, y: int, skip_x: int = -1) -> Dictionary:
	var cells := []
	for x in range(int(board_state["width"])):
		if x != skip_x:
			cells.append({"x": x, "y": y})
	return Board.with_cells(board_state, cells, 1)


static func case_create() -> Dictionary:
	var c := TestAssert.new_collector()
	var b := Board.create()
	TestAssert.equal(c, b["width"], 10, "width")
	TestAssert.equal(c, b["height"], 22, "height includes 2 hidden rows")
	TestAssert.equal(c, b["hidden_rows"], 2, "hidden rows")
	TestAssert.equal(c, b["grid"].size(), 220, "grid size")
	TestAssert.equal(c, Board.full_rows(b).size(), 0, "no full rows on an empty board")
	TestAssert.equal(c, Board.cell_at(b, 0, 0), 0, "cells start empty")
	return c


static func case_can_place() -> Dictionary:
	var c := TestAssert.new_collector()
	var b := Board.create()
	TestAssert.is_true(c, Board.can_place(b, [{"x": 0, "y": 0}, {"x": 9, "y": 21}]), "empty cells are placeable")
	TestAssert.is_false(c, Board.can_place(b, [{"x": -1, "y": 0}]), "left wall blocks")
	TestAssert.is_false(c, Board.can_place(b, [{"x": 10, "y": 0}]), "right wall blocks")
	TestAssert.is_false(c, Board.can_place(b, [{"x": 0, "y": 22}]), "floor blocks")
	TestAssert.is_false(c, Board.can_place(b, [{"x": 0, "y": -1}]), "ceiling blocks")
	var occupied := Board.with_cells(b, [{"x": 5, "y": 5}], 3)
	TestAssert.is_false(c, Board.can_place(occupied, [{"x": 5, "y": 5}]), "occupied cell blocks")
	return c


static func case_with_cells_purity() -> Dictionary:
	var c := TestAssert.new_collector()
	var original := Board.create()
	var updated := Board.with_cells(original, [{"x": 2, "y": 3}], 7)
	TestAssert.equal(c, Board.cell_at(updated, 2, 3), 7, "value written in the copy")
	TestAssert.equal(c, Board.cell_at(original, 2, 3), 0, "original board untouched")
	return c


static func case_single_clear() -> Dictionary:
	var c := TestAssert.new_collector()
	var b := Board.create()
	b = fill_row(b, 21)
	b = Board.with_cells(b, [{"x": 0, "y": 20}], 5)
	var rows := Board.full_rows(b)
	TestAssert.equal(c, rows.size(), 1, "one full row detected")
	TestAssert.equal(c, rows[0], 21, "bottom row is full")
	var cleared := Board.clear_rows(b, rows)
	TestAssert.equal(c, Board.cell_at(cleared, 0, 21), 5, "marker block shifted down")
	TestAssert.equal(c, Board.cell_at(cleared, 1, 21), 0, "rest of the shifted row is empty")
	TestAssert.equal(c, Board.full_rows(cleared).size(), 0, "no full rows remain")
	return c


static func case_quad_clear() -> Dictionary:
	var c := TestAssert.new_collector()
	var b := Board.create()
	for y in range(18, 22):
		b = fill_row(b, y)
	var rows := Board.full_rows(b)
	TestAssert.equal(c, rows.size(), 4, "four full rows detected")
	var cleared := Board.clear_rows(b, rows)
	var empty := true
	for value in cleared["grid"]:
		if int(value) != 0:
			empty = false
	TestAssert.is_true(c, empty, "board is empty after the quad clear")
	return c


static func case_non_contiguous_clear() -> Dictionary:
	var c := TestAssert.new_collector()
	var b := Board.create()
	b = fill_row(b, 19)
	b = fill_row(b, 21)
	b = Board.with_cells(b, [{"x": 5, "y": 20}], 4)
	var rows := Board.full_rows(b)
	TestAssert.equal(c, rows.size(), 2, "two separated full rows detected")
	var cleared := Board.clear_rows(b, rows)
	TestAssert.equal(c, Board.cell_at(cleared, 5, 21), 4, "partial row landed at the bottom")
	TestAssert.equal(c, Board.cell_at(cleared, 5, 20), 0, "row above is empty")
	TestAssert.equal(c, Board.full_rows(cleared).size(), 0, "no full rows remain")
	return c


static func case_hidden_rows() -> Dictionary:
	var c := TestAssert.new_collector()
	var b := Board.create()
	TestAssert.is_false(c, Board.stack_in_hidden_rows(b), "empty board has nothing hidden")
	b = Board.with_cells(b, [{"x": 4, "y": 1}], 2)
	TestAssert.is_true(c, Board.stack_in_hidden_rows(b), "block in row 1 is in the hidden area")
	return c
