extends Panel
signal difficulty_chosen(is_easy: bool)

@export var easy_btn_path: NodePath = NodePath("CenterContainer/VBoxContainer/HBoxContainer/EasyBtn")
@export var hard_btn_path: NodePath = NodePath("CenterContainer/VBoxContainer/HBoxContainer/HardBtn")

var _easy: Button
var _hard: Button

func _ready() -> void:
	_easy = get_node_or_null(easy_btn_path) as Button
	if _easy == null:
		_easy = find_child("EasyBtn", true, false) as Button

	_hard = get_node_or_null(hard_btn_path) as Button
	if _hard == null:
		_hard = find_child("HardBtn", true, false) as Button

	if _easy == null or _hard == null:
		push_error("DifficultyChoicePanel: Could not resolve Easy/Hard buttons at %s / %s"
			% [str(easy_btn_path), str(hard_btn_path)])
		return

	_easy.pressed.connect(func(): difficulty_chosen.emit(true);  queue_free())
	_hard.pressed.connect(func(): difficulty_chosen.emit(false); queue_free())
	mouse_filter = MOUSE_FILTER_STOP
