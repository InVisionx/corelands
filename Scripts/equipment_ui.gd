extends Control

signal equipment_updated()

@onready var grid := $PanelContainer/VBoxContainer/GridContainer

# Map slot node names to profile slot keys
const SLOT_MAP = {
	"CapeSlot": "cape",
	"HelmetSlot": "helm",
	"AmuletSlot": "amulet",
	"WeaponSlot": "weapon",
	"OffhandSlot": "offhand",
	"ChestSlot": "chest",
	"LegsSlot": "legs",
	"GlovesSlot": "gloves",
	"BootsSlot": "boots"
}

var default_icons: Dictionary = {}

func _ready():
	for child in grid.get_children():
		if child is TextureButton:
			child.focus_mode = Control.FOCUS_NONE
			child.connect("pressed", Callable(self, "_on_slot_pressed").bind(child.name))
			default_icons[child.name] = child.texture_normal

	# 🔗 Connect refresh signals
	if not EquipmentManager.is_connected("equipment_updated", Callable(self, "_refresh_icons")):
		EquipmentManager.connect("equipment_updated", Callable(self, "_refresh_icons"))

	if not InventoryManager.is_connected("inventory_updated", Callable(self, "_refresh_icons")):
		InventoryManager.connect("inventory_updated", Callable(self, "_refresh_icons"))

	_refresh_icons()

# ----------------------------------------
# 🖱️ When clicking a slot (unequip)
# ----------------------------------------
func _on_slot_pressed(slot_name: String):
	var slot_key = SLOT_MAP.get(slot_name, "")
	if slot_key == "":
		return
	print("🧤 UI clicked unequip:", slot_key)
	EquipmentManager.unequip_slot(slot_key)

# ----------------------------------------
# 🔁 Refresh icons + tooltips
# ----------------------------------------
func _refresh_icons():
	print("🔁 Refreshing equipment icons")
	if not ProfileManager.current_profile.has("equipment"):
		return

	var equip_array = ProfileManager.current_profile["equipment"]

	for child in grid.get_children():
		if not (child is TextureButton):
			continue

		var slot_type = SLOT_MAP.get(child.name, "")
		var found_item_id = null

		for slot in equip_array:
			if slot["slot"] == slot_type:
				found_item_id = slot.get("item", null)
				break

		if found_item_id != null and found_item_id != "":
			var item_data = ItemDataBase.get_item(found_item_id)
			if item_data and item_data.icon:
				child.texture_normal = item_data.icon
				child.tooltip_text = item_data.display_name if item_data.display_name != "" else found_item_id
			else:
				child.texture_normal = default_icons.get(child.name, null)
				child.tooltip_text = "Empty " + slot_type.capitalize() + " slot"
		else:
			child.texture_normal = default_icons.get(child.name, null)
			child.tooltip_text = "Empty " + slot_type.capitalize() + " slot"

	print("✅ Equipment icons + tooltips updated.\n")
