# scripts/Gameplay/WomanPhoto.gd
extends Area2D
# warning-ignore:unused_signal
signal all_words_transformed

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

@onready var container : Node2D   = $PhrasesContainer
@onready var sprite    : Sprite2D = $Sprite2D

var revealed_count : int = 0
var transformed    : Array[bool] = []

func _ready() -> void:
	# prepare the transformed flags
	transformed.resize(overlay_words.size())
	for i in range(transformed.size()):
		transformed[i] = false

func _input_event(_vp, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_reveal_next_phrase()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_handle_phrase_click(event.global_position)

func _reveal_next_phrase() -> void:
	if revealed_count >= overlay_words.size():
		return
	# spawn a new Label for the next phrase
	var lbl := Label.new()
	lbl.text = overlay_words[revealed_count]
	lbl.name = "Phrase_%d" % revealed_count
	lbl.modulate = Color(1,1,1)                       # white text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE     # clicks pass through to area2d
	# position evenly above the portrait
	var tex_size = sprite.texture.get_size() * sprite.scale
	var x = tex_size.x * (0.1 + 0.8 * revealed_count / (overlay_words.size() - 1))
	lbl.position = Vector2(x, -20)
	container.add_child(lbl)
	revealed_count += 1

func _handle_phrase_click(global_pos: Vector2) -> void:
	var local = container.to_local(global_pos)
	for node in container.get_children():
		if node is Label:
			var lbl = node as Label
			var rect = Rect2(lbl.position, lbl.get_minimum_size())
			if rect.has_point(local):
				# 1. Split the name "Phrase_3" into ["Phrase","3"]
				var parts = lbl.name.split("_")  
				# 2. Convert the second element into an int
				var idx   = parts[1].to_int()       
				if not transformed[idx]:
					_transform_label(lbl, idx)
				return

func _transform_label(lbl: Label, idx: int) -> void:
	transformed[idx] = true
	lbl.text = overlay_words[idx] + overlay_transforms[idx]
	lbl.modulate = Color(1,0.8,0.4)   # tint transformed text
	# when all done, signal StageController
	if _all_transformed():
		emit_signal("all_words_transformed")

func _all_transformed() -> bool:
	for done in transformed:
		if not done:
			return false
	return true
