class_name Stage1State
extends StageState

const CRITTERS : Array[PackedScene] = [
	preload("res://Scenes/Critters/CritterJesterka.tscn"),
	preload("res://Scenes/Critters/CritterBrouk.tscn"),
	preload("res://Scenes/Critters/CritterList.tscn"),
	preload("res://Scenes/Critters/CritterSklenenka.tscn"),
	preload("res://Scenes/Critters/CritterSnek.tscn"),
	preload("res://Scenes/Critters/CritterKliste.tscn")
]

var photo_dialogues_done : int = 0
var photos_total   : int = 0
var critters_done  : int = 0
var _queue : Array[PackedScene] = []

func enter(controller) -> void:
	controller.gameplay.visible = true
	CircleBank.reset_all(); CircleBank.show_bank()
	photo_dialogues_done = 0
	critters_done = 0
	photos_total = 0
	for ph in controller.get_tree().get_nodes_in_group("photos"):
		var pid: String = ph.dialog_id
		if pid != "":
			photos_total += 1
	_queue = CRITTERS.duplicate()
	_queue.shuffle()
	_spawn_next_critter(controller)

func exit(_controller) -> void:
	pass

func _spawn_next_critter(controller) -> void:
	if _queue.is_empty():
		_check_stage1_done(controller)
		return
	var cr: Node = (_queue.pop_back() as PackedScene).instantiate()
	if controller.critter_layer:
		controller.critter_layer.add_child(cr)
	else:
		controller.get_tree().current_scene.add_child(cr)
	cr.dialogue_done.connect(controller._on_critter_dialogue_done.bind(cr))

func on_photo_dialogue_done(controller, _photo) -> void:
	photo_dialogues_done += 1
	_check_stage1_done(controller)

func on_critter_dialogue_done(controller, critter) -> void:
	critters_done += 1
	if is_instance_valid(critter):
		critter.add_to_group("discardable")
	_spawn_next_critter(controller)
	_check_stage1_done(controller)

func _check_stage1_done(_controller) -> void:
	if photo_dialogues_done == photos_total and critters_done == CRITTERS.size():
		finished.emit(Stage2State.new())
