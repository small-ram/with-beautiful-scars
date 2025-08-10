extends Area2D
signal dialogue_done

@export var base_action  : String = "critter"
@export var one_liner_id : String = ""
@export var move_speed   : float  = 80.0     # px/s
@export var off_margin   : float  = 64.0     # how far past the edge before flip
@export var lane_padding : float  = 80.0     # keep lane away from perpendicular edges
@export var debug_bounds : bool   = false    # draw detected screen rect

@onready var sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var label  : Label            = $KeyLabel
@onready var vp     : Viewport         = get_viewport()

var _view : Rect2
var _dir  : Vector2 = Vector2.ZERO
var _action_name : String
var _triggered   : bool = false
const DEBUG := true

# ───────── READY ─────────
func _ready() -> void:
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
	if _triggered:
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
	sprite.animation_finished.connect(_on_trigger_anim_finished, CONNECT_ONE_SHOT)

	if one_liner_id == "":
		if DEBUG: print("[Critter] (no one_liner_id) – only play trigger anim")
		return

	var dm : Node = get_tree().get_root().get_node_or_null("DialogueManager")
	if dm == null:
		push_warning("[Critter] DialogueManager autoload not found at /root/DialogueManager")
		return
	if not dm.has_method("start"):
		push_warning("[Critter] DialogueManager is missing method 'start(String)'")
		return

	# Connect to know when dialogue ends (one-shot).
	if DEBUG: print("[Critter] → starting one-liner id='", one_liner_id, "'")
	dm.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"), CONNECT_ONE_SHOT)
	dm.call("start", one_liner_id)

func _on_trigger_anim_finished(_anim:String) -> void:
	# If dialogue did not run, allow movement again
	if one_liner_id == "":
		_triggered = false
		sprite.play("move")

func _on_dialogue_finished(last_id: String) -> void:
	# Ignore unrelated dialogues if multiple critters/photos can trigger
	if last_id != one_liner_id:
		return
	if DEBUG: print("[Critter] dialogue finished id='", last_id, "'")
	_triggered = false
	sprite.play("move")
	emit_signal("dialogue_done")
	if InputMap.has_action(_action_name):
		InputMap.erase_action(_action_name)

func _exit_tree() -> void:
	if InputMap.has_action(_action_name):
		InputMap.erase_action(_action_name)

# ───────── DEBUG DRAW ─────────
func _draw() -> void:
	if not debug_bounds: return
	var local_pos : Vector2 = to_local(_view.position)
	var r : Rect2 = Rect2(local_pos, _view.size)
	draw_rect(r, Color(0,1,0,0.15), true)
	draw_rect(r, Color(0,1,0,0.9), false, 2.0)
