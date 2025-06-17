# scripts/Gameplay/Photo.gd
@tool
extends Area2D
signal snapped(photo, slot)

# --------------------------------------------------------------------#
#  EXPORTED DATA
# --------------------------------------------------------------------#
@export var dialog_id     : String = ""
@export var memory_id     : String = ""          # legacy
@export var snap_radius   : float  = 100.0
@export var allowed_slots : PackedInt32Array = [] # slot indices valid for this photo

# --------------------------------------------------------------------#
#  INTERNAL STATE
# --------------------------------------------------------------------#
@onready var sprite : Sprite2D = $Sprite2D

var _dragging        : bool = false
var _drag_off        : Vector2
var _snapped         : bool = false
var _in_hand         : bool = false
var is_sealed        : bool = false
var _circle_container : Node2D = null   # reference to my own container
var _circles_spawned : bool = false              # guards double-spawn

const DEBUG := true                              # console chatter

# --------------------------------------------------------------------#
#  READY
# --------------------------------------------------------------------#
func _ready() -> void:
	set_pickable(true)
	add_to_group("photos")

# --------------------------------------------------------------------#
#  INPUT (drag / drop)
# --------------------------------------------------------------------#
func _input_event(_vp:Viewport, ev:InputEvent, _shape_idx:int) -> void:
	if _snapped:
		return

	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			if not _circles_spawned:
				_spawn_memory_circles()
				_circles_spawned = true
			_dragging = true
			_in_hand  = true
			_drag_off = global_position - ev.position
			move_to_front()
		else:
			if _dragging:
				_dragging = false
				_in_hand  = false
				_try_snap()
			_clear_circles()   # ← always clear, even if snap failed

func _input(ev:InputEvent) -> void:
	if _dragging and ev is InputEventMouseMotion:
		global_position = ev.position + _drag_off

func is_in_hand() -> bool:
	return _in_hand

# ---------------------------------------------------------------
#  SPAWN CIRCLES  – called the first time you press the mouse
# ---------------------------------------------------------------
func _spawn_memory_circles() -> void:
	if _circle_container:                      # already exists
		return

	var parent := get_tree().get_first_node_in_group("WorkspaceLayer")
	if parent == null:
		parent = get_tree().root              # safety fallback

	_circle_container = Node2D.new()
	_circle_container.name = "CirclesContainer"
	parent.add_child(_circle_container)

	var circle_scene := preload("res://Scenes/MemoryCircle.tscn")
	var viewport_size := get_viewport_rect().size
	var origin := Vector2(128, viewport_size.y - 128)   # bottom-left start

	var i := 0             # horizontal index for spacing
	for slot_idx in allowed_slots:
		var slot := _find_slot_by_idx(slot_idx)
		if slot == null:
			if DEBUG: push_warning("%s: slot %s missing" % [name, slot_idx])
			continue

		var c := circle_scene.instantiate()
		_circle_container.add_child(c)
		c.global_position = origin + Vector2(i * 200, 0)
		i += 1

		c.init(slot, self)                               # pass slot + photo
		c.connect("seal_done", Callable(self, "_on_seal"))

	if DEBUG:
		print(name, ": spawned", _circle_container.get_child_count(), "circles")

# ---------------------------------------------------------------
#  CLEAR CIRCLES  – called on every mouse-up and inside _snap_to_slot()
# ---------------------------------------------------------------
func _clear_circles() -> void:
	if _circle_container:
		_circle_container.queue_free()
		_circle_container = null
	_circles_spawned = false


# --------------------------------------------------------------------#
#  SNAP LOGIC
# --------------------------------------------------------------------#
func _try_snap() -> void:
	var slot := _nearest_slot()
	if slot == null:
		if DEBUG: print("⨯ no nearby slot  –  pos=", global_position)
		return

	if slot.slot_idx not in allowed_slots:
		if DEBUG: print("⨯ slot not allowed  idx=", slot.slot_idx, " allowed=", allowed_slots)
		return

	var mem_id : String = MemoryPool.table.slot_to_memory_id[slot.slot_idx]
	if not MemoryPool.is_free(mem_id):
		if DEBUG: print("⨯ memory already used  id=", mem_id)
		return

	var dist := global_position.distance_to(slot.global_position)
	if dist > snap_radius:
		if DEBUG: print("⨯ too far  dist=", dist, "  radius=", snap_radius)
		return

	if DEBUG: print("✓ snap OK  slot=", slot.slot_idx, "  mem=", mem_id)
	_snap_to_slot(slot, mem_id)

func _snap_to_slot(slot:Area2D, mem_id:String) -> void:
	_snapped        = true
	global_position = slot.global_position
	set_pickable(false)

	MemoryPool.claim(mem_id)
	emit_signal("snapped", self, slot)

	if dialog_id != "":
		DialogueManager.load_tree(dialog_id)

# --------------------------------------------------------------------#
#  HELPERS
# --------------------------------------------------------------------#
func _nearest_slot() -> Area2D:
	var best : Area2D
	var best_d := 1e20

	for s in get_tree().get_nodes_in_group("memory_slots"):
		if s.slot_idx in allowed_slots:
			var d := global_position.distance_to(s.global_position)
			if d < best_d:
				best_d = d
				best   = s
	return best

func _find_slot_by_idx(idx:int) -> Area2D:
	for s in get_tree().get_nodes_in_group("memory_slots"):
		if s.slot_idx == idx:
			return s
	return null

# --------------------------------------------------------------------#
#  CLEANUP & SEAL
# --------------------------------------------------------------------#
func unlock_for_cleanup() -> void:
	if !_snapped:
		return
	_snapped = false
	set_pickable(true)

func _on_seal(_p) -> void:
	is_sealed = true
	# TODO: play a stamp tween / animation here
