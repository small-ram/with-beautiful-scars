extends CanvasLayer

# Where your editor-placed circle sprites live
@export_node_path("Node") var icons_container_path: NodePath

# Pulse visuals (kept from before)
@export var max_dist  : float = 250.0
@export var max_scale : float = 1.8
@export var pulse_tint: Color = Color(1, 1, 1)

var _icons    : Dictionary = {}   # mem_id -> Sprite2D
var _base_mod : Dictionary = {}   # mem_id -> Color
var _mem2slot : Dictionary = {}   # mem_id -> MemorySlot (Node2D)
var _active_photo : Node = null
var _container : Node = null

func _ready() -> void:
	MemoryPool.claimed.connect(_on_memory_claimed)
	call_deferred("_late_init")

	# Track photos (for pulsing while dragging)
	for p in get_tree().get_nodes_in_group("photos"):
		_hook_photo_signals(p)
	get_tree().node_added.connect(_on_node_added)

	set_process(true)

func _late_init() -> void:
	_cache_slots()
	_collect_icons()

# ---------- data setup ----------
func _cache_slots() -> void:
	_mem2slot.clear()
	for s: Node in get_tree().get_nodes_in_group("memory_slots"):
		var mid: String = s.get("memory_id") as String
		if mid != null and mid != "":
			_mem2slot[mid] = s

func _collect_icons() -> void:
	_icons.clear()
	_base_mod.clear()
	_container = null

	if icons_container_path != NodePath(""):
		_container = get_node_or_null(icons_container_path)
	if _container == null:
		_container = get_tree().current_scene.find_child("boruvci", true, false)
	if _container == null:
		push_warning("CircleBank: no icons container found (set 'icons_container_path' or add a 'CircleIcons' node).")
		return

	# Optional auto-assign textures if missing, using MemoryTable
	var tex_map: Dictionary = {}
	if MemoryPool != null and MemoryPool.table != null:
		tex_map = MemoryPool.table.memory_to_circle_tex as Dictionary

	for c in _container.get_children():
		var spr: Sprite2D = c as Sprite2D
		if spr == null:
			continue

		# Prefer exported property 'memory_id' (via CircleIcon.gd), else metadata
		var mem_id: String = ""
		var v: Variant = spr.get("memory_id")  # will be null if not present
		if v is String:
			mem_id = v
		elif spr.has_meta("memory_id"):
			mem_id = str(spr.get_meta("memory_id"))

		if mem_id == "":
			continue

		# Auto texture if user forgot to assign and table has one
		if spr.texture == null and tex_map.has(mem_id):
			var tex := tex_map[mem_id] as Texture2D
			if tex != null:
				spr.texture = tex

		_icons[mem_id] = spr
		_base_mod[mem_id] = spr.modulate

# ---------- track dynamic photos ----------
func _on_node_added(n: Node) -> void:
	if n is Photo:
		_hook_photo_signals(n)

func _hook_photo_signals(p: Photo) -> void:
	if not p.drag_started.is_connected(_on_drag_started):
		p.drag_started.connect(_on_drag_started)
	if not p.drag_ended.is_connected(_on_drag_ended):
		p.drag_ended.connect(_on_drag_ended)

# ---------- runtime updates ----------
func _on_drag_started(photo: Node) -> void:
	_active_photo = photo

func _on_drag_ended(_photo: Node) -> void:
	_active_photo = null
	_reset_all()

func _on_memory_claimed(mem_id: String) -> void:
	if _icons.has(mem_id):
		var spr: Sprite2D = _icons[mem_id] as Sprite2D
		if spr:
			spr.visible = false

func _process(_d: float) -> void:
	if _active_photo == null:
		return
	if MemoryPool == null or MemoryPool.table == null:
		return

	# read allowed slots from the active photo
	if not _active_photo.has_method("get"):
		return
	var slots: Array = _active_photo.get("allowed_slots") as Array
	if slots == null:
		return

	var allowed: Array[String] = _mems_for_photo(slots)
	for mem_id_any in _icons.keys():
		var mem_id: String = mem_id_any as String
		if mem_id == null:
			continue
		var spr: Sprite2D = _icons[mem_id] as Sprite2D
		if spr == null:
			continue
		if mem_id in allowed:
			_apply_pulse(spr, mem_id)
		else:
			_reset_icon(mem_id, spr)

# ---------- helpers ----------
func _slot_map() -> Dictionary:
	if MemoryPool == null:
		return {}
	var t: MemoryTable = MemoryPool.table
	if t == null:
		return {}
	var m: Dictionary = t.get("slot_to_memory_id") as Dictionary
	return m if m != null else {}

func _mems_for_photo(slots: Array) -> Array[String]:
	var out: Array[String] = []
	var map: Dictionary = _slot_map()
	if map.is_empty():
		return out
	for idx_any in slots:
		if typeof(idx_any) == TYPE_INT:
			var idx: int = idx_any
			var id: String = map.get(idx, "") as String
			if id != null and id != "":
				out.append(id)
	return out

func _apply_pulse(spr: Sprite2D, mem_id: String) -> void:
	var slot: Node2D = _mem2slot.get(mem_id) as Node2D
	if slot == null or not is_instance_valid(slot):
		return
	var dist: float = _active_photo.global_position.distance_to(slot.global_position)
	var t: float = clamp(1.0 - dist / max_dist, 0.0, 1.0)

	spr.scale    = Vector2.ONE * lerp(1.0, max_scale, t)
	spr.modulate = (_base_mod[mem_id] as Color).lerp(pulse_tint, t)

func _reset_icon(mem_id: String, spr: Sprite2D) -> void:
	spr.scale    = Vector2.ONE
	spr.modulate = _base_mod[mem_id] as Color

func _reset_all() -> void:
	for mem_id_any in _icons.keys():
		var mem_id: String = mem_id_any as String
		if mem_id != null:
			_reset_icon(mem_id, _icons[mem_id] as Sprite2D)

# ---------- API used by StageController ----------
func show_bank() -> void:
	if _container: _container.visible = true
	else: visible = true

func hide_bank() -> void:
	if _container: _container.visible = false
	else: visible = false

func reset_all() -> void:
	for spr: Sprite2D in _icons.values():
		if spr:
			spr.visible = true
	_reset_all()

func reload() -> void:
	_cache_slots()
	_collect_icons()
