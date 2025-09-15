extends Panel

@export var target_path: String = "res://Scenes/Main.tscn"
@onready var _bar: ProgressBar = %ProgressBar
@onready var _label: Label = %StatusLabel

var _loader: ResourceInteractiveLoader
var _done: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label.text = "Loading…"
	_bar.value = 0.0
	_loader = ResourceLoader.load_interactive(target_path)
	if _loader == null:
		_label.text = "Failed to start loading."
		return
	set_process(true)

func _process(_dt: float) -> void:
	if _done or _loader == null:
		return
	# Poll a few stages per frame to move faster while staying responsive
	var i := 0
	while i < 8:
		var err := _loader.poll()
		if err == ERR_FILE_EOF:
			_on_loaded(_loader.get_resource())
			return
		elif err != OK:
			_label.text = "Error loading."
			set_process(false)
			return
		i += 1

	# Update progress
	var stage := float(_loader.get_stage())
	var total := float(_loader.get_stage_count())
	if total > 0.0:
		_bar.value = stage / total

func _on_loaded(res: Resource) -> void:
	_done = true
	_bar.value = 1.0
	_label.text = "Starting…"
	var packed := res as PackedScene
	if packed:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(target_path)
