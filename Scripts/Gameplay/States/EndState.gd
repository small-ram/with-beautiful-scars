# scripts/Gameplay/States/EndState.gd
extends StageState

# Loads the outro dialogue.

func enter(_controller: Node) -> void:
	DialogueManager.load_tree('outro')
