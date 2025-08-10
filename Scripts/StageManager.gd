extends Node

@export_node_path("Node") var parent_stage_path : NodePath
@export_node_path("Node") var gameplay_stage_path : NodePath
@export_node_path("Node") var mid_stage_path : NodePath
@export_node_path("Node") var fetus_stage_path : NodePath
@export_node_path("Node") var cleanup_stage_path : NodePath
@export_node_path("Node") var outro_stage_path : NodePath

var _stages : Array[Node] = []
var _current_idx : int = -1

func _ready() -> void:
    _stages = [
        _fetch_node(parent_stage_path, "ParentStage"),
        _fetch_node(gameplay_stage_path, "GameplayStage"),
        _fetch_node(mid_stage_path, "MidStage"),
        _fetch_node(fetus_stage_path, "FetusStage"),
        _fetch_node(cleanup_stage_path, "CleanupStage"),
        _fetch_node(outro_stage_path, "OutroStage")
    ]
    for s in _stages:
        if s == null:
            continue
        s.visible = false
        if s.has_signal("completed"):
            s.completed.connect(_on_stage_completed.bind(s))
    _start_stage(0)

func _start_stage(idx:int) -> void:
    if idx >= _stages.size():
        return
    _current_idx = idx
    var stage = _stages[idx]
    if stage:
        stage.visible = true
        if stage.has_method("start"):
            stage.start()

func _on_stage_completed(stage:Node) -> void:
    if stage:
        stage.visible = false
        var next_idx = _stages.find(stage) + 1
        _start_stage(next_idx)

func _fetch_node(path:NodePath, fallback:String) -> Node:
    if path != NodePath(""):
        var n = get_node_or_null(path)
        if n:
            return n
    return get_node_or_null(fallback)
