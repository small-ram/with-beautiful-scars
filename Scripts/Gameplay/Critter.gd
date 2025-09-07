extends Area2D
signal dialogue_done

@export var base_action  : String = "critter"
@export var one_liner_id : String = ""
@export var move_speed   : float  = 80.0
@export var off_margin   : float  = 64.0
@export var lane_padding : float  = 80.0

@export var wander_strength : float = 0.30
@export var wander_freq     : float = 0.35
@export var turn_rate_deg_s : float = 180.0
@export var speed_wobble    : float = 0.10
@export var edge_pause_min  : float = 0.06
@export var edge_pause_max  : float = 0.20

@onready var sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var key_sprite : Sprite2D         = $Sprite2D
@onready var label  : Label            = $Sprite2D/KeyLabel
@onready var vp     : Viewport         = get_viewport()

var _view : Rect2
var _dir  : Vector2 = Vector2.ZERO
var _axis_dir : Vector2 = Vector2.ZERO
var _perp_dir : Vector2 = Vector2.ZERO
var _consumed: bool = false
var _action_name : String
var _triggered   : bool = false
var _my_run_active: bool = false
var _cleanup_mode: bool = false
var _dragging: bool = false
var _drag_off: Vector2 = Vector2.ZERO

var _noise : FastNoiseLite
var _t : float = 0.0
var _edge_pause_until : float = 0.0

func _ready() -> void:
	add_to_group("critters")
	set_pickable(true)  # ← allow mouse clicks on the Area2D
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)
	vp.size_changed.connect(_on_viewport_resized)
	_refresh_view_rect()

	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.frequency = 1.0

	_assign_unique_key()
	_spawn_at_random_edge()
	sprite.play("move")
	
func _can_click() -> bool:
	if _cleanup_mode: return false
	if _triggered: return false
	if _my_run_active: return false
	if is_instance_valid(DialogueManager) and DialogueManager.is_active():
		return false
	return true

func _on_mouse_enter() -> void:
	var shape: int
	if _cleanup_mode:
		shape = Input.CURSOR_POINTING_HAND
	else:
		shape = Input.CURSOR_POINTING_HAND if _can_click() else Input.CURSOR_ARROW
	Input.set_default_cursor_shape(shape)

func _on_mouse_exit() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


# ───────── VIEW UTIL: required editor rect ─────────
func _editor_bounds() -> Rect2:
	var ref := get_tree().get_first_node_in_group("critter_bounds") as Control
	assert(ref != null, "Critter bounds ReferenceRect (group 'critter_bounds') is required.")
	return ref.get_global_rect()

func _refresh_view_rect() -> void:
	_view = _editor_bounds()
	queue_redraw()

func _on_viewport_resized() -> void:
	_refresh_view_rect()

func _physics_process(delta: float) -> void:
	if _triggered or _axis_dir == Vector2.ZERO:
		return

	_t += delta

	if _edge_pause_until > 0.0:
		if _t < _edge_pause_until:
			_update_facing()
			return
		_edge_pause_until = 0.0

	var n := _noise.get_noise_1d(_t * wander_freq)
	var lateral := _perp_dir * (n * wander_strength)
	var desired := (_axis_dir + lateral).normalized()
	var base_dir := _axis_dir if _dir == Vector2.ZERO else _dir
	var max_turn := deg_to_rad(turn_rate_deg_s) * delta
	_dir = _rotate_toward(base_dir, desired, max_turn)

	var nw := _noise.get_noise_1d((_t + 123.456) * (wander_freq * 0.6))
	var speed := move_speed * (1.0 + nw * speed_wobble)
	global_position += _dir * speed * delta

	if _axis_dir.x != 0.0:
		if ((_axis_dir.x > 0.0 and global_position.x > _view.position.x + _view.size.x + off_margin)
		or  (_axis_dir.x < 0.0 and global_position.x < _view.position.x - off_margin)):
			_flip_lane()
	elif _axis_dir.y != 0.0:
		if ((_axis_dir.y > 0.0 and global_position.y > _view.position.y + _view.size.y + off_margin)
		or  (_axis_dir.y < 0.0 and global_position.y < _view.position.y - off_margin)):
			_flip_lane()

	_update_facing()

	if Input.is_action_just_pressed(_action_name):
		_trigger()

	if _cleanup_mode:
		return

func _spawn_at_random_edge() -> void:
	var xmin: float = _view.position.x
	var xmax: float = _view.position.x + _view.size.x
	var ymin: float = _view.position.y
	var ymax: float = _view.position.y + _view.size.y

	var pad_x: float = clampf(lane_padding, 0.0, maxf(0.0, (_view.size.x * 0.5) - 8.0))
	var pad_y: float = clampf(lane_padding, 0.0, maxf(0.0, (_view.size.y * 0.5) - 8.0))

	match randi() % 4:
		0:
			global_position = Vector2(xmin - off_margin, randf_range(ymin + pad_y, ymax - pad_y))
			_axis_dir = Vector2.RIGHT
		1:
			global_position = Vector2(xmax + off_margin, randf_range(ymin + pad_y, ymax - pad_y))
			_axis_dir = Vector2.LEFT
		2:
			global_position = Vector2(randf_range(xmin + pad_x, xmax - pad_x), ymin - off_margin)
			_axis_dir = Vector2.DOWN
		3:
			global_position = Vector2(randf_range(xmin + pad_x, xmax - pad_x), ymax + off_margin)
			_axis_dir = Vector2.UP

	_perp_dir = Vector2(-_axis_dir.y, _axis_dir.x)
	_dir = _axis_dir
	_update_facing()

