# Scripts/UI/StartMenu.gd
extends Panel

@export_node_path("Button")
var new_game_btn_path: NodePath = NodePath("CenterContainer/VBoxContainer/HBoxContainer/NewGameBtn")

var _btn: Button

func _ready() -> void:
	# Defer wiring to the next frame to ensure all children (including the
	# HBoxContainer/NewGameBtn declared later in the scene file) are present.
	call_deferred("_wire")

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
	# (Web) unlock audio on a user gesture if your AudioManager has this helper.
	if is_instance_valid(AudioManager) and AudioManager.has_method("unlock_on_user_gesture"):
		AudioManager.unlock_on_user_gesture()

	# Defensive: clear any lingering dialogue state.
	if is_instance_valid(DialogueManager):
		DialogueManager.clear_cache()
		if DialogueManager.is_active():
			DialogueManager.close()

	# Defer the scene change so we don't mutate the tree mid-callback.
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/Main.tscn")
