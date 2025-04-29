extends Control
signal choice_made(next_id)

@onready var body  := $VBoxContainer/BodyLabel
@onready var list  := $VBoxContainer/ChoiceList

func set_text(txt:String, choices:Array) -> void:
	body.text = txt
	list.clear()
	for c in choices:
		list.add_item(c["label"])
		list.set_item_metadata(list.item_count-1, c["next"])
	list.item_selected.connect(_on_choice)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	position = (get_viewport_rect().size - size) / 2    # center runtime

func _on_choice(idx:int) -> void:
	var next_id = list.get_item_metadata(idx)
	queue_free()  # close panel
	choice_made.emit(next_id)
