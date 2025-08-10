# File: DialogueManager.gd (autoload)
# Godot 4.4

extends Node

signal dialogue_started(id: String)
signal line_loaded(id: String, line: Dictionary)
signal line_shown(id: String, line: Dictionary)
signal choice_made(id: String, choice_index: int, next_id: String)
signal dialogue_finished(last_id: String)
signal dialogue_closed(id: String)  # legacy alias

@export var dialogue_ui_scene: PackedScene = preload("res://Scenes/Overlays/DialoguePanel.tscn")

@export var search_dirs: PackedStringArray = [
	"res://Data/Dialogue/Photos", "res://Data/Dialogue/Critters", "res://Data/Dialogue"
]
@export var file_ext: String = ".json"

# ───────── State ─────────
var _cache: Dictionary = {}  # id:String -> Dictionary (parsed JSON)
var _current_id: String = ""
var _current_line: Dictionary = {}
var _ui: Node = null
var _active: bool = false

var _ui_host: Node = null
var _ui_owned: bool = false


# ───────── Lifecycle ─────────
func _ready() -> void:
	_ui = _find_ui_in_tree()


func register_ui(ui_node: Node) -> void:
	_ui = ui_node


func unregister_ui(ui_node: Node) -> void:
	if _ui == ui_node:
		_ui = null


# ───────── Public API ─────────
func start(id: String) -> void:
	var line: Dictionary = _load(id)
	if line.is_empty():
		return

	_current_id = id
	_current_line = line
	_active = true

	emit_signal("dialogue_started", id)
	emit_signal("line_loaded", id, line)

	var ui: Node = _ensure_ui()
	if ui == null or not ui.has_method("show_line"):
		_active = false
		return

	ui.call_deferred("show_line", line)
	emit_signal("line_shown", id, line)


func choose(choice_index: int) -> void:
	if not _active:
		return

	var choices_any: Variant = _current_line.get("choices", [])
	if not (choices_any is Array):
		return
	var choices: Array = choices_any
	if choice_index < 0 or choice_index >= choices.size():
		return

	if not (choices[choice_index] is Dictionary):
		return
	var choice: Dictionary = choices[choice_index]

	var next_val: Variant = choice.get("next", "")
	var next_id: String = str(next_val).strip_edges()

	emit_signal("choice_made", _current_id, choice_index, next_id)

	if next_id == "" or _resolve_path_for_id(next_id) == "":
		_finish()
	else:
		start(next_id)


func advance() -> void:
	if not _active:
		return
	var choices_any: Variant = _current_line.get("choices", [])
	if not (choices_any is Array) or (choices_any as Array).is_empty():
		_finish()


func close() -> void:
	if _active:
		_finish()


func is_active() -> bool:
	return _active


func current_id() -> String:
	return _current_id


func current_line() -> Dictionary:
	return _current_line


func current_choices() -> Array:
	var a: Variant = _current_line.get("choices", [])
	return (a as Array) if (a is Array) else []


func clear_cache() -> void:
	_cache.clear()


func warm_cache(ids: Array) -> void:
	for id_any in ids:
		if id_any is String:
			_load(id_any as String)


# ───────── Internals ─────────
func _finish() -> void:
	var last: String = _current_id
	_active = false
	emit_signal("dialogue_finished", last)
	emit_signal("dialogue_closed", last)
	_dismiss_ui()


func _load(id: String) -> Dictionary:
	if _cache.has(id):
		var cached_any: Variant = _cache[id]
		if cached_any is Dictionary:
			return cached_any as Dictionary

	var path: String = _resolve_path_for_id(id)
	if path == "":
		return {}

	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()

	var parsed_any: Variant = JSON.parse_string(text)
	if parsed_any is Dictionary:
		var parsed: Dictionary = parsed_any
		_cache[id] = parsed
		return parsed
	return {}


func _resolve_path_for_id(id: String) -> String:
	if id.begins_with("res://"):
		var full: String = id if id.ends_with(file_ext) else (id + file_ext)
		return full if FileAccess.file_exists(full) else ""

	var id_with_ext: String = id if id.ends_with(file_ext) else (id + file_ext)
	var slash: int = id_with_ext.find("/")

	for dir_path in search_dirs:
		var base: String = (dir_path as String).rstrip("/")
		var candidate: String = base + "/" + id_with_ext
		if slash >= 0:
			var first: String = id_with_ext.substr(0, slash)
			if base.ends_with("/" + first):
				candidate = base + "/" + id_with_ext.substr(first.length() + 1)
		if FileAccess.file_exists(candidate):
			return candidate

	return id_with_ext if FileAccess.file_exists(id_with_ext) else ""


# ───────── UI discovery / creation ─────────
func _find_ui_in_tree() -> Node:
	var g: Node = get_tree().get_first_node_in_group("dialogue_ui")
	if g != null:
		return g
	var named: Node = get_tree().get_root().find_child("DialogueUI", true, false)
	return named


func _ensure_ui() -> Node:
	if _ui != null and is_instance_valid(_ui):
		if _ui_host == null or not is_instance_valid(_ui_host):
			_ui_host = _find_ui_host(_ui)
		_show_ui_host()
		return _ui

	var g: Node = get_tree().get_first_node_in_group("dialogue_ui")
	if g != null:
		_ui = g
		_ui_host = _find_ui_host(_ui)
		_ui_owned = false
		_show_ui_host()
		return _ui

	if dialogue_ui_scene == null:
		return null
	var inst: Node = dialogue_ui_scene.instantiate()
	get_tree().get_root().add_child(inst)
	_ui_owned = true
	_ui_host = inst

	var found_in_inst: Node = _find_show_line(inst)
	_ui = found_in_inst if found_in_inst != null else inst
	_show_ui_host()
	return _ui


func _find_show_line(root: Node) -> Node:
	if root.has_method("show_line"):
		return root
	for child: Node in root.get_children():
		var found: Node = _find_show_line(child)
		if found != null:
			return found
	return null


func _find_ui_host(ui_node: Node) -> Node:
	var n: Node = ui_node
	while n != null:
		if n is CanvasLayer:
			return n
		n = n.get_parent()
	return ui_node.get_parent()


func _show_ui_host() -> void:
	if _ui_host == null:
		return
	if _ui_host is CanvasItem:
		(_ui_host as CanvasItem).visible = true
	else:
		_ui_host.set("visible", true)


func _dismiss_ui() -> void:
	if _ui_host == null:
		return
	if _ui_owned:
		_ui_host.queue_free()
		_ui_host = null
		_ui = null
		_ui_owned = false
	else:
		if _ui_host is CanvasItem:
			(_ui_host as CanvasItem).visible = false
		else:
			_ui_host.set("visible", false)


func load_tree(root_id: String) -> void:
	start(root_id)
