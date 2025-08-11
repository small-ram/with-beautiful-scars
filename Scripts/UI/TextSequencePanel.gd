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
		mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event : InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
				_advance()

func _advance() -> void:
		_idx += 1
		if _idx >= lines.size():
				intro_finished.emit()
				queue_free()
		else:
				_label.text = lines[_idx]
