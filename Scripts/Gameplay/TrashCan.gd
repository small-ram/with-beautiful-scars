extends Area2D
@export var allowed_group := "discardable"

signal cleanup_complete

func _ready() -> void:
	body_entered.connect(_on_body)

func _on_body(body: Node) -> void:
	if body.is_in_group(allowed_group):
		body.queue_free()
		if _all_cleared():
			cleanup_complete.emit()

func _all_cleared() -> bool:
	for p in get_tree().get_nodes_in_group("photos"):
		if p.is_inside_tree():
			return false
	return true
