extends Node

signal completed

func start() -> void:
    print("Fetus stage started")
    completed.emit()
