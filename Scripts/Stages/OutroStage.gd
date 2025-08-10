extends Node

signal completed

func start() -> void:
    print("Outro stage started")
    completed.emit()
