extends RigidBody3D
class_name DroppedItemPickup

# ---------------------------------------------------------
# Injected by InventoryManager AFTER spawn
# ---------------------------------------------------------
var item_id: String
var quantity: int = 1

# ---------------------------------------------------------
# Setup
# ---------------------------------------------------------
func _physics_process(_delta):
	if sleeping:
		freeze = true
		set_physics_process(false)

# ---------------------------------------------------------
# Called by InventoryManager after spawning
# ---------------------------------------------------------
func set_item_data(_id: String, _qty: int):
	item_id = _id
	quantity = _qty

# ---------------------------------------------------------
# Called by PlayerController when clicked
# ---------------------------------------------------------
func on_click(_player):
	if not item_id or quantity <= 0:
		push_warning("DroppedItemPickup clicked with invalid data")
		return

	var success := InventoryManager.add_item(
		{"id": item_id},
		quantity
	)

	if success:
		queue_free()
	else:
		print("Inventory Full!")
