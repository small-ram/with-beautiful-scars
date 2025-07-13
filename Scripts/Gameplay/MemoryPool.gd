extends Node
# --------------------------------------------------------------------
#  INTERNAL DATA
# --------------------------------------------------------------------
var table : MemoryTable            # will be set from StageController
var _free : Array = []     # IDs that are still available
# --------------------------------------------------------------------
#  INITIALISE FROM STAGECONTROLLER
# --------------------------------------------------------------------
func init_from_table(t : MemoryTable) -> void:
	table  = t
	_free  = t.slot_to_memory_id.values()     # fresh copy of all IDs
# --------------------------------------------------------------------
#  PUBLIC API
# --------------------------------------------------------------------
func is_free(id : String) -> bool:
	return id in _free
	
func claim(id : String) -> void:
	_free.erase(id)
	claimed.emit(id)
	
func all_used() -> bool:
	return _free.is_empty()

signal claimed(mem_id:String)
