class_name Piece
extends RefCounted

# Tetromino definitions: shapes, rotation states and SRS wall kicks.
# Pure module: no scene-tree dependencies.
#
# Translated from source/logic/piece.bs. Keep both implementations in step:
# a rule change here must be mirrored there, and vice versa.


# The 7 standard tetromino type ids, in canonical order.
static func types() -> Array[String]:
	return ["I", "O", "T", "S", "Z", "J", "L"]


# Numeric index (1..7) for a piece type; 0 means empty board cell.
static func type_index(piece_type: String) -> int:
	var all := types()
	for i in range(all.size()):
		if all[i] == piece_type:
			return i + 1
	return 0


# SRS bounding-box size for a piece type.
static func box_size(piece_type: String) -> int:
	if piece_type == "I":
		return 4
	if piece_type == "O":
		return 2
	return 3


# Spawn-state (rotation 0) cells, relative to the bounding box.
# Coordinates are x to the right, y DOWNWARD (board row order).
static func spawn_cells(piece_type: String) -> Array:
	match piece_type:
		"I":
			return [{"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1}, {"x": 3, "y": 1}]
		"O":
			return [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": 1, "y": 1}]
		"T":
			return [{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1}]
		"S":
			return [{"x": 1, "y": 0}, {"x": 2, "y": 0}, {"x": 0, "y": 1}, {"x": 1, "y": 1}]
		"Z":
			return [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 1, "y": 1}, {"x": 2, "y": 1}]
		"J":
			return [{"x": 0, "y": 0}, {"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1}]
		"L":
			return [{"x": 2, "y": 0}, {"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1}]
	return []


# Rotates box-relative cells 90 degrees clockwise inside an n x n box.
# With y growing downward, clockwise is: (x, y) -> (n - 1 - y, x).
static func rotate_cells_cw(cells: Array, n: int) -> Array:
	var rotated := []
	for cell in cells:
		rotated.append({"x": n - 1 - int(cell["y"]), "y": int(cell["x"])})
	return rotated


# Box-relative cells for a piece type at a rotation state (0..3).
static func cells_for(piece_type: String, rotation: int) -> Array:
	var cells := spawn_cells(piece_type)
	var n := box_size(piece_type)
	var turns := ((rotation % 4) + 4) % 4
	for _i in range(turns):
		cells = rotate_cells_cw(cells, n)
	return cells


# SRS wall-kick offsets to try, in order, when rotating from_rot -> to_rot.
# Offsets use the SRS guideline convention where +y means UP; board code
# must SUBTRACT dy when applying them to this repo's y-down grid.
static func kick_table(piece_type: String, from_rot: int, to_rot: int) -> Array:
	if piece_type == "O":
		return [{"x": 0, "y": 0}]
	var key := from_to_key(from_rot, to_rot)
	var tables: Dictionary
	if piece_type == "I":
		tables = {
			"0>1": [{"x": 0, "y": 0}, {"x": -2, "y": 0}, {"x": 1, "y": 0}, {"x": -2, "y": -1}, {"x": 1, "y": 2}],
			"1>0": [{"x": 0, "y": 0}, {"x": 2, "y": 0}, {"x": -1, "y": 0}, {"x": 2, "y": 1}, {"x": -1, "y": -2}],
			"1>2": [{"x": 0, "y": 0}, {"x": -1, "y": 0}, {"x": 2, "y": 0}, {"x": -1, "y": 2}, {"x": 2, "y": -1}],
			"2>1": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": -2, "y": 0}, {"x": 1, "y": -2}, {"x": -2, "y": 1}],
			"2>3": [{"x": 0, "y": 0}, {"x": 2, "y": 0}, {"x": -1, "y": 0}, {"x": 2, "y": 1}, {"x": -1, "y": -2}],
			"3>2": [{"x": 0, "y": 0}, {"x": -2, "y": 0}, {"x": 1, "y": 0}, {"x": -2, "y": -1}, {"x": 1, "y": 2}],
			"3>0": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": -2, "y": 0}, {"x": 1, "y": -2}, {"x": -2, "y": 1}],
			"0>3": [{"x": 0, "y": 0}, {"x": -1, "y": 0}, {"x": 2, "y": 0}, {"x": -1, "y": 2}, {"x": 2, "y": -1}]
		}
	else:
		tables = {
			"0>1": [{"x": 0, "y": 0}, {"x": -1, "y": 0}, {"x": -1, "y": 1}, {"x": 0, "y": -2}, {"x": -1, "y": -2}],
			"1>0": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 1, "y": -1}, {"x": 0, "y": 2}, {"x": 1, "y": 2}],
			"1>2": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 1, "y": -1}, {"x": 0, "y": 2}, {"x": 1, "y": 2}],
			"2>1": [{"x": 0, "y": 0}, {"x": -1, "y": 0}, {"x": -1, "y": 1}, {"x": 0, "y": -2}, {"x": -1, "y": -2}],
			"2>3": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 1, "y": 1}, {"x": 0, "y": -2}, {"x": 1, "y": -2}],
			"3>2": [{"x": 0, "y": 0}, {"x": -1, "y": 0}, {"x": -1, "y": -1}, {"x": 0, "y": 2}, {"x": -1, "y": 2}],
			"3>0": [{"x": 0, "y": 0}, {"x": -1, "y": 0}, {"x": -1, "y": -1}, {"x": 0, "y": 2}, {"x": -1, "y": 2}],
			"0>3": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 1, "y": 1}, {"x": 0, "y": -2}, {"x": 1, "y": -2}]
		}
	if not tables.has(key):
		return [{"x": 0, "y": 0}]
	return tables[key]


static func from_to_key(from_rot: int, to_rot: int) -> String:
	return str(from_rot) + ">" + str(to_rot)
