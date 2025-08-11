extends HBoxContainer
@onready var restart_btn := $RestartBtn
@onready var quit_btn    := $QuitBtn
func _ready():
		var sc := get_tree().current_scene.get_node_or_null("StageController")
		if sc:
				restart_btn.pressed.connect(sc.reset)
		quit_btn.pressed.connect(get_tree().quit)
