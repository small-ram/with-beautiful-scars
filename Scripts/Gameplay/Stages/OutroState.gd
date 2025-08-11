extends StageState
class_name OutroState

func enter(controller) -> void:
	if DialogueManager.is_active():
		await DialogueManager.dialogue_finished
	DialogueManager.start("outro")

func exit(controller) -> void:
	pass
