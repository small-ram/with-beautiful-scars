extends CanvasLayer
signal bank_ready

# ───────── inspector knobs ─────────
@export_node_path("Marker2D") var origin_path : NodePath = NodePath("")
@export var icon_spacing : Vector2 = Vector2(200, 0)
@export var max_dist     : float   = 250.0
@export var max_scale    : float   = 1.8
@export var pulse_tint   : Color   = Color(1, 1, 1)

# ───────── internals ─────────
var _icons    : Dictionary         = {}     # mem_id → Sprite2D
var _base_mod : Dictionary         = {}     # mem_id → Color
var _mem2slot : Dictionary         = {}     # mem_id → MemorySlot
var _active_photo : Node = null

# ───────── life-cycle ─────────
func _ready() -> void:
	MemoryPool.claimed.connect(_on_memory_claimed)
	call_deferred("_late_init")

	for p in get_tree().get_nodes_in_group("photos"):
		p.drag_started.connect(_on_drag_started)
		p.drag_ended  .connect(_on_drag_ended)

	set_process(true)

func _late_init() -> void:
	_cache_slots()
	_build_icons()
	emit_signal("bank_ready")

# ───────── data setup ─────────
func _cache_slots() -> void:
	for s : Node in get_tree().get_nodes_in_group("memory_slots"):
		_mem2slot[s.memory_id] = s

func _resolve_origin() -> Vector2:
	if origin_path != NodePath(""):
		var n := get_node_or_null(origin_path)
		if n: return n.global_position
	var m := get_tree().current_scene.find_child("CircleBankOrigin", true, false)
	return m.global_position if m else Vector2.ZERO

func _build_icons() -> void:
	var table := MemoryPool.table
	if table == null:
		push_error("CircleBank: table null"); return

	var origin : Vector2 = _resolve_origin()
	var idx   : int = 0
	for mem_id : String in table.memory_to_circle_tex:
		var spr : Sprite2D = Sprite2D.new()
		spr.texture  = table.memory_to_circle_tex[mem_id]
		spr.position = origin + icon_spacing * idx
		spr.z_index  = 20
		add_child(spr)
		_icons[mem_id]   = spr
		_base_mod[mem_id]= spr.modulate
		idx += 1

# ───────── runtime updates ─────────
func _on_drag_started(photo:Node) -> void:
	_active_photo = photo

func _on_drag_ended(_photo:Node) -> void:
	_active_photo = null
	_reset_all()

func _on_memory_claimed(mem_id:String) -> void:
	if _icons.has(mem_id):
		_icons[mem_id].visible = false

func _process(_d:float) -> void:
	if _active_photo == null: return

	var allowed : Array[String] = _mems_for_photo(_active_photo)
	for mem_id : String in _icons:
		var spr : Sprite2D = _icons[mem_id]
		if mem_id in allowed:
			_apply_pulse(spr, mem_id)
		else:
			_reset_icon(mem_id, spr)

# ───────── helpers ─────────
func _mems_for_photo(p:Node) -> Array[String]:
	var out : Array[String] = []
	for idx : int in p.allowed_slots:
		var id : String = MemoryPool.table.slot_to_memory_id.get(idx, "")
		if id != "": out.append(id)
	return out

func _apply_pulse(spr:Sprite2D, mem_id:String) -> void:
	var slot : Node2D = _mem2slot.get(mem_id)
	if slot == null: return

	var dist : float = _active_photo.global_position.distance_to(slot.global_position)
	var t    : float = clamp(1.0 - dist / max_dist, 0.0, 1.0)

	spr.scale    = Vector2.ONE * lerp(1.0, max_scale, t)
	spr.modulate = _base_mod[mem_id].lerp(pulse_tint, t)

func _reset_icon(mem_id:String, spr:Sprite2D) -> void:
	spr.scale    = Vector2.ONE
	spr.modulate = _base_mod[mem_id]

func _reset_all() -> void:
	for mem_id : String in _icons:
		_reset_icon(mem_id, _icons[mem_id])

# ───────── API for StageController ─────────
func show_bank():  visible = true
func hide_bank():  visible = false
func reset_all() -> void:
	for spr : Sprite2D in _icons.values():
		spr.visible = true
	_reset_all()
