extends Node

signal bank_updated()
signal slot_clicked(slot_index: int, item_data: Dictionary)
signal item_transferred(from: String, to: String, item_id: String, qty: int)

var player_ref: Node = null
var selected_slot: int = -1
var _busy := false
var placeholders_enabled: bool = false


# -------------------------------
# 🔗 PLAYER REFERENCE
# -------------------------------
func set_player(player: Node) -> void:
	player_ref = player

func get_player() -> Node:
	return player_ref


# -------------------------------
# 🔍 GET BANK
# -------------------------------
func _get_bank() -> Array:
	if not ProfileManager.current_profile.has("bank"):
		ProfileManager.current_profile["bank"] = []
	return ProfileManager.current_profile["bank"]


# -------------------------------
# ✅ ADD ITEM (stacking fixed + placeholders respected)
# -------------------------------
func add_item(item: Dictionary, quantity: int = 1) -> bool:
	var bank = _get_bank()
	var item_id = item.get("id", "")
	if item_id == "":
		push_warning("❌ add_item: Missing ID")
		return false

	print("🏦 add_item:", item_id, "qty:", quantity)

	# --- 1️⃣ Always stack items if they already exist ---
	for slot in bank:
		if slot != null and slot.get("id", "") == item_id and not slot.get("placeholder", false):
			slot["qty"] = slot.get("qty", 0) + quantity
			print("🧱 Stacked", item_id, "→ New qty:", slot["qty"])
			emit_signal("bank_updated")
			_save()
			return true

	# --- 2️⃣ Replace placeholder if present ---
	for i in range(bank.size()):
		var slot = bank[i]
		if slot != null and slot.get("placeholder", false) and slot.get("id", "") == item_id:
			print("📦 Replacing placeholder:", item_id)
			bank[i] = {"id": item_id, "qty": quantity, "placeholder": false}
			emit_signal("bank_updated")
			_save()
			return true

	# --- 3️⃣ Otherwise add to first empty slot ---
	for i in range(bank.size()):
		if bank[i] == null:
			print("💠 Added new entry:", item_id)
			bank[i] = {"id": item_id, "qty": quantity, "placeholder": false}
			emit_signal("bank_updated")
			_save()
			return true

	push_warning("⚠️ Bank full, cannot add item: " + item_id)
	return false

# -------------------------------
# ❌ REMOVE ITEM (Withdraw or convert to placeholder)
# -------------------------------
func remove_item(slot_index: int, quantity: int = 1) -> void:
	var bank = _get_bank()
	if slot_index < 0 or slot_index >= bank.size(): return

	var slot = bank[slot_index]
	if slot == null: return

	slot["qty"] -= quantity

	if slot["qty"] <= 0:
		var id = slot.get("id", "")
		if placeholders_enabled:
			bank[slot_index] = {"id": id, "qty": 0, "placeholder": true}
		else:
			bank[slot_index] = null

	emit_signal("bank_updated")
	_save()


# -------------------------------
# 🔁 MOVE / SWAP
# -------------------------------
func move_item(from_index: int, to_index: int) -> void:
	var bank = _get_bank()
	if from_index == to_index: return
	if from_index < 0 or to_index < 0: return
	if from_index >= bank.size() or to_index >= bank.size(): return

	var temp = bank[from_index]
	bank[from_index] = bank[to_index]
	bank[to_index] = temp

	emit_signal("bank_updated")
	_save()


# -------------------------------
# 🖱️ SLOT CLICK HANDLER
# -------------------------------
func on_slot_clicked(slot_index: int) -> void:
	print("📦 Bank slot clicked:", slot_index)
	if _busy:
		print("⚙️ Busy, ignoring click")
		return
	_busy = true

	var bank = _get_bank()
	if slot_index < 0 or slot_index >= bank.size():
		_busy = false
		return

	var slot_data = bank[slot_index]
	if slot_data == null:
		_busy = false
		return

	if selected_slot == -1:
		selected_slot = slot_index
	else:
		move_item(selected_slot, slot_index)
		selected_slot = -1

	_busy = false
	emit_signal("bank_updated")


# -------------------------------
# 🔁 TRANSFER TO INVENTORY
# -------------------------------
func withdraw_to_inventory(slot_index: int, quantity: int = 1) -> bool:
	var bank = _get_bank()
	if slot_index < 0 or slot_index >= bank.size():
		return false

	var slot = bank[slot_index]
	if slot == null or slot.get("placeholder", false):
		return false

	var id = slot.get("id", "")
	var item_data = ItemDataBase.get_item(id)
	if not item_data:
		return false

	if InventoryManager.add_item({"id": id, "stackable": item_data.stackable}, quantity):
		remove_item(slot_index, quantity)
		emit_signal("item_transferred", "bank", "inventory", id, quantity)
		return true
	else:
		push_warning("⚠️ Inventory full, cannot withdraw " + id)
		return false


# -------------------------------
# 🔁 TRANSFER FROM INVENTORY
# -------------------------------
func deposit_from_inventory(inv_slot_index: int, quantity: int = 1) -> bool:
	var inventory = ProfileManager.current_profile["inventory"]
	if inv_slot_index < 0 or inv_slot_index >= inventory.size():
		return false

	var slot = inventory[inv_slot_index]
	if slot == null:
		return false

	var id = slot.get("id", "")
	var item_data = ItemDataBase.get_item(id)
	if not item_data:
		return false

	if add_item({"id": id, "stackable": item_data.stackable}, quantity):
		InventoryManager.remove_item(inv_slot_index, quantity)
		emit_signal("item_transferred", "inventory", "bank", id, quantity)
		return true
	else:
		push_warning("⚠️ Bank full, cannot deposit " + id)
		return false


# -------------------------------
# 🧭 PLACEHOLDER TOGGLE
# -------------------------------
func set_placeholders_enabled(state: bool) -> void:
	placeholders_enabled = state
	print("🏦 Placeholders enabled:", placeholders_enabled)


# -------------------------------
# 💾 SAVE
# -------------------------------
func _save() -> void:
	ProfileManager.save_profile()
