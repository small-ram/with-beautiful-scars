extends Panel
signal intro_finished

var lines : Array[String] = []

@export var label_path: NodePath = "CenterContainer/VBoxContainer/LineLabel"
@onready var _label : Label = get_node(label_path)
var _idx : int = 0

func _ready() -> void:
	if lines.is_empty():
		queue_free()
		return
	_label.text = lines[_idx]
	# Consume clicks so they don’t pass through to gameplay
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_unhandled_input(false) # not needed; we use _gui_input()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		_advance()

func _advance() -> void:
	_idx += 1
	if _idx >= lines.size():
		intro_finished.emit()
		queue_free()
	else:
		_label.text = lines[_idx]
