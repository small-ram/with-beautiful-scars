# scripts/UI/IntroPanel.gd
extends "res://Scripts/UI/TextSequencePanel.gd"

const LINES : Array[String] = [
		"She was a tough child.",
		"Now she always seems to be on the verge of ABYSS.",
		"(Or something equally dramatic to emphasize her mental instability)",
		"Her therapist said she believes\n in the 'transformational power of internal dialogue'.",
		"...",
		"That's easy.",
		"The abyss has always had your voice.",
		"\"Hey.\""
]
func _init() -> void:
		lines = LINES
