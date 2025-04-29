# scripts/Gameplay/WomanPhoto.gd
extends Area2D
signal all_words_transformed   # StageController listens to this

@export var overlay_words : Array[String] = [
	"My body", "My past", "My children",
	"My self", "My career", "My home"
]

@export var overlay_transforms : Array[String] = [
	" — changed beyond recognition",
	" — a dream of freedom, disappearing",
	" — deeply unloveable",
	" — pain of the strongest gravity",
	" — dispensable",
	" — a thankless job"
]

@onready var sprite     : Sprite2D = $Sprite2D
@onready var container  : Node2D   = $PhrasesContainer

var revealed_count : int          = 0
var transformed    : Array[bool]  = []

func _ready() -> void:
	transformed.resize(overlay_words.size())
	for i in range(transformed.size()):
		transformed[i] = false
	# make sure labels draw above the sprite
	container.z_index = 10
	sprite.z_index    = 0

func _input_event(_vp, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_reveal_next_phrase()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_handle_phrase_click(event.global_position)

# --------------------------------------------------------------
func _reveal_next_phrase() -> void:
	if revealed_count >= overlay_words.size():
		return

	var lbl := Label.new()
	lbl.text = overlay_words[revealed_count]
	lbl.name = "phrase"
	lbl.set_meta("idx", revealed_count)
	lbl.modulate = Color.WHITE
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE   # don’t block clicks
	lbl.theme_type_variation = "Label"              # inherit project font

	# --- new placement: vertical stack left-aligned to portrait ---
	var margin_left := 12.0
	var line_height := 26.0
	lbl.position = Vector2(margin_left,
		-20 + revealed_count * line_height)

	container.add_child(lbl)
	lbl.z_index = 10
	revealed_count += 1

# --------------------------------------------------------------
func _handle_phrase_click(global_pos: Vector2) -> void:
	var local = container.to_local(global_pos)

	# iterate children in reverse so topmost label gets priority
	for i in range(container.get_child_count() - 1, -1, -1):
		var n = container.get_child(i)
		if n is Label:
			var lbl := n as Label
			var size := lbl.get_minimum_size()      # after text update
			var rect := Rect2(lbl.position, size)
			if rect.has_point(local):
				var idx := int(lbl.get_meta("idx"))
				if not transformed[idx]:
					_transform_label(lbl, idx)
				return

func _transform_label(lbl: Label, idx: int) -> void:
	transformed[idx] = true
	lbl.text = overlay_words[idx] + overlay_transforms[idx]
	lbl.modulate = Color(1,0.8,0.4)
	if _all_transformed():
		emit_signal("all_words_transformed")

func _all_transformed() -> bool:
	for done in transformed:
		if not done:
			return false
	return true
