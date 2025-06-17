@tool
extends Area2D

signal seal_done(photo)

var _slot  : Node2D
var _photo : Area2D
var _sharp : bool = false

func init(slot:Node2D, photo:Area2D) -> void:
	_slot  = slot
	_photo = photo
	$AnimationPlayer.play("sharpen")   # ← NEW: put the player on the clip
	set_process(true)          # make sure _physics_process runs

func _ready():
	set_process(false)         # disabled until init() is called

func _physics_process(_delta:float) -> void:
	if _slot == null: return
	var dist   : float = _photo.global_position.distance_to(_slot.global_position)
	var factor : float = clamp(1.0 - dist / 250.0, 0.0, 1.0)
	$AnimationPlayer.seek(factor * 0.3, true)

func _on_dialogue_closed(_unused:String) -> void:
	emit_signal("seal_done", _photo)
	queue_free()
