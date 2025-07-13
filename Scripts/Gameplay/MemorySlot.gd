extends Area2D
@export var memory_id : String = ""
@onready var sprite := $Sprite2D
@export var slot_idx : int = 0      # 0 = unassigned, give each slot a unique index

func _ready():
	add_to_group("memory_slots")
	collision_layer = 2       # slot layer
	collision_mask  = 0       # doesn’t detect physics, only overlaps
	
func get_circle_texture() -> Texture2D:
	return MemoryPool.table.memory_to_circle_tex.get(memory_id, null)
