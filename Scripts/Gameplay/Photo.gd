@tool
class_name Photo
extends Area2D

# ───────────────────────────
#  Signals
# ───────────────────────────
signal snapped(photo: Photo, slot: Area2D)
signal drag_started(photo)
signal drag_ended(photo)

# ───────────────────────────
#  Inspector fields
# ───────────────────────────
@export var dialog_id      : String           = ""
@export var memory_id      : String           = ""
@export var snap_radius    : float            = 30.0
@export var allowed_slots  : PackedInt32Array = []

# ───────────────────────────
#  Internal state
# ───────────────────────────
@onready var sprite : Sprite2D = $Sprite2D

var _dragging : bool    = false
var _drag_off : Vector2
var _snapped  : bool    = false
var _in_hand  : bool    = false
var is_sealed : bool    = false

static var current_drag    : Photo = null                # exclusive-drag lock
static var _unused_tapes   : Array[Texture2D] = []       # shared between all photos

const DEBUG := true

# tape pool  (add the exact filenames you have in Assets/Tape/)
const TAPE_TEXTURES : Array[Texture2D] = [
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
	add_to_group("photos")

# ───────────────────────────
#  Input (drag / drop)
# ───────────────────────────
func _input_event(_vp: Viewport, ev: InputEvent, _shape_idx: int) -> void:
	if _snapped:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			if _top_photo_at_point(ev.position) != self: return
			if Photo.current_drag != null: return
			Photo.current_drag = self
			_dragging = true
			_in_hand  = true
			_drag_off = global_position - ev.position
			move_to_front()
			emit_signal("drag_started", self)
		else:
			if Photo.current_drag != self:
				return
			_dragging = false
			_in_hand  = false
			_try_snap()
			emit_signal("drag_ended", self)
			Photo.current_drag = null

func _input(ev: InputEvent) -> void:
	if _dragging and ev is InputEventMouseMotion:
		global_position = ev.position + _drag_off

func is_in_hand() -> bool:
	return _in_hand

# ───────────────────────────
#  Find the top-most photo at a screen point
# ───────────────────────────
func _top_photo_at_point(screen_pt: Vector2) -> Photo:
	var best     : Photo = null
	var best_z   : int   = -65536
	var best_idx : int   = -1

	for ph: Photo in get_tree().get_nodes_in_group("photos"):
		if not ph.is_pickable(): continue
		if not _sprite_contains_screen_point(ph, screen_pt): continue

		var zi  : int = ph.z_index
		var idx : int = ph.get_index()
		if zi > best_z or (zi == best_z and idx > best_idx):
			best     = ph
			best_z   = zi
			best_idx = idx
	return best

func _sprite_contains_screen_point(ph: Photo, screen_pt: Vector2) -> bool:
	var local_pt : Vector2 = ph.to_local(screen_pt)
	var rect     : Rect2   = ph.sprite.get_rect()
	return rect.has_point(local_pt)

# ───────────────────────────
#  Snap logic
# ───────────────────────────
func _try_snap() -> void:
	var slot : Area2D = _nearest_slot()
	if slot == null:
		if DEBUG: print("[Photo] ⨯ no nearby slot – pos=", global_position)
		return
	if slot.slot_idx not in allowed_slots:
		if DEBUG: print("[Photo] ⨯ slot not allowed idx=", slot.slot_idx, " allowed=", allowed_slots)
		return

	var mem_id : String = MemoryPool.table.slot_to_memory_id[slot.slot_idx]
	if not MemoryPool.is_free(mem_id):
		if DEBUG: print("[Photo] ⨯ memory already used id=", mem_id)
		return

	var dist : float = global_position.distance_to(slot.global_position)
	if dist > snap_radius:
		if DEBUG: print("[Photo] ⨯ too far dist=", dist, " radius=", snap_radius)
		return

	if DEBUG: print("[Photo] ✓ snap OK slot=", slot.slot_idx, " mem=", mem_id)
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

# ───────────────────────────
#  Dialogue trigger (+ debug)
# ───────────────────────────
func _start_dialogue_if_possible() -> void:
	if dialog_id == "":
		if DEBUG: print("[Photo] (no dialog_id set) – skip")
		return
	if Engine.is_editor_hint():
		if DEBUG: print("[Photo] editor hint – skip dialogue")
		return

	var dm : Node = get_tree().get_root().get_node_or_null("DialogueManager")
	if dm == null:
		push_warning("[Photo] DialogueManager autoload not found at /root/DialogueManager")
		return
	if not dm.has_method("start"):
		push_warning("[Photo] DialogueManager is missing method 'start(String)'")
		return

	if DEBUG: print("[Photo] → starting dialogue id='", dialog_id, "'")
	dm.call("start", dialog_id)

# ───────────────────────────
#  Helpers
# ───────────────────────────
func _nearest_slot() -> Area2D:
	var best  : Area2D = null
	var best_d: float  = INF
	for s in get_tree().get_nodes_in_group("memory_slots"):
		if s.slot_idx in allowed_slots:
			var d : float = global_position.distance_to(s.global_position)
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
	if not _snapped:
		return
	_snapped = false
	set_pickable(true)

func _attach_random_tape() -> void:
	if _unused_tapes.is_empty():
		_unused_tapes = TAPE_TEXTURES.duplicate()
		_unused_tapes.shuffle()

	var tex : Texture2D = _unused_tapes.pop_back()
	if tex == null: return

	var tape : Sprite2D = Sprite2D.new()
	tape.texture = tex
	tape.centered = true
	add_child(tape)

	var half_h : float = sprite.texture.get_height() * sprite.scale.y * 0.5
	tape.position = Vector2(0, -half_h)

func _on_seal(_p: Photo) -> void:
	is_sealed = true
	_attach_random_tape()
