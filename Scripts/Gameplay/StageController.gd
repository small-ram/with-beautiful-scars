# scripts/Gameplay/StageController.gd
extends Node
#
# Flow summary
#   • parent / difficulty   (unchanged)
#   • Stage 1    – all photo dialogues and critter dialogues finished
#   • Stage 2    – mid panel → woman photo
#   • Stage 3    – woman shrinks to marker, fetus spawns at FetusSpawn
#               click fetus → centre + heartbeat + dialogue
#   • Stage 4    – photos turn gold when dragged over fetus, then drag to river
#   • Outro
#
# ───────── EXPORTS ─────────
@export_node_path("Node")        var gameplay_path      : NodePath
@export_node_path("CanvasLayer") var overlay_path       : NodePath
@export_node_path("CanvasLayer") var critter_layer_path : NodePath
@export_node_path("Node")        var stack_path         : NodePath
@export_node_path("Marker2D")    var woman_spawn_path   : NodePath
@export_node_path("Marker2D")    var river_spawn_path   : NodePath
@export_node_path("Marker2D")    var fetus_spawn_path   : NodePath
@export_node_path("Marker2D")   var fetus_centre_path : NodePath
@export_node_path("Marker2D")    var woman_target_path  : NodePath

@export var mid_stage_panel     : PackedScene               # “Now she is ready …”
@export var memory_table        : MemoryTable
@export var alt_intro_scene     : PackedScene
@export_file("*.json") var easy_slots_json : String
@export_file("*.json") var hard_slots_json : String
@export var heartbeat_sfx       : String = "fetusHeartbeat"

# ───────── ONREADY MARKERS ─────────
@onready var _woman_spawn : Marker2D = get_node_or_null(woman_spawn_path)
@onready var _river_pos   : Marker2D = get_node_or_null(river_spawn_path)
@onready var _fetus_spawn : Marker2D = get_node_or_null(fetus_spawn_path)
@onready var _fetus_centre : Marker2D = get_node_or_null(fetus_centre_path)
@onready var _woman_target: Marker2D = get_node_or_null(woman_target_path)

# ───────── STATE ─────────
var gameplay : Node        = null
var overlay  : CanvasLayer = null
var critter_layer : CanvasLayer = null
var woman    : Node = null
var fetus    : Node = null
var current_state : StageState = null

# ───────── READY ─────────
func _ready() -> void:
	# Initialize the memory pool only if a table is assigned
	if memory_table == null:
		push_warning("StageController: 'memory_table' is not assigned. MemoryPool will be empty; dialogues that rely on it may fail.")
	else:
		MemoryPool.init_from_table(memory_table)
		CircleBank.reload()  # <-- ensure icons rebuild after load/reload

	gameplay = _fetch_node(gameplay_path, "Gameplay"); gameplay.visible = false
	overlay  = _fetch_node(overlay_path,  "OverlayLayer")
	critter_layer = _fetch_node(critter_layer_path, "CritterLayer") as CanvasLayer

	for ph in get_tree().get_nodes_in_group("photos"):
		var pid: String = ph.dialog_id
		if pid != "":
			ph.dialogue_done.connect(_on_photo_dialogue_done)

	change_state(IntroState.new())


# ───────── STATE HELPERS ─────────
func change_state(new_state: StageState) -> void:
	if current_state:
		current_state.finished.disconnect(change_state)
		current_state.exit(self)
	current_state = new_state
	if current_state:
		current_state.finished.connect(change_state)
		current_state.enter(self)

func _on_photo_dialogue_done(photo) -> void:
	if current_state:
		current_state.on_photo_dialogue_done(self, photo)

func _on_critter_dialogue_done(critter) -> void:
	if current_state:
		current_state.on_critter_dialogue_done(self, critter)

# ───────── RESET ─────────
func reset() -> void:
	# If a dialogue is open, close it first so no UI lingers across reloads
	if is_instance_valid(DialogueManager) and DialogueManager.is_active():
		DialogueManager.close()

	# Politely exit current state
	if current_state:
		current_state.exit(self)
		current_state = null

	# Clean local spawned nodes (safe even if null)
	if woman:
		woman.queue_free()
		woman = null
	if fetus:
		fetus.queue_free()
		fetus = null

	# Reset CircleBank visuals before we leave the scene
	CircleBank.reset_all()

	# IMPORTANT: perform the scene change DEFERRED and RETURN immediately.
	# Do NOT await frames or call anything on this node after this line.
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/Main.tscn")
	return

# ───────── helpers ─────────
func _clear_overlay() -> void:
	if overlay == null: return
	for c in overlay.get_children(): c.queue_free()

func _fetch_node(path:NodePath, fallback:String) -> Node:
	if path != NodePath(""):
		var n := get_node_or_null(path)
		if n: return n
	return get_tree().current_scene.find_child(fallback, true, false)
