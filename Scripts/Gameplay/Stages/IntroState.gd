# Scripts/Gameplay/Stages/IntroState.gd
class_name IntroState
extends StageState

const INTRO_PANEL := preload("res://Scenes/Overlays/IntroPanel.tscn")

func enter(controller) -> void:
	_apply_slot_cfg(controller, controller.easy_slots_json)

	var skip: bool = controller.get_tree().has_meta("skip_intro") \
		and bool(controller.get_tree().get_meta("skip_intro"))

	if skip:
		controller.get_tree().set_meta("skip_intro", false)
		# ⬇️ Defer the state change to the next idle tick (avoid re-entrancy)
		controller.call_deferred("change_state", Stage1State.new())
		return

	if controller.music_intro != "":
		MusicManager.play(controller.music_intro)
	controller._clear_overlay()
	var intro := INTRO_PANEL.instantiate()
	controller.overlay.add_child(intro)
	intro.intro_finished.connect(func(): finished.emit(Stage1State.new()))

func exit(controller) -> void:
	controller._clear_overlay()

func _apply_slot_cfg(controller, path: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path): return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK: return
	for n in j.data:
		var ph: Photo = controller.get_tree().current_scene.find_child(n, true, false)
		if ph:
			ph.allowed_slots = PackedInt32Array(j.data[n])
