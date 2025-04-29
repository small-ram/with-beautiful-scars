# scripts/Gameplay/StageController.gd
extends Node

enum Stage { INTRO, STAGE1, STAGE2, STAGE3, CLEANUP, END }
var stage: Stage = Stage.INTRO
var photos_needed: int = 0
var snaps_done: int = 0
var woman: Node = null

const INTRO_PANEL := preload("res://Scenes/Overlays/IntroPanel.tscn")
const WOMAN_SCENE := preload("res://Scenes/WomanPhoto.tscn")
const FETUS_SCENE := preload("res://Scenes/FetusPhoto.tscn")
const TRASH_SCENE := preload("res://Scenes/TrashCan.tscn")

var gameplay: Node = null
var overlay: CanvasLayer = null

func _ready() -> void:
	var root = get_tree().current_scene

	# 1) Find & hide Gameplay
	gameplay = root.find_child("Gameplay", true, false)
	if gameplay == null:
		push_error("StageController: Could not find 'Gameplay'!")
	else:
		gameplay.visible = false

	# 2) Find OverlayLayer & spawn intro
	overlay = root.find_child("OverlayLayer", true, false) as CanvasLayer
	if overlay == null:
		push_error("OverlayLayer not found! Children of root are: " 
			+ str(root.get_children().map(func(c): return c.name)))
	else:
		var intro = INTRO_PANEL.instantiate()
		overlay.add_child(intro)
		intro.intro_finished.connect(_enter_stage1)

	# 3) Pre-connect all photos for Stage1
	for p in get_tree().get_nodes_in_group("photos"):
		p.snapped.connect(_on_photo_snapped)
		photos_needed += 1

# ---------- Stage 1 ----------
func _enter_stage1() -> void:
	stage = Stage.STAGE1
	snaps_done = 0
	# --- CLEAR ANY LEFTOVER PANELS ---
	if overlay:
		for child in overlay.get_children():
			child.queue_free()
	# Now un-hide photos & slots
	if gameplay:
		gameplay.visible = true
	print(">>> ENTER STAGE 1")


func _on_photo_snapped(_p, _s) -> void:
	snaps_done += 1
	if snaps_done == photos_needed and stage == Stage.STAGE1:
		_enter_stage2()

# ---------- Stage 2 ----------
func _enter_stage2() -> void:
	stage = Stage.STAGE2
	woman = WOMAN_SCENE.instantiate()
	var stack = get_tree().current_scene.find_child("PhotoStack", true, false)
	if stack:
		stack.add_child(woman)
		woman.position = Vector2(1050, 300)
		woman.z_index = 10
		woman.all_words_transformed.connect(_enter_stage3)
	else:
		push_error("StageController: 'PhotoStack' not found!")

# ---------- Stage 3 ----------
func _enter_stage3() -> void:
	stage = Stage.STAGE3
	var fetus = FETUS_SCENE.instantiate()
	get_tree().current_scene.add_child(fetus)
	fetus.global_position = Vector2(640, 360)
	var tw = fetus.create_tween()
	tw.tween_property(fetus, "scale", Vector2.ONE * 1.3, 1.0)
	fetus.dialog_done.connect(_enter_cleanup)

# ---------- Stage 4 / Cleanup ----------
func _enter_cleanup() -> void:
	stage = Stage.CLEANUP
	var trash = TRASH_SCENE.instantiate()
	get_tree().current_scene.add_child(trash)
	trash.global_position = Vector2(180, 420)
	trash.cleanup_complete.connect(_enter_end)

func _enter_end() -> void:
	stage = Stage.END
	DialogueManager.load_tree("end_text")
