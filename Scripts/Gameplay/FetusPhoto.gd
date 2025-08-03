# scripts/Gameplay/FetusPhoto.gd
extends Area2D
signal dialog_done

@export var dialog_id  : String = "fetus_dialog"
@export var center_pos : Vector2                 # set by StageController

@onready var _clicked : bool = false

func _ready() -> void:
	input_pickable = true                        # receive mouse clicks
	area_entered.connect(_on_area_entered)

func _input_event(_vp, ev:InputEvent, _i:int) -> void:
	if _clicked: return
	if ev is InputEventMouseButton and ev.pressed:
		_clicked = true
		_move_to_center_and_talk()

# ───────── move & dialogue ─────────
func _move_to_center_and_talk() -> void:
	var tw := create_tween()
	tw.tween_property(self, "global_position", center_pos, 0.6)\
	   .set_trans(Tween.TRANS_SINE)
	await tw.finished

	DialogueManager.load_tree(dialog_id)
	DialogueManager.dialogue_closed.connect(_on_dialogue_closed, CONNECT_ONE_SHOT)

func _on_dialogue_closed(_id:String) -> void:
	dialog_done.emit()

# ───────── gild photos on touch ─────────
func _on_area_entered(a:Area2D) -> void:
	if not a.is_in_group("photos"):            # only photos matter
		return

	# must be dragged *right now*
	var is_dragging: bool = a.has_method("is_in_hand") and a.is_in_hand()
	if not is_dragging:
		return

	# already gold? skip
	if a.is_in_group("gold"): return

	# — gild —
	a.sprite.modulate = Color(1, 0.85, 0.3)
	a.allowed_slots   = PackedInt32Array()      # disable snapping
	a.add_to_group("gold")
