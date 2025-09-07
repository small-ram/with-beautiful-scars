extends Panel
signal parent_chosen(is_parent: bool)

@export var yes_btn_path: NodePath = NodePath("CenterContainer/VBoxContainer/HBoxContainer/YesBtn")
@export var no_btn_path: NodePath  = NodePath("CenterContainer/VBoxContainer/HBoxContainer/NoBtn")

var _yes_btn: Button
var _no_btn: Button

func _ready() -> void:
	# Resolve via exported paths, then fall back by name search (editor renames safe)
	_yes_btn = get_node_or_null(yes_btn_path) as Button
	if _yes_btn == null:
		_yes_btn = find_child("YesBtn", true, false) as Button

	_no_btn = get_node_or_null(no_btn_path) as Button
	if _no_btn == null:
		_no_btn = find_child("NoBtn", true, false) as Button

	if _yes_btn == null or _no_btn == null:
		push_error("ParentChoicePanel: Could not resolve Yes/No buttons at %s / %s"
			% [str(yes_btn_path), str(no_btn_path)])
		return

	_yes_btn.pressed.connect(_on_yes)
	_no_btn.pressed.connect(_on_no)
	mouse_filter = MOUSE_FILTER_STOP

func _on_yes() -> void:
	parent_chosen.emit(true)
	queue_free()

func _on_no() -> void:
	parent_chosen.emit(false)
	queue_free()
