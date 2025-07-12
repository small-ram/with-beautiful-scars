# scripts/Gameplay/StageController.gd
extends Node

# ───────────────────────── EXPORTS ─────────────────────────
@export_node_path("Node")        var gameplay_path    : NodePath
@export_node_path("CanvasLayer") var overlay_path     : NodePath
@export_node_path("Node")        var stack_path       : NodePath
@export_node_path("Marker2D")    var woman_spawn_path : NodePath
@export_node_path("Marker2D")    var trash_spawn_path : NodePath
@export_node_path("Marker2D")    var fetus_spawn_path : NodePath

@export var woman_lead_in_scene : PackedScene
@export var memory_table        : MemoryTable
@export var alt_intro_scene     : PackedScene         # duplicate of IntroPanel with parent-branch text
@export var easy_slots_json     : String = "res://Data/SlotConfigs/easy.json"
@export var hard_slots_json     : String = "res://Data/SlotConfigs/hard.json"

# ───────── ONREADY MARKERS ─────────
@onready var _woman_spawn : Marker2D = get_node_or_null(woman_spawn_path)
@onready var _trash_spawn : Marker2D = get_node_or_null(trash_spawn_path)
@onready var _fetus_spawn : Marker2D = get_node_or_null(fetus_spawn_path)

# ───────── STATE ─────────
enum Stage { SETUP, INTRO, STAGE1, WOMAN_LEADIN, STAGE2, STAGE3, CLEANUP, END }
var stage : Stage = Stage.SETUP

var gameplay : Node        = null
var overlay  : CanvasLayer = null
var woman    : Node        = null

var photos_needed : int = 0
var snaps_done    : int = 0

# ───────── PRELOADS ─────────
const PARENT_PANEL      := preload("res://Scenes/Overlays/ParentChoicePanel.tscn")
const DIFFICULTY_PANEL  := preload("res://Scenes/Overlays/DifficultyChoicePanel.tscn")
const INTRO_PANEL       := preload("res://Scenes/Overlays/IntroPanel.tscn")
const WOMAN_SCENE       := preload("res://Scenes/WomanPhoto.tscn")
const FETUS_SCENE       := preload("res://Scenes/FetusPhoto.tscn")
const TRASH_SCENE       := preload("res://Scenes/TrashCan.tscn")
const CRITTER_SCENES := [
	preload("res://Scenes/CritterSklenenka.tscn"),
	preload("res://Scenes/CritterSnek.tscn"),
	preload("res://Scenes/CritterBrouk.tscn"),
	preload("res://Scenes/CritterJesterka.tscn"),
	preload("res://Scenes/CritterKliste.tscn"),
	preload("res://Scenes/CritterList.tscn")
]

# ───────── READY ─────────
func _ready() -> void:
	if memory_table == null:
		push_error("StageController: memory_table not assigned"); return
	MemoryPool.init_from_table(memory_table)

	gameplay = _fetch_node(gameplay_path, "Gameplay")
	overlay  = _fetch_node(overlay_path,  "OverlayLayer")
	if gameplay: gameplay.visible = false
	if overlay == null:
		push_error("StageController: OverlayLayer missing!"); return

	# 1st fork – “Are you her parent?”
	var p := PARENT_PANEL.instantiate()
	overlay.add_child(p)
	p.parent_chosen.connect(_on_parent_decided)

	for ph in get_tree().get_nodes_in_group("photos"):
		ph.snapped.connect(_on_photo_snapped)
		photos_needed += 1

# ───────── CHOICE FLOW ─────────
func _on_parent_decided(is_parent:bool) -> void:
	for c in overlay.get_children(): c.queue_free()

	if is_parent:
		_show_alt_intro()
	else:
		_show_difficulty()

func _show_alt_intro() -> void:
	if alt_intro_scene == null:
		push_error("StageController: alt_intro_scene not set"); return
	var alt := alt_intro_scene.instantiate()
	overlay.add_child(alt)

	# when the last parent-branch line is clicked, exit the game
	alt.intro_finished.connect(func(): get_tree().quit())


func _show_difficulty() -> void:
	var d := DIFFICULTY_PANEL.instantiate()
	overlay.add_child(d)
	d.difficulty_chosen.connect(_on_difficulty_selected)

