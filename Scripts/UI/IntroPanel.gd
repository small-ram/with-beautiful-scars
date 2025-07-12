# scripts/UI/IntroPanel.gd
extends Panel
signal intro_finished

# -------------------------------------------------------------------
# The lines of intro text
# -------------------------------------------------------------------
var lines : Array[String] = [
	"She was a tough child.",
	"Now she always seems to be on the verge of ABYSS.",
	"(Or something equally dramatic to emphasize her mental instability)",
	"Her therapist said she believes\n in the 'transformational power of internal dialogue'.",
	"...",
	"That's easy.",
	"The abyss has always had your voice.",
	"Hey."
]

@onready var _label : Label = $CenterContainer/LineLabel
var _idx : int = 0

func _ready() -> void:
	# show the first line
	_label.text = lines[_idx]
	# block clicks from passing through
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_advance()

func _advance() -> void:
	_idx += 1
	if _idx >= lines.size():
		emit_signal("intro_finished")
		queue_free()
	else:
		_label.text = lines[_idx]
