extends Node

# Layout smoke test: boots the real scene tree and asserts that screens fill
# their parent and that the FR03 responsive rules actually flip.
#
# Runs as a SCENE, not a --script SceneTree replacement, because autoloads
# (FBBridge, Ads) are not registered in --script mode and game.gd would fail to
# compile. Run with:
#
#   godot --headless --path godot res://tests/SmokeLayout.tscn
#
# This exists because a Control that silently collapses to zero size still
# "works" — it renders its children at their minimum size in the top-left
# corner, which reads as a styling bug rather than a layout one.

const EXPECTED_SCREENS := ["nickname_entry.gd", "dashboard.gd", "game.gd"]

var _failures := 0


func _ready() -> void:
	await _check_screens_fill()
	await _check_responsive_layout()

	print("")
	if _failures == 0:
		print("BRICKRAIN_LAYOUT_RESULT: PASS")
	else:
		print("BRICKRAIN_LAYOUT_RESULT: FAIL (" + str(_failures) + ")")
	get_tree().quit(0 if _failures == 0 else 1)


func _check_screens_fill() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	# Two frames: one to enter the tree, one for the layout pass to settle.
	await get_tree().process_frame
	await get_tree().process_frame

	# Screens must fill Main. Main itself is sized by the viewport, which is a
	# headless stub here, so it is the reference rather than the assertion.
	var expected: Vector2 = main.size
	print("-- screens fill Main ", expected, " --")

	var found := []
	for child in main.get_children():
		if child is Control and child.get_script() != null:
			var name := str(child.get_script().resource_path.get_file())
			found.append(name)
			_expect_size(name, child.size, expected)

	# A screen that failed to compile simply would not be here; without this
	# check the suite would report PASS for a tree that never built.
	for want in EXPECTED_SCREENS:
		if not found.has(want):
			print("MISSING SCREEN: " + want + " (did its script fail to compile?)")
			_failures += 1
	main.queue_free()


# FR03: portrait stacks panel / well / controls into a column; landscape puts
# them side by side. In both cases the well must stay inside the view.
func _check_responsive_layout() -> void:
	print("")
	print("-- responsive layout --")
	var game := GameScreen.new()
	add_child(game)
	await get_tree().process_frame
	game.start_game("Tester", 0)

	await _assert_orientation(game, Vector2(460, 900), true, "portrait 460x900")
	await _assert_orientation(game, Vector2(900, 460), false, "landscape 900x460")
	await _assert_orientation(game, Vector2(1080, 1920), true, "portrait 1080x1920")
	game.queue_free()


func _assert_orientation(game: GameScreen, view: Vector2, want_portrait: bool, label: String) -> void:
	# The screen is anchored to its parent, so drive it by size directly.
	game.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	game.size = view
	await get_tree().process_frame
	await get_tree().process_frame

	var got := game.is_portrait()
	if got == want_portrait:
		print("%-24s portrait=%s  ok" % [label, str(got)])
	else:
		print("%-24s portrait=%s  EXPECTED %s" % [label, str(got), str(want_portrait)])
		_failures += 1

	# The well must be non-degenerate AND fit inside the viewport. A side panel
	# whose minimum size exceeds the available height silently pushes the well
	# off the bottom of the screen, which is exactly what this catches.
	var m := game.board_metrics()
	var well: Vector2 = m["well"]
	var origin: Vector2 = m["origin"]
	var fits := (
		origin.x >= -0.5
		and origin.y >= -0.5
		and well.x > 0.0
		and well.y > 0.0
		and well.x <= view.x + 0.5
		and well.y <= view.y + 0.5
	)
	if fits:
		print("%-24s well=%s origin=%s  ok" % [label, str(well.round()), str(origin)])
	else:
		print(
			"%-24s well=%s origin=%s  DOES NOT FIT IN %s"
			% [label, str(well.round()), str(origin), str(view)]
		)
		_failures += 1


func _expect_size(label: String, actual: Vector2, expected: Vector2) -> void:
	var ok := actual.is_equal_approx(expected)
	print("%-36s %-18s %s" % [label, str(actual), "ok" if ok else "EXPECTED " + str(expected)])
	if not ok:
		_failures += 1
