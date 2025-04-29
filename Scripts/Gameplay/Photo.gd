# scripts/Gameplay/Photo.gd
extends Area2D
# warning-ignore:unused_signal
signal snapped(photo, slot)

@export var memory_id: String = ""

@onready var sprite   : Sprite2D         = $Sprite2D
@onready var collider : CollisionShape2D = $CollisionShape2D

var dragging     : bool        = false
var drag_offset  : Vector2     = Vector2.ZERO

func _ready() -> void:
	# Make sure we get _input_event calls
	set_pickable(true)
	# Size the collider exactly to the sprite
	if collider.shape is RectangleShape2D:
		var size = sprite.texture.get_size() * sprite.scale
		collider.shape.size = size

func _input_event(_viewport, event, _shape_idx) -> void:
	# Mouse button press/release
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start drag if click was inside the sprite's rect
			var loc = to_local(event.global_position)
			if sprite.get_rect().has_point(loc):
				dragging = true
				# offset keeps your grab point constant
				drag_offset = global_position - event.global_position
		elif dragging:
			# On release: stop dragging and snap
			dragging = false
			_try_snap()

func _process(_delta: float) -> void:
	if dragging:
		global_position = get_global_mouse_position() + drag_offset

func _try_snap() -> void:
	for slot in get_tree().get_nodes_in_group("memory_slots"):
		if slot.memory_id == memory_id and overlaps_area(slot):
			global_position = slot.global_position
			set_pickable(false)
			emit_signal("snapped", self, slot)
			return
