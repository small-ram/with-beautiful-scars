extends Resource
class_name MemoryTable
@export var photo_to_slots : Dictionary = {}
@export var slot_to_memory_id : Dictionary = {}
@export var memory_to_circle_tex : Dictionary = {
	"mem_crib":       preload("res://Assets/Circles/circle_crib.png"),
	"mem_hehory":     preload("res://Assets/Circles/circle_horse.png"),
	"mem_distance":   preload("res://Assets/Circles/circle_distance.png"),
	"mem_repair":     preload("res://Assets/Circles/circle_repair.jpg"),
	"mem_concept":    preload("res://Assets/Circles/circle_concept.png"),
	"mem_closure":    preload("res://Assets/Circles/circle_closure.jpg")
}
