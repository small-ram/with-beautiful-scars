extends Node
class_name AudioManagerSingleton   # <-- NEW name avoids clash

var _cache : Dictionary = {}

@onready var _player := AudioStreamPlayer.new()

func _ready() -> void:
	add_child(_player)

func play_sfx(name:String) -> void:
	var stream:AudioStream = _cache.get(name)
	if stream == null:
		var path := "res://assets/sounds/%s.ogg" % name
		if not FileAccess.file_exists(path):
			if OS.is_debug_build(): push_warning("Missing SFX: " + path)
			return
		stream = load(path)
		_cache[name] = stream

	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	p.finished.connect(func(): p.queue_free())
	p.play()
