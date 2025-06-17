extends Area2D
@export var memory_id : String = ""
@onready var sprite := $Sprite2D
@export var slot_idx : int = 0      # 0 = unassigned, give each slot a unique index

func _ready():
	add_to_group("memory_slots")
	collision_layer = 2       # slot layer
	collision_mask  = 0       # doesn’t detect physics, only overlaps

func _hover_on() -> void:
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector2.ONE * 1.1, 0.15)

func _hover_off() -> void:
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector2.ONE, 0.15)
