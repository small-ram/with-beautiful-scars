extends "res://Scripts/UI/IntroPanel.gd"

# Specific lines for the “parent” branch
var _parent_lines : Array[String] = [
	"I had a happy childhood.\n
	...\n
	I had a childhood.",
	"You gave me some fundamental life skills.",
	"Stealth\nWoodcraft\nSelf-sufficiency\nResponsibility for the emotions of others",
	"You taught me to laugh at my own pain.",
	"You taught me to never laugh at your pain.",
	"But, all irony aside...",
	"...I know you did your best.\n Thank you.",
]

func _ready() -> void:
	lines = _parent_lines          # overwrite base-class var
	super._ready()                 # run original setup
