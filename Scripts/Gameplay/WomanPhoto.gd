@tool
extends "res://Scripts/Gameplay/Photo.gd"   # keep drag/snap behaviour
signal all_words_transformed

# ───────────── tweakables ─────────────
@export var phrases_file       : String = "res://Data/woman_phrases.json"
@export var reveal_radius      : float  = 200.0     # px
@export var hover_scale_factor : float  = 1.4       # multiplier for font size (not node scale)
@export var fade_strength      : float  = 1.0

# glyph colors (outline/shadow stay crisp)
@export var base_tint        : Color = Color(0.85, 0.90, 1.00)
@export var hover_tint       : Color = Color(1.00, 1.00, 1.00)
@export var transformed_tint : Color = Color(1.00, 0.90, 0.60)

# typography
@export var label_font_path   : String = "res://Assets/Fonts/Inter-Regular.ttf"
@export var label_font_size   : int    = 36
@export var outline_size_px   : int    = 4
@export var outline_color     : Color  = Color(0, 0, 0, 0.90)
@export var enable_shadow     : bool   = false
@export var shadow_color      : Color  = Color(0, 0, 0, 0.50)

# size control (avoid pixelation + “too small after transform”)
@export var min_font_size         : int = 28
@export var max_font_size         : int = 64
@export var transformed_font_size : int = 44

# ───────────── cached nodes & state ─────────────
@onready var _container : Node2D = $ShardContainer

var _phrases     : Array[Dictionary] = []
var _labels      : Array[Label]      = []
var _transformed : PackedByteArray = PackedByteArray()   # 0 = not transformed, 1 = transformed
var _font_cached : Font = null

# ────────────────────────────────────────────────
func _ready() -> void:
	super._ready()  # Photo.gd initialisation

	# Cache font once (prevents repeated loads)
	if label_font_path != "" and ResourceLoader.exists(label_font_path):
		_font_cached = load(label_font_path) as Font

	# Robust defaults if serialized scene left them null/invalid
	if typeof(min_font_size) != TYPE_INT or min_font_size <= 0:
		min_font_size = max(1, label_font_size - 8)
	if typeof(max_font_size) != TYPE_INT or max_font_size < min_font_size:
		max_font_size = max(min_font_size, label_font_size * 2)
	if typeof(transformed_font_size) != TYPE_INT or transformed_font_size <= 0:
		transformed_font_size = label_font_size

	_load_phrases()
	await _spawn_labels_async()          # stagger creation to reduce hitch

	# IMPORTANT: size the state array AFTER labels exist
	_transformed.resize(_labels.size())  # zero-initialized

	# Hook shard clicks and hide overlays
	for i in range(_container.get_child_count()):
		var shard : Area2D = _container.get_child(i)
		if not shard.input_event.is_connected(_on_shard_input):
			shard.input_event.connect(_on_shard_input.bind(i))
		var overlay := shard.get_node("CrackOverlay") as CanvasItem
		if overlay:
			overlay.visible = false

	set_process(true)

# ────────────────────────────────────────────────
func _load_phrases() -> void:
	var txt := FileAccess.get_file_as_string(phrases_file)
	var j   := JSON.new()
	if j.parse(txt) != OK or typeof(j.data) != TYPE_ARRAY:
		push_error("WomanPhoto: JSON load failed at %s" % phrases_file)
		return
	for e in j.data:
		if typeof(e) == TYPE_DICTIONARY:
			_phrases.append(e as Dictionary)

# ────────────────────────────────────────────────
# Create labels in small batches to avoid a one-frame spike
func _spawn_labels_async() -> void:
	var created: int = 0
	var shard_count: int = int(min(_phrases.size(), _container.get_child_count()))
	for i in range(shard_count):
		var shard: Area2D = _container.get_child(i)
		var poly: PackedVector2Array = shard.get_node("CollisionPolygon2D").polygon
		var center: Vector2 = _poly_box_center(poly)

		var lbl := Label.new()
		lbl.text = str(_phrases[i]["short"])
		lbl.anchor_left = 0
		lbl.anchor_top = 0
		lbl.position = center
		lbl.visible = false
		lbl.scale = Vector2.ONE
		lbl.z_index = 100

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
	if enable_shadow:
		lbl.add_theme_color_override("font_shadow_color", shadow_color)
	else:
		lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0))
	# we animate alpha via self_modulate
	lbl.self_modulate = Color(1,1,1,0)

func _poly_box_center(poly:PackedVector2Array) -> Vector2:
	var min_x := INF; var min_y := INF
	var max_x := -INF; var max_y := -INF
	for p in poly:
		min_x = min(min_x, p.x); max_x = max(max_x, p.x)
		min_y = min(min_y, p.y); max_y = max(max_y, p.y)
	return Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)

# ────────────────────────────────────────────────
func _process(_delta:float) -> void:
	# Guard against early calls (e.g., tool mode)
	if _labels.is_empty() or _transformed.size() < _labels.size():
		return

	var mp : Vector2 = get_viewport().get_mouse_position()

	for i in range(_labels.size()):
		# Safe guard against out-of-bounds (if something desynced)
		if i >= _transformed.size():
			break

		# Already transformed → skip hover effects
		if _transformed[i] != 0:
			continue

		var lbl := _labels[i]

		var dist : float = mp.distance_to(lbl.global_position)
		var t    : float = clampf(1.0 - dist / reveal_radius, 0.0, 1.0)

		lbl.visible         = t > 0.05
		lbl.self_modulate.a = clampf(t * fade_strength, 0.0, 1.0)

		# Crisp: adjust font size (not node scale) and clamp to safe bounds
		var raw_size := int(round(label_font_size * lerp(1.0, hover_scale_factor, t)))
		var min_sz:int = min_font_size
		if typeof(min_font_size) != TYPE_INT or min_font_size <= 0:
			min_sz = max(1, label_font_size - 8)
		var max_sz:int = max_font_size
		if typeof(max_font_size) != TYPE_INT or max_font_size < min_sz:
			max_sz = max(min_sz, label_font_size * 2)
		var target_size := clampi(raw_size, min_sz, max_sz)
		lbl.add_theme_font_size_override("font_size", target_size)
		lbl.scale = Vector2.ONE  # keep geometry scale at 1

		# Glyph color only (outline/shadow stay crisp)
		var col := base_tint.lerp(hover_tint, t)
		lbl.add_theme_color_override("font_color", col)

func _on_shard_input(_vp, event:InputEvent, _shape_idx:int, idx:int) -> void:
	if event is InputEventMouseButton and event.pressed:
		_transform_phrase(idx)

# ────────────────────────────────────────────────
func _transform_phrase(idx:int) -> void:
	if idx < 0 or idx >= _labels.size():
		return
	# guard array size (in case of editor-time changes)
	if _transformed.size() < _labels.size():
		_transformed.resize(_labels.size())

	if _transformed[idx] != 0:
		return

	var lbl := _labels[idx]
	lbl.text = str(_phrases[idx]["long"])
	lbl.add_theme_color_override("font_color", transformed_tint)
	lbl.add_theme_font_size_override("font_size", transformed_font_size)  # final readable size
	lbl.scale = Vector2.ONE
	lbl.self_modulate.a = 1.0

	_transformed[idx] = 1

	var overlay := _container.get_child(idx).get_node("CrackOverlay") as CanvasItem
	if overlay:
		overlay.visible = true

	# emit when all entries are non-zero
	if not _transformed.has(0):
		all_words_transformed.emit()
