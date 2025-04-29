# scripts/UI/IntroPanel.gd
extends Panel
signal intro_finished

var lines := [
	"I was tougher as a kid.",
	"As an adult, I'm always on the verge\nof AN ABYSS.",
	"(Or something equally dramatic to emphasize my mental instability)",
	"My therapist said she believes\nin the “transformational power of internal dialogue”.",
	"...",
	"That's easy.",
	"The abyss has always had your voice.",
	"Hey."
]

@onready var label := $CenterContainer/LineLabel
var idx := 0

func _ready() -> void:
	# Show first line
	label.text = lines[0]
	# Ensure this Panel receives gui_input events
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_advance()

func _advance() -> void:
	idx += 1
	if idx >= lines.size():
		emit_signal("intro_finished")
		queue_free()
	else:
		label.text = lines[idx]
