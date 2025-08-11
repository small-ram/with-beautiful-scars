extends Control

@export var stylebook_path: String = "res://Data/Dialogue/stylebook.json"
@export var hover_sfx: AudioStream

# Optional explicit hookups (auto-detect if empty)
@export_node_path("RichTextLabel") var body_path: NodePath
@export_node_path("VBoxContainer") var choice_path: NodePath
@export_node_path("TextureRect") var portrait_path: NodePath
@export_node_path("AnimationPlayer") var anim_path: NodePath
@export_node_path() var hover_path: NodePath  # AudioStreamPlayer2D/AudioStreamPlayer
@export_node_path("NinePatchRect") var backplate_path: NodePath
@export_node_path("MarginContainer") var content_path: NodePath

var _body: RichTextLabel = null
var _choice_box: VBoxContainer = null
var _portrait: TextureRect = null
var _anim: AnimationPlayer = null
var _hover_snd: Node = null
var _backplate: Control = null
var _content: MarginContainer = null

var _stylebook: Dictionary = {}
var _button_theme_path: String = ""
var _theme_cache: Dictionary = {}  # path -> Theme

func _ready() -> void:
	add_to_group("dialogue_ui")
	if is_instance_valid(DialogueManager):
		DialogueManager.register_ui(self)
	_autowire_nodes()
	_stylebook = _load_json(stylebook_path)

# ---------- Node wiring ----------
func _autowire_nodes() -> void:
        if body_path != NodePath():      _body       = get_node_or_null(body_path) as RichTextLabel
        if choice_path != NodePath():    _choice_box = get_node_or_null(choice_path) as VBoxContainer
        if portrait_path != NodePath():  _portrait   = get_node_or_null(portrait_path) as TextureRect
        if anim_path != NodePath():      _anim       = get_node_or_null(anim_path) as AnimationPlayer
        if hover_path != NodePath():     _hover_snd  = get_node_or_null(hover_path)
        if backplate_path != NodePath(): _backplate  = get_node_or_null(backplate_path) as Control
        if content_path != NodePath():   _content    = get_node_or_null(content_path) as MarginContainer

        if _body == null:
                _body = get_node_or_null("Backplate/Content/BodyAndChoices/LineRow/BodyLabel") as RichTextLabel
        if _choice_box == null:
                _choice_box = get_node_or_null("Backplate/Content/BodyAndChoices/Choices/ChoiceBox") as VBoxContainer
        if _portrait == null:
                _portrait = get_node_or_null("Backplate/Content/BodyAndChoices/LineRow/Portrait") as TextureRect
        if _anim == null:
                _anim = get_node_or_null("../AnimationPlayer") as AnimationPlayer
        if _hover_snd == null:
                _hover_snd = get_node_or_null("../sfxHover")
        if _backplate == null:
                _backplate = get_node_or_null("Backplate") as Control
        if _content == null:
                _content = get_node_or_null("Backplate/Content") as MarginContainer

        if _body == null:
                _body = find_child("BodyLabel", true, false) as RichTextLabel
        if _choice_box == null:
                _choice_box = find_child("ChoiceBox", true, false) as VBoxContainer
        if _portrait == null:
                _portrait = find_child("Portrait", true, false) as TextureRect
        if _anim == null:
                _anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
        if _hover_snd == null:
                _hover_snd = find_child("sfxHover", true, false)
        if _backplate == null:
                _backplate = find_child("Backplate", true, false) as Control
        if _content == null:
                _content = find_child("Content", true, false) as MarginContainer

        if _body == null:
                _body = _find_first_of_type(self, "RichTextLabel") as RichTextLabel
        if _choice_box == null:
                _choice_box = _find_first_of_type(self, "VBoxContainer") as VBoxContainer
        if _portrait == null:
                _portrait = _find_first_of_type(self, "TextureRect") as TextureRect
        if _backplate == null:
                _backplate = _find_first_of_type(self, "NinePatchRect") as Control
        if _content == null:
                _content = _find_first_of_type(self, "MarginContainer") as MarginContainer

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
		_autowire_nodes()

	# Style first
	var style: Dictionary = _resolve_style(data)
	_apply_style(style)

	# Label layout
	if _body != null:
		_body.visible = true
		_body.bbcode_enabled = true
		_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.fit_content = true
		_body.scroll_active = false
		_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_body.size_flags_vertical = Control.SIZE_FILL

	# Content
	var body_text: String = str(data.get("body", ""))
	if _body != null:
		_body.text = body_text

		var portrait_path_s: String = str(data.get("portrait", ""))
		if _portrait != null:
				if portrait_path_s != "":
						_portrait.texture = load(portrait_path_s) as Texture2D
						_portrait.visible = true
				else:
						_portrait.texture = null
						_portrait.visible = false

	# Choices
	_clear_choices()
	var choices_any: Variant = data.get("choices", [])
	var choices: Array = (choices_any as Array) if (choices_any is Array) else []
	if _choice_box != null:
		for i: int in choices.size():
			var entry_any: Variant = choices[i]
			if entry_any is Dictionary:
				var entry: Dictionary = entry_any
				_add_choice_button(i, str(entry.get("label", "")))

		# If there are no choices, show a Continue button (robust to queued frees)
		if choices.is_empty():
			_add_continue_button()

	# Animation
	if _anim != null and _anim.has_animation("FadeIn"):
		_anim.play("FadeIn")

