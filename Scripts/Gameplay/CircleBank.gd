# Scripts/Managers/CircleBank.gd  (AutoLoad)
extends CanvasLayer

@export var icon_spacing : Vector2 = Vector2(96, 0)

var _icons : Dictionary = {}         # mem_id → Sprite2D

func _ready() -> void:
	MemoryPool.claimed.connect(_on_memory_claimed)
	call_deferred("_build_icons")    # wait one frame; MemoryPool.table will be set

func _build_icons() -> void:
	if MemoryPool.table == null:
		push_error("CircleBank: MemoryPool.table still null!"); return

	var idx := 0
	for mem_id in MemoryPool.table.memory_to_circle_tex:
		var s := Sprite2D.new()
		s.texture = MemoryPool.table.memory_to_circle_tex[mem_id]
		s.position = Vector2(64, 960) + icon_spacing * idx   # bottom-left row
		s.z_index  = 20
		add_child(s)
		_icons[mem_id] = s
		idx += 1
	emit_signal("ready")

func _on_memory_claimed(mem_id:String) -> void:
	if _icons.has(mem_id):
		_icons[mem_id].visible = false

func reset_all() -> void:           # called on restart
	for s in _icons.values(): s.visible = true