func _on_difficulty_selected(is_easy:bool) -> void:
	var cfg_path := easy_slots_json if is_easy else hard_slots_json
	_apply_slot_config(cfg_path)

	for c in overlay.get_children(): c.queue_free()
	var intro := INTRO_PANEL.instantiate()
	overlay.add_child(intro)
	intro.intro_finished.connect(_enter_stage1)
	
func _spawn_critters() -> void:
	var spawns := get_tree().current_scene.find_child("CritterSpawnPoints", true, false)
	if spawns == null:
		push_warning("CritterSpawnPoints node missing"); return

	for i in CRITTER_SCENES.size():
		var c : Area2D = CRITTER_SCENES[i].instantiate() as Area2D   # explicit type
		spawns.add_child(c)
		c.global_position = spawns.get_child(i).global_position

# ───────── SLOT CONFIG LOADER ─────────
func _apply_slot_config(path:String) -> void:
	var txt := FileAccess.get_file_as_string(path)
	var j   := JSON.new()
	if j.parse(txt) != OK or typeof(j.data) != TYPE_DICTIONARY:
		push_error("SlotConfig parse failed: " + path); return

	for photo_name in j.data:
		var ph := get_tree().current_scene.find_child(photo_name, true, false)
		if ph == null: continue

		# check property list for "allowed_slots"
		for prop in ph.get_property_list():
			if prop.name == "allowed_slots":
				ph.set("allowed_slots", PackedInt32Array(j.data[photo_name]))
				break

# ───────── STAGE 1 – PUZZLE ─────────
func _enter_stage1() -> void:
	stage      = Stage.STAGE1
	snaps_done = 0
	if gameplay: gameplay.visible = true
	for c in overlay.get_children(): c.queue_free()
	_spawn_critters()

func _on_photo_snapped(_p, _s) -> void:
	if stage != Stage.STAGE1: return
	snaps_done += 1
	if snaps_done == photos_needed:
		_enter_woman_leadin()

# ───────── WOMAN LEAD-IN ─────────
func _enter_woman_leadin() -> void:
	stage = Stage.WOMAN_LEADIN
	var panel := woman_lead_in_scene.instantiate()
	overlay.add_child(panel)
	panel.panel_closed.connect(_enter_stage2)

# ───────── STAGE 2 – WOMAN ─────────
func _enter_stage2() -> void:
	stage = Stage.STAGE2
	var stack := _fetch_node(stack_path, "PhotoStack")
	if stack == null:
		push_error("StageController: PhotoStack missing!"); return

	woman = WOMAN_SCENE.instantiate()
	stack.add_child(woman)
	woman.global_position = (_woman_spawn.global_position if _woman_spawn else Vector2.ZERO)
	woman.z_index = 99
	woman.all_words_transformed.connect(_enter_stage3)

# ───────── STAGE 3 – FETUS ─────────
func _enter_stage3() -> void:
	stage = Stage.STAGE3
	var fetus := FETUS_SCENE.instantiate()
	get_tree().current_scene.add_child(fetus)
	fetus.global_position = (_fetus_spawn.global_position if _fetus_spawn else Vector2.ZERO)
	fetus.create_tween().tween_property(fetus, "scale", Vector2.ONE * 1.3, 1.0)
	fetus.dialog_done.connect(_enter_cleanup)

# ───────── STAGE 4 – CLEANUP ─────────
func _enter_cleanup() -> void:
	stage = Stage.CLEANUP
	for ph in get_tree().get_nodes_in_group("photos"):
		if ph.is_in_group("non_discardable"): continue
		if ph.has_method("unlock_for_cleanup"): ph.unlock_for_cleanup()

	var trash := TRASH_SCENE.instantiate()
	get_tree().current_scene.add_child(trash)
	trash.global_position = (_trash_spawn.global_position if _trash_spawn else Vector2.ZERO)
	trash.cleanup_complete.connect(_enter_end)

# ───────── STAGE 5 – END ─────────
func _enter_end() -> void:
	stage = Stage.END
	DialogueManager.load_tree("outro")

# ───────── helper ─────────
func _fetch_node(path:NodePath, fallback:String) -> Node:
	if path != NodePath(""):
		var n := get_node_or_null(path)
		if n: return n
	return get_tree().current_scene.find_child(fallback, true, false)
