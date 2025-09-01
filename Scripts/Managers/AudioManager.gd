# Scripts/Managers/AudioManager.gd
extends Node

var _cache : Dictionary = {}              # file-name ➜ AudioStream
var _player : AudioStreamPlayer = null    # one reusable player

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)

# ----------------------------------------------------------------
func play_sfx(sfx_name: String) -> void:
	var stream : AudioStream = _cache.get(sfx_name)
	if stream == null:
		stream = _find_and_load(sfx_name)
		if stream == null:
			if OS.is_debug_build():
				push_warning("Missing SFX: " + sfx_name)
			return
		_cache[sfx_name] = stream

	_player.stream = stream
	_player.play()

# ----------------------------------------------------------------
func _find_and_load(base:String) -> AudioStream:
	const EXTENSIONS := [".wav", ".ogg", ".mp3"]   # search order
	for ext in EXTENSIONS:
		var path := "res://Assets/Sounds/%s%s" % [base, ext]
		if FileAccess.file_exists(path):
			return load(path)
	return null
