# Scripts/Gameplay/OutroState.gd  (REPLACE FILE)
extends StageState
class_name OutroState

const OUTRO_PANEL := preload("res://Scenes/Overlays/OutroPanel.tscn")

func enter(controller) -> void:
	controller._clear_overlay()
	var panel: Node = OUTRO_PANEL.instantiate()
	controller.overlay.add_child(panel)
	# Optional: end the app after the outro
	# panel.intro_finished.connect(func(): controller.get_tree().quit())

func exit(_controller) -> void:
	# Let the panel manage its own lifetime; nothing to do here.
	pass
