extends Node

# -------------------------------------------------
#              StageController
# -------------------------------------------------
# Tracks game progress and spawns stage‑specific
# scenes (woman photo, fetus photo, etc.)
# -------------------------------------------------

enum GameStage { STAGE1, STAGE2, STAGE3 }
var stage : GameStage = GameStage.STAGE1

var total_photos   : int = 0
var snapped_count  : int = 0
var stage2_started : bool = false

func _ready() -> void:
	# Count draggable photos and wire their 'snapped' signal
	for photo in get_tree().get_nodes_in_group("photos"):
		if photo.has_signal("snapped"):
			total_photos += 1
			photo.snapped.connect(_on_photo_snapped)

# -------------------------------------------------
# Stage‑1 completion → enter Stage‑2
# -------------------------------------------------
func _on_photo_snapped(_photo : Node, _slot : Node) -> void:
	snapped_count += 1
	if snapped_count == total_photos and stage == GameStage.STAGE1 and !stage2_started:
		stage2_started = true
		_enter_stage2()

func _enter_stage2() -> void:
	print(">>> ENTER STAGE 2")
	stage = GameStage.STAGE2

	# --- load WomanPhoto scene (adjust path if different) ---
	var woman_scene : PackedScene = preload("res://Scenes/WomanPhoto.tscn")
	print("woman_scene is:", woman_scene)
	if woman_scene == null:
		push_error("woman_scene preload failed – check path!")
		return
	var woman : Area2D = woman_scene.instantiate()
	# --------------------------------------------------------

	# find PhotoStack, wherever it lives
	var stack := get_tree().get_current_scene().find_child("PhotoStack", true, false)
	if stack == null:
		push_error("PhotoStack node not found")
		return

	stack.add_child(woman)
	woman.global_position = Vector2(1050, 300)
	woman.z_index = 20
	if woman.has_node("Sprite2D"):
		woman.get_node("Sprite2D").z_index = 20

	# connect Stage‑2 completion
	if woman.has_signal("all_words_transformed"):
		woman.all_words_transformed.connect(_on_woman_completed)

func _on_woman_completed() -> void:
	print("== Stage 2 complete! ==")
	_enter_stage3()

func _enter_stage3() -> void:
	print("== Stage 3 starting (stub) ==")
	# TODO: spawn fetus photo and dialogue