# ---------- Choices ----------
func _clear_choices() -> void:
	if _choice_box == null:
		return
	var children: Array = _choice_box.get_children()
	for c: Node in children:
		_choice_box.remove_child(c)  # immediate removal so child count is updated now
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
        var theme_path_s: String = str(style.get("theme", ""))
        if theme_path_s != "":
                var th: Theme = _get_theme(theme_path_s)
                if th != null:
                        theme = th

        var col: Color = Color(1, 1, 1, 1)
        if style.has("body_color"):
                col = Color(str(style["body_color"]))
        var fs: int = 18
        if style.has("body_font_size"):
                fs = int(style["body_font_size"])
        var font_path_s: String = str(style.get("body_font", ""))
        var font_res: Font = null
        if font_path_s != "":
                var res: Resource = load(font_path_s)
                font_res = res as Font

        if _body != null:
                _body.add_theme_color_override("default_color", col)
                _body.add_theme_font_size_override("normal_font_size", fs)
                if font_res != null:
                        _body.add_theme_font_override("normal_font", font_res)

        if _content != null and style.has("content_margin"):
                var m_any: Variant = style["content_margin"]
                var m: int = int(m_any)
                _content.add_theme_constant_override("margin_left", m)
                _content.add_theme_constant_override("margin_top", m)
                _content.add_theme_constant_override("margin_right", m)
                _content.add_theme_constant_override("margin_bottom", m)

        if _backplate != null and style.has("background_texture"):
                var tex_path: String = str(style["background_texture"])
                if tex_path != "":
                        var tex_res: Resource = load(tex_path)
                        var tex: Texture2D = tex_res as Texture2D
                        if _backplate.has_method("set_texture"):
                                _backplate.call("set_texture", tex)

        if _backplate != null and style.has("corner_radius"):
                var radius: int = int(style["corner_radius"])
                var sb: StyleBoxFlat = StyleBoxFlat.new()
                sb.bg_color = Color(1, 1, 1, 0)
                sb.corner_radius_top_left = radius
                sb.corner_radius_top_right = radius
                sb.corner_radius_bottom_left = radius
                sb.corner_radius_bottom_right = radius
                _backplate.add_theme_stylebox_override("panel", sb)

        _button_theme_path = str(style.get("button_theme", ""))

func _get_theme(path: String) -> Theme:
	if path == "":
		return null
	if _theme_cache.has(path):
		var cached_any: Variant = _theme_cache[path]
		var cached_theme: Theme = cached_any as Theme
		if cached_theme != null:
			return cached_theme
	var res: Resource = load(path)
	var th: Theme = res as Theme
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
