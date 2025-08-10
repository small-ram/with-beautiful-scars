# scripts/Gameplay/StageController.gd
extends Node
#
# Flow summary
#   • parent / difficulty   (unchanged)
#   • Stage 1  – 6 photos snapped AND 6 critter dialogues done
#   • Stage 2  – mid panel → woman photo
#   • Stage 3  – woman shrinks to marker, fetus spawns at FetusSpawn
#               click fetus → centre + heartbeat + dialogue
#   • Stage 4  – photos turn gold when dragged over fetus, then drag to river
#   • Outro
#

# ───────── EXPORTS ─────────
@export_node_path("Node")        var gameplay_path      : NodePath
@export_node_path("CanvasLayer") var overlay_path       : NodePath
@export_node_path("Node")        var stack_path         : NodePath
@export_node_path("Marker2D")    var woman_spawn_path   : NodePath
@export_node_path("Marker2D")    var river_spawn_path   : NodePath
@export_node_path("Marker2D")    var fetus_spawn_path   : NodePath
@export_node_path("Marker2D") 	var fetus_centre_path : NodePath
@export_node_path("Marker2D")    var woman_target_path  : NodePath

@export var woman_lead_in_scene : PackedScene
@export var mid_stage_panel     : PackedScene               # “Now she is ready …”
@export var memory_table        : MemoryTable
@export var alt_intro_scene     : PackedScene
@export var easy_slots_json     : String
@export var hard_slots_json     : String
@export var heartbeat_sfx       : String = "fetusHeartbeat"

# ───────── ONREADY MARKERS ─────────
@onready var _woman_spawn : Marker2D = get_node_or_null(woman_spawn_path)
@onready var _river_pos   : Marker2D = get_node_or_null(river_spawn_path)
@onready var _fetus_spawn : Marker2D = get_node_or_null(fetus_spawn_path)
@onready var _fetus_centre : Marker2D = get_node_or_null(fetus_centre_path)
@onready var _woman_target: Marker2D = get_node_or_null(woman_target_path)

# ───────── STATE ─────────
enum Stage { INTRO, STAGE1, STAGE2, STAGE3, STAGE4, END }
var stage : Stage = Stage.INTRO

var gameplay : Node        = null
var overlay  : CanvasLayer = null
var woman    : Node = null
var fetus    : Node = null

var snaps_done     : int = 0
var photos_total   : int = 0
var critters_done  : int = 0

# critter queue
const CRITTERS : Array[PackedScene] = [
	preload("res://Scenes/Critters/CritterJesterka.tscn"),
	preload("res://Scenes/Critters/CritterBrouk.tscn"),
	preload("res://Scenes/Critters/CritterList.tscn"),
	preload("res://Scenes/Critters/CritterSklenenka.tscn"),
	preload("res://Scenes/Critters/CritterSnek.tscn"),
	preload("res://Scenes/Critters/CritterKliste.tscn")
]
var _queue : Array[PackedScene] = []
var _current_critter : Node = null

# ───────── PRELOADS ─────────
# Gameplay depends on a few key scenes. These preloads make their
# responsibilities explicit and avoid repeated disk access during play.
const PARENT_PANEL     := preload("res://Scenes/Overlays/ParentChoicePanel.tscn")
const DIFFICULTY_PANEL := preload("res://Scenes/Overlays/DifficultyChoicePanel.tscn")
const INTRO_PANEL      := preload("res://Scenes/Overlays/IntroPanel.tscn")
const WOMAN_SCENE      := preload("res://Scenes/WomanPhoto.tscn")   # stage 2 photo of the mother
const FETUS_SCENE      := preload("res://Scenes/FetusPhoto.tscn")   # stage 3 heartbeat interaction
const RIVER_SCENE      := preload("res://Scenes/River.tscn")        # stage 4 cleanup area

# ───────── READY ─────────
func _ready() -> void:
	MemoryPool.init_from_table(memory_table)

	gameplay = _fetch_node(gameplay_path, "Gameplay") ; gameplay.visible = false
	overlay  = _fetch_node(overlay_path,  "OverlayLayer")

	var parent := PARENT_PANEL.instantiate()
	overlay.add_child(parent)
	parent.parent_chosen.connect(_on_parent_decided)

	for ph in get_tree().get_nodes_in_group("photos"):
		photos_total += 1
		ph.snapped.connect(_on_photo_snapped)

# ──────── PARENT / DIFFICULTY ────────
func _on_parent_decided(is_parent:bool) -> void:
	_clear_overlay()
	if is_parent: _show_alt_intro() 
	else: _show_difficulty()

