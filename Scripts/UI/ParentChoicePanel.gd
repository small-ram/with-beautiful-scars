extends Panel
signal parent_chosen(is_parent:bool)

@onready var yes_btn := $"VBoxContainer/HBoxContainer/YesBtn"
@onready var no_btn  := $"VBoxContainer/HBoxContainer/NoBtn"

func _ready() -> void:
	yes_btn.pressed.connect(_on_yes)
	no_btn .pressed.connect(_on_no)
	mouse_filter = MOUSE_FILTER_STOP

func _on_yes(): parent_chosen.emit(true); queue_free()
func _on_no() : parent_chosen.emit(false); queue_free()
