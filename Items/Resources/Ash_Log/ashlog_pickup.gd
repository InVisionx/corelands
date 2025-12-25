extends Clickable

# Data passed from InventoryManager
var item_id: String = "ashlog"
var quantity: int = 1

func _ready():
	interaction_type = "interact"
	add_to_group("interact")
	
	await get_tree().create_timer(3.0).timeout
	
	# "freeze" is the property name. true is the value.
	# This bypasses the "Invalid Cast" error completely.
	set_deferred("freeze", true)

# Called by InventoryManager after spawning
func set_item_data(_id: String, _qty: int):
	item_id = _id
	quantity = _qty

# Called by PlayerController when clicked
func on_click(_player):
	var success = InventoryManager.add_item({"id": item_id}, quantity)
	if success:
		queue_free()
	else:
		print("Inventory Full!")