func _show_alt_intro() -> void:
	var alt := alt_intro_scene.instantiate()
	overlay.add_child(alt)
	alt.intro_finished.connect(func(): get_tree().quit())

func _show_difficulty() -> void:
	var d := DIFFICULTY_PANEL.instantiate()
	overlay.add_child(d)
	d.difficulty_chosen.connect(_on_diff_selected)

func _on_diff_selected(easy:bool) -> void:
	_apply_slot_cfg(easy_slots_json if easy else hard_slots_json)
	_clear_overlay()
	var intro := INTRO_PANEL.instantiate()
	overlay.add_child(intro)
	intro.intro_finished.connect(_enter_stage1)

func _apply_slot_cfg(path:String) -> void:
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK: return
	for n in j.data:
		var ph := get_tree().current_scene.find_child(n, true, false)
		if ph: ph.allowed_slots = PackedInt32Array(j.data[n])

# ──────── STAGE 1 ────────
func _enter_stage1() -> void:
	stage = Stage.STAGE1
	gameplay.visible = true
	CircleBank.reset_all(); CircleBank.show_bank()
	snaps_done = 0; critters_done = 0
	_queue = CRITTERS.duplicate(); _queue.shuffle()
	_spawn_next_critter()

func _spawn_next_critter() -> void:
	if _current_critter: _current_critter.queue_free()
	if _queue.is_empty():
		_current_critter = null
		_check_stage1_done()
		return
	_current_critter = _queue.pop_back().instantiate()
	get_tree().current_scene.add_child(_current_critter)
	_current_critter.dialogue_done.connect(_on_critter_done, CONNECT_ONE_SHOT)

func _on_critter_done() -> void:
	critters_done += 1
	_spawn_next_critter()        # continue queue
	_check_stage1_done()

func _on_photo_snapped(_p, _slot) -> void:
	if stage != Stage.STAGE1: return
	snaps_done += 1
	_check_stage1_done()

func _check_stage1_done() -> void:
	if snaps_done == photos_total and critters_done == 6 and _current_critter == null:
		_enter_stage2()

# ──────── STAGE 2 (mid panel → woman) ────────
func _enter_stage2() -> void:
	stage = Stage.STAGE2
	_clear_overlay()
	var mid := mid_stage_panel.instantiate()
	overlay.add_child(mid)
	mid.intro_finished.connect(_spawn_woman)

func _spawn_woman() -> void:
	_clear_overlay()
	var stack := _fetch_node(stack_path, "PhotoStack")
	woman = WOMAN_SCENE.instantiate()
	stack.add_child(woman)
	woman.global_position = (_woman_spawn.global_position if _woman_spawn else Vector2(150,150))
	woman.all_words_transformed.connect(_enter_stage3)

# ──────── STAGE 3 (woman shrinks → fetus) ────────
func _enter_stage3() -> void:
	stage = Stage.STAGE3
	var dest := _woman_target.global_position if _woman_target else Vector2(100,100)
	woman.create_tween().tween_property(woman,"global_position",dest,0.8).set_trans(Tween.TRANS_SINE)
	woman.create_tween().tween_property(woman,"scale",Vector2.ONE*0.3,0.8)

	await get_tree().create_timer(0.8).timeout
	fetus = FETUS_SCENE.instantiate()
	get_tree().current_scene.add_child(fetus)
	fetus.global_position = (_fetus_spawn.global_position if _fetus_spawn else Vector2.ZERO)
	fetus.center_pos      = _fetus_centre.global_position
	AudioManager.play_sfx(heartbeat_sfx)
	fetus.dialog_done.connect(_enter_stage4)

# ──────── STAGE 4 (gold → river) ────────
func _enter_stage4() -> void:
	stage = Stage.STAGE4
	CircleBank.hide_bank()

	for ph in get_tree().get_nodes_in_group("photos"):
		if ph.has_method("unlock_for_cleanup"): ph.unlock_for_cleanup()

	var river := RIVER_SCENE.instantiate()
	get_tree().current_scene.add_child(river)
	river.global_position = (_river_pos.global_position if _river_pos else Vector2(640,720))
	river.cleanup_complete.connect(_enter_end)

# ──────── OUTRO ────────
func _enter_end() -> void:
	stage = Stage.END
	DialogueManager.load_tree("outro")

# ──────── helpers ────────
func _clear_overlay() -> void:
	if overlay == null: return
	for c in overlay.get_children(): c.queue_free()

func _fetch_node(path:NodePath, fallback:String) -> Node:
	if path != NodePath(""):
		var n := get_node_or_null(path)
		if n: return n
	return get_tree().current_scene.find_child(fallback, true, false)
