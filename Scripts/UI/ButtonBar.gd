extends HBoxContainer
@onready var restart_btn := $RestartBtn
@onready var quit_btn    := $QuitBtn
func _ready():
	restart_btn.pressed.connect(get_tree().reload_current_scene)
	quit_btn.pressed.connect(get_tree().quit)
