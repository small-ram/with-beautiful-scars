extends Control

# ---------------------- CONFIG: FONTS (Variable-friendly) ----------------------
@export_file("*.ttf","*.otf","*.ttc") var inter_var_roman_path  : String = "res://Assets/Font/InterVariable.ttf"
@export_file("*.ttf","*.otf","*.ttc") var inter_var_italic_path : String = "res://Assets/Font/InterVariable-Italic.ttf" # optional but recommended
@export_file("*.ttf","*.otf","*.ttc") var mono_font_path        : String = "res://Assets/Font/JetBrainsMono.ttf"      # for [code]
# Decorative / calligraphic font (optional)
@export_file("*.ttf", "*.otf") var lucida_path: String = "res://Assets/Font/LucidaUnicodeCalligraphy.ttf"
@export var lucida_tag: String = "calli"   # Use [calli]...[/calli] in JSON

# Optional per-project styling
@export var body_variation: String = ""        # Theme variation name for RichTextLabel
@export var button_variation: String = ""      # Theme variation name for Buttons
@export var hover_sfx: AudioStream

# Node paths
@export_node_path("RichTextLabel")   var body_path: NodePath
@export_node_path("VBoxContainer")   var choice_box_path: NodePath   # points to ChoiceBox under ScrollContainer
@export_node_path("TextureRect")     var portrait_path: NodePath
@export_node_path("AnimationPlayer") var anim_path: NodePath
@export_node_path()                  var hover_audio_path: NodePath
@export_node_path("Button")          var choice_template_path: NodePath   # ChoiceBox/ChoiceTemplate

# Internals
var _body: RichTextLabel
var _choice_box: VBoxContainer
var _portrait: TextureRect
var _anim: AnimationPlayer
var _hover_audio: Node
var _choice_template: Button

func _ready() -> void:
	_body            = get_node_or_null(body_path) as RichTextLabel
	_choice_box      = get_node_or_null(choice_box_path) as VBoxContainer
	_portrait        = get_node_or_null(portrait_path) as TextureRect
	_anim            = get_node_or_null(anim_path) as AnimationPlayer
	_hover_audio     = get_node_or_null(hover_audio_path)
	_choice_template = get_node_or_null(choice_template_path) as Button

	if _body:
		if body_variation != "": _body.theme_type_variation = body_variation
		_setup_richtext_fonts(_body)
		# Core label behavior
		_body.bbcode_enabled = true
		_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.fit_content = false
		_body.scroll_active = true

	# Let critters find this for fallback portraits
	add_to_group("dialogue_ui")

	if is_instance_valid(DialogueManager):
		DialogueManager.register_ui(self)

func _exit_tree() -> void:
	if is_instance_valid(DialogueManager):
		DialogueManager.unregister_ui(self)

# ---------------------- PUBLIC API (called by DialogueManager) ----------------------
func show_line(data: Dictionary) -> void:
	visible = true

	# 1) Body text (string or array of paragraphs)
	if _body:
		var raw_body: Variant = data.get("body", "")
		var bb := _to_bbcode_body(raw_body)
		bb = _normalize_markup(bb)
		_body.bbcode_text = bb

	# 2) Portrait
	if _portrait:
		var p: String = str(data.get("portrait", ""))
		if p != "" and ResourceLoader.exists(p):
			_portrait.texture = load(p) as Texture2D
			_portrait.visible = true
		else:
			if _portrait.texture == null:
				_portrait.visible = false

	# 3) Choices
	_clear_choices()
	var choices: Array = []
	var choices_any: Variant = data.get("choices", [])
	if choices_any is Array:
		choices = choices_any

	if _choice_box:
		if choices.is_empty():
			_add_continue_button()
		else:
			for i in range(choices.size()):
				var label: String = ""
				var e: Variant = choices[i]
				if e is Dictionary:
					var d: Dictionary = e
					label = str(d.get("label", ""))
				else:
					label = str(e)
				if label == "":
					label = "Continue"
				_add_choice_button(i, label)

	# 4) Optional entrance anim
	if _anim and _anim.has_animation("FadeIn"):
		_anim.play("FadeIn")

# Allow critters/logic to provide a portrait if the JSON lacks one
func set_fallback_portrait(tex: Texture2D) -> void:
	if _portrait and tex and (_portrait.texture == null):
		_portrait.texture = tex
		_portrait.visible = true

# ---------------------- UI helpers ----------------------
func _clear_choices() -> void:
	if _choice_box == null: return
	for c in _choice_box.get_children():
		if c != _choice_template:
			c.queue_free()
	if _choice_template:
		_choice_template.visible = false

func _make_button() -> Button:
	var b: Button
	if is_instance_valid(_choice_template):
		b = _choice_template.duplicate() as Button
		if b:
			b.visible = true
			b.disabled = false
			return b
	# Fallback if template missing
	b = Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = 0
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	return b

func _add_choice_button(index: int, text: String) -> void:
	if _choice_box == null: return
	var b: Button = _make_button()
	if button_variation != "": b.theme_type_variation = button_variation
	b.text = text                    # Buttons ignore BBCode by design → keep plain text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(_on_btn_hover)
	b.pressed.connect(_on_btn_pressed.bind(index))
	_choice_box.add_child(b)
	if _choice_box.get_child_count() == 1:
		b.grab_focus()

func _add_continue_button() -> void:
	if _choice_box == null: return
	var b: Button = _make_button()
	if button_variation != "": b.theme_type_variation = button_variation
	b.text = "Continue"
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(_on_btn_hover)
	b.pressed.connect(_on_continue_pressed)
	_choice_box.add_child(b)
	b.grab_focus()

