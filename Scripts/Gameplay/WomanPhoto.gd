@tool
extends "res://Scripts/Gameplay/Photo.gd"   # keep drag/snap behaviour
signal all_words_transformed

# ───────────── tweakables ─────────────
@export var phrases_file       : String = "res://Data/woman_phrases.json"
@export var reveal_radius      : float  = 200.0     # px
@export var hover_scale_factor : float  = 1.4
@export var fade_strength      : float  = 1.0
@export var base_tint          : Color = Color(0.7, 0.7, 0.9)  # far colour
@export var hover_tint         : Color = Color(1,   1,   1)    # near colour
@export var transformed_tint   : Color = Color(1, 0.9, 0.6)    # after click

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
		shard.area_entered.connect(_on_shard_entered.bind(i))
		shard.area_exited .connect(_on_shard_exited .bind(i))
		shard.input_event .connect(_on_shard_input  .bind(i))

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
		lbl.text        = _phrases[i]["short"]
		lbl.anchor_left = 0
		lbl.anchor_top  = 0
		lbl.position    = center
		lbl.visible     = false
		lbl.scale       = Vector2.ONE
		lbl.modulate    = base_tint
		lbl.z_index     = 100                      # always on top

		shard.add_child(lbl)
		_labels.append(lbl)

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

		lbl.visible      = t > 0.05
		lbl.scale        = Vector2.ONE * lerp(1.0, hover_scale_factor, t)
		lbl.modulate     = base_tint.lerp(hover_tint, t)
		lbl.modulate.a   = t * fade_strength

# ───────────── shard callbacks ─────────────
func _on_shard_entered(_area:Area2D, _idx:int) -> void: pass
func _on_shard_exited (_area:Area2D, _idx:int) -> void: pass

func _on_shard_input(_vp, event:InputEvent, _shape_idx:int, idx:int) -> void:
	if event is InputEventMouseButton and event.pressed:
		_transform_phrase(idx)

# ────────────────────────────────────────────────
func _transform_phrase(idx:int) -> void:
	if idx < 0 or idx >= _labels.size() or _transformed[idx]: return

	var lbl := _labels[idx]
	lbl.text     = _phrases[idx]["long"]          # replace short → long
	lbl.modulate = transformed_tint
	_transformed[idx] = true

	var overlay := _container.get_child(idx).get_node("CrackOverlay") as CanvasItem
	overlay.visible = true

	if _transformed.count(0) == 0:			# all done
		all_words_transformed.emit()
