extends RefCounted
class_name StageState

signal finished(new_state: StageState)

func enter(_controller) -> void: pass
func exit(_controller) -> void: pass
func on_photo_dialogue_done(_controller, _photo) -> void: pass
func on_critter_dialogue_done(_controller, _critter) -> void: pass
