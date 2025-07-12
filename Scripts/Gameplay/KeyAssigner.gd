# res://Scripts/Managers/KeyAssigner.gd
extends Node

var _unused_codes : Array[int] = []

func _ready() -> void:
	# Fill the pool with A-Z keycodes
	for k in range(KEY_A, KEY_Z + 1):   # classic range(start, end)
		_unused_codes.append(k)
	_unused_codes.shuffle()

func take_free_key() -> int:
	if _unused_codes.is_empty():
		push_error("KeyAssigner: ran out of keys")
		return KEY_SPACE            # safe fallback
	return _unused_codes.pop_back()
