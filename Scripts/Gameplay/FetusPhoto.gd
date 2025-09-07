# scripts/Gameplay/FetusPhoto.gd
extends Area2D
signal dialogue_done

@export var dialog_id  : String  = "fetus_dialog"
@export var center_pos : Vector2                 # set by StageController

# --- Visual heartbeat targets ---
@export var fetus_sprite_path    : NodePath = NodePath("Sprite2D")
@export var heartbeat_player_path: NodePath            # optional AudioStreamPlayer

# --- Heartbeat look & feel ---
@export var bpm             : float = 60.0       # visual cycle matches 60/BPM
@export var scale_amp       : float = 0.06       # 0.04–0.08 is natural
@export var brighten_amount : float = 0.08       # 0..1 lerp toward white at peak
@export var use_echo_layer  : bool  = true       # soft after-image behind
@export var use_micro_ripple: bool  = false      # needs a ShaderMaterial with 'pulse' uniform

# Lub-dub timings (seconds); total cycle auto-adjusted to BPM with a pause
@export var lub_up      : float = 0.08   # fast swell
@export var lub_release : float = 0.12   # partial relax
@export var dub_gap     : float = 0.16   # tiny silence between lub and dub
@export var dub_up      : float = 0.06   # softer second swell
@export var dub_release : float = 0.22   # full relax

var _clicked       : bool = false
var _my_run_active : bool = false

# Runtime refs for visuals
var _sprite     : Sprite2D
var _audio      : AudioStreamPlayer
var _echo       : Sprite2D
var _base_scale : Vector2
var _base_color : Color
const _WHITE    : Color = Color(1, 1, 1, 1)

func _ready() -> void:
	input_pickable = true
	area_entered.connect(_on_area_entered)

	_sprite = get_node_or_null(fetus_sprite_path) as Sprite2D
	if _sprite == null:
		push_error("FetusPhoto: fetus_sprite_path is not set or not a Sprite2D.")
		return

	_audio = get_node_or_null(heartbeat_player_path) as AudioStreamPlayer

	_base_scale = _sprite.scale
	_base_color = _sprite.modulate

	# Optional echo layer (behind the main sprite)
	if use_echo_layer and _echo == null:
		_echo = Sprite2D.new()
		_echo.texture  = _sprite.texture
		_echo.centered = _sprite.centered
		_echo.offset   = _sprite.offset
		_echo.flip_h   = _sprite.flip_h
		_echo.flip_v   = _sprite.flip_v
		_echo.position = _sprite.position
		_echo.z_index  = _sprite.z_index - 1
		_echo.modulate = Color(1, 1, 1, 0.0)
		_echo.scale    = _base_scale
		add_child(_echo)

	# Start heartbeat visuals (and audio if assigned)
	_start_heartbeat()
	if _audio != null and !_audio.playing:
		_audio.play(0.0)

func _input_event(_vp, ev: InputEvent, _i: int) -> void:
	if _clicked:
		return
	if ev is InputEventMouseButton and ev.pressed:
		_clicked = true
		_move_to_center_and_talk()

# ───────── move & dialogue ─────────
func _move_to_center_and_talk() -> void:
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "global_position", center_pos, 0.6)
	await tw.finished

	# Track run ownership
	if DialogueManager.has_signal("dialogue_started"):
		DialogueManager.dialogue_started.connect(
			func(id: String) -> void:
				_my_run_active = (id == dialog_id),
			Object.CONNECT_ONE_SHOT
		)
	else:
		_my_run_active = true

	DialogueManager.dialogue_finished.connect(
		func(_last_id: String) -> void:
			if _my_run_active:
				_my_run_active = false
				dialogue_done.emit(),
			Object.CONNECT_ONE_SHOT
	)
	DialogueManager.start(dialog_id)

# ───────── gild photos on touch (unchanged) ─────────
func _on_area_entered(a: Area2D) -> void:
	if not a.is_in_group("photos"):
		return
	var is_dragging: bool = a.has_method("is_in_hand") and a.is_in_hand()
	if not is_dragging:
		return
	if a.is_in_group("gold"):
		return

	# — gild —
	# NOTE: relies on the other Area2D exposing 'sprite' and 'allowed_slots'
	a.sprite.modulate = Color(1, 0.85, 0.3)
	a.allowed_slots   = PackedInt32Array()
	a.add_to_group("gold")

