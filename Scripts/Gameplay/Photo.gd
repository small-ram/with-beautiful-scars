# scripts/Gameplay/Photo.gd
extends Area2D
signal snapped(photo, slot)

@export var memory_id: String
@export var snap_radius: float = 100.0  # tweak in Inspector

@onready var sprite: Sprite2D = $Sprite2D

var dragging := false
var drag_offset := Vector2.ZERO

func _ready() -> void:
	set_pickable(true)
	print("photo ready:", name, "mem_id=", memory_id)

func _input_event(_viewport, event, _shape_index) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# always start drag when clicking *anywhere* on the sprite
			if sprite.get_rect().has_point(to_local(event.position)):
				dragging = true
				drag_offset = global_position - event.position
				move_to_front()
				# consume so UI doesn’t steal it
				get_viewport().set_input_as_handled()
		else:
			# on release, stop drag and try snapping
			if dragging:
				dragging = false
				_try_snap()
	elif event is InputEventMouseMotion and dragging:
		# follow cursor without interruption
		global_position = event.position + drag_offset

func _unhandled_input(event: InputEvent) -> void:
	# catch fast mouse motion when cursor leaves sprite
	if dragging and event is InputEventMouseMotion:
		global_position = event.position + drag_offset

func _try_snap() -> void:
	# find *only* your matching slot
	var slot = null
	for s in get_tree().get_nodes_in_group("memory_slots"):
		if s.memory_id == memory_id:
			slot = s
			break
	if slot == null:
		print("⚠ no slot found for", memory_id); return

	var dist = global_position.distance_to(slot.global_position)
	print("snap dist to", slot.name, "=", dist, "radius=", snap_radius)
	if dist <= snap_radius:
		global_position = slot.global_position
		set_pickable(false)
		emit_signal("snapped", self, slot)
	else:
		print("→ too far to snap")
