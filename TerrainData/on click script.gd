extends Clickable

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group(interaction_type)
	print("added to group : " + interaction_type)

func on_click(_player):
	print("we are inside on_click")
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
