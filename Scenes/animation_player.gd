extends Area2D
@export var memory_id    : String
@export var anchor_slot  : NodePath
signal circle_sharpened(memory_id)
var _sharp := false

func _physics_process(_d):
	var target := get_node(anchor_slot) as Node2D
	var dist := position.distance_to(target.global_position)
	var factor := clamp(250.0 - dist, 0, 250) / 250.0
	$AnimationPlayer.seek(factor * 0.2, true)

	if not _sharp and factor >= 1.0:
		_sharp = true
		circle_sharpened.emit(memory_id)
