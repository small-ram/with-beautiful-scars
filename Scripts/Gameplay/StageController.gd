extends Node

enum Stage { INTRO, STAGE1, STAGE2, STAGE3, CLEANUP, END }
var stage: Stage = Stage.INTRO
var photos_needed := 0
var snaps_done    := 0
var woman: Node

const WOMAN_SCENE := preload("res://Scenes/WomanPhoto.tscn")

func _ready() -> void:
	# connect every photo
	for p in get_tree().get_nodes_in_group("photos"):
		p.snapped.connect(_on_photo_snapped)
		photos_needed += 1
	stage = Stage.STAGE1

func _on_photo_snapped(_p,_s) -> void:
	snaps_done += 1
	if snaps_done == photos_needed and stage == Stage.STAGE1:
		_enter_stage2()

# ---------- Stage 2 ----------
func _enter_stage2() -> void:
	stage = Stage.STAGE2
	woman = WOMAN_SCENE.instantiate()
	var stack := get_tree().current_scene.find_child("PhotoStack",true,false)
	stack.add_child(woman)
	woman.position = Vector2(1050,300)
	woman.z_index = 10
	woman.all_words_transformed.connect(_enter_stage3)

# ---------- Stage 3 ----------
const FETUS_SCENE := preload("res://Scenes/FetusPhoto.tscn")

func _enter_stage3() -> void:
	stage = Stage.STAGE3
	var fetus := FETUS_SCENE.instantiate()
	get_tree().current_scene.add_child(fetus)
	fetus.global_position = Vector2(640, 360)
	# gentle zoom-in
	var tw := fetus.create_tween()
	tw.tween_property(fetus, "scale", Vector2.ONE * 1.3, 1.0)
	fetus.dialog_done.connect(_enter_cleanup)

# ---------- Stage 4 ----------
func _enter_cleanup() -> void:
	stage = Stage.CLEANUP
	# TODO: spawn trash-can, register for drag-in events
