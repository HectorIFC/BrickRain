extends Node

# Autoload. Background music.
#
# Three things make this more than "play a stream":
#
# 1. The track is fetched over HTTP rather than loaded from res://. Everything
#    in res:// is packed into index.pck, which the browser downloads in full
#    before the first frame — so shipping the music that way would delay the
#    boot for every player. It is excluded from the export and copied to the
#    bundle root instead (see scripts/package-web.js).
#
# 2. Playback cannot start before a user gesture. Browsers block audio until
#    then, so the first play() call comes from the Play button, never from boot.
#
# 3. The "tense" variant is the same track pitched up with a low-pass opened
#    out, not a second file. It costs no extra bytes.
#
# Music sits on its own bus so the sound effects cut through it and the tense
# filter never touches them.

const TRACK_URL := "theme.ogg"
const TRACK_RES := "res://music/theme.ogg"
const BUS_NAME := "Music"

const NORMAL_PITCH := 1.0
const TENSE_PITCH := 1.10
const NORMAL_CUTOFF := 20500.0
const TENSE_CUTOFF := 3200.0
const VOLUME_DB := -7.0

var _player: AudioStreamPlayer
var _shim: JavaScriptObject = null
var _cb_track: JavaScriptObject
var _filter: AudioEffectFilter
var _bus_index := 0
var _muted := false
var _tense := false
var _wanted := false
var _ready_to_play := false


func _ready() -> void:
	_muted = Storage.load_muted()
	_setup_bus()

	_player = AudioStreamPlayer.new()
	_player.bus = BUS_NAME
	_player.volume_db = VOLUME_DB
	add_child(_player)

	_load_track()


func _setup_bus() -> void:
	_bus_index = AudioServer.get_bus_index(BUS_NAME)
	if _bus_index == -1:
		_bus_index = AudioServer.bus_count
		AudioServer.add_bus(_bus_index)
		AudioServer.set_bus_name(_bus_index, BUS_NAME)
		AudioServer.set_bus_send(_bus_index, "Master")
	# A wide-open low-pass by default; closing it is what makes the tense
	# variant sound urgent without a second recording.
	_filter = AudioEffectFilter.new()
	_filter.cutoff_hz = NORMAL_CUTOFF
	AudioServer.add_bus_effect(_bus_index, _filter)
	_apply_mute()


func _load_track() -> void:
	# In the editor and on desktop the track is still a normal resource; only
	# the web export strips it out of the pck, and only there is a fetch needed.
	if not OS.has_feature("web"):
		if ResourceLoader.exists(TRACK_RES):
			_adopt(load(TRACK_RES))
		return
	_shim = JavaScriptBridge.get_interface("BrickRainMusic")
	if _shim == null:
		push_warning("BrickRainMusic shim missing; continuing without music")
		return
	# Must stay referenced for as long as JS might call it, exactly as in
	# fb_bridge.gd; a local would be collected before the fetch resolves.
	_cb_track = JavaScriptBridge.create_callback(_on_track_ready)
	_shim.load(TRACK_URL, _cb_track)


func _on_track_ready(args: Array) -> void:
	var encoded := str(args[0]) if args.size() > 0 else ""
	if encoded == "":
		push_warning("music unavailable; continuing without it")
		return
	_adopt(AudioStreamOggVorbis.load_from_buffer(Marshalls.base64_to_raw(encoded)))


func _adopt(stream: AudioStream) -> void:
	if stream == null:
		push_warning("music stream could not be decoded; continuing without it")
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_player.stream = stream
	_ready_to_play = true
	# Surfaces in the browser console. Worth keeping: on Facebook's hosting the
	# only way to tell "music never loaded" from "music is loaded but muted" is
	# a line like this.
	print("music ready: %.1fs" % stream.get_length())
	# The track may arrive after the player already asked for it.
	if _wanted:
		_start()


# Call from a user-initiated action; browsers reject audio started any other way.
func play() -> void:
	_wanted = true
	if _ready_to_play:
		_start()


func stop() -> void:
	_wanted = false
	_player.stop()


func _start() -> void:
	if not _player.playing:
		_player.play()


# Pitched up and filtered when the stack is near the top.
func set_tense(value: bool) -> void:
	if _tense == value:
		return
	_tense = value
	_player.pitch_scale = TENSE_PITCH if value else NORMAL_PITCH
	_filter.cutoff_hz = TENSE_CUTOFF if value else NORMAL_CUTOFF


func is_muted() -> bool:
	return _muted


func set_muted(value: bool) -> void:
	_muted = value
	_apply_mute()
	Storage.save_muted(value)


# Mutes Master, not just the music bus: someone reaching for mute in a public
# place wants silence, not a game that still clicks and thuds at them.
func _apply_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), _muted)


func toggle_muted() -> bool:
	set_muted(not _muted)
	return _muted
