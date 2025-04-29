extends Node
signal dialogue_closed(id)

var data := {}

func load_tree(id:String) -> void:
	var file := "res://Data/Dialogue/%s.json" % id
	var j = JSON.new()
	if j.parse(FileAccess.get_file_as_string(file)) == OK:
		data = j.data
		_show_panel(data["text"], data["choices"])
	else:
		push_error("Dialogue JSON parse error: %s" % file)

const PANEL_SCENE := preload("res://Scenes/Overlays/DialoguePanel.tscn")

func _show_panel(text:String, choices:Array) -> void:
	var panel := PANEL_SCENE.instantiate()          # DialoguePanel.tscn
	# --- THIS line finds the OverlayLayer CanvasLayer in Main.tscn ---
	var overlay := get_tree()                       \
		.current_scene                              \
		.get_node("UI/OverlayLayer")
	overlay.add_child(panel)                        # add panel to layer
	panel.set_text(text, choices)
	panel.choice_made.connect(_on_choice)

func _on_choice(next_id:String) -> void:
	dialogue_closed.emit(next_id)
	load_tree(next_id)
