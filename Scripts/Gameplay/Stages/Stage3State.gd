extends StageState
class_name Stage3State

const FETUS_SCENE := preload("res://Scenes/FetusPhoto.tscn")

func enter(controller) -> void:
    var dest := controller._woman_target.global_position if controller._woman_target else Vector2(100,100)
    controller.woman.create_tween().tween_property(controller.woman, "global_position", dest, 0.8).set_trans(Tween.TRANS_SINE)
    controller.woman.create_tween().tween_property(controller.woman, "scale", Vector2.ONE * 0.3, 0.8)

    await controller.get_tree().create_timer(0.8).timeout
    controller.fetus = FETUS_SCENE.instantiate()
    controller.get_tree().current_scene.add_child(controller.fetus)
    controller.fetus.global_position = (controller._fetus_spawn.global_position if controller._fetus_spawn else Vector2.ZERO)
    controller.fetus.center_pos      = controller._fetus_centre.global_position
    AudioManager.play_sfx(controller.heartbeat_sfx)
    controller.fetus.dialogue_done.connect(func(): finished.emit(Stage4State.new()))

func exit(controller) -> void:
    pass
