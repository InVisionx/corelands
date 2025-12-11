extends Clickable

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group(interaction_type)
	print("added to group : " + interaction_type)

func on_click(_player):
	print("in click")
	var bank_pre = preload("res://Scenes/bank_ui.tscn")
	var bank = bank_pre.instantiate()
	var ui = _player.get_node_or_null("UI_Layer")
	if ui:
		ui.add_child(bank)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
