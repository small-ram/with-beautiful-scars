# scripts/Gameplay/States/Stage2State.gd
extends StageState

# Shows mid-stage panel then spawns woman.
# Transition: Stage2State -> Stage3State.

const Stage3State = preload('res://Scripts/Gameplay/States/Stage3State.gd')

func enter(controller: Node) -> void:
	controller.clear_overlay()
	var mid := controller.mid_stage_panel.instantiate()
	controller.overlay.add_child(mid)
	mid.intro_finished.connect(func():
		controller.clear_overlay()
		var stack := controller.fetch_node(controller.stack_path, 'PhotoStack')
		controller.woman = controller.WOMAN_SCENE.instantiate()
		stack.add_child(controller.woman)
		controller.woman.global_position = (controller._woman_spawn.global_position if controller._woman_spawn else Vector2(150,150))
		controller.woman.all_words_transformed.connect(func():
			transition_to.emit(Stage3State.new())
		)
	)
