extends Area2D
signal snapped(photo, slot)

@export var memory_id : String
@onready var sprite   := $Sprite2D
@onready var collider := $CollisionShape2D

var dragging        := false
var drag_offset     := Vector2.ZERO
var original_zindex := 0

func _ready() -> void:
	set_pickable(true)
	if collider.shape is RectangleShape2D:
		collider.shape.size = sprite.texture.get_size() * sprite.scale

# ------------------------------------------------------------------
func _input_event(_vp, ev, _si) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed and sprite.get_rect().has_point(to_local(ev.position)):
			if _is_frontmost_photo_at(ev.global_position):
				dragging        = true
				original_zindex = z_index
				z_index         = 10_000                  # above photos only
				drag_offset     = global_position - ev.position
		elif !ev.pressed and dragging:
			dragging = false
			z_index  = original_zindex                    # restore layer
			_try_snap()

	elif ev is InputEventMouseMotion and dragging:
		global_position = ev.position + drag_offset

func _unhandled_input(ev:InputEvent) -> void:
	if dragging and ev is InputEventMouseMotion:
		global_position = ev.position + drag_offset
# ------------------------------------------------------------------
func _is_frontmost_photo_at(mouse_pos: Vector2) -> bool:
	var front_photo : Area2D = null
	var highest_z   := -1_000_000
	for p in get_tree().get_nodes_in_group("photos"):
		if p.sprite.get_rect().has_point(p.to_local(mouse_pos)):
			if p.z_index > highest_z:
				highest_z = p.z_index
				front_photo = p
	return front_photo == self
# ------------------------------------------------------------------
func _try_snap() -> void:
	for slot in get_tree().get_nodes_in_group("memory_slots"):
		if slot.memory_id == memory_id and overlaps_area(slot):
			global_position = slot.global_position
			set_pickable(false)
			emit_signal("snapped", self, slot)
			return
