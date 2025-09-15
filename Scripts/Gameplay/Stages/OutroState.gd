extends StageState
class_name OutroState

const OUTRO_PANEL := preload("res://Scenes/Overlays/OutroPanel.tscn")

func enter(controller) -> void:
	controller._clear_overlay()
	var panel := OUTRO_PANEL.instantiate()
	controller.overlay.add_child(panel)

	panel.intro_finished.connect(func ():
		# Stop SFX only
		if is_instance_valid(AudioManager):
			AudioManager.stop_all()

		# (Keep music playing)
		if is_instance_valid(DialogueManager):
			DialogueManager.clear_cache()
			if DialogueManager.is_active():
				DialogueManager.close()

		controller.get_tree().change_scene_to_file("res://Scenes/Overlays/StartMenu.tscn")
	, Object.CONNECT_ONE_SHOT)

func exit(_controller) -> void:
	pass
