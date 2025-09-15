# Scripts/Managers/AudioManager.gd
extends Node

@export var default_bus: String = "Master"  # set to "Master" on Web if needed

var _cache: Dictionary = {}                         # key -> AudioStream
var _player: AudioStreamPlayer                     = null
var _unlock_dummy: AudioStreamPlayer               = null

# Map friendly keys (e.g., "photoSnap") to exact resource paths/UIDs
var _aliases: Dictionary = {}                      # key -> String (path or uid)
var _last_resolved: Dictionary = {}                # key -> String (debug: final path)

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = _resolve_bus(default_bus)
	add_child(_player)

func _resolve_bus(bus_name: String) -> String:
	for i in range(AudioServer.get_bus_count()):
		if AudioServer.get_bus_name(i) == bus_name:
			return bus_name
	return "Master"

# ---------- PUBLIC API ----------
func set_alias(key: String, path_or_uid: String) -> void:
	_aliases[key] = path_or_uid

func play_sfx(sfx_name: String) -> void:
	if sfx_name == "":
		return
	var stream: AudioStream = _cache.get(sfx_name) as AudioStream
	if stream == null:
		stream = _find_and_load(sfx_name)
		if stream == null:
			push_warning("AudioManager: SFX not found: " + sfx_name)
			return
		_cache[sfx_name] = stream

	_player.stream = stream
	_player.play()

	# Debug print (typed to avoid Variant warnings)
	if OS.is_debug_build():
		var bus_name: StringName = _player.bus
		var resolved: String     = str(_last_resolved.get(sfx_name, "<unknown>"))
		print("[SFX] ", sfx_name, " → ", resolved, "  (bus=", String(bus_name), ")")

func preload_sfx(names: Array[String]) -> void:
	for n in names:
		if n == "": continue
		if _cache.has(n): continue
		var s: AudioStream = _find_and_load(n)
		if s != null:
			_cache[n] = s
		else:
			push_warning("AudioManager: preload missing SFX: " + n)

# ---------- resolution ----------
func _exts_for_platform() -> PackedStringArray:
	if OS.get_name() == "Web":
		return PackedStringArray([".mp3", ".ogg", ".wav"])
	return PackedStringArray([".wav", ".ogg", ".mp3"])

func _find_and_load(key: String) -> AudioStream:
	var base: String = key
	if _aliases.has(key):
		base = _aliases[key] as String

	var exts: PackedStringArray = _exts_for_platform()

	# Full path or UID?
	if base.begins_with("res://") or base.begins_with("uid://"):
		# Already has extension?
		if ResourceLoader.exists(base):
			_last_resolved[key] = base
			return load(base) as AudioStream
		# Try common extensions if none present
		if not base.get_file().contains("."):
			for ext in exts:
				var p: String = base + ext
				if FileAccess.file_exists(p):
					_last_resolved[key] = p
					return load(p) as AudioStream
		return null

	# Basename within Assets/Sounds (case-sensitive on Web)
	for ext in exts:
		var path: String = "res://Assets/Sounds/%s%s" % [base, ext]
		if FileAccess.file_exists(path):
			_last_resolved[key] = path
			return load(path) as AudioStream

	return null

# ---------- Web unlock ----------
func unlock_on_user_gesture() -> void:
	if _unlock_dummy != null:
		return
	_unlock_dummy = AudioStreamPlayer.new()
	add_child(_unlock_dummy)

	# 50 ms of stereo silence at 44.1 kHz, 16-bit
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = true
	var samples: int = int(wav.mix_rate * 0.05)              # 0.05s
	var bytes := PackedByteArray()
	bytes.resize(samples * 2 /*channels*/ * 2 /*bytes*/ )
	for i in range(bytes.size()):
		bytes[i] = 0
	wav.data = bytes

	_unlock_dummy.stream = wav
	_unlock_dummy.play()

	get_tree().create_timer(0.06).timeout.connect(
		func() -> void:
			if is_instance_valid(_unlock_dummy):
				_unlock_dummy.stop(),
		Object.CONNECT_ONE_SHOT
	)

func stop_all() -> void:
	if _player:
		_player.stop()
