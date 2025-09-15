extends Panel

@export_node_path("Button") var new_game_btn_path: NodePath = NodePath("HBoxContainer/NewGameBtn")
const MAIN_SCENE_PATH := "res://Scenes/Main.tscn"

var _btn: Button
var _preload_requested: bool = false
var _packed: PackedScene = null

func _ready() -> void:
	call_deferred("_wire")
	# Kick off threaded preload ASAP
	var err := ResourceLoader.load_threaded_request(MAIN_SCENE_PATH)
	if err == OK:
		_preload_requested = true

func _process(_dt: float) -> void:
	if _preload_requested and _packed == null:
		var st := ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_packed = ResourceLoader.load_threaded_get(MAIN_SCENE_PATH) as PackedScene

func _wire() -> void:
	_btn = get_node_or_null(new_game_btn_path) as Button
	if _btn == null:
		_btn = find_child("NewGameBtn", true, false) as Button
	if _btn == null:
		push_error("StartMenu: NewGameBtn not found at %s and not found by name." % str(new_game_btn_path))
		return
	if not _btn.pressed.is_connected(_on_new_game):
		_btn.pressed.connect(_on_new_game)
	mouse_filter = MOUSE_FILTER_STOP
	_btn.grab_focus()

func _on_new_game() -> void:
	_btn.disabled = true

	# WebAudio unlock
	if is_instance_valid(AudioManager) and AudioManager.has_method("unlock_on_user_gesture"):
		AudioManager.unlock_on_user_gesture()

	# Defensive dialogue cleanup
	if is_instance_valid(DialogueManager):
		DialogueManager.clear_cache()
		if DialogueManager.is_active():
			DialogueManager.close()

	# If preloaded, switch instantly; else wait a few frames until it finishes.
	if _packed:
		get_tree().change_scene_to_packed(_packed)
	else:
		await get_tree().process_frame
		# Optional: show a tiny "Loading…" label or dim panel here
		while _packed == null:
			var st := ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH)
			if st == ResourceLoader.THREAD_LOAD_LOADED:
				_packed = ResourceLoader.load_threaded_get(MAIN_SCENE_PATH) as PackedScene
				break
			await get_tree().process_frame
		get_tree().change_scene_to_packed(_packed)
