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

func _show_panel(text:String, choices:Array) -> void:
	var panel := preload("res://Scenes/UI/DialoguePanel.tscn").instantiate()
	get_tree().current_scene.add_child(panel)
	panel.set_text(text, choices)
	panel.choice_made.connect(_on_choice)  # fires when player clicks

func _on_choice(next_id:String) -> void:
	dialogue_closed.emit(next_id)
	load_tree(next_id)
