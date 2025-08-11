extends Control

@export var stylebook_path: String = "res://Data/Dialogue/stylebook.json"
@export var hover_sfx: AudioStream

# Optional explicit hookups (auto-detect if empty)
@export_node_path("RichTextLabel")   var body_path: NodePath
@export_node_path("VBoxContainer")   var choice_path: NodePath
@export_node_path("TextureRect")     var portrait_path: NodePath
@export_node_path("AnimationPlayer") var anim_path: NodePath
@export_node_path()                  var hover_path: NodePath        # AudioStreamPlayer2D/AudioStreamPlayer
@export_node_path("NinePatchRect")   var backplate_path: NodePath
@export_node_path("MarginContainer") var content_path: NodePath

var _body: RichTextLabel
var _choice_box: VBoxContainer
var _portrait: TextureRect
var _anim: AnimationPlayer
var _hover_snd: Node
var _backplate: Control
var _content: MarginContainer

var _stylebook: Dictionary = {}
var _button_theme_path: String = ""
var _theme_cache: Dictionary = {}    # path -> Theme

# Constant arrays (literal-only → valid constant expressions)
const FB_BODY      := ["Backplate/Content/BodyAndChoices/LineRow/BodyLabel", "BodyLabel"]
const FB_CHOICES   := ["Backplate/Content/BodyAndChoices/Choices/ChoiceBox", "ChoiceBox"]
const FB_PORTRAIT  := ["Backplate/Content/BodyAndChoices/LineRow/Portrait", "Portrait"]
const FB_ANIM      := ["../AnimationPlayer", "AnimationPlayer"]
const FB_HOVER     := ["../sfxHover", "sfxHover"]
const FB_BACKPLATE := ["Backplate"]
const FB_CONTENT   := ["Backplate/Content", "Content"]

# ---------- Lifecycle ----------
func _ready() -> void:
	add_to_group("dialogue_ui")
	if is_instance_valid(DialogueManager):
		DialogueManager.register_ui(self)
	_wire_nodes()
	_stylebook = _load_json(stylebook_path)

# ---------- Node wiring ----------
func _wire_nodes() -> void:
	_body       = _resolve_node(body_path,      FB_BODY,      "RichTextLabel")   as RichTextLabel
	_choice_box = _resolve_node(choice_path,    FB_CHOICES,   "VBoxContainer")   as VBoxContainer
	_portrait   = _resolve_node(portrait_path,  FB_PORTRAIT,  "TextureRect")     as TextureRect
	_anim       = _resolve_node(anim_path,      FB_ANIM,      "AnimationPlayer") as AnimationPlayer
	_hover_snd  = _resolve_node(hover_path,     FB_HOVER,     "")                # Any Node
	_backplate  = _resolve_node(backplate_path, FB_BACKPLATE, "NinePatchRect")   as Control
	_content    = _resolve_node(content_path,   FB_CONTENT,   "MarginContainer") as MarginContainer

func _resolve_node(path: NodePath, fallbacks: Array, type_name: String) -> Node:
	var n: Node = null
	if path != NodePath():
		n = get_node_or_null(path)
	if n == null:
		for p in fallbacks:
			var candidate: Node = get_node_or_null(p)
			if candidate != null:
				n = candidate
				break
	if n == null and type_name != "":
		n = _find_first_of_type(self, type_name)
	return n

func _find_first_of_type(root: Node, type_name: String) -> Node:
	for c: Node in root.get_children():
		if c.get_class() == type_name:
			return c
		var n: Node = _find_first_of_type(c, type_name)
		if n != null:
			return n
	return null

# ---------- Public API ----------
func show_line(data: Dictionary) -> void:
	visible = true
	if _body == null or _choice_box == null or _portrait == null:
		_wire_nodes()

	# Style first
	var style: Dictionary = _resolve_style(data)
	_apply_style(style)

	# Label layout & text
	if _body != null:
		_body.visible = true
		_body.bbcode_enabled = true
		_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.fit_content = true
		_body.scroll_active = false
		_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_body.size_flags_vertical = Control.SIZE_FILL
		var body_text: String = str(data.get("body", ""))
		_body.text = body_text

	# Portrait
	if _portrait != null:
		var portrait_path_s: String = str(data.get("portrait", ""))
		if portrait_path_s != "" and ResourceLoader.exists(portrait_path_s):
			_portrait.texture = load(portrait_path_s) as Texture2D
			_portrait.visible = true
		else:
			_portrait.texture = null
			_portrait.visible = false

	# Choices
	_clear_choices()
	var choices_any: Variant = data.get("choices", [])
	var choices: Array = []
	if choices_any is Array:
		choices = choices_any
	if _choice_box != null:
		for i in range(choices.size()):
			var entry_any: Variant = choices[i]
			if entry_any is Dictionary:
				var entry: Dictionary = entry_any
				_add_choice_button(i, str(entry.get("label", "")))
		if choices.is_empty():
			_add_continue_button()

	# Animation
	if _anim != null and _anim.has_animation("FadeIn"):
		_anim.play("FadeIn")

# ---------- Choices ----------
func _clear_choices() -> void:
	if _choice_box == null:
		return
	for c: Node in _choice_box.get_children():
		_choice_box.remove_child(c)
		c.queue_free()

