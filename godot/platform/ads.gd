extends Node

# Autoload. Rewarded video (FR04).
#
# Wraps FBBridge with the states the UI actually needs to reason about:
# is there an offer worth showing, and did the player earn the reward.
#
# Two failure modes are ordinary, not exceptional, and are handled explicitly
# rather than silently swallowed:
#
#   no fill      - the network has no inventory right now. The offer must be
#                  hidden, not shown-then-failed.
#   user dismiss - the player closed the video early. The reward must NOT be
#                  granted; only a completed view counts.
#
# The ad is preloaded during play so the offer is instant at game over, which
# is the only moment it is shown.

signal availability_changed(available: bool)
signal reward_granted
signal reward_failed(code: String)

# Codes that mean "there is simply nothing to show" rather than a real fault.
const NO_INVENTORY_CODES := ["ADS_NO_FILL", "RATE_LIMITED", "CLIENT_UNSUPPORTED_OPERATION"]

var _available := false
var _loading := false
var _showing := false


func _ready() -> void:
	FBBridge.rewarded_loaded.connect(_on_loaded)
	FBBridge.rewarded_shown.connect(_on_shown)


# True when an ad is loaded and ready to play right now.
func is_offer_available() -> bool:
	return _available and not _showing


# Starts a preload. Safe to call repeatedly; no-ops while one is in flight or
# an ad is already banked.
func preload_ad() -> void:
	if _loading or _available or _showing:
		return
	var placement := AppConfig.rewarded_placement_id()
	if placement == "":
		# Expected before Phase 6 wires the dashboard ids; not an error.
		return
	if not FBBridge.is_available():
		return
	_loading = true
	FBBridge.load_rewarded(placement)


func show_ad() -> void:
	if not is_offer_available():
		reward_failed.emit("ADS_NOT_LOADED")
		return
	_showing = true
	_set_available(false)
	FBBridge.show_rewarded()


func _on_loaded(ok: bool, code: String) -> void:
	_loading = false
	if ok:
		_set_available(true)
		return
	_set_available(false)
	if code in NO_INVENTORY_CODES:
		# Nothing to show; stay quiet and simply leave the offer hidden.
		return
	push_warning("rewarded video failed to load: " + code)


func _on_shown(ok: bool, code: String) -> void:
	_showing = false
	if ok:
		reward_granted.emit()
	else:
		reward_failed.emit(code)
	# The consumed ad object is gone either way; line up the next one.
	preload_ad()


func _set_available(value: bool) -> void:
	if _available == value:
		return
	_available = value
	availability_changed.emit(value)
