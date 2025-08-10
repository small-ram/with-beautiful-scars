extends Node

signal completed

func start() -> void:
    print("Cleanup stage started")
    completed.emit()
