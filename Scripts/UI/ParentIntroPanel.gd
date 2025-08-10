extends "res://Scripts/UI/TextSequencePanel.gd"

# Specific lines for the “parent” branch
const LINES : Array[String] = [
        "I had a happy childhood.\n...\nI had a childhood.",
        "You gave me some fundamental life skills.",
        "Stealth\nWoodcraft\nSelf-sufficiency\nResponsibility for the emotions of others",
        "You taught me to laugh at my own pain.",
        "You taught me to never laugh at your pain.",
        "But, all irony aside...",
        "...I know you did your best.\n Thank you.",
]

func _init() -> void:
        lines = LINES
