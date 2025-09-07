# Scripts/Managers/KeyAssigner.gd (autoload)
extends Node

var _unused_codes: Array[int] = []

# Keep this an Array[int] so it matches _unused_codes
const FIXED: Array[int] = [KEY_M, KEY_O, KEY_T, KEY_H, KEY_E, KEY_R]

func _ready() -> void:
	reset()  # harmless on first boot

func reset() -> void:
	_unused_codes = FIXED.duplicate()  # Array[int] -> Array[int]

func take_free_key() -> int:
	if _unused_codes.is_empty():
		push_error("KeyAssigner: ran out of keys")
		return KEY_SPACE
	var code: int = _unused_codes[0]
	_unused_codes.remove_at(0)  # keep order M→O→T→H→E→R
	return code
