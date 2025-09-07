class_name Stage4State
extends StageState

const RIVER_SCENE := preload("res://Scenes/Kun.tscn")
const NEXT_STATE  := preload("res://Scripts/Gameplay/Stages/OutroState.gd") 

func enter(controller) -> void:
	CircleBank.hide_bank()
	for ph in controller.get_tree().get_nodes_in_group("photos"):
		if ph.has_method("unlock_for_cleanup"): ph.unlock_for_cleanup()
	for cr in controller.get_tree().get_nodes_in_group("critters"):
		if cr.has_method("unlock_for_cleanup"): cr.unlock_for_cleanup()
	var river := RIVER_SCENE.instantiate()
	controller.get_tree().current_scene.add_child(river)
	river.global_position = (controller._river_pos.global_position if controller._river_pos else Vector2(640, 720))
	river.cleanup_complete.connect(func(): finished.emit(NEXT_STATE.new()))

func exit(_controller) -> void:
	pass
