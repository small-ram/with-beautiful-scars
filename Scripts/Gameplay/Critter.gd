extends Area2D

@export var base_action  : String = "critter"
@export var one_liner_id : String = ""
@export var wander_speed : float  = 50.0
@export var wander_interval : float = 1.2
@export var lifetime : float = 0.0

@onready var sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var label  : Label             = $KeyLabel
@onready var view   : Rect2             = Rect2(Vector2.ZERO, get_viewport_rect().size)

var _vel           : Vector2 = Vector2.ZERO
var _elapsed_change: float   = 0.0
var _age           : float   = 0.0
var _triggered     : bool    = false
var _action_name   : String

func _ready() -> void:
	_assign_unique_key()
	_pick_new_direction()
	area_entered.connect(_on_area_entered)

func _physics_process(delta:float) -> void:
	if _triggered: return
	_age += delta
	if lifetime > 0 and _age > lifetime:
		queue_free(); return

	_elapsed_change += delta
	if _elapsed_change > wander_interval:
		_pick_new_direction()

	global_position += _vel * delta
	_bounce()

	if Input.is_action_just_pressed(_action_name):
		_trigger()

# ----------------------------------------------------------------
func _assign_unique_key() -> void:
	var keycode : int = KeyAssigner.take_free_key()
	_action_name = "%s_%d" % [base_action, keycode]

	if !InputMap.has_action(_action_name):
		InputMap.add_action(_action_name)
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(_action_name, ev)

	label.text = OS.get_keycode_string(keycode)

func _on_area_entered(a:Area2D) -> void:
	if a.is_in_group("player"):
		_trigger()

func _pick_new_direction() -> void:
	_elapsed_change = 0.0
	_vel = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized() * wander_speed
	sprite.play("idle")

func _bounce() -> void:
	if !view.has_point(global_position):
		_vel = -_vel

func _trigger() -> void:
	_triggered = true
	sprite.play("trigger")
	label.hide()
	if one_liner_id != "":
		DialogueManager.load_tree(one_liner_id)
