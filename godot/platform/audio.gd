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
	"level_up",
	"game_over",
	"new_record",
	"menu_select"
]

# Maps a game event kind to the effect it plays.
const EVENT_SOUNDS := {
	"move": "move",
	"rotate": "rotate",
	"hardDrop": "hard_drop",
	"lock": "lock",
	"lineClear": "line_clear",
	"levelUp": "level_up",
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
		_players[name].play()


# Drains a game state's events array into sound effects.
func play_events(events: Array) -> void:
	for event in events:
		var kind := str(event["kind"])
		if EVENT_SOUNDS.has(kind):
			play(EVENT_SOUNDS[kind])
