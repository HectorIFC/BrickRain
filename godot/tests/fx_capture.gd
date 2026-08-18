extends Node

# Frame-capture harness for effects too fast to screenshot by hand: the
# LEVEL-up popup, the wave, and the new-record fireworks show.
#
# It does NOT assert anything - it drives a real GameScreen through a scripted
# effects timeline so Movie Maker mode can record every frame. Run with:
#
#   godot --path godot --write-movie ../build/captures/fx.png --fixed-fps 30 \
#         res://tests/FxCapture.tscn
#
# (`make godot-capture` wraps exactly that.) --write-movie renders offline at
# a fixed clock, so nothing depends on machine speed - the same reason a
# background browser tab, whose throttled clock once stretched a 0.9 s timer
# to 18 s, is the WRONG place to judge these animations.
#
# Runs as a SCENE (not --script) for the same reason as smoke_layout.gd: the
# autoloads game.gd needs are only registered in scene mode.

# Cue times in seconds; the popup rise lasts 0.85 s, a firework 0.45 s + burst.
const CUES := [
	{"at": 0.6, "cue": "level"},
	{"at": 2.2, "cue": "fireworks"},
	{"at": 5.6, "cue": "quit"},
]

var _game: GameScreen
var _t := 0.0
var _next_cue := 0


func _ready() -> void:
	_game = GameScreen.new()
	_game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_game)
	_game.size = get_viewport().get_visible_rect().size
	_game.start_game("Tester", 0)


func _process(delta: float) -> void:
	_t += delta
	if _next_cue >= CUES.size() or _t < CUES[_next_cue]["at"]:
		return
	match str(CUES[_next_cue]["cue"]):
		"level":
			# The exact calls game.gd makes on a levelUp event.
			_game._fx.level_up()
			_game._fx.popup("LEVEL 2", UiStyle.SIZE_OVERLAY_TITLE)
			_game._audio.play("level_up")
			_game._audio.play("level_whoosh")
		"fireworks":
			# The record celebration: fanfare + confetti, then the looping show.
			_game._running = false
			_game._audio.play("new_record")
			_game._audio.play("confetti_pop")
			_game._fx.confetti()
			_game._celebrating = true
			_game._next_firework_s = 0.2
		"quit":
			get_tree().quit()
	_next_cue += 1
