extends Node

signal claimed(mem_id: String)

# --------------------------------------------------------------------
#  INTERNAL DATA (typed)
# --------------------------------------------------------------------
var table: MemoryTable = null                   # set from StageController
var _free: Array[String] = []                   # IDs still available

# --------------------------------------------------------------------
#  INITIALISE FROM STAGECONTROLLER
# --------------------------------------------------------------------
func init_from_table(t: MemoryTable) -> void:
	table = t
	_free.clear()

	if t == null:
		push_error("MemoryPool.init_from_table: memory table is NULL. Assign StageController.memory_table in the editor.")
		return

	# Expect MemoryTable to expose a typed Dictionary property.
	# Use explicit type to avoid Variant inference warnings.
	var mapping: Dictionary = t.slot_to_memory_id

	if typeof(mapping) != TYPE_DICTIONARY:
		push_error("MemoryPool.init_from_table: 'slot_to_memory_id' must be a Dictionary, got %s." % typeof(mapping))
		return

	# Copy all values (assumed string IDs) into a typed array
	var values_array: Array = mapping.values()        # returns Array (untyped)
	_free = []                                        # rebuild as Array[String]
	for v in values_array:
		if typeof(v) == TYPE_STRING:
			_free.append(v)
		else:
			push_warning("MemoryPool: non-string ID ignored: %s" % str(v))

# --------------------------------------------------------------------
#  PUBLIC API
# --------------------------------------------------------------------
func is_free(id: String) -> bool:
	return id in _free

func claim(id: String) -> void:
	_free.erase(id)
	claimed.emit(id)

func all_used() -> bool:
	return _free.is_empty()
