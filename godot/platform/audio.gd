class_name GameAudio
extends Node

# Sound-effect playback. One AudioStreamPlayer per effect so overlapping
# events (a move landing on the same frame as a lock) do not cut each other
# off — the Roku build gets this for free from cached roAudioResource objects.
#
# Trigger points mirror components/GameScreen.bs:playSounds.

const SOUND_NAMES := [
	"move",
	"rotate",
	"hard_drop",
	"lock",
	"line_clear",
	"quad_clear",
	"level_up",
	"level_whoosh",
	"game_over",
	"new_record",
	"confetti_pop",
	"combo",
	"menu_select"
]

# Maps the simple game event kinds to the effect they play. lineClear, levelUp
# and combo are handled explicitly in play_events: they choose or layer sounds
# based on the event payload.
const EVENT_SOUNDS := {
	"move": "move",
	"rotate": "rotate",
	"hardDrop": "hard_drop",
	"lock": "lock",
	"gameOver": "game_over",
	"pause": "menu_select",
	"resume": "menu_select"
}

var _players := {}


func _ready() -> void:
	for name in SOUND_NAMES:
		var path := "res://assets/sounds/%s.ogg" % name
		if not ResourceLoader.exists(path):
			push_warning("missing sound effect: " + path)
			continue
		var player := AudioStreamPlayer.new()
		player.stream = load(path)
		player.bus = "Master"
		add_child(player)
		_players[name] = player


func play(name: String) -> void:
	if _players.has(name):
		var player: AudioStreamPlayer = _players[name]
		player.pitch_scale = 1.0
		player.play()


# The classic reward ladder: the same blip raised roughly a semitone per step.
func play_pitched(name: String, steps: int) -> void:
	if _players.has(name):
		var player: AudioStreamPlayer = _players[name]
		player.pitch_scale = pow(2.0, clampi(steps, 0, 12) / 12.0)
		player.play()


# Drains a game state's events array into sound effects.
func play_events(events: Array) -> void:
	for event in events:
		var kind := str(event["kind"])
		match kind:
			"lineClear":
				# A quad is the game's peak moment and gets its own fanfare.
				play("quad_clear" if int(event.get("lines", 0)) >= 4 else "line_clear")
			"levelUp":
				# The sparkle plus the airy sweep that rides the visual wave.
				play("level_up")
				play("level_whoosh")
			"combo":
				play_pitched("combo", int(event.get("count", 1)))
			_:
				if EVENT_SOUNDS.has(kind):
					play(EVENT_SOUNDS[kind])
