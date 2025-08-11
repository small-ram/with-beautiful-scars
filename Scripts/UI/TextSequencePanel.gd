extends Panel
signal intro_finished

var lines : Array[String] = []

@export var label_path: NodePath = "CenterContainer/VBoxContainer/LineLabel"
@onready var _label : Label = get_node(label_path)
var _idx : int = 0
@export var line_delay : float = 2.0

func _ready() -> void:
		if lines.is_empty():
				queue_free()
				return
		_label.text = lines[_idx]
		mouse_filter = Control.MOUSE_FILTER_STOP
		_wait_and_advance()

func _wait_and_advance() -> void:
		await get_tree().create_timer(line_delay).timeout
		_advance()

func _advance() -> void:
		_idx += 1
		if _idx >= lines.size():
				intro_finished.emit()
				queue_free()
		else:
				_label.text = lines[_idx]
				_wait_and_advance()
