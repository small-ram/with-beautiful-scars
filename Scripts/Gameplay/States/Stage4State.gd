# scripts/Gameplay/States/Stage4State.gd
extends StageState

# Handles cleanup of photos into the river.
# Transition: Stage4State -> EndState.

const EndState = preload('res://Scripts/Gameplay/States/EndState.gd')

func enter(controller: Node) -> void:
	CircleBank.hide_bank()
	for ph in controller.get_tree().get_nodes_in_group('photos'):
		if ph.has_method('unlock_for_cleanup'):
			ph.unlock_for_cleanup()
        var river := controller.RIVER_SCENE.instantiate()
        controller.get_tree().current_scene.add_child(river)
        var river_pos := (
                controller._river_pos.global_position
                if controller._river_pos
                else Vector2(640, 720)
        )
        river.global_position = river_pos
        river.cleanup_complete.connect(func():
                transition_to.emit(EndState.new())
        )
