extends Panel

@export_node_path("Button")
var new_game_btn_path: NodePath = NodePath("HBoxContainer/NewGameBtn")  # MUST be NodePath, not String

@export_file("*.mp3")
var intro_music: String = ""  # single @export_file only; do NOT combine with @export

const INTRO_PANEL_PATH := "res://Scenes/Overlays/IntroPanel.tscn"
const MAIN_PATH        := "res://Scenes/Main.tscn"

var _btn: Button

# Background load state
var _packed: PackedScene = null
var _intro: Node = null
var _intro_btn: Button = null
var _intro_done: bool = false

# Tiny “Loading…” dots animation after intro finishes (while we wait)
var _dots_timer: Timer = null
var _dots_count: int = 0

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
	if is_instance_valid(PreloadHub):
		PreloadHub.begin()

func _on_new_game() -> void:
	_btn.disabled = true
	
	# Unlock global audio context (covers music + sfx on Web)
	if is_instance_valid(AudioManager):
		AudioManager.unlock_on_user_gesture()
		AudioManager.set_alias("photoSnap", "res://Assets/Sounds/photoSnap.wav")
		AudioManager.set_alias("heartbeat", "res://Assets/Sounds/heartbeat.mp3")

		# 📦 Preload them so there’s no first-time hitch later
		AudioManager.preload_sfx([
			"photoSnap",
			"heartbeat",
		])
	get_tree().set_meta("skip_intro", true)

	# Tell Main to skip its own Intro (we're showing it here)
	if is_instance_valid(RunFlags):
		RunFlags.skip_intro = true

	# Show Intro immediately
	var intro_ps := load(INTRO_PANEL_PATH) as PackedScene
	_intro = intro_ps.instantiate()
	get_tree().root.add_child(_intro)
	_intro_btn = _intro.find_child("AdvanceBtn", true, false) as Button
	if _intro.has_signal("intro_finished"):
		_intro.connect("intro_finished", _on_intro_finished, Object.CONNECT_ONE_SHOT)

	# Start intro music here (MusicManager is an autoload, so it persists across the scene change)
	if intro_music != "" and is_instance_valid(MusicManager):
		MusicManager.play(intro_music)

	# Start background threaded load (non-blocking)
	var err: int = ResourceLoader.load_threaded_request(MAIN_PATH)
	if err != OK:
		# Fallback: direct switch if threaded request fails (rare)
		get_tree().change_scene_to_file(MAIN_PATH)
		return

	set_process(true)

func _process(_dt: float) -> void:
	# If not yet obtained, poll threaded status
	if _packed == null:
		var st: int = ResourceLoader.load_threaded_get_status(MAIN_PATH)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_packed = ResourceLoader.load_threaded_get(MAIN_PATH) as PackedScene
		elif st == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Threaded load failed for %s" % MAIN_PATH)
			set_process(false)
			return

	# If the player finished reading and Main is ready, start now
	if _intro_done and _packed != null:
		_start_main()

func _on_intro_finished() -> void:
	_intro_done = true
	# If still loading, disable button and show “Loading…” with animated dots
	if _packed == null and _intro_btn:
		_intro_btn.disabled = true
		_intro_btn.text = "Loading…"
		_dots_timer = Timer.new()
		_dots_timer.wait_time = 0.35
		_dots_timer.one_shot = false
		_dots_timer.timeout.connect(_on_loading_tick)
		add_child(_dots_timer)
		_dots_timer.start()

func _on_loading_tick() -> void:
	if _intro_btn == null: return
	_dots_count = (_dots_count + 1) % 4
	var dots := ""
	for i in _dots_count: dots += "."
	_intro_btn.text = "Loading" + dots

func _start_main() -> void:
	set_process(false)
	if _dots_timer and is_instance_valid(_dots_timer):
		_dots_timer.stop()
		_dots_timer.queue_free()
	get_tree().change_scene_to_packed(_packed)
