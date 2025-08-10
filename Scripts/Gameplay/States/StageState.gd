# scripts/Gameplay/States/StageState.gd
extends Node
class_name StageState

signal transition_to(next_state)

func enter(_controller: Node) -> void:
	pass
