extends StageState
class_name Stage2State

const WOMAN_SCENE := preload("res://Scenes/WomanPhoto.tscn")

func enter(controller) -> void:
    controller._clear_overlay()
    var mid := controller.mid_stage_panel.instantiate()
    controller.overlay.add_child(mid)
    mid.intro_finished.connect(func(): _spawn_woman(controller))

func exit(controller) -> void:
    controller._clear_overlay()

func _spawn_woman(controller) -> void:
    controller._clear_overlay()
    var stack := controller._fetch_node(controller.stack_path, "PhotoStack")
    controller.woman = WOMAN_SCENE.instantiate()
    stack.add_child(controller.woman)
    controller.woman.global_position = (controller._woman_spawn.global_position if controller._woman_spawn else Vector2(150,150))
    controller.woman.all_words_transformed.connect(func(): finished.emit(Stage3State.new()))
