extends Node

signal completed

func start() -> void:
    print("Parent/difficulty stage started")
    completed.emit()
