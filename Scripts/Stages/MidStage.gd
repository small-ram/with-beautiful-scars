extends Node

signal completed

func start() -> void:
    print("Mid-stage started")
    completed.emit()
