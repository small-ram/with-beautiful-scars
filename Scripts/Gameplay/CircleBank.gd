extends CanvasLayer

# ───────── inspector ─────────
@export_node_path("Marker2D") var origin_path : NodePath = NodePath("")
@export var icon_spacing : Vector2 = Vector2(200, 0)
@export var max_dist     : float   = 250.0
@export var max_scale    : float   = 1.8
@export var pulse_tint   : Color   = Color(1, 1, 1)

# ───────── internals ─────────
var _icons    : Dictionary = {}     # String (mem_id) -> Sprite2D
var _base_mod : Dictionary = {}     # String (mem_id) -> Color
var _mem2slot : Dictionary = {}     # String (mem_id) -> Node2D (MemorySlot)
var _active_photo : Node = null

func _ready() -> void:
	# hide icon on claim (fast path)
	if MemoryPool and MemoryPool.has_signal("claimed") and not MemoryPool.claimed.is_connected(_on_memory_claimed):
		MemoryPool.claimed.connect(_on_memory_claimed)

	# build after pool exists
	call_deferred("_rebuild")

	# watch photos for hover pulse and snap
	for p in get_tree().get_nodes_in_group("photos"):
		_hook_photo_signals(p)
	get_tree().node_added.connect(_on_node_added)

	set_process(true)

func _rebuild() -> void:
	_cache_slots()
	_build_icons()
	_sync_visibility()

# ───────── data setup ─────────
func _cache_slots() -> void:
	_mem2slot.clear()
	for s: Node in get_tree().get_nodes_in_group("memory_slots"):
		var mid: String = s.get("memory_id") as String
		if mid != null and mid != "":
			_mem2slot[mid] = s

func _resolve_origin() -> Vector2:
	if origin_path != NodePath(""):
		var n: Node2D = get_node_or_null(origin_path) as Node2D
		if n:
			return n.global_position
	var m: Node2D = get_tree().current_scene.find_child("CircleBankOrigin", true, false) as Node2D
	return m.global_position if m else Vector2.ZERO

func _build_icons() -> void:
	# wait for pool
	while MemoryPool == null or MemoryPool.table == null:
		await get_tree().process_frame

	var table := MemoryPool.table
	var tex_map: Dictionary = table.get("memory_to_circle_tex") as Dictionary
	if tex_map == null or tex_map.is_empty():
		push_warning("CircleBank: MemoryTable has no 'memory_to_circle_tex'; icons will not be built.")
		return

	# clear & rebuild
	for c in get_children():
		c.queue_free()
	_icons.clear()
	_base_mod.clear()

	var origin := _resolve_origin()
	var idx := 0
	for mem_id_any in tex_map.keys():
		var mem_id: String = mem_id_any as String
		if mem_id == null or mem_id == "":
			continue
		var tex: Texture2D = tex_map.get(mem_id, null) as Texture2D
		if tex == null:
			continue

		var spr := Sprite2D.new()
		spr.texture  = tex
		spr.position = origin + icon_spacing * idx
		spr.z_index  = 20
		add_child(spr)

		_icons[mem_id]    = spr
		_base_mod[mem_id] = spr.modulate
		idx += 1

# ───────── track dynamic photos ─────────
func _on_node_added(n: Node) -> void:
	if n is Photo:
		_hook_photo_signals(n)

func _hook_photo_signals(p: Photo) -> void:
	if not p.drag_started.is_connected(_on_drag_started):
		p.drag_started.connect(_on_drag_started)
	if not p.drag_ended.is_connected(_on_drag_ended):
		p.drag_ended.connect(_on_drag_ended)
	if not p.snapped.is_connected(_on_photo_snapped):
		p.snapped.connect(_on_photo_snapped)

func _on_drag_started(photo: Node) -> void:
	_active_photo = photo

func _on_drag_ended(_photo: Node) -> void:
	_active_photo = null
	_reset_all_mod()

# Hide immediately when a photo snaps to a slot (best effort; frame sync below is the source of truth)
func _on_photo_snapped(_photo: Photo, slot: Area2D) -> void:
	var map := _slot_map()
	if map.is_empty():
		return
	var mem_id := map.get(slot.get("slot_idx"), "") as String
	if mem_id != null and _icons.has(mem_id):
		var spr := _icons[mem_id] as Sprite2D
		if spr:
			spr.visible = false

# ───────── runtime updates ─────────
func _on_memory_claimed(_mem_id: String) -> void:
	_sync_visibility()  # robust against build order

func _process(_d: float) -> void:
	# keep visibility in sync with pool every frame (6 icons → trivial)
	_sync_visibility()

	# pulsing guidance only while dragging
	if _active_photo == null:
		return
	if MemoryPool == null or MemoryPool.table == null:
		return

	var slots_any: Variant = _active_photo.get("allowed_slots")
	var slots: Array = []
	if slots_any is Array:
		slots = slots_any
	elif slots_any is PackedInt32Array:
		for v in slots_any:
			slots.append(int(v))
	else:
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

# ───────── helpers ─────────
func _sync_visibility() -> void:
	if MemoryPool == null or MemoryPool.table == null:
		return
	for mem_id_any in _icons.keys():
		var mem_id: String = mem_id_any as String
		var spr: Sprite2D = _icons[mem_id] as Sprite2D
		if spr:
			spr.visible = MemoryPool.is_free(mem_id)

func _slot_map() -> Dictionary:
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

func _reset_all_mod() -> void:
	for mem_id_any in _icons.keys():
		var mem_id: String = mem_id_any as String
		if mem_id != null:
			_reset_icon(mem_id, _icons[mem_id] as Sprite2D)

# ───────── API for StageController ─────────
func show_bank() -> void:
	visible = true

func hide_bank() -> void:
	visible = false

func reset_all() -> void:
	for spr: Sprite2D in _icons.values():
		spr.visible = true
	_reset_all_mod()
	_sync_visibility()

func reload() -> void:
	_rebuild()
