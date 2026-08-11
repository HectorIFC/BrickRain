class_name BagCases
extends RefCounted

# Unit tests for core/bag.gd (seedable 7-bag randomizer).
# Ported from tests/cases/bagCases.bs.


static func run_all() -> Array:
	return [
		{"name": "bag: each of 7 pieces appears exactly once per bag", "collector": case_seven_bag()},
		{"name": "bag: same seed reproduces the same sequence", "collector": case_determinism()},
		{"name": "bag: ensure_queue fills without changing dealt order", "collector": case_ensure_queue()},
		{"name": "bag: random generator stays in range", "collector": case_random_range()}
	]


static func deal_many(seed: int, count: int) -> Array:
	var bag_state := Bag.create(seed)
	var dealt_types := []
	for _i in range(count):
		var dealt := Bag.deal(bag_state)
		bag_state = dealt["bag"]
		dealt_types.append(dealt["piece_type"])
	return dealt_types


static func case_seven_bag() -> Dictionary:
	var c := TestAssert.new_collector()
	var dealt_types := deal_many(42, 14)
	for bag_index in range(2):
		var counts := {}
		for i in range(7):
			var piece_type = dealt_types[bag_index * 7 + i]
			if not counts.has(piece_type):
				counts[piece_type] = 0
			counts[piece_type] = int(counts[piece_type]) + 1
		for piece_type: String in Piece.types():
			var label := "bag " + str(bag_index) + " deals exactly one " + piece_type
			TestAssert.equal(c, counts.get(piece_type, null), 1, label)
	return c


static func case_determinism() -> Dictionary:
	var c := TestAssert.new_collector()
	var first := deal_many(1234, 21)
	var second := deal_many(1234, 21)
	var identical := true
	for i in range(first.size()):
		if first[i] != second[i]:
			identical = false
	TestAssert.is_true(c, identical, "two runs with seed 1234 deal identical pieces")
	return c


static func case_ensure_queue() -> Dictionary:
	var c := TestAssert.new_collector()
	var bag_state := Bag.create(7)
	var filled := Bag.ensure_queue(bag_state, 4)
	TestAssert.is_true(c, filled["queue"].size() >= 4, "queue holds at least 4 pieces")
	# Dealing must consume exactly the head of the ensured queue.
	var expected = filled["queue"][0]
	var dealt := Bag.deal(filled)
	TestAssert.equal(c, dealt["piece_type"], expected, "deal returns the queue head")
	TestAssert.equal(c, dealt["bag"]["queue"][0], filled["queue"][1], "queue advances by one")
	return c


static func case_random_range() -> Dictionary:
	var c := TestAssert.new_collector()
	var state := 1
	var in_range := true
	for _i in range(1000):
		var result := Bag.next_random(state)
		state = int(result["rng_state"])
		var value := float(result["value"])
		if value < 0.0 or value >= 1.0:
			in_range = false
		if state < 1 or state > 2147483646:
			in_range = false
	TestAssert.is_true(c, in_range, "1000 draws stay within [0,1) and valid state range")
	return c