# ---------------------- Signals ----------------------
func _on_continue_pressed() -> void:
	if is_instance_valid(DialogueManager):
		DialogueManager.advance()

func _on_btn_pressed(index: int) -> void:
	if is_instance_valid(DialogueManager):
		DialogueManager.choose(index)

func _on_btn_hover() -> void:
	if _hover_audio and hover_sfx:
		if _hover_audio is AudioStreamPlayer2D:
			var p2d: AudioStreamPlayer2D = _hover_audio
			p2d.stream = hover_sfx
			p2d.play()
		elif _hover_audio is AudioStreamPlayer:
			var p: AudioStreamPlayer = _hover_audio
			p.stream = hover_sfx
			p.play()
	if _anim and _anim.has_animation("ChoiceHoverPulse"):
		_anim.play("ChoiceHoverPulse")

# ---------------------- MARKUP PROCESSING ----------------------
# Let authors write body either as a single string or Array of paragraphs.
# Arrays are joined with a blank line between items.
func _to_bbcode_body(value: Variant) -> String:
	if value is Array:
		var parts: PackedStringArray = []
		for v in value:
			parts.append(str(v))
		return "\n\n".join(parts)
	return str(value)

# Light normalizer:
# - unify newlines
# - support [quote]...[/quote] sugar → [indent][i]...[/i][/indent]
# Light normalizer + semantic font aliases
func _normalize_markup(s: String) -> String:
	var r := s.replace("\r\n", "\n")

	# Sugar for quotes → indented italics
	r = r.replace("[quote]",  "[indent][i]")
	r = r.replace("[/quote]", "[/i][/indent]")

	# --- Semantic font alias: [calli]...[/calli] (or whatever lucida_tag is)
	if lucida_tag != "" and lucida_path != "" and ResourceLoader.exists(lucida_path):
		var open_tag  := "[" + lucida_tag + "]"
		var close_tag := "[/" + lucida_tag + "]"
		# Replace all occurrences; keep it simple and fast
		r = r.replace(open_tag,  "[font=\"" + lucida_path + "\"]")
		r = r.replace(close_tag, "[/font]")

	return r


# ---------------------- FONT SETUP (variable-font aware) ----------------------
func _setup_richtext_fonts(label: RichTextLabel) -> void:
	var roman_ff  : Font = _load_fontfile(inter_var_roman_path)
	var italic_ff : Font = _load_fontfile(inter_var_italic_path) # may be null if you don't ship it
	var mono_ff   : Font = _load_fontfile(mono_font_path)

	# --- Normal / Bold from ROMAN variable file via 'wght'
	if roman_ff:
		label.add_theme_font_override("normal_font", _axes(roman_ff, {"wght": 400.0}))
		label.add_theme_font_override("bold_font",   _axes(roman_ff, {"wght": 700.0}))

	# --- Italic / Bold-Italic
	if italic_ff:
		label.add_theme_font_override("italics_font",      _axes(italic_ff, {"wght": 400.0}))
		label.add_theme_font_override("bold_italics_font", _axes(italic_ff, {"wght": 700.0}))
	elif roman_ff and _font_has_axis(roman_ff, "slnt"):
		# If no dedicated italic file, try slant axis on roman
		label.add_theme_font_override("italics_font",      _axes(roman_ff, {"wght": 400.0, "slnt": -10.0}))
		label.add_theme_font_override("bold_italics_font", _axes(roman_ff, {"wght": 700.0, "slnt": -10.0}))
	elif roman_ff:
		# Last resort: map italics to roman so tags don't break (visual italics won't appear)
		label.add_theme_font_override("italics_font",      _axes(roman_ff, {"wght": 400.0}))
		label.add_theme_font_override("bold_italics_font", _axes(roman_ff, {"wght": 700.0}))

	# --- Monospace for [code]
	if mono_ff:
		label.add_theme_font_override("mono_font", mono_ff)

	# Optional readability tweak
	label.add_theme_constant_override("line_separation", 2)

# Make a specific OpenType-variation instance (weight/slant/etc.)
func _axes(base: Font, requested_axes: Dictionary) -> Font:
	if base == null:
		return null
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = _clamp_axes_to_supported(base, requested_axes)
	return v

func _load_fontfile(path: String) -> Font:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var f := load(path)
	return f as Font

func _font_has_axis(f: Font, tag: String) -> bool:
	if f == null:
		return false
	var axes := f.get_supported_variation_list() # Dictionary axis_tag -> limits
	return axes.has(tag)

# Clamp requested axis values to what the font supports (type-agnostic to avoid crashes)
func _clamp_axes_to_supported(base: Font, requested: Dictionary) -> Dictionary:
	if base == null:
		return requested
	var axes := base.get_supported_variation_list()
	var out := {}
	for k in requested.keys():
		var value := float(requested[k])
		if axes.has(k):
			var limits = axes[k]     # could be Vector2, Vector3, Array, etc. depending on build
			var minv := 0.0
			var maxv := 1000.0
			match typeof(limits):
				TYPE_VECTOR2:
					minv = limits.x; maxv = limits.y
				TYPE_VECTOR3:
					minv = limits.x; maxv = limits.y
				TYPE_ARRAY:
					if limits.size() >= 2:
						minv = float(limits[0]); maxv = float(limits[1])
				_:
					# leave the defaults
					pass
			out[k] = clamp(value, minv, maxv)
		# else: axis not supported → silently drop
	return out
