class_name Stage2State
extends StageState

const WOMAN_SCENE := preload("res://Scenes/WomanPhoto.tscn")
const NEXT_STATE  := preload("res://Scripts/Gameplay/Stages/Stage3State.gd")

func enter(controller) -> void:
	# Start clean (no prior overlays)
	controller._clear_overlay()

	# 1) Pre-instantiate Woman (invisible) so she can build quietly
	var w: Node2D = WOMAN_SCENE.instantiate() as Node2D
	w.visible = false
	w.z_index = 900

	# Read export strings (typed to avoid Variant inference warnings)
	var phrases_path: String = ""
	var font_path: String = ""
	if w.has_method("get"):
		var pp_any: Variant = w.get("phrases_file")
		var fp_any: Variant = w.get("label_font_path")
		phrases_path = (pp_any as String) if (pp_any is String) else ""
		font_path    = (fp_any as String) if (fp_any is String) else ""

	# Parse phrases + load font up-front
	var phrases: Array[Dictionary] = _parse_phrases(phrases_path)
	var font: Font = _load_font_if_any(font_path)

	# Inject BEFORE adding to scene so WomanPhoto._ready() uses them
	if w.has_method("set"):
		w.set("injected_phrases", phrases)
		if font != null:
			w.set("font_override", font)

	# Parent ABOVE critters and keep a handle
	controller.overlay.add_child(w)
	controller.woman = w

	# Wire transition to Stage 3 (do this before reveal)
	if w.has_signal("all_words_transformed"):
		w.connect("all_words_transformed", func() -> void:
			finished.emit(NEXT_STATE.new())
		)

	# 2) Show Mid panel (Woman continues preparing behind it)
	var mid: Node = controller.mid_stage_panel.instantiate()
	controller.overlay.add_child(mid)

	# When Mid finishes, do NOT clear overlay — just free mid and reveal Woman
	mid.connect("intro_finished", func() -> void:
		_on_mid_finished(controller, w, mid),
		Object.CONNECT_ONE_SHOT
	)

func _on_mid_finished(controller, w: Node2D, mid: Node) -> void:
	# Music for the woman phase
	if controller.music_woman != "":
		MusicManager.play(controller.music_woman)

	# Remove only the panel (do NOT clear the whole overlay!)
	if is_instance_valid(mid):
		mid.queue_free()

	# Spawn position
	var spawn_pos: Vector2 = Vector2(150, 150)
	if controller._woman_spawn:
		spawn_pos = controller._woman_spawn.global_position

	# Reveal with a tiny fade-in
	if not is_instance_valid(w):
		return
	w.global_position = spawn_pos
	w.visible = true
	# small cosmetic fade-in (skip if you don’t want it)
	if w is CanvasItem:
		var ci := w as CanvasItem
		var base := ci.modulate
		ci.modulate = Color(base.r, base.g, base.b, 0.0)
		var tw := ci.create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(ci, "modulate:a", 1.0, 0.15)

# ---------- helpers ----------
func _parse_phrases(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if path == "" or not FileAccess.file_exists(path):
		return out
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed_any: Variant = JSON.parse_string(txt)
	if not (parsed_any is Array):
		return out
	var arr: Array = parsed_any
	for e_any in arr:
		if e_any is Dictionary:
			var d: Dictionary = e_any
			if d.has("short") and d.has("long"):
				out.append(d)
	return out

func _load_font_if_any(path: String) -> Font:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var r: Resource = load(path)
	return r as Font
