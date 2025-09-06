extends Control

@export var hover_sfx: AudioStream
@export var body_variation: String = ""      # optional Theme variation name
@export var button_variation: String = ""    # optional Theme variation name for buttons

@export_node_path("RichTextLabel")   var body_path: NodePath
@export_node_path("VBoxContainer")   var choice_box_path: NodePath   # points to ChoiceBox under ScrollContainer
@export_node_path("TextureRect")     var portrait_path: NodePath
@export_node_path("AnimationPlayer") var anim_path: NodePath
@export_node_path()                  var hover_audio_path: NodePath
@export_node_path("Button")          var choice_template_path: NodePath   # ChoiceBox/ChoiceTemplate

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

	if _body and body_variation != "":
		_body.theme_type_variation = body_variation
	if is_instance_valid(DialogueManager):
		DialogueManager.register_ui(self)

func show_line(data: Dictionary) -> void:
	visible = true

	# Body text (visuals from Theme)
	if _body:
		_body.bbcode_enabled = true
		_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.fit_content = false
		_body.scroll_active = true
		# IMPORTANT: use bbcode_text so inline tags (e.g., [font]) are parsed
		_body.bbcode_text = str(data.get("body", ""))

	# Portrait
	if _portrait:
		var p: String = str(data.get("portrait", ""))
		if p != "" and ResourceLoader.exists(p):
			_portrait.texture = load(p) as Texture2D
			_portrait.visible = true
		else:
			_portrait.texture = null
			_portrait.visible = false

	# Choices
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
				var e: Variant = choices[i]
				var label: String
				if e is Dictionary:
					var d: Dictionary = e
					label = str(d.get("label", ""))
				else:
					label = str(e)
				_add_choice_button(i, label)

	# Optional entrance anim
	if _anim and _anim.has_animation("FadeIn"):
		_anim.play("FadeIn")

# ---- Buttons from in-scene template ----
func _make_button() -> Button:
	if _choice_template:
		var b := _choice_template.duplicate() as Button
		b.visible = true
		b.disabled = false
		return b
	# Fallback if template missing (keeps behavior correct)
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = 0
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	return b

func _add_choice_button(index: int, text: String) -> void:
	if _choice_box == null: return
	var b := _make_button()
	if button_variation != "": b.theme_type_variation = button_variation
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(_on_btn_hover)
	b.pressed.connect(_on_btn_pressed.bind(index))
	_choice_box.add_child(b)

func _add_continue_button() -> void:
	if _choice_box == null: return
	var b := _make_button()
	if button_variation != "": b.theme_type_variation = button_variation
	b.text = "Continue"
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(_on_btn_hover)
	b.pressed.connect(_on_continue_pressed)
	_choice_box.add_child(b)
	b.grab_focus()

func _clear_choices() -> void:
	if _choice_box == null: return
	for c in _choice_box.get_children():
		c.queue_free()

# ---- Signals ----
func _on_continue_pressed() -> void:
	if is_instance_valid(DialogueManager): DialogueManager.advance()

func _on_btn_pressed(index: int) -> void:
	if is_instance_valid(DialogueManager): DialogueManager.choose(index)

func _on_btn_hover() -> void:
	if _hover_audio and hover_sfx:
		if _hover_audio is AudioStreamPlayer2D:
			var p2d: AudioStreamPlayer2D = _hover_audio; p2d.stream = hover_sfx; p2d.play()
		elif _hover_audio is AudioStreamPlayer:
			var p: AudioStreamPlayer = _hover_audio; p.stream = hover_sfx; p.play()
	if _anim and _anim.has_animation("ChoiceHoverPulse"):
		_anim.play("ChoiceHoverPulse")
