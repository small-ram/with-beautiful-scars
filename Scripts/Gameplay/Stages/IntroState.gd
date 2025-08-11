extends StageState
class_name IntroState

const PARENT_PANEL     := preload("res://Scenes/Overlays/ParentChoicePanel.tscn")
const DIFFICULTY_PANEL := preload("res://Scenes/Overlays/DifficultyChoicePanel.tscn")
const INTRO_PANEL      := preload("res://Scenes/Overlays/IntroPanel.tscn")

func enter(controller) -> void:
    var parent: Node = PARENT_PANEL.instantiate()
    controller.overlay.add_child(parent)
    parent.parent_chosen.connect(_on_parent_decided.bind(controller))

func exit(controller) -> void:
    controller._clear_overlay()

func _on_parent_decided(is_parent: bool, controller) -> void:
    controller._clear_overlay()
    if is_parent:
        var alt: Node = controller.alt_intro_scene.instantiate()
        controller.overlay.add_child(alt)
        alt.intro_finished.connect(func(): controller.get_tree().quit())
    else:
        _show_difficulty(controller)

func _show_difficulty(controller) -> void:
    var d: Node = DIFFICULTY_PANEL.instantiate()
    controller.overlay.add_child(d)
    d.difficulty_chosen.connect(_on_diff_selected.bind(controller))

func _on_diff_selected(easy: bool, controller) -> void:
    _apply_slot_cfg(controller, controller.easy_slots_json if easy else controller.hard_slots_json)
    controller._clear_overlay()
    var intro: Node = INTRO_PANEL.instantiate()
    controller.overlay.add_child(intro)
    intro.intro_finished.connect(func(): finished.emit(Stage1State.new()))

func _apply_slot_cfg(controller, path: String) -> void:
    if path.is_empty() or not FileAccess.file_exists(path):
        return
    var j := JSON.new()
    if j.parse(FileAccess.get_file_as_string(path)) != OK:
        return
    for n in j.data:
        var ph: Photo = controller.get_tree().current_scene.find_child(n, true, false) as Photo
        if ph:
            ph.allowed_slots = PackedInt32Array(j.data[n])
