extends CanvasLayer

@export_node_path("Marker2D") var origin_path : NodePath          # NEW
@export var icon_spacing      : Vector2 = Vector2(96, 0)

var _icons : Dictionary = {}   # mem_id → Sprite2D
var _origin : Vector2          # resolved on first frame

func _ready() -> void:
	MemoryPool.claimed.connect(_on_memory_claimed)
	call_deferred("_build_icons")

func _build_icons() -> void:
	if MemoryPool.table == null:
		push_error("CircleBank: MemoryPool.table null"); return

	var marker := get_node_or_null(origin_path)
	_origin = marker.global_position if marker else Vector2(64, 960)

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

func _on_memory_claimed(mem_id:String) -> void:
	if _icons.has(mem_id):
		_icons[mem_id].visible = false
		
func show_bank():  visible = true
func hide_bank():  visible = false

func reset_all() -> void:
	for s in _icons.values(): s.visible = true
