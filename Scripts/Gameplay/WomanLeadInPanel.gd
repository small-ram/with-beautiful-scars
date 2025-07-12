extends Panel
signal panel_closed            # will replace intro_finished

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP   # block clicks behind

func _gui_input(ev : InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		emit_signal("panel_closed")
		queue_free()                   # self-destruct
