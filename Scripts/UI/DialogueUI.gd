@tool
extends Panel

## Dialogue UI (Godot 4.4) – single-definition, warnings-free
class_name DialogueUI

# ───────────────── editor-exposed configuration ─────────────────
@export var dialogue_dir: String = "res://Data/Dialogue" # folder with *.json
@export var start_id:   String  = "mem_concept_dialog"   # first dialogue id

# Theme
@export var base_color:  Color = Color("1e1e1e")
@export var accent_color: Color = Color("#ffbb00")
@export var body_font:   Font
@export var body_font_size: int = 24

# Portrait
@export var speaker_texture: Texture2D
@export var speaker_offset: Vector2 = Vector2(32, 32)

# Sounds
@export var hover_sound: AudioStream
@export var click_sound: AudioStream

# ───────────────── node references ─────────────────
@onready var _body_label: RichTextLabel   = $MarginContainer/VBox/RichTextLabel
@onready var _choices:    VBoxContainer  = $MarginContainer/VBox/Choices
@onready var _speaker:    TextureRect    = $Speaker
@onready var _sfx:        AudioStreamPlayer = $AudioStreamPlayer

# ───────────────── runtime ─────────────────
var _dialogue_map: Dictionary = {}
var _current_id:   String = ""

# ───────────────── lifecycle ─────────────────
func _ready() -> void:
	_apply_theme()
	_load_dialogues()
	if _dialogue_map.has(start_id):
		_show_block(start_id)
	else:
		push_warning("Start id '%s' not found" % start_id)

# ───────────────── theme / layout ─────────────────
func _apply_theme() -> void:
	self_modulate = base_color

	if _speaker:
		_speaker.texture  = speaker_texture
		_speaker.position = speaker_offset
	else:
		push_warning("TextureRect 'Speaker' missing – portrait skipped.")

	if _body_label:
		if body_font:
			_body_label.add_theme_font_override("font", body_font)
		_body_label.add_theme_font_size_override("font_size", body_font_size)
	else:
		push_warning("RichTextLabel path incorrect – body text won’t show.")

# ───────────────── JSON loading ─────────────────
func _load_dialogues() -> void:
	var dir: DirAccess = DirAccess.open(dialogue_dir)
	if dir == null:
		push_error("Cannot open %s" % dialogue_dir)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var json_path: String = dialogue_dir.path_join(fname)
			var block: Dictionary = _parse_json(json_path)
			if block.has("id"):
				_dialogue_map[block["id"]] = block
		fname = dir.get_next()
	dir.list_dir_end()

func _parse_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read %s" % path)
		return {}
	var parser := JSON.new()
	var err: Error = parser.parse(file.get_as_text())
	if err != OK:
		push_error("JSON error in %s: %s" % [path, parser.get_error_message()])
		return {}
	return parser.data as Dictionary

# ───────────────── show block ─────────────────
func _show_block(block_id: String) -> void:
	_current_id = block_id
	var block: Dictionary = _dialogue_map.get(block_id, {})

	if _body_label:
		_body_label.text = block.get("body", "[missing body]")

	# rebuild choices safely
	if _choices:
		for child in _choices.get_children():
			child.queue_free()
		for choice in block.get("choices", []):
			var btn := Button.new()
			btn.text = choice.get("label", "?")
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_color_override("font_color", accent_color)
			btn.mouse_entered.connect(_on_hover.bind(btn))
			btn.pressed.connect(_on_press.bind(btn, choice))
			_choices.add_child(btn)

# ───────────────── interaction ─────────────────
func _on_hover(btn: Button) -> void:
	if hover_sound:
		_sfx.stream = hover_sound
		_sfx.play()
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.08)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.10)

func _on_press(btn: Button, choice: Dictionary) -> void:
	if click_sound:
		_sfx.stream = click_sound
		_sfx.play()
	var next_id: String = choice.get("next", "")
	if next_id != "" and _dialogue_map.has(next_id):
		_show_block(next_id)
	else:
		hide()  # dialogue finished
