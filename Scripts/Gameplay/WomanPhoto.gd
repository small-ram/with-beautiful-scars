extends "res://Scripts/Gameplay/Photo.gd"    # inherit drag snap
signal all_words_transformed

@export var left_margin : float = 12.0
@export var line_height : float = 26.0

@onready var container := $PhrasesContainer

# ------------------------------------------------------------------
# short + long sentence pairs
# ------------------------------------------------------------------
@export var phrases : Array[Dictionary] = [
	{ "short": "My body",     "long": " — changed beyond recognition" },
	{ "short": "My past",     "long": " — a dream of freedom, disappearing" },
	{ "short": "My children", "long": " — deeply unloveable" },
	{ "short": "My self",     "long": " — pain of the strongest gravity" },
	{ "short": "My career",   "long": " — dispensable" },
	{ "short": "My home",     "long": " — a thankless job" }
]

var revealed_count : int         = 0
var transformed    : Array[bool] = []

# ------------------------------------------------------------------
func _ready() -> void:
	transformed.resize(phrases.size())
	container.z_index = 10
	sprite.z_index    = 0

func _input_event(_vp, event: InputEvent, _shape_idx: int) -> void:
	# 1) woman-specific mouse handling
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_reveal_next_phrase()
			return                      # stop: don't start a drag
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_handle_phrase_click(event.global_position)
			# no return → allow Photo.gd to treat same press as drag start

	# 2) delegate all input to Photo.gd so dragging works
	super._input_event(_vp, event, _shape_idx)

# ------------------------------------------------------------------
func _reveal_next_phrase() -> void:
	if revealed_count >= phrases.size():
		return

	var data: Dictionary = phrases[revealed_count]

	var lbl := Label.new()
	lbl.text = String(data["short"])
	lbl.name = "phrase"
	lbl.set_meta("idx", revealed_count)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.theme_type_variation = "Label"

	# ensure size is calculated for first-frame hit-testing
	lbl.size = lbl.get_minimum_size()
	lbl.position = Vector2(left_margin, -20 + revealed_count * line_height)

	container.add_child(lbl)
	lbl.z_index = 10

	revealed_count += 1

# ------------------------------------------------------------------
func _handle_phrase_click(global_pos: Vector2) -> void:
	var local: Vector2 = container.to_local(global_pos)   # ← typed
	for i in range(container.get_child_count() - 1, -1, -1):
		var n := container.get_child(i)
		if n is Label:
			var lbl := n as Label
			var rect := Rect2(lbl.position, lbl.size)
			if rect.has_point(local):
				var idx := int(lbl.get_meta("idx"))
				if not transformed[idx]:
					_transform_label(lbl, idx)
				return

func _transform_label(lbl: Label, idx: int) -> void:
	var data: Dictionary = phrases[idx]
	lbl.text = String(data["short"]) + String(data["long"])
	lbl.modulate = Color(1.0, 0.8, 0.4)
	transformed[idx] = true
	if transformed.count(false) == 0:
		all_words_transformed.emit()
