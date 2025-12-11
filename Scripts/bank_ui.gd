extends Control

@onready var bank_grid: GridContainer = $PanelContainer/VBoxContainer/HBoxContainer/Bank/ScrollContainer/BankGrid
@onready var inv_grid: GridContainer = $PanelContainer/VBoxContainer/HBoxContainer/Inv/InvGrid
@onready var space: Label = $PanelContainer/VBoxContainer/HBoxContainer2/Label
@onready var placeholder_toggle: CheckBox = $PanelContainer/VBoxContainer/HBoxContainer2/Placeholder
const SLOT_SCENE := preload("res://Scenes/bank_slot.tscn")

var player_ui: Node = null


# -------------------------------
# 🔧 READY
# -------------------------------
func _ready():
	_refresh_bank()
	_refresh_inventory()

	BankManager.connect("bank_updated", Callable(self, "_refresh_bank"))
	InventoryManager.connect("inventory_updated", Callable(self, "_refresh_inventory"))

	player_ui = get_parent().get_node_or_null("UI")
	if player_ui:
		player_ui.visible = false

	# ✅ Connect placeholder toggle
	if placeholder_toggle:
		placeholder_toggle.connect("toggled", Callable(self, "_on_placeholders_toggled"))


# -------------------------------
# ⎋ ESCAPE CLOSE
# -------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if ProfileManager and not ProfileManager.current_profile.is_empty():
				ProfileManager.save_profile()
			if player_ui:
				player_ui.visible = true
			queue_free()


# -------------------------------
# 🧹 Utility
# -------------------------------
func _clear_children(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()


func compress_bank() -> void:
	var bank = ProfileManager.current_profile.get("bank", [])
	var compressed: Array = []

	# Move all non-empty or placeholder slots to the top
	for slot in bank:
		if slot != null:
			compressed.append(slot)

	while compressed.size() < bank.size():
		compressed.append(null)

	ProfileManager.current_profile["bank"] = compressed
	ProfileManager.save_profile()


# -------------------------------
# 🏦 Populate Bank Side
# -------------------------------
func _refresh_bank():
	var spaces = 0
	_clear_children(bank_grid)
	compress_bank()
	var bank = ProfileManager.current_profile.get("bank", [])

	for i in range(bank.size()):
		var slot_node = SLOT_SCENE.instantiate()
		slot_node.slot_index = i
		bank_grid.add_child(slot_node)

		var slot_data = bank[i]
		if slot_data != null:
			var id = slot_data.get("id", "")
			var qty = slot_data.get("qty", 0)
			var is_placeholder = slot_data.get("placeholder", false)

			slot_node.set_item(id, qty)
			spaces += 1

			# 🕸️ Faded icon for placeholders
			if is_placeholder:
				slot_node.modulate = Color(1, 1, 1, 0.35)
				if slot_node.has_node("Quantity"):
					slot_node.get_node("Quantity").text = ""
			else:
				slot_node.modulate = Color(1, 1, 1, 1)
		else:
			slot_node.clear()

		slot_node.connect("bank_slot_pressed", Callable(self, "_on_bank_slot_clicked"))

	space.text = "{0}/100".format([spaces])


# -------------------------------
# 🎒 Populate Inventory Side
# -------------------------------
func _refresh_inventory():
	_clear_children(inv_grid)
	var inv = ProfileManager.current_profile.get("inventory", [])

	for i in range(inv.size()):
		var slot_node = SLOT_SCENE.instantiate()
		slot_node.slot_index = i
		inv_grid.add_child(slot_node)

		var slot_data = inv[i]
		if slot_data != null:
			slot_node.set_item(slot_data.get("id", ""), slot_data.get("qty", 1))
		else:
			slot_node.clear()

		slot_node.connect("bank_slot_pressed", Callable(self, "_on_inventory_slot_clicked"))


# -------------------------------
# 🖱️ Click Handlers
# -------------------------------
func _on_bank_slot_clicked(slot_index: int) -> void:
	var bank = ProfileManager.current_profile.get("bank", [])
	if slot_index < 0 or slot_index >= bank.size():
		return

	var slot = bank[slot_index]
	if slot == null:
		return

	# 🧱 Skip placeholder slots
	if slot.get("placeholder", false):
		print("Clicked a placeholder — skipping")
		return

	var qty = slot.get("qty", 1)
	var move_qty = 1 if qty > 1 else qty

	if BankManager.withdraw_to_inventory(slot_index, move_qty):
		_refresh_bank()
		_refresh_inventory()


func _on_inventory_slot_clicked(slot_index: int) -> void:
	var inv = ProfileManager.current_profile.get("inventory", [])
	if slot_index < 0 or slot_index >= inv.size():
		return

	var slot = inv[slot_index]
	if slot == null:
		return

	var qty = slot.get("qty", 1)
	var move_qty = 1 if qty > 1 else qty

	if BankManager.deposit_from_inventory(slot_index, move_qty):
		_refresh_bank()
		_refresh_inventory()


# -------------------------------
# 🧭 Placeholder Toggle
# -------------------------------
func _on_placeholders_toggled(pressed: bool) -> void:
	print("🧩 Placeholder mode:", pressed)
	BankManager.set_placeholders_enabled(pressed)
