class_name Bag
extends RefCounted

# 7-bag piece randomizer: every run of 7 deals contains each tetromino
# exactly once. Seedable for reproducible games and tests.
# Pure module: every mutation returns a new bag Dictionary.
#
# Translated from source/logic/bag.bs. Keep both implementations in step.
#
# The generator below MUST stay bit-exact with the BrightScript original —
# the seeded-game golden values in both test suites depend on it. Do not
# swap it for RandomNumberGenerator.


# Creates a bag state. Pass a positive seed for a deterministic sequence;
# -1 (default) draws a random seed once, so all later deals stay pure.
static func create(seed: int = -1) -> Dictionary:
	var rng_state := seed
	if rng_state < 1:
		rng_state = int(Time.get_ticks_usec() % 2147483645) + 1
	return {"rng_state": rng_state, "queue": []}


# Park-Miller "minimal standard" generator: state = state * 16807 mod (2^31 - 1).
# Computed in double precision so the product never loses integer accuracy
# (max product is ~3.6e13, well inside a double's exact integer range).
static func next_random(rng_state: int) -> Dictionary:
	var product := float(rng_state) * 16807.0
	var modulus := 2147483647.0
	var remainder := product - float(int(product / modulus)) * modulus
	if remainder < 1.0:
		remainder = 1.0
	return {"rng_state": int(remainder), "value": remainder / modulus}


# Returns a new bag whose queue holds at least min_count upcoming pieces.
static func ensure_queue(bag_state: Dictionary, min_count: int) -> Dictionary:
	var existing: Array = bag_state["queue"]
	if existing.size() >= min_count:
		return bag_state
	var queue := existing.duplicate()
	var rng_state := int(bag_state["rng_state"])
	while queue.size() < min_count:
		var shuffled := shuffle_bag(rng_state)
		rng_state = int(shuffled["rng_state"])
		for piece_type in shuffled["pieces"]:
			queue.append(piece_type)
	return {"rng_state": rng_state, "queue": queue}


# Deals the next piece. Returns { bag, piece_type }.
static func deal(bag_state: Dictionary) -> Dictionary:
	var filled := ensure_queue(bag_state, 1)
	var queue: Array = filled["queue"]
	return {
		"bag": {"rng_state": filled["rng_state"], "queue": queue.slice(1)},
		"piece_type": queue[0]
	}


# Fisher-Yates shuffle of one fresh bag of 7. Returns { pieces, rng_state }.
static func shuffle_bag(rng_state: int) -> Dictionary:
	var pieces := Piece.types()
	var state := rng_state
	for i in range(pieces.size() - 1, 0, -1):
		var random_result := next_random(state)
		state = int(random_result["rng_state"])
		var j := int(float(random_result["value"]) * (i + 1))
		if j > i:
			j = i
		var swap = pieces[i]
		pieces[i] = pieces[j]
		pieces[j] = swap
	return {"pieces": pieces, "rng_state": state}
