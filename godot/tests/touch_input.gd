extends Node

# Touch input smoke test: proves a finger on the well actually reaches the
# game.
#
# This exists because nothing else in the repository exercised touch. The
# desktop playtests all used the keyboard, so a Control silently swallowing
# InputEventScreenTouch before InputRouter ever saw it would look completely
# fine right up until someone opened the game on a phone.
#
# Events are pushed straight into the viewport, the same path a real finger
# takes, so the assertions cover the whole chain: viewport, GUI consumption,
# InputRouter gesture recognition, and the game state that comes out.
#
# Runs as a SCENE, not --script, for the same reason as smoke_layout.gd: the
# autoloads game.gd needs are only registered in scene mode.
#
#   godot --headless --path godot res://tests/TouchInput.tscn

const VIEW := Vector2(1080, 1920)

var _failures := 0
var _game: GameScreen


func _ready() -> void:
	_game = GameScreen.new()
	_game.size = VIEW
	add_child(_game)
	await get_tree().process_frame
	_game.start_game("Tester", 0)
	await get_tree().process_frame

	await _check_drag_moves_sideways()
	await _check_tap_rotates()
	await _check_flick_hard_drops()

	print("")
	if _failures == 0:
		print("BRICKRAIN_TOUCH_RESULT: PASS")
	else:
		print("BRICKRAIN_TOUCH_RESULT: FAIL (" + str(_failures) + ")")
	get_tree().quit(0 if _failures == 0 else 1)


# --- gestures -------------------------------------------------------------


# A drag across the well is how a player moves a piece. The step threshold is
# a fraction of the short side (InputRouter.SWIPE_STEP_RATIO), so one long
# drag is several steps.
func _check_drag_moves_sideways() -> void:
	var before := _active_x()
	await _drag(_well_centre(), Vector2(VIEW.x * 0.25, 0.0), 5)
	var after := _active_x()
	_expect(after > before, "drag right moves the piece right (x %d -> %d)" % [before, after])

	before = _active_x()
	await _drag(_well_centre(), Vector2(-VIEW.x * 0.25, 0.0), 5)
	after = _active_x()
	_expect(after < before, "drag left moves the piece left (x %d -> %d)" % [before, after])


func _check_tap_rotates() -> void:
	var before := _active_rotation()
	await _tap(_well_centre())
	var after := _active_rotation()
	_expect(after != before, "tap rotates the piece (rotation %d -> %d)" % [before, after])


# A fast, long downward flick is the hard drop, and a hard drop locks the
# piece: the surest signal is that the well gained settled cells.
func _check_flick_hard_drops() -> void:
	var before := _filled_cells()
	await _drag(_well_centre(), Vector2(0.0, VIEW.y * 0.35), 3, 0.0)
	await get_tree().process_frame
	var after := _filled_cells()
	_expect(after > before, "downward flick hard drops (filled cells %d -> %d)" % [before, after])


# --- synthetic events -----------------------------------------------------


func _tap(at: Vector2) -> void:
	_push_touch(at, true)
	await get_tree().process_frame
	_push_touch(at, false)
	await get_tree().process_frame


func _drag(from: Vector2, delta: Vector2, steps: int, settle: float = 0.0) -> void:
	_push_touch(from, true)
	await get_tree().process_frame
	var last := from
	for i in range(1, steps + 1):
		var at := from + delta * (float(i) / float(steps))
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = at
		event.relative = at - last
		get_viewport().push_input(event)
		last = at
		await get_tree().process_frame
	_push_touch(last, false)
	await get_tree().process_frame
	if settle > 0.0:
		await get_tree().create_timer(settle).timeout


func _push_touch(at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = pressed
	get_viewport().push_input(event)


# --- state readers --------------------------------------------------------


func _well_centre() -> Vector2:
	var m := _game.board_metrics()
	var origin: Vector2 = m["origin"]
	var well: Vector2 = m["well"]
	return _game.get_global_rect().position + origin + well * 0.5


func _state() -> Dictionary:
	return _game._state


func _active_x() -> int:
	var active = _state()["active"]
	return -999 if active == null else int(active["x"])


func _active_rotation() -> int:
	var active = _state()["active"]
	return -999 if active == null else int(active["rotation"])


func _filled_cells() -> int:
	var grid: Array = _state()["board"]["grid"]
	var count := 0
	for value in grid:
		if int(value) != 0:
			count += 1
	return count


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  ok   " + label)
	else:
		print("  FAIL " + label)
		_failures += 1
