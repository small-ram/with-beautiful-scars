extends Area2D
@export var allowed_group : String = "discardable"
signal cleanup_complete               # fires when last discardable photo is gone

var _inside : Array[Area2D] = []      # photos currently overlapping the bin

func _ready() -> void:
	area_entered.connect(_on_area_entered)   # Area–Area collisions
	area_exited .connect(_on_area_exited)
	set_physics_process(true)

func _on_area_entered(a: Area2D) -> void:
	if a.is_in_group(allowed_group):
		_inside.append(a)

func _on_area_exited(a: Area2D) -> void:
	_inside.erase(a)

func _physics_process(_delta: float) -> void:
	# delete any photo that is inside AND no longer being dragged
	for p in _inside.duplicate():
		var dragging: bool = false                 # ← typed
		if p.has_method("is_in_hand"):
			dragging = p.is_in_hand()

		if not dragging and p.is_inside_tree():
			p.queue_free()
			_inside.erase(p)

	if _all_cleared():
		cleanup_complete.emit()


func _all_cleared() -> bool:
	for p in get_tree().get_nodes_in_group("photos"):
		if p.is_in_group("non_discardable"):
			continue            # skip the fetus
		if p.is_inside_tree():
			return false
	return true
