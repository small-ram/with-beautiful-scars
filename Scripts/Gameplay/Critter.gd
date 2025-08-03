extends Area2D
signal dialogue_done              # fires after this critter’s panel closes
@export var base_action  : String = "critter"
@export var one_liner_id : String = ""
@export var move_speed   : float  = 80.0

@onready var sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var label  : Label             = $KeyLabel
@onready var view   : Rect2             = Rect2(Vector2.ZERO, get_viewport_rect().size)

var _dir         : Vector2    # unit vector across the screen
var _action_name : String
var _triggered   : bool = false

# ───────── ready ─────────
func _ready() -> void:
	_assign_unique_key()
	_pick_entry_and_direction()
	sprite.play("move")

func _physics_process(delta:float) -> void:
	if _triggered: return
	global_position += _dir * move_speed * delta

	# off opposite edge? flip direction
	if not view.grow(64).has_point(global_position):   # 64px margin
		_dir = -_dir
		sprite.flip_h = !_dir.x > 0

	if Input.is_action_just_pressed(_action_name):
		_trigger()

# ───────── directional spawn ─────────
func _pick_entry_and_direction() -> void:
	var side := randi() % 4          # 0=L,1=R,2=T,3=B
	match side:
		0:
			global_position = Vector2(-64, randf_range(view.position.y, view.end.y))
			_dir = Vector2(1, 0)
		1:
			global_position = Vector2(view.end.x + 64, randf_range(view.position.y, view.end.y))
			_dir = Vector2(-1, 0)
		2:
			global_position = Vector2(randf_range(view.position.x, view.end.x), -64)
			_dir = Vector2(0, 1)
		3:
			global_position = Vector2(randf_range(view.position.x, view.end.x), view.end.y + 64)
			_dir = Vector2(0, -1)
	sprite.flip_h = _dir.x < 0

# ───────── key assignment ─────────
func _assign_unique_key() -> void:
	var keycode : int = KeyAssigner.take_free_key()
	_action_name = "%s_%d" % [base_action, keycode]

	if !InputMap.has_action(_action_name):
		InputMap.add_action(_action_name)
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(_action_name, ev)

	label.text = OS.get_keycode_string(keycode)

# ───────── trigger logic ─────────
func _trigger() -> void:
	_triggered = true
	sprite.play("trigger")
	label.hide()
	sprite.animation_finished.connect(
		func(anim): sprite.play("move"), CONNECT_ONE_SHOT)

	if one_liner_id != "":
		DialogueManager.load_tree(one_liner_id)
		DialogueManager.dialogue_closed.connect(_on_dialogue_closed, CONNECT_ONE_SHOT)

func _on_dialogue_closed(_id:String) -> void:
	dialogue_done.emit()
