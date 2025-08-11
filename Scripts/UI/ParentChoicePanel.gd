extends Panel
signal parent_chosen(is_parent:bool)

@export var yes_btn_path: NodePath
@export var no_btn_path: NodePath

@onready var yes_btn: Button = get_node(yes_btn_path)
@onready var no_btn : Button = get_node(no_btn_path)

func _ready() -> void:
	yes_btn.pressed.connect(_on_yes)
	no_btn .pressed.connect(_on_no)
	mouse_filter = MOUSE_FILTER_STOP

func _on_yes(): parent_chosen.emit(true); queue_free()
func _on_no() : parent_chosen.emit(false); queue_free()