func _add_choice_button(index: int, label_text: String) -> void:
	var b: Button = Button.new()
	b.text = label_text
	b.focus_mode = Control.FOCUS_ALL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND
	b.mouse_entered.connect(_on_btn_hovered)
	b.pressed.connect(_on_btn_pressed.bind(index))

	var btn_theme_path_s: String = _current_button_theme_path()
	if btn_theme_path_s != "":
		var th: Theme = _get_theme(btn_theme_path_s)
		if th != null:
			b.theme = th
	else:
		b.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		b.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		b.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))

	_choice_box.add_child(b)

func _add_continue_button() -> void:
	var b: Button = Button.new()
	b.text = "Continue"
	b.focus_mode = Control.FOCUS_ALL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND
	b.mouse_entered.connect(_on_btn_hovered)
	b.pressed.connect(_on_continue_pressed)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	_choice_box.add_child(b)
	b.grab_focus()

func _on_continue_pressed() -> void:
	if is_instance_valid(DialogueManager):
		DialogueManager.advance()

func _on_btn_pressed(index: int) -> void:
	if is_instance_valid(DialogueManager):
		DialogueManager.choose(index)

func _on_btn_hovered() -> void:
	if _hover_snd != null and hover_sfx != null:
		if _hover_snd is AudioStreamPlayer2D:
			var p2d: AudioStreamPlayer2D = _hover_snd
			p2d.stream = hover_sfx
			p2d.play()
		elif _hover_snd is AudioStreamPlayer:
			var p: AudioStreamPlayer = _hover_snd
			p.stream = hover_sfx
			p.play()
		else:
			_hover_snd.set("stream", hover_sfx)
			_hover_snd.call("play")
	if _anim != null and _anim.has_animation("ChoiceHoverPulse"):
		_anim.play("ChoiceHoverPulse")

# ---------- Styling ----------
func _resolve_style(line: Dictionary) -> Dictionary:
	var style_key: String = str(line.get("style", "default"))
	var def_any: Variant = _stylebook.get("default", {})
	var st_any: Variant = _stylebook.get(style_key, def_any)
	return (st_any as Dictionary) if (st_any is Dictionary) else {}

func _apply_style(style: Dictionary) -> void:
	# Scene/theme
	var theme_path_s: String = str(style.get("theme", ""))
	if theme_path_s != "":
		var th: Theme = _get_theme(theme_path_s)
		if th != null:
			theme = th

	# Body font/color/size with safe defaults and no error spam
	var col: Color = _color_from(style.get("body_color", "#ffffff"), Color(1, 1, 1, 1))
	var fs: int = int(style.get("body_font_size", 18))
	var font_path_s: String = str(style.get("body_font", ""))

	var font_res: Font = null
	if font_path_s != "" and ResourceLoader.exists(font_path_s):
		font_res = load(font_path_s) as Font   # guarded load

	if _body != null:
		_body.add_theme_color_override("default_color", col)
		_body.add_theme_font_size_override("normal_font_size", fs)
		if font_res != null:
			_body.add_theme_font_override("normal_font", font_res)

	# Content margin
	if _content != null and style.has("content_margin"):
		var m: int = int(style["content_margin"])
		_content.add_theme_constant_override("margin_left", m)
		_content.add_theme_constant_override("margin_top", m)
		_content.add_theme_constant_override("margin_right", m)
		_content.add_theme_constant_override("margin_bottom", m)

	# Backplate texture (optional)
	if _backplate != null and style.has("background_texture"):
		var tex_path: String = str(style["background_texture"])
		if tex_path != "" and ResourceLoader.exists(tex_path):
			var tex: Texture2D = load(tex_path) as Texture2D
			if _backplate.has_method("set_texture"):
				_backplate.call("set_texture", tex)

	# Rounded corners (uses "panel" stylebox key)
	if _backplate != null and style.has("corner_radius"):
		var radius: int = int(style["corner_radius"])
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0)
		sb.corner_radius_top_left = radius
		sb.corner_radius_top_right = radius
		sb.corner_radius_bottom_left = radius
		sb.corner_radius_bottom_right = radius
		_backplate.add_theme_stylebox_override("panel", sb)

	# Button theme for choices
	_button_theme_path = str(style.get("button_theme", ""))

func _get_theme(path: String) -> Theme:
	if path == "":
		return null
	if _theme_cache.has(path):
		var cached_any: Variant = _theme_cache[path]
		var cached_theme: Theme = cached_any as Theme
		if cached_theme != null:
			return cached_theme
	if not ResourceLoader.exists(path):
		return null
	var th: Theme = load(path) as Theme
	if th != null:
		_theme_cache[path] = th
	return th

# ---------- JSON utils ----------
func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt: String = f.get_as_text()
	f.close()
	var parsed_any: Variant = JSON.parse_string(txt)
	return (parsed_any as Dictionary) if (parsed_any is Dictionary) else {}

func _current_button_theme_path() -> String:
	return _button_theme_path

# ---------- Helpers ----------
func _color_from(value: Variant, fallback: Color) -> Color:
	# Accept "#rrggbb", "rrggbb", or dict {r,g,b,a}
	if value is String:
		return Color.from_string(value, fallback)
	if value is Dictionary:
		var d: Dictionary = value
		return Color(
			float(d.get("r", fallback.r)),
			float(d.get("g", fallback.g)),
			float(d.get("b", fallback.b)),
			float(d.get("a", fallback.a))
		)
	return fallback
