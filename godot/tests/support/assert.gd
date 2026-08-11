class_name TestAssert
extends RefCounted

# Minimal assertion collector shared by all test cases. Each case function
# creates a collector, runs its checks against it and returns it; the runner
# only inspects results.
#
# Mirrors tests/support/assert.bs so both suites stay structurally identical
# and drift between the two implementations is easy to spot.


static func new_collector() -> Dictionary:
	return {"checks": 0, "failures": []}


static func is_true(c: Dictionary, condition: bool, label: String) -> void:
	c["checks"] = int(c["checks"]) + 1
	if not condition:
		c["failures"].append(label)


static func is_false(c: Dictionary, condition: bool, label: String) -> void:
	is_true(c, not condition, label)


static func equal(c: Dictionary, actual, expected, label: String) -> void:
	c["checks"] = int(c["checks"]) + 1
	if not values_equal(actual, expected):
		c["failures"].append(
			label + " — expected " + to_debug_string(expected) + ", got " + to_debug_string(actual)
		)


# Asserts that a cells array ({x, y} Dictionaries) contains the given coordinate.
static func contains_cell(c: Dictionary, cells: Array, x: int, y: int, label: String) -> void:
	c["checks"] = int(c["checks"]) + 1
	for cell in cells:
		if int(cell["x"]) == x and int(cell["y"]) == y:
			return
	c["failures"].append(
		label + " — cell (" + str(x) + "," + str(y) + ") not found in " + to_debug_string(cells)
	)


# Asserts that two cells arrays contain the same set of coordinates.
static func same_cells(c: Dictionary, actual: Array, expected: Array, label: String) -> void:
	c["checks"] = int(c["checks"]) + 1
	if actual.size() != expected.size():
		c["failures"].append(
			label + " — expected " + str(expected.size()) + " cells, got " + str(actual.size())
		)
		return
	for want in expected:
		var found := false
		for cell in actual:
			if int(cell["x"]) == int(want["x"]) and int(cell["y"]) == int(want["y"]):
				found = true
		if not found:
			c["failures"].append(
				label + " — missing cell (" + str(want["x"]) + "," + str(want["y"]) + ")"
			)
			return


# Asserts that a game events array contains an event of the given kind.
static func has_event(c: Dictionary, events: Array, kind: String, label: String) -> void:
	c["checks"] = int(c["checks"]) + 1
	for event in events:
		if event["kind"] == kind:
			return
	c["failures"].append(
		label + " — event '" + kind + "' not found in " + to_debug_string(events)
	)


static func values_equal(a, b) -> bool:
	if a == null and b == null:
		return true
	if a == null or b == null:
		return false
	return a == b


static func to_debug_string(value) -> String:
	if value == null:
		return "invalid"
	var text := JSON.stringify(value)
	if text == "":
		return "<unprintable>"
	return text
