extends Node

signal inventory_updated()
signal slot_clicked(slot_index: int, item_data: Dictionary)

var player_ref: Node = null

# -------------------------------
# 🔍 GET INVENTORY
# -------------------------------
func _get_inventory() -> Array:
	if not ProfileManager.current_profile.has("inventory"):
		ProfileManager.current_profile["inventory"] = []
	return ProfileManager.current_profile["inventory"]

# -------------------------------
# ✅ ADD ITEM (SAFE + STACK-AWARE)
# -------------------------------
func add_item(item: Dictionary, quantity: int = 1) -> bool:
	var inventory = _get_inventory()
	var item_id = item.get("id", "")

	if item_id == "":
		return false

	var item_data = ItemDataBase.get_item(item_id)
	var stackable = item_data != null and item_data.stackable

	# Try stacking first
	if stackable:
		for slot in inventory:
			if slot != null and slot.get("id", "") == item_id:
				slot["qty"] += quantity
				emit_signal("inventory_updated")
				_save()
				return true

	# Find empty slot
	for i in range(inventory.size()):
		if inventory[i] == null:
			inventory[i] = {"id": item_id, "qty": quantity}
			emit_signal("inventory_updated")
			_save()
			return true

	push_warning("⚠ Inventory full, cannot add item: " + item_id)
	return false

# -------------------------------
# ❌ REMOVE ITEM
# -------------------------------
func remove_item(slot_index: int, quantity: int = 1) -> void:
	var inventory = _get_inventory()
	if slot_index < 0 or slot_index >= inventory.size():
		return

	var slot = inventory[slot_index]
	if slot == null:
		return

	slot["qty"] -= quantity
	if slot["qty"] <= 0:
		inventory[slot_index] = null

	emit_signal("inventory_updated")
	_save()

# -------------------------------
# 🔁 MOVE / SWAP
# -------------------------------
func move_item(from_index: int, to_index: int) -> void:
	var inventory = _get_inventory()
	if from_index == to_index:
		return
	if from_index < 0 or to_index < 0:
		return
	if from_index >= inventory.size() or to_index >= inventory.size():
		return

	var temp = inventory[from_index]
	inventory[from_index] = inventory[to_index]
	inventory[to_index] = temp

	emit_signal("inventory_updated")
	_save()

# -------------------------------
# 🖱️ SLOT CLICK HANDLER
# -------------------------------
var selected_slot: int = -1
var _busy := false

func on_slot_clicked(slot_index: int) -> void:
	if _busy:
		return
	_busy = true

	var inventory = _get_inventory()
	if slot_index < 0 or slot_index >= inventory.size():
		_busy = false
		return

	var slot_data = inventory[slot_index]
	if slot_data == null:
		_busy = false
		return

	# -------------------------------
	# ⚔️ EQUIP CHECK
	# -------------------------------
	var id = slot_data.get("id", "")
	if id != "":
		var item_data = ItemDataBase.get_item(id)
		if item_data and item_data.equip_slot != "":
			# EquipmentManager handles EVERYTHING:
			# - swap
			# - inventory removal
			# - visuals
			# - saving
			EquipmentManager.equip_item(id, slot_index)
			_busy = false
			return

	# -------------------------------
	# 🧳 DEFAULT INVENTORY MOVE
	# -------------------------------
	if selected_slot == -1:
		selected_slot = slot_index
	else:
		move_item(selected_slot, slot_index)
		selected_slot = -1

	_busy = false

# -------------------------------
# 🧰 HELPERS (USED BY EQUIPMENT MANAGER)
# -------------------------------
func get_slot(slot_index: int) -> Dictionary:
	var inventory = _get_inventory()
	if slot_index < 0 or slot_index >= inventory.size():
		return {}
	return inventory[slot_index] if inventory[slot_index] != null else {}

func set_slot(slot_index: int, data: Dictionary) -> void:
	var inventory = _get_inventory()
	if slot_index < 0 or slot_index >= inventory.size():
		return
	inventory[slot_index] = data if data.size() > 0 else null
	emit_signal("inventory_updated")
	_save()

func clear_slot(slot_index: int) -> void:
	set_slot(slot_index, {})

# -------------------------------
# 🔗 PLAYER REFERENCE
# -------------------------------
func set_player(player: Node) -> void:
	player_ref = player

# -------------------------------
# 💾 SAVE
# -------------------------------
func _save() -> void:
	ProfileManager.save_profile()
