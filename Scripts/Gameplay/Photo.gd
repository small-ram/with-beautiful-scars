@tool
class_name Photo
extends Area2D

# ───────────────────────────
#  Signals
# ───────────────────────────
signal snapped(photo: Photo, slot: Area2D)
signal drag_started(photo)
signal drag_ended(photo)
signal dialogue_done(photo)

# ───────────────────────────
#  Inspector fields
# ───────────────────────────
@export var dialog_id      : String           = ""
@export var memory_id      : String           = ""
@export var snap_radius    : float            = 30.0
@export var allowed_slots  : PackedInt32Array = []

# ───────── Z-LAYERS ─────────
const Z_PHOTO_DEFAULT   := 400
const Z_PHOTO_DRAG_PRE  := 650   # pre-cleanup drag stays below moving critters (700)
const Z_CLEANUP_BASE    := 500   # everyone equal at start of cleanup
const Z_CLEANUP_DRAG    := 1200  # dragged item always on very top during cleanup

# ───────────────────────────
#  Nodes / State
# ───────────────────────────
@onready var sprite: Sprite2D = $Sprite2D

var _dragging: bool = false
var _drag_off: Vector2
var _snapped: bool = false
var _in_hand: bool = false
var _dialogue_complete: bool = false

static var current_drag: Photo = null
static var _unused_tapes: Array[Texture2D] = []

# Tape pool (add the exact filenames you have in Assets/Tape/)
const TAPE_TEXTURES: Array[Texture2D] = [
	preload("res://Assets/Tape/tape1.png"),
	preload("res://Assets/Tape/tape2.png"),
	preload("res://Assets/Tape/tape3.png"),
	preload("res://Assets/Tape/tape4.png"),
	preload("res://Assets/Tape/tape6.png"),
	preload("res://Assets/Tape/tape7.png"),
	preload("res://Assets/Tape/tape8.png")
]

# ───────────────────────────
#  Ready
# ───────────────────────────
func _ready() -> void:
	set_pickable(true)
	add_to_group("photos")   # needed for top-most resolution
	z_index = Z_PHOTO_DEFAULT
	_update_cursor_global()

# ───────────────────────────
#  Cursor rules (global, top-most aware)
#   • top-most over draggable -> POINTING_HAND
#   • while dragging          -> MOVE
#   • otherwise               -> ARROW
# ───────────────────────────
func _is_draggable_now() -> bool:
	return is_pickable() and not _snapped

func _update_cursor_global() -> void:
	# 1) Dragging always wins.
	if Photo.current_drag != null and Photo.current_drag._dragging:
		Input.set_default_cursor_shape(Input.CURSOR_MOVE)
		return

	# 2) Find the top-most photo under the mouse (by z_index, then scene order).
	var mouse := get_global_mouse_position()
	var top := _top_photo_at_point(mouse)

	# 3) Decide cursor for the whole scene.
	if top != null and top._is_draggable_now():
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

# ───────────────────────────
#  Input handlers
# ───────────────────────────
func _input_event(_vp: Viewport, ev: InputEvent, _shape_idx: int) -> void:
	# Note: _input_event is only delivered when the mouse is actually over this Area2D
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			# Start drag only if THIS is the top-most photo under the cursor and draggable.
			if not _is_draggable_now():
				return
			if _top_photo_at_point(ev.position) != self:
				return
			if Photo.current_drag != null:
				return

			Photo.current_drag = self
			_dragging = true
			_in_hand  = true
			_drag_off = global_position - ev.position
			move_to_front()
			if _in_cleanup():
				z_index = _claim_top_z()
			else:
				z_index = Z_PHOTO_DRAG_PRE

			emit_signal("drag_started", self)
			_update_cursor_global()  # MOVE
		else:
			# Mouse released (only called if pointer is still over us)
			if Photo.current_drag != self:
				return
			_dragging = false
			_in_hand  = false
			_try_snap()
			if _in_cleanup():
				if not _snapped:
					z_index = Z_CLEANUP_BASE
				else:
					z_index = Z_PHOTO_DEFAULT

			emit_signal("drag_ended", self)
			Photo.current_drag = null
			_update_cursor_global()  # hand if still over top-most & draggable, else arrow

func _input(ev: InputEvent) -> void:
	# Update cursor on any mouse move (top-most aware), and move while dragging.
	if ev is InputEventMouseMotion:
		if _dragging:
			global_position = ev.position + _drag_off
			# While dragging, MOVE always applies (enforced by _update_cursor_global too).
		_update_cursor_global()

func is_in_hand() -> bool:
	return _in_hand

