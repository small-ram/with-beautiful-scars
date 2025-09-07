# Scripts/Managers/MusicManager.gd
extends Node

@export var default_bus: String = "Music"  # falls back to Master if not found
@export var fade_seconds: float = 0.8

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _current: AudioStreamPlayer
var _next: AudioStreamPlayer

func _ready() -> void:
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	add_child(_a); add_child(_b)

	var bus_name := _resolve_bus(default_bus)
	_a.bus = bus_name
	_b.bus = bus_name

	_a.volume_db = -80.0
	_b.volume_db = -80.0
	_current = null
	_next = null

func _resolve_bus(name: String) -> String:
	for i in range(AudioServer.get_bus_count()):
		if AudioServer.get_bus_name(i) == name:
			return name
	return "Master"

func _load_stream(s: Variant) -> AudioStream:
	if s is AudioStream:
		return s
	if s is String and s != "":
		# accept full paths or basenames; try direct path first
		if ResourceLoader.exists(s):
			return load(s) as AudioStream
		# try basename in Assets/Sounds with web-friendly extension order
		return _find_and_load_basename(s)
	return null

func _find_and_load_basename(base: String) -> AudioStream:
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


func play(s: Variant, fade: float = -1.0, loop: bool = true) -> void:
	var f := (fade if fade >= 0.0 else fade_seconds)
	var stream := _load_stream(s)
	if stream == null:
		return

	# Respect loop flag if the stream supports it
	if stream.has_method("set_loop"):
		stream.call("set_loop", loop)

	if _current == null or not _current.playing:
		_current = _a
		_next = _b
		_current.stream = stream
		_current.pitch_scale = 1.0
		_current.play()
		_current.stream_paused = false
		_current.volume_db = -80.0
		_fade_to(_current, 0.0, f)
		return

	_next = (_a if _current == _b else _b)
	_next.stream = stream
	_next.pitch_scale = 1.0
	_next.play()
	_next.stream_paused = false
	_next.volume_db = -80.0

	# Crossfade
	_fade_to(_next, 0.0, f)
	_fade_to(_current, -80.0, f).finished.connect(
		func():
			_current.stop()
			_current = _next
			_next = null,
		Object.CONNECT_ONE_SHOT
	)

func stop(fade: float = -1.0) -> void:
	if _current == null:
		return
	var f := (fade if fade >= 0.0 else fade_seconds)
	_fade_to(_current, -80.0, f).finished.connect(
		func():
			_current.stop()
			_current = null,
		Object.CONNECT_ONE_SHOT
	)

func set_volume_db(db: float) -> void:
	if _current:
		_current.volume_db = db

func _fade_to(p: AudioStreamPlayer, target_db: float, t: float) -> Tween:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(p, "volume_db", target_db, max(0.0, t))
	return tw
