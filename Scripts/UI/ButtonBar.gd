extends HBoxContainer
@onready var restart_btn := $RestartBtn
func _ready():
		var sc := get_tree().current_scene.get_node_or_null("StageController")
		if sc:
				restart_btn.pressed.connect(sc.reset)
