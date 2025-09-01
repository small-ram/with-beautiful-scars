# Scripts/Managers/KeyAssigner.gd
extends Node

var _unused_codes : Array[Key] = []
var _custom_queue : Array[Key] = []   # deterministic queue, FIFO

func _ready() -> void:
	for i in range(KEY_A, KEY_Z + 1):
		_unused_codes.append(i as Key)  # type-safe
	_unused_codes.shuffle()

func set_custom_keys(codes: Array[Key]) -> void:
	_custom_queue = codes.duplicate()

func take_free_key() -> Key:
	if not _custom_queue.is_empty():
		return _custom_queue.pop_front()
	if _unused_codes.is_empty():
		push_error("KeyAssigner: ran out of keys")
		return KEY_SPACE as Key
	return _unused_codes.pop_back()
