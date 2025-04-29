extends HBoxContainer

@onready var restart_btn: Button = $RestartBtn
@onready var quit_btn:    Button = $QuitBtn

func _ready() -> void:
	restart_btn.pressed.connect(_on_restart)
	quit_btn.pressed.connect(_on_quit)

func _on_restart() -> void:
	get_tree().reload_current_scene()

func _on_quit() -> void:
	get_tree().quit()
