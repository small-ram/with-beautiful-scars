extends Node

signal completed

func start() -> void:
    print("Main gameplay stage started")
    completed.emit()
