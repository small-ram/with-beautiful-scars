# scripts/Gameplay/States/IntroState.gd
extends StageState

# Handles parent and difficulty selection.
# Transition: IntroState -> Stage1State.

const Stage1State = preload('res://Scripts/Gameplay/States/Stage1State.gd')

func enter(controller: Node) -> void:
	var parent := controller.PARENT_PANEL.instantiate()
	controller.overlay.add_child(parent)
	parent.parent_chosen.connect(func(is_parent: bool):
		controller.clear_overlay()
		if is_parent:
			var alt := controller.alt_intro_scene.instantiate()
			controller.overlay.add_child(alt)
			alt.intro_finished.connect(func(): controller.get_tree().quit())
		else:
			_show_difficulty(controller)
	)

func _show_difficulty(controller: Node) -> void:
	var d := controller.DIFFICULTY_PANEL.instantiate()
	controller.overlay.add_child(d)
	d.difficulty_chosen.connect(func(easy: bool):
		var cfg := controller.easy_slots_json if easy else controller.hard_slots_json
		controller.apply_slot_cfg(cfg)
		controller.clear_overlay()
		var intro := controller.INTRO_PANEL.instantiate()
		controller.overlay.add_child(intro)
		intro.intro_finished.connect(func():
			transition_to.emit(Stage1State.new())
		)
	)
