extends Panel
signal difficulty_chosen(is_easy:bool)

@export var easy_btn_path: NodePath
@export var hard_btn_path: NodePath

@onready var easy: Button = get_node(easy_btn_path)
@onready var hard: Button = get_node(hard_btn_path)

func _ready() -> void:
	easy.pressed.connect(func(): difficulty_chosen.emit(true);  queue_free())
	hard.pressed.connect(func(): difficulty_chosen.emit(false); queue_free())
	mouse_filter = MOUSE_FILTER_STOP
