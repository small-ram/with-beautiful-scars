extends Panel
signal difficulty_chosen(is_easy:bool)

@onready var easy := $"VBoxContainer/HBoxContainer/EasyBtn"
@onready var hard := $"VBoxContainer/HBoxContainer/HardBtn"

func _ready() -> void:
	easy.pressed.connect(func(): difficulty_chosen.emit(true);  queue_free())
	hard.pressed.connect(func(): difficulty_chosen.emit(false); queue_free())
	mouse_filter = MOUSE_FILTER_STOP
