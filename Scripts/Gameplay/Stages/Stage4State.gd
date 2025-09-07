# Stage4State.gd (full)
class_name Stage4State
extends StageState

func enter(controller) -> void:
	CircleBank.hide_bank()

	# start cleanup music
	if controller.music_cleanup != "":
		MusicManager.play(controller.music_cleanup)

	# Enable cleanup mode on all interactables
	for ph in controller.get_tree().get_nodes_in_group("photos"):
		if ph.has_method("unlock_for_cleanup"): ph.unlock_for_cleanup()
	for cr in controller.get_tree().get_nodes_in_group("critters"):
		if cr.has_method("unlock_for_cleanup"): cr.unlock_for_cleanup()
	# Woman becomes draggable in cleanup via its override
	if controller.woman and controller.woman.has_method("unlock_for_cleanup"):
		controller.woman.unlock_for_cleanup()

	# Ensure the horse pad exists
	var rv: Node2D = controller.river
	if rv == null:
		var scn: PackedScene = preload("res://Scenes/Kun.tscn")
		rv = scn.instantiate() as Node2D
		controller.get_tree().current_scene.add_child(rv)
		controller.river = rv
		var pos: Vector2 = controller._river_pos.global_position if controller._river_pos else Vector2(640, 720)
		rv.global_position = pos

	# Move all interactive nodes into CleanupLayer so they layer above the horse
	var cleanup_parent: Node = controller.get_tree().current_scene.find_child("CleanupLayer", true, false)
	if cleanup_parent:
		for ph in controller.get_tree().get_nodes_in_group("photos"):
			if ph is Node2D: _reparent_preserve_global(ph as Node2D, cleanup_parent)
		for cr in controller.get_tree().get_nodes_in_group("critters"):
			if cr is Node2D: _reparent_preserve_global(cr as Node2D, cleanup_parent)
		if controller.woman and controller.woman is Node2D:
			_reparent_preserve_global(controller.woman as Node2D, cleanup_parent)

	# Activate horse and wire completion
	if rv.has_method("set_active"):
		rv.call("set_active", true)
	if rv.has_signal("arrangement_complete"):
		rv.connect("arrangement_complete", func():
			finished.emit(OutroState.new()),
			Object.CONNECT_ONE_SHOT
		)

func exit(_controller) -> void:
	pass

func _reparent_preserve_global(n: Node2D, new_parent: Node) -> void:
	if n.get_parent() == new_parent:
		return
	# Godot 4 has Node.reparent(new_parent, keep_global_xform)
	if n.has_method("reparent"):
		n.call("reparent", new_parent, true)
		return
	# Fallback manual preserve
	var gp: Vector2 = n.global_position
	var gr: float   = n.global_rotation
	var gs: Vector2 = n.global_scale
	var old := n.get_parent()
	if old:
		old.remove_child(n)
	new_parent.add_child(n)
	n.global_position = gp
	n.global_rotation = gr
	n.global_scale    = gs