# ───────── heartbeat visuals ─────────
func _start_heartbeat() -> void:
	_run_heartbeat_cycle()

func _run_heartbeat_cycle() -> void:
	if _sprite == null:
		return

	# Make total cycle match BPM by adding a pause segment as needed.
	var beat_total : float = lub_up + lub_release + dub_gap + dub_up + dub_release
	var cycle_len : float = 60.0 / max(bpm, 1.0)
	var pause     : float = max(0.0, cycle_len - beat_total)

	# Targets
	var lub_peak_scale    : Vector2 = _base_scale * (1.0 + scale_amp)
	var lub_relaxed_scale : Vector2 = _base_scale * (1.0 + scale_amp * 0.35)
	var dub_peak_scale    : Vector2 = _base_scale * (1.0 + scale_amp * 0.75)
	var bright_color      : Color   = _base_color.lerp(_WHITE, clamp(brighten_amount, 0.0, 1.0))

	# Main tween on the sprite (scale + brighten)
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# LUB: quick swell + brighten
	t.tween_property(_sprite, "scale", lub_peak_scale, lub_up).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_sprite, "modulate", bright_color, lub_up).set_ease(Tween.EASE_OUT)

	# Partial relax
	t.tween_property(_sprite, "scale", lub_relaxed_scale, lub_release).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(_sprite, "modulate", _base_color, lub_release).set_ease(Tween.EASE_IN_OUT)

	# Tiny gap before dub
	t.tween_interval(dub_gap)

	# DUB: softer swell
	t.tween_property(_sprite, "scale", dub_peak_scale, dub_up).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_sprite, "modulate", bright_color, dub_up).set_ease(Tween.EASE_OUT)

	# Full relax + pause to complete BPM
	t.tween_property(_sprite, "scale", _base_scale, dub_release).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_sprite, "modulate", _base_color, dub_release).set_ease(Tween.EASE_IN)
	if pause > 0.0:
		t.tween_interval(pause)

	# Echo layer animation (behind the photo)
	if use_echo_layer and _echo != null:
		var e: Tween = create_tween()
		e.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# prepare starting size slightly larger for a halo feel
		_echo.scale = _base_scale * (1.0 + scale_amp * 1.30)
		# fade in across LUB
		e.tween_property(_echo, "modulate:a", 0.25, lub_up + lub_release).set_ease(Tween.EASE_OUT)
		# hold across the small gap
		e.tween_interval(dub_gap)
		# small re-accent on DUB
		e.tween_property(_echo, "modulate:a", 0.20, dub_up).set_ease(Tween.EASE_OUT)
		# fade away while shrinking slightly toward base, over dub_release + pause
		e.tween_property(_echo, "modulate:a", 0.0, dub_release + pause).set_ease(Tween.EASE_IN)
		e.parallel().tween_property(_echo, "scale", _base_scale * (1.0 + scale_amp * 0.15), dub_release + pause)

	# Optional micro-ripple: drive a 'pulse' uniform in a shader on the sprite
	if use_micro_ripple and _sprite.material is ShaderMaterial:
		var mat: ShaderMaterial = _sprite.material as ShaderMaterial
		var r: Tween = create_tween()
		r.tween_property(mat, "shader_parameter/pulse", 1.0, lub_up).set_ease(Tween.EASE_OUT)
		r.tween_property(mat, "shader_parameter/pulse", 0.3, lub_release + dub_gap).set_ease(Tween.EASE_IN_OUT)
		r.tween_property(mat, "shader_parameter/pulse", 1.0, dub_up).set_ease(Tween.EASE_OUT)
		r.tween_property(mat, "shader_parameter/pulse", 0.0, dub_release + pause).set_ease(Tween.EASE_IN)

	# Loop forever
	t.finished.connect(_run_heartbeat_cycle)
