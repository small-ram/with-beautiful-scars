extends Node
signal dialogue_closed(id)

@export_node_path("CanvasLayer") var overlay_path : NodePath = NodePath("UI/OverlayLayer")

const PANEL_SCENE := preload("res://Scenes/Overlays/DialoguePanel.tscn")

var _active_panel : Node = null

func load_tree(id:String) -> void:
	var file := "res://Data/Dialogue/%s.json" % id
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(file)) != OK or typeof(j.data) != TYPE_DICTIONARY:
		push_error("Dialogue JSON parse error: %s" % file)
		return

	_show_panel(
		j.data.get("text", j.data.get("body", "")),
		j.data.get("choices", [])
	)

func _show_panel(text:String, choices:Array) -> void:
	var overlay := get_node_or_null(overlay_path)
	if overlay == null or not overlay.is_inside_tree():
		var scene := get_tree().current_scene
		overlay = scene.get_node("UI/OverlayLayer") if scene else null
	if overlay == null:
		push_error("DialogueManager: OverlayLayer missing!")
		return

	if _active_panel:
		_active_panel.queue_free()

	var panel := PANEL_SCENE.instantiate()
	overlay.add_child(panel)
	panel.set_text(text, choices)
	panel.choice_made.connect(_on_choice)
	_active_panel = panel


func _on_choice(next_id:String) -> void:
	dialogue_closed.emit(next_id)
	if next_id != "":
		load_tree(next_id)
