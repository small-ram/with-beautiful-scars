@tool
extends "res://Scripts/Gameplay/Photo.gd"   # keep drag/snap behaviour
signal all_words_transformed

# ───────────── tweakables ─────────────
@export var phrases_file       : String = "res://Data/woman_phrases.json"
@export var reveal_radius      : float  = 200.0     # px
@export var hover_scale_factor : float  = 1.4
@export var fade_strength      : float  = 1.0

# text colors (glyph color only; outline/shadow stay crisp)
@export var base_tint        : Color = Color(0.85, 0.90, 1.00)  # far colour
@export var hover_tint       : Color = Color(1.00, 1.00, 1.00)  # near colour
@export var transformed_tint : Color = Color(1.00, 0.90, 0.60)  # after click

# ── NEW: legibility / typography ──
@export var label_font_path   : String = "res://Assets/Fonts/Inter-Regular.ttf" # change to your font
@export var label_font_size   : int    = 36       # base size, scaled up on hover by your existing code
@export var outline_size_px   : int    = 4        # thick outline = instant readability
@export var outline_color     : Color  = Color(0, 0, 0, 0.90)
@export var enable_shadow     : bool   = true    # outline usually suffices; turn on if you like
@export var shadow_color      : Color  = Color(0, 0, 0, 0.50)

# ───────────── cached nodes & state ─────────────
@onready var _container : Node2D = $ShardContainer

var _phrases     : Array[Dictionary] = []
var _labels      : Array[Label]      = []
var _transformed : PackedByteArray

# ────────────────────────────────────────────────
func _ready() -> void:
	super._ready()      # Photo.gd initialisation

	_load_phrases()
	_spawn_labels()

	_transformed = PackedByteArray()
	_transformed.resize(_phrases.size())

	for i in range(_container.get_child_count()):
		var shard : Area2D = _container.get_child(i)
		shard.input_event.connect(_on_shard_input.bind(i))

		var overlay := shard.get_node("CrackOverlay") as CanvasItem
		overlay.visible = false

	set_process(true)

# ────────────────────────────────────────────────
func _load_phrases() -> void:
	var txt := FileAccess.get_file_as_string(phrases_file)
	var j   := JSON.new()
	if j.parse(txt) != OK or typeof(j.data) != TYPE_ARRAY:
		push_error("WomanPhoto: JSON load failed"); return
	for e in j.data:
		if typeof(e) == TYPE_DICTIONARY:
			_phrases.append(e as Dictionary)

# ────────────────────────────────────────────────
func _spawn_labels() -> void:
	for i in range(_phrases.size()):
		var shard  : Area2D             = _container.get_child(i)
		var poly   : PackedVector2Array = shard.get_node("CollisionPolygon2D").polygon
		var center : Vector2            = _poly_box_center(poly)

		var lbl := Label.new()
		lbl.text      = str(_phrases[i]["short"])
		lbl.anchor_left = 0
		lbl.anchor_top  = 0
		lbl.position    = center
		lbl.visible     = false
		lbl.scale       = Vector2.ONE
		lbl.z_index     = 100

		_apply_label_style(lbl)

		shard.add_child(lbl)
		_labels.append(lbl)

# Create readable label styling (font + outline + optional shadow)
func _apply_label_style(lbl: Label) -> void:
	# base font
	var f: Font = null
	if label_font_path != "" and ResourceLoader.exists(label_font_path):
		f = load(label_font_path) as Font

	if f != null:
		lbl.add_theme_font_override("font", f)
	lbl.add_theme_font_size_override("font_size", label_font_size)

	# outline (the most important readability boost)
	lbl.add_theme_constant_override("outline_size", outline_size_px)
	lbl.add_theme_color_override("font_outline_color", outline_color)

	# glyph color starts at base_tint; we will update per-frame
	lbl.add_theme_color_override("font_color", base_tint)

	# optional subtle shadow (outline usually enough)
	if enable_shadow:
		lbl.add_theme_color_override("font_shadow_color", shadow_color)
	else:
		# ensure no inherited shadow surprises
		lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0))

	# we’ll drive transparency via self_modulate.a, not the glyph color alpha
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
	var mp : Vector2 = get_viewport().get_mouse_position()

	for i in range(_labels.size()):
		if _transformed[i]: continue
		var lbl := _labels[i]

		var dist : float = mp.distance_to(lbl.global_position)
		var t    : float = clamp(1.0 - dist / reveal_radius, 0.0, 1.0)

		lbl.visible            = t > 0.05
		lbl.scale              = Vector2.ONE * lerp(1.0, hover_scale_factor, t)
		lbl.self_modulate.a    = clamp(t * fade_strength, 0.0, 1.0)

		# Color only the glyphs (outline/shadow stay crisp)
		var col := base_tint.lerp(hover_tint, t)
		lbl.add_theme_color_override("font_color", col)

func _on_shard_input(_vp, event:InputEvent, _shape_idx:int, idx:int) -> void:
	if event is InputEventMouseButton and event.pressed:
		_transform_phrase(idx)

# ────────────────────────────────────────────────
func _transform_phrase(idx:int) -> void:
	if idx < 0 or idx >= _labels.size() or _transformed[idx]: return

	var lbl := _labels[idx]
	lbl.text = str(_phrases[idx]["long"])    # replace short → long
	lbl.add_theme_color_override("font_color", transformed_tint)
	lbl.self_modulate.a = 1.0                # make sure it stays fully visible
	_transformed[idx] = true

	var overlay := _container.get_child(idx).get_node("CrackOverlay") as CanvasItem
	overlay.visible = true

	# emit when no zero remains
	if !_transformed.has(0):
		all_words_transformed.emit()
