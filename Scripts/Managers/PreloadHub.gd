extends Node

const THREAD_LOAD_IN_PROGRESS := ResourceLoader.THREAD_LOAD_IN_PROGRESS
const THREAD_LOAD_LOADED      := ResourceLoader.THREAD_LOAD_LOADED

var default_paths: PackedStringArray = [
	"res://Scenes/Kun.tscn",
	"res://Scenes/WomanPhoto.tscn",
	"res://Scenes/FetusPhoto.tscn",
	"res://Scenes/Critters/CritterJesterka.tscn",
	"res://Scenes/Critters/CritterBrouk.tscn",
	"res://Scenes/Critters/CritterList.tscn",
	"res://Scenes/Critters/CritterSklenenka.tscn",
	"res://Scenes/Critters/CritterSnek.tscn",
	"res://Scenes/Critters/CritterKliste.tscn",
]

var _requested: Dictionary = {}   # path -> true
var _cache: Dictionary     = {}   # path -> Resource

func begin(paths: PackedStringArray = default_paths) -> void:
	for p in paths:
		if _requested.has(p): continue
		_requested[p] = true
		ResourceLoader.load_threaded_request(p)

func is_ready(path: String) -> bool:
	if _cache.has(path): return true
	var st := ResourceLoader.load_threaded_get_status(path)
	return st == THREAD_LOAD_LOADED

func get_now(path: String) -> Resource:
	if _cache.has(path): return _cache[path]
	if is_ready(path):
		var res := ResourceLoader.load_threaded_get(path)
		_cache[path] = res
		return res
	var res2 := load(path)
	_cache[path] = res2
	return res2

func get_async(path: String, timeout_sec: float = 1.2) -> Resource:
	if _cache.has(path): return _cache[path]
	var t0 := Time.get_ticks_msec()
	while true:
		var st := ResourceLoader.load_threaded_get_status(path)
		if st == THREAD_LOAD_LOADED:
			var res := ResourceLoader.load_threaded_get(path)
			_cache[path] = res
			return res
		if timeout_sec > 0.0 and (Time.get_ticks_msec() - t0) > int(timeout_sec * 1000.0):
			break
		await get_tree().process_frame
	return get_now(path)
