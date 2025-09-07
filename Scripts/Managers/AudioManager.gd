# Scripts/Managers/AudioManager.gd
extends Node

@export var default_bus: String = "SFX"  # falls back to Master if not present

var _cache  : Dictionary = {}                # sfx name -> AudioStream
var _player : AudioStreamPlayer = null       # one reusable player
var _unlock_dummy: AudioStreamPlayer = null  # used once to unlock WebAudio

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = _resolve_bus(default_bus)
	add_child(_player)

func _resolve_bus(name: String) -> String:
	for i in range(AudioServer.get_bus_count()):
		if AudioServer.get_bus_name(i) == name:
			return name
	return "Master"

# ----------------------------------------------------------------
func play_sfx(sfx_name: String) -> void:
	if sfx_name == "":
		return
	var stream: AudioStream = _cache.get(sfx_name)
	if stream == null:
		stream = _find_and_load(sfx_name)
		if stream == null:
			if OS.is_debug_build():
				push_warning("Missing SFX: " + sfx_name)
			return
		_cache[sfx_name] = stream
	_player.stream = stream
	_player.play()

# Web-friendly extension order (MP3 first on Web for Safari/iOS)
func _find_and_load(base: String) -> AudioStream:
	var exts: PackedStringArray
	if OS.get_name() == "Web":
		exts = PackedStringArray([".mp3", ".ogg", ".wav"])
	else:
		exts = PackedStringArray([".wav", ".ogg", ".mp3"])

	for ext in exts:
		var path := "res://Assets/Sounds/%s%s" % [base, ext]
		if FileAccess.file_exists(path):
			return load(path) as AudioStream
	return null


# ----------------------------------------------------------------
# Call this ONCE from a user gesture (e.g., New Game button) before any audio
func unlock_on_user_gesture() -> void:
	if _unlock_dummy != null:
		return
	_unlock_dummy = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100.0
	gen.buffer_length = 0.1
	_unlock_dummy.stream = gen
	add_child(_unlock_dummy)
	_unlock_dummy.play()

	# Push a tiny bit of silence to nudge the WebAudio context
	var pb := _unlock_dummy.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		var frames := int(gen.mix_rate * 0.02)
		for i in range(frames):
			pb.push_frame(Vector2.ZERO)

	get_tree().create_timer(0.05).timeout.connect(
		func():
			if is_instance_valid(_unlock_dummy):
				_unlock_dummy.stop(),
		Object.CONNECT_ONE_SHOT
	)

# ----------------------------------------------------------------
func stop_all() -> void:
	if _player:
		_player.stop()
