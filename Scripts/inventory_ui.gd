extends Control

@export var total_slots: int = 28  # ✅ configurable slot count in the editor
@onready var grid: GridContainer = $PanelContainer/VBoxContainer/GridContainer
const SLOT_SCENE := preload("res://Scenes/inventory_slot.tscn")

func _ready():
	var inventory: Array = ProfileManager.current_profile.get("inventory", [])

	for i in range(total_slots):
		var slot = SLOT_SCENE.instantiate()
		slot.slot_index = i
		grid.add_child(slot)

		# If this slot index has a valid item, populate it
		if i < inventory.size() and inventory[i] != null:
			var item_data = inventory[i]
			_populate_slot(slot, item_data)
		else:
			_clear_slot(slot)

	await get_tree().process_frame
	grid.queue_sort()

	InventoryManager.connect("inventory_updated", Callable(self, "_refresh_inventory"))
	InventoryManager.connect("slot_clicked", Callable(self, "_on_slot_clicked"))
	_refresh_inventory()


# --------------------------
# Optional helper functions
# --------------------------

func _populate_slot(slot: Node, item_data: Dictionary) -> void:
	if not item_data.is_empty():
		# Example: your slot script may have set_item(icon, qty)
		if slot.has_method("set_item"):
			slot.set_item(item_data.get("icon", null), item_data.get("qty", 1))
	else:
		_clear_slot(slot)

func _clear_slot(slot: Node) -> void:
	if slot.has_method("clear"):
		slot.clear()

func _refresh_inventory():
	var inventory = ProfileManager.current_profile.get("inventory", [])
	for i in range(grid.get_child_count()):
		var slot = grid.get_child(i)
		if i < inventory.size() and inventory[i] != null:
			var item = inventory[i]
			var id = item.get("id", "")
			var qty = item.get("qty", 1)
			slot.set_item(id, qty)
		else:
			slot.clear()

func _on_slot_clicked(index: int, _item: Dictionary):
	InventoryManager.on_slot_clicked(index)