func _flip_lane() -> void:
	_axis_dir = -_axis_dir
	_perp_dir = Vector2(-_axis_dir.y, _axis_dir.x)
	_dir = _rotate_toward(_dir, _axis_dir, deg_to_rad(720))
	_edge_pause_until = _t + randf_range(edge_pause_min, edge_pause_max)

func _update_facing() -> void:
	sprite.rotation = atan2(_dir.y, _dir.x) - PI / 2.0

# ---- UNIQUE KEY / INPUT ACTION ----
func _assign_unique_key() -> void:
	var keycode: Key = KeyAssigner.take_free_key()
	_action_name = "%s_%d" % [base_action, int(keycode)]
	if not InputMap.has_action(_action_name):
		InputMap.add_action(_action_name)
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(_action_name, ev)
	label.text = OS.get_keycode_string(keycode)


# ───────── TRIGGER GUARD (no overlapping dialogues) ─────────
func _trigger() -> void:
	if _consumed or _triggered:
		return
	if is_instance_valid(DialogueManager) and DialogueManager.is_active():
		return
	_triggered = true
	sprite.play("trigger")
	key_sprite.hide()
	label.hide()

	# Provide a fallback portrait (first frame of "trigger" or current frame)
	var tex: Texture2D = null
	if sprite.sprite_frames:
		if sprite.sprite_frames.has_animation("trigger"):
			tex = sprite.sprite_frames.get_frame_texture("trigger", 0)
		elif sprite.sprite_frames.has_animation("move"):
			tex = sprite.sprite_frames.get_frame_texture("move", sprite.frame)
	var ui := get_tree().get_first_node_in_group("dialogue_ui")
	if ui and tex and ui.has_method("set_fallback_portrait"):
		ui.call("set_fallback_portrait", tex)

	var dm := get_tree().root.get_node_or_null("DialogueManager")
	if dm:
		if dm.has_signal("dialogue_started") and not dm.dialogue_started.is_connected(_on_dialogue_started):
			dm.dialogue_started.connect(_on_dialogue_started)
		if dm.has_signal("dialogue_finished") and not dm.dialogue_finished.is_connected(_on_dialogue_finished):
			dm.dialogue_finished.connect(_on_dialogue_finished)
		if dm.has_method("start"):
			dm.start(one_liner_id)
			_my_run_active = (one_liner_id != "")
		else:
			_my_run_active = true
	else:
		_my_run_active = false

	await sprite.animation_finished
	_on_trigger_anim_finished()

func _on_trigger_anim_finished() -> void:
	if one_liner_id == "":
		_triggered = false
		sprite.play("move")

func _on_dialogue_started(id: String) -> void:
	_my_run_active = (id == one_liner_id)

func _on_dialogue_finished(_last_id: String) -> void:
	_finish_if_mine()

func _finish_if_mine() -> void:
	if not _my_run_active:
		return
	_my_run_active = false
	_dir = Vector2.ZERO
	sprite.play("trigger")
	add_to_group("gold")
	emit_signal("dialogue_done")

# ---- CLEANUP / DRAG ----
func unlock_for_cleanup() -> void:
	_cleanup_mode = true
	_triggered = true
	_dir = Vector2.ZERO
	set_pickable(true)
	label.hide()
	var frames := sprite.sprite_frames
	if frames != null and frames.has_animation("trigger"):
		sprite.play("trigger")
	else:
		sprite.stop()

func _input_event(_vp: Viewport, ev: InputEvent, _shape_idx: int) -> void:
	# Cleanup mode: drag to the river
	if _cleanup_mode:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_dragging = true
				_drag_off = global_position - ev.position
				move_to_front()
				Input.set_default_cursor_shape(Input.CURSOR_MOVE)
			else:
				_dragging = false
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		return

	# Normal mode: left-click triggers the critter (same as hotkey)
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		_trigger()

func _input(ev: InputEvent) -> void:
	if _cleanup_mode and _dragging and ev is InputEventMouseMotion:
		global_position = ev.position + _drag_off

# ---- UTIL ----
func _rotate_toward(current: Vector2, target: Vector2, max_step: float) -> Vector2:
	var c := current.normalized()
	var t := target.normalized()
	if c == Vector2.ZERO:
		return t
	var ang := c.angle_to(t)
	if abs(ang) <= max_step:
		return t
	return c.rotated(sign(ang) * max_step).normalized()
	
# Critter.gd — add anywhere in the script
func is_in_hand() -> bool:
	# dragging only exists during cleanup mode
	return _cleanup_mode and _dragging

func force_drop() -> void:
	_dragging = false
