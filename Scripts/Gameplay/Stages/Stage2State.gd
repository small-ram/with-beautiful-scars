class_name Stage2State
extends StageState

const WOMAN_SCENE := preload("res://Scenes/WomanPhoto.tscn")
const NEXT_STATE  := preload("res://Scripts/Gameplay/Stages/Stage3State.gd") 

func enter(controller) -> void:
	controller._clear_overlay()
	var mid: Node = controller.mid_stage_panel.instantiate()
	controller.overlay.add_child(mid)
	mid.intro_finished.connect(func(): _spawn_woman(controller))

func _spawn_woman(controller) -> void:
	if controller.music_woman != "":
		MusicManager.play(controller.music_woman)
	controller._clear_overlay()

	# Instance & parent ABOVE critters
	var w: Node2D = WOMAN_SCENE.instantiate() as Node2D
	controller.overlay.add_child(w)

	# Typed spawn position (no inference ambiguity)
	var spawn_pos: Vector2
	if controller._woman_spawn:
		spawn_pos = controller._woman_spawn.global_position
	else:
		spawn_pos = Vector2(150, 150)

	# No to_local needed; global coords work across layers
	w.global_position = spawn_pos

	# Keep a handle and wire the transition
	controller.woman = w
	w.all_words_transformed.connect(func(): finished.emit(NEXT_STATE.new()))