# ───────────────────────────
#  Top-most resolution & hit test
#  (no Transform2D.xform; use Sprite2D local rect with to_local)
# ───────────────────────────
func _top_photo_at_point(screen_pt: Vector2) -> Photo:
	var best: Photo = null
	var best_z: int = -1_000_000
	var best_idx: int = -1

	for ph: Photo in get_tree().get_nodes_in_group("photos"):
		# Only consider photos whose sprite bounds contain the point.
		if not _sprite_contains_screen_point(ph, screen_pt):
			continue

		var zi := ph.z_index
		var idx := ph.get_index()
		if zi > best_z or (zi == best_z and idx > best_idx):
			best = ph
			best_z = zi
			best_idx = idx

	return best

func _sprite_contains_screen_point(ph: Photo, screen_pt: Vector2) -> bool:
	if ph.sprite == null or ph.sprite.texture == null:
		return false
	# Convert the global mouse point into the Sprite2D's local space.
	var local_pt: Vector2 = ph.sprite.to_local(screen_pt)
	# Compare against the sprite's local rect (handles scale/rotation/offset via to_local).
	var rect: Rect2 = ph.sprite.get_rect()
	return rect.has_point(local_pt)

# ───────────────────────────
#  Snap logic
# ───────────────────────────
func _try_snap() -> void:
	if _snapped:
		return
	var slot: Area2D = _nearest_slot()
	if slot == null:
		return
	if slot.slot_idx not in allowed_slots:
		return

	var mem_id: String = MemoryPool.table.slot_to_memory_id[slot.slot_idx]
	if not MemoryPool.is_free(mem_id):
		return

	var dist: float = global_position.distance_to(slot.global_position)
	if dist > snap_radius:
		return

	_snap_to_slot(slot, mem_id)

func _snap_to_slot(slot: Area2D, mem_id: String) -> void:
	_snapped = true
	global_position = slot.global_position
	set_pickable(false)

	MemoryPool.claim(mem_id)
	_attach_random_tape()
	emit_signal("snapped", self, slot)
	AudioManager.play_sfx("photoSnap")

	_start_dialogue_if_possible()
	_update_cursor_global()  # now not draggable -> arrow on hover

# ───────────────────────────
#  Dialogue trigger (unchanged)
# ───────────────────────────
var _my_run_active: bool = false

func _start_dialogue_if_possible() -> void:
	if _dialogue_complete:
		return
	if dialog_id.is_empty():
		_dialogue_complete = true
		return
	if Engine.is_editor_hint():
		return
	if not DialogueManager.has_method("start"):
		_dialogue_complete = true
		emit_signal("dialogue_done", self)
		return
	else:
		_my_run_active = true

	DialogueManager.dialogue_finished.connect(
		func(_last_id: String) -> void:
			_finish_if_mine(),
		Object.CONNECT_ONE_SHOT
	)

	if DialogueManager.has_signal("dialogue_closed"):
		DialogueManager.dialogue_closed.connect(
			func(id: String) -> void:
				if id == dialog_id:
					_finish_if_mine(),
			Object.CONNECT_ONE_SHOT
		)

	DialogueManager.start(dialog_id)

func _finish_if_mine() -> void:
	if _dialogue_complete or not _my_run_active:
		return
	_dialogue_complete = true
	_my_run_active = false
	emit_signal("dialogue_done", self)

# ───────────────────────────
#  Helpers
# ───────────────────────────
func _nearest_slot() -> Area2D:
	var best: Area2D = null
	var best_d: float = INF
	for s in get_tree().get_nodes_in_group("memory_slots"):
		if s.slot_idx in allowed_slots:
			var d: float = global_position.distance_to(s.global_position)
			if d < best_d:
				best_d = d
				best = s
	return best

# ───────────────────────────
#  Cleanup
# ───────────────────────────
func unlock_for_cleanup() -> void:
	if not _snapped:
		return
	_snapped = false
	set_pickable(true)
	_update_cursor_global()

func _in_cleanup() -> bool:
	var p: Node = get_parent()
	while p:
		if p.name == "CleanupLayer":
			return true
		p = p.get_parent()
	return false

func _attach_random_tape() -> void:
	if _unused_tapes.is_empty():
		_unused_tapes = TAPE_TEXTURES.duplicate()
		_unused_tapes.shuffle()

	var tex: Texture2D = _unused_tapes.pop_back()
	if tex == null:
		return

	var tape := Sprite2D.new()
	tape.texture = tex
	tape.centered = true
	add_child(tape)

	var half_h: float = sprite.texture.get_height() * sprite.scale.y * 0.5
	tape.position = Vector2(0, -half_h)

func _find_cleanup_layer() -> Node:
	return get_tree().current_scene.find_child("CleanupLayer", true, false)

func _claim_top_z() -> int:
	var cl := _find_cleanup_layer()
	if cl:
		var cur := int(cl.get_meta("interaction_z", 500))
		cur += 1
		cl.set_meta("interaction_z", cur)
		return cur
	return 501
