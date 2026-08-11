class_name Board
extends RefCounted

# Board (well) state: grid storage, collision checks, line detection/clearing.
# Pure module: every mutation returns a new board Dictionary, inputs are
# never changed.
#
# Translated from source/logic/board.bs. Keep both implementations in step.


# Creates an empty board. The grid is a flat array of integers
# (index = y * width + x): 0 = empty, 1..7 = piece type index.
# The top `hidden_rows` rows are the spawn area above the visible well.
static func create(width: int = 10, visible_rows: int = 20, hidden_rows: int = 2) -> Dictionary:
	var height := visible_rows + hidden_rows
	var grid := []
	grid.resize(width * height)
	grid.fill(0)
	return {"width": width, "height": height, "hidden_rows": hidden_rows, "grid": grid}


static func in_bounds(board_state: Dictionary, x: int, y: int) -> bool:
	return x >= 0 and x < int(board_state["width"]) and y >= 0 and y < int(board_state["height"])


static func cell_at(board_state: Dictionary, x: int, y: int) -> int:
	if not in_bounds(board_state, x, y):
		return -1
	return int(board_state["grid"][y * int(board_state["width"]) + x])


# True when every cell is inside the board and currently empty.
static func can_place(board_state: Dictionary, cells: Array) -> bool:
	for cell in cells:
		if cell_at(board_state, int(cell["x"]), int(cell["y"])) != 0:
			return false
	return true


# Returns a new board with `value` written at every given cell.
static func with_cells(board_state: Dictionary, cells: Array, value: int) -> Dictionary:
	var grid: Array = clone_grid(board_state["grid"])
	var width := int(board_state["width"])
	for cell in cells:
		if in_bounds(board_state, int(cell["x"]), int(cell["y"])):
			grid[int(cell["y"]) * width + int(cell["x"])] = value
	return with_grid(board_state, grid)


# Row indices (top to bottom) that are completely filled.
static func full_rows(board_state: Dictionary) -> Array:
	var rows := []
	var width := int(board_state["width"])
	var grid: Array = board_state["grid"]
	for y in range(int(board_state["height"])):
		var full := true
		for x in range(width):
			if int(grid[y * width + x]) == 0:
				full = false
				break
		if full:
			rows.append(y)
	return rows


# Returns a new board with the given rows removed and the same number of
# empty rows inserted at the top (everything above shifts down).
static func clear_rows(board_state: Dictionary, rows: Array) -> Dictionary:
	if rows.size() == 0:
		return board_state
	var cleared := {}
	for row_index in rows:
		cleared[int(row_index)] = true
	var width := int(board_state["width"])
	var source: Array = board_state["grid"]
	var grid := []
	for _i in range(rows.size() * width):
		grid.append(0)
	for y in range(int(board_state["height"])):
		if not cleared.has(y):
			for x in range(width):
				grid.append(source[y * width + x])
	return with_grid(board_state, grid)


# True when the stack has any block inside the hidden spawn rows.
static func stack_in_hidden_rows(board_state: Dictionary) -> bool:
	var width := int(board_state["width"])
	var grid: Array = board_state["grid"]
	for y in range(int(board_state["hidden_rows"])):
		for x in range(width):
			if int(grid[y * width + x]) != 0:
				return true
	return false


static func clone_grid(grid: Array) -> Array:
	return grid.duplicate()


static func with_grid(board_state: Dictionary, grid: Array) -> Dictionary:
	return {
		"width": board_state["width"],
		"height": board_state["height"],
		"hidden_rows": board_state["hidden_rows"],
		"grid": grid
	}
