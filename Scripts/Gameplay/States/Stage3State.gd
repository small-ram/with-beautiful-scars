# scripts/Gameplay/States/Stage3State.gd
extends StageState

# Shrinks woman and spawns fetus with dialogue.
# Transition: Stage3State -> Stage4State.

const Stage4State = preload('res://Scripts/Gameplay/States/Stage4State.gd')

func enter(controller: Node) -> void:
	var dest := controller._woman_target.global_position if controller._woman_target else Vector2(100,100)
	controller.woman.create_tween().tween_property(controller.woman, 'global_position', dest, 0.8).set_trans(Tween.TRANS_SINE)
	controller.woman.create_tween().tween_property(controller.woman, 'scale', Vector2.ONE * 0.3, 0.8)
	await controller.get_tree().create_timer(0.8).timeout
	controller.fetus = controller.FETUS_SCENE.instantiate()
	controller.get_tree().current_scene.add_child(controller.fetus)
	controller.fetus.global_position = (controller._fetus_spawn.global_position if controller._fetus_spawn else Vector2.ZERO)
	controller.fetus.center_pos = controller._fetus_centre.global_position
	AudioManager.play_sfx(controller.heartbeat_sfx)
	controller.fetus.dialog_done.connect(func():
		transition_to.emit(Stage4State.new())
	)
