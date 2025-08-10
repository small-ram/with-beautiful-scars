# scripts/Gameplay/States/Stage1State.gd
extends StageState

# Manages photo snaps and critter dialogues.
# Transition: Stage1State -> Stage2State.

const Stage2State = preload('res://Scripts/Gameplay/States/Stage2State.gd')
const CRITTERS : Array[PackedScene] = [
	preload('res://Scenes/Critters/CritterJesterka.tscn'),
	preload('res://Scenes/Critters/CritterBrouk.tscn'),
	preload('res://Scenes/Critters/CritterList.tscn'),
	preload('res://Scenes/Critters/CritterSklenenka.tscn'),
	preload('res://Scenes/Critters/CritterSnek.tscn'),
	preload('res://Scenes/Critters/CritterKliste.tscn')
]

var snaps_done : int = 0
var photos_total : int = 0
var critters_done : int = 0
var _queue : Array[PackedScene] = []
var _current_critter : Node = null

func enter(controller: Node) -> void:
	controller.gameplay.visible = true
	CircleBank.reset_all(); CircleBank.show_bank()
	snaps_done = 0; critters_done = 0; photos_total = 0
	for ph in controller.get_tree().get_nodes_in_group('photos'):
		photos_total += 1
		ph.snapped.connect(_on_photo_snapped)
	_queue = CRITTERS.duplicate(); _queue.shuffle()
	_spawn_next_critter(controller)

func _on_photo_snapped(_p, _slot) -> void:
	snaps_done += 1
	_check_done()

func _spawn_next_critter(controller: Node) -> void:
	if _current_critter:
		_current_critter.queue_free()
	if _queue.is_empty():
		_current_critter = null
		_check_done()
		return
	_current_critter = _queue.pop_back().instantiate()
	controller.get_tree().current_scene.add_child(_current_critter)
	_current_critter.dialogue_done.connect(func():
		critters_done += 1
		_spawn_next_critter(controller)
		_check_done()
	)

func _check_done() -> void:
	if snaps_done == photos_total and critters_done == 6 and _current_critter == null:
		transition_to.emit(Stage2State.new())
