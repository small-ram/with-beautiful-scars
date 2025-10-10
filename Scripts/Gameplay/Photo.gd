@tool
class_name Photo
extends Area2D

signal snapped(photo: Photo, slot: Area2D)
signal drag_started(photo)
signal drag_ended(photo)
signal dialogue_done(photo)

@export var dialog_id      : String           = ""
@export var memory_id      : String           = ""
@export var snap_radius    : float            = 30.0
@export var allowed_slots  : PackedInt32Array = []

const Z_PHOTO_DEFAULT   := 400
const Z_PHOTO_DRAG_PRE  := 650
const Z_CLEANUP_BASE    := 500
const Z_CLEANUP_DRAG    := 1200

@onready var sprite : Sprite2D = $Sprite2D

var _dragging : bool    = false
var _drag_off : Vector2
var _snapped  : bool    = false
var _in_hand  : bool    = false
var _dialogue_complete : bool = false

static var current_drag    : Photo = null
static var _unused_tapes   : Array[Texture2D] = []

const TAPE_TEXTURES : Array[Texture2D] = [
	preload("res://Assets/Tape/tape1.png"),
	preload("res://Assets/Tape/tape2.png"),
	preload("res://Assets/Tape/tape3.png"),
	preload("res://Assets/Tape/tape4.png"),
	preload("res://Assets/Tape/tape6.png"),
	preload("res://Assets/Tape/tape7.png"),
	preload("res://Assets/Tape/tape8.png")
]

func _ready() -> void:
	set_pickable(true)
	add_to_group("photos")
	z_index = Z_PHOTO_DEFAULT
	_update_cursor_global()

# ─────────────────────────────────────────────────────────────
# Cursor control (shared logic)
# ─────────────────────────────────────────────────────────────
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_update_cursor_global()

func _update_cursor_global() -> void:
	if _any_dragging_global():
		Input.set_default_cursor_shape(Input.CURSOR_MOVE)
		return
	var mouse: Vector2 = get_global_mouse_position()
	var top := _top_ui_target_at_point(mouse)
	if top != null:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

# ─────────────────────────────────────────────────────────────
# Input / drag
# ─────────────────────────────────────────────────────────────
func _input_event(_vp: Viewport, ev: InputEvent, _shape_idx: int) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			if not _is_draggable_now():
				return
			var mouse: Vector2 = ev.position
			if _top_ui_target_at_point(mouse) != self:
				return
			if Photo.current_drag != null:
				return
			Photo.current_drag = self
			_dragging = true
			_in_hand  = true
			_drag_off = global_position - mouse
			move_to_front()
			if _in_cleanup():
				z_index = _claim_top_z()
			else:
				z_index = Z_PHOTO_DRAG_PRE
			emit_signal("drag_started", self)
			_update_cursor_global()
		else:
			if Photo.current_drag != self:
				return
			_dragging = false
			_in_hand  = false
			_try_snap()
			if _in_cleanup():
				z_index = Z_CLEANUP_BASE if not _snapped else Z_PHOTO_DEFAULT
			emit_signal("drag_ended", self)
			Photo.current_drag = null
			_update_cursor_global()

func _input(ev: InputEvent) -> void:
	if _dragging and ev is InputEventMouseMotion:
		global_position = ev.position + _drag_off
		_update_cursor_global()

func is_in_hand() -> bool:
	return _in_hand

func _is_draggable_now() -> bool:
	return is_pickable() and not _snapped

# ─────────────────────────────────────────────────────────────
# Combined top-most resolver (photos + critters)
# ─────────────────────────────────────────────────────────────
func _top_ui_target_at_point(screen_pt: Vector2) -> Node2D:
	var best: Node2D = null
	var best_z: int = -1_000_000
	var best_idx: int = -1

	# Photos (including special ones like Woman/Fetus that implement a custom hook)
	for ph in get_tree().get_nodes_in_group("photos"):
		var n := ph as Node2D
		if n == null:
			continue

		var interactive: bool = false
		var hit: bool = false

		# 1) Custom hook (e.g., WomanPhoto shards, Fetus animated sprite)
		if n.has_method("_is_custom_interactive_at_point"):
			interactive = bool(n.call("_is_custom_interactive_at_point", screen_pt))
			hit = interactive
		else:
			# 2) Default Photo hit test
			var p := n as Photo
			if p != null:
				if p.is_pickable() and not p._snapped:
					var spr := p.get_node_or_null("Sprite2D") as Sprite2D
					if spr and spr.texture:
						var lp: Vector2 = spr.to_local(screen_pt)
						var r: Rect2 = spr.get_rect()
						hit = r.has_point(lp)
						interactive = hit
			else:
				# 3) Generic Sprite2D fallback (pickable)
				if n.has_method("is_pickable") and n.call("is_pickable"):
					var spr2 := n.get_node_or_null("Sprite2D") as Sprite2D
					if spr2 and spr2.texture:
						var lp2: Vector2 = spr2.to_local(screen_pt)
						var r2: Rect2 = spr2.get_rect()
						hit = r2.has_point(lp2)
						interactive = hit

		if not (hit and interactive):
			continue

		var zi: int = n.z_index
		var idx: int = n.get_index()
		if zi > best_z or (zi == best_z and idx > best_idx):
			best = n; best_z = zi; best_idx = idx

	# Critters (unchanged from your current version)
	for c in get_tree().get_nodes_in_group("critters"):
		var cr := c as Area2D
		if cr == null:
			continue
		var spr := cr.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if spr == null or spr.sprite_frames == null:
			continue
		var lp3: Vector2 = spr.to_local(screen_pt)
		var rect3: Rect2 = _animated_sprite_local_rect(spr)
		if not rect3.has_point(lp3):
			continue
		var inter := false
		if cr.has_method("_can_click") and cr.call("_can_click"):
			inter = true
		if cr.has_method("_is_draggable_in_cleanup") and cr.call("_is_draggable_in_cleanup"):
			inter = true
		if not inter:
			continue
		var zi3: int = cr.z_index
		var idx3: int = cr.get_index()
		if zi3 > best_z or (zi3 == best_z and idx3 > best_idx):
			best = cr; best_z = zi3; best_idx = idx3

	return best

