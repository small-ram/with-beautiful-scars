# Stage3State.gd
extends StageState
class_name Stage3State

const FETUS_SCENE := preload("res://Scenes/FetusPhoto.tscn")

func enter(controller) -> void:
	# Woman moves/shrinks to her target as before
	var dest: Vector2 = controller._woman_target.global_position if controller._woman_target else Vector2(100, 100)
	controller.woman.create_tween().tween_property(controller.woman, "global_position", dest, 0.8).set_trans(Tween.TRANS_SINE)
	controller.woman.create_tween().tween_property(controller.woman, "scale", Vector2.ONE * 0.22, 0.5)

	await controller.get_tree().create_timer(0.8).timeout

	# Spawn the fetus and leave it in place (no center_pos, no movement)
	controller.fetus = FETUS_SCENE.instantiate()
	controller.get_tree().current_scene.add_child(controller.fetus)

	# Place at spawn marker if present
	if controller._fetus_spawn:
		var pos: Vector2 = controller._fetus_spawn.global_position
		var f2d := controller.fetus as Node2D
		if f2d != null:
			f2d.global_position = pos

	# Optional heartbeat SFX (FetusPhoto also has its own AudioStream option)
	if controller.heartbeat_sfx != "":
		AudioManager.play_sfx(controller.heartbeat_sfx)

	# When the fetus panel is closed, proceed to Stage 4
	controller.fetus.dialogue_done.connect(
		func(): finished.emit(Stage4State.new()),
		Object.CONNECT_ONE_SHOT
	)

func exit(_controller) -> void:
	pass
