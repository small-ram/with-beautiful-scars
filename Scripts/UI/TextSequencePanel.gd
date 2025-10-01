extends Panel
signal intro_finished

@export var lines: Array[String] = []
@export var advance_text: String = "Next"
@export var label_path: NodePath = ""
@export var advance_btn_path: NodePath = ""

@onready var _label: Label = get_node_or_null(label_path)
@onready var _btn: Button = get_node_or_null(advance_btn_path)

var _idx: int = 0

func _ready() -> void:
	if lines.is_empty():
		queue_free(); return

	# Panels: centered text
	if _label:
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_label.text = lines[_idx]

	mouse_filter = Control.MOUSE_FILTER_STOP

	# Robustly resolve the button (path or by name)
	if _btn == null:
		_btn = find_child("AdvanceBtn", true, false) as Button
	if _btn:
		_btn.text = advance_text
		# Auto-size the button to its text and center it in the VBox
		_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_btn.custom_minimum_size = Vector2.ZERO
		if not _btn.pressed.is_connected(_advance):
			_btn.pressed.connect(_advance)
		_btn.grab_focus()
	else:
		push_error("TextSequencePanel: AdvanceBtn not found at %s and not found by name." % str(advance_btn_path))

# Button-only advance (no click-anywhere)
func _gui_input(_ev: InputEvent) -> void:
	pass

func _advance() -> void:
	_idx += 1
	if _idx >= lines.size():
		intro_finished.emit()
		queue_free()
	else:
		if _label:
			_label.text = lines[_idx]
