@tool
extends "res://Scripts/Gameplay/Photo.gd"   # keep drag/snap behaviour
signal all_words_transformed

@export var phrases_file       : String = "res://Data/Dialogue/Photos/woman_phrases.json"

# Hover reveal
@export var reveal_radius      : float  = 200.0
@export var hover_scale_factor : float  = 1.25
@export var fade_strength      : float  = 1.0
@export var finish_delay_sec   : float  = 0.8

# Glyph tints
@export var base_tint        : Color = Color(0.85, 0.90, 1.00)
@export var hover_tint       : Color = Color(1.00, 1.00, 1.00)
@export var transformed_tint : Color = Color(1.00, 0.90, 0.60)

# Typography
@export var label_font_path   : String = "res://Assets/Fonts/Inter-SemiBold.ttf"
@export var label_font_size   : int    = 36
@export var outline_size_px   : int    = 2
@export var outline_color     : Color  = Color(0, 0, 0, 0.75)
@export var enable_shadow     : bool   = true
@export var shadow_color      : Color  = Color(0, 0, 0, 0.45)
@export var shadow_size_px    : int    = 1
@export var shadow_offset     : Vector2 = Vector2(0, 1)

# Size control
@export var min_font_size         : int = 30
@export var max_font_size         : int = 62
@export var transformed_font_size : int = 46

# ---- Injected data (bypass disk I/O in _ready if provided) ----
@export var injected_phrases: Array[Dictionary] = []
@export var font_override: Font = null

@onready var _container : Node2D = $ShardContainer

var _phrases     : Array[Dictionary] = []
var _labels      : Array[Label]      = []
var _transformed : PackedByteArray   = PackedByteArray()
var _font_cached : Font              = null

func _ready() -> void:
	set_pickable(false)

	# Prefer injected font
	if font_override != null:
		_font_cached = font_override
	elif label_font_path != "" and ResourceLoader.exists(label_font_path):
		var f: Resource = load(label_font_path)
		if f is Font:
			_font_cached = f

	label_font_size       = max(1, label_font_size)
	min_font_size         = max(1, min_font_size)
	max_font_size         = max(min_font_size, max_font_size)
	transformed_font_size = max(1, transformed_font_size)
	outline_size_px       = clampi(outline_size_px, 0, 8)
	shadow_size_px        = clampi(shadow_size_px, 0, 8)

	_load_phrases()
	await _spawn_labels_async()

	_transformed.resize(_labels.size())

	var cc: int = _container.get_child_count()
	for i in range(cc):
		var shard := _container.get_child(i)
		if shard is Area2D:
			var a2d: Area2D = shard
			if not a2d.input_event.is_connected(_on_shard_input):
				a2d.input_event.connect(_on_shard_input.bind(i))
			if not a2d.mouse_entered.is_connected(_on_shard_hover_enter):
				a2d.mouse_entered.connect(_on_shard_hover_enter.bind(i))
			if not a2d.mouse_exited.is_connected(_on_shard_hover_exit):
				a2d.mouse_exited.connect(_on_shard_hover_exit.bind(i))
			var overlay := a2d.get_node_or_null("CrackOverlay")
			if overlay and overlay is CanvasItem:
				(overlay as CanvasItem).visible = false

	if not mouse_entered.is_connected(_on_self_hover_enter):
		mouse_entered.connect(_on_self_hover_enter)
	if not mouse_exited.is_connected(_on_self_hover_exit):
		mouse_exited.connect(_on_self_hover_exit)

	set_process(true)

func unlock_for_cleanup() -> void:
	set_pickable(true)

func _on_self_hover_enter() -> void:
	var can_drag: bool = is_pickable() and not _snapped
	Input.set_default_cursor_shape(
		Input.CURSOR_POINTING_HAND if can_drag else Input.CURSOR_ARROW
	)

func _on_self_hover_exit() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _on_shard_hover_enter(idx: int) -> void:
	var done: bool = _is_shard_transformed(idx)
	Input.set_default_cursor_shape(
		Input.CURSOR_POINTING_HAND if not done else Input.CURSOR_ARROW
	)

func _on_shard_hover_exit(_idx: int) -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _is_shard_transformed(idx: int) -> bool:
	return (idx >= 0 and idx < _transformed.size() and _transformed[idx] != 0)

func _load_phrases() -> void:
	if not injected_phrases.is_empty():
		_phrases = injected_phrases.duplicate()
		return

	if not FileAccess.file_exists(phrases_file):
		push_error("WomanPhoto: phrases file not found: %s" % phrases_file)
		return

	var txt: String = FileAccess.get_file_as_string(phrases_file)
	var j := JSON.new()
	if j.parse(txt) != OK:
		push_error("WomanPhoto: JSON parse failed at %s" % phrases_file)
		return
	if typeof(j.data) != TYPE_ARRAY:
		push_error("WomanPhoto: JSON root must be an array in %s" % phrases_file)
		return

	_phrases.clear()
	for e in j.data:
		if typeof(e) == TYPE_DICTIONARY and e.has("short") and e.has("long"):
			_phrases.append(e)

