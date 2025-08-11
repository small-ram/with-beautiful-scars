extends RefCounted
class_name StageState

signal finished(new_state: StageState)

func enter(controller) -> void:
    pass

func exit(controller) -> void:
    pass

func on_photo_dialogue_done(controller, photo) -> void:
    pass

func on_critter_dialogue_done(controller, critter) -> void:
    pass
