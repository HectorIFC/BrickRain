class_name InputRouter
extends Node

# FR02: maps keyboard AND touch onto one action vocabulary, so the game scene
# never has to know which device produced an action.
#
# Actions emitted: move_left, move_right, soft_drop, hard_drop, rotate_cw,
# rotate_ccw, hold, pause.
#
# DAS (delayed auto-shift) is ported from components/GameScreen.bs: the first
# repeat waits DAS_INITIAL_MS, subsequent ones fire every DAS_REPEAT_MS.
#
# Key bindings follow desktop falling-block convention rather than the Roku
# remote layout (Up rotates instead of hard-dropping; Space hard-drops), since
# that is what keyboard players expect.

signal action(name: String)

const DAS_INITIAL_MS := 250
const DAS_REPEAT_MS := 50

# Touch tuning, in fractions of the viewport's shorter side so behaviour is
# consistent across screen sizes.
const TAP_MAX_TRAVEL_RATIO := 0.04
const TAP_MAX_DURATION_MS := 250
const SWIPE_STEP_RATIO := 0.06
const HARD_DROP_TRAVEL_RATIO := 0.18
const HARD_DROP_MAX_DURATION_MS := 300

const REPEATABLE := ["move_left", "move_right", "soft_drop"]

var _enabled := true
var _held_action := ""
var _das_elapsed_ms := 0.0
var _das_phase := "initial"

# Touch gesture state.
var _touch_active := false
var _touch_start := Vector2.ZERO
var _touch_last := Vector2.ZERO
var _touch_start_ms := 0
var _touch_travel := 0.0
var _gesture_consumed := false
# Sideways steps disqualify a flick; downward ones must not. See _handle_touch.
var _moved_sideways := false

var _key_map := {
	KEY_LEFT: "move_left",
	KEY_A: "move_left",
	KEY_RIGHT: "move_right",
	KEY_D: "move_right",
	KEY_DOWN: "soft_drop",
	KEY_S: "soft_drop",
	KEY_SPACE: "hard_drop",
	KEY_UP: "rotate_cw",
	KEY_W: "rotate_cw",
	KEY_X: "rotate_cw",
	KEY_Z: "rotate_ccw",
	KEY_C: "hold",
	KEY_SHIFT: "hold",
	KEY_ESCAPE: "pause",
	KEY_P: "pause"
}


func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		release_all()


# Clears any held key so auto-shift cannot keep firing across a pause or a
# scene change.
func release_all() -> void:
	_held_action = ""
	_touch_active = false
	_gesture_consumed = false


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventKey:
		_handle_key(event)
	elif event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_key(event: InputEventKey) -> void:
	if event.echo:
		return
	if not _key_map.has(event.keycode):
		return
	var name: String = _key_map[event.keycode]
	if not event.pressed:
		if name == _held_action:
			_held_action = ""
		return
	_emit(name)
	if name in REPEATABLE:
		_begin_das(name)
	get_viewport().set_input_as_handled()


func _begin_das(name: String) -> void:
	_held_action = name
	_das_phase = "initial"
	_das_elapsed_ms = 0.0


func _process(delta: float) -> void:
	if not _enabled or _held_action == "":
		return
	_das_elapsed_ms += delta * 1000.0
	var threshold := DAS_INITIAL_MS if _das_phase == "initial" else DAS_REPEAT_MS
	while _das_elapsed_ms >= threshold:
		_das_elapsed_ms -= threshold
		_das_phase = "repeat"
		threshold = DAS_REPEAT_MS
		_emit(_held_action)


# --- touch ---
#
# Tap             -> rotate_cw
# Horizontal drag -> move_left / move_right, one step per swipe increment
# Downward drag   -> soft_drop, one step per swipe increment
# Fast long flick down -> hard_drop
func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_active = true
		_touch_start = event.position
		_touch_last = event.position
		_touch_start_ms = Time.get_ticks_msec()
		_touch_travel = 0.0
		_gesture_consumed = false
		_moved_sideways = false
		return

	if not _touch_active:
		return
	_touch_active = false
	_held_action = ""
	var duration := Time.get_ticks_msec() - _touch_start_ms
	var delta := event.position - _touch_start

	# A fast, long downward flick is a hard drop.
	#
	# The disqualifier here is deliberately _moved_sideways, not
	# _gesture_consumed: a flick has to cross the soft-drop step (6% of the
	# short side) on its way to the hard-drop distance (18%), so testing
	# "nothing was consumed" made the gesture unreachable in practice, and the
	# player got a stream of soft drops instead. A sideways drag still cannot
	# turn into a slam.
	if (
		not _moved_sideways
		and delta.y >= _short_side() * HARD_DROP_TRAVEL_RATIO
		and absf(delta.y) > absf(delta.x)
		and duration <= HARD_DROP_MAX_DURATION_MS
	):
		_emit("hard_drop")
		return

	# Anything short and brief that never turned into a drag is a tap.
	if not _gesture_consumed and _touch_travel <= _short_side() * TAP_MAX_TRAVEL_RATIO and duration <= TAP_MAX_DURATION_MS:
		_emit("rotate_cw")


func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _touch_active:
		return
	_touch_travel += event.relative.length()
	var step := _short_side() * SWIPE_STEP_RATIO
	var delta := event.position - _touch_last

	if absf(delta.x) >= step and absf(delta.x) >= absf(delta.y):
		_emit("move_right" if delta.x > 0.0 else "move_left")
		_touch_last = event.position
		_gesture_consumed = true
		_moved_sideways = true
	elif delta.y >= step:
		_emit("soft_drop")
		_touch_last = event.position
		_gesture_consumed = true


# The on-screen buttons drive the same DAS the keyboard uses, so holding the
# left button repeats exactly like holding the left key.
func press_action(name: String) -> void:
	if not _enabled:
		return
	_emit(name)
	if name in REPEATABLE:
		_begin_das(name)


func release_action(name: String) -> void:
	if _held_action == name:
		_held_action = ""


func _short_side() -> float:
	var size := get_viewport().get_visible_rect().size
	return minf(size.x, size.y)


func _emit(name: String) -> void:
	action.emit(name)
