extends Area2D
signal dialogue_done

@export var base_action  : String = "critter"
@export var one_liner_id : String = ""
@export var move_speed   : float  = 80.0     # px/s
@export var off_margin   : float  = 64.0     # how far past the edge before flip
@export var lane_padding : float  = 80.0     # keep lane away from perpendicular edges

@onready var sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var label  : Label            = $KeyLabel
@onready var vp     : Viewport         = get_viewport()

var _view : Rect2
var _dir  : Vector2 = Vector2.ZERO
var _action_name : String
var _triggered   : bool = false
var _my_run_active: bool = false
var _cleanup_mode: bool = false
var _dragging: bool = false
var _drag_off: Vector2 = Vector2.ZERO


# ───────── READY ─────────
func _ready() -> void:
	add_to_group("critters")
	z_index = 10000
	z_as_relative = false
	vp.size_changed.connect(_on_viewport_resized)
	_refresh_view_rect()

	_assign_unique_key()
	_spawn_at_random_edge()
	sprite.play("move")

# ───────── VIEW UTIL ─────────
func _refresh_view_rect() -> void:
	_view = vp.get_visible_rect()
	queue_redraw()

func _on_viewport_resized() -> void:
	_refresh_view_rect()

# ───────── PHYSICS ─────────
func _physics_process(delta: float) -> void:
	if _triggered or _dir == Vector2.ZERO:
		return

	global_position += _dir * move_speed * delta

	# Horizontal runs: flip after leaving real L/R by off_margin
	if _dir.x != 0.0:
		if (_dir.x > 0.0 and global_position.x > _view.position.x + _view.size.x + off_margin) \
		or (_dir.x < 0.0 and global_position.x < _view.position.x - off_margin):
			_dir.x = -_dir.x
			_update_facing()

	# Vertical runs: flip after leaving real T/B by off_margin
	if _dir.y != 0.0:
		if (_dir.y > 0.0 and global_position.y > _view.position.y + _view.size.y + off_margin) \
		or (_dir.y < 0.0 and global_position.y < _view.position.y - off_margin):
			_dir.y = -_dir.y
			_update_facing()

	if Input.is_action_just_pressed(_action_name):
		_trigger()
	if _cleanup_mode:
		return
	if _triggered or _dir == Vector2.ZERO:
		return

# ───────── SPAWN HELPERS ─────────
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
			_dir = Vector2(1, 0)
		1:
			global_position = Vector2(xmax + off_margin, randf_range(ymin + pad_y, ymax - pad_y))
			_dir = Vector2(-1, 0)
		2:
			global_position = Vector2(randf_range(xmin + pad_x, xmax - pad_x), ymin - off_margin)
			_dir = Vector2(0, 1)
		3:
			global_position = Vector2(randf_range(xmin + pad_x, xmax - pad_x), ymax + off_margin)
			_dir = Vector2(0, -1)

	_update_facing()

# ───────── DIRECTION → SPRITE ORIENT ─────────
func _update_facing() -> void:
	# Art faces +Y (up), so rotate dir to that frame
	sprite.rotation = atan2(_dir.y, _dir.x) - PI / 2

# ───────── KEY ASSIGNMENT ─────────
func _assign_unique_key() -> void:
	var keycode : int = KeyAssigner.take_free_key()
	_action_name = "%s_%d" % [base_action, keycode]
	if not InputMap.has_action(_action_name):
		InputMap.add_action(_action_name)
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(_action_name, ev)
	label.text = OS.get_keycode_string(keycode)

# ───────── TRIGGER ─────────
func _trigger() -> void:
	_triggered = true
	sprite.play("trigger")
	label.hide()
	sprite.animation_finished.connect(_on_trigger_anim_finished, Object.CONNECT_ONE_SHOT)

	# Mark runs that start with *this* one_liner_id
	if DialogueManager.has_signal("dialogue_started"):
		DialogueManager.dialogue_started.connect(
			func(id: String) -> void:
				_my_run_active = (id == one_liner_id),
			Object.CONNECT_ONE_SHOT
		)
	else:
		# If your DM lacks 'dialogue_started', assume single-run and mark as ours.
		_my_run_active = true

	# Finish when the run ends (don't rely on last_id matching)
	DialogueManager.dialogue_finished.connect(
		func(_last_id: String) -> void:
			_finish_if_mine(),
		Object.CONNECT_ONE_SHOT
	)

	DialogueManager.start(one_liner_id)

func _on_trigger_anim_finished(_anim: String) -> void:
	# If dialogue did not run, allow movement again
	if one_liner_id == "":
		_triggered = false
		sprite.play("move")

func _finish_if_mine() -> void:
	if not _my_run_active:
		return
	_my_run_active = false

	# Lock the critter and signal completion exactly once
	_dir = Vector2.ZERO
	sprite.play("trigger")
	add_to_group("gold")
	emit_signal("dialogue_done")

# ───────── CLEANUP ─────────
func unlock_for_cleanup() -> void:
	_cleanup_mode = true
	_triggered = true          # disable key-trigger path
	_dir = Vector2.ZERO        # stop motion
	set_pickable(true)         # allow _input_event on Area2D
	label.hide()

	var frames := sprite.sprite_frames
	if frames != null and frames.has_animation("trigger"):
		sprite.play("trigger")
	else:
		# Fallback: just stop on current frame if "trigger" doesn't exist
		sprite.stop()

		
# ───────── DRAG HANDLERS ─────────
func _input_event(_vp: Viewport, ev: InputEvent, _shape_idx: int) -> void:
	if not _cleanup_mode:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_dragging = true
			_drag_off = global_position - ev.position
			move_to_front()
		else:
			_dragging = false

func _input(ev: InputEvent) -> void:
	if _cleanup_mode and _dragging and ev is InputEventMouseMotion:
		global_position = ev.position + _drag_off
