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
# ✅ ADD ITEM
# -------------------------------
func add_item(item: Dictionary, quantity: int = 1) -> bool:
	var inventory = _get_inventory()
	var stackable = item.get("stackable", false)
	var item_id = item.get("id", "")

	# Try to stack first
	if stackable:
		for slot in inventory:
			if slot != null and slot.get("id", "") == item_id:
				slot["qty"] += quantity
				emit_signal("inventory_updated")
				_save()
				return true

	# Otherwise find empty slot
	for i in range(inventory.size()):
		if inventory[i] == null:
			inventory[i] = {"id": item_id, "qty": quantity}
			emit_signal("inventory_updated")
			_save()
			return true

	# Fallback — inventory full, could add logic later
	push_warning("⚠️ Inventory full, cannot add item: " + item_id)
	return false


# -------------------------------
# ❌ REMOVE ITEM
# -------------------------------
func remove_item(slot_index: int, quantity: int = 1) -> void:
	var inventory = _get_inventory()
	if slot_index < 0 or slot_index >= inventory.size(): return

	var slot = inventory[slot_index]
	if slot == null: return

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
	if from_index == to_index: return
	if from_index < 0 or to_index < 0: return
	if from_index >= inventory.size() or to_index >= inventory.size(): return

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
	print("we clicked the slot and are in the inventory manager")
	if _busy:
		print("we are busy")
		return
	_busy = true

	var inventory = _get_inventory()
	if slot_index < 0 or slot_index >= inventory.size():
		print("slot index less than 0?")
		_busy = false
		return

	var slot_data = inventory[slot_index]
	if slot_data == null:
		print("slot data null")
		_busy = false
		return

	# -------------------------------
	# ⚔️ EQUIP CHECK
	# -------------------------------
	var id = slot_data.get("id", "")
	if id != "":
		var item_data = ItemDataBase.get_item(id)
		if item_data and item_data.equip_slot != "":
			print("🗡️ Equipping item via EquipmentManager:", id)

			# ✅ Use EquipmentManager to handle logic
			EquipmentManager.equip_item(id)

			# Remove item from inventory
			inventory[slot_index] = null
			ProfileManager.current_profile["inventory"] = inventory
			ProfileManager.save_profile()

			emit_signal("inventory_updated")
			_busy = false
			return  # prevent move logic

	# -------------------------------
	# 🧳 DEFAULT INVENTORY LOGIC
	# -------------------------------
	if selected_slot == -1:
		selected_slot = slot_index
	else:
		move_item(selected_slot, slot_index)
		selected_slot = -1

	_busy = false
	emit_signal("inventory_updated")

# -------------------------------
# ⚔️ EQUIP ITEM
# -------------------------------
func _equip_item(slot_index: int, item_data: ItemData) -> void:
	if not player_ref:
		push_warning("⚠️ No player reference set.")
		return

	print("▶ EQUIP attempt:", item_data.id, "slot:", item_data.equip_slot)

	var equip_slot := item_data.equip_slot
	if equip_slot == "":
		push_warning("⚠️ Item missing equip_slot, cannot equip.")
		return

	# -------------------------------
	# ⚔️ EQUIP: Weapon Slot
	# -------------------------------
	if equip_slot == "weapon":
		var attach: BoneAttachment3D = player_ref.get_node_or_null("PlayerModel/Skeleton3D/WeaponAttach")
		if not attach:
			push_warning("⚠️ WeaponAttach not found on player.")
			return

		# Clear existing weapon
		for c in attach.get_children():
			c.queue_free()

		if item_data.prefab:
			var weapon_instance = item_data.prefab.instantiate()
			weapon_instance.name = item_data.id
			attach.add_child(weapon_instance)
			player_ref.has_2h = true

			var idle_transform: Node3D = weapon_instance.get_node_or_null("IdleTransform")
			if idle_transform:
				weapon_instance.transform = idle_transform.transform
				print("✨ Applied IdleTransform to", item_data.id)
			else:
				print("ℹ️ No IdleTransform found for", item_data.id)

			print("✅ Equipped weapon prefab:", item_data.id)
		else:
			push_warning("⚠️ Item has no prefab to equip.")
			return
	else:
		print("⚠️ Equip slot not implemented yet:", equip_slot)

	# -------------------------------
	# 🧠 UPDATE PROFILE EQUIPMENT
	# -------------------------------
	var equip_array: Array = ProfileManager.current_profile.get("equipment", [])
	var updated := false
	for slot in equip_array:
		if slot["slot"] == equip_slot:
			slot["item"] = item_data.id
			updated = true
			break

	if not updated:
		equip_array.append({"slot": equip_slot, "item": item_data.id})
	ProfileManager.current_profile["equipment"] = equip_array

	print("💾 Equipment array updated:", equip_array)

	# -------------------------------
	# 🧹 REMOVE ITEM FROM INVENTORY
	# -------------------------------
	var inventory = _get_inventory()
	if slot_index >= 0 and slot_index < inventory.size():
		print("🧹 Removing from inventory slot", slot_index)
		inventory[slot_index] = null
	else:
		push_warning("⚠️ Invalid slot index:", slot_index)

	ProfileManager.current_profile["inventory"] = inventory

	# -------------------------------
	# 💾 SAVE + REFRESH UI
	# -------------------------------
	ProfileManager.save_profile()
	emit_signal("inventory_updated")

	var equip_ui: Node = player_ref.get_node_or_null("UI_Layer/UI/EquipmentUI")
	if equip_ui and equip_ui.has_signal("equipment_updated"):
		equip_ui.emit_signal("equipment_updated")

	print("✅ Equip complete for", item_data.id)

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
