extends SceneTree

# Headless test runner: executes every shared test case and prints a parseable
# summary, then exits non-zero on failure so CI can gate on it.
#
# Run with:
#   godot --headless --path godot --script res://tests/run_tests.gd
#
# Mirrors tests/headless/main.bs, including the BRICKRAIN_TESTS_RESULT
# sentinel line, so both suites report in the same shape.


func _initialize() -> void:
	print("BrickRain headless logic tests (Godot)")
	print("======================================")
	var groups := [
		{"name": "piece", "results": PieceCases.run_all()},
		{"name": "board", "results": BoardCases.run_all()},
		{"name": "bag", "results": BagCases.run_all()},
		{"name": "score", "results": ScoreCases.run_all()},
		{"name": "leaderboard", "results": LeaderboardCases.run_all()},
		{"name": "game", "results": GameCases.run_all()}
	]
	var passed := 0
	var failed := 0
	var checks := 0
	for group in groups:
		for result in group["results"]:
			var collector: Dictionary = result["collector"]
			checks += int(collector["checks"])
			if collector["failures"].size() == 0:
				passed += 1
				print("[PASS] " + result["name"] + " (" + str(collector["checks"]) + " checks)")
			else:
				failed += 1
				print("[FAIL] " + result["name"])
				for failure in collector["failures"]:
					print("       - " + str(failure))
	print("======================================")
	print("Cases: " + str(passed + failed) + ", checks: " + str(checks) + ", failed: " + str(failed))
	if failed == 0:
		print("BRICKRAIN_TESTS_RESULT: PASS")
	else:
		print("BRICKRAIN_TESTS_RESULT: FAIL")
	quit(0 if failed == 0 else 1)
