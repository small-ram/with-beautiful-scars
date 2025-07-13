# Scripts/Managers/CircleBank.gd  (AutoLoad)
extends CanvasLayer

@export_node_path("Marker2D") var origin_path : NodePath = NodePath("")  # optional
@export var icon_spacing : Vector2 = Vector2(96, 0)

var _icons : Dictionary = {}
var _origin : Vector2 = Vector2.ZERO

func _ready() -> void:
	MemoryPool.claimed.connect(_on_memory_claimed)
	call_deferred("_build_icons")     # wait until MemoryPool.table exists

func _build_icons() -> void:
	if MemoryPool.table == null:
		push_error("CircleBank: MemoryPool.table null"); return

	# 1) find origin
	if origin_path != NodePath(""):
		var n := get_node_or_null(origin_path)
		_origin = n.global_position if n else Vector2.ZERO
	else:
		var marker := get_tree().current_scene.find_child("CircleBankOrigin", true, false)
		_origin = marker.global_position if marker else Vector2.ZERO

	# 2) create icons
	var idx := 0
	for mem_id in MemoryPool.table.memory_to_circle_tex:
		var s := Sprite2D.new()
		s.texture = MemoryPool.table.memory_to_circle_tex[mem_id]
		s.position = _origin + icon_spacing * idx
		s.z_index  = 20
		add_child(s)
		_icons[mem_id] = s
		idx += 1

	emit_signal("ready")

# ─── runtime updates ───────────────────────────────
func _on_memory_claimed(mem_id:String) -> void:
	if _icons.has(mem_id):
		_icons[mem_id].visible = false

func show_bank():  visible = true
func hide_bank():  visible = false

func reset_all() -> void:
	for s in _icons.values(): s.visible = true
