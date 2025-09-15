extends Node

var _unused_codes: Array[Key] = []

const FIXED: Array[Key] = [
	Key.KEY_M, Key.KEY_O, Key.KEY_T, Key.KEY_H, Key.KEY_E, Key.KEY_R
]

func _ready() -> void:
	reset()

func reset() -> void:
	_unused_codes = FIXED.duplicate()

func take_free_key() -> Key:
	if _unused_codes.is_empty():
		push_error("KeyAssigner: ran out of keys")
		return Key.KEY_SPACE
	var code: Key = _unused_codes[0]
	_unused_codes.remove_at(0)
	return code
