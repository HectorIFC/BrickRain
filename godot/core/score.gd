class_name Score
extends RefCounted

# Scoring, line counting, leveling and gravity speed rules.
# Pure module: every mutation returns a new score Dictionary.
#
# Translated from source/logic/score.bs. Keep both implementations in step.


static func create() -> Dictionary:
	return {"score": 0, "lines": 0, "level": 1}


# Points awarded for clearing `cleared_count` lines at the given level.
# A back-to-back quad (a quad with no easier clear since the last one)
# pays 1.5x: 1200 x level instead of 800.
static func line_points(cleared_count: int, level: int, b2b_armed: bool = false) -> int:
	if cleared_count == 1:
		return 100 * level
	if cleared_count == 2:
		return 300 * level
	if cleared_count == 3:
		return 500 * level
	if cleared_count >= 4:
		if b2b_armed:
			return 1200 * level
		return 800 * level
	return 0


# Bonus for the Nth consecutive clearing lock: 50 x combo x level.
# combo counts from -1 (no chain); the first clear (combo 0) pays nothing.
static func combo_bonus(combo: int, level: int) -> int:
	if combo < 1:
		return 0
	return 50 * combo * level


# Level derived from total cleared lines: level up every 10 lines.
# BrightScript `\` is integer division; `/` on two ints is integer division
# in GDScript too, so the truncation behaviour matches.
@warning_ignore("integer_division")
static func level_for_lines(lines: int) -> int:
	return 1 + lines / 10


# Gravity interval in ms for a level: max(80, 1000 - (level - 1) * 90).
static func gravity_ms(level: int) -> int:
	var interval := 1000 - (level - 1) * 90
	if interval < 80:
		interval = 80
	return interval


# Applies a line clear. Returns { score, leveled_up }: the new score state
# and whether the clear crossed a level boundary. All clear-time scoring
# lives here: line points (with the back-to-back multiplier) plus the
# combo bonus, both computed at the PRE-clear level.
static func apply_clear(score_state: Dictionary, cleared_count: int, b2b_armed: bool = false, combo: int = -1) -> Dictionary:
	var points := line_points(cleared_count, int(score_state["level"]), b2b_armed) \
		+ combo_bonus(combo, int(score_state["level"]))
	var lines := int(score_state["lines"]) + cleared_count
	var new_level := level_for_lines(lines)
	return {
		"score": {
			"score": int(score_state["score"]) + points,
			"lines": lines,
			"level": new_level
		},
		"leveled_up": new_level > int(score_state["level"])
	}


# Drop bonus: +1 per cell for soft drop, +2 per cell for hard drop.
static func add_drop_points(score_state: Dictionary, cells_dropped: int, per_cell: int) -> Dictionary:
	return {
		"score": int(score_state["score"]) + cells_dropped * per_cell,
		"lines": score_state["lines"],
		"level": score_state["level"]
	}
