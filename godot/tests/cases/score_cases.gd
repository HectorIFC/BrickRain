class_name ScoreCases
extends RefCounted

# Unit tests for core/score.gd (scoring, leveling, gravity speed).
# Ported from tests/cases/scoreCases.bs.


static func run_all() -> Array:
	return [
		{"name": "score: line points follow the 100/300/500/800 table", "collector": case_points()},
		{"name": "score: level up lands exactly at 10 lines", "collector": case_level_boundary()},
		{"name": "score: gravity speeds up and bottoms out at 80 ms", "collector": case_gravity()},
		{"name": "score: drop bonuses are per cell", "collector": case_drop_points()},
		{"name": "score: back-to-back and combo bonuses", "collector": case_combo_and_b2b()}
	]


static func case_combo_and_b2b() -> Dictionary:
	var c := TestAssert.new_collector()
	# Back-to-back only multiplies quads: 1200 x level instead of 800.
	TestAssert.equal(c, Score.line_points(4, 2, true), 2400, "b2b quad at level 2")
	TestAssert.equal(c, Score.line_points(4, 2, false), 1600, "plain quad at level 2")
	TestAssert.equal(c, Score.line_points(2, 3, true), 900, "b2b flag never touches non-quads")
	# Combo ladder: -1 and 0 pay nothing, then 50 x combo x level.
	TestAssert.equal(c, Score.combo_bonus(-1, 5), 0, "no chain, no bonus")
	TestAssert.equal(c, Score.combo_bonus(0, 5), 0, "first clear pays nothing")
	TestAssert.equal(c, Score.combo_bonus(1, 2), 100, "combo 1 at level 2")
	TestAssert.equal(c, Score.combo_bonus(3, 2), 300, "combo 3 at level 2")
	# apply_clear folds both in, at the pre-clear level.
	var result := Score.apply_clear({"score": 0, "lines": 0, "level": 1}, 4, true, 2)
	TestAssert.equal(c, result["score"]["score"], 1300, "b2b quad 1200 + combo 2 bonus 100")
	result = Score.apply_clear({"score": 0, "lines": 0, "level": 1}, 1)
	TestAssert.equal(c, result["score"]["score"], 100, "defaults keep the old behaviour")
	return c


static func case_points() -> Dictionary:
	var c := TestAssert.new_collector()
	TestAssert.equal(c, Score.line_points(1, 1), 100, "single at level 1")
	TestAssert.equal(c, Score.line_points(2, 1), 300, "double at level 1")
	TestAssert.equal(c, Score.line_points(3, 1), 500, "triple at level 1")
	TestAssert.equal(c, Score.line_points(4, 1), 800, "quad at level 1")
	TestAssert.equal(c, Score.line_points(4, 5), 4000, "quad at level 5")
	TestAssert.equal(c, Score.line_points(0, 3), 0, "no lines, no points")
	return c


static func case_level_boundary() -> Dictionary:
	var c := TestAssert.new_collector()
	var nine_lines := {"score": 0, "lines": 9, "level": 1}
	var result := Score.apply_clear(nine_lines, 1)
	TestAssert.equal(c, result["score"]["lines"], 10, "lines reach 10")
	TestAssert.equal(c, result["score"]["level"], 2, "level 2 exactly at 10 lines")
	TestAssert.is_true(c, result["leveled_up"], "level-up flag set")

	var eight_lines := {"score": 0, "lines": 8, "level": 1}
	result = Score.apply_clear(eight_lines, 1)
	TestAssert.equal(c, result["score"]["level"], 1, "still level 1 at 9 lines")
	TestAssert.is_false(c, result["leveled_up"], "no level-up flag at 9 lines")

	# A quad can jump the boundary in one clear.
	result = Score.apply_clear({"score": 0, "lines": 17, "level": 2}, 4)
	TestAssert.equal(c, result["score"]["lines"], 21, "lines accumulate")
	TestAssert.equal(c, result["score"]["level"], 3, "level 3 after crossing 20 lines")
	TestAssert.equal(c, result["score"]["score"], 1600, "quad scored with the pre-clear level")
	return c


static func case_gravity() -> Dictionary:
	var c := TestAssert.new_collector()
	TestAssert.equal(c, Score.gravity_ms(1), 1000, "level 1 interval")
	TestAssert.equal(c, Score.gravity_ms(2), 910, "level 2 interval")
	TestAssert.equal(c, Score.gravity_ms(11), 100, "level 11 interval")
	TestAssert.equal(c, Score.gravity_ms(12), 80, "level 12 hits the 80 ms floor")
	TestAssert.equal(c, Score.gravity_ms(30), 80, "interval never goes below 80 ms")
	return c


static func case_drop_points() -> Dictionary:
	var c := TestAssert.new_collector()
	var base := Score.create()
	var soft := Score.add_drop_points(base, 3, 1)
	TestAssert.equal(c, soft["score"], 3, "soft drop adds 1 per cell")
	var hard := Score.add_drop_points(soft, 10, 2)
	TestAssert.equal(c, hard["score"], 23, "hard drop adds 2 per cell")
	TestAssert.equal(c, hard["lines"], 0, "drops do not touch lines")
	TestAssert.equal(c, base["score"], 0, "input state is not mutated")
	return c
