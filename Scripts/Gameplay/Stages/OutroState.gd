class_name OutroState
extends StageState
signal finished(new_state: StageState)

func enter(_controller) -> void:
	if DialogueManager.is_active():
		await DialogueManager.dialogue_finished
	DialogueManager.start("outro")

func exit(_controller) -> void:
	pass
