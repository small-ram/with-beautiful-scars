extends Area2D
@export var memory_id : String = ""
@export var slot_idx : int = 0      # 0 = unassigned, give each slot a unique index
	
func get_circle_texture() -> Texture2D:
	return MemoryPool.table.memory_to_circle_tex.get(memory_id, null)
