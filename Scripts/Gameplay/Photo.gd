@tool
class_name Photo
extends Area2D

# ───────────────────────────
#  Signals
# ───────────────────────────
signal snapped(photo: Photo, slot: Area2D)

# ───────────────────────────
#  Inspector fields
# ───────────────────────────
@export var dialog_id      : String           = ""
@export var memory_id      : String           = ""
@export var snap_radius    : float            = 30.0
@export var allowed_slots  : PackedInt32Array = []
@export var circle_spacing : float            = 200.0    # px gap
@export_node_path("Node2D") var origin_path : NodePath


# ───────────────────────────
#  Internal state
# ───────────────────────────
@onready var sprite : Sprite2D = $Sprite2D

var _dragging         := false
var _drag_off         : Vector2
var _snapped          := false
var _in_hand          := false
var is_sealed         := false
var _circles_spawned  := false
var _circle_container : Node2D = null

static var current_drag : Photo = null         # exclusive-drag lock
const DEBUG := true

# ───────────────────────────
#  Ready
# ───────────────────────────
func _ready() -> void:
	set_pickable(true)
	add_to_group("photos")

# ───────────────────────────
#  Input (drag / drop)
# ───────────────────────────
func _input_event(_vp: Viewport, ev: InputEvent, _shape_idx: int) -> void:
	if _snapped:
		return

	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			# drag only if THIS is the visible top-most photo at the click
			if _top_photo_at_point(ev.position) != self:
				return
			if Photo.current_drag != null:
				return
			Photo.current_drag = self

			if not _circles_spawned:
				_spawn_memory_circles()
				_circles_spawned = true

			_dragging = true
			_in_hand  = true
			_drag_off = global_position - ev.position
			move_to_front()

		else:  # mouse released
			if Photo.current_drag != self:
				return
			_dragging = false
			_in_hand  = false
			_try_snap()
			_clear_circles()
			Photo.current_drag = null

func _input(ev: InputEvent) -> void:
	if _dragging and ev is InputEventMouseMotion:
		global_position = ev.position + _drag_off

func is_in_hand() -> bool: return _in_hand

# ───────────────────────────
#  Find the top-most photo at a screen point
# ───────────────────────────
func _top_photo_at_point(screen_pt: Vector2) -> Photo:
	var best      : Photo = null
	var best_z    : int   = -65536
	var best_idx  : int   = -1

	for ph: Photo in get_tree().get_nodes_in_group("photos"):
		if not ph.is_pickable():
			continue
		if not _sprite_contains_screen_point(ph, screen_pt):
			continue

		var zi  := ph.z_index
		var idx := ph.get_index()
		if zi > best_z or (zi == best_z and idx > best_idx):
			best     = ph
			best_z   = zi
			best_idx = idx
	return best


func _sprite_contains_screen_point(ph: Photo, screen_pt: Vector2) -> bool:
	# Convert screen point into the photo’s local space, then test against
	# the Sprite’s rectangle (faster than a physics query).
	var local_pt := ph.to_local(screen_pt)
	var rect := ph.sprite.get_rect()
	return rect.has_point(local_pt)

# ───────────────────────────
#  Circle preview handling
# ───────────────────────────
func _spawn_memory_circles() -> void:
	if _circle_container:                    # already spawned for this drag
		return

	# 1. decide which Canvas layer receives the circles
	var parent := get_tree().get_first_node_in_group("WorkspaceLayer")
	if parent == null:
		parent = get_tree().root            # safety fallback

	# 2. decide the origin for the first circle
	var origin_node : Node2D = null
	if origin_path != NodePath(""):
		origin_node = get_node_or_null(origin_path)

	var origin : Vector2
	if origin_node:
		origin = origin_node.global_position
	else:
		# fallback-corner if the designer forgot to place CircleOrigin
		origin = Vector2(128, get_viewport_rect().size.y - 128)

	# 3. create a private container so we can delete circles in one call
	_circle_container = Node2D.new()
	_circle_container.name = "CirclesContainer"
	parent.add_child(_circle_container)

	# 4. instance one MemoryCircle per allowed slot
	var circle_scene := preload("res://Scenes/MemoryCircle.tscn")
	var idx := 0
	for slot_idx in allowed_slots:
		var slot := _find_slot_by_idx(slot_idx)
		if slot == null:
			if DEBUG: push_warning("%s: slot %s missing" % [name, slot_idx])
			continue

		var c : Area2D = circle_scene.instantiate()
		c.set("tex", slot.get_circle_texture())   # inject per-slot icon
		_circle_container.add_child(c)
		c.global_position = origin + Vector2(idx * circle_spacing, 0)
		idx += 1

		c.init(slot, self)
		c.connect("seal_done", Callable(self, "_on_seal"))

	if DEBUG:
		print(name, ": spawned", _circle_container.get_child_count(), "circles at", origin)

func _clear_circles() -> void:
	if _circle_container:
		_circle_container.queue_free()
		_circle_container = null
	_circles_spawned = false

# ───────────────────────────
#  Snap logic (unchanged)
# ───────────────────────────
func _try_snap() -> void:
	var slot := _nearest_slot()
	if slot == null:
		if DEBUG: print("⨯ no nearby slot – pos=", global_position)
		return
	if slot.slot_idx not in allowed_slots:
		if DEBUG: print("⨯ slot not allowed idx=", slot.slot_idx, " allowed=", allowed_slots)
		return

	var mem_id : String = MemoryPool.table.slot_to_memory_id[slot.slot_idx]
	if not MemoryPool.is_free(mem_id):
		if DEBUG: print("⨯ memory already used id=", mem_id)
		return

	var dist := global_position.distance_to(slot.global_position)
	if dist > snap_radius:
		if DEBUG: print("⨯ too far dist=", dist, " radius=", snap_radius)
		return

	if DEBUG: print("✓ snap OK slot=", slot.slot_idx, " mem=", mem_id)
	_snap_to_slot(slot, mem_id)

func _snap_to_slot(slot: Area2D, mem_id: String) -> void:
	_clear_circles()
	_snapped = true
	global_position = slot.global_position
	set_pickable(false)

	MemoryPool.claim(mem_id)
	emit_signal("snapped", self, slot)
	AudioManager.play_sfx("photoSnap")

	if dialog_id != "":
		DialogueManager.load_tree(dialog_id)

# ───────────────────────────
#  Helpers
# ───────────────────────────
func _nearest_slot() -> Area2D:
	var best  : Area2D
	var best_d := INF
	for s in get_tree().get_nodes_in_group("memory_slots"):
		if s.slot_idx in allowed_slots:
			var d := global_position.distance_to(s.global_position)
			if d < best_d:
				best_d = d
				best   = s
	return best

func _find_slot_by_idx(idx: int) -> Area2D:
	for s in get_tree().get_nodes_in_group("memory_slots"):
		if s.slot_idx == idx:
			return s
	return null

# ───────────────────────────
#  Cleanup & seal
# ───────────────────────────
func unlock_for_cleanup() -> void:
	if !_snapped:
		return
	_snapped = false
	set_pickable(true)

func _on_seal(_p: Photo) -> void:
	is_sealed = true
	# TODO: add stamp/tween if desired
