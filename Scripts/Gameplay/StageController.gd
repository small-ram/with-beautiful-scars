# scripts/Gameplay/StageController.gd
extends Node
#
# State machine overview
#   IntroState  → Stage1State → Stage2State → Stage3State → Stage4State → EndState
#   Each state handles its own setup and emits `transition_to` when ready to move
#   to the next step. StageController swaps states and keeps common references.
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

var current_state : Node = null

# ───────── PRELOADS ─────────
const PARENT_PANEL     := preload("res://Scenes/Overlays/ParentChoicePanel.tscn")
const DIFFICULTY_PANEL := preload("res://Scenes/Overlays/DifficultyChoicePanel.tscn")
const INTRO_PANEL      := preload("res://Scenes/Overlays/IntroPanel.tscn")
const WOMAN_SCENE      := preload("res://Scenes/WomanPhoto.tscn")
const FETUS_SCENE      := preload("res://Scenes/FetusPhoto.tscn")
const RIVER_SCENE      := preload("res://Scenes/River.tscn")  # Area2D with cleanup_complete

# ───────── STATES ─────────
const IntroState  = preload("res://Scripts/Gameplay/States/IntroState.gd")
const Stage1State = preload("res://Scripts/Gameplay/States/Stage1State.gd")
const Stage2State = preload("res://Scripts/Gameplay/States/Stage2State.gd")
const Stage3State = preload("res://Scripts/Gameplay/States/Stage3State.gd")
const Stage4State = preload("res://Scripts/Gameplay/States/Stage4State.gd")
const EndState    = preload("res://Scripts/Gameplay/States/EndState.gd")

# ───────── READY ─────────
func _ready() -> void:
	MemoryPool.init_from_table(memory_table)

	gameplay = fetch_node(gameplay_path, "Gameplay") ; gameplay.visible = false
	overlay  = fetch_node(overlay_path,  "OverlayLayer")

	change_state(IntroState.new())

func change_state(state: Node) -> void:
	if current_state:
			current_state.queue_free()
	current_state = state
	add_child(current_state)
	current_state.transition_to.connect(change_state)
	if current_state is IntroState:
			stage = Stage.INTRO
	elif current_state is Stage1State:
			stage = Stage.STAGE1
	elif current_state is Stage2State:
			stage = Stage.STAGE2
	elif current_state is Stage3State:
			stage = Stage.STAGE3
	elif current_state is Stage4State:
			stage = Stage.STAGE4
	elif current_state is EndState:
			stage = Stage.END
	current_state.enter(self)

func apply_slot_cfg(path:String) -> void:
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK: return
	for n in j.data:
			var ph := get_tree().current_scene.find_child(n, true, false)
			if ph: ph.allowed_slots = PackedInt32Array(j.data[n])

# ──────── helpers ────────
func clear_overlay() -> void:
	if overlay == null: return
	for c in overlay.get_children(): c.queue_free()

func fetch_node(path:NodePath, fallback:String) -> Node:
	if path != NodePath(""):
			var n := get_node_or_null(path)
			if n: return n
	return get_tree().current_scene.find_child(fallback, true, false)
