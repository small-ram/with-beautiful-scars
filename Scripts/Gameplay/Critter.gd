extends Area2D
@export var action_name     : String = ""         # InputMap action
@export var one_liner_id    : String = ""                  # dialogue JSON id
@export var wander_speed    : float  = 50.0
@export var wander_interval : float  = 1.2                 # sec between dir changes
@export var lifetime        : float  = 0                   # 0 = never despawn

@onready var sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var label  : Label             = $KeyLabel
@onready var view   : Rect2             = Rect2(Vector2.ZERO, get_viewport_rect().size)

var _vel                : Vector2 = Vector2.ZERO
var _elapsed_dir_change : float  = 0.0
var _age                : float  = 0.0
var _triggered          : bool   = false

func _ready() -> void:
	# create/run-time action if missing
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E          # default E
		InputMap.action_add_event(action_name, ev)
		label.text = OS.get_keycode_string(ev.physical_keycode)   # "E"
	else:
		label.text = "?"
	_pick_new_direction()
	connect("area_entered", Callable(self, "_on_area_entered"))         # for clicks

func _physics_process(delta: float) -> void:
	if _triggered:
		return
	_elapsed_dir_change += delta
	_age += delta
	if lifetime > 0 and _age > lifetime:
		queue_free()
		return

	if _elapsed_dir_change > wander_interval:
		_pick_new_direction()

	global_position += _vel * delta
	_bounce()

	if Input.is_action_just_pressed(action_name):
		_trigger()

func _on_area_entered(a: Area2D) -> void:
	if a.is_in_group("player"):                      # optional: click/touch
		_trigger()

# ---------- helpers ----------
func _pick_new_direction() -> void:
	_elapsed_dir_change = 0.0
	_vel = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized() * wander_speed
	sprite.play("idle")

func _bounce() -> void:
	if global_position.x < view.position.x or global_position.x > view.end.x:
		_vel.x = -_vel.x
	if global_position.y < view.position.y or global_position.y > view.end.y:
		_vel.y = -_vel.y

func _trigger() -> void:
	_triggered = true
	sprite.play("trigger")
	label.hide()
	if one_liner_id != "":
		DialogueManager.load_tree(one_liner_id)      # opens your JSON text
