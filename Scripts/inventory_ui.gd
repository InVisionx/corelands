extends Control

@export var total_slots: int = 28  
@onready var grid: GridContainer = $PanelContainer/VBoxContainer/GridContainer
const SLOT_SCENE := preload("res://Scenes/inventory_slot.tscn")

func _ready():
	var inventory: Array = ProfileManager.current_profile.get("inventory", [])

	# Create slots
	for i in range(total_slots):
		var slot = SLOT_SCENE.instantiate()
		slot.slot_index = i
		grid.add_child(slot)

		# Initial populate
		if i < inventory.size() and inventory[i] != null:
			var item_data = inventory[i]
			_populate_slot(slot, item_data)
		else:
			_clear_slot(slot)

	# Ensure layout is calculated
	await get_tree().process_frame
	grid.queue_sort()

	# Listen for updates
	InventoryManager.connect("inventory_updated", Callable(self, "_refresh_inventory"))
	_refresh_inventory()


func _populate_slot(slot: Node, item_data: Dictionary) -> void:
	if not item_data.is_empty():
		if slot.has_method("set_item"):
			slot.set_item(item_data.get("id", ""), item_data.get("qty", 1))
	else:
		_clear_slot(slot)


func _clear_slot(slot: Node) -> void:
	if slot.has_method("clear"):
		slot.clear()


func _refresh_inventory():
	var inventory = ProfileManager.current_profile.get("inventory", [])
	for i in range(grid.get_child_count()):
		var slot = grid.get_child(i)
		
		# Guard against out of bounds if inventory array is smaller than UI slots
		if i < inventory.size() and inventory[i] != null:
			var item = inventory[i]
			var id = item.get("id", "")
			var qty = item.get("qty", 1)
			slot.set_item(id, qty)
		else:
			slot.clear()
