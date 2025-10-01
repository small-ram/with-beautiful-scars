# StartMenu.gd
extends Panel

@export_node_path("Button")
var new_game_btn_path: NodePath = NodePath("HBoxContainer/NewGameBtn")

# Allow WAV/OGG/MP3 and avoid comma-separated filter string
@export_file("*.wav", "*.ogg", "*.mp3")
var intro_music: String = ""

const INTRO_PANEL_SCN := preload("res://Scenes/Overlays/IntroPanel.tscn")
const MAIN_PATH       := "res://Scenes/Main.tscn"

var _btn: Button

# Background load state
var _packed: PackedScene = null
var _intro: Node = null
var _intro_done: bool = false

# The ONLY Loading UI (on New Game button)
var _immediate_loading_timer: Timer = null
var _immediate_dots: int = 0

func _ready() -> void:
	call_deferred("_wire")

func _wire() -> void:
	_btn = get_node_or_null(new_game_btn_path) as Button
	if _btn == null:
		_btn = find_child("NewGameBtn", true, false) as Button
	if _btn == null:
		push_error("StartMenu: NewGameBtn not found at %s and not found by name." % str(new_game_btn_path))
		return
	if not _btn.pressed.is_connected(_on_new_game):
		_btn.pressed.connect(_on_new_game)
	mouse_filter = MOUSE_FILTER_STOP
	_btn.grab_focus()

# ---- Single Loading UI on New Game button ----
func _start_loading_ui_now() -> void:
	if _btn:
		_btn.disabled = true
		_btn.text = "Loading"
	if _immediate_loading_timer == null:
		_immediate_loading_timer = Timer.new()
		_immediate_loading_timer.wait_time = 0.35
		_immediate_loading_timer.one_shot = false
		_immediate_loading_timer.timeout.connect(func ():
			if _btn == null:
				return
			_immediate_dots = (_immediate_dots + 1) % 4
			var dots := ""
			for i in _immediate_dots:
				dots += "."
			_btn.text = "Loading" + dots
		)
		add_child(_immediate_loading_timer)
	_immediate_loading_timer.start()

func _stop_loading_ui_now() -> void:
	if _immediate_loading_timer:
		_immediate_loading_timer.stop()
		_immediate_loading_timer.queue_free()
		_immediate_loading_timer = null

# ---- Main click handler (chunked across frames) ----
func _on_new_game() -> void:
	# 0) Show Loading… immediately and let the browser paint it
	_start_loading_ui_now()
	await get_tree().process_frame
	await get_tree().process_frame

	# 1) Unlock audio + sfx aliases/preloads (cheap)
	if is_instance_valid(AudioManager):
		AudioManager.unlock_on_user_gesture()
		AudioManager.set_alias("photoSnap", "res://Assets/Sounds/photoSnap.ogg")
		AudioManager.set_alias("heartbeat", "res://Assets/Sounds/heartbeat.ogg")
		AudioManager.preload_sfx(["photoSnap", "heartbeat"])

	# 2) Skip intro flags for Main (we show intro panel here)
	get_tree().set_meta("skip_intro", true)
	if is_instance_valid(RunFlags):
		RunFlags.skip_intro = true

	# 3) Start music (immediate start)
	if intro_music != "" and is_instance_valid(MusicManager):
		if MusicManager.has_method("play_instant"):
			MusicManager.play_instant(intro_music)
		else:
			MusicManager.play(intro_music, 0.0, true)
	await get_tree().process_frame

	# 4) Add Intro panel (already preloaded)
	_intro = INTRO_PANEL_SCN.instantiate()
	get_tree().root.add_child(_intro)
	if _intro.has_signal("intro_finished"):
		_intro.connect("intro_finished", _on_intro_finished, Object.CONNECT_ONE_SHOT)
	await get_tree().process_frame

	# 5) Start background threaded load of MAIN (non-blocking)
	var err: int = ResourceLoader.load_threaded_request(MAIN_PATH)
	if err != OK:
		# Fallback: load synchronously
		_stop_loading_ui_now()
		get_tree().change_scene_to_file(MAIN_PATH)
		return

	set_process(true)

func _process(_dt: float) -> void:
	# Poll threaded status until the scene is ready
	if _packed == null:
		var st: int = ResourceLoader.load_threaded_get_status(MAIN_PATH)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_packed = ResourceLoader.load_threaded_get(MAIN_PATH) as PackedScene
		elif st == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Threaded load failed for %s" % MAIN_PATH)
			set_process(false)
			_stop_loading_ui_now()
			get_tree().change_scene_to_file(MAIN_PATH)
			return

	# When intro is done and MAIN is ready, switch
	if _intro_done and _packed != null:
		_start_main()

func _on_intro_finished() -> void:
	_intro_done = true
	# IMPORTANT: No additional loading UI here (requirement).
	# We ONLY show 'Loading' on the New Game button.

func _start_main() -> void:
	set_process(false)
	_stop_loading_ui_now()
	get_tree().change_scene_to_packed(_packed)
