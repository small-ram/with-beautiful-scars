# scripts/Gameplay/StageController.gd
extends Node

@export var trash_spawn : Vector2 = Vector2(680, 820)   # ← editable in Inspector
# -------------------------------------------------------------
# ENUM & RUNTIME STATE
# -------------------------------------------------------------
enum Stage { INTRO, STAGE1, WOMAN_LEADIN, STAGE2, STAGE3, CLEANUP, END }
@export var woman_lead_in_scene : PackedScene   # assign SimpleLeadInPanel.tscn
var stage : Stage = Stage.INTRO

var photos_needed : int = 0
var snaps_done    : int = 0

var gameplay : Node        = null
var overlay  : CanvasLayer = null
var woman    : Node        = null      # keep reference if you ever need it

# -------------------------------------------------------------
# EXPORTED NODE-PATHS  (leave empty to let the script auto-find)
# -------------------------------------------------------------
@export_node_path("Node")        var gameplay_path : NodePath
@export_node_path("CanvasLayer") var overlay_path  : NodePath
@export_node_path("Node")        var stack_path    : NodePath   # “PhotoStack”
@export var memory_table : MemoryTable

# -------------------------------------------------------------
# PRELOADED SCENES
# -------------------------------------------------------------
const INTRO_PANEL := preload("res://Scenes/Overlays/IntroPanel.tscn")
const WOMAN_SCENE := preload("res://Scenes/WomanPhoto.tscn")
const FETUS_SCENE := preload("res://Scenes/FetusPhoto.tscn")
const TRASH_SCENE := preload("res://Scenes/TrashCan.tscn")

# -------------------------------------------------------------
# HELPER: find node by path or fall back to name-search
# -------------------------------------------------------------
func _fetch_node(path: NodePath, fallback_name: String) -> Node:
	var n: Node = null
	if path != NodePath(""):
		n = get_node_or_null(path)
	if n == null:
		n = get_tree().current_scene.find_child(fallback_name, true, false)
	return n

# -------------------------------------------------------------
# READY
# -------------------------------------------------------------
func _ready() -> void:
	print("StageController PATH:", get_path())
	print("StageController INSTANCE:", self, "  table:", memory_table)
	if memory_table == null:
		push_error("StageController: memory_table not assigned")
		return
	MemoryPool.init_from_table(memory_table)
	var _slot_to_mem = memory_table.slot_to_memory_id
	var _photo_to_slots = memory_table.photo_to_slots
	# 1. locate key layers
	gameplay = _fetch_node(gameplay_path, "Gameplay")
	overlay  = _fetch_node(overlay_path,  "OverlayLayer")

	if gameplay:
		gameplay.visible = false
	else:
		push_error("StageController: could not find Gameplay layer!")

	if overlay:
		var intro := INTRO_PANEL.instantiate()
		overlay.add_child(intro)
		intro.intro_finished.connect(_enter_stage1)
	else:
		push_error("StageController: could not find OverlayLayer!")

	# 2. set up photo-snap counting for Stage 1
	for p in get_tree().get_nodes_in_group("photos"):
		p.snapped.connect(_on_photo_snapped)
		photos_needed += 1

# -------------------------------------------------------------
# STAGE 1 – regular photo puzzle
# -------------------------------------------------------------
func _enter_stage1() -> void:
	stage      = Stage.STAGE1
	snaps_done = 0

	if overlay:
		for child in overlay.get_children():
			child.queue_free()

	if gameplay:
		gameplay.visible = true

func _on_photo_snapped(_p, _s) -> void:
	if stage != Stage.STAGE1:
		return
	snaps_done += 1
	if snaps_done == photos_needed:
		_enter_woman_leadin()

# -------------------------------------------------------------
# Woman leadin
# -------------------------------------------------------------
func _enter_woman_leadin() -> void:
	stage = Stage.WOMAN_LEADIN
	var panel := woman_lead_in_scene.instantiate()
	overlay.add_child(panel)
	panel.panel_closed.connect(_enter_stage2)

# -------------------------------------------------------------
# STAGE 2 – woman phrases
# -------------------------------------------------------------
func _enter_stage2() -> void:
	stage = Stage.STAGE2

	var stack := _fetch_node(stack_path, "PhotoStack")
	if stack == null:
		push_error("StageController: could not find PhotoStack!")
		return

	woman = WOMAN_SCENE.instantiate()
	stack.add_child(woman)
	woman.position = Vector2(1700, 300)   # tweak for your resolution
	woman.z_index  = 99
	woman.all_words_transformed.connect(_enter_stage3)

# -------------------------------------------------------------
# STAGE 3 – fetus
# -------------------------------------------------------------
func _enter_stage3() -> void:
	stage = Stage.STAGE3

	var fetus := FETUS_SCENE.instantiate()
	get_tree().current_scene.add_child(fetus)
	fetus.global_position = Vector2(640, 360)

	# pulse tween
	fetus.create_tween().tween_property(fetus, "scale", Vector2.ONE * 1.3, 1.0)

	fetus.dialog_done.connect(_enter_cleanup)

# -------------------------------------------------------------
# STAGE 4 – cleanup / trash-can
# -------------------------------------------------------------
func _enter_cleanup() -> void:
	stage = Stage.CLEANUP

	# 1. unlock every photo except the fetus (non_discardable)
	for p in get_tree().get_nodes_in_group("photos"):
		if p.is_in_group("non_discardable"):
			continue
		if p.has_method("unlock_for_cleanup"):
			p.unlock_for_cleanup()

	# 2. spawn the TrashCan at the chosen position
	var trash := TRASH_SCENE.instantiate()
	get_tree().current_scene.add_child(trash)
	trash.global_position = trash_spawn
	trash.cleanup_complete.connect(_enter_end)

# -------------------------------------------------------------
# STAGE 5 – ending
# -------------------------------------------------------------
func _enter_end() -> void:
	stage = Stage.END
	DialogueManager.load_tree("outro")
