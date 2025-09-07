extends Area2D
class_name HorsePad

signal arrangement_complete

@export var affects_groups: PackedStringArray = ["photos", "critters"]
@export var snap_point_path: NodePath = NodePath("TopAnchor")
@export var body_sprite_path: NodePath = NodePath("Sprite2D")
@export var active: bool = false
@export var scatter_radius: float = 16.0
@export var max_rotation_deg: float = 45.0
@export var gold_tint: Color = Color(1.0, 0.85, 0.30)

var _inside: Array[Area2D] = []
var _snap_point: Marker2D
var _sprite: Sprite2D
var _normal_mod: Color = Color(1,1,1,1)
var _eligible_total: int = -1
var _done_count: int = 0
var _processed_ids: Dictionary = {}

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_snap_point = get_node_or_null(snap_point_path) as Marker2D
	_sprite = get_node_or_null(body_sprite_path) as Sprite2D
	if _sprite:
		_normal_mod = _sprite.modulate
	set_physics_process(true)
	set_process(true)

func set_active(v: bool) -> void:
	active = v
	if active:
		_prepare_eligibility()
	else:
		# Make sure we’re visually normal outside cleanup
		if _sprite:
			_sprite.modulate = _normal_mod

func _on_area_entered(a: Area2D) -> void:
	if not active:
		return
	if _is_target(a):
		_inside.append(a)

func _on_area_exited(a: Area2D) -> void:
	if not active:
		return
	_inside.erase(a)

func _process(_dt: float) -> void:
	# Only glow during cleanup
	if _sprite:
		_sprite.modulate = (gold_tint if (active and _any_dragging()) else _normal_mod)

func _physics_process(_dt: float) -> void:
	if not active:
		return
	for a in _inside.duplicate():
		if not is_instance_valid(a):
			_inside.erase(a)
			continue
		if not _is_target(a):
			continue

		var dragging := false
		if a.has_method("is_in_hand"):
			dragging = bool(a.call("is_in_hand"))
		if dragging:
			continue

		if a.has_method("force_drop"):
			a.call("force_drop")

		_snap_onto_horse(a)
		_inside.erase(a)

	if _eligible_total >= 0 and _done_count >= _eligible_total:
		_eligible_total = -1
		arrangement_complete.emit()

func _is_target(n: Node) -> bool:
	for g in affects_groups:
		if n.is_in_group(g):
			return true
	return false

func _any_dragging() -> bool:
	for p in get_tree().get_nodes_in_group("photos"):
		if p.has_method("is_in_hand") and bool(p.call("is_in_hand")):
			return true
	for c in get_tree().get_nodes_in_group("critters"):
		if c.has_method("is_in_hand") and bool(c.call("is_in_hand")):
			return true
	return false

func _is_memory_photo(a: Area2D) -> bool:
	if not a.is_in_group("photos"):
		return false
	var mid: String = a.get("memory_id") as String
	return mid != null and mid != ""

func _prepare_eligibility() -> void:
	_done_count = 0
	_processed_ids.clear()
	var uniq := {}
	for g in affects_groups:
		for n in get_tree().get_nodes_in_group(g):
			if n is Area2D:
				uniq[(n as Node).get_instance_id()] = true
	_eligible_total = uniq.size()

func _snap_onto_horse(a: Area2D) -> void:
	var iid: int = a.get_instance_id()
	if _processed_ids.has(iid):
		return

	# Gild memory photos only
	if _is_memory_photo(a):
		var spr := a.get_node_or_null("Sprite2D") as Sprite2D
		if spr:
			spr.modulate = gold_tint
		if a.has_method("set"):
			a.set("allowed_slots", PackedInt32Array())
		a.add_to_group("gold")

	# Top-center anchor + light scatter + random tilt
	var base := _snap_point.global_position if _snap_point != null else global_position
	var offset := Vector2(randf_range(-scatter_radius, scatter_radius), randf_range(-scatter_radius, scatter_radius))
	var target := base + offset
	var rot_deg := randf_range(-max_rotation_deg, max_rotation_deg)

	var n2d := a as Node2D
	if n2d:
		n2d.global_position = target
		n2d.rotation_degrees = rot_deg

	if a.has_method("set_pickable"):
		a.set_pickable(false)

	_processed_ids[iid] = true
	_done_count += 1
