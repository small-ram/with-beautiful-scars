# scripts/Gameplay/FetusPhoto.gd
extends Area2D
signal dialog_done

func _ready() -> void:
	DialogueManager.load_tree("fetus_dialog")   # open JSON dialogue
	DialogueManager.dialogue_closed.connect(_on_dialog_closed)

func _on_dialog_closed(_id:String) -> void:
	dialog_done.emit()
