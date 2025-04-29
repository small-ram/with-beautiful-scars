# scripts/Gameplay/Photo.gd
extends Area2D
signal snapped(photo, slot)

@export var memory_id   : String
@export var snap_radius : float = 100.0

@onready var sprite     := $Sprite2D

var dragging    : bool    = false
var drag_offset : Vector2 = Vector2.ZERO

func _ready() -> void:
	set_pickable(true)
	set_process_input(true)

func _input_event(_viewport, event, _shape_index) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if sprite.get_rect().has_point(to_local(event.position)):
				dragging    = true
				drag_offset = global_position - event.position
				move_to_front()
		else:
			if dragging:
				dragging = false
				_try_snap()

func _input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseMotion:
		global_position = event.position + drag_offset

func _try_snap() -> void:
	var slot = null
	for s in get_tree().get_nodes_in_group("memory_slots"):
		if s.memory_id == memory_id:
			slot = s
			break
	if slot == null:
		return

	var dist = global_position.distance_to(slot.global_position)
	if dist <= snap_radius:
		global_position = slot.global_position
		set_pickable(false)
		emit_signal("snapped", self, slot)