func _spawn_labels_async() -> void:
	_labels.clear()
	var created: int = 0
	var shard_count: int = min(_phrases.size(), _container.get_child_count())
	for i in range(shard_count):
		var shard_node := _container.get_child(i)
		if not (shard_node is Area2D):
			continue
		var shard: Area2D = shard_node
		var collider := shard.get_node_or_null("CollisionPolygon2D")
		if collider == null or not (collider is CollisionPolygon2D):
			continue
		var poly: PackedVector2Array = (collider as CollisionPolygon2D).polygon
		if poly.is_empty():
			continue
		var center: Vector2 = _poly_box_center(poly)

		var lbl := Label.new()
		lbl.text = str(_phrases[i]["short"])
		lbl.anchor_left = 0.0
		lbl.anchor_top = 0.0
		lbl.position = center
		lbl.visible = false
		lbl.scale = Vector2.ONE
		lbl.z_index = 2

		_apply_label_style(lbl)
		shard.add_child(lbl)
		_labels.append(lbl)

		created += 1
		if created % 3 == 0:
			await get_tree().process_frame

func _apply_label_style(lbl: Label) -> void:
	if _font_cached != null:
		lbl.add_theme_font_override("font", _font_cached)
	lbl.add_theme_font_size_override("font_size", label_font_size)
	lbl.add_theme_constant_override("outline_size", outline_size_px)
	lbl.add_theme_color_override("font_outline_color", outline_color)
	lbl.add_theme_color_override("font_color", base_tint)
	if enable_shadow and shadow_size_px > 0:
		lbl.add_theme_color_override("font_shadow_color", shadow_color)
		lbl.add_theme_constant_override("shadow_size", shadow_size_px)
		lbl.add_theme_constant_override("shadow_offset_x", int(round(shadow_offset.x)))
		lbl.add_theme_constant_override("shadow_offset_y", int(round(shadow_offset.y)))
	else:
		lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0))
		lbl.add_theme_constant_override("shadow_size", 0)
		lbl.add_theme_constant_override("shadow_offset_x", 0)
		lbl.add_theme_constant_override("shadow_offset_y", 0)
	lbl.self_modulate = Color(1,1,1,0)

func _poly_box_center(poly: PackedVector2Array) -> Vector2:
	var min_x: float = INF; var min_y: float = INF
	var max_x: float = -INF; var max_y: float = -INF
	for p in poly:
		min_x = min(min_x, p.x); max_x = max(max_x, p.x)
		min_y = min(min_y, p.y); max_y = max(max_y, p.y)
	return Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)

func _process(_delta: float) -> void:
	if _labels.is_empty():
		return
	if _transformed.size() < _labels.size():
		_transformed.resize(_labels.size())

	var mp: Vector2 = get_viewport().get_mouse_position()

	for i in range(_labels.size()):
		if i >= _transformed.size():
			break
		if _transformed[i] != 0:
			continue

		var lbl: Label = _labels[i]
		var dist: float = mp.distance_to(lbl.global_position)
		var t: float = clampf(1.0 - dist / reveal_radius, 0.0, 1.0)

		lbl.visible = t > 0.05
		lbl.self_modulate.a = clampf(t * fade_strength, 0.0, 1.0)

		var raw_size: int = int(round(label_font_size * lerp(1.0, hover_scale_factor, t)))
		var target_size: int = clampi(raw_size, min_font_size, max_font_size)
		lbl.add_theme_font_size_override("font_size", target_size)
		lbl.scale = Vector2.ONE

		var col: Color = base_tint.lerp(hover_tint, t)
		lbl.add_theme_color_override("font_color", col)

func _on_shard_input(_vp, event: InputEvent, _shape_idx: int, idx: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_transform_phrase(idx)

func _transform_phrase(idx: int) -> void:
	if idx < 0 or idx >= _labels.size():
		return
	if _transformed.size() < _labels.size():
		_transformed.resize(_labels.size())
	if _transformed[idx] != 0:
		return

	var lbl: Label = _labels[idx]
	lbl.text = str(_phrases[idx]["long"])
	lbl.add_theme_color_override("font_color", transformed_tint)
	lbl.add_theme_font_size_override("font_size", clampi(transformed_font_size, min_font_size, max_font_size))
	lbl.scale = Vector2.ONE
	lbl.self_modulate.a = 1.0

	_transformed[idx] = 1

	var shard_node := _container.get_child(idx)
	if shard_node and shard_node is Area2D:
		var overlay := (shard_node as Area2D).get_node_or_null("CrackOverlay")
		if overlay and overlay is CanvasItem:
			(overlay as CanvasItem).visible = true

	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	if not _transformed.has(0):
		await get_tree().create_timer(max(0.0, finish_delay_sec)).timeout
		all_words_transformed.emit()