func _photo_contains_screen_point(ph: Photo, screen_pt: Vector2) -> bool:
	if ph.sprite == null or ph.sprite.texture == null:
		return false
	var local_pt: Vector2 = ph.sprite.to_local(screen_pt)
	var rect: Rect2 = ph.sprite.get_rect()
	return rect.has_point(local_pt)

func _critter_contains_screen_point(cr: Area2D, screen_pt: Vector2) -> bool:
	var spr := cr.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr == null or spr.sprite_frames == null:
		return false
	var local_pt: Vector2 = spr.to_local(screen_pt)
	var rect: Rect2 = _animated_sprite_local_rect(spr)
	return rect.has_point(local_pt)

func _animated_sprite_local_rect(spr: AnimatedSprite2D) -> Rect2:
	var frames := spr.sprite_frames
	if frames == null:
		return Rect2()
	var anim: String = spr.animation
	if anim == "":
		var names := frames.get_animation_names()
		if names.size() > 0:
			anim = names[0]
	var frame_index: int = spr.frame
	var tex := frames.get_frame_texture(anim, frame_index)
	if tex == null:
		return Rect2()
	var size: Vector2 = tex.get_size()
	var origin: Vector2 = (spr.offset - (size * 0.5)) if spr.centered else spr.offset
	return Rect2(origin, size)

func _any_dragging_global() -> bool:
	for p in get_tree().get_nodes_in_group("photos"):
		var ph := p as Node
		if ph != null and ph.has_method("is_in_hand") and ph.call("is_in_hand"):
			return true
	for c in get_tree().get_nodes_in_group("critters"):
		var cr := c as Node
		if cr != null and cr.has_method("is_in_hand") and cr.call("is_in_hand"):
			return true
	return false

# ─────────────────────────────────────────────────────────────
# Snap / Dialogue (unchanged behavior)
# ─────────────────────────────────────────────────────────────
func _try_snap() -> void:
	var slot : Area2D = _nearest_slot()
	if slot == null: return
	if slot.slot_idx not in allowed_slots: return
	var mem_id : String = MemoryPool.table.slot_to_memory_id[slot.slot_idx]
	if not MemoryPool.is_free(mem_id): return
	var dist : float = global_position.distance_to(slot.global_position)
	if dist > snap_radius: return
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
	_update_cursor_global()

var _my_run_active: bool = false

func _start_dialogue_if_possible() -> void:
	if _dialogue_complete: return
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
				if id == dialog_id: _finish_if_mine(),
			Object.CONNECT_ONE_SHOT
		)

	DialogueManager.start(dialog_id)

func _finish_if_mine() -> void:
	if _dialogue_complete or not _my_run_active: return
	_dialogue_complete = true
	_my_run_active = false
	emit_signal("dialogue_done", self)

# ─────────────────────────────────────────────────────────────
# Helpers / Cleanup
# ─────────────────────────────────────────────────────────────
func _nearest_slot() -> Area2D:
	var best  : Area2D = null
	var best_d: float  = INF
	for s in get_tree().get_nodes_in_group("memory_slots"):
		if s.slot_idx in allowed_slots:
			var d : float = global_position.distance_to(s.global_position)
			if d < best_d:
				best_d = d; best = s
	return best

func unlock_for_cleanup() -> void:
	if not _snapped: return
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
	var tex : Texture2D = _unused_tapes.pop_back()
	if tex == null: return
	var tape : Sprite2D = Sprite2D.new()
	tape.texture = tex
	tape.centered = true
	add_child(tape)
	var half_h : float = sprite.texture.get_height() * sprite.scale.y * 0.5
	tape.position = Vector2(0, -half_h)

func _find_cleanup_layer() -> Node:
	return get_tree().current_scene.find_child("CleanupLayer", true, false)

func _claim_top_z() -> int:
	var cl := _find_cleanup_layer()
	if cl:
		var cur: int = int(cl.get_meta("interaction_z", 500))
		cur += 1
		cl.set_meta("interaction_z", cur)
		return cur
	return 501
